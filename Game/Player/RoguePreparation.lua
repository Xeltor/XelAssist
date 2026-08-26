-- Exact build-5875 Preparation identity and root-catalogue cooldown evidence.
-- The runtime seals the VMaNGOS reset predicate once at the graph root; search
-- descendants never read DBC, class, cooldown, or localized spell-name APIs.
XelAssist.Game.Player.RoguePreparation = {}
local P = XelAssist.Game.Player.RoguePreparation

P.SPELL_ID = 14185
P.ROGUE_FAMILY = 8
P.DUMMY_EFFECT = 3
P.COOLDOWN_MS = 420000
P.GCD_MS = 1000
P.MAX_CACHE = 384

local PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
local PLAYER_CLASS, PLAYER_CLASS_KNOWN = nil, false

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

local function unsigned32(value)
    value = integer(value, -2147483648, 4294967295)
    if value and value < 0 then value = value + 4294967296 end
    return integer(value, 0, 4294967295)
end

local function signed32(value)
    value = unsigned32(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    if signed then return signed32(value) end
    return finite(value, -2147483648, 9007199254740991)
end

local function triple(spellId, field, signed)
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
        out[index] = signed and signed32(values[index])
            or finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classToken()
    if PLAYER_CLASS_KNOWN then return PLAYER_CLASS end
    PLAYER_CLASS_KNOWN = true
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    PLAYER_CLASS = ok and type(token) == "string" and token or nil
    return PLAYER_CLASS
end

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    return ok and integer(milliseconds, 0, 4294967295) or nil
end

local function setupTopology()
    return scalar(P.SPELL_ID, "school") == 0
        and scalar(P.SPELL_ID, "category") == 0
        and scalar(P.SPELL_ID, "dispel") == 0
        and scalar(P.SPELL_ID, "mechanic") == 0
        and unsigned32(scalar(P.SPELL_ID, "attributes")) == 262160
        and unsigned32(scalar(P.SPELL_ID, "attributesEx")) == 32
        and scalar(P.SPELL_ID, "attributesEx2") == 0
        and scalar(P.SPELL_ID, "attributesEx3") == 0
        and scalar(P.SPELL_ID, "attributesEx4") == 0
        and scalar(P.SPELL_ID, "castingTimeIndex") == 1
        and scalar(P.SPELL_ID, "recoveryTime") == P.COOLDOWN_MS
        and scalar(P.SPELL_ID, "categoryRecoveryTime") == 0
        and scalar(P.SPELL_ID, "interruptFlags") == 0
        and scalar(P.SPELL_ID, "auraInterruptFlags") == 0
        and scalar(P.SPELL_ID, "channelInterruptFlags") == 0
        and scalar(P.SPELL_ID, "procFlags") == 0
        and scalar(P.SPELL_ID, "procChance") == 101
        and scalar(P.SPELL_ID, "procCharges") == 0
        and scalar(P.SPELL_ID, "durationIndex") == 0
        and duration(P.SPELL_ID) == 0
        and scalar(P.SPELL_ID, "powerType", true) == 0
        and scalar(P.SPELL_ID, "manaCost") == 0
        and scalar(P.SPELL_ID, "manaCostPerlevel") == 0
        and scalar(P.SPELL_ID, "manaPerSecond") == 0
        and scalar(P.SPELL_ID, "manaPerSecondPerLevel") == 0
        and scalar(P.SPELL_ID, "rangeIndex") == 1
        and scalar(P.SPELL_ID, "spellFamilyName") == 0
        and scalar(P.SPELL_ID, "spellFamilyFlags") == 0
        and scalar(P.SPELL_ID, "startRecoveryCategory") == 133
        and scalar(P.SPELL_ID, "startRecoveryTime") == P.GCD_MS
        and scalar(P.SPELL_ID, "maxAffectedTargets") == 0
        and equal(triple(P.SPELL_ID, "effect"), P.DUMMY_EFFECT, 0, 0)
        and equal(triple(P.SPELL_ID, "effectBasePoints", true), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectDieSides", true), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(P.SPELL_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectAmplitude"), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectMiscValue", true), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectTriggerSpell"), 0, 0, 0)
end

local function installedProfile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    if not setupTopology() then
        PROFILE = { valid = false, exact = false,
            reason = "Preparation DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = P.SPELL_ID,
        family = P.ROGUE_FAMILY, cooldown = P.COOLDOWN_MS / 1000,
        gcd = P.GCD_MS / 1000,
        predicate = "Rogue family; GetRecoveryTime > 0",
        source = "installed build-5875 DBC plus VMaNGOS EffectDummy(14185)" }
    return copy(PROFILE)
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return copy(cached) end
    local family = scalar(spellId, "spellFamilyName")
    local recovery = scalar(spellId, "recoveryTime")
    local categoryRecovery = scalar(spellId, "categoryRecoveryTime")
    local complete = integer(family, 0, 4294967295) ~= nil
        and integer(recovery, 0, 4294967295) ~= nil
        and integer(categoryRecovery, 0, 4294967295) ~= nil
    local effective = complete and math.max(recovery, categoryRecovery) or nil
    cached = { claimed = true, complete = complete, exact = complete,
        spellId = spellId, family = family, recoveryTime = recovery,
        categoryRecoveryTime = categoryRecovery, effectiveRecovery = effective,
        eligible = complete and family == P.ROGUE_FAMILY
            and effective > 0 or false,
        source = "root-captured installed DBC Preparation server predicate" }
    if not complete then
        cached.reason = "Preparation reset classification is incomplete"
    end
    if ACTION_COUNT < P.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = copy(cached), ACTION_COUNT + 1
    end
    return copy(cached)
end

function P:InferKnowledge(spellId)
    if classToken() ~= "ROGUE" then
        return nil, "player is not an exactly identified Rogue", false
    end
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "spell is not Preparation", false
    end
    local profile, reason = installedProfile()
    if not profile then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        self = true, combatBuff = true, cooldown = true,
        roguePreparation = true, requiresRoguePreparationEvidence = true,
        submissionGuarded = true, roguePreparationEvidence = copy(profile),
        source = profile.source }, nil, true
end

function P:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.roguePreparationEvidence
    if not (facts and facts.roguePreparation == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.family == self.ROGUE_FAMILY
        and found.cooldown == self.COOLDOWN_MS / 1000
        and found.gcd == self.GCD_MS / 1000) then return nil end
    return found
end

function P:CooldownContract(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.roguePreparationCooldown
    if not (type(found) == "table" and found.claimed == true
        and integer(found.spellId, 1, 4294967295)
        and found.complete == true and found.exact == true
        and integer(found.family, 0, 4294967295)
        and integer(found.recoveryTime, 0, 4294967295)
        and integer(found.categoryRecoveryTime, 0, 4294967295)
        and found.effectiveRecovery == math.max(
            found.recoveryTime, found.categoryRecoveryTime)) then return nil end
    local eligible = found.family == self.ROGUE_FAMILY
        and found.effectiveRecovery > 0
    if found.eligible ~= eligible then return nil end
    return found
end

function P:CaptureFacts(action, facts)
    if classToken() ~= "ROGUE" or not (action
        and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return facts end
    local found = actionProfile(action.spellId)
    if not found then return facts end
    local out = copy(facts)
    out.roguePreparationCooldown = found
    local evidence = self:Evidence(out) or self:Evidence(action)
    if evidence then
        out.cost, out.powerType, out.cast = 0, 0, 0
        out.gcd, out.cooldown = evidence.gcd, evidence.cooldown
    end
    return out
end

function P:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
    PLAYER_CLASS, PLAYER_CLASS_KNOWN = nil, false
end
