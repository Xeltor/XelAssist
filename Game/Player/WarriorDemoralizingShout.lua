-- Installed build-5875 Demoralizing Shout identity and root-only geometry.
-- The graph receives its exact flat threat and aura lifetime, but never an
-- inferred attack-power or incoming-damage value: both depend on mechanics
-- that the current hostile snapshot cannot prove.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorDemoralizingShout = {}
local D = XelAssist.Game.Player.WarriorDemoralizingShout

D.WARRIOR_FAMILY = 4
D.FAMILY_FLAG = 131072
D.RAGE = 1
D.BASE_RADIUS = 10
D.BASE_DURATION = 30
D.ATTACK_POWER_AURA = 99
D.SERVER_PROFILE = "VMaNGOS build-5875 spell_threat db-e5f3fd0"

local RANKS = {
    [1160] = { rank = 1, level = 14, maxLevel = 24,
        basePoints = -36, flatThreat = 11 },
    [6190] = { rank = 2, level = 24, maxLevel = 34,
        basePoints = -56, flatThreat = 19 },
    [11554] = { rank = 3, level = 34, maxLevel = 44,
        basePoints = -71, flatThreat = 27 },
    [11555] = { rank = 4, level = 44, maxLevel = 54,
        basePoints = -106, flatThreat = 35 },
    [11556] = { rank = 5, level = 54, maxLevel = 64,
        basePoints = -141, flatThreat = 43 },
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

local SCALARS = {
    school = 0, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 0, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
    auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
    procChance = 101, procCharges = 0, durationIndex = 9, powerType = 1,
    manaCost = 100, manaCostPerlevel = 0, manaPerSecond = 0,
    manaPerSecondPerLevel = 0, rangeIndex = 1, speed = 0,
    modalNextSpell = 0, stackAmount = 0, equippedItemClass = -1,
    equippedItemSubClassMask = 0, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 4,
    spellFamilyFlags = 131072, maxAffectedTargets = 0, dmgClass = 1,
    preventionType = 1, stanceBarOrder = 4294967295,
}

local function scalarsMatch(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "maxLevel") == rank.maxLevel
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), -1, 0, 0)
        and equal(triple(spellId, "effectBasePoints"),
            rank.basePoints, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 22, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 15, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 13, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 99, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function classify(spellId)
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        return found, found.reason, true
    end
    local rank = RANKS[spellId]
    if not rank then
        return nil, "not an installed Demoralizing Shout identity", false
    end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "warriorDemoralizingShout", spellId = spellId,
        source = "installed build-5875 Demoralizing Shout DBC plus "
            .. D.SERVER_PROFILE }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)) then
        found.reason = "Demoralizing Shout DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found, found.reason, true
    end
    found.valid, found.exact = true, true
    found.rank, found.level, found.maxLevel =
        rank.rank, rank.level, rank.maxLevel
    found.powerType, found.baseCost = D.RAGE, 10
    found.stances, found.school = 0, 0
    found.deliveryModel, found.deliverySubtype = "magic", "spell"
    found.baseRadius, found.baseDuration = D.BASE_RADIUS, D.BASE_DURATION
    found.attackPowerAura, found.attackPowerBasePoints =
        D.ATTACK_POWER_AURA, rank.basePoints
    found.attackPowerPerLevel, found.attackPowerReductionModeled = -1, false
    found.flatThreat, found.flatThreatMultiplier = rank.flatThreat, 1
    found.flatThreatModel = "negative-flat-per-successful-recipient"
    found.inverseEffectMask = 0
    found.serverBuildMin, found.serverBuildMax = 0, 5875
    found.serverProfileExact, found.runtimeVerified = true, false
    CACHE[spellId] = copy(found)
    return found, nil, true
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorDemoralizingShoutEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (facts and facts.warriorDemoralizingShout == true and rank
        and found.valid == true and found.exact == true
        and found.portfolio == "warriorDemoralizingShout"
        and found.rank == rank.rank and found.level == rank.level
        and found.maxLevel == rank.maxLevel and found.powerType == D.RAGE
        and found.baseCost == 10 and found.stances == 0 and found.school == 0
        and found.deliveryModel == "magic"
        and found.deliverySubtype == "spell"
        and found.baseRadius == D.BASE_RADIUS
        and found.baseDuration == D.BASE_DURATION
        and found.attackPowerAura == D.ATTACK_POWER_AURA
        and found.attackPowerBasePoints == rank.basePoints
        and found.attackPowerPerLevel == -1
        and found.attackPowerReductionModeled == false
        and found.flatThreat == rank.flatThreat
        and found.flatThreatMultiplier == 1
        and found.flatThreatModel
            == "negative-flat-per-successful-recipient"
        and found.inverseEffectMask == 0 and found.serverBuildMin == 0
        and found.serverBuildMax == 5875 and found.serverProfileExact == true
        and found.runtimeVerified == false) then return nil end
    return found
end

local function duration(spellId, ignoreModifiers)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId,
        ignoreModifiers and 1 or nil)
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end

local function capturedProfile(found)
    local profile = { recognized = true, valid = false, exact = false,
        portfolio = "warriorDemoralizingShout", spellId = found.spellId,
        source = "root-captured local radius and duration modifiers" }
    local api = C_Spell and C_Spell.GetSpellRadius
    if type(api) ~= "function" then
        profile.reason = "Demoralizing Shout radius API unavailable"
        return profile
    end
    local ok, baseRadius, radius = pcall(api, found.spellId)
    baseRadius, radius = finite(baseRadius, 0.01, 1000),
        finite(radius, 0.01, 1000)
    local baseDuration = duration(found.spellId, true)
    local actualDuration = duration(found.spellId, false)
    if not ok or baseRadius ~= found.baseRadius or not radius then
        profile.reason = "Demoralizing Shout radius evidence unavailable"
    elseif baseDuration ~= found.baseDuration or not actualDuration then
        profile.reason = "Demoralizing Shout duration evidence unavailable"
    else
        profile.valid, profile.exact = true, true
        profile.baseRadius, profile.radius = baseRadius, radius
        profile.baseDuration, profile.duration = baseDuration, actualDuration
        profile.flatThreat, profile.runtimeVerified =
            found.flatThreat, found.runtimeVerified
        profile.attackPowerReductionModeled = false
    end
    return profile
end

local function topology(profile)
    if not (profile and profile.valid) then
        return { available = false,
            reason = profile and profile.reason or "root evidence unavailable" }
    end
    local effect = { index = 1, effect = 6, implicitA = 22,
        implicitB = 15, aura = D.ATTACK_POWER_AURA, relation = "hostile",
        shape = "area", center = "caster", radiusIndex = 13,
        radius = profile.radius, radiusKnown = true }
    return { available = true, area = true,
        source = "root-captured Demoralizing Shout hostile area",
        effects = { effect }, hostile = { effect }, friendly = {} }
end

local function exactThreatMap(facts, found)
    local amounts, count, key = facts and facts.baseFlatThreatBySpellId, 0, nil
    if type(amounts) ~= "table" then return false end
    for key in pairs(amounts) do count = count + 1 end
    return count == 1 and amounts[found.spellId] == found.flatThreat
end

local function captured(action, snapshot)
    local facts = type(snapshot) == "table" and snapshot.facts or snapshot
    local identity, found = sealed(action), sealed(facts)
    local profile = facts and facts.warriorDemoralizingShoutProfile
    local spellTopology = facts and facts.topology
    local effect = spellTopology and spellTopology.effects
        and spellTopology.effects[1]
    if not (identity and found and identity.spellId == found.spellId
        and type(profile) == "table" and profile.valid == true
        and profile.exact == true and profile.spellId == found.spellId
        and profile.baseRadius == found.baseRadius
        and profile.baseDuration == found.baseDuration
        and profile.flatThreat == found.flatThreat
        and profile.runtimeVerified == found.runtimeVerified
        and profile.attackPowerReductionModeled == false
        and facts.kind == "debuff" and facts.aoe == true
        and facts.duration == profile.duration and exactThreatMap(facts, found)
        and spellTopology.available == true and spellTopology.area == true
        and table.getn(spellTopology.effects) == 1
        and effect.effect == 6 and effect.aura == D.ATTACK_POWER_AURA
        and effect.relation == "hostile" and effect.shape == "area"
        and effect.center == "caster" and effect.radius == profile.radius
        and effect.radiusKnown == true and effect.maxTargets == nil) then
        return nil
    end
    return found, profile
end

function D:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then
        return nil, "Demoralizing Shout identity unavailable", false
    end
    return classify(spellId)
end

function D:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "debuff", kindExact = true,
        warriorDemoralizingShout = true, aoe = true, hostile = true,
        school = found.school, resourceType = "rage",
        deliveryModel = found.deliveryModel,
        deliverySubtype = found.deliverySubtype,
        requiresExactUsability = true, submissionGuarded = true,
        runtimeUnverified = true, attackPowerReductionModeled = false,
        baseFlatThreatBySpellId = { [spellId] = found.flatThreat },
        baseFlatThreatSource = D.SERVER_PROFILE,
        warriorDemoralizingShoutEvidence = copy(found),
        source = found.source }, nil, true
end

function D:CaptureFacts(action, facts)
    local found = sealed(action) or sealed(facts)
    if not found then return facts end
    local out, profile = copy(facts), capturedProfile(found)
    out.kind, out.aoe = "debuff", true
    out.warriorDemoralizingShout = true
    out.attackPowerReductionModeled = false
    out.warriorDemoralizingShoutEvidence = copy(found)
    out.warriorDemoralizingShoutProfile = profile
    out.baseFlatThreatBySpellId = { [found.spellId] = found.flatThreat }
    out.baseFlatThreatSource = D.SERVER_PROFILE
    out.duration = profile.valid and profile.duration or nil
    out.topology = topology(profile)
    return out
end

function D:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

function D:CapturedEvidence(action, snapshot)
    local found, profile = captured(action, snapshot)
    return found and copy(found) or nil, profile and copy(profile) or nil
end

function D:Invalidate()
    CACHE = {}
end
