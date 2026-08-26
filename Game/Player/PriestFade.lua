-- Exact Fade identity and root evidence for the installed build-5875 client.
-- Numeric spell identities only select rows for full topology validation;
-- localized names and rank text never choose this mechanic.  Graph search
-- consumes the sealed contract and never rereads player, aura, or DBC APIs.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestFade = {}
local F = XelAssist.Game.Player.PriestFade

F.PRIEST_FAMILY = 6
F.FAMILY_FLAG = 16384
F.MANA = 0
F.ALL_EFFECTS_MOD = 8
F.MODEL = "temporary-flat"

local RANKS = {
    [586] = { rank = 1, baseLevel = 8, spellLevel = 8,
        maxLevel = 18, manaCost = 40, threatBasePoints = -56 },
    [9578] = { rank = 2, baseLevel = 20, spellLevel = 20,
        maxLevel = 30, manaCost = 75, threatBasePoints = -156 },
    [9579] = { rank = 3, baseLevel = 30, spellLevel = 30,
        maxLevel = 40, manaCost = 125, threatBasePoints = -286 },
    [9592] = { rank = 4, baseLevel = 40, spellLevel = 40,
        maxLevel = 50, manaCost = 175, threatBasePoints = -441 },
    [10941] = { rank = 5, baseLevel = 50, spellLevel = 50,
        maxLevel = 60, manaCost = 225, threatBasePoints = -621 },
    [10942] = { rank = 6, baseLevel = 60, spellLevel = 60,
        maxLevel = 70, manaCost = 275, threatBasePoints = -821 },
}

local CACHE = {}

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
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

local function scalarTopology(spellId, rank)
    return scalar(spellId, "school") == 5
        and scalar(spellId, "category") == 82
        and scalar(spellId, "dispel") == 1
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 1024
        and scalar(spellId, "attributesEx2") == 524288
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 30000
        and scalar(spellId, "interruptFlags") == 8
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "baseLevel") == rank.baseLevel
        and scalar(spellId, "spellLevel") == rank.spellLevel
        and scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "durationIndex") == 1
        and scalar(spellId, "powerType") == F.MANA
        and scalar(spellId, "manaCost") == rank.manaCost
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == F.PRIEST_FAMILY
        and scalar(spellId, "spellFamilyFlags") == F.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end

local ZERO = { 0, 0, 0 }
local ONE = { 1, 1, 0 }
local EFFECT = { 6, 6, 0 }
local DUMMY = { 4, 4, 0 }
local LEVEL = { 0, -3, 0 }

local function effectTopology(spellId, rank)
    return equal(triple(spellId, "effect"), EFFECT)
        and equal(triple(spellId, "effectDieSides"), ONE)
        and equal(triple(spellId, "effectBaseDice"), ONE)
        and equal(triple(spellId, "effectDicePerLevel"), ZERO)
        and equal(triple(spellId, "effectRealPointsPerLevel"), LEVEL)
        and equal(triple(spellId, "effectBasePoints"),
            { -16, rank.threatBasePoints, 0 })
        and equal(triple(spellId, "effectMechanic"), ZERO)
        and equal(triple(spellId, "effectImplicitTargetA"), ONE)
        and equal(triple(spellId, "effectImplicitTargetB"), ZERO)
        and equal(triple(spellId, "effectRadiusIndex"), ZERO)
        and equal(triple(spellId, "effectApplyAuraName"), DUMMY)
        and equal(triple(spellId, "effectAmplitude"), ZERO)
        and equal(triple(spellId, "effectMultipleValue"), ZERO)
        and equal(triple(spellId, "effectChainTarget"), ZERO)
        and equal(triple(spellId, "effectItemType"), ZERO)
        and equal(triple(spellId, "effectMiscValue"), ZERO)
        and equal(triple(spellId, "effectTriggerSpell"), ZERO)
        and equal(triple(spellId, "effectPointsPerComboPoint"), ZERO)
end

local function profile(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, true
    end
    local rank = RANKS[spellId]
    if not rank then return nil, "not an installed Fade identity", false end
    local out = { recognized = true, valid = false, exact = false,
        spellId = spellId, model = F.MODEL,
        source = "installed build-5875 Fade DBC topology" }
    if not (scalarTopology(spellId, rank)
        and effectTopology(spellId, rank)) then
        out.reason = "Fade DBC topology is incomplete"
        CACHE[spellId] = copy(out)
        return out, out.reason, true
    end
    out.valid, out.exact = true, true
    out.rank, out.baseLevel, out.spellLevel, out.maxLevel = rank.rank,
        rank.baseLevel, rank.spellLevel, rank.maxLevel
    out.powerType, out.baseManaCost = F.MANA, rank.manaCost
    out.signedBaseThreat, out.signedThreatPerLevel =
        rank.threatBasePoints + 1, -3
    out.baseDuration, out.categoryCooldown = 10, 30
    out.recipient, out.application = "caster-hostile-references", "aura-land"
    out.appliesOnlyExistingReferences, out.requiresZeroTemporaryModifier =
        true, true
    CACHE[spellId] = copy(out)
    return out, nil, true
end

function F:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "invalid spell identity", false end
    return profile(spellId)
end

function F:InferKnowledge(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or not RANKS[spellId] then
        return nil, "not an installed Fade identity", false
    end
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    local found, reason = profile(spellId)
    if not (found and found.valid == true) then return nil, reason, true end
    return { inferred = true, kind = "threatDrop", kindExact = true,
        self = true, fixedTarget = "player", recipientRelation = "friendly",
        recipientRelationExact = true, resourceType = "mana",
        priestFade = true, threatDropModel = self.MODEL,
        requiresPriestFadeEvidence = true, requiresExactUsability = true,
        submissionGuarded = true, runtimeUnverified = true,
        priestFadeEvidence = copy(found),
        source = found.source }, nil, true
end

local function staticEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestFadeEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (facts and facts.priestFade == true and rank
        and found.valid == true and found.exact == true
        and found.model == F.MODEL and found.rank == rank.rank
        and found.baseLevel == rank.baseLevel
        and found.spellLevel == rank.spellLevel
        and found.maxLevel == rank.maxLevel
        and found.powerType == F.MANA
        and found.baseManaCost == rank.manaCost
        and found.signedBaseThreat == rank.threatBasePoints + 1
        and found.signedThreatPerLevel == -3
        and found.baseDuration == 10 and found.categoryCooldown == 30
        and found.recipient == "caster-hostile-references"
        and found.application == "aura-land"
        and found.appliesOnlyExistingReferences == true
        and found.requiresZeroTemporaryModifier == true) then return nil end
    return found
end

function F:Evidence(subject)
    local found = staticEvidence(subject)
    return found and copy(found) or nil
end

local function rootContract(found)
    local level = playerLevel()
    if not level or type(GetSpellDuration) ~= "function"
        or type(GetSpellModifiers) ~= "function" then
        return nil, "Fade level, duration, or modifier evidence unavailable"
    end
    local baseOK, baseMs = pcall(GetSpellDuration, found.spellId, true)
    local liveOK, liveMs = pcall(GetSpellDuration, found.spellId)
    baseMs = baseOK and integer(baseMs, 1, 600000) or nil
    liveMs = liveOK and integer(liveMs, 1, 600000) or nil
    local modOK, flat, percent, changed = pcall(
        GetSpellModifiers, found.spellId, F.ALL_EFFECTS_MOD)
    flat, percent = modOK and tonumber(flat) or nil,
        modOK and tonumber(percent) or nil
    changed = modOK and integer(changed, 0, 4294967295) or nil
    if baseMs ~= 10000 or not liveMs or flat ~= 0 or percent ~= 0
        or changed ~= 0 then
        return nil, "Fade has unsupported duration or effect modifiers"
    end
    local effective = math.max(found.baseLevel, level)
    if found.maxLevel > 0 then effective = math.min(effective, found.maxLevel) end
    local signed = found.signedBaseThreat
        + (effective - found.spellLevel) * found.signedThreatPerLevel
    local amount = integer(-signed, 1, 1000000)
    if not amount then return nil, "Fade threat magnitude is unavailable" end
    return { valid = true, exact = true, spellId = found.spellId,
        rank = found.rank, model = found.model, playerLevel = level,
        effectiveLevel = effective, amount = amount,
        duration = liveMs / 1000, baseDuration = found.baseDuration,
        recipient = found.recipient, application = found.application,
        appliesOnlyExistingReferences = true,
        requiresZeroTemporaryModifier = true,
        removalVisitsCurrentReferences = true,
        runtimeVerified = false,
        source = found.source .. "; root-captured level and duration" }
end

function F:CaptureFacts(action, facts)
    local found = staticEvidence(action) or staticEvidence(facts)
    if not found then return facts end
    local out, contract, reason = copy(facts), rootContract(found)
    out.priestFade, out.self = true, true
    out.runtimeUnverified = true
    out.threatDropModel = self.MODEL
    out.priestFadeEvidence = copy(found)
    out.priestFadeContract = contract or { recognized = true,
        valid = false, exact = false, spellId = found.spellId,
        model = found.model, reason = reason }
    if contract then
        out.threatDropAmount, out.threatDropDuration =
            contract.amount, contract.duration
    else
        out.threatDropAmount, out.threatDropDuration = nil, nil
    end
    return out
end

local function capturedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local static = staticEvidence(subject)
    local found = facts and facts.priestFadeContract
    if not (static and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == static.spellId
        and found.rank == static.rank and found.model == F.MODEL
        and integer(found.playerLevel, 1, 255)
        and integer(found.effectiveLevel, static.baseLevel, static.maxLevel)
        and found.effectiveLevel == math.min(static.maxLevel,
            math.max(static.baseLevel, found.playerLevel))
        and found.amount == -(static.signedBaseThreat
            + (found.effectiveLevel - static.spellLevel)
                * static.signedThreatPerLevel)
        and finite(found.duration, 0.001, 600)
        and found.baseDuration == static.baseDuration
        and found.recipient == static.recipient
        and found.application == static.application
        and found.appliesOnlyExistingReferences == true
        and found.requiresZeroTemporaryModifier == true
        and found.removalVisitsCurrentReferences == true
        and found.runtimeVerified == false) then return nil end
    return found
end

function F:CapturedEvidence(subject)
    local found = capturedEvidence(subject)
    return found and copy(found) or nil
end

function F:Invalidate()
    CACHE = {}
end
