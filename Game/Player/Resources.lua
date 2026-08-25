-- Conservative player-resource graph clock. Only a verified, attributed
-- energy tick envelope may create future resource; mana and rage remain open.
XelAssist.Game.Player.Resources = {}
local R = XelAssist.Game.Player.Resources

local ENERGY = 3

local function copy(source)
    if not source then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

function R:Attach(state, evidence)
    state.playerResourceClock = copy(evidence)
    return state
end

function R:ClockFor(state)
    local clock = state and state.playerResourceClock
    if tonumber(state and state.resourceType) ~= ENERGY
        or not (clock and clock.verified and clock.phaseKnown
            and clock.externalEnergizeExcluded)
        or tonumber(clock.resourceType) ~= ENERGY then return nil end
    local amount, interval, nextIn = tonumber(clock.amount),
        tonumber(clock.interval), tonumber(clock.nextIn)
    if not amount or amount <= 0 or not interval or interval <= 0
        or not nextIn or nextIn < 0 then return nil end
    return clock, amount, interval, nextIn
end

function R:Advance(state, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    local clock, amount, interval, nextIn = self:ClockFor(state)
    if elapsed <= 0 or not clock then return 0 end
    if elapsed < nextIn then clock.nextIn = nextIn - elapsed; return 0 end
    local afterFirst = elapsed - nextIn
    local ticks = 1 + math.floor(afterFirst / interval)
    local residual = afterFirst - (ticks - 1) * interval
    clock.nextIn = interval - residual
    local prior = tonumber(state.resource) or 0
    state.resource = math.min(tonumber(state.resourceMax) or prior,
        prior + ticks * amount)
    if state.resource >= (tonumber(state.resourceMax) or 0) then
        clock.phaseKnown, clock.nextIn = false, nil
        clock.phaseSource = "projected energy cap erased tick phase"
    end
    return state.resource - prior
end

local function probe(state, at)
    local out = { resource = tonumber(state.resource),
        resourceMax = tonumber(state.resourceMax), resourceType = state.resourceType,
        playerResourceReserved = tonumber(state.playerResourceReserved) or 0,
        playerResourceClock = copy(state.playerResourceClock) }
    R:Advance(out, math.max(0, (tonumber(at) or 0)
        - (tonumber(state.time) or 0)))
    return out
end

function R:ResourceAt(state, at)
    local out = probe(state, at)
    return out.resource and out.resource - out.playerResourceReserved or nil
end

function R:Earliest(state, cost, readyAt)
    cost, readyAt = math.max(0, tonumber(cost) or 0),
        math.max(tonumber(state.time) or 0, tonumber(readyAt) or 0)
    local out = probe(state, readyAt)
    local available = (tonumber(out.resource) or 0) - out.playerResourceReserved
    if available >= cost then return readyAt end
    local maximum = (tonumber(out.resourceMax) or 0) - out.playerResourceReserved
    if maximum < cost then return nil end
    local clock, amount, interval, nextIn = self:ClockFor(out)
    if not clock then return nil end
    local ticks = math.ceil((cost - available) / amount)
    return readyAt + nextIn + math.max(0, ticks - 1) * interval
end

function R:Spend(state, cost)
    local resource = tonumber(state.resource)
    cost = math.max(0, tonumber(cost) or 0)
    if not resource or resource < cost then return false end
    state.resource = resource - cost
    local clock = state.playerResourceClock
    if tonumber(state.resourceType) == ENERGY and clock and clock.verified
        and clock.externalEnergizeExcluded and state.resource
            < (tonumber(state.resourceMax) or 0) and not clock.phaseKnown
        and tonumber(clock.interval) and clock.interval > 0 then
        clock.phaseKnown, clock.nextIn = true, clock.interval
        clock.phaseSource = "lower bound after projected energy spend"
    end
    return true
end
