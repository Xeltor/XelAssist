-- Graph-native health-funded channels.  Start payment and every completed tick
-- are causal events: hostile damage at the same timestamp resolves first, an
-- unaffordable upkeep tick ends the channel, and only paid ticks heal the pet.
XelAssist.Graph.HealthTransfer = {}
local H = XelAssist.Graph.HealthTransfer
local State = XelAssist.Graph.State
local EPSILON = 0.0001

local function exactData(data)
    if type(data) ~= "table" or data.exact ~= true then return nil end
    local initial = tonumber(data.initialHealthCost)
    local upkeep = tonumber(data.periodicHealthCost)
    local heal = tonumber(data.healPerTick)
    local interval = tonumber(data.interval)
    local ticks = tonumber(data.ticks)
    local duration = tonumber(data.duration)
    if not (initial and initial >= 0 and upkeep and upkeep > 0
        and heal and heal > 0 and interval and interval > 0
        and ticks and ticks > 0 and duration and duration > 0) then return nil end
    return data
end

local function dataFor(action, tooltip)
    if not (action and action.facts and action.facts.healthFundedChannel) then
        return nil
    end
    return exactData(tooltip and tooltip.healthTransfer)
end

local function petOf(state)
    return state and state.actors and state.actors.pet or nil
end

local function petMissing(state)
    local pet = petOf(state)
    if not pet then return 0 end
    return math.max(0, (tonumber(pet.healthMax) or 0)
        - (tonumber(pet.health) or 0))
end

local function playerGuid(state)
    local player = state and state.actors and state.actors.player
    if player and player.guid ~= nil then return player.guid end
    local friendly = State:FriendlyByUnit(state, "player")
    return friendly and friendly.guid or nil
end

local function incomingDamage(state, within)
    local events = XelAssist.Graph.HostileCastEvents
    local guid = playerGuid(state)
    if not (events and events.IncomingDamage and guid) then return 0, false end
    return events:IncomingDamage(state, guid, within)
end

local function usefulTicks(missing, heal, limit)
    local ticks, restored = 0, 0
    while ticks < limit and restored + EPSILON < missing do
        ticks, restored = ticks + 1, restored + heal
    end
    return ticks
end

local function affordableTicks(state, initial, upkeep, limit, wait,
    nextTick, interval)
    local startIncoming, exact = incomingDamage(state, wait)
    local remaining = (tonumber(state.health) or 0)
        - math.max(0, tonumber(startIncoming) or 0)
    if remaining <= initial + EPSILON then
        return 0, startIncoming, exact
    end
    remaining = remaining - initial
    local ticks, priorIncoming = 0, math.max(0, startIncoming or 0)
    local totalIncoming, paidExact = priorIncoming, exact
    while ticks < limit do
        local at = math.max(0, tonumber(wait) or 0)
            + nextTick + ticks * interval
        totalIncoming, exact = incomingDamage(state, at)
        totalIncoming = math.max(priorIncoming,
            tonumber(totalIncoming) or priorIncoming)
        remaining = remaining - (totalIncoming - priorIncoming)
        local throughExact = paidExact and exact
        if remaining <= upkeep + EPSILON then break end
        remaining, priorIncoming = remaining - upkeep, totalIncoming
        paidExact = throughExact
        ticks = ticks + 1
    end
    return ticks, priorIncoming, paidExact
end

local function availableTicks(remaining, nextTick, interval, limit)
    local ticks, at = 0, nextTick
    while ticks < limit and at <= remaining + EPSILON do
        ticks, at = ticks + 1, at + interval
    end
    return ticks
end

local function plannedDuration(nextTick, interval, ticks)
    if ticks <= 0 then return 0 end
    return nextTick + (ticks - 1) * interval
end

local function buildPlan(state, data, initial, nextTick, available, missing,
    wait, continuation)
    local heal, upkeep = data.healPerTick, data.periodicHealthCost
    local useful = usefulTicks(missing, heal, available)
    if useful <= 0 then return nil, "companion at full health" end
    local safe, incoming, incomingExact = affordableTicks(state, initial,
        upkeep, useful, wait, nextTick, data.interval)
    local planned = math.min(useful, safe)
    if planned <= 0 then return nil, "health" end
    local duration = plannedDuration(nextTick, data.interval, planned)
    local raw = heal * planned
    local effective = math.min(raw, missing)
    local healthCost = initial + upkeep * planned
    return { data = data, start = not continuation,
        continuation = continuation and true or false,
        nextTickIn = nextTick, plannedTicks = planned,
        availableTicks = available, usefulTicks = useful,
        plannedDuration = duration, fullDuration = data.duration,
        rawHealing = raw, effectiveHealing = effective,
        initialHealthCost = initial, periodicHealthCost = upkeep,
        healthCost = healthCost, incomingDamage = incoming,
        incomingExact = incomingExact, source = data.source }
end

function H:Is(action, tooltip)
    return dataFor(action, tooltip) ~= nil
end

function H:Blocker(action, state, tooltip)
    if not (action and action.facts and action.facts.healthFundedChannel) then
        return nil
    end
    local data = dataFor(action, tooltip)
    if not data then return "health transfer evidence unknown" end
    local pet = petOf(state)
    if not pet or pet.dead or (tonumber(pet.health) or 0) <= 0 then
        return "pet"
    end
    local plan, reason = buildPlan(state, data, data.initialHealthCost,
        data.interval, data.ticks, petMissing(state), 0, false)
    if not plan then return reason end
    return nil
end

function H:Prepare(context)
    local data = dataFor(context.action, context.tooltip)
    if not data then return false, "health transfer evidence unknown" end
    local plan, reason = buildPlan(context.state, data, data.initialHealthCost,
        data.interval, data.ticks, petMissing(context.state),
        context.wait, false)
    if not plan then return false, reason or "health" end
    context.healthTransfer = plan
    context.cast, context.occupancy = plan.plannedDuration,
        plan.plannedDuration
    context.downtime = math.max(0.05, tonumber(context.gcd) or 0,
        plan.plannedDuration)
    context.advanceDowntime = math.max(0, tonumber(context.wait) or 0)
        + context.downtime
    context.power, context.expectedPower = plan.rawHealing, plan.rawHealing
    context.effectivePower = plan.effectiveHealing
    context.estimated = false
    context.powerEvidence = { exact = true, complete = true,
        source = data.source }
    context.cost, context.costKnown = 0, true
    return true
end

function H:ContinuationPlan(state, data, remaining, total)
    data = exactData(data)
    if not data then return nil end
    remaining = math.max(0, tonumber(remaining) or 0)
    total = math.max(remaining, tonumber(total) or tonumber(data.duration) or 0)
    local elapsed = math.max(0, total - remaining)
    local timing = XelAssist.Game.SpellTiming
    local nextTick = timing and timing.Next
        and timing:Next(data.interval, elapsed) or data.interval
    local available = availableTicks(remaining, nextTick,
        data.interval, data.ticks)
    if available <= 0 then return nil end
    local plan = buildPlan(state, data, 0, nextTick, available,
        petMissing(state), 0, true)
    if plan then
        plan.channelRemaining = remaining
        plan.channelTotal = total
    end
    return plan
end

function H:Value(state, plan)
    if not plan then return 0 end
    local duration = math.max(0.5, plan.plannedDuration)
    local effective, healthCost = plan.effectiveHealing, plan.healthCost
    local maximum = math.max(1, tonumber(state.healthMax) or 0)
    local post = math.max(0, (tonumber(state.health) or 0)
        - healthCost - plan.incomingDamage)
    local postFraction = post / maximum
    local risk = healthCost / maximum * 900
    if postFraction < 0.35 then risk = risk + (0.35 - postFraction) * 3000 end
    if state.hasAggro and not state.tank then risk = risk * 1.2 end
    local overheal = math.max(0, plan.rawHealing - effective)
    return effective * 5 / duration
        + effective / math.max(1, healthCost) * 55
        - risk - overheal * 1.5
end

function H:Score(context)
    local plan = context.healthTransfer
    if not plan then return false end
    context.effectivePower = plan.effectiveHealing
    context.value = self:Value(context.state, plan)
    context.reason = plan.rawHealing > plan.effectiveHealing * 1.35
        and "limits companion overhealing and health loss"
        or "transfers safe health to the companion"
    return true
end

local function stopChannel(out)
    out.playerCasting, out.playerChanneling = false, false
    out.playerCastName, out.playerCastSpellId = nil, nil
    out.playerCastTargetGUID, out.castRemaining = nil, 0
    out.channelCommitment, out.channelCommitmentClaimed = nil, nil
    if out.actorReadyAt then
        out.actorReadyAt.player = tonumber(out.time) or 0
    end
end

local function setPlayerHealth(out, health)
    health = math.max(0, health)
    out.health = health
    local actor = out.actors and out.actors.player
    if actor then actor.health = health end
    local friendly = State:FriendlyByUnit(out, "player")
    if friendly then friendly.health = health end
    if friendly and out.friendlies
        and out.friendlies.primaryKey == friendly.key then
        out.healHealth = health
    end
end

local function setPetHealth(out, health)
    local pet = petOf(out)
    if not pet then return 0 end
    local before = tonumber(pet.health) or 0
    pet.health = math.min(tonumber(pet.healthMax) or before, health)
    local friendly = State:FriendlyByUnit(out, "pet")
    if friendly then friendly.health = pet.health end
    if friendly and out.friendlies
        and out.friendlies.primaryKey == friendly.key then
        out.healHealth = pet.health
    end
    if XelAssist.Graph.CompanionCommandPolicy then
        XelAssist.Graph.CompanionCommandPolicy:UpdateRecovery(pet)
    end
    return math.max(0, pet.health - before)
end

function H:Events(out, source, candidate)
    local plan = candidate and candidate.healthTransfer
    if not plan then return {} end
    local events, wait = {}, math.max(0, tonumber(candidate.wait) or 0)
    if plan.start then
        table.insert(events, { owner = "healthTransfer",
            kind = "healthTransferStart", offset = wait, priority = 20 })
    end
    local tick, offset = nil, wait + plan.nextTickIn
    for tick = 1, plan.plannedTicks do
        table.insert(events, { owner = "healthTransfer",
            kind = "healthTransferTick", offset = offset,
            priority = 16, tick = tick })
        offset = offset + plan.data.interval
    end
    return events
end

function H:ApplyEvent(out, candidate, context, entry)
    local plan = candidate and candidate.healthTransfer
    if not (plan and entry) then return false end
    if entry.kind == "healthTransferStart" then
        local cost = plan.initialHealthCost
        if (tonumber(out.health) or 0) <= cost + EPSILON then
            candidate.healthTransferInterrupted = true
            stopChannel(out)
            return false
        end
        setPlayerHealth(out, out.health - cost)
        out.playerCasting, out.playerChanneling = true, true
        out.playerCastName = candidate.action.name
        out.playerCastSpellId = candidate.action.spellId
        local pet = petOf(out)
        out.playerCastTargetGUID = candidate.targetGUID
            or candidate.castTargetGUID or pet and pet.guid
        out.castRemaining = plan.fullDuration
        out.channelCommitment = {
            name = candidate.action.name, spellId = candidate.action.spellId,
            targetGUID = out.playerCastTargetGUID,
            targetMatches = false, selfChannel = false,
            friendlyKey = candidate.targetKey,
            friendlyUnit = "pet", remaining = plan.fullDuration,
            total = plan.fullDuration, power = plan.data.totalHealing,
            kind = "petHeal", known = true, estimated = false,
            healthTransferData = plan.data,
        }
        out.channelCommitmentClaimed = nil
        context.healthTransferStarted = true
        candidate.healthTransferStarted = true
        candidate.healthTransferHealthSpent = cost
        return true
    end
    if entry.kind ~= "healthTransferTick"
        or candidate.healthTransferInterrupted then return false end
    local pet = petOf(out)
    local upkeep = plan.periodicHealthCost
    if not pet or pet.dead or (tonumber(pet.health) or 0) <= 0
        or (tonumber(out.health) or 0) <= upkeep + EPSILON then
        candidate.healthTransferInterrupted = true
        stopChannel(out)
        return false
    end
    setPlayerHealth(out, out.health - upkeep)
    local effective = setPetHealth(out,
        (tonumber(pet.health) or 0) + plan.data.healPerTick)
    candidate.healthTransferAppliedTicks =
        (candidate.healthTransferAppliedTicks or 0) + 1
    candidate.healthTransferHealthSpent =
        (candidate.healthTransferHealthSpent or 0) + upkeep
    candidate.healthTransferEffectiveHealing =
        (candidate.healthTransferEffectiveHealing or 0) + effective
    return true
end

function H:CanResolve(candidate)
    local plan = candidate and candidate.healthTransfer
    if not plan then return true end
    if candidate.healthTransferInterrupted then return false end
    return not plan.start or candidate.healthTransferStarted == true
end

function H:Finish(out, candidate)
    if not (candidate and candidate.healthTransfer) then return false end
    if candidate.healthTransferInterrupted
        or (tonumber(out.castRemaining) or 0) <= EPSILON then
        stopChannel(out)
    end
    return true
end
