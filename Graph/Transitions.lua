-- The public transition boundary. Resource consumption, elapsed world effects,
-- and the chosen action remain separate so each piece is reviewable in isolation.
XelAssist.Graph.Transitions = {}
local T = XelAssist.Graph.Transitions
local State = XelAssist.Graph.State
local Actions = XelAssist.Graph.ActionEffects
local Timeline = XelAssist.Graph.Timeline

function T:Advance(source, candidate)
    if candidate.targetRelation == "hostile" and source.hostiles then
        if candidate.targetSource == "engaged" and candidate.targetKey ~= nil
            and State.HostileContext then
            source = State:HostileContext(source, candidate.targetKey) or source
        elseif source.targetContextKey ~= nil and State.SelectedHostileContext then
            source = State:SelectedHostileContext(source) or source
        end
    end
    local out = State:Copy(source)
    local context = Actions:Context(source, candidate)
    return Timeline:Run(out, source, candidate, context)
end
