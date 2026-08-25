-- A self-recipient finisher still spends combo points owned by the hostile
-- unit they were built on.  Cast recipient and combo owner are independent.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")

local state = Fixture.State("smart")
state.inCombat = true
state.resource, state.resourceMax, state.resourceType = 100, 100, 3
XelAssist.Graph.ComboState:Attach(state, 3, "target-guid", {
    selectedExact = true,
    globalExact = true,
    source = "exact hostile combo owner",
})

local slice = Fixture.Action("Slice and Dice", 1, "buff", 0, 20, {
    self = true,
    combo = true,
    testDuration = 6,
    testDurationBase = 6,
    testDurationMax = 21,
    testDurationComboScaled = true,
})
Fixture:Use(state, { slice })

local descriptors = XelAssist.Graph.Targets:Targets(slice, state)
assert(table.getn(descriptors) == 1
    and descriptors[1].unit == "player"
    and descriptors[1].guid == "player-guid"
    and descriptors[1].relation == "self",
    "Slice and Dice must keep the player as its immutable cast recipient")

local candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
    slice, state, descriptors[1])
assert(candidate, "hostile-owned combo points must legalize a self finisher: "
    .. tostring(blocker))
assert(candidate.target == "player"
    and candidate.targetGUID == "player-guid"
    and candidate.targetRelation == "self"
    and candidate.comboTargetGUID == "target-guid",
    "the candidate must carry the self recipient and hostile combo owner separately")
assert(candidate.tooltip.duration == 15
    and candidate.tooltip.durationComboPoints == 3,
    "the self buff duration must use the hostile owner's three combo points")

local projected = XelAssist.Graph.Transitions:Advance(state, candidate)
local player = XelAssist.Graph.State:FriendlyByUnit(projected, "player")
assert(projected.resource == 80,
    "the self finisher must pay its energy cost exactly once")
assert(XelAssist.Graph.ComboState:Availability(projected, "target-guid") == 0
    and projected.combo == 0,
    "a landed self finisher must consume the hostile owner's combo points")
assert(player and player.auras and player.auras["Slice and Dice"]
    and player.auras["Slice and Dice"].duration == 15,
    "Slice and Dice must project its aura onto the player")
assert(not projected.auras["Slice and Dice"],
    "a self finisher must not project its buff onto the hostile aura table")

print("ok: Rogue self finisher keeps cast recipient and combo owner separate")
