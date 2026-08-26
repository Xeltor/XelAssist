-- Bounded session evidence for ordinary hostile white swings. Raw Nampower
-- packets are admitted only when both opaque identities are currently proven;
-- player/pet-owned attacks remain in their dedicated ledgers.
XelAssist.Game.HostileAttackRounds = {}
local H = XelAssist.Game.HostileAttackRounds

H.MAX_LANES = 5
H.INTERVAL_SAMPLES = 3
H.DAMAGE_SAMPLES = 5
H.STALE_MULTIPLIER = 1.75
H.lanes = {}

local function flag(value, mask)
    value, mask = tonumber(value) or 0, tonumber(mask) or 1
    return math.floor(value / mask)
        - math.floor(value / (mask * 2)) * 2 == 1
end

local function liveGuid(unit)
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 or guid == nil then return nil end
    return guid
end

local function owned(guid)
    return guid ~= nil and (guid == liveGuid("player") or guid == liveGuid("pet"))
end

local function friendlyUnit(guid)
    if guid == nil then return nil end
    if guid == liveGuid("player") then return "player" end
    if guid == liveGuid("pet") then return "pet" end
    local raid = type(GetNumRaidMembers) == "function"
        and math.max(0, math.min(40, tonumber(GetNumRaidMembers()) or 0)) or 0
    local party = type(GetNumPartyMembers) == "function"
        and math.max(0, math.min(4, tonumber(GetNumPartyMembers()) or 0)) or 0
    local i
    for i = 1, raid do
        if liveGuid("raid" .. i) == guid then return "raid" .. i end
    end
    for i = 1, party do
        if liveGuid("party" .. i) == guid then return "party" .. i end
    end
    return nil
end

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge then return nil end
    return value
end

local function mitigationRegime(unit)
    if type(UnitArmor) ~= "function" or liveGuid(unit) == nil then return nil end
    local ok, base, effective, armor, positive, negative = pcall(UnitArmor, unit)
    base, effective, armor = finite(base), finite(effective), finite(armor)
    if not ok or base == nil or effective == nil or armor == nil then return nil end
    local defenseBase, defenseModifier
    if type(UnitDefense) == "function" then
        local defenseOk
        defenseOk, defenseBase, defenseModifier = pcall(UnitDefense, unit)
        defenseBase, defenseModifier = finite(defenseBase), finite(defenseModifier)
        if not defenseOk or defenseBase == nil or defenseModifier == nil then
            return nil
        end
    end
    local level = type(UnitLevel) == "function" and finite(UnitLevel(unit)) or nil
    if level == nil then return nil end
    local form = unit == "player" and type(GetShapeshiftForm) == "function"
        and finite(GetShapeshiftForm()) or 0
    if form == nil then return nil end
    return { baseArmor = base, effectiveArmor = effective, armor = armor,
        positiveArmor = finite(positive) or 0, negativeArmor = finite(negative) or 0,
        defenseBase = defenseBase, defenseModifier = defenseModifier,
        level = level, form = form }
end

local function sameRegime(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    local key, value
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key, value in pairs(right) do if left[key] ~= value then return false end end
    return true
end

local function laneFor(owner, attacker, victim, hand)
    local i, lane
    for i = 1, table.getn(owner.lanes) do
        lane = owner.lanes[i]
        if lane.attackerGuid == attacker and lane.victimGuid == victim
            and lane.hand == hand then return lane end
    end
    if table.getn(owner.lanes) >= owner.MAX_LANES then table.remove(owner.lanes, 1) end
    lane = { attackerGuid = attacker, victimGuid = victim, hand = hand,
        intervals = {}, damages = {}, blockedAmounts = {}, eligibleHits = {},
        generation = 0 }
    table.insert(owner.lanes, lane)
    return lane
end

local function boundedInsert(values, value, maximum)
    table.insert(values, value)
    while table.getn(values) > maximum do table.remove(values, 1) end
end

local function median(values)
    if table.getn(values) < H.INTERVAL_SAMPLES then return nil end
    local ordered, i = {}, nil
    for i = 1, table.getn(values) do ordered[i] = values[i] end
    table.sort(ordered)
    return ordered[math.floor((table.getn(ordered) + 1) / 2)]
end

local function stableInterval(values)
    local middle = median(values)
    if not middle or middle < 0.4 or middle > 10 then return nil end
    local low, high = values[1], values[1]
    local i
    for i = 2, table.getn(values) do
        low, high = math.min(low, values[i]), math.max(high, values[i])
    end
    if high - low > math.max(0.20, middle * 0.15) then return nil end
    return middle + 0.05
end

local function average(values)
    if table.getn(values) == 0 then return nil end
    local total, i = 0, nil
    for i = 1, table.getn(values) do total = total + values[i] end
    return total / table.getn(values)
end

local function minimum(values)
    if table.getn(values) == 0 then return nil end
    local value, i = values[1], nil
    for i = 2, table.getn(values) do value = math.min(value, values[i]) end
    return value
end

local function damagingFraction(values)
    if table.getn(values) == 0 then return nil end
    local damaging, i = 0, nil
    for i = 1, table.getn(values) do
        if values[i] > 0 then damaging = damaging + 1 end
    end
    return damaging / table.getn(values)
end

local function eligibleRetaliation(hitInfo, victimState)
    victimState = tonumber(victimState)
    if flag(hitInfo, 16) then return 0 end
    if victimState == 2 or victimState == 3 or victimState == 6
        or victimState == 7 or victimState == 8 then return 0 end
    return (victimState == 1 or victimState == 5) and 1 or 0
end

function H:Observe(attackerGuid, victimGuid, totalDamage, hitInfo,
    victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist, at)
    local victimUnit = friendlyUnit(victimGuid)
    if attackerGuid == nil or victimGuid == nil or owned(attackerGuid)
        or victimUnit == nil or not (XelAssist.Game.Hostiles
            and XelAssist.Game.Hostiles:ProvesGuid(attackerGuid)) then return false end
    hitInfo = tonumber(hitInfo)
    if hitInfo == nil or flag(hitInfo, 65536) then return false end
    at, totalDamage = tonumber(at), tonumber(totalDamage)
    if not at or not totalDamage or totalDamage < 0 then return false end
    local hand = flag(hitInfo, 4) and "off" or "main"
    local regime = mitigationRegime(victimUnit)
    if not regime then return false end
    local lane = laneFor(self, attackerGuid, victimGuid, hand)
    if lane.regime and not sameRegime(lane.regime, regime) then
        lane.intervals, lane.damages, lane.blockedAmounts, lane.eligibleHits,
            lane.lastAt = {}, {}, {}, {}, nil
    end
    if lane.lastAt then
        local interval = at - lane.lastAt
        if interval <= 0 or interval > 10 then
            lane.intervals, lane.damages, lane.eligibleHits = {}, {}, {}
        else boundedInsert(lane.intervals, interval, self.INTERVAL_SAMPLES) end
    end
    local absorbed = tonumber(totalAbsorb) or 0
    if absorbed <= 0 then
        boundedInsert(lane.damages, totalDamage, self.DAMAGE_SAMPLES)
    end
    boundedInsert(lane.eligibleHits,
        eligibleRetaliation(hitInfo, victimState), self.DAMAGE_SAMPLES)
    if tonumber(blockedAmount) and blockedAmount > 0 then
        boundedInsert(lane.blockedAmounts, blockedAmount, self.DAMAGE_SAMPLES)
    end
    lane.lastAt, lane.lastDamage, lane.hitInfo = at, totalDamage, hitInfo
    lane.victimState = tonumber(victimState)
    lane.blocked, lane.absorbed, lane.resisted = tonumber(blockedAmount) or 0,
        absorbed, tonumber(totalResist) or 0
    lane.interval, lane.expectedDamage = stableInterval(lane.intervals),
        average(lane.damages)
    lane.victimUnit, lane.regime = victimUnit, regime
    lane.generation = lane.generation + 1
    return true
end

local function retainedHostile(hostiles, guid)
    local i, key, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey and hostiles.byKey[key]
        if record and record.guid == guid and record.dead ~= true then return key end
    end
    return nil
end

local function retainedFriendly(friendlies, actors, guid)
    if actors and actors.player and actors.player.guid == guid then
        return "player", "player"
    end
    if actors and actors.pet and actors.pet.guid == guid then return "pet", "pet" end
    local i, key, record
    for i = 1, table.getn(friendlies and friendlies.order or {}) do
        key = friendlies.order[i]
        record = friendlies.byKey and friendlies.byKey[key]
        if record and record.guid == guid then
            return record.relation or "ally", record.unit
        end
    end
    return nil
end

function H:Snapshot(hostiles, friendlies, actors, at)
    local out, i = { lanes = {}, capped = false }, nil
    out.playerPushback = XelAssist.Game.Player
        and XelAssist.Game.Player.PushbackEvidence
        and XelAssist.Game.Player.PushbackEvidence:Snapshot() or nil
    if hostiles and hostiles.selectedKey and type(GetBlockChance) == "function"
        and XelAssist.Game.Geometry then
        local ok, chance = pcall(GetBlockChance)
        local geometry = XelAssist.Game.Geometry:Observe("target", "player")
        chance = ok and finite(chance) or nil
        if chance and chance >= 0 and chance <= 100
            and type(geometry.behind) == "boolean" then
            out.playerDefense = { exact = true,
                selectedKey = hostiles.selectedKey,
                selectedBehindPlayer = geometry.behind,
                blockChance = chance,
                source = "stock block chance and reverse UnitXP geometry" }
        end
    end
    at = tonumber(at)
    if not at then return out end
    for i = 1, table.getn(self.lanes) do
        local lane = self.lanes[i]
        local attackerKey = retainedHostile(hostiles, lane.attackerGuid)
        local victimKind, victimUnit = retainedFriendly(
            friendlies, actors, lane.victimGuid)
        local regime = victimUnit and mitigationRegime(victimUnit) or nil
        local interval, damage = tonumber(lane.interval), tonumber(lane.expectedDamage)
        local due = interval and lane.lastAt and lane.lastAt + interval or nil
        if attackerKey and victimKind and sameRegime(lane.regime, regime)
            and interval and damage and due and due > at
            and due - at <= interval * self.STALE_MULTIPLIER then
            table.insert(out.lanes, { attackerGuid = lane.attackerGuid,
                attackerKey = attackerKey, victimGuid = lane.victimGuid,
                victimKind = victimKind, hand = lane.hand,
                interval = interval, nextSwingIn = due - at,
                expectedDamage = damage, generation = lane.generation,
                damageProbability = damagingFraction(lane.damages),
                retaliationProbability = average(lane.eligibleHits),
                blockLowerBound = minimum(lane.blockedAmounts),
                blockSamples = table.getn(lane.blockedAmounts),
                mitigationRegime = regime,
                phaseKnown = true, magnitudeEstimated = true,
                source = "observed hostile post-mitigation white rounds" })
        end
    end
    return out
end

function H:Reset(reason)
    self.lanes, self.lastResetReason = {}, reason or "session reset"
end
