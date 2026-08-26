-- Branch-local mana scarcity for ordinary action scoring. The existing fixed
-- resource reserve is expressed against current spendable mana so conserving
-- mana, or earning an exact tick while wanding, changes later opportunity cost.
-- Rage and energy retain their existing maximum-pool behavior.
XelAssist.Graph.ManaOpportunity = {}
local M = XelAssist.Graph.ManaOpportunity

M.MANA = 0

function M:CostFraction(state, cost, maximum)
    cost, maximum = math.max(0, tonumber(cost) or 0),
        math.max(0, tonumber(maximum) or 0)
    if cost <= 0 or maximum <= 0 then return 0, maximum, false end
    if tonumber(state and state.resourceType) ~= self.MANA
        or state.playerResourceExact == false
        or state.manaOpportunityWandAvailable ~= true then
        return cost / maximum, maximum, false
    end
    local current = tonumber(state.resource)
    if current == nil then return cost / maximum, maximum, false end
    local available = math.max(0, current
        - math.max(0, tonumber(state.playerResourceReserved) or 0))
    local basis = math.max(cost, math.min(maximum, available))
    return cost / basis, basis, basis < maximum
end
