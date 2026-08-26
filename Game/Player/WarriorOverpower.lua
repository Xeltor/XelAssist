-- Exact installed build-5875 Overpower identity. The client DBC proves the
-- normalized weapon hit, rank bonus, Battle Stance/rage constraints and its
-- dodge-reaction attribute. Live availability remains owned by the generic
-- reactive-state ledger and IsUsableAction fallback; no synthetic timer is
-- introduced because these rows expose casterAuraState=0.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorOverpower = {}
local O = XelAssist.Game.Player.WarriorOverpower

O.WARRIOR_FAMILY = 4
O.FAMILY_FLAG = 4
O.BATTLE_STANCE = 65536
O.RAGE = 1
O.DODGE_REACTION_ATTRIBUTE = 1073741824

local RANKS = {
    [7384] = { rank = 1, level = 12, bonus = 5 },
    [7887] = { rank = 2, level = 28, bonus = 15 },
    [11584] = { rank = 3, level = 44, bonus = 25 },
    [11585] = { rank = 4, level = 60, bonus = 35 },
}
local CACHE = {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value >= -2147483648 and value <= 4294967295 and value or nil
end

local function integer(value)
    value = finite(value)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key = {}, 0, nil
    for key in pairs(values) do
        if not integer(key) or key < 1 or key > 3 then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for key = 1, 3 do
        out[key] = finite(values[key])
        if out[key] == nil then return nil end
    end
    return out
end

local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function hasFlag(value, flag)
    value = integer(value)
    return value and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end

local function rangeExact(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and minimum == 0 and maximum == 5
end

local SCALARS = {
    school = 0, category = 65, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 2424848,
    attributesEx = 1209008640, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 512, stances = 65536,
    stancesNot = 0, targets = 0, targetCreatureType = 0,
    requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 5000,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 101, procCharges = 0, maxLevel = 0,
    durationIndex = 0, powerType = 1, manaCost = 50,
    manaCostPerlevel = 0, manaPerSecond = 0, manaPerSecondPerLevel = 0,
    rangeIndex = 2, speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = 2,
    equippedItemSubClassMask = 173555, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 4, maxAffectedTargets = 0,
    dmgClass = 2, preventionType = 2,
}

local function topology(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return hasFlag(scalar(spellId, "attributesEx"),
            O.DODGE_REACTION_ATTRIBUTE)
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and equal(triple(spellId, "effect"), 121, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.bonus - 1, 0, 0)
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
        and rangeExact(spellId)
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

function O:Classify(spellId)
    spellId = integer(spellId)
    if not spellId then return nil, "Overpower identity unavailable", false end
    local rank = RANKS[spellId]
    if not rank then return nil, "not an installed Overpower identity", false end
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        return found.valid and found or nil, found.reason, true
    end
    local found = { recognized = true, valid = false, exact = false,
        spellId = spellId, rank = rank.rank, level = rank.level,
        source = "installed Octo patch-5 Overpower DBC topology" }
    if not topology(spellId, rank) then
        found.reason = "Overpower DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return nil, found.reason, true
    end
    found.valid, found.exact = true, true
    found.bonusDamage, found.cost = rank.bonus, 5
    found.stances, found.minRange, found.maxRange = O.BATTLE_STANCE, 0, 5
    found.cooldown, found.gcd, found.cast = 5, 1.5, 0
    found.normalizedWeaponDamage = true
    found.requiresDodgeReaction = true
    found.casterAuraState = 0
    found.actionSpecificThreatKnown = false
    CACHE[spellId] = copy(found)
    return copy(found), nil, true
end

function O:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not found then return nil, reason, handled end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorOverpower = true, melee = true, reactive = true,
        requiresExactUsability = true, submissionGuarded = true,
        school = 0, resourceType = "rage", stanceMask = found.stances,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, normalizedWeaponDamage = true,
        warriorOverpowerEvidence = copy(found), source = found.source }, nil, true
end

function O:Invalidate() CACHE = {} end
