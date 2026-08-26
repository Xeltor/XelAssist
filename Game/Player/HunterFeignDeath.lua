-- Exact installed Feign Death identity and root aura state. Threat success is
-- deliberately not asserted: the server rolls bounded hostile references and
-- the graph must retain that coupled success/resist uncertainty.
XelAssist.Game.Player.HunterFeignDeath = {}
local F = XelAssist.Game.Player.HunterFeignDeath

F.SPELL_ID, F.HUNTER_FAMILY, F.FAMILY_FLAG = 5384, 9, 256
F.MANA, F.AURA_TYPE = 0, 66
F.MODEL, F.DURATION = "resistible-all-or-nothing", 360
F.COOLDOWN, F.COST = 30, 80
local PROFILE = nil

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
local function scalar(field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, F.SPELL_ID, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then
        value = value - 4294967296
    end
    return value
end
local function triple(field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, F.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = integer(values[index], signed and -2147483648 or 0,
            4294967295)
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b
        and values[3] == c
end
local function hunter()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "HUNTER"
end

local function topology()
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, F.SPELL_ID, 1)
        duration = ok and integer(value, 1, 3600000) or nil
    end
    return scalar("school") == 0 and scalar("category") == 0
        and scalar("dispel") == 0 and scalar("mechanic") == 0
        and scalar("attributes") == 34930944
        and scalar("attributesEx") == 394240
        and scalar("attributesEx2") == 0
        and scalar("attributesEx3") == 0
        and scalar("attributesEx4") == 0
        and scalar("stances") == 0 and scalar("stancesNot") == 0
        and scalar("castingTimeIndex") == 1
        and scalar("recoveryTime") == F.COOLDOWN * 1000
        and scalar("categoryRecoveryTime") == 0
        and scalar("interruptFlags") == 15
        and scalar("auraInterruptFlags") == 15420
        and scalar("channelInterruptFlags") == 0
        and scalar("baseLevel") == 30 and scalar("spellLevel") == 30
        and scalar("durationIndex") == 41 and duration == F.DURATION * 1000
        and scalar("powerType", true) == F.MANA
        and scalar("manaCost") == F.COST
        and scalar("manaCostPerlevel") == 0
        and scalar("manaCostPercentage") == 0
        and scalar("rangeIndex") == 1
        and scalar("spellFamilyName") == F.HUNTER_FAMILY
        and scalar("spellFamilyFlags") == F.FAMILY_FLAG
        and equal(triple("effect"), 6, 0, 0)
        and equal(triple("effectDieSides"), 1, 0, 0)
        and equal(triple("effectBaseDice"), 1, 0, 0)
        and equal(triple("effectBasePoints", true), -1, 0, 0)
        and equal(triple("effectImplicitTargetA"), 1, 0, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"), F.AURA_TYPE, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
end

local function profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not topology() then
        PROFILE = { valid = false, exact = false,
            reason = "Feign Death DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = F.SPELL_ID,
        family = F.HUNTER_FAMILY, familyFlag = F.FAMILY_FLAG,
        auraType = F.AURA_TYPE, model = F.MODEL, duration = F.DURATION,
        cooldown = F.COOLDOWN, powerType = F.MANA, cost = F.COST,
        outcomeCoupled = true, petCombatContinues = true,
        interruptsPlayerAttacks = true, runtimeUnverified = true,
        source = "installed Octo patch-5 DBC plus VMaNGOS e5f3fd0 lifecycle" }
    return copy(PROFILE)
end

function F:InferKnowledge(spellId)
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "not installed Feign Death", false
    elseif not hunter() then
        return nil, "player is not an exactly identified Hunter", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "threatDrop", kindExact = true,
        self = true, fixedTarget = "player", recipientRelation = "friendly",
        recipientRelationExact = true, resourceType = "mana", cooldown = true,
        gcd = 0, hunterFeignDeath = true, threatDropModel = self.MODEL,
        requiresHunterFeignDeathEvidence = true,
        requiresExactUsability = true, submissionGuarded = true,
        runtimeUnverified = true, hunterFeignDeathEvidence = copy(found),
        source = found.source }, nil, true
end

function F:CaptureFacts(action, facts)
    if not (action and tonumber(action.spellId) == self.SPELL_ID) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local found, reason = profile()
    out.hunterFeignDeath, out.threatDropModel = true, self.MODEL
    out.hunterFeignDeathEvidence = found
    if not found then
        out.requiresHunterFeignDeathEvidence = true
        out.hunterFeignDeathEvidenceReason = reason
    end
    return out
end

function F:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterFeignDeathEvidence
    if not (facts and facts.hunterFeignDeath == true and found
        and found.valid == true and found.exact == true
        and found.spellId == self.SPELL_ID and found.model == self.MODEL
        and found.duration == self.DURATION and found.cooldown == self.COOLDOWN
        and found.cost == self.COST and found.outcomeCoupled == true
        and found.petCombatContinues == true
        and found.interruptsPlayerAttacks == true) then return nil end
    return found
end

function F:Snapshot(token)
    local found, reason = profile()
    local out = { available = false, exact = false, profile = found,
        source = "numeric player Feign Death aura" }
    if token ~= "HUNTER" or not hunter() or not found then
        out.reason = reason or "Hunter Feign Death evidence unavailable"
        return out
    end
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "numeric Feign Death aura evidence unavailable"; return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, self.SPELL_ID)
    if not ok then
        out.reason = "numeric Feign Death aura evidence unavailable"; return out
    end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local now
    if type(GetTime) == "function" then
        local timeOK, value = pcall(GetTime)
        now = timeOK and finite(value, 0, 1000000000) or nil
    end
    local duration = type(aura) == "table"
        and finite(aura.duration, 0.001, self.DURATION) or nil
    local expiration = type(aura) == "table" and now
        and finite(aura.expirationTime, now, now + self.DURATION) or nil
    if not (duration and expiration and duration <= self.DURATION) then
        out.available, out.exact = false, false
        out.reason = "active Feign Death lifetime unavailable"; return out
    end
    out.active, out.remaining = true, math.max(0, expiration - now)
    out.outcomeKnown = false
    return out
end

function F:Invalidate() PROFILE = nil end
