-- Exact reactive evidence must participate in graph legality and branch state,
-- not merely describe a live proc beside the search.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local Evidence = XelAssist.Game.Player.ReactiveEvidence
function Evidence:Requirement(action)
    return action and action.spellId == 7384 and 2 or 0, true,
        "test DBC casterAuraState"
end
function Evidence:Available(snapshot, action)
    local stateID = self:Requirement(action)
    if stateID == 0 or not (snapshot and snapshot.exact) then
        return nil, stateID, "test reactive evidence unavailable"
    end
    return snapshot.mask == 2, stateID, "test exact player auraState"
end

local originalUsability = XelAssist.Graph.RootObservation.Usability

local function subject()
    local action = Fixture.Action("Reactive Strike", 1, "damage", 40, 5, {
        reactive = true, melee = true, testMinRange = 0, testMaxRange = 5,
    })
    action.spellId, action.actor, action.executor = 7384, "player", "playerSpell"
    return action
end

local function scored(state, action)
    Fixture:Use(state, { action })
    local descriptor = XelAssist.Graph.Targets:Targets(action, state)[1]
    return XelAssist.Graph.Scoring:Evaluate(action, state, descriptor)
end

local action = subject()
local state = Fixture.State("smart")
state.playerReactive = { mask = 2, exact = true }
local candidate, blocker = scored(state, action)
assert(candidate and not blocker,
    "an exact active root bit must legalize its reactive edge")

local projected = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(projected.reactiveConsumed and projected.reactiveConsumed[2],
    "a chosen reactive must be consumed in only the chosen graph branch")
assert(projected.readyAt["player:Reactive Strike"] == nil,
    "reactive consumption must not invent a sixty-second cooldown")

candidate, blocker = scored(projected, action)
assert(candidate == nil and blocker == "reactive state inactive",
    "a consumed state must not legalize another reactive edge")

state = Fixture.State("smart")
state.playerReactive = { mask = 2, exact = true }
state.playerGcdReadyAt = 0.5
candidate, blocker = scored(state, action)
assert(candidate == nil and blocker == "reactive window phase unknown",
    "a live bit with no expiry must not survive a projected wait")

state = Fixture.State("smart")
state.playerReactive = { mask = 0, exact = true }
candidate, blocker = scored(state, action)
assert(candidate == nil and blocker == "reactive state inactive",
    "an exact inactive bit must block the reactive edge")

function Evidence:Requirement()
    return 0, true, "installed client has no casterAuraState"
end
function Evidence:Available()
    return nil, 0, "installed client has no casterAuraState"
end
XelAssist.Graph.RootObservation.Usability = function()
    return { known = true, usable = true }, "known"
end
state = Fixture.State("smart")
candidate, blocker = scored(state, action)
assert(candidate and not blocker,
    "exact root usability must legalize a DBC-opaque proc now")
projected = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(projected.reactiveConsumed
        and projected.reactiveConsumed.rootUsability,
    "an opaque proc must be consumed in the selected branch")
candidate, blocker = scored(projected, action)
assert(candidate == nil,
    "an opaque root proc must not survive its selected graph edge")
XelAssist.Graph.RootObservation.Usability = originalUsability

print("ok: exact reactive evidence drives graph legality and consumption")
