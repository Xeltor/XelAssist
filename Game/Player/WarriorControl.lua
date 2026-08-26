-- Exact patch-5 Hamstring and Disarm boundaries. Hamstring's direct packet is
-- safe graph damage; its target-motion value and Disarm's hostile weapon state
-- stay withheld until the graph has causal evidence for those consequences.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorControl = {}
local C = XelAssist.Game.Player.WarriorControl

C.WARRIOR_FAMILY = 4
C.HAMSTRING_STANCES = 327680
C.DEFENSIVE_STANCE = 131072

local HAMSTRING = {
    [1715] = { rank = 1, level = 8, damage = 5, slow = 40 },
    [7372] = { rank = 2, level = 32, damage = 18, slow = 45 },
    [7373] = { rank = 3, level = 54, damage = 45, slow = 50 },
}
local DISARM = 676
local CACHE = {}

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function integer(value)
    value = tonumber(value)
    return value and value == value and math.floor(value) == value
        and value >= -2147483648 and value <= 4294967295 and value or nil
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and integer(value) or nil
end

local function triple(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = integer(values[index])
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function durationExact(spellId, expected)
    if type(GetSpellDuration) ~= "function" then return false end
    local ok, milliseconds = pcall(GetSpellDuration, spellId)
    return ok and milliseconds == expected * 1000
end

local function rangeExact(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and minimum == 0 and maximum == 5
end

local HAMSTRING_SCALARS = {
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

local function scalarsMatch(spellId, expected, level)
    local field, value
    for field, value in pairs(expected) do
        if scalar(spellId, field) ~= value then return false end
    end
    return not level or scalar(spellId, "baseLevel") == level
        and scalar(spellId, "spellLevel") == level
end

local function hamstringTopology(spellId, rank)
    return scalarsMatch(spellId, HAMSTRING_SCALARS, rank.level)
        and durationExact(spellId, 15) and rangeExact(spellId)
        and equal(triple(spellId, "effect"), 2, 6, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 1, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true),
            rank.damage - 1, -(rank.slow + 1), 0)
        and equal(triple(spellId, "effectMechanic"), 0, 11, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 6, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 33, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local DISARM_SCALARS = {
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
}

local function disarmTopology(spellId)
    return scalarsMatch(spellId, DISARM_SCALARS, 18)
        and durationExact(spellId, 10) and rangeExact(spellId)
        and equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true), -1, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 67, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

function C:Classify(spellId)
    spellId = integer(spellId)
    local rank = spellId and HAMSTRING[spellId]
    if not rank and spellId ~= DISARM then
        return nil, "not an installed Warrior control identity", false
    end
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        return found.valid and found or nil, found.reason, true
    end
    local kind = rank and "hamstring" or "disarm"
    local found = { recognized = true, valid = false, exact = false,
        spellId = spellId, controlKind = kind,
        source = "installed Octo patch-5 Warrior control DBC topology" }
    if rank and not hamstringTopology(spellId, rank)
        or not rank and not disarmTopology(spellId) then
        found.reason = "Warrior " .. kind .. " DBC topology is incomplete"
        CACHE[spellId] = found
        return nil, found.reason, true
    end
    found.valid, found.exact = true, true
    found.rank, found.level = rank and rank.rank or 1,
        rank and rank.level or 18
    found.cost, found.duration = rank and 10 or 20, rank and 15 or 10
    found.minRange, found.maxRange, found.gcd = 0, 5, 1.5
    found.stances = rank and C.HAMSTRING_STANCES or C.DEFENSIVE_STANCE
    found.damage, found.slowPercent = rank and rank.damage, rank and rank.slow
    found.cooldown = rank and 0 or 60
    found.actionSpecificThreatKnown = false
    found.hostileWeaponStateKnown = false
    CACHE[spellId] = found
    return copy(found), nil, true
end

function C:InferKnowledge(spellId)
    if not warrior() then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not found then return nil, reason, handled end
    if found.controlKind == "disarm" then
        return nil, "hostile weapon state and Disarm consequence unavailable", true
    end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorHamstring = true, melee = true, hostile = true, school = 0,
        resourceType = "rage", stanceMask = found.stances,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, noWeaponDamageFallback = true,
        requiresExactUsability = true, submissionGuarded = true,
        targetMovementSlowPercent = found.slowPercent,
        targetMovementSlowValueUnknown = true,
        supplementalThreatUnknown = true,
        warriorControlEvidence = copy(found), source = found.source }, nil, true
end

function C:Invalidate() CACHE = {} end
