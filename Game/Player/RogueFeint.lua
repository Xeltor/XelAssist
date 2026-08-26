-- Exact Feint discovery from the installed build-5875 Spell.dbc.  Numeric
-- identities only select rows for validation; localized names and rank text
-- never choose mechanics.  Graph descendants consume the sealed descriptor
-- copied into action facts and never reread DBC, range, or player APIs.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.RogueFeint = {}
local F = XelAssist.Game.Player.RogueFeint

F.ROGUE_FAMILY = 8
F.ROGUE_FAMILY_FLAG = 134217728
F.ENERGY = 3
F.MODEL = "target-local-flat"
F.MAX_CACHE = 5

local RANKS = {
    [1966] = { baseLevel = 16, spellLevel = 16, maxLevel = 26,
        basePoints = { -151, -1, 0 }, dice = { 1, 1, 0 } },
    [6768] = { baseLevel = 28, spellLevel = 28, maxLevel = 38,
        basePoints = { -241, 0, 0 }, dice = { 1, 0, 0 } },
    [8637] = { baseLevel = 40, spellLevel = 40, maxLevel = 50,
        basePoints = { -391, 0, 0 }, dice = { 1, 0, 0 } },
    [11303] = { baseLevel = 52, spellLevel = 52, maxLevel = 62,
        basePoints = { -601, 0, 0 }, dice = { 1, 0, 0 } },
    [25302] = { baseLevel = 60, spellLevel = 60, maxLevel = 70,
        basePoints = { -801, 0, 0 }, dice = { 1, 0, 0 } },
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

local function playerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, value = pcall(UnitLevel, "player")
    return ok and integer(value, 1, 255) or nil
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

local function equal(values, expected)
    return values and expected and values[1] == expected[1]
        and values[2] == expected[2] and values[3] == expected[3]
end

local function range(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return nil, nil end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    minimum, maximum = tonumber(minimum), tonumber(maximum)
    if not ok or minimum ~= 0 or maximum ~= 5 then return nil, nil end
    return minimum, maximum
end

local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 82
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 327696
        and scalar(spellId, "attributesEx") == 134217728
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 10000
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "baseLevel") == rank.baseLevel
        and scalar(spellId, "spellLevel") == rank.spellLevel
        and scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "durationIndex") == 0
        and scalar(spellId, "powerType") == F.ENERGY
        and scalar(spellId, "manaCost") == 20
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1000
        and scalar(spellId, "spellFamilyName") == F.ROGUE_FAMILY
        and scalar(spellId, "spellFamilyFlags") == F.ROGUE_FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 2
        and scalar(spellId, "preventionType") == 2
end

local ZERO = { 0, 0, 0 }
local NEGATIVE_LEVEL = { -1, 0, 0 }
local EFFECT = { 63, 0, 0 }
local HOSTILE = { 6, 0, 0 }

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), EFFECT)
        and equal(triple(spellId, "effectDieSides"), rank.dice)
        and equal(triple(spellId, "effectBaseDice"), rank.dice)
        and equal(triple(spellId, "effectDicePerLevel"), ZERO)
        and equal(triple(spellId, "effectRealPointsPerLevel"), NEGATIVE_LEVEL)
        and equal(triple(spellId, "effectBasePoints"), rank.basePoints)
        and equal(triple(spellId, "effectMechanic"), ZERO)
        and equal(triple(spellId, "effectImplicitTargetA"), HOSTILE)
        and equal(triple(spellId, "effectImplicitTargetB"), ZERO)
        and equal(triple(spellId, "effectRadiusIndex"), ZERO)
        and equal(triple(spellId, "effectApplyAuraName"), ZERO)
        and equal(triple(spellId, "effectAmplitude"), ZERO)
        and equal(triple(spellId, "effectMultipleValue"), ZERO)
        and equal(triple(spellId, "effectChainTarget"), ZERO)
        and equal(triple(spellId, "effectMiscValue"), ZERO)
        and equal(triple(spellId, "effectTriggerSpell"), ZERO)
        and equal(triple(spellId, "effectPointsPerComboPoint"), ZERO)
end

local function raw(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, true
    end
    local rank = RANKS[spellId]
    if not rank then return nil, "not an installed Feint identity", false end
    local found = { recognized = true, valid = false, spellId = spellId,
        model = F.MODEL,
        source = "installed build-5875 Feint DBC effect-63 topology" }
    local minimum, maximum = range(spellId)
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and minimum == 0 and maximum == 5) then
        found.reason = "Feint DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found, found.reason, true
    end
    found.valid, found.exact = true, true
    found.baseLevel, found.spellLevel, found.maxLevel = rank.baseLevel,
        rank.spellLevel, rank.maxLevel
    found.signedBaseThreat = rank.basePoints[1] + rank.dice[1]
    found.signedThreatPerLevel = -1
    found.powerType, found.cost = F.ENERGY, 20
    found.minRange, found.maxRange = minimum, maximum
    found.category, found.categoryCooldown = 82, 10
    found.gcd, found.cast = 1, 0
    found.school, found.dmgClass = 0, 2
    found.deliveryModel, found.deliverySubtype = "physical", "melee"
    found.usesWeaponSkill, found.refundsPowerOnFailure = true, true
    found.resourceRefundAmountExact = false
    found.recipient, found.effectOpcode = "selected-hostile", 63
    CACHE[spellId] = copy(found)
    return found, nil, true
end

function F:Classify(spellId, level)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or not RANKS[spellId] then
        return nil, "not an installed Feint identity", false
    end
    local found, reason = raw(spellId)
    if not (found and found.valid == true) then return found, reason, true end
    level = integer(level, 1, 255) or playerLevel()
    if not level then
        found.valid, found.exact = false, false
        found.reason = "player level unavailable for Feint threat scaling"
        return found, found.reason, true
    end
    local effective = math.max(found.baseLevel, level)
    if found.maxLevel > 0 then effective = math.min(effective, found.maxLevel) end
    local signed = found.signedBaseThreat
        + (effective - found.spellLevel) * found.signedThreatPerLevel
    if signed >= 0 then
        found.valid, found.exact = false, false
        found.reason = "Feint signed threat magnitude is invalid"
        return found, found.reason, true
    end
    found.playerLevel, found.effectiveLevel = level, effective
    found.amount = -signed
    return found, nil, true
end

function F:InferKnowledge(spellId)
    if classToken() ~= "ROGUE" then
        return nil, "player is not an exactly identified Rogue", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "threatDrop", kindExact = true,
        rogueFeint = true, targetLocalThreatDrop = true,
        threatDropModel = self.MODEL, melee = true, school = 0,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, requiresExactUsability = true,
        submissionGuarded = true, rogueFeintEvidence = copy(found),
        source = found.source }, nil, true
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.rogueFeintEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    local level = found and integer(found.playerLevel, 1, 255)
    local effective = found and integer(found.effectiveLevel, 1, 255)
    local expected = rank and effective and -(rank.basePoints[1] + rank.dice[1]
        + (effective - rank.spellLevel) * -1) or nil
    if not (facts and facts.rogueFeint == true and rank
        and found.valid == true and found.exact == true
        and found.model == F.MODEL and level and effective
        and effective == math.min(rank.maxLevel, math.max(rank.baseLevel, level))
        and found.baseLevel == rank.baseLevel
        and found.spellLevel == rank.spellLevel
        and found.maxLevel == rank.maxLevel
        and found.signedBaseThreat == rank.basePoints[1] + rank.dice[1]
        and found.signedThreatPerLevel == -1
        and found.amount == expected and expected and expected > 0
        and found.powerType == F.ENERGY and found.cost == 20
        and found.minRange == 0 and found.maxRange == 5
        and found.category == 82 and found.categoryCooldown == 10
        and found.gcd == 1 and found.cast == 0
        and found.school == 0 and found.dmgClass == 2
        and found.deliveryModel == "physical"
        and found.deliverySubtype == "melee"
        and found.usesWeaponSkill == true
        and found.refundsPowerOnFailure == true
        and found.resourceRefundAmountExact == false
        and found.recipient == "selected-hostile"
        and found.effectOpcode == 63) then return nil end
    return found
end

function F:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

-- Called while the root is open, but deliberately consumes only evidence
-- already sealed into the action by inference.  No mutable API is read here.
function F:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = evidence(action) or evidence(facts)
    if not found then return out end
    out.rogueFeint, out.targetLocalThreatDrop = true, true
    out.threatDropModel, out.threatDropAmount = self.MODEL, found.amount
    out.rogueFeintEvidence = copy(found)
    out.powerType, out.cost = found.powerType, found.cost
    out.minRange, out.maxRange = found.minRange, found.maxRange
    out.categoryCooldown, out.cooldownGroup = found.categoryCooldown,
        found.category
    out.gcd, out.cast, out.school = found.gcd, found.cast, found.school
    out.deliveryModel, out.deliverySubtype = found.deliveryModel,
        found.deliverySubtype
    out.usesWeaponSkill = true
    return out
end

function F:Invalidate()
    CACHE = {}
end
