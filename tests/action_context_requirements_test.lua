-- Shared legality must carry exact DBC stance and equipment constraints through
-- the production Targets path, including future graph nodes.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local defensiveMask = 131072
local shield = { classificationKnown = true, classID = 4,
    subClassID = 6, inventoryType = 14, broken = false }
local empty = { classificationKnown = true, empty = true }
local sword = { classificationKnown = true, classID = 2,
    subClassID = 7, inventoryType = 13, broken = false }
local action = Fixture.Action("Opaque defensive strike", 1, "damage", 40, 5, {
    melee = true, effectMaxRange = 5,
    testStances = defensiveMask,
    testEquippedItemClass = 4,
    testEquippedItemSubClassMask = 64,
    testEquippedItemInventoryTypeMask = 16384,
})
local state = Fixture.State("smart")
state.targetDistance, state.targetDistanceKind = 3, "hitbox"
state.distance, state.distanceKind = 3, "hitbox"
state.playerForm = { available = true, formID = 17 }
state.inventory = { mainHand = sword, offHand = empty, ranged = empty,
    ammo = { known = true, count = 0 }, itemCounts = {}, reagentCounts = {} }
Fixture:Use(state, { action })
local descriptor = XelAssist.Graph.Targets:Targets(action, state)[1]

local legal, reason = XelAssist.Graph.Targets:Legal(action, state, descriptor)
assert(not legal and reason == "required player form inactive",
    "a mismatched exact stance must block before later graph scoring")

state.playerForm.formID = 18
legal, reason = XelAssist.Graph.Targets:Legal(action, state, descriptor)
assert(not legal and reason == "required equipment missing or broken",
    "matching stance must not bypass a missing exact shield")

state.inventory.offHand = shield
legal, reason = XelAssist.Graph.Targets:Legal(action, state, descriptor)
assert(legal and reason == nil,
    "matching exact stance and shield must admit the ordinary graph edge")

state.time = 8
state.playerForm.formID, state.inventory.offHand = 17, empty
legal, reason = XelAssist.Graph.Targets:Legal(action, state, descriptor)
assert(not legal and reason == "required player form inactive",
    "advancing time must not erase an unchanged stance requirement")

print("ok: production legality preserves exact form and equipment constraints")
