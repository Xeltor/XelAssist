-- Compose stateful, action-specific damage proc lanes without teaching the
-- generic scorer class identities or proc ordering.
XelAssist.Graph.DamageProcAdjustments = {}
local A = XelAssist.Graph.DamageProcAdjustments

function A:Adjust(context)
    local stormstrike = XelAssist.Graph.ShamanStormstrike
    if stormstrike then
        local adjusted, reason = stormstrike:Adjust(context)
        if not adjusted and reason then return reason end
    end
    local shieldMastery = XelAssist.Graph.WarriorShieldBlock
    if shieldMastery then
        local adjusted, reason = shieldMastery:AdjustRevenge(context)
        if not adjusted and reason then return reason end
    end
    return nil
end

function A:Consume(state, candidate)
    local stormstrike = XelAssist.Graph.ShamanStormstrike
    if stormstrike then stormstrike:Consume(state, candidate) end
    local shieldMastery = XelAssist.Graph.WarriorShieldBlock
    if shieldMastery then shieldMastery:ConsumeRevenge(state, candidate) end
end
