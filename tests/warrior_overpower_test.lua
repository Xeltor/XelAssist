XelAssist = { Game = { Player = {} }, Graph = {} }
local class, changed = "WARRIOR", nil
function UnitClass() return "Warrior", class end
function GetSpellRangeData(index) assert(index == 2); return 0, 5 end

local ranks = {
    [7384] = { rank = 1, level = 12, bonus = 5 },
    [7887] = { rank = 2, level = 28, bonus = 15 },
    [11584] = { rank = 3, level = 44, bonus = 25 },
    [11585] = { rank = 4, level = 60, bonus = 35 },
}
local common = {
    school=0, category=65, castUI=0, dispel=0, mechanic=0,
    attributes=2424848, attributesEx=1209008640,
    attributesEx2=0, attributesEx3=0, attributesEx4=512, stances=65536,
    stancesNot=0, targets=0, targetCreatureType=0, requiresSpellFocus=0,
    casterAuraState=0, targetAuraState=0, castingTimeIndex=1,
    recoveryTime=0, categoryRecoveryTime=5000, interruptFlags=0,
    auraInterruptFlags=0, channelInterruptFlags=0, procFlags=0,
    procChance=101, procCharges=0, maxLevel=0, durationIndex=0,
    powerType=1, manaCost=50, manaCostPerlevel=0, manaPerSecond=0,
    manaPerSecondPerLevel=0, rangeIndex=2, speed=0, modalNextSpell=0,
    stackAmount=0, equippedItemClass=2,
    equippedItemSubClassMask=173555, equippedItemInventoryTypeMask=0,
    manaCostPercentage=0, startRecoveryCategory=133, startRecoveryTime=1500,
    maxTargetLevel=0, spellFamilyName=4, spellFamilyFlags=4,
    maxAffectedTargets=0, dmgClass=2, preventionType=2,
}
function GetSpellRecField(id, field, array)
    local rank = ranks[id]; if not rank then return nil end
    if changed == field then return 999 end
    if not array then
        if field == "baseLevel" or field == "spellLevel" then return rank.level end
        return common[field]
    end
    local value = {0,0,0}
    if field == "effect" then value={121,0,0}
    elseif field == "effectDieSides" or field == "effectBaseDice" then value={1,0,0}
    elseif field == "effectBasePoints" then value={rank.bonus-1,0,0}
    elseif field == "effectImplicitTargetA" then value={6,0,0} end
    return value
end

dofile("Game/Player/WarriorOverpower.lua")
local O = XelAssist.Game.Player.WarriorOverpower
for id, rank in pairs(ranks) do
    local found, reason, handled = O:Classify(id)
    assert(found and handled and not reason and found.exact
        and found.rank == rank.rank and found.bonusDamage == rank.bonus
        and found.normalizedWeaponDamage and found.requiresDodgeReaction
        and found.casterAuraState == 0 and found.cost == 5
        and found.actionSpecificThreatKnown == false)
    local facts = O:InferKnowledge(id)
    assert(facts and facts.warriorOverpower and facts.kind == "damage"
        and facts.reactive and facts.requiresExactUsability
        and facts.normalizedWeaponDamage and facts.usesWeaponSkill
        and facts.threat == nil)
end
assert(select(3, O:Classify(9999)) == false)
O:Invalidate(); changed = "attributesEx"
local found, reason, handled = O:Classify(7384)
assert(not found and handled and reason == "Overpower DBC topology is incomplete",
    "recognized shifted topology must fail closed")
changed = nil; O:Invalidate(); class = "MAGE"
assert(select(3, O:InferKnowledge(7384)) == false,
    "non-Warriors must not claim Warrior identities")
print("ok: exact Overpower ranks and dodge-reactive inference")
