-- Recommendation value derived from exact-recipient hostile casts. This stays
-- separate from generic potency scoring so unsupported evidence has one gate.
XelAssist.Graph.IncomingScoring = {}
local I = XelAssist.Graph.IncomingScoring

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
    local amount = incoming(context, application + duration, application)
    context.incomingDuringAbsorb = amount
    local heuristic = context.friendly
        and context.friendly.targetedByCurrentEnemy
        or context.target == "player" and context.state.hasAggro
    local expected = amount > 0 or heuristic
    local value = context.power * 3 / math.max(0.5, context.downtime)
        + (expected and 900 or 0) + math.min(context.power, amount) * 5
    return value, expected and "absorbs expected incoming damage"
        or "adds a protective buffer"
end
