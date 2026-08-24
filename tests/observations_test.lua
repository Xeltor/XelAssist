GetTime = function() return XelAssistTestTime or 10 end
UnitExists = function(unit)
    if unit == "target" then return true, XelAssistTestGUID or "target-a" end
    return unit == "player", unit == "player" and "player" or nil
end
GetUnitField = function(unit, field)
    if unit == "target" and field == "resistances" then return { 0, 0, 150, 0, 0, 0, 0 } end
end
SpellInfo = function(id) return id == 348 and "Immolate" or "Spell" end
GetSpellRecField = function(_, field) if field == "school" then return 2 end end
SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight"

dofile("XelAssist_Observations.lua")
local action = { name = "Immolate" }
local fire = { school = 2 }
XelAssistObservations:Submitted(action, "target", fire)
assert(XelAssistObservations:CombatMessage("Your Immolate was resisted by Enemy.") == "retry")
assert(not XelAssistObservations:Blocker(action, "target"), "a resist must permit immediate retry")
assert(XelAssistObservations:ResistanceMultiplier(action, "target", fire) < 1,
    "a full resist must add target-school evidence")
assert(XelAssistObservations:ResistanceMultiplier(action, "target", { school = 5 }) == 1,
    "resistance evidence must not leak to another damage school")
XelAssistObservations:Submitted(action, "target", fire)
assert(XelAssistObservations:CombatMessage("Your Immolate hits Enemy. (20 resisted)") == "partial resist",
    "partial mitigation must not be mistaken for a failed application")
local live = XelAssistObservations:LiveResistances("target")
assert(live and live[3] == 150, "live target resistance vector was not discovered")
local liveMultiplier, source = XelAssistObservations:ResistanceMultiplier(action, "target", fire,
    { targetResistances = live, playerLevel = 60 })
assert(liveMultiplier == 0.625 and source == "live resistance",
    "150 Fire resistance at level 60 should estimate 37.5 percent average mitigation")
local missOutcome, missTarget, missSpell = XelAssistObservations:SpellMiss(348, "target-a", 2)
assert(missOutcome == "retry" and missTarget == "target-a" and missSpell == "Immolate",
    "numeric Nampower resist events must retain spell and target identity")
local beforeOrdinaryMiss = XelAssistObservations:ResistanceMultiplier(action, "target", fire)
missOutcome, missTarget, missSpell = XelAssistObservations:SpellMiss(348, "target-a", 1)
assert(missOutcome == "retry" and missTarget == "target-a" and missSpell == "Immolate",
    "ordinary numeric Nampower misses must also permit a clean retry")
assert(XelAssistObservations:ResistanceMultiplier(action, "target", fire) == beforeOrdinaryMiss,
    "legacy fallback must not reinterpret an ordinary miss as school resistance")

XelAssistObservations:Submitted(action, "target", fire)
assert(XelAssistObservations:CombatMessage("Enemy is immune to your Immolate.") == "immune")
assert(XelAssistObservations:Blocker(action, "target") == "observed immunity")
XelAssistTestGUID = "target-b"
assert(not XelAssistObservations:Blocker(action, "target"), "immunity must be target scoped")

XelAssistObservations:Submitted(action, "target", fire)
XelAssistObservations:Submitted({ name = "Arcane Intellect" }, "player", {})
assert(not XelAssistObservations:ErrorMessage(SPELL_FAILED_LINE_OF_SIGHT)
    and not XelAssistObservations:Blocker(action, "target"),
    "an off-target submission must retire stale hostile UI-error correlation")

XelAssistObservations:Submitted(action, "target", fire)
assert(XelAssistObservations:ErrorMessage(SPELL_FAILED_LINE_OF_SIGHT) == "line of sight")
assert(XelAssistObservations:Blocker(action, "target") == "line of sight")
assert(not XelAssistObservations:Blocker({ name = "Firebolt", actor = "pet" }, "target"),
    "player line-of-sight failure must not block an independently positioned pet")
XelAssistTestTime = 12
assert(not XelAssistObservations:Blocker(action, "target"), "line-of-sight evidence must expire")
print("ok: target-scoped resist, immunity and line-of-sight observations")
