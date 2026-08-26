local function check(value, message) if not value then error(message) end end
XelAssist = { Game = { Player = {} } }
local class, changed = "WARRIOR", nil
function UnitClass() return "Warrior", class end
function GetSpellRangeData(index) check(index == 2, "wrong range row"); return 0, 5 end

local ranks = { [72] = { 1, 12, 6 }, [1671] = { 2, 32, 18 },
    [1672] = { 3, 52, 45 } }
local common = { school=0, category=88, attributes=327696,
    attributesEx=134218240, attributesEx2=0, attributesEx3=8,
    attributesEx4=0, stances=196608, stancesNot=0,
    castingTimeIndex=1, recoveryTime=0, categoryRecoveryTime=12000,
    durationIndex=32, powerType=1, manaCost=100, rangeIndex=2,
    equippedItemClass=4, equippedItemSubClassMask=64,
    equippedItemInventoryTypeMask=0, startRecoveryCategory=133,
    startRecoveryTime=1500, spellFamilyName=4, spellFamilyFlags=2048,
    dmgClass=2, preventionType=2 }
function GetSpellRecField(id, field, array)
    local rank = ranks[id]; if not rank then return nil end
    if changed == field then return 999 end
    if not array then
        if field == "baseLevel" or field == "spellLevel" then return rank[2] end
        return common[field]
    end
    if field == "effect" then return {68,2,0} end
    if field == "effectDieSides" then return {1,1,0} end
    if field == "effectBasePoints" then return {4294967295,rank[3]-1,0} end
    if field == "effectMechanic" then return {26,0,0} end
    if field == "effectImplicitTargetA" then return {6,6,0} end
    return {0,0,0}
end

dofile("Game/Player/WarriorShieldBash.lua")
local B = XelAssist.Game.Player.WarriorShieldBash
for id, rank in pairs(ranks) do
    local found, reason, handled = B:Classify(id)
    check(found and handled and not reason and found.exact, "rank not classified")
    check(found.rank == rank[1] and found.damage == rank[3]
        and found.cost == 10 and found.cooldown == 12
        and found.requiresShield and found.interruptsSpellcasting
        and found.actionSpecificThreatKnown == false, "rank facts shifted")
    local facts = B:InferKnowledge(id)
    check(facts and facts.kind == "damage" and facts.interrupt
        and facts.requiresShield and facts.usesWeaponSkill
        and facts.threat == nil and facts.requiresExactUsability,
        "unsafe Shield Bash inference")
end
local _, _, foreign = B:Classify(9999)
check(foreign == false, "foreign spell claimed")
B:Invalidate(); changed = "equippedItemClass"
local found, reason, handled = B:Classify(72)
check(not found and handled and reason == "Shield Bash DBC topology is incomplete",
    "shifted shield requirement must fail closed")
changed = nil; B:Invalidate(); class = "MAGE"
local _, _, nonWarrior = B:InferKnowledge(72)
check(nonWarrior == false, "non-Warrior spell claimed")
class = "WARRIOR"
dofile("Game/ActionInference.lua")
local inferred, inferenceReason, inferenceHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(72)
check(inferred and not inferenceReason and inferenceHandled
    and inferred.warriorShieldBash and inferred.interrupt,
    "root class inference must own exact Shield Bash")
print("ok: exact Shield Bash ranks, shield legality and interrupt inference")
