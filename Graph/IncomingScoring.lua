-- Recommendation value derived from exact-recipient hostile casts. This stays
-- separate from generic potency scoring so unsupported evidence has one gate.
XelAssist.Graph.IncomingScoring = {}
local I = XelAssist.Graph.IncomingScoring
local MageManaShieldScoring = XelAssist.Graph.MageManaShieldScoring

local function recipientGuid(context)
    local descriptor = context and context.descriptor
    local guid = descriptor and descriptor.guid
    if not guid and context and context.target == "player" then
        guid = context.state.actors and context.state.actors.player
            and context.state.actors.player.guid
    end
    return guid
end

local function applicationOffset(context)
    return math.max(0, tonumber(context and context.wait) or 0)
        + math.max(0, tonumber(context and context.cast) or 0)
end

local function incoming(context, window, strictlyAfter)
    local events = XelAssist.Graph.HostileCastEvents
    if not events then return 0 end
    return events:IncomingDamage(
        context.state, recipientGuid(context), window, strictlyAfter)
end

function I:AdjustTargetNeed(context)
    local amount = incoming(context, applicationOffset(context))
    local maximum = context.friendly and context.friendly.healthMax
        or context.target == "player" and context.state.healthMax or 0
    context.incomingBeforeHeal = amount
    context.targetMissing = math.min(maximum,
        context.targetMissing + amount)
end

function I:AbsorbValue(context)
    local application = applicationOffset(context)
    local duration = tonumber(context.tooltip and context.tooltip.duration)
    if duration == nil then duration = 10 end
    duration = math.min(15, math.max(0, duration))
    local evidence, blocker, handled
    if MageManaShieldScoring then
        evidence, blocker, handled = MageManaShieldScoring:Evidence(
            context, application + duration, application)
    end
    if handled and not evidence then
        context.incomingDuringAbsorbExact = false
        context.estimated = true
        return -100000, blocker or "absorb consequence evidence unavailable"
    end
    local amount = evidence and evidence.incoming
        or incoming(context, application + duration, application)
    context.incomingDuringAbsorb = amount
    local power = evidence and evidence.capacity
        or tonumber(context.absorbEffectivePower) or context.power
    if evidence then
        context.incomingDuringAbsorbExact = evidence.incomingExact
        context.mageManaShieldUnknownIncomingEvents =
            evidence.unknownIncomingEvents
        if not evidence.incomingExact then context.estimated = true end
    end
    local heuristic = context.friendly
        and context.friendly.targetedByCurrentEnemy
        or context.target == "player" and context.state.hasAggro
    if evidence and evidence.allowAggroHeuristic == false then
        heuristic = false
    end
    local expected = power > 0 and (amount > 0 or heuristic)
    local value = power * 3 / math.max(0.5, context.downtime)
        + (expected and 900 or 0) + math.min(power, amount) * 5
    return value, expected and "absorbs expected incoming damage"
        or "adds a protective buffer"
end
