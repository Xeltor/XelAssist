-- Search-pure use of a completed, root-sealed Evocation mana envelope.
XelAssist.Graph.MageEvocation = {}
local E = XelAssist.Graph.MageEvocation

local function evidence(action)
    local facts = action and action.facts
    local found = facts and facts.mageEvocationEvidence
    if not (facts and facts.mageEvocation == true and found
        and found.valid == true and found.exact == true
        and found.spellId == 12051) then return nil end
    return found
end

local function learned(state)
    local found = state and state.mageEvocationEvidence
    if not (found and found.exact == true and found.spellId == 12051
        and tonumber(found.minimumGain) and found.minimumGain > 0
        and tonumber(found.maximumInterval) and found.maximumInterval > 0
        and tonumber(found.minimumTicks) and found.minimumTicks >= 1
        and tonumber(found.resourceGain) == found.minimumGain * found.minimumTicks)
        then return nil end
    return found
end

function E:CanUse(state, facts)
    return facts and facts.mageEvocation == true and learned(state) ~= nil
end

function E:Prepare(action, state, tooltip)
    if not evidence(action) then return nil, nil, false end
    local found = learned(state)
    if not found then return nil, "completed Evocation evidence unavailable", true end
    local resource, maximum = tonumber(state.resource), tonumber(state.resourceMax)
    if not resource or not maximum or maximum <= 0 then
        return nil, "mana state unavailable", true
    end
    if resource >= maximum then return nil, "mana already full", true end
    local out, key, value = {}, nil, nil
    for key, value in pairs(tooltip or {}) do out[key] = value end
    out.classMechanic = "mageEvocation"
    out.mageEvocationTransition = { exact = true, spellId = 12051,
        resourceGain = found.resourceGain, minimumGain = found.minimumGain,
        minimumTicks = found.minimumTicks,
        maximumInterval = found.maximumInterval, source = found.source }
    return out, nil, true
end

function E:Score(context, projection)
    local transition = projection and projection.mageEvocationTransition
    if not (transition and transition.exact) then
        return false, "Evocation transition unavailable"
    end
    local state = context.state
    local maximum = math.max(1, tonumber(state.resourceMax) or 0)
    local missing = math.max(0, maximum - (tonumber(state.resource) or 0))
    local gain = math.max(0, tonumber(transition.resourceGain) or 0)
    local effective = math.min(gain, missing)
    local urgency = math.min(1, missing / maximum)
    context.power, context.expectedPower, context.effectivePower =
        gain, gain, effective
    context.value = effective / maximum * 1800 * (0.5 + urgency)
        + effective * 4 / math.max(0.5, tonumber(context.downtime) or 0.5)
        - math.max(0, gain - effective) / maximum * 1800
    context.reason = "restores mana from learned Evocation ticks"
    context.estimated = false
    return true
end

function E:Apply(state, candidate)
    local transition = candidate and candidate.classMechanicProjection
        and candidate.classMechanicProjection.mageEvocationTransition
    if not (transition and transition.exact) then return false end
    state.resource = math.min(tonumber(state.resourceMax) or 0,
        (tonumber(state.resource) or 0) + transition.resourceGain)
    if state.actors and state.actors.player then
        state.actors.player.resource = state.resource
    end
    local clock = state.playerResourceClock
    if clock then
        clock.phaseKnown, clock.nextIn = false, nil
        clock.phaseSource = "projected Evocation changed mana regime"
    end
    return true
end

function E:Copy(source, target)
    local found = source and source.mageEvocationEvidence
    if not found then return false end
    target.mageEvocationEvidence = {}
    local key, value
    for key, value in pairs(found) do target.mageEvocationEvidence[key] = value end
    return true
end
