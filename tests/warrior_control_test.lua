XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local ranks = {
    [1715] = { level = 8, damage = 5, slow = 40 },
    [7372] = { level = 32, damage = 18, slow = 45 },
    [7373] = { level = 54, damage = 45, slow = 50 },
}
local rows = {}

local function fill(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

local common = {
    school = 0, category = 1166, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 134218240,
    attributesEx2 = 0, attributesEx3 = 1032, attributesEx4 = 0,
    stances = 327680, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0, durationIndex = 8,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 101, procCharges = 0, maxLevel = 0,
    powerType = 1, manaCost = 100, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 2,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = 2, equippedItemSubClassMask = 173555,
    equippedItemInventoryTypeMask = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 4,
    spellFamilyFlags = 2, spellFamilyFlags2 = 0,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
    stanceBarOrder = 4294967295,
}

for spellId, rank in pairs(ranks) do
    local row = fill(common)
    row.baseLevel, row.spellLevel = rank.level, rank.level
    row.effect = { 2, 6, 0 }
    row.effectDieSides, row.effectBaseDice = { 1, 1, 0 }, { 1, 1, 0 }
    row.effectDicePerLevel, row.effectRealPointsPerLevel =
        { 0, 0, 0 }, { 0, 0, 0 }
    row.effectBasePoints = { rank.damage - 1,
        4294967296 - rank.slow - 1, 0 }
    row.effectMechanic = { 0, 11, 0 }
    row.effectImplicitTargetA = { 6, 6, 0 }
    row.effectImplicitTargetB, row.effectRadiusIndex = { 0, 0, 0 }, { 0, 0, 0 }
    row.effectApplyAuraName = { 0, 33, 0 }
    row.effectAmplitude, row.effectMultipleValue = { 0, 0, 0 }, { 0, 0, 0 }
    row.effectChainTarget, row.effectItemType = { 0, 0, 0 }, { 0, 0, 0 }
    row.effectMiscValue, row.effectTriggerSpell = { 0, 0, 0 }, { 0, 0, 0 }
    row.effectPointsPerComboPoint = { 0, 0, 0 }
    rows[spellId] = row
end

rows[676] = {
    school = 0, category = 109, castUI = 0, dispel = 0, mechanic = 3,
    attributes = 327696, attributesEx = 134218240,
    attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
    stances = 131072, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 60000, durationIndex = 1,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 101, procCharges = 0, maxLevel = 0,
    powerType = 1, manaCost = 200, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 2,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = -1, equippedItemSubClassMask = 0,
    equippedItemInventoryTypeMask = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 4,
    spellFamilyFlags = 512, spellFamilyFlags2 = 0,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
    stanceBarOrder = 4294967295,
    baseLevel = 18, spellLevel = 18,
    effect = { 6, 0, 0 }, effectBasePoints = { 4294967295, 0, 0 },
    effectDieSides = { 1, 0, 0 }, effectBaseDice = { 1, 0, 0 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectMechanic = { 0, 0, 0 },
    effectImplicitTargetA = { 6, 0, 0 },
    effectImplicitTargetB = { 0, 0, 0 }, effectRadiusIndex = { 0, 0, 0 },
    effectApplyAuraName = { 67, 0, 0 },
    effectAmplitude = { 0, 0, 0 }, effectMultipleValue = { 0, 0, 0 },
    effectChainTarget = { 0, 0, 0 }, effectItemType = { 0, 0, 0 },
    effectMiscValue = { 0, 0, 0 }, effectTriggerSpell = { 0, 0, 0 },
    effectPointsPerComboPoint = { 0, 0, 0 },
}

GetSpellRecField = function(spellId, field, array)
    local value = rows[spellId] and rows[spellId][field]
    if array == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellRangeData = function(index)
    assert(index == 2, "unexpected Warrior control range")
    return 0, 5
end
GetSpellDuration = function(spellId)
    return spellId == 676 and 10000 or 15000
end
UnitClass = function() return "Warrior", "WARRIOR" end

dofile("Game/Player/WarriorControl.lua")
local C = XelAssist.Game.Player.WarriorControl

for spellId, rank in pairs(ranks) do
    local facts, reason, handled = C:InferKnowledge(spellId)
    assert(facts and reason == nil and handled == true
        and facts.kind == "damage" and facts.warriorHamstring == true
        and facts.noWeaponDamageFallback == true
        and facts.targetMovementSlowPercent == rank.slow
        and facts.targetMovementSlowValueUnknown == true,
        "exact Hamstring ranks must expose damage without proxy slow value")
    local evidence = facts.warriorControlEvidence
    assert(evidence.damage == rank.damage and evidence.cost == 10
        and evidence.duration == 15 and evidence.stances == 327680,
        "Hamstring must retain exact packet and legality")
end

local disarm, reason, handled = C:InferKnowledge(676)
assert(disarm == nil and handled == true
    and reason == "hostile weapon state and Disarm consequence unavailable",
    "Disarm must be recognized but withheld without hostile weapon evidence")
local evidence = C:Classify(676)
assert(evidence and evidence.valid == true and evidence.cooldown == 60
    and evidence.duration == 10 and evidence.stances == 131072,
    "Disarm identity and legality must remain exact")

rows[1715].effectApplyAuraName[2] = 31
C:Invalidate()
local shifted, shiftedReason, shiftedHandled = C:InferKnowledge(1715)
assert(shifted == nil and shiftedHandled == true
    and shiftedReason == "Warrior hamstring DBC topology is incomplete",
    "shifted Hamstring topology must fail closed")

print("ok: exact Hamstring packets and fail-closed Disarm boundary")
