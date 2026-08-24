-- The public transition boundary. Resource consumption, elapsed world effects,
-- and the chosen action remain separate so each piece is reviewable in isolation.
XelAssist.Graph.Transitions = {}
local T = XelAssist.Graph.Transitions
local State = XelAssist.Graph.State
local Actions = XelAssist.Graph.ActionEffects
local Ongoing = XelAssist.Graph.OngoingEffects

function T:Advance(source, candidate)
    local out = State:Copy(source)
    local context = Actions:Context(source, candidate)
    Actions:Consume(out, candidate)
    Ongoing:Advance(out, source, candidate, context)
    Actions:Apply(out, source, candidate, context)
    return out
end
