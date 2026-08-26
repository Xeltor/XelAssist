XelAssist = { Game = { Player = {} }, Graph = {} }
local requirements = { [1] = 2, [2] = 3, [3] = 0 }
XelAssist.Game.Player.ReactiveEvidence = {
    Requirement = function(_, action)
        local value = requirements[action.spellId]
        return value, value ~= nil, "test DBC requirement"
    end,
    Available = function(self, snapshot, action)
        local stateID, exact, source = self:Requirement(action)
        if not exact or stateID == 0 or not (snapshot and snapshot.exact) then
            return nil, stateID, source
        end
        local flag = 2 ^ (stateID - 1)
        local active = math.floor(snapshot.mask / flag)
            - math.floor(snapshot.mask / (flag * 2)) * 2 == 1
        return active, stateID, source
    end,
}

dofile("Graph/ReactiveState.lua")
local Reactive = XelAssist.Graph.ReactiveState
local first = { spellId = 1, actor = "player",
    facts = { reactive = true } }
local second = { spellId = 2, actor = "player",
    facts = { reactive = true } }
local opaque = { spellId = 3, actor = "player",
    facts = { reactive = true } }
local ordinary = { spellId = 4, actor = "player", facts = {} }
local pet = { spellId = 1, actor = "pet", facts = { reactive = true } }
local state = { time = 0, playerReactive = { mask = 2, exact = true } }

local blocker, handled, detail = Reactive:Evaluate(first, state, 0)
assert(blocker == nil and handled and detail.available
    and detail.stateID == 2 and detail.rootOnly,
    "an exact active state must admit only its immediate player edge")
assert(Reactive:Evaluate(second, state, 0) == "reactive state inactive",
    "an exact inactive state must block a different reactive edge")
assert(Reactive:Evaluate(first, state, 0.1)
        == "reactive window phase unknown",
    "a root-only bit must not survive an unproven future wait")
state.time = 0.1
assert(Reactive:Evaluate(first, state, 0.1)
        == "reactive window phase unknown",
    "a root-only bit must not leak into a later graph node")
state.time = 0

assert(Reactive:Consume(state, first)
    and state.reactiveConsumed[2]
    and Reactive:Evaluate(first, state, 0) == "reactive state inactive",
    "a chosen reactive must be consumed only in its graph branch")
assert(not state.reactiveConsumed[3],
    "consuming one reactive state must not erase another state")
assert(Reactive:Evaluate(opaque, state, 0) == "reactive state unknown",
    "a reactive classification without a DBC requirement must fail closed")

XelAssist.Graph.RootObservation = {
    Usability = function(_, _, action)
        return { known = true, usable = action.spellId == 3 }, "known"
    end,
}
local fallbackBlocker, fallbackHandled, fallbackDetail =
    Reactive:Evaluate(opaque, state, 0)
assert(fallbackBlocker == nil and fallbackHandled
    and fallbackDetail.usabilityFallback and fallbackDetail.rootOnly,
    "exact live spell usability must recover a missing DBC proc requirement")
assert(Reactive:Consume(state, opaque)
    and state.reactiveConsumed.rootUsability
    and Reactive:Evaluate(opaque, state, 0) == "reactive state inactive",
    "a root-usability proc must be consumed conservatively in its branch")
state.reactiveConsumed.rootUsability = nil
assert(Reactive:Evaluate(opaque, state, 0.1)
        == "reactive window phase unknown",
    "root usability must never project a proc through a wait")
XelAssist.Graph.RootObservation.Usability = function()
    return { known = true, usable = false, reason = "state" }, "known"
end
assert(Reactive:Evaluate(opaque, state, 0) == "reactive state inactive",
    "an explicit unusable root result must not legalize an opaque proc")

assert(select(2, Reactive:Evaluate(ordinary, state, 0)) == false
    and select(2, Reactive:Evaluate(pet, state, 0)) == false,
    "the player evidence module must not claim ordinary or pet actions")

print("ok: exact root-only reactive state and branch-local consumption")
