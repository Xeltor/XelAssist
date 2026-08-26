-- Exact installed-client Distracting Shot evidence. Numeric identities only
-- select candidate DBC rows; the complete effect-63 ranged topology must still
-- match before the graph may project its selected-hostile threat packet.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.HunterDistractingShot = {}
local D = XelAssist.Game.Player.HunterDistractingShot

D.HUNTER_FAMILY = 9
D.FAMILY_FLAG = 65536
D.THREAT_EFFECT = 63
D.ALL_EFFECTS_MOD = 8
D.THREAT_MOD = 2
D.SERVER_PROFILE = "VMaNGOS effect-63 threat execution"

local RANKS = {
    [20736] = { rank = 1, level = 12, maxLevel = 19,
        cost = 20, base = 109, perLevel = 1.5 },
    [14274] = { rank = 2, level = 20, maxLevel = 29,
        cost = 30, base = 159, perLevel = 2 },
    [15629] = { rank = 3, level = 30, maxLevel = 39,
        cost = 50, base = 249, perLevel = 2.5 },
    [15630] = { rank = 4, level = 40, maxLevel = 49,
        cost = 70, base = 349, perLevel = 3 },
    [15631] = { rank = 5, level = 50, maxLevel = 59,
        cost = 90, base = 464, perLevel = 3.5 },
    [15632] = { rank = 6, level = 60, maxLevel = 69,
        cost = 110, base = 599, perLevel = 4 },
}

local CACHE, CACHE_COUNT, MAX_CACHE = {}, 0, 12

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

local function copyProfile(source)
    local out = copy(source)
    if source and source.allEffectsModifier then
        out.allEffectsModifier = copy(source.allEffectsModifier)
    end
    if source and source.threatModifier then
        out.threatModifier = copy(source.threatModifier)
    end
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
    if scalar(spellId, "rangeIndex") ~= 114
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 114)
    return ok and minimum == 8 and maximum == 35
end

local SCALARS = {
    school = 6, category = 911, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 65538, attributesEx = 131072,
    attributesEx2 = 131072, attributesEx3 = 0, attributesEx4 = 0,
    stances = 0, stancesNot = 0, targets = 0, targetCreatureType = 0,
    requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 18, recoveryTime = 0, categoryRecoveryTime = 8000,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 101, procCharges = 0, durationIndex = 0,
    powerType = 0, manaCostPerlevel = 0, manaPerSecond = 0,
    manaPerSecondPerLevel = 0, rangeIndex = 114, speed = 40,
    modalNextSpell = 75, stackAmount = 0, equippedItemClass = 2,
    equippedItemSubClassMask = 262156, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 9,
    spellFamilyFlags = 65536, maxAffectedTargets = 0, dmgClass = 3,
    preventionType = 2,
}

local function scalarsMatch(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "manaCost") == rank.cost
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 63, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"),
            rank.perLevel, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.base, 0, 0)
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
end

local function raw(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, cached.recognized == true
    end
    local rank = RANKS[spellId]
    if not rank then
        return nil, "not an installed Distracting Shot identity", false
    end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "hunterDistractingShot", spellId = spellId,
        rank = rank.rank, source = "installed build-5875 effect-63 DBC topology" }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and exactRange(spellId)) then
        found.reason = "Distracting Shot DBC topology is incomplete"
    else
        found.valid, found.exact = true, true
        found.level, found.maxLevel, found.cost =
            rank.level, rank.maxLevel, rank.cost
        found.basePoints, found.baseDice = rank.base, 1
        found.realPointsPerLevel = rank.perLevel
        found.baseThreat = rank.base + 1
        found.school, found.effectOpcode = 6, D.THREAT_EFFECT
        found.family, found.familyFlag = D.HUNTER_FAMILY, D.FAMILY_FLAG
        found.recipient, found.attackType = "selected-hostile", "ranged"
        found.minRange, found.maxRange = 8, 35
        found.gcd, found.cast, found.cooldown = 1.5, 0, 8
        found.consumesAmmunition, found.usesWeaponSkill = true, true
    end
    if CACHE_COUNT < MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = copy(found), CACHE_COUNT + 1
    end
    return copy(found), found.reason, true
end

local function sealedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterDistractingShotEvidence
    local rank = found and RANKS[found.spellId]
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "hunterDistractingShot"
        and found.rank == rank.rank and found.level == rank.level
        and found.maxLevel == rank.maxLevel and found.cost == rank.cost
        and found.basePoints == rank.base and found.baseDice == 1
        and found.realPointsPerLevel == rank.perLevel
        and found.baseThreat == rank.base + 1 and found.school == 6
        and found.effectOpcode == D.THREAT_EFFECT
        and found.family == D.HUNTER_FAMILY
        and found.familyFlag == D.FAMILY_FLAG
        and found.recipient == "selected-hostile"
        and found.attackType == "ranged" and found.minRange == 8
        and found.maxRange == 35 and found.gcd == 1.5
        and found.cast == 0 and found.cooldown == 8
        and found.consumesAmmunition == true
        and found.usesWeaponSkill == true) then return nil end
    return found
end

local function modifier(spellId, kind)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(GetSpellModifiers, spellId, kind)
    flat = ok and finite(flat, -100000, 100000) or nil
    percent = ok and finite(percent, -100, 10000) or nil
    changed = ok and integer(changed, 0, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil
        or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then return nil end
    return { kind = kind, flat = flat, percent = percent, changed = changed }
end

local function profile(found, state)
    local playerLevel = integer(state and state.playerLevel, 1, 255)
    local rank = found and RANKS[found.spellId]
    if not (found and rank and playerLevel) then
        return { valid = false, exact = false,
            reason = "Distracting Shot player level evidence unavailable" }
    end
    local allEffects = modifier(found.spellId, D.ALL_EFFECTS_MOD)
    local threat = modifier(found.spellId, D.THREAT_MOD)
    if not (allEffects and threat) then
        return { valid = false, exact = false,
            reason = "Distracting Shot modifier evidence unavailable" }
    end
    local effectiveLevel = math.max(rank.level,
        math.min(rank.maxLevel, playerLevel))
    local amount = rank.base + 1
        + (effectiveLevel - rank.level) * rank.perLevel
    local unmodified = amount
    amount = (amount + allEffects.flat)
        * (100 + allEffects.percent) / 100
    amount = (amount + threat.flat) * (100 + threat.percent) / 100
    if not finite(amount, 0, 1000000) then
        return { valid = false, exact = false,
            reason = "Distracting Shot threat is outside its safe domain" }
    end
    local out = copy(found)
    out.valid, out.exact, out.playerLevel = true, true, playerLevel
    out.effectiveLevel, out.unmodifiedThreat = effectiveLevel, unmodified
    out.effectiveThreat = amount
    out.allEffectsModifier, out.threatModifier = allEffects, threat
    out.source = out.source .. " plus root level and spell modifiers"
    return out
end

local function sealedModifier(value, kind)
    local flat = value and finite(value.flat, -100000, 100000)
    local percent = value and finite(value.percent, -100, 10000)
    local changed = value and integer(value.changed, 0, 4294967295)
    if not (type(value) == "table" and value.kind == kind
        and flat and percent and changed
        and (flat ~= 0 or percent ~= 0) == (changed ~= 0)) then return nil end
    return flat, percent
end

local function sealedProfile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterDistractingShotProfile
    local base = found and sealedEvidence({ hunterDistractingShotEvidence = found })
    local playerLevel = found and integer(found.playerLevel, 1, 255)
    local firstFlat, firstPercent = sealedModifier(
        found and found.allEffectsModifier, D.ALL_EFFECTS_MOD)
    local secondFlat, secondPercent = sealedModifier(
        found and found.threatModifier, D.THREAT_MOD)
    if not (base and playerLevel and firstFlat and firstPercent
        and secondFlat and secondPercent) then return nil end
    local effectiveLevel = math.max(base.level,
        math.min(base.maxLevel, playerLevel))
    local unmodified = base.baseThreat
        + (effectiveLevel - base.level) * base.realPointsPerLevel
    local expected = (unmodified + firstFlat)
        * (100 + firstPercent) / 100
    expected = (expected + secondFlat) * (100 + secondPercent) / 100
    if found.effectiveLevel ~= effectiveLevel
        or found.unmodifiedThreat ~= unmodified
        or found.effectiveThreat ~= expected
        or not finite(expected, 0, 1000000) then return nil end
    return found
end

function D:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then
        return nil, "Distracting Shot identity unavailable", false
    end
    return raw(spellId)
end

function D:InferKnowledge(spellId)
    if classToken() ~= "HUNTER" then
        return nil, "player is not an exactly identified Hunter", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "utility", kindExact = true,
        hostile = true, ranged = true, weaponRanged = true,
        ammunition = true, deliveryModel = "physical",
        deliverySubtype = "ranged", usesWeaponSkill = true,
        effectMinRange = found.minRange, effectMaxRange = found.maxRange,
        targetLocalFlatThreat = true, threatOnly = true,
        hunterDistractingShot = true,
        requiresExactHunterDistractingShot = true,
        requiresExactUsability = true, submissionGuarded = true,
        powerType = 0, cost = found.cost, gcd = found.gcd, cast = found.cast,
        hunterDistractingShotEvidence = copy(found), source = found.source },
        nil, true
end

function D:CaptureFacts(action, facts, state)
    if not (facts and facts.hunterDistractingShot == true) then return facts end
    local found = sealedEvidence(facts)
    if not (found and tonumber(action and action.spellId) == found.spellId) then
        return facts
    end
    local out, captured = copy(facts), profile(found, state)
    out.hunterDistractingShotProfile = copyProfile(captured)
    out.baseFlatThreatBySpellId = nil
    out.baseFlatThreatSource = nil
    if captured.valid == true and captured.exact == true then
        out.baseFlatThreatBySpellId = {
            [found.spellId] = captured.effectiveThreat }
        out.baseFlatThreatSource = captured.source
        out.effectActor, out.school = "player", found.school
    end
    return out
end

function D:Evidence(subject)
    local found = sealedEvidence(subject)
    return found and copy(found) or nil
end

function D:Profile(subject)
    local found = sealedProfile(subject)
    return found and copyProfile(found) or nil
end

function D:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
