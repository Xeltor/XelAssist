-- Composes spatial setup transitions without making the general action-effect
-- pipeline own Stealth or player-controlled movement semantics.
XelAssist.Graph.SpatialEffects = {}
local S = XelAssist.Graph.SpatialEffects

function S:Apply(out, candidate)
    if XelAssist.Graph.ChannelCommitment then
        XelAssist.Graph.ChannelCommitment:Apply(out, candidate)
    end
    if XelAssist.Graph.StealthSetup then
        XelAssist.Graph.StealthSetup:Apply(out, candidate)
    end
    if XelAssist.Graph.MovementSetup then
        XelAssist.Graph.MovementSetup:Apply(out, candidate)
    end
end
