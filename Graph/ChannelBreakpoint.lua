-- Marginal continuation for an already-active exact-cadence channel. Each
-- plan waits only until the next completed tick, then lets graph search choose
-- again. Cadence and phase are frozen by ChannelCommitment before search; this
-- module performs no live reads and knows no class, spell name, or rotation.
XelAssist.Graph.ChannelBreakpoint = {}
local B = XelAssist.Graph.ChannelBreakpoint
local State = XelAssist.Graph.State
local Cadence = XelAssist.Graph.ChannelCadence

B.EXACT_CADENCE_SOURCE, B.ACCELERATED_CADENCE_SOURCE = Cadence.DBC, Cadence.ACCELERATED_ARCANA
B.MAX_TICKS = 40

local EPSILON = 0.0001

local function nonnegative(value)
    value = tonumber(value)
    if value == nil or value < 0 or value ~= value
        or value == math.huge then return nil end
    return value
end

local function validGuid(guid)
    return type(guid) == "string" and guid ~= ""
        and guid ~= "0x000000000" and guid ~= "0x0000000000000000"
end

local function sameSpell(state, commitment)
    local live, planned = tonumber(state and state.playerCastSpellId),
        tonumber(commitment and commitment.spellId)
    return live ~= nil and planned ~= nil and live == planned
end

local function retainedChannel(state, commitment)
    local remaining = nonnegative(state and state.castRemaining)
    if type(state) ~= "table" or type(commitment) ~= "table"
        or state.playerChanneling ~= true or not remaining
        or remaining <= EPSILON or commitment.known ~= true
        or not sameSpell(state, commitment) then
        return nil, "exact active channel unavailable"
    end
    if commitment.healthTransferData then
        return nil, "health-funded channel requires its causal owner"
    end
    if not commitment.selfChannel then
        if not validGuid(commitment.targetGUID)
            or state.playerCastTargetGUID ~= commitment.targetGUID then
            return nil, "channel recipient identity unavailable"
        end
    end
    return remaining, nil
end

local function phase(cadence, remaining)
    if type(cadence) ~= "table"
        or not Cadence:Exact(cadence.source) then
        return nil, "exact channel cadence unavailable"
    end
    local interval = nonnegative(cadence.interval)
    local total = nonnegative(cadence.total)
    local rootRemaining = nonnegative(cadence.rootRemaining)
    local rootNext = nonnegative(cadence.rootNextTickIn)
    local tickPower = nonnegative(cadence.tickPower)
    local totalTicks = nonnegative(cadence.totalTicks)
    if not interval or interval <= 0 or not total or total <= 0
        or rootRemaining == nil or rootNext == nil or rootNext <= 0
        or rootNext > interval + EPSILON or tickPower == nil or not totalTicks
        or totalTicks <= 0 or totalTicks > B.MAX_TICKS
        or totalTicks ~= math.floor(totalTicks)
        or math.abs(totalTicks * interval - total) > EPSILON
        or rootRemaining > total + EPSILON
        or remaining > rootRemaining + EPSILON then
        return nil, "exact channel cadence unavailable"
    end
    local progressed = rootRemaining - remaining
    local nextTick = rootNext - math.max(0, progressed)
    local guard = 0
    -- SpellTiming may freeze a tick only 0.0001s away.  Preserve it at the
    -- root, but once graph time has advanced through that boundary, skip it.
    while progressed > 0 and nextTick <= EPSILON
        and guard < B.MAX_TICKS do
        nextTick, guard = nextTick + interval, guard + 1
    end
    if guard >= B.MAX_TICKS or nextTick > remaining + EPSILON then
        return nil, "no remaining completed channel tick"
    end
    local remainingTicks, at = 0, nextTick
    while at <= remaining + EPSILON
        and remainingTicks < B.MAX_TICKS do
        remainingTicks, at = remainingTicks + 1, at + interval
    end
    if remainingTicks <= 0 or at <= remaining + EPSILON then
        return nil, "channel tick budget exceeded"
    end
    return { interval = interval, nextTickIn = nextTick,
        tickPower = tickPower, remainingTicks = remainingTicks,
        remainingAfter = math.max(0, remaining - nextTick),
        remainingTicksAfter = remainingTicks - 1 }, nil
end

local function exactTarget(state, commitment, projection)
    local view = projection or state
    if commitment.targetMatches ~= true
        or view.targetGUID ~= commitment.targetGUID
        or projection and projection.targetAlive == false then
        return nil, nil, "channel hostile identity unavailable"
    end
    local health = nonnegative(view.targetHealth)
    if view.targetHealthExact == true and health == nil then
        return nil, nil, "channel hostile health unavailable"
    end
    return health, view.targetHealthExact == true, nil
end

local function friendlyTarget(state, commitment, projection)
    if projection then
        local health, maximum = nonnegative(projection.friendlyHealth),
            nonnegative(projection.friendlyHealthMax)
        if projection.friendlyKey ~= commitment.friendlyKey
            or projection.friendlyGUID ~= commitment.targetGUID
            or projection.friendlyHealthExact ~= true
            or projection.friendlyDead == true or health == nil
            or maximum == nil or maximum <= 0 or health > maximum then
            return nil, "channel friendly identity unavailable"
        end
        return { key = projection.friendlyKey,
            guid = projection.friendlyGUID, health = health,
            healthMax = maximum }, nil
    end
    if not (State and type(State.FriendlyByKey) == "function"
        and commitment.friendlyKey ~= nil) then
        return nil, "channel friendly identity unavailable"
    end
    local record = State:FriendlyByKey(state, commitment.friendlyKey)
    local exact = record and record.healthExact
    if exact == nil and record then exact = record.exact end
    local health, maximum = nonnegative(record and record.health),
        nonnegative(record and record.healthMax)
    if not record or record.guid ~= commitment.targetGUID or exact ~= true
        or record.dead == true or health == nil or maximum == nil
        or maximum <= 0 or health > maximum then
        return nil, "channel friendly identity unavailable"
    end
    return { key = commitment.friendlyKey, guid = record.guid,
        health = health, healthMax = maximum }, nil
end

local function damageEffect(state, commitment, raw, projection)
    local health, exact, reason = exactTarget(state, commitment, projection)
    if reason then return nil, reason end
    if exact and health <= 0 then return nil, "channel recipient defeated" end
    local evidence = commitment.damageEvidence
    local factor = evidence and nonnegative(evidence.damageFactor) or 1
    local delivery = evidence and nonnegative(
        evidence.applicationDelivery) or 1
    if factor == nil or delivery == nil or delivery > 1 then
        return nil, "channel damage evidence unavailable"
    end
    local damage = raw * factor
    if exact then damage = math.min(damage, health) end
    return { damage = damage, effectivePower = damage,
        applicationDelivery = delivery,
        threatActor = evidence and evidence.threatActor
            or commitment.damageActor,
        threatFactor = evidence and evidence.threatFactor
            or commitment.threatFactor,
        estimated = not exact or evidence and evidence.estimated == true }, nil
end

local function leechEffect(state, commitment, raw, projection)
    local evidence = commitment.leechEvidence
    local health, exact, reason = exactTarget(
        state, commitment, projection)
    if reason then return nil, reason end
    if type(evidence) ~= "table" then return nil, "leech evidence unavailable" end
    local factor = nonnegative(evidence.damageFactor)
    local ratio = nonnegative(evidence.ratio)
    local delivery = nonnegative(evidence.applicationDelivery)
    local view = projection or state
    local playerHealth, playerMaximum = nonnegative(view.health),
        nonnegative(view.healthMax)
    if factor == nil or ratio == nil or delivery == nil or delivery > 1
        or playerHealth == nil or playerMaximum == nil
        or playerMaximum <= 0 or playerHealth > playerMaximum then
        return nil, "leech evidence unavailable"
    end
    if exact and health <= 0 then return nil, "channel recipient defeated" end
    local damage = raw * factor
    if exact then damage = math.min(damage, health) end
    local healing = math.min(playerMaximum - playerHealth, damage * ratio)
    return { damage = damage, healing = healing,
        effectivePower = damage, applicationDelivery = delivery,
        leechRatio = ratio, estimated = not exact,
        threatActor = evidence.threatActor,
        threatFactor = evidence.threatFactor }, nil
end

local function friendlyEffect(state, commitment, raw, projection)
    local target, reason = friendlyTarget(state, commitment, projection)
    if not target then return nil, reason end
    local healing = math.min(raw, target.healthMax - target.health)
    return { healing = healing, effectivePower = healing,
        friendlyKey = target.key, friendlyGUID = target.guid,
        estimated = false }, nil
end

local function resourceEffect(state, raw, projection)
    local view = projection or state
    local current, maximum = nonnegative(view.resource),
        nonnegative(view.resourceMax)
    if view.playerResourceExact ~= true or current == nil or maximum == nil
        or maximum <= 0 or current > maximum then
        return nil, "channel resource evidence unavailable"
    end
    local gain = math.min(raw, maximum - current)
    return { resourceGain = gain, effectivePower = gain,
        estimated = false }, nil
end

local function effect(state, commitment, raw, projection)
    if commitment.leechEvidence then
        return leechEffect(state, commitment, raw, projection)
    end
    local kind = commitment.kind
    if kind == "damage" or kind == "builder" or kind == "dot" then
        return damageEffect(state, commitment, raw, projection)
    elseif kind == "heal" or kind == "hot" or kind == "petHeal" then
        return friendlyEffect(state, commitment, raw, projection)
    elseif kind == "resource" then
        return resourceEffect(state, raw, projection)
    end
    return nil, "unsupported channel effect"
end

local function marginalValue(projected)
    return (tonumber(projected.damage) or 0) * 4
        + (tonumber(projected.healing) or 0) * 5
        + (tonumber(projected.resourceGain) or 0) * 4
end

function B:Plan(state, commitment, projection)
    local remaining, reason = retainedChannel(state, commitment)
    if not remaining then return nil, reason end
    local timing
    timing, reason = phase(commitment.cadence, remaining)
    if not timing then return nil, reason end
    local projected
    projected, reason = effect(
        state, commitment, timing.tickPower, projection)
    if not projected then return nil, reason end
    local now = nonnegative(state.time)
    if now == nil then return nil, "channel graph time unavailable" end
    local value = marginalValue(projected)
    return { spellId = commitment.spellId,
        targetGUID = commitment.targetGUID,
        friendlyKey = projected.friendlyKey,
        friendlyGUID = projected.friendlyGUID,
        kind = commitment.kind, duration = timing.nextTickIn,
        landsAt = now + timing.nextTickIn,
        interval = timing.interval, ticks = 1,
        remainingBefore = remaining,
        remainingAfter = timing.remainingAfter,
        remainingTicksBefore = timing.remainingTicks,
        remainingTicksAfter = timing.remainingTicksAfter,
        completesChannel = timing.remainingTicksAfter == 0,
        rawPower = timing.tickPower,
        effectivePower = projected.effectivePower,
        damage = projected.damage, healing = projected.healing,
        resourceGain = projected.resourceGain,
        applicationDelivery = projected.applicationDelivery,
        leechRatio = projected.leechRatio,
        threatActor = projected.threatActor,
        threatFactor = projected.threatFactor,
        value = value,
        valueRate = value / math.max(0.05, timing.nextTickIn),
        estimated = commitment.estimated == true
            or projected.estimated == true,
        frozen = true,
        reason = "preserves exactly one completed channel tick",
        source = "frozen exact-cadence channel breakpoint" }, nil
end

function B:DamageEvidence(state, action, tooltip, cadence, targetMatches)
    local facts = action and action.facts or {}
    local kind = facts.kind
    if not (targetMatches and cadence and (kind == "damage"
        or kind == "builder" or kind == "dot")) then return nil end
    local effects = XelAssist.Graph.Effects
    if not (effects and type(effects.OverWindow) == "function") then
        return { damageFactor = 1, applicationDelivery = 1,
            estimated = true, threatActor = facts.damageActor
                or facts.effectActor or action.actor or "player",
            threatFactor = math.max(0, tonumber(facts.threat) or 1),
            source = "channel delivery unavailable" }
    end
    local factor, delivery, resistance = effects:OverWindow(
        action, "target", tooltip, state, 0,
        math.max(0, tonumber(state.castRemaining) or 0),
        "periodic", true)
    factor, delivery = nonnegative(factor), nonnegative(delivery)
    local unknown = factor == nil or delivery == nil or delivery > 1
    if unknown then factor, delivery, resistance = 1, 1, nil end
    if delivery <= 0 then factor = 0 end
    return { damageFactor = factor, applicationDelivery = delivery,
        resistance = resistance, estimated = unknown
            or resistance and resistance.unknown,
        threatActor = facts.damageActor or facts.effectActor
            or action.actor or "player",
        threatFactor = math.max(0, tonumber(facts.threat) or 1),
        source = "frozen conditional periodic delivery" }
end

local function cloneAction(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function B:Candidate(state, commitment, template)
    local initial, reason = self:Plan(state, commitment)
    if not initial then return nil, reason end
    local action = cloneAction(template)
    action.name = "Continue " .. tostring(commitment.name)
    local friendly = commitment.friendlyUnit ~= nil
    local candidate = { action = action, value = initial.value,
        reason = initial.reason,
        target = commitment.targetMatches and "target"
            or friendly and commitment.friendlyUnit or "player",
        targetKey = commitment.targetMatches and state.targetGUID
            or friendly and (commitment.friendlyKey
                or commitment.friendlyUnit) or "player",
        targetGUID = commitment.targetMatches and state.targetGUID
            or friendly and commitment.targetGUID or nil,
        targetRelation = commitment.targetMatches and "hostile"
            or friendly and commitment.friendlyUnit == "pet" and "pet"
            or friendly and "ally" or "self",
        targetSource = "active channel", cost = 0, costKnown = true,
        cast = initial.duration, wait = 0, occupancy = initial.duration,
        downtime = initial.duration, valueDowntime = initial.duration,
        gcd = 0, normalGcd = false, actionStart = state.time,
        tooltip = { cost = 0, cast = initial.duration, gcd = 0,
            source = "active channel breakpoint" },
        power = initial.rawPower, rawPower = initial.rawPower,
        effectivePower = initial.effectivePower,
        effectDelivery = initial.applicationDelivery or 1,
        estimated = initial.estimated, channelCommitment = commitment,
        channelBreakpoint = initial }
    local timeline = XelAssist.Graph.Timeline
    local forecast = timeline and timeline.BeforeAction
        and timeline:BeforeAction(state, candidate) or nil
    local projection = forecast and forecast.channelProjection
    if not projection then return nil, "channel timeline evidence unavailable" end
    local plan
    plan, reason = self:Plan(state, commitment, projection)
    if not plan then return nil, reason end
    candidate.value, candidate.reason = plan.value, plan.reason
    candidate.power, candidate.rawPower = plan.rawPower, plan.rawPower
    candidate.effectivePower = plan.effectivePower
    candidate.effectDelivery = plan.applicationDelivery or 1
    candidate.estimated, candidate.channelBreakpoint = plan.estimated, plan
    return candidate, nil
end

local function clearChannel(out)
    out.playerCasting, out.playerChanneling = false, false
    out.playerCastName, out.playerCastSpellId = nil, nil
    out.playerCastTargetGUID, out.castRemaining = nil, 0
    out.channelCommitment, out.channelCommitmentClaimed = nil, nil
    if out.actorReadyAt then
        out.actorReadyAt.player = tonumber(out.time) or 0
    end
end

local function exactDeliveryState(out, plan, commitment)
    if not (plan and plan.frozen == true and commitment
        and tonumber(plan.spellId) == tonumber(commitment.spellId)
        and tonumber(out.playerCastSpellId) == tonumber(plan.spellId)
        and math.abs((tonumber(out.time) or -1) - plan.landsAt) <= EPSILON
        and math.abs((tonumber(out.castRemaining) or -1)
            - plan.remainingAfter) <= EPSILON) then return false end
    if plan.remainingAfter > EPSILON and out.playerChanneling ~= true then
        return false
    end
    if not commitment.selfChannel
        and out.playerCastTargetGUID ~= plan.targetGUID then return false end
    return true
end

local function healFriendly(out, commitment, amount)
    local target = commitment.friendlyKey and State:FriendlyByKey(
        out, commitment.friendlyKey) or nil
    local exact = target and target.healthExact
    if exact == nil and target then exact = target.exact end
    if not (target and target.guid == commitment.targetGUID
        and exact == true and target.dead ~= true) then return false end
    local before = tonumber(target.health) or 0
    target.health = math.min(tonumber(target.healthMax) or before,
        before + math.max(0, tonumber(amount) or 0))
    if commitment.friendlyUnit == "player" then
        out.health = target.health
        if out.actors and out.actors.player then
            out.actors.player.health = target.health
        end
    elseif commitment.friendlyUnit == "pet" and out.actors
        and out.actors.pet and out.actors.pet.guid == target.guid then
        out.actors.pet.health = target.health
        local policy = XelAssist.Graph.CompanionCommandPolicy
        if policy then policy:UpdateRecovery(out.actors.pet) end
    end
    return true
end

function B:Apply(out, candidate)
    local plan = candidate and candidate.channelBreakpoint
    local commitment = candidate and candidate.channelCommitment
    if not exactDeliveryState(out, plan, commitment) then return false end
    if plan.damage ~= nil then
        if commitment.leechEvidence and XelAssist.Graph.LeechChannel then
            XelAssist.Graph.LeechChannel:ApplyEvent(out, candidate, {
                kind = "leechChannelTick", leech = {
                    targetGUID = plan.targetGUID, spellId = plan.spellId,
                    tickDamage = plan.damage, ratio = plan.leechRatio,
                    threatActor = plan.threatActor,
                    threatFactor = plan.threatFactor } })
        else
            local hostile, record = XelAssist.Graph.HostileEffects, State
                and State.ActiveHostile and State:ActiveHostile(out) or nil
            local applied, dealt
            if hostile then applied, dealt = hostile:ApplySelectedDamage(
                out, math.max(0, tonumber(plan.damage) or 0)) end
            if applied and dealt and dealt > 0 and record
                and record.guid == plan.targetGUID
                and XelAssist.Graph.PlayerThreat then
                XelAssist.Graph.PlayerThreat:Add(record, out,
                    plan.threatActor or "player", dealt
                        * math.max(0, tonumber(plan.threatFactor) or 1))
            end
        end
    elseif plan.healing ~= nil then
        healFriendly(out, commitment, plan.rawPower)
    elseif plan.resourceGain ~= nil then
        out.resource = math.min(tonumber(out.resourceMax) or 0,
            (tonumber(out.resource) or 0) + plan.rawPower)
        if out.actors and out.actors.player then
            out.actors.player.resource = out.resource
        end
    end
    if plan.completesChannel then clearChannel(out)
    else out.channelCommitmentClaimed = nil end
    return true
end
