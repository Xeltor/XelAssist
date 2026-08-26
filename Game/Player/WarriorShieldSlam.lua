-- Exact installed Shield Slam identity. The patch-5 rows prove the shield,
-- rage, range, cooldown and base physical packet. Octo's private AP/block-value
-- additions, threat packet and probabilistic hostile dispel stay explicit gaps.
XelAssist.Game.Player.WarriorShieldSlam = {}
local S = XelAssist.Game.Player.WarriorShieldSlam

S.WARRIOR_FAMILY = 4
S.FAMILY_FLAG_LOW = 33554432
S.FAMILY_FLAG_HIGH = 1

local RANKS = {
    [23922] = { rank = 1, level = 30, base = 174, die = 11 },
    [23923] = { rank = 2, level = 38, base = 225, die = 11 },
    [23924] = { rank = 3, level = 46, base = 264, die = 13 },
    [23925] = { rank = 4, level = 54, base = 303, die = 15 },
    [52315] = { rank = 5, level = 60, base = 342, die = 17 },
}
local TALENTS = {
    [51598] = { rank = 1, reduction = 0.75, trigger = 51596,
        blockChance = 0.35 },
    [51599] = { rank = 2, reduction = 1.50, trigger = 51597,
        blockChance = 0.70 },
}
local CACHE = {}
local TALENT_CACHE = {}

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

local function rangeExact(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and minimum == 0 and maximum == 5
end

local SCALARS = {
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

local function scalarsMatch(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 38, 2, 0)
        and equal(triple(spellId, "effectDieSides"), 1, rank.die, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true),
            0, rank.base - 1, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 6, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 1, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

local function talentTopology(spellId, talent)
    return scalar(spellId, "procFlags") == 16
        and scalar(spellId, "procChance") == 100
        and equal(triple(spellId, "effect"), 6, 6, 0)
        and equal(triple(spellId, "effectBasePoints", true),
            talent.rank == 1 and -751 or -1501, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 107, 42, 0)
        and equal(triple(spellId, "effectMiscValue"), 11, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"),
            0, talent.trigger, 0)
end

local function procTopology(spellId, talent)
    return scalar(spellId, "procFlags") == 680
        and scalar(spellId, "procCharges") == 1
        and scalar(spellId, "durationIndex") == 557
        and scalar(spellId, "equippedItemClass") == 4
        and scalar(spellId, "equippedItemSubClassMask") == 64
        and equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 51, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true),
            talent.blockChance * 100 - 1, 0, 0)
end

function S:ImprovedEvidence()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "talent ownership API unavailable"
    end
    local spellId
    if IsPlayerSpell(51599) then spellId = 51599
    elseif IsPlayerSpell(51598) then spellId = 51598 end
    if not spellId then return nil, "Improved Shield Slam not learned" end
    if TALENT_CACHE[spellId] ~= nil then
        local cached = TALENT_CACHE[spellId]
        return cached.valid and copy(cached) or nil, cached.reason
    end
    local talent = TALENTS[spellId]
    local found = copy(talent)
    found.spellId, found.valid = spellId, false
    if not (talentTopology(spellId, talent)
        and procTopology(talent.trigger, talent)) then
        found.reason = "Improved Shield Slam DBC topology is incomplete"
        TALENT_CACHE[spellId] = found
        return nil, found.reason
    end
    found.valid, found.baseCooldown = true, 6
    found.effectiveCooldown = 6 - talent.reduction
    found.procValueKnown = false
    found.source = "installed Octo patch-5 Improved Shield Slam DBC topology"
    TALENT_CACHE[spellId] = found
    return copy(found)
end

function S:CaptureFacts(action, facts)
    if not (type(action) == "table" and type(facts) == "table"
        and self:Evidence(action)) then return facts end
    local improved = self:ImprovedEvidence()
    if not improved then return facts end
    facts.categoryCooldown = improved.effectiveCooldown
    facts.improvedShieldSlamEvidence = improved
    return facts
end

function S:Classify(spellId)
    spellId = integer(spellId)
    local rank = spellId and RANKS[spellId]
    if not rank then return nil, "not an installed Shield Slam identity", false end
    local cached = CACHE[spellId]
    if cached then
        return cached.valid and copy(cached) or nil, cached.reason, true
    end
    cached = { recognized = true, valid = false, exact = false,
        spellId = spellId, rank = rank.rank, level = rank.level,
        source = "installed Octo patch-5 Shield Slam DBC topology" }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and rangeExact(spellId)) then
        cached.reason = "Shield Slam DBC topology is incomplete"
        CACHE[spellId] = cached
        return nil, cached.reason, true
    end
    cached.valid, cached.exact = true, true
    cached.damageMinimum = rank.base
    cached.damageMaximum = rank.base + rank.die - 1
    cached.cost, cached.cooldown, cached.gcd = 20, 6, 1.5
    cached.minRange, cached.maxRange, cached.requiresShield = 0, 5, true
    cached.apDamageKnown, cached.blockValueDamageKnown = false, false
    cached.actionSpecificThreatKnown = false
    cached.magicDispelCount, cached.magicDispelProbabilityKnown = 1, false
    CACHE[spellId] = cached
    return copy(cached), nil, true
end

function S:InferKnowledge(spellId)
    if not warrior() then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not found then return nil, reason, handled end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorShieldSlam = true, melee = true, hostile = true, school = 0,
        requiresShield = true, resourceType = "rage", usesWeaponSkill = true,
        deliveryModel = "physical", deliverySubtype = "melee",
        requiresExactUsability = true, submissionGuarded = true,
        noWeaponDamageFallback = true, supplementalThreatUnknown = true,
        shieldBlockValueDamageUnknown = true, attackPowerDamageUnknown = true,
        offensiveMagicDispelUnknown = true,
        warriorShieldSlamEvidence = copy(found), source = found.source }, nil, true
end

function S:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorShieldSlamEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (facts and facts.warriorShieldSlam == true and rank
        and facts.kind == "damage" and facts.melee == true
        and facts.requiresShield == true and facts.noWeaponDamageFallback == true
        and facts.supplementalThreatUnknown == true
        and found.valid == true and found.exact == true
        and found.rank == rank.rank and found.level == rank.level
        and found.damageMinimum == rank.base
        and found.damageMaximum == rank.base + rank.die - 1
        and found.cost == 20 and found.cooldown == 6 and found.gcd == 1.5
        and found.minRange == 0 and found.maxRange == 5
        and found.requiresShield == true and found.apDamageKnown == false
        and found.blockValueDamageKnown == false
        and found.actionSpecificThreatKnown == false
        and found.magicDispelCount == 1
        and found.magicDispelProbabilityKnown == false) then return nil end
    return copy(found)
end

function S:Invalidate()
    CACHE = {}
    TALENT_CACHE = {}
end
