table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local row = {
    school = 0, category = 0, mechanic = 0, attributes = 2424848,
    attributesEx = 134218240, attributesEx2 = 0, attributesEx3 = 1024,
    attributesEx4 = 0, stances = 0, stancesNot = 0,
    castingTimeIndex = 1, recoveryTime = 15000, categoryRecoveryTime = 0,
    durationIndex = 0, powerType = 3, manaCost = 10, manaCostPerlevel = 0,
    baseLevel = 22, spellLevel = 22, maxLevel = 0, rangeIndex = 2,
    spellFamilyName = 8, spellFamilyFlags = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1000,
    dmgClass = 2, preventionType = 2, equippedItemClass = 2,
    equippedItemSubClassMask = 173555,
    effect = triple(31, 80), effectDieSides = triple(1, 1, 1),
    effectBaseDice = triple(1, 1, 1), effectDicePerLevel = triple(),
    effectRealPointsPerLevel = triple(), effectBasePoints = triple(89),
    effectImplicitTargetA = triple(6, 6), effectImplicitTargetB = triple(),
    effectApplyAuraName = triple(), effectTriggerSpell = triple(),
}
local reads, class = 0, "ROGUE"
function GetSpellRecField(id, field, copied)
    reads = reads + 1
    if id ~= 45603 then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellRangeData(index)
    reads = reads + 1
    assert(index == 2)
    return 0, 5
end
function UnitClass() return "localized", class end

dofile("Game/Player/RogueSurpriseAttack.lua")
local Surprise = XelAssist.Game.Player.RogueSurpriseAttack
local profile = assert(Surprise:Profile())
assert(profile.weaponPercent == 90 and profile.comboGain == 1
    and profile.energyCost == 10 and profile.cooldown == 15
    and profile.bypassesDodge and profile.bypassesParry
    and profile.bypassesBlock and not profile.bypassesOrdinaryMiss
    and profile.requiresMainHandWeapon,
    "installed topology must expose one point and only proven avoidance bypasses")

local facts, reason, handled = Surprise:InferKnowledge(45603)
assert(facts and reason == nil and handled and facts.kind == "builder"
    and facts.comboBuilder and facts.weaponHand == "main"
    and facts.deliveryModel == "physical" and facts.usesWeaponSkill
    and facts.alwaysHit == false and facts.bypassesDodge
    and facts.bypassesParry and facts.bypassesBlock,
    "inference must retain the ordinary miss roll while removing avoidance")
assert(Surprise:InferKnowledge(45604) == nil,
    "another Octo Rogue action must not enter Surprise Attack inference")

class = "WARRIOR"
local foreign, _, foreignHandled = Surprise:InferKnowledge(45603)
assert(foreign == nil and not foreignHandled,
    "another class must not claim the exact Rogue action")
class = "ROGUE"

Surprise:Invalidate()
row.effectBasePoints[1] = 90
local malformed, malformedReason = Surprise:Profile()
assert(malformed == nil
    and malformedReason == "Surprise Attack DBC topology is incomplete",
    "a recognized shifted row must fail closed instead of falling through")
row.effectBasePoints[1] = 89
Surprise:Invalidate()
facts = assert(Surprise:InferKnowledge(45603))

XelAssist.Combat = {}
dofile("Combat/Delivery.lua")
local delivery = XelAssist.Combat.Delivery:PhysicalContext(
    { actor = "player", facts = facts }, {}, {
        actor = "player", level = 22, deliverySubtype = "melee",
        deliveryModelKnown = true, frozenStateEvidence = true,
        weaponSkills = { main = { total = 110, known = true },
            mainToken = "dagger", formWeaponUseKnown = true },
        hitBonuses = { equipmentKnown = true, totalKnown = false, melee = 0 },
        positionKnown = true, behindTarget = false,
    }, { level = 22, isPlayer = false })
assert(delivery.avoidanceBypassed == true and delivery.alwaysHit == false
    and string.find(delivery.priorGaps, "mechanic resistance", 1, true)
    and not string.find(delivery.priorGaps, "active defenses", 1, true),
    "avoidance immunity must retain ordinary miss and mechanic uncertainty")

XelAssist.Graph.ComboState = nil
dofile("Graph/ComboState.lua")
local Combo = XelAssist.Graph.ComboState
local state = { targetGUID = "enemy", combo = 0 }
Combo:Attach(state, 0, nil)
local candidate = { action = { facts = facts }, tooltip = { comboGain = 1 },
    targetGUID = "enemy", targetRelation = "hostile",
    resistance = { landChance = 0.75 } }
assert(Combo:Apply(state, candidate, facts))
local branches = state.comboBranches
assert(#branches == 2
    and branches[1].points == 0 and branches[1].probability == 0.25
    and branches[2].targetGUID == "enemy" and branches[2].points == 1
    and branches[2].probability == 0.75,
    "one combo point must be awarded only on uncertain delivered hits")

print("ok: exact Surprise Attack builder and conservative delivery")
