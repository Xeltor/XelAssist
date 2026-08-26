-- Ambient player off-hand rounds. This lane consumes only the frozen phase,
-- damage and target evidence attached at the root; it performs no live reads
-- during search and never replaces or arms a main-hand on-next-swing action.
XelAssist.Graph.PlayerOffhandSwings = {}
local O = XelAssist.Graph.PlayerOffhandSwings
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Targets = XelAssist.Graph.CompanionTargets
local PlayerRage = XelAssist.Graph.PlayerRage
local PlayerThreat = XelAssist.Graph.PlayerThreat

local MAX_EVENTS = 8
local READY_DELAY = 0.05
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local HunterRapidFire = XelAssist.Graph.HunterRapidFire
local DruidBarkskin = XelAssist.Graph.DruidBarkskin
local DruidBloodFrenzy = XelAssist.Graph.DruidBloodFrenzy

local WHITE_ACTION = { name = "Attack", actor = "player", facts = {
    kind = "damage", school = 0, melee = true, whiteAttack = true,
    weaponHand = "off", deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
} }
local WHITE_TOOLTIP = { school = 0 }

local function afterCastLocks(state, candidate, offset)
    offset = math.max(READY_DELAY, tonumber(offset) or 0)
    local currentEnd = state and state.playerCasting and math.max(0,
        tonumber(state.castRemaining) or 0) or 0
    if offset <= currentEnd then offset = currentEnd + READY_DELAY end
    local action = candidate and candidate.action
    local cast = math.max(0, tonumber(candidate and candidate.cast) or 0)
    if action and action.actor ~= "pet" and cast > 0 then
        local start = math.max(0, tonumber(candidate.wait) or 0)
        local finish = start + cast
        if offset >= start and offset <= finish then
            offset = finish + READY_DELAY
        end
    end
    return offset
end

local function addUnknown(candidate, reason)
    candidate.playerOffhandUnknowns =
        candidate.playerOffhandUnknowns or {}
    local index
    for index = 1, table.getn(candidate.playerOffhandUnknowns) do
        if candidate.playerOffhandUnknowns[index] == reason then return end
    end
    table.insert(candidate.playerOffhandUnknowns, reason)
end

local function targetIdentity(state, guid)
    local key, record = Targets:ForGuid(state, guid)
    if key and record and not Targets:ProvenDead(record) then
        return key, true, record
    end
    if not Targets:Hostiles(state) and guid ~= nil
        and guid == state.targetGUID then return nil, false, nil end
    return nil, nil, nil
end

local function geometry(state, record)
    local observed = record and record.geometry and record.geometry.player
    if observed then return observed end
    return { distance = state.targetDistance,
        distanceKind = state.targetDistanceKind }
end

local function legalGeometry(state, record)
    local observed = geometry(state, record)
    if type(observed.distance) ~= "number" then
        return nil, "player off-hand melee geometry"
    end
    local kind = observed.distanceKind or observed.source
    if kind ~= "hitbox" and kind ~= "combat reach" then
        return nil, "player off-hand melee distance provenance"
    end
    if observed.distance > 5 then return false, "range" end
    return true, nil
end

local function event(state, round, guid, key, targetLocal, offset, window)
    return { owner = "ongoing", kind = "playerOffhandSwing",
        priority = 50, offset = offset, windowEnd = window,
        targetGuid = guid, targetKey = key, targetLocal = targetLocal,
        applicationAt = (tonumber(state.time) or 0) + offset,
        phaseSource = round.phaseSource }
end

function O:Events(state, candidate)
    local events, attack = {}, state and state.playerAttack
    local round = attack and attack.offhandAttackRound
    if not (round and round.projectable and round.phaseKnown
        and round.verified and attack.active == true
        and round.targetGuid) then return events end
    local key, targetLocal, record = targetIdentity(
        state, round.targetGuid)
    if targetLocal == nil then return events end
    local window = math.max(0, tonumber(candidate and candidate.downtime) or 0)
    local allowed, reason = legalGeometry(state, record)
    if allowed ~= true then
        round.nextSwingIn = math.max(0,
            (tonumber(round.nextSwingIn) or 0) - window)
        if round.nextSwingIn <= 0 then round.readyHeld = true end
        if allowed == nil then addUnknown(candidate, reason) end
        return events
    end
    local interval = math.max(0.1, tonumber(round.interval) or 0)
    if interval <= 0.1 and not tonumber(round.interval) then return events end
    local offset = round.readyHeld and READY_DELAY
        or math.max(READY_DELAY, tonumber(round.nextSwingIn) or interval)
    offset = afterCastLocks(state, candidate, offset)
    local count = 0
    while offset <= window and count < MAX_EVENTS do
        table.insert(events, event(state, round, round.targetGuid,
            key, targetLocal, offset, window))
        local reset = state.classMechanicClass == "HUNTER" and HunterRapidFire
            and HunterRapidFire:MeleeIntervalAfter(
                state, "off", offset, interval)
            or RogueSlice and RogueSlice:IntervalAfter(
                state, "off", offset, interval) or interval
        reset = DruidBloodFrenzy and DruidBloodFrenzy:IntervalAfter(
            state, "off", offset, reset) or reset
        reset = DruidBarkskin
            and DruidBarkskin:MeleeInterval(state, reset) or reset
        offset = afterCastLocks(state, candidate, offset + reset)
        count = count + 1
    end
    round.readyHeld = nil
    round.nextSwingIn = math.max(READY_DELAY, offset - window)
    if count == MAX_EVENTS and offset <= window then
        table.insert(events, { owner = "ongoing",
            kind = "playerOffhandTimelineCap", priority = 55,
            offset = offset, windowEnd = window })
        round.projectable, round.phaseKnown = false, false
        addUnknown(candidate, "player off-hand swing timeline cap")
    end
    return events
end

function O:StillCurrent(state, entry)
    local attack = state and state.playerAttack
    local round = attack and attack.offhandAttackRound
    if not (attack and attack.active == true and round
        and round.targetGuid == entry.targetGuid) then return false end
    return Targets:Resolve(state, entry) ~= nil
end

local function refreshRecord(out, record)
    if record and State.RefreshHostileRecord then
        State:RefreshHostileRecord(out, record.key)
    end
end

local function markUnknown(target, record, reason)
    if record then
        record.healthExact = false
        record.playerOffhandDamageUnknown = true
        record.threat = record.threat or {}
        record.threat.playerDeltaExact = false
    else
        target.targetHealthExact = false
        target.playerOffhandDamageUnknown = true
    end
    target.playerOffhandUnknownReason = reason
end

local function applyKnown(target, record, rawPower)
    local decision = 1
    if XelAssist.Combat.Resistance then
        local estimate = XelAssist.Combat.Resistance:Estimate(
            WHITE_ACTION, "target", WHITE_TOOLTIP, target)
        decision = Effects:Decision(estimate, target, true)
    end
    local expected = math.max(0,
        (tonumber(rawPower) or 0) * (tonumber(decision) or 1))
    local dealt
    if record then
        if not (record.healthExact and tonumber(record.health)) then
            return nil
        end
        local before = tonumber(record.health)
        record.health = math.max(0, before - expected)
        dealt = before - record.health
        if record.health <= 0 then
            record.dead, record.projectedDefeated = true, true
        end
    else
        if not (target.targetHealthExact
            and tonumber(target.targetHealth)) then return nil end
        local before = tonumber(target.targetHealth)
        target.targetHealth = math.max(0, before - expected)
        dealt = before - target.targetHealth
        if target.targetHealth <= 0 then target.hostile = false end
    end
    if record and dealt > 0 then
        PlayerThreat:Add(record, target, "player", dealt, 0)
    end
    return dealt
end

function O:Apply(out, entry)
    if entry.kind == "playerOffhandTimelineCap" then return true end
    if not self:StillCurrent(out, entry) then return false end
    local target, _, record = Targets:Resolve(out, entry)
    if not target then return false end
    local round = out.playerAttack
        and out.playerAttack.offhandAttackRound
    local dealt = round and round.normalDamageKnown == true
        and tonumber(round.power)
        and applyKnown(target, record, round.power) or nil
    if dealt == nil then
        markUnknown(target, record,
            "ordinary player off-hand outcome magnitude unavailable")
    elseif PlayerRage then
        PlayerRage:GainFromWhite(out, dealt)
    end
    refreshRecord(out, record)
    return true
end

function O:CanChange(state)
    local attack = state and state.playerAttack
    local round = attack and attack.offhandAttackRound
    return attack and attack.active == true and round
        and round.projectable == true and round.targetGuid ~= nil
        or false
end
