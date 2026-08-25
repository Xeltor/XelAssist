-- Conservative graph-clock arithmetic for controlled resources. Hunter focus
-- evidence is learned separately by FocusEvidence and attached by identity.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.Resources = {}
local R = XelAssist.Game.Pets.Resources

local FOCUS_POWER_TYPE = 2

local function numeric(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

local function sameIdentity(left, right)
    return left ~= nil and right ~= nil and left == right
end

local function copyClock(source)
    if not source then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

function R:CopyClock(source)
    return copyClock(source)
end

function R:Attach(actor, lifecycle)
    if not actor then return nil end
    local clock = lifecycle and lifecycle.resourceRegen or nil
    actor.resourceType = actor.ownerClass == "HUNTER" and FOCUS_POWER_TYPE
        or actor.resourceType
    if actor.ownerClass == "HUNTER" and clock and clock.verified
        and tonumber(clock.resourceType) == FOCUS_POWER_TYPE
        and sameIdentity(clock.sourceGuid, actor.guid) then
        actor.resourceRegen = copyClock(clock)
        actor.resourceRegenKnown = true
    else
        actor.resourceRegen = nil
        actor.resourceRegenKnown = false
    end
    return actor
end

function R:ClockFor(actor)
    local clock = actor and actor.resourceRegen
    if not actor or actor.ownerClass ~= "HUNTER"
        or tonumber(actor.resourceType) ~= FOCUS_POWER_TYPE
        or not (clock and clock.verified and clock.phaseKnown
            and clock.externalEnergizeExcluded)
        or tonumber(clock.resourceType) ~= FOCUS_POWER_TYPE
        or not sameIdentity(clock.sourceGuid, actor.guid) then return nil end
    local amount, interval, nextIn = numeric(clock.amount),
        numeric(clock.interval), numeric(clock.nextIn)
    if not amount or amount <= 0 or not interval or interval <= 0
        or not nextIn or nextIn < 0 then return nil end
    return clock, amount, interval, nextIn
end

function R:TimeUntil(actor, required)
    local resource, maximum, cost = numeric(actor and actor.resource),
        numeric(actor and actor.resourceMax), numeric(required)
    if not resource or not maximum or not cost then return nil end
    if actor.resourceExact == false and cost > 0 then return nil end
    if resource >= cost then return 0 end
    if cost > maximum then return nil end
    local clock, amount, interval, nextIn = self:ClockFor(actor)
    if not clock then return nil end
    local missing = cost - resource
    local ticks = math.ceil(missing / amount)
    return nextIn + math.max(0, ticks - 1) * interval
end

function R:AdvanceActor(actor, elapsed)
    elapsed = numeric(elapsed)
    if not elapsed or elapsed <= 0 then return 0 end
    local clock, amount, interval, nextIn = self:ClockFor(actor)
    if not clock then return 0 end
    local resource, maximum = numeric(actor.resource), numeric(actor.resourceMax)
    if not resource or not maximum or maximum <= 0 then return 0 end
    if elapsed < nextIn then
        clock.nextIn = nextIn - elapsed
        return 0
    end
    local afterFirst = elapsed - nextIn
    local ticks = 1 + math.floor(afterFirst / interval)
    local residual = afterFirst - (ticks - 1) * interval
    clock.nextIn = interval - residual
    local prior = resource
    actor.resource = math.min(maximum, resource + ticks * amount)
    if actor.resource >= maximum then
        clock.phaseKnown, clock.nextIn = false, nil
        clock.phaseSource = "projected focus cap erased tick phase"
    end
    return actor.resource - prior
end

function R:SpendActor(actor, cost)
    if not actor then return false, 0 end
    local resource, maximum = numeric(actor.resource) or 0,
        numeric(actor.resourceMax) or 0
    cost = math.max(0, numeric(cost) or 0)
    if actor.resourceExact == false and cost > 0 then return false, 0 end
    if cost > resource then return false, 0 end
    actor.resource = resource - cost
    local clock = actor.resourceRegen
    if actor.ownerClass == "HUNTER" and clock and clock.verified
        and actor.resource < maximum and not clock.phaseKnown
        and clock.externalEnergizeExcluded
        and numeric(clock.interval) and clock.interval > 0 then
        clock.phaseKnown, clock.nextIn = true, clock.interval
        clock.phaseSource = "lower bound after projected spend"
    end
    return true, cost
end
