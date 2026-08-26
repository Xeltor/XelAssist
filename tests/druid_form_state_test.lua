XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local classToken, exists, formID, primary = "DRUID", true, 1, 3
local powers = {
    [0] = { 137, 260 }, [1] = { 0, 100 }, [3] = { 42, 100 },
}
local powerCalls, maxCalls = 0, 0
UnitClass = function() return "Druid", classToken end
UnitExists = function() return exists end
GetShapeshiftFormID = function() return formID end
UnitPowerType = function() return primary, "ENERGY" end
UnitPower = function(_, powerType)
    powerCalls = powerCalls + 1
    return powers[powerType][1]
end
UnitPowerMax = function(_, powerType)
    maxCalls = maxCalls + 1
    return powers[powerType][2]
end
CancelShapeshiftForm = function() end

local definitions = {
    [768] = { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 1 } } },
    [5487] = { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 5 } } },
    [783] = { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 3 } } },
    [9001] = { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 1 },
            { kind = "shapeshift", form = 5 } } },
    [9002] = { complete = true, admissible = true,
        atoms = { { kind = "damage" } } },
    [9003] = { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 99 } } },
    [9004] = { complete = false, admissible = false,
        atoms = { { kind = "shapeshift", form = 1 },
            { kind = "modifier", modifier = "unknown" } } },
}
XelAssist.Game.SpellSemantics = {}
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    return definitions[spellId] or { complete = false,
        admissible = false, atoms = {} }
end

local costs = {
    [768] = { { type = 0, cost = 35 } },
    [5487] = { { type = 0, cost = 40 } },
    [783] = { { type = 0, cost = 20 } },
    [9001] = { { type = 0, cost = 1 } },
    [9002] = { { type = 0, cost = 1 } },
    [9003] = { { type = 0, cost = 1 } },
    [9004] = { { type = 0, cost = 1 } },
}
C_Spell = { GetSpellPowerCost = function(spellId) return costs[spellId] end }

dofile("Game/Player/DruidFormState.lua")
local Forms = XelAssist.Game.Player.DruidFormState

local cat = Forms:Snapshot()
assert(cat.available and cat.formID == 1 and cat.primaryType == 3
    and cat.powers[3].current == 42 and cat.powers[0].current == 137
    and cat.powers[0].maximum == 260 and powerCalls == 3 and maxCalls == 3,
    "Cat form must retain a bounded exact hidden-mana observation")

local shift, reason = Forms:PrepareShift(
    { name = "Bear Form", spellId = 5487 }, cat)
assert(shift and reason == nil and shift.sourceForm == 1
    and shift.targetForm == 5 and shift.targetPrimary == 1
    and shift.cost.type == 0 and shift.cost.cost == 40
    and shift.destinationPowerKnown == false,
    "a Bear transition must be funded from hidden mana and fail closed on destination rage")
assert(Forms:Apply(cat, shift) and cat.formID == 5
    and cat.powers[0].current == 97 and cat.primaryType == 1
    and cat.powers[1].current == nil
    and cat.powers[1].currentKnown == false,
    "projection must deduct hidden mana without inventing Bear rage or Furor")

local cancel
cancel, reason = Forms:PrepareCancel(cat)
assert(cancel and reason == nil and cancel.sourceForm == 5
    and cancel.targetForm == 0 and cancel.destinationPowerKnown,
    "a Druid form cancel must expose the exact preserved hidden mana")
assert(Forms:Apply(cat, cancel) and cat.formID == 0
    and cat.primaryType == 0 and cat.powers[0].current == 97,
    "cancel projection must return to caster mana without a fabricated cost")

formID, primary = 3, 0
powers[0], powers[1], powers[3] = { 50, 260 }, { 0, 100 }, { 0, 100 }
local travel = Forms:Snapshot()
shift, reason = Forms:PrepareShift({ name = "Incomplete", spellId = 9004 }, travel)
assert(shift == nil and reason == "shapeshift semantics are incomplete",
    "incomplete whole-spell semantics must fail closed before graph discovery")
shift, reason = Forms:PrepareShift({ name = "Travel Form", spellId = 783 }, travel)
assert(shift == nil and reason == "form already active",
    "the active form must not be recommended again")

powers[0][1] = 19
travel = Forms:Snapshot()
shift, reason = Forms:PrepareShift({ name = "Cat Form", spellId = 768 }, travel)
assert(shift == nil and reason == "hidden mana insufficient",
    "current mana-primary state must not disguise insufficient hidden mana")
powers[0][1] = 50

shift, reason = Forms:PrepareShift({ name = "Conflicting", spellId = 9001 }, travel)
assert(shift == nil and reason == "shapeshift spell has conflicting forms",
    "conflicting form atoms must fail closed")
shift, reason = Forms:PrepareShift({ name = "Not Form", spellId = 9002 }, travel)
assert(shift == nil and reason == "spell is not an exact shapeshift",
    "non-form spells must not enter the form transition model")
shift, reason = Forms:PrepareShift({ name = "Unknown Form", spellId = 9003 }, travel)
assert(shift == nil and reason == "shapeshift destination form is unresolved",
    "unknown installed-client form IDs must fail closed")

local oldCost = C_Spell.GetSpellPowerCost
C_Spell.GetSpellPowerCost = function() return { { type = 3, cost = 20 } } end
shift, reason = Forms:PrepareShift({ name = "Cat Form", spellId = 768 }, travel)
assert(shift == nil and reason == "shapeshift is not exactly mana funded",
    "resource type must come from the live effective-cost API")
C_Spell.GetSpellPowerCost = oldCost

primary = 3
formID = 5
local mismatch = Forms:Snapshot()
assert(not mismatch.available
    and mismatch.reason == "Druid form and primary power disagree",
    "form/power races must not publish an incoherent root")

classToken, formID, primary = "SHAMAN", 16, 0
local outsider = Forms:Snapshot()
assert(not outsider.available
    and outsider.reason == "player is not an exactly identified Druid",
    "the Druid form model must not absorb other shapeshift classes")

print("ok: exact Druid hidden-power and form transition evidence")
