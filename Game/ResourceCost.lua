-- DBC resource costs use the server's storage scale; live UnitMana and the
-- spell tooltip expose display units. Keep that conversion at the data edge.
XelAssist.Game.ResourceCost = {}
local C = XelAssist.Game.ResourceCost

function C:Normalize(powerType, cost)
    cost = tonumber(cost)
    if cost and tonumber(powerType) == 1 then return cost / 10 end
    return cost
end
