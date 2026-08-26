XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local ranks = {
    [23922] = { level = 30, base = 174, die = 11 },
    [23923] = { level = 38, base = 225, die = 11 },
    [23924] = { level = 46, base = 264, die = 13 },
    [23925] = { level = 54, base = 303, die = 15 },
    [52315] = { level = 60, base = 342, die = 17 },
}

local scalars = {
    school = 0, category = 971, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 134218240,
    attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
    stances = 0, stancesNot = 0, targets = 0, targetCreatureType = 0,
    requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 6000,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 101, procCharges = 0, maxLevel = 0,
    durationIndex = 0, powerType = 1, manaCost = 200,
    manaCostPerlevel = 0, manaPerSecond = 0, manaPerSecondPerLevel = 0,
    rangeIndex = 2, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = 4, equippedItemSubClassMask = 64,
    equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    maxTargetLevel = 0, spellFamilyName = 4,
    spellFamilyFlags = 33554432, spellFamilyFlags2 = 1,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
}

local rows = {}
for spellId, rank in pairs(ranks) do
    local row, key, value = {}, nil, nil
    for key, value in pairs(scalars) do row[key] = value end
    row.baseLevel, row.spellLevel = rank.level, rank.level
    row.effect = { 38, 2, 0 }
    row.effectDieSides = { 1, rank.die, 0 }
    row.effectBaseDice = { 1, 1, 0 }
    row.effectDicePerLevel = { 0, 0, 0 }
    row.effectRealPointsPerLevel = { 0, 0, 0 }
    row.effectBasePoints = { 0, rank.base - 1, 0 }
    row.effectMechanic = { 0, 0, 0 }
    row.effectImplicitTargetA = { 6, 6, 0 }
    row.effectImplicitTargetB = { 0, 0, 0 }
    row.effectRadiusIndex = { 0, 0, 0 }
    row.effectApplyAuraName = { 0, 0, 0 }
    row.effectAmplitude = { 0, 0, 0 }
    row.effectChainTarget = { 0, 0, 0 }
    row.effectItemType = { 0, 0, 0 }
    row.effectMiscValue = { 1, 0, 0 }
    row.effectTriggerSpell = { 0, 0, 0 }
    row.effectPointsPerComboPoint = { 0, 0, 0 }
    rows[spellId] = row
end

rows[51598] = {
    procFlags = 16, procChance = 100,
    effect = { 6, 6, 0 }, effectBasePoints = { -751, 0, 0 },
    effectApplyAuraName = { 107, 42, 0 }, effectMiscValue = { 11, 0, 0 },
    effectTriggerSpell = { 0, 51596, 0 },
}
rows[51599] = {
    procFlags = 16, procChance = 100,
    effect = { 6, 6, 0 }, effectBasePoints = { -1501, 0, 0 },
    effectApplyAuraName = { 107, 42, 0 }, effectMiscValue = { 11, 0, 0 },
    effectTriggerSpell = { 0, 51597, 0 },
}
rows[51596] = {
    procFlags = 680, procCharges = 1, durationIndex = 557,
    equippedItemClass = 4, equippedItemSubClassMask = 64,
    effect = { 6, 0, 0 }, effectApplyAuraName = { 51, 0, 0 },
    effectBasePoints = { 34, 0, 0 },
}
rows[51597] = {
    procFlags = 680, procCharges = 1, durationIndex = 557,
    equippedItemClass = 4, equippedItemSubClassMask = 64,
    effect = { 6, 0, 0 }, effectApplyAuraName = { 51, 0, 0 },
    effectBasePoints = { 69, 0, 0 },
}

GetSpellRecField = function(spellId, field, array)
    local value = rows[spellId] and rows[spellId][field]
    if array == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellRangeData = function(index)
    assert(index == 2, "unexpected Shield Slam range index")
    return 0, 5
end
UnitClass = function() return "Warrior", "WARRIOR" end
local learned = {}
IsPlayerSpell = function(spellId) return learned[spellId] == true end

dofile("Game/Player/WarriorShieldSlam.lua")
local S = XelAssist.Game.Player.WarriorShieldSlam

for spellId, rank in pairs(ranks) do
    local facts, reason, handled = S:InferKnowledge(spellId)
    assert(facts and reason == nil and handled == true
        and facts.kind == "damage" and facts.warriorShieldSlam == true
        and facts.requiresShield == true and facts.noWeaponDamageFallback == true
        and facts.threat == nil and facts.supplementalThreatUnknown == true,
        "each exact Shield Slam rank must be admitted without invented threat")
    local evidence = S:Evidence(facts)
    assert(evidence and evidence.damageMinimum == rank.base
        and evidence.damageMaximum == rank.base + rank.die - 1
        and evidence.cost == 20 and evidence.cooldown == 6
        and evidence.magicDispelCount == 1
        and evidence.magicDispelProbabilityKnown == false,
        "Shield Slam must retain exact base packet and explicit private gaps")
end


local shieldAction = { facts = S:InferKnowledge(23922) }
local baseFacts = { categoryCooldown = 6 }
assert(S:CaptureFacts(shieldAction, baseFacts).categoryCooldown == 6,
    "unlearned Improved Shield Slam must retain the base cooldown")
learned[51598] = true
local rankOne = S:CaptureFacts(shieldAction, { categoryCooldown = 6 })
assert(rankOne.categoryCooldown == 5.25
    and rankOne.improvedShieldSlamEvidence.rank == 1
    and rankOne.improvedShieldSlamEvidence.procValueKnown == false,
    "rank one must reduce cooldown without inventing block value")
learned[51599] = true
local rankTwo = S:CaptureFacts(shieldAction, { categoryCooldown = 6 })
assert(rankTwo.categoryCooldown == 4.5
    and rankTwo.improvedShieldSlamEvidence.rank == 2,
    "highest learned exact talent rank must own the cooldown")
rows[51599].effectTriggerSpell[2] = 51596
S:Invalidate()
local shiftedTalent = S:CaptureFacts(shieldAction, { categoryCooldown = 6 })
assert(shiftedTalent.categoryCooldown == 6
    and shiftedTalent.improvedShieldSlamEvidence == nil,
    "shifted talent topology must fail closed to the base cooldown")
rows[51599].effectTriggerSpell[2] = 51597
S:Invalidate()

rows[23922].effectMiscValue[1] = 2
S:Invalidate()
local shifted, reason, handled = S:InferKnowledge(23922)
assert(shifted == nil and handled == true
    and reason == "Shield Slam DBC topology is incomplete",
    "a shifted Shield Slam row must fail closed without localized fallback")
rows[23922].effectMiscValue[1] = 1
S:Invalidate()

local weaponCalls = 0
XelAssist.Game.Capabilities = {
    WeaponDamage = function()
        weaponCalls = weaponCalls + 1
        return 999
    end,
    BonusDamage = function() return 0 end,
}
dofile("Graph/ActionPower.lua")
local action = { rank = 1, actor = "player", facts = {
    kind = "damage", melee = true, school = 0,
    noWeaponDamageFallback = true } }
local power = XelAssist.Graph.ActionPower:Estimate(
    action, { dbcAverage = 180, school = 0 }, {}, nil, false, nil)
assert(power == 180 and weaponCalls == 0,
    "Shield Slam base damage must not receive generic main-hand damage")

dofile("Game/RootPowerEvidence.lua")
local observed = { powerRecords = {} }
local captured = XelAssist.Game.RootPowerEvidence:Capture(observed, action,
    { dbcAverage = 180, school = 0 }, "shield-slam")
assert(captured.dbcWeaponCaptured == true and captured.dbcWeapon == 0
    and weaponCalls == 0,
    "root power capture must preserve Shield Slam's non-weapon boundary")

print("ok: exact Shield Slam ranks and private arithmetic boundaries")
