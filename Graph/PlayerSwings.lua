-- Player main-hand rounds are ambient timeline events. A next-swing button
-- press only arms one target-pinned modifier; damage and threat occur when the
-- resolved melee clock reaches that target, never at input time.
XelAssist.Graph.PlayerSwings = {}
local S = XelAssist.Graph.PlayerSwings
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Targets = XelAssist.Graph.CompanionTargets
local PlayerRage = XelAssist.Graph.PlayerRage
local PlayerThreat = XelAssist.Graph.PlayerThreat
local Windfury = XelAssist.Graph.ShamanWindfuryTotem

local MAX_EVENTS = 8
local READY_DELAY = 0.05

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

local WHITE_ACTION = { name = "Attack", actor = "player", facts = {
    kind = "damage", school = 0, melee = true, whiteAttack = true,
    weaponHand = "main", deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
} }
local WHITE_TOOLTIP = { school = 0 }

local function onSwing(action, tooltip)
    local facts = action and action.facts or {}
    return facts.onNextSwing or facts.onSwing or tooltip
        and (tooltip.onNextSwing or tooltip.onSwing) and true or false
end

local function area(action, tooltip)
    local facts = action and action.facts or {}
    local topology = tooltip and tooltip.topology
    return facts.aoe or topology and topology.area and true or false
end

local function addUnknown(candidate, reason)
    candidate.playerSwingUnknowns = candidate.playerSwingUnknowns or {}
    local index
    for index = 1, table.getn(candidate.playerSwingUnknowns) do
        if candidate.playerSwingUnknowns[index] == reason then return end
    end
    table.insert(candidate.playerSwingUnknowns, reason)
end

function S:Is(action, tooltip)
    return onSwing(action, tooltip)
end

function S:ImpactDelay(state)
    local round = state and state.playerAttack and state.playerAttack.attackRound
    if not (round and round.projectable) then return nil end
    return afterCastLocks(state, nil, round.nextSwingIn)
end

function S:ExpectedWhite(state, targetGuid)
    local round = state and state.playerAttack and state.playerAttack.attackRound
    local raw = round and tonumber(round.power)
    if not raw or targetGuid == nil or round.targetGuid ~= targetGuid then
        return nil, nil
    end
    local decision = 1
    if XelAssist.Combat.Resistance then
        local estimate = XelAssist.Combat.Resistance:Estimate(
            WHITE_ACTION, "target", WHITE_TOOLTIP, state)
        decision = Effects:Decision(estimate, state, true)
    end
    decision = math.max(0, tonumber(decision) or 0)
    return raw * decision, decision
end

function S:Occupancy()
    return READY_DELAY
end

function S:Blocker(action, state, descriptor, tooltip)
    if not onSwing(action, tooltip) then return nil end
    if area(action, tooltip) then
        return "next-swing area recipients unresolved"
    end
    local attack = state and state.playerAttack
    if not attack then return "player melee state unavailable" end
    if attack.activeKnown ~= true or attack.active ~= true then
        return attack.active == false and "player melee attack inactive"
            or "player melee attack state uncertain"
    end
    local pending = attack.onSwing
    if pending and pending.occupied then return "next-swing action already armed" end
    local round = attack.attackRound
    if not (round and round.projectable and round.phaseKnown
        and round.verified) then
        return round and round.reason or "player swing phase unavailable"
    end
    local targetGuid = descriptor and descriptor.guid or state.targetGUID
    if targetGuid == nil or round.targetGuid ~= targetGuid then
        return "player swing target changed"
    end
    if (tonumber(round.nextSwingIn) or 0) <= READY_DELAY then
        return "player swing already resolving"
    end
    if round.normalDamageKnown ~= true or not tonumber(round.power) then
        return "player white-swing magnitude uncertain"
    end
    return nil
end

function S:Reserve(out, candidate)
    if not onSwing(candidate and candidate.action,
        candidate and candidate.tooltip) then return false end
    local attack, resource = out.playerAttack, tonumber(out.resource)
    if not attack then return false end
    if attack.onSwing and attack.onSwing.occupied then return false end
    local costKnown = candidate.costKnown ~= false
    local cost = costKnown and math.max(0, tonumber(candidate.cost) or 0) or nil
    local reserved = math.max(0, tonumber(out.playerResourceReserved) or 0)
    if not resource or cost and resource - reserved < cost then return false end
    out.playerResourceReserved = reserved
        + (cost or math.max(0, resource - reserved))
    attack.onSwing = { occupied = true, pending = true,
        exact = true, projected = true, phase = "graph-reserved",
        reservedCost = cost, costKnown = costKnown,
        source = "graph next-swing reservation" }
    return true
end

function S:Arm(out, candidate)
    if not onSwing(candidate and candidate.action,
        candidate and candidate.tooltip) then return false end
    local attack = out.playerAttack
    if not attack then return false end
    local pending = attack.onSwing
    if not (pending and pending.occupied and pending.projected) then
        return false
    end
    local facts = candidate.action.facts or {}
    pending.phase, pending.source = "graph-armed", "graph next-swing arm"
    pending.spellId, pending.name = candidate.action.spellId,
        candidate.action.name
    pending.targetGuid, pending.targetKey = candidate.targetGUID,
        candidate.targetKey
    pending.action, pending.tooltip = candidate.action, candidate.tooltip
    pending.rawPower, pending.cost = candidate.rawPower, candidate.cost
    pending.costKnown = candidate.costKnown ~= false
    pending.reservedCost = pending.costKnown and math.max(0,
        tonumber(pending.reservedCost) or tonumber(candidate.cost) or 0) or nil
    pending.threatMultiplier = tonumber(facts.threat) or 1
    return true
end

local function targetIdentity(state, guid)
    local key, record = Targets:ForGuid(state, guid)
    if key and record and not Targets:ProvenDead(record) then
        return key, true, record
    end
    if not Targets:Hostiles(state) and guid ~= nil and guid == state.targetGUID then
        return nil, false, nil
    end
    return nil, nil, nil
end

local function geometry(state, record)
    local observed = record and record.geometry and record.geometry.player
    if observed then return observed end
    return { distance = state.targetDistance, distanceKind = state.targetDistanceKind,
        lineOfSight = state.targetLineOfSight }
end

local function legalGeometry(state, record)
    local observed = geometry(state, record)
    if type(observed.distance) ~= "number" then
        return nil, "player melee geometry"
    end
    local kind = observed.distanceKind or observed.source
    if kind ~= "hitbox" and kind ~= "combat reach" then
        return nil, "player melee distance provenance"
    end
    if observed.distance > 5 then return false, "range" end
    return true, nil
end

local function event(state, round, guid, key, targetLocal, offset, window)
    return { owner = "ongoing", kind = "playerMainSwing", priority = 50,
        offset = offset, windowEnd = window, targetGuid = guid,
        targetKey = key, targetLocal = targetLocal,
        applicationAt = (tonumber(state.time) or 0) + offset,
        phaseSource = round.phaseSource }
end

function S:Events(state, candidate)
    local events, attack = {}, state and state.playerAttack
    local round = attack and attack.attackRound
    if not (round and round.projectable and attack.active == true
        and round.targetGuid) then return events end
    local key, targetLocal, record = targetIdentity(state, round.targetGuid)
    if targetLocal == nil then return events end
    local window = math.max(0, tonumber(candidate.downtime) or 0)
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
        table.insert(events, event(state, round, round.targetGuid, key,
            targetLocal, offset, window))
        offset, count = afterCastLocks(state, candidate, offset + interval),
            count + 1
    end
    round.readyHeld = nil
    round.nextSwingIn = math.max(READY_DELAY, offset - window)
    if count == MAX_EVENTS and offset <= window then
        table.insert(events, { owner = "ongoing", kind = "playerSwingTimelineCap",
            priority = 55, offset = offset, windowEnd = window })
        round.projectable, round.phaseKnown = false, false
        addUnknown(candidate, "player swing timeline cap")
    end
    return events
end

function S:StillCurrent(state, entry)
    local attack, round = state.playerAttack,
        state.playerAttack and state.playerAttack.attackRound
    if not (attack and attack.active == true and round and round.projectable
        and round.targetGuid == entry.targetGuid) then return false end
    return Targets:Resolve(state, entry) ~= nil
end

local function refreshRecord(out, record)
    if record and State.RefreshHostileRecord then
        State:RefreshHostileRecord(out, record.key)
    end
end

local function applyThreat(record, state, amount)
    if not record or amount <= 0 then return end
    PlayerThreat:Add(record, state, "player", amount)
end

local function applyKnown(target, record, action, tooltip, rawPower,
    threatMultiplier)
    if not (action and tooltip and tonumber(rawPower)) then return nil end
    local decision = 1
    if XelAssist.Combat.Resistance then
        local estimate = XelAssist.Combat.Resistance:Estimate(
            action, "target", tooltip, target)
        decision = Effects:Decision(estimate, target, true)
    end
    local expected = math.max(0, rawPower * (tonumber(decision) or 1))
    local dealt = expected
    if record then
        if record.healthExact and tonumber(record.health) then
            local before = tonumber(record.health)
            record.health = math.max(0, before - expected)
            dealt = before - record.health
            if record.health <= 0 then
                record.dead, record.projectedDefeated = true, true
            end
        else return nil end
    elseif target.targetHealthExact and tonumber(target.targetHealth) then
        local before = tonumber(target.targetHealth)
        target.targetHealth = math.max(0, before - expected)
        dealt = before - target.targetHealth
        if target.targetHealth <= 0 then target.hostile = false end
    else return nil end
    applyThreat(record, target,
        dealt * (tonumber(threatMultiplier) or 1))
    return dealt
end

local function commitCost(out, pending)
    local cost = tonumber(pending.reservedCost or pending.cost)
    out.playerResourceReserved = 0
    if pending.costKnown == false or not cost then
        out.resource, out.playerResourceExact = 0, false
        return false
    end
    local resource = tonumber(out.resource)
    if not resource or resource < cost then
        out.resource, out.playerResourceExact = 0, false
        return false
    end
    out.resource = resource - math.max(0, cost)
    return true
end

local function commitCooldown(out, pending, entry)
    local action, tooltip = pending.action, pending.tooltip or {}
    if not action then return end
    local at = tonumber(entry.applicationAt) or tonumber(out.time) or 0
    local ledger = XelAssist.Graph.CooldownLedger
    local function project(readyAt)
        if ledger and ledger:IsPrepared(out) and ledger:Supports(action) then
            return ledger:Project(out, action, readyAt)
        end
        out.readyAt[(action.actor or "player") .. ":" .. action.name] = readyAt
    end
    local cooldown = tonumber(tooltip.cooldown)
    if cooldown and cooldown > 0 then project(at + cooldown) end
    local facts = action.facts or {}
    local group = facts.cooldownGroup or tooltip.cooldownGroup
    local category = tonumber(tooltip.categoryCooldown)
    if group and category and category > 0 then
        if ledger and ledger:IsPrepared(out) then
            ledger:ProjectGroup(out, group, at + category)
        else out.readyAt["group:" .. group] = at + category end
    end
end

local function markUnknown(target, record, reason)
    if record then
        record.healthExact = false
        record.playerSwingDamageUnknown = true
        record.threat = record.threat or {}
        record.threat.playerDeltaExact = false
    else
        target.targetHealthExact = false
        target.playerSwingDamageUnknown = true
    end
    target.playerSwingUnknownReason = reason
end

function S:Apply(out, entry)
    if entry.kind == "playerSwingTimelineCap" then return true end
    if not self:StillCurrent(out, entry) then return false end
    local target, _, record, selected = Targets:Resolve(out, entry)
    if not target then return false end
    local pending = out.playerAttack and out.playerAttack.onSwing
    if pending and pending.occupied then
        commitCost(out, pending)
        commitCooldown(out, pending, entry)
        if pending.targetGuid ~= nil and pending.targetGuid ~= entry.targetGuid then
            markUnknown(target, record, "next-swing target changed")
        elseif applyKnown(target, record, pending.action, pending.tooltip,
            pending.rawPower, pending.threatMultiplier) == nil then
            markUnknown(target, record, "next-swing outcome magnitude unavailable")
        end
        out.playerAttack.onSwing = { occupied = false, pending = false,
            exact = true, phase = "graph-resolved",
            source = "projected player main-hand round" }
    else
        local round = out.playerAttack and out.playerAttack.attackRound
        local raw = round and round.normalDamageKnown == true
            and round.power or nil
        local windReason, windHandled, windDelivery
        if raw and Windfury then
            raw, windReason, windHandled, windDelivery =
                Windfury:WhiteSwingRawPower(out, entry.targetGuid, raw)
        end
        local dealt = raw and applyKnown(target, record, WHITE_ACTION,
            WHITE_TOOLTIP, raw, 1) or nil
        if dealt == nil then
            markUnknown(target, record, windReason
                or "ordinary player swing outcome magnitude unavailable")
        elseif PlayerRage then
            PlayerRage:GainFromWhite(out, dealt)
        end
        if windHandled and dealt ~= nil then
            Windfury:AfterWhiteSwing(out, entry.targetGuid, windDelivery)
        end
    end
    refreshRecord(out, record)
    return true
end
