-- Admission seal for root-captured engine-effective Warrior rage costs.
XelAssist.Graph.WarriorCostPassives = {}
local P = XelAssist.Graph.WarriorCostPassives

function P:Blocker(action, state, descriptor, tooltip)
    local runtime = XelAssist.Game.Player.WarriorCostPassives
    if not runtime:Is(action) then return nil, false end
    local found = runtime:Evidence(action)
    if not (found and tooltip and tooltip.cost==found.cost
        and state and state.resourceType==1
        and descriptor and descriptor.relation=="hostile") then
        return "Warrior effective rage cost unavailable", true
    end
    return nil, true
end
