XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
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

dofile("Combat/Observations.lua")
local action = { name = "Immolate" }
local fire = { school = 2 }
XelAssist.Combat.Observations:Submitted(action, "target", fire)
assert(XelAssist.Combat.Observations:CombatMessage("Your Immolate was resisted by Enemy.") == "retry")
assert(not XelAssist.Combat.Observations:Blocker(action, "target"), "a resist must permit immediate retry")
assert(XelAssist.Combat.Observations:ResistanceMultiplier(action, "target", fire) < 1,
    "a full resist must add target-school evidence")
assert(XelAssist.Combat.Observations:ResistanceMultiplier(action, "target", { school = 5 }) == 1,
    "resistance evidence must not leak to another damage school")
XelAssist.Combat.Observations:Submitted(action, "target", fire)
assert(XelAssist.Combat.Observations:CombatMessage("Your Immolate hits Enemy. (20 resisted)") == "partial resist",
    "partial mitigation must not be mistaken for a failed application")
local live = XelAssist.Combat.Observations:LiveResistances("target")
assert(live and live[3] == 150, "live target resistance vector was not discovered")
local liveMultiplier, source = XelAssist.Combat.Observations:ResistanceMultiplier(action, "target", fire,
    { targetResistances = live, playerLevel = 60 })
assert(liveMultiplier == 0.625 and source == "live resistance",
    "150 Fire resistance at level 60 should estimate 37.5 percent average mitigation")
local missOutcome, missTarget, missSpell = XelAssist.Combat.Observations:SpellMiss(348, "target-a", 2)
assert(missOutcome == "retry" and missTarget == "target-a" and missSpell == "Immolate",
    "numeric Nampower resist events must retain spell and target identity")
local beforeOrdinaryMiss = XelAssist.Combat.Observations:ResistanceMultiplier(action, "target", fire)
missOutcome, missTarget, missSpell = XelAssist.Combat.Observations:SpellMiss(348, "target-a", 1)
assert(missOutcome == "retry" and missTarget == "target-a" and missSpell == "Immolate",
    "ordinary numeric Nampower misses must also permit a clean retry")
assert(XelAssist.Combat.Observations:ResistanceMultiplier(action, "target", fire) == beforeOrdinaryMiss,
    "legacy fallback must not reinterpret an ordinary miss as school resistance")

XelAssist.Combat.Observations:Submitted(action, "target", fire)
assert(XelAssist.Combat.Observations:CombatMessage("Enemy is immune to your Immolate.") == "immune")
assert(XelAssist.Combat.Observations:Blocker(action, "target") == "observed immunity")
XelAssistTestGUID = "target-b"
assert(not XelAssist.Combat.Observations:Blocker(action, "target"), "immunity must be target scoped")

XelAssist.Combat.Observations:Submitted(action, "target", fire)
XelAssist.Combat.Observations:Submitted({ name = "Arcane Intellect" }, "player", {})
assert(not XelAssist.Combat.Observations:ErrorMessage(SPELL_FAILED_LINE_OF_SIGHT)
    and not XelAssist.Combat.Observations:Blocker(action, "target"),
    "an off-target submission must retire stale hostile UI-error correlation")

XelAssist.Combat.Observations:Submitted(action, "target", fire)
assert(XelAssist.Combat.Observations:ErrorMessage(SPELL_FAILED_LINE_OF_SIGHT) == "line of sight")
assert(XelAssist.Combat.Observations:Blocker(action, "target") == "line of sight")
assert(not XelAssist.Combat.Observations:Blocker({ name = "Firebolt", actor = "pet" }, "target"),
    "player line-of-sight failure must not block an independently positioned pet")
XelAssistTestTime = 12
assert(not XelAssist.Combat.Observations:Blocker(action, "target"), "line-of-sight evidence must expire")

local opaqueTarget = {}
XelAssistTestGUID, XelAssistTestTime = opaqueTarget, 20
XelAssist.Combat.Observations:Submitted(action, "target", fire)
assert(XelAssist.Combat.Observations:CombatMessage(
    "Enemy is immune to your Immolate.") == "immune"
    and XelAssist.Combat.Observations:Blocker(action, "target") == "observed immunity",
    "observation keys must accept an opaque SuperWoW target identity")
XelAssistTestGUID = {}
assert(not XelAssist.Combat.Observations:Blocker(action, "target"),
    "opaque target identities must remain isolated without stringification")
print("ok: target-scoped resist, immunity and line-of-sight observations")
