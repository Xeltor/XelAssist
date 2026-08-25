XelAssist = { Graph = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local steps = 0
XelAssist.Graph.RootObservation = {
    Begin = function(_, state, actions, observedAt)
        return { state = state, actions = actions, observedAt = observedAt }
    end,
    Step = function()
        steps = steps + 1
        return steps >= 3
    end,
    Seal = function(_, observed)
        observed.sealed = true
        return observed
    end,
    Actions = function(_, state)
        return state.frozenActions, "known"
    end,
}

dofile("Graph/SearchPreparation.lua")
local Preparation = XelAssist.Graph.SearchPreparation
local original, frozen = { { name = "live" } }, { { name = "frozen" } }
local session = { state = { frozenActions = frozen }, observedAt = 12,
    status = "pending", phase = "actions" }
assert(not Preparation:Begin(session, original)
    and session.phase == "observe" and session.actions == original,
    "action discovery must enter the observation cursor")
assert(not Preparation:Advance(session) and not Preparation:Advance(session),
    "incomplete capture steps must remain resumable")
assert(Preparation:Advance(session) and session.phase == "prepare"
    and session.prepareStage == 1 and session.actions == frozen,
    "only a sealed observation may replace the live action catalog")

XelAssist.Graph.RootObservation = nil
local fallback = { status = "pending", phase = "actions" }
Preparation:Begin(fallback, original)
assert(fallback.phase == "prepare" and fallback.prepareStage == 1,
    "reduced test environments may retain the legacy preparation path")

print("search preparation tests passed")
