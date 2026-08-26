-- Installed-client Thunder Clap identity plus its build-5875 server threat
-- packet. Numeric spell IDs select rows only; complete DBC topology proves
-- the caster-centred damage/aura pair before the graph receives 2.5x threat.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorThunderClap = {}
local T = XelAssist.Game.Player.WarriorThunderClap

T.WARRIOR_FAMILY = 4
T.FAMILY_FLAG = 128
T.BATTLE_AND_DEFENSIVE = 196608
T.RAGE = 1
T.THREAT_MULTIPLIER = 2.5
T.MAX_TARGETS = 4
T.RADIUS = 8
T.SERVER_PROFILE = "VMaNGOS build-5875 spell_threat db-e5f3fd0"

local RANKS = {
    [6343] = { rank = 1, level = 6, damageBase = 9, durationIndex = 1 },
    [8198] = { rank = 2, level = 18, damageBase = 22, durationIndex = 305 },
    [8204] = { rank = 3, level = 28, damageBase = 36, durationIndex = 85 },
    [8205] = { rank = 4, level = 38, damageBase = 54, durationIndex = 467 },
    [11580] = { rank = 5, level = 48, damageBase = 81, durationIndex = 468 },
    [11581] = { rank = 6, level = 58, damageBase = 102, durationIndex = 9 },
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
    school = 0, category = 49, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 136, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 196608,
    stancesNot = 0, targets = 0, targetCreatureType = 0,
    requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 4000,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 0, procCharges = 0, maxLevel = 0,
    powerType = 1, manaCost = 200, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 1,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = -1, equippedItemSubClassMask = 0,
    equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    maxTargetLevel = 0, spellFamilyName = 4, spellFamilyFlags = 128,
    maxAffectedTargets = 4, dmgClass = 1, preventionType = 1,
    stanceBarOrder = 4294967295,
}

local function scalarsMatch(spellId, rank)
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(spellId, field) ~= expected then return false end
    end
    return scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "durationIndex") == rank.durationIndex
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 2, 6, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 1, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"),
            rank.damageBase, -11, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 22, 22, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 15, 15, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 14, 14, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 138, 0)
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
    if not rank then return nil, "not an installed Thunder Clap identity", false end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "warriorThunderClap", spellId = spellId,
        source = "installed build-5875 Thunder Clap DBC plus "
            .. T.SERVER_PROFILE }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)) then
        found.reason = "Thunder Clap DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found, found.reason, true
    end
    found.valid, found.exact = true, true
    found.rank, found.level = rank.rank, rank.level
    found.powerType, found.baseCost = T.RAGE, 20
    found.stances, found.school = T.BATTLE_AND_DEFENSIVE, 0
    found.deliveryModel, found.deliverySubtype = "magic", "spell"
    found.radius, found.maxAffectedTargets = T.RADIUS, T.MAX_TARGETS
    found.damageMinimum, found.damageMaximum = rank.damageBase + 1,
        rank.damageBase + 1
    found.attackTimeIncreasePercent, found.meleeHasteAura = 10, 138
    found.cooldown, found.gcd, found.cast = 4, 1.5, 0
    found.flatThreat, found.damageThreatMultiplier = 0, T.THREAT_MULTIPLIER
    found.inverseEffectMask = 0
    found.serverBuildMin, found.serverBuildMax = 0, 5875
    found.serverProfileExact, found.runtimeVerified = true, false
    CACHE[spellId] = copy(found)
    return found, nil, true
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorThunderClapEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (facts and facts.warriorThunderClap == true and rank
        and found.valid == true and found.exact == true
        and found.portfolio == "warriorThunderClap"
        and found.rank == rank.rank and found.level == rank.level
        and found.powerType == T.RAGE and found.baseCost == 20
        and found.stances == T.BATTLE_AND_DEFENSIVE and found.school == 0
        and found.deliveryModel == "magic"
        and found.deliverySubtype == "spell"
        and found.radius == T.RADIUS
        and found.maxAffectedTargets == T.MAX_TARGETS
        and found.damageMinimum == rank.damageBase + 1
        and found.damageMaximum == rank.damageBase + 1
        and found.attackTimeIncreasePercent == 10
        and found.meleeHasteAura == 138 and found.cooldown == 4
        and found.gcd == 1.5 and found.cast == 0
        and found.flatThreat == 0
        and found.damageThreatMultiplier == T.THREAT_MULTIPLIER
        and found.inverseEffectMask == 0 and found.serverBuildMin == 0
        and found.serverBuildMax == 5875
        and found.serverProfileExact == true
        and found.runtimeVerified == false) then return nil end
    return found
end

local function damageTopology(found)
    local effect = { index = 1, effect = 2, implicitA = 22, implicitB = 15,
        relation = "hostile", shape = "area", center = "caster",
        radiusIndex = 14, radius = found.radius, radiusKnown = true,
        maxTargets = found.maxAffectedTargets }
    return { available = true, area = true,
        source = "sealed Thunder Clap direct-damage topology",
        effects = { effect }, hostile = { effect }, friendly = {} }
end

local function captured(action, snapshot)
    local facts = type(snapshot) == "table" and snapshot.facts or snapshot
    if facts == nil then
        facts = type(action) == "table" and action.facts or action
    end
    local identity, found = sealed(action), sealed(facts)
    local topology = facts and facts.topology
    local effect = topology and topology.effects and topology.effects[1]
    if not (identity and found and identity.spellId == found.spellId
        and facts.kind == "damage" and facts.aoe == true
        and facts.threat == T.THREAT_MULTIPLIER
        and facts.maxAffectedTargets == T.MAX_TARGETS
        and topology.available == true and topology.area == true
        and table.getn(topology.effects) == 1
        and effect.effect == 2 and effect.relation == "hostile"
        and effect.shape == "area" and effect.center == "caster"
        and effect.radius == T.RADIUS and effect.radiusKnown == true
        and effect.maxTargets == T.MAX_TARGETS) then return nil end
    return found
end

function T:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Thunder Clap identity unavailable", false end
    return classify(spellId)
end

function T:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorThunderClap = true, aoe = true, hostile = true,
        school = found.school, resourceType = "rage",
        stanceMask = found.stances, deliveryModel = found.deliveryModel,
        deliverySubtype = found.deliverySubtype,
        requiresExactUsability = true, submissionGuarded = true,
        threat = found.damageThreatMultiplier, runtimeUnverified = true,
        maxAffectedTargets = found.maxAffectedTargets,
        warriorThunderClapEvidence = copy(found), source = found.source }, nil, true
end

function T:CaptureFacts(action, facts)
    local found = sealed(action) or sealed(facts)
    if not found then return facts end
    local out = copy(facts)
    out.kind, out.aoe, out.threat = "damage", true,
        found.damageThreatMultiplier
    out.maxAffectedTargets = found.maxAffectedTargets
    out.warriorThunderClap = true
    out.warriorThunderClapEvidence = copy(found)
    out.topology = damageTopology(found)
    return out
end

function T:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

function T:CapturedEvidence(action, snapshot)
    local found = captured(action, snapshot)
    return found and copy(found) or nil
end

function T:Invalidate()
    CACHE = {}
end
