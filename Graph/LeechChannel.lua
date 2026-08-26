-- Causal delivery for exact-cadence channels that convert hostile damage into
-- player healing. Spell identity is deliberately irrelevant: facts, installed
-- cadence, resistance evidence and graph health state define the transition.
XelAssist.Graph.LeechChannel = {}
local L = XelAssist.Graph.LeechChannel
local State = XelAssist.Graph.State
local PlayerThreat = XelAssist.Graph.PlayerThreat
local EPSILON = 0.0001
local MAX_TICKS = 40

local function clamp01(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function stopChannel(out, spellId)
    if spellId and out.playerCastSpellId
        and tonumber(out.playerCastSpellId) ~= tonumber(spellId) then return end
    out.playerCasting, out.playerChanneling = false, false
    out.playerCastName, out.playerCastSpellId = nil, nil
    out.playerCastTargetGUID, out.castRemaining = nil, 0
    out.channelCommitment, out.channelCommitmentClaimed = nil, nil
    if out.actorReadyAt then
        out.actorReadyAt.player = tonumber(out.time) or 0
    end
end

function L:Evidence(state, action, tooltip, cadence, targetMatches)
    local facts = action and action.facts or {}
    if not (facts.channel == true and facts.leech == true
        and targetMatches and cadence and tonumber(cadence.tickPower)) then
        return nil
    end
    local ratio = tonumber(tooltip and tooltip.leechRatio)
        or tonumber(facts.leechRatio) or 1
    if ratio < 0 then return nil end
    local factor, application, resistance = 1, 1, nil
    local effects = XelAssist.Graph.Effects
    if effects and effects.OverWindow and XelAssist.Combat.Resistance then
        local conditional
        conditional, application, resistance = effects:OverWindow(
            action, "target", tooltip, state, 0,
            math.max(0, tonumber(state.castRemaining) or 0),
            "periodic", true)
        if conditional ~= nil then factor = math.max(0, conditional) end
        if application ~= nil and clamp01(application) <= 0 then factor = 0 end
    end
    return { ratio = ratio, damageFactor = factor,
        applicationDelivery = clamp01(application), resistance = resistance,
        threatActor = facts.damageActor or facts.effectActor
            or action.actor or "player",
        threatFactor = math.max(0, tonumber(facts.threat) or 1),
        source = "exact channel cadence and conditional periodic delivery" }
end

function L:Plan(state, commitment, timing)
    local evidence = commitment and commitment.leechEvidence
    local cadence = commitment and commitment.cadence
    local ticks = math.max(0, math.min(MAX_TICKS,
        tonumber(timing and timing.remainingTicks) or 0))
    local interval = tonumber(timing and timing.interval)
    local nextTick = tonumber(timing and timing.nextTickIn)
    local rawTick = tonumber(cadence and cadence.tickPower)
    if not (evidence and interval and interval > 0 and nextTick
        and nextTick >= 0 and rawTick and rawTick >= 0) then return nil end

    local factor = math.max(0, tonumber(evidence.damageFactor) or 0)
    local deliveredTick = rawTick * factor
    local scheduled = ticks
    local naturalDuration = math.max(0,
        tonumber(state and state.castRemaining) or 0)
    if naturalDuration <= 0 and ticks > 0 then
        naturalDuration = nextTick + (ticks - 1) * interval
    end
    if deliveredTick <= EPSILON then
        scheduled = 0
    elseif state.targetHealthExact then
        local health = math.max(0, tonumber(state.targetHealth) or 0)
        scheduled = 0
        while scheduled < ticks
            and scheduled * deliveredTick + EPSILON < health do
            scheduled = scheduled + 1
        end
    end
    local rawDamage = rawTick * scheduled
    local damage = deliveredTick * scheduled
    local effectiveDamage = damage
    if state.targetHealthExact then
        effectiveDamage = math.min(damage,
            math.max(0, tonumber(state.targetHealth) or 0))
    end
    local missing = math.max(0, (tonumber(state.healthMax) or 0)
        - (tonumber(state.health) or 0))
    local healing = math.min(missing,
        effectiveDamage * math.max(0, tonumber(evidence.ratio) or 0))
    -- Delivery failure does not end the cast. A fully resisted channel still
    -- owns the player until its observed remaining duration expires. Only a
    -- proven lethal delivered tick may shorten that occupancy.
    local duration = naturalDuration
    if deliveredTick > EPSILON and scheduled < ticks then
        duration = scheduled > 0
            and nextTick + (scheduled - 1) * interval or 0
    end
    return { ticks = scheduled, availableTicks = ticks,
        interval = interval, nextTickIn = nextTick, duration = duration,
        rawTickDamage = rawTick, tickDamage = deliveredTick,
        rawDamage = rawDamage, damage = damage,
        effectiveDamage = effectiveDamage, effectiveHealing = healing,
        ratio = evidence.ratio, damageFactor = factor,
        applicationDelivery = evidence.applicationDelivery,
        threatActor = evidence.threatActor, threatFactor = evidence.threatFactor,
        resistance = evidence.resistance, targetGUID = commitment.targetGUID,
        spellId = commitment.spellId, source = evidence.source }
end

function L:Value(plan, remaining, base)
    if not plan then return base end
    return (tonumber(base) or 0) + plan.effectiveHealing * 5
        / math.max(0.5, tonumber(remaining) or 0.5)
end

function L:Events(out, candidate)
    local plan = candidate and candidate.leechChannel
    if not plan then return {} end
    local events, tick, offset = {}, nil, plan.nextTickIn
    for tick = 1, plan.ticks do
        table.insert(events, { owner = "ongoing", kind = "leechChannelTick",
            offset = offset, priority = 50, leech = plan, tick = tick })
        offset = offset + plan.interval
    end
    table.insert(events, { owner = "ongoing", kind = "leechChannelFinish",
        offset = plan.duration, priority = 90, leech = plan })
    return events
end

local function healPlayer(out, amount)
    local before = math.max(0, tonumber(out.health) or 0)
    local maximum = math.max(before, tonumber(out.healthMax) or before)
    local after = math.min(maximum, before + math.max(0, amount))
    out.health = after
    if out.actors and out.actors.player then
        out.actors.player.health = after
    end
    local friendly = State and State.FriendlyByUnit
        and State:FriendlyByUnit(out, "player") or nil
    if friendly then friendly.health = after end
    if friendly and out.friendlies
        and out.friendlies.primaryKey == friendly.key then
        out.healHealth = after
    end
    return after - before
end

function L:ApplyEvent(out, candidate, entry)
    local plan = entry and entry.leech
    if not plan then return false end
    if entry.kind == "leechChannelFinish" then
        stopChannel(out, plan.spellId)
        return true
    end
    if entry.kind ~= "leechChannelTick" then return false end
    local hostile = XelAssist.Graph.HostileEffects
    if not (hostile and hostile.ApplySelectedDamage) then return true end
    local record = State and State.ActiveHostile
        and State:ActiveHostile(out) or nil
    if not (record and record.guid ~= nil
        and record.guid == plan.targetGUID) then return true end
    local applied, dealt = hostile:ApplySelectedDamage(
        out, math.max(0, tonumber(plan.tickDamage) or 0))
    if not applied or not dealt or dealt <= 0 then return true end
    if PlayerThreat then
        PlayerThreat:Add(record, out, plan.threatActor,
            dealt * math.max(0, tonumber(plan.threatFactor) or 0))
    end
    healPlayer(out, dealt * math.max(0, tonumber(plan.ratio) or 0))
    return true
end
