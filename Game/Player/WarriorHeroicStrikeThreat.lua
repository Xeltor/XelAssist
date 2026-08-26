-- Installed-client Heroic Strike identity plus the build-5875 server threat
-- profile. Numeric identities validate mechanics only; action order and value
-- remain graph consequences of damage, rage, swing timing, and threat state.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorHeroicStrikeThreat = {}
local H = XelAssist.Game.Player.WarriorHeroicStrikeThreat

H.WARRIOR_FAMILY = 4
H.WARRIOR_FAMILY_FLAG = 64
H.RAGE = 1
H.DAMAGE_THREAT_MULTIPLIER = 1
H.SERVER_PROFILE = "VMaNGOS build-5875 spell_threat db-e5f3fd0"

local RANKS = {
    [78] = { level = 1, bonus = 10, flat = 20 },
    [284] = { level = 8, bonus = 20, flat = 39 },
    [285] = { level = 16, bonus = 31, flat = 59 },
    [1608] = { level = 24, bonus = 43, flat = 78 },
    [11564] = { level = 32, bonus = 57, flat = 98 },
    [11565] = { level = 40, bonus = 79, flat = 118 },
    [11566] = { level = 48, bonus = 110, flat = 137 },
    [11567] = { level = 56, bonus = 137, flat = 145 },
    [25286] = { level = 60, bonus = 156, flat = 175,
        buildMin = 5086 },
}

local CACHE = {}

local function finite(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function exactRange(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and minimum == 0 and maximum == 5
end

local SCALARS = {
    school = 0, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327700, attributesEx = 134217728,
    attributesEx2 = 0, attributesEx3 = 1024, attributesEx4 = 0,
    stances = 0, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0,
    interruptFlags = 0, auraInterruptFlags = 0,
    channelInterruptFlags = 0, procFlags = 0, procChance = 101,
    procCharges = 0, maxLevel = 0, durationIndex = 0,
    powerType = 1, manaCost = 150, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 2,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = 2, equippedItemSubClassMask = 173555,
    equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 0,
    startRecoveryTime = 0, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 64,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
    stanceBarOrder = 4294967295,
}

local function scalarsMatch(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 17, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.bonus, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
        and equal(triple(spellId, "dmgMultiplier"), 1, 1, 1)
end

local function classify(spellId)
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        return found, found.reason, true
    end
    local rank = RANKS[spellId]
    if not rank then
        return nil, "not an installed Heroic Strike identity", false
    end
    local found = { recognized = true, valid = false, exact = false,
        spellId = spellId, source =
            "installed build-5875 Heroic Strike DBC plus " .. H.SERVER_PROFILE }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and exactRange(spellId)) then
        found.reason = "Heroic Strike DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found, found.reason, true
    end
    found.valid, found.exact = true, true
    found.level, found.powerType, found.cost = rank.level, H.RAGE, 15
    found.minRange, found.maxRange = 0, 5
    found.gcd, found.cast, found.onNextSwing = 0, 0, true
    found.family, found.familyFlag = H.WARRIOR_FAMILY,
        H.WARRIOR_FAMILY_FLAG
    found.damageBonus = rank.bonus + 1
    found.flatThreat, found.damageThreatMultiplier = rank.flat,
        H.DAMAGE_THREAT_MULTIPLIER
    found.inverseEffectMask = 0
    found.serverBuildMin, found.serverBuildMax = rank.buildMin or 0, 5875
    found.serverProfileExact, found.runtimeVerified = true, false
    CACHE[spellId] = copy(found)
    return found, nil, true
end

function H:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then
        return nil, "Heroic Strike identity unavailable", false
    end
    return classify(spellId)
end

function H:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorHeroicStrikeThreat = true, melee = true, school = 0,
        resourceType = "rage", deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true,
        requiresExactUsability = true, submissionGuarded = true,
        onNextSwing = true, threat = found.damageThreatMultiplier,
        supplementalFlatThreat = found.flatThreat,
        supplementalFlatThreatSource = self.SERVER_PROFILE,
        runtimeUnverified = true,
        warriorHeroicStrikeThreatEvidence = copy(found),
        source = found.source }, nil, true
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorHeroicStrikeThreatEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (facts and facts.warriorHeroicStrikeThreat == true and rank
        and facts.kind == "damage" and facts.melee == true
        and facts.onNextSwing == true
        and facts.threat == H.DAMAGE_THREAT_MULTIPLIER
        and facts.supplementalFlatThreat == rank.flat
        and facts.runtimeUnverified == true
        and found.valid == true and found.exact == true
        and found.level == rank.level and found.powerType == H.RAGE
        and found.cost == 15 and found.minRange == 0 and found.maxRange == 5
        and found.gcd == 0 and found.cast == 0 and found.onNextSwing == true
        and found.family == H.WARRIOR_FAMILY
        and found.familyFlag == H.WARRIOR_FAMILY_FLAG
        and found.damageBonus == rank.bonus + 1
        and found.flatThreat == rank.flat
        and found.damageThreatMultiplier == H.DAMAGE_THREAT_MULTIPLIER
        and found.inverseEffectMask == 0
        and found.serverBuildMin == (rank.buildMin or 0)
        and found.serverBuildMax == 5875
        and found.serverProfileExact == true
        and found.runtimeVerified == false) then return nil end
    return found
end

function H:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

function H:Invalidate()
    CACHE = {}
end
