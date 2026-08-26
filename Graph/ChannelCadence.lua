-- Shared identity for root-sealed channel clocks. This module validates only
-- evidence provenance; it owns no spell, class, tick arithmetic, or policy.
XelAssist.Graph.ChannelCadence = {}
local C = XelAssist.Graph.ChannelCadence

C.DBC = "client DBC effectAmplitude"
C.ACCELERATED_ARCANA = "engine-effective Accelerated Arcana cadence"

function C:Exact(source)
    return source == self.DBC or source == self.ACCELERATED_ARCANA
end
