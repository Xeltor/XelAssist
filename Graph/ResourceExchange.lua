-- Graph-native health/resource exchange. Legality, utility and state mutation
-- share the same exact tooltip evidence so the search cannot price a gain that
-- its transition does not apply.
XelAssist.Graph.ResourceExchange = {}
local R = XelAssist.Graph.ResourceExchange
local State = XelAssist.Graph.State

local function facts(action)
    return action and action.facts or {}
end

local function dangerAfterExchange(state, healthAfter, healthMax, within)
    local incoming = 0
    local events = XelAssist.Graph.HostileCastEvents
    local actor = state.actors and state.actors.player
    local friendly = State:FriendlyByUnit(state, "player")
    local guid = actor and actor.guid or friendly and friendly.guid
    if events and guid then
        incoming = events:IncomingDamage(state, guid, within)
    end
    incoming = math.max(0, tonumber(incoming) or 0)
    local projected = math.max(0, healthAfter - incoming)
    return 1 - math.min(1, projected / healthMax)
end

function R:Is(action)
    return facts(action).healthConversion == true
end

function R:Blocker(action, state, tooltip)
    if not self:Is(action) then return nil end
    local healthCost = tonumber(tooltip and tooltip.healthCost)
    local resourceGain = tonumber(tooltip and tooltip.resourceGain)
    if not (healthCost and healthCost > 0 and resourceGain
        and resourceGain > 0) then return "health conversion unknown" end
    local health, maximum = tonumber(state.health), tonumber(state.healthMax)
    local resource, resourceMax = tonumber(state.resource),
        tonumber(state.resourceMax)
    if not (health and maximum and maximum > 0) then
        return "health state unknown"
    end
    if health <= healthCost then return "health conversion would be lethal" end
    if not (resource and resourceMax and resourceMax > 0) then
        return "resource state unknown"
    end
    if resource >= resourceMax then return "resource already full" end
    return nil
end

function R:Score(context)
    if not self:Is(context.action) then return false end
    local state, tooltip = context.state, context.tooltip or {}
    local gain = math.max(0, tonumber(tooltip.resourceGain) or 0)
    local healthCost = math.max(0, tonumber(tooltip.healthCost) or 0)
    local resourceMax = math.max(1, tonumber(state.resourceMax) or 0)
    local healthMax = math.max(1, tonumber(state.healthMax) or 0)
    local missing = math.max(0, resourceMax - (tonumber(state.resource) or 0))
    local effective = math.min(gain, missing)
    local urgency = math.min(1, missing / resourceMax)
    local healthAfter = math.max(0, (tonumber(state.health) or 0) - healthCost)
    local danger = dangerAfterExchange(
        state, healthAfter, healthMax,
        math.max(0, tonumber(context.wait) or 0)
            + math.max(0, tonumber(context.downtime) or 0))
    local resourceValue = effective / resourceMax * 1800 * (0.5 + urgency)
        + effective * 4 / math.max(0.5, context.downtime)
    local healthValue = healthCost / healthMax * 1200
        * (1 + danger * danger * 4
            + (state.hasAggro and danger * 1.5 or 0))
    local waste = math.max(0, gain - effective) / resourceMax * 1800
    context.power, context.expectedPower, context.effectivePower =
        gain, gain, effective
    context.value = resourceValue - healthValue - waste
    context.reason = waste > 0
        and "avoids wasting health on excess mana"
        or "trades health for needed mana"
    return true
end

function R:Apply(out, candidate)
    if not self:Is(candidate and candidate.action) then return false end
    local tooltip = candidate.tooltip or {}
    local healthCost = math.max(0, tonumber(tooltip.healthCost) or 0)
    local resourceGain = math.max(0, tonumber(tooltip.resourceGain) or 0)
    out.resource = math.min(tonumber(out.resourceMax) or 0,
        (tonumber(out.resource) or 0) + resourceGain)
    out.health = math.max(0, (tonumber(out.health) or 0) - healthCost)
    local player = State:FriendlyByUnit(out, "player")
    if player then player.health = out.health end
    if out.actors and out.actors.player then
        out.actors.player.health = out.health
        out.actors.player.resource = out.resource
    end
    return true
end
