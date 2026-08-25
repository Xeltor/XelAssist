-- Atomic chosen-action payment. Effects and inventory mutation happen only
-- after the actor's resource payment is proven and committed.
XelAssist.Graph.ActionConsumption = {}
local C = XelAssist.Graph.ActionConsumption

local function spendPlayer(out, candidate)
    local resource, cost = tonumber(out.resource),
        math.max(0, tonumber(candidate.cost) or 0)
    if not resource or resource < cost then return false end
    out.resource = resource - cost
    return true
end

function C:Consume(out, candidate, context)
    local action, facts = candidate.action, candidate.action.facts
    local swings = XelAssist.Graph.PlayerSwings
    if swings and swings:Is(action, candidate.tooltip) then
        return swings:Reserve(out, candidate)
    elseif action.actor == "pet" and out.actors and out.actors.pet then
        if not (context and context.petCostPaid) then
            local resources = XelAssist.Graph.CompanionResources
            if not (resources and resources:BeginChosen(
                out, candidate, context or {})) then return false end
        end
    elseif not spendPlayer(out, candidate) then return false end
    if action.executor == "item" and action.itemId and out.inventory
        and out.inventory.itemCounts then
        out.inventory.itemCounts[action.itemId] = math.max(0,
            (out.inventory.itemCounts[action.itemId] or 0) - 1)
    end
    if facts.reagentName and out.inventory
        and out.inventory.reagentCounts then
        out.inventory.reagentCounts[facts.reagentName] = math.max(0,
            (out.inventory.reagentCounts[facts.reagentName] or 0) - 1)
    end
    return true
end
