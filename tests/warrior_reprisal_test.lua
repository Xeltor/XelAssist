XelAssist = { Game = { Player = {} }, Graph = {} }
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {
    [51593] = { attributes = 464, procFlags = 16, procChance = 50,
        procCharges = 0, durationIndex = 21, spellFamilyName = 4,
        effect = t(6, 6), effectDieSides = t(1, 1),
        effectBaseDice = t(1, 1), effectBasePoints = t(24, 0),
        effectImplicitTargetA = t(1, 1), effectApplyAuraName = t(108, 4),
        effectMiscValue = t(), effectTriggerSpell = t() },
    [51594] = { attributes = 464, procFlags = 16, procChance = 100,
        procCharges = 0, durationIndex = 21, spellFamilyName = 4,
        effect = t(6, 6), effectDieSides = t(1, 1),
        effectBaseDice = t(1, 1), effectBasePoints = t(49, 0),
        effectImplicitTargetA = t(1, 1), effectApplyAuraName = t(108, 4),
        effectMiscValue = t(), effectTriggerSpell = t() },
}
function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
local class, rank = "WARRIOR", 2
function UnitClass() return "Warrior", class end
function IsPlayerSpell(id)
    return rank == 2 and id == 51594 or rank == 1 and id == 51593
end
function GetSpellModifiers(_, operation)
    assert(operation == 0)
    return 0, rank == 2 and 50 or rank == 1 and 25 or 0,
        rank > 0 and 1 or 0
end

dofile("Game/Player/WarriorReprisal.lua")
local Runtime = XelAssist.Game.Player.WarriorReprisal
local action = { spellId = 6572,
    facts = { warriorRevengeThreat = true, kind = "damage" } }
local rankTwo = Runtime:CaptureFacts(action, action.facts)
assert(rankTwo.warriorReprisalEvidence.available
    and rankTwo.warriorReprisalEvidence.exact
    and rankTwo.warriorReprisalEvidence.rank == 2
    and rankTwo.warriorReprisalEvidence.damagePercent == 50
    and rankTwo.warriorReprisalEvidence.refundChance == 1
    and rankTwo.warriorReprisalEvidence.refundMode
        == "withheld-private-success-trigger",
    "rank two must seal exact damage while withholding its private refund")
rank = 1
local rankOne = Runtime:CaptureFacts(action, action.facts)
assert(rankOne.warriorReprisalEvidence.rank == 1
    and rankOne.warriorReprisalEvidence.damagePercent == 25
    and rankOne.warriorReprisalEvidence.refundChance == 0.5,
    "rank one must retain its distinct damage and refund chance")
rank = 0
local absent = Runtime:CaptureFacts(action, action.facts)
assert(absent.warriorReprisalEvidence.available
    and absent.warriorReprisalEvidence.exact
    and not absent.warriorReprisalEvidence.learned,
    "an unlearned talent must be exact")
class, rank = "MAGE", 2
assert(not Runtime:CaptureFacts(action, action.facts)
    .warriorReprisalEvidence.available,
    "another class must not inherit Reprisal")
class = "WARRIOR"

dofile("Graph/WarriorReprisal.lua")
local Graph = XelAssist.Graph.WarriorReprisal
local adjusted, applied = Graph:AdjustPower(action, rankTwo, 100)
assert(applied and adjusted == 150,
    "rank two must multiply Revenge power exactly once")
adjusted, applied = Graph:AdjustPower(action, rankOne, 100)
assert(applied and adjusted == 125,
    "rank one must multiply Revenge power exactly once")
adjusted, applied = Graph:AdjustPower(action, absent, 100)
assert(not applied and adjusted == 100,
    "an unlearned Reprisal must leave Revenge unchanged")
rankTwo.warriorReprisalEvidence.damageModifier.percent = 49
adjusted, applied = Graph:AdjustPower(action, rankTwo, 100)
assert(not applied and adjusted == 100,
    "forged engine modifier evidence must fail closed")
print("ok: exact Reprisal Revenge damage with private refund withheld")
