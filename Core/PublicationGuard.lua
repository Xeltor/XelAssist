-- Bounded live validation for the one action selected by a completed graph.
-- This is not a second snapshot and never re-scores alternatives: it rejects
-- only a publication that has become unsafe while sliced work was finishing.
XelAssist.Core.PublicationGuard = {}
local P = XelAssist.Core.PublicationGuard
local PlayerTauntGuard = XelAssist.Core.PlayerTauntGuard

local function friendly(relation)
    return relation == "ally" or relation == "friendly"
        or relation == "self" or relation == "player" or relation == "pet"
end

local function guardedApplication(facts, tooltip)
    if facts and facts.submissionGuarded then return true end
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" then
        return true
    end
    if kind == "petHeal" then
        return facts.channel or tooltip
            and (tonumber(tooltip.duration) or 0) > 0 and true or false
    end
    return kind == "resource" and (facts.transientResource or facts.channel
        or tooltip and (tonumber(tooltip.duration) or 0) > 0) and true or false
end

local function actorIdentity(plan)
    local action = plan.action
    if action.actor ~= "pet" then return true, nil end
    local ref = action.actorRef or plan.actorRef
    if not ref then return false, "companion identity unavailable" end
    local actors = XelAssist.Game and XelAssist.Game.Actors
    if not (actors and actors.ValidateActorRef) then
        return false, "companion validation unavailable"
    end
    local _, reason = actors:ValidateActorRef(ref)
    return reason == nil, reason
end

local function recipientIdentity(plan)
    local action = plan.action
    local guard = XelAssist.Core and XelAssist.Core.TargetGuard
    if not guard then return false, "target validation unavailable" end
    if action.actor == "pet" then
        local valid, reason = guard:ValidatePetTarget(plan)
        return valid and true or false, reason
    end
    local ref = plan.castTargetRef or plan.targetRef
    local unit = plan.castTarget or plan.target
    local _, reason, hostile = guard:ValidateHostile(plan, unit, ref)
    if hostile then return reason == nil, reason end
    local relation = ref and ref.relation
        or plan.castTargetRelation or plan.targetRelation
    if friendly(relation) and ref and relation ~= "self"
        and relation ~= "player" then
        local capabilities = XelAssist.Game and XelAssist.Game.Capabilities
        if not (capabilities and capabilities.ValidateFriendlyRef) then
            return false, "ally validation unavailable"
        end
        local _, friendlyReason = capabilities:ValidateFriendlyRef(ref)
        return friendlyReason == nil, friendlyReason
    end
    return true, nil
end

local function affordable(plan)
    local action, facts = plan.action, plan.action.facts or {}
    if plan.costKnown ~= true or (tonumber(plan.cost) or 0) <= 0
        or (tonumber(plan.wait) or 0) > 0 or facts.healthConversion
        or action.executor == "item" or action.executor == "instruction" then
        return true, nil
    end
    if not UnitMana then return false, "resource state unavailable" end
    local unit = action.actor == "pet" and "pet" or "player"
    local ok, current = pcall(UnitMana, unit)
    if not ok or tonumber(current) == nil then
        return false, "resource state unavailable"
    end
    if tonumber(current) < tonumber(plan.cost) then
        return false, action.actor == "pet"
            and "companion resource changed" or "resource changed"
    end
    return true, nil
end

local function reagentAvailable(plan)
    local reagent = plan.action.facts and plan.action.facts.reagentName
    if not reagent then return true, nil end
    local actors = XelAssist.Game and XelAssist.Game.Actors
    if not (actors and actors.HasReagent) then
        return false, "reagent state unavailable"
    end
    local available = actors:HasReagent(reagent)
    if available == false then return false, "missing " .. reagent end
    if available ~= true then return false, "reagent state unavailable" end
    return true, nil
end

local function applicationOpen(plan)
    if not guardedApplication(plan.action.facts, plan.tooltip) then
        return true, nil
    end
    if not (XelAssist and XelAssist.IsAuraPending) then return true, nil end
    local ref = plan.targetRef or plan.castTargetRef
    local target = plan.targetGUID or plan.castTargetGUID
        or ref and ref.guid or plan.target or plan.castTarget
    local ok, pending = pcall(XelAssist.IsAuraPending, XelAssist,
        plan.action.name, plan.action.actor, target)
    if not ok then return false, "application state unavailable" end
    if pending then return false, "application already pending" end
    return true, nil
end

function P:Validate(plan)
    if type(plan) ~= "table" or type(plan.action) ~= "table" then
        return false, "recommendation incomplete"
    end
    local valid, reason = actorIdentity(plan)
    if not valid then return false, reason end
    valid, reason = recipientIdentity(plan)
    if not valid then return false, reason end
    if PlayerTauntGuard then
        valid, reason = PlayerTauntGuard:Validate(plan)
        if not valid then return false, reason end
    end
    valid, reason = affordable(plan)
    if not valid then return false, reason end
    valid, reason = reagentAvailable(plan)
    if not valid then return false, reason end
    return applicationOpen(plan)
end
