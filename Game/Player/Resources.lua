-- Conservative player-resource graph clock. Verified energy ticks and sealed
-- finite class clocks may create future resource; unobserved regen stays open.
XelAssist.Game.Player.Resources = {}
local R = XelAssist.Game.Player.Resources

local MANA, ENERGY = 0, 3

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

function R:RootEvidence(state, actor, at)
    local player = XelAssist.Game.Player or {}
    local kind = tonumber(state and state.resourceType)
    local guid = actor and actor.guid
    if kind == MANA and player.ManaEvidence then
        return player.ManaEvidence:Snapshot(guid, state.resource,
            state.resourceMax, at)
    elseif kind == ENERGY and player.EnergyEvidence then
        return player.EnergyEvidence:Observe(guid, state.resource,
            state.resourceMax, at, false, kind)
    end
    return nil
end

function R:ClockFor(state)
    local clock = state and state.playerResourceClock
    local kind = tonumber(state and state.resourceType)
    if (kind ~= ENERGY and kind ~= MANA)
        or not (clock and clock.verified and clock.phaseKnown
            and clock.externalEnergizeExcluded)
        or tonumber(clock.resourceType) ~= kind then return nil end
    local amount, interval, nextIn = tonumber(clock.amount),
        tonumber(clock.interval), tonumber(clock.nextIn)
    if not amount or amount <= 0 or not interval or interval <= 0
        or not nextIn or nextIn < 0 then return nil end
    return clock, amount, interval, nextIn
end

function R:IsManaSpend(state, candidate)
    local action = candidate and candidate.action
    return tonumber(state and state.resourceType) == MANA
        and action and (action.actor or "player") == "player"
        and math.max(0, tonumber(candidate.cost) or 0) > 0
end

local function closeManaClock(clock, reason)
    if not clock then return end
    clock.phaseKnown, clock.nextIn = false, nil
    clock.pendingSpendSpellId = nil
    clock.phaseSource = reason
end

local function exactGoContract(clock, candidate)
    local contract = clock and clock.postSpend
    local spellId = candidate and candidate.action
        and tonumber(candidate.action.spellId)
    return candidate and candidate.costKnown == true and spellId
        and contract and contract.verified and contract.boundary == "go"
        and tonumber(contract.spellId) == spellId
        and tonumber(contract.delay) and contract.delay > 0
end

-- This runs at the chosen spell's start, after any resource-waiting window but
-- before its cast time. Only an exact GO-paid contract may keep ticking during
-- the cast; every unknown/start-paid regime closes before it can invent mana.
function R:BeginChosen(state, candidate)
    if not self:IsManaSpend(state, candidate) then return true end
    local clock = state.playerResourceClock
    if exactGoContract(clock, candidate) then
        clock.pendingSpendSpellId = tonumber(candidate.action.spellId)
    else closeManaClock(clock, "projected mana spell began without exact GO contract") end
    return true
end

function R:Advance(state, elapsed)
    local warrior = XelAssist.Game.Player.WarriorRage
    if warrior and warrior:Active(state) then
        return warrior:Advance(state, elapsed)
    end
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
    local warrior = XelAssist.Game.Player.WarriorRage
    if warrior and warrior:Active(state) then
        return warrior:ResourceAt(state, at)
    end
    local wisdom = XelAssist.Graph and XelAssist.Graph.PaladinWisdom
    if wisdom then
        local value, handled = wisdom:ResourceAt(state, at)
        if handled then return value end
    end
    local out = probe(state, at)
    return out.resource and out.resource - out.playerResourceReserved or nil
end

function R:Earliest(state, cost, readyAt)
    local warrior = XelAssist.Game.Player.WarriorRage
    if warrior and warrior:Active(state) then
        return warrior:Earliest(state, cost, readyAt)
    end
    local wisdom = XelAssist.Graph and XelAssist.Graph.PaladinWisdom
    if wisdom then
        local value, handled = wisdom:Earliest(state, cost, readyAt)
        if handled then return value end
    end
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

function R:Spend(state, cost, candidate)
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
    elseif tonumber(state.resourceType) == MANA and cost > 0 then
        local contract = clock and clock.postSpend
        local spellId = candidate and candidate.action
            and tonumber(candidate.action.spellId)
        local matched = clock and clock.pendingSpendSpellId == spellId
            and exactGoContract(clock, candidate)
        if matched and state.resource < (tonumber(state.resourceMax) or 0) then
            clock.phaseKnown, clock.nextIn = true, contract.delay
            clock.phaseSource = "observed exact GO-to-passive-mana envelope"
            clock.pendingSpendSpellId = nil
        else closeManaClock(clock,
            "projected mana spend had no matching exact GO contract") end
    end
    return true
end
