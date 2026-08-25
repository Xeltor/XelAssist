-- Causal resource clock shared by companion scheduling and event resolution.
-- The scheduler uses a private actor copy; the real actor is mutated only when
-- the Timeline reaches an actual cast-start or instant-impact event.
XelAssist.Graph.CompanionResources = {}
local C = XelAssist.Graph.CompanionResources

local EPSILON = 0.0001

local function api()
    return XelAssist.Game and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Resources or nil
end

local function copyTable(source)
    if type(source) ~= "table" then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

local function copyActor(actor)
    return { guid = actor.guid, ownerClass = actor.ownerClass,
        resource = tonumber(actor.resource),
        resourceMax = tonumber(actor.resourceMax),
        resourceType = actor.resourceType,
        resourceRegen = copyTable(actor.resourceRegen),
        resourceRegenKnown = actor.resourceRegenKnown,
        resourceExact = actor.resourceExact }
end

local function petAction(candidate)
    local action = candidate and candidate.action
    return action and action.actor == "pet"
        and action.executor == "petAbility"
end

function C:ChosenCost(candidate)
    if not petAction(candidate) then return 0, true end
    if candidate.costKnown == false then return 0, false end
    local cost = tonumber(candidate.cost)
    if cost and cost > 0 then return math.max(0, cost), true end
    local tooltipCost = tonumber(candidate.tooltip and candidate.tooltip.cost)
    if tooltipCost ~= nil then return math.max(0, tooltipCost), true end
    if candidate.costKnown == true then return math.max(0, cost or 0), true end
    return 0, false
end

local function spend(actor, cost)
    local resources = api()
    if resources then return resources:SpendActor(actor, cost) end
    local resource = tonumber(actor and actor.resource)
    cost = math.max(0, tonumber(cost) or 0)
    if not resource or resource < cost then return false, 0 end
    actor.resource = resource - cost
    return true, cost
end

local function advance(actor, elapsed)
    if elapsed <= 0 then return end
    local resources = api()
    if resources then resources:AdvanceActor(actor, elapsed) end
end

function C:Create(actor, candidate)
    local chosen = petAction(candidate)
    local chosenCost, chosenCostKnown = self:ChosenCost(candidate)
    return { actor = copyActor(actor), time = 0,
        exact = tonumber(actor.resource) ~= nil
            and actor.resourceExact ~= false,
        chosenAt = chosen and math.max(0,
            tonumber(candidate.wait) or 0) or nil,
        chosenCost = chosen and chosenCost or 0,
        chosenCostKnown = not chosen or chosenCostKnown,
        chosenSpent = not chosen }
end

local function copyClock(clock)
    return { actor = copyActor(clock.actor), time = clock.time,
        exact = clock.exact, chosenAt = clock.chosenAt,
        chosenCost = clock.chosenCost, chosenSpent = clock.chosenSpent,
        chosenCostKnown = clock.chosenCostKnown,
        chosenFailed = clock.chosenFailed }
end

local function advanceTo(clock, at)
    at = math.max(clock.time, tonumber(at) or clock.time)
    if not clock.chosenSpent and clock.chosenAt <= at then
        advance(clock.actor, math.max(0, clock.chosenAt - clock.time))
        clock.time = math.max(clock.time, clock.chosenAt)
        local paid = clock.chosenCostKnown
            and spend(clock.actor, clock.chosenCost)
        clock.chosenSpent = true
        if not paid then
            clock.chosenFailed = true
            return false
        end
    end
    advance(clock.actor, math.max(0, at - clock.time))
    clock.time = at
    return not clock.chosenFailed
end

function C:AdvanceTo(clock, at)
    return advanceTo(clock, at)
end

local function protectedCost(clock)
    return not clock.chosenSpent and clock.chosenCost or 0
end

local function affordable(clock, cost)
    local resource = tonumber(clock.actor.resource)
    return resource ~= nil
        and resource + EPSILON >= cost + protectedCost(clock)
end

-- Return the first verified lower-envelope time at which cost can be paid.
-- A future chosen pet action is inserted into the probe before any ambient
-- lane may use focus that action requires.
function C:Earliest(clock, cost, costKnown, readyAt)
    readyAt = math.max(clock.time, tonumber(readyAt) or clock.time)
    if not costKnown then return readyAt end
    cost = math.max(0, tonumber(cost) or 0)
    if not clock.exact then return cost <= 0 and readyAt or nil end
    local probe = copyClock(clock)
    if not advanceTo(probe, readyAt) then return nil end
    if affordable(probe, cost) then return readyAt end
    local resources = api()
    if not resources then return nil end
    local attempts = 0
    while attempts < 3 do
        attempts = attempts + 1
        local delay = resources:TimeUntil(
            probe.actor, cost + protectedCost(probe))
        if delay == nil then
            if probe.chosenSpent then return nil end
            if not advanceTo(probe, probe.chosenAt) then return nil end
            if affordable(probe, cost) then return probe.time end
            delay = resources:TimeUntil(probe.actor, cost)
            if delay == nil then return nil end
        end
        local focusAt = probe.time + math.max(0, delay)
        if not probe.chosenSpent and probe.chosenAt <= focusAt + EPSILON then
            if not advanceTo(probe, probe.chosenAt) then return nil end
            if affordable(probe, cost) then return probe.time end
        else
            if not advanceTo(probe, focusAt) then return nil end
            if affordable(probe, cost) then return probe.time end
            return nil
        end
    end
    return nil
end

function C:Reserve(clock, at, cost, costKnown)
    if not advanceTo(clock, at) then return false end
    if not costKnown then
        clock.exact = false
        clock.actor.resourceExact = false
        return true
    end
    cost = math.max(0, tonumber(cost) or 0)
    if not affordable(clock, cost) then return false end
    return spend(clock.actor, cost)
end

function C:SpendActor(actor, cost, costKnown)
    if costKnown == false then
        actor.resourceExact = false
        actor.resourceUnknownReason = "companion action cost"
        return true, nil
    end
    return spend(actor, math.max(0, tonumber(cost) or 0))
end

function C:BeginChosen(out, candidate, context)
    local actor = out and out.actors and out.actors.pet
    if not petAction(candidate) then return true end
    local cost, known = self:ChosenCost(candidate)
    if not known then return false end
    if actor and actor.actionReadyExact == false then return false end
    if cost > 0 and actor and actor.resourceExact == false then return false end
    local paid = actor and self:SpendActor(actor, cost, true)
    if not paid then return false end
    context.petCostPaid = true
    self:CommitChosen(out, candidate)
    return true
end

function C:CommitChosen(out, candidate)
    local actor = out and out.actors and out.actors.pet
    if not actor then return end
    local busy = math.max(0.1, tonumber(candidate.occupancy) or 0,
        tonumber(candidate.cast) or 0,
        tonumber(candidate.tooltip and candidate.tooltip.gcd) or 1.5)
    local left = math.max(0, (tonumber(candidate.wait) or 0)
        + busy
        - (tonumber(candidate.downtime) or 0))
    actor.actionReadyIn = math.max(tonumber(actor.actionReadyIn) or 0, left)
    out.actorReadyAt = out.actorReadyAt or {}
    out.actorReadyAt.pet = math.max(tonumber(out.actorReadyAt.pet) or 0,
        (tonumber(out.time) or 0) + left)
end

function C:ChosenExact(state, action, cost)
    local actor = state and state.actors and state.actors.pet
    if not (action and action.actor == "pet"
        and action.executor == "petAbility") then return true end
    if tonumber(cost) == nil then return false end
    return not (actor and actor.resourceExact == false
        and tonumber(cost) > 0)
end

function C:ReadyExact(state, action)
    local actor = state and state.actors and state.actors.pet
    return not (action and action.actor == "pet" and actor
        and actor.actionReadyExact == false)
end
