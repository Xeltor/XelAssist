-- Installed Octo patch-5 Stormstrike identity and root-only aura observation.
-- Mutable spell/aura APIs are never used by graph descendants.
XelAssist.Game.Player.ShamanStormstrike = {}
local S = XelAssist.Game.Player.ShamanStormstrike

S.SPELL_ID, S.AURA_ID = 17364, 52412
S.NATURE_MASK, S.AMPLIFIER = 8, 0.25
S.CHARGES, S.DURATION, S.COOLDOWN = 2, 12, 8
local PROFILE

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value
        or (low and value < low) or (high and value > high) then return nil end
    return value
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(value) ~= "table" or value[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do out[index] = finite(value[index]) end
    if out[1] == nil or out[2] == nil or out[3] == nil then return nil end
    return out
end
local function equals(value, a, b, c)
    return value and value[1] == a and value[2] == b and value[3] == c
end
local function copy(value, depth)
    if type(value) ~= "table" or depth <= 0 then return value end
    local out, key, entry = {}, nil, nil
    for key, entry in pairs(value) do out[key] = copy(entry, depth - 1) end
    return out
end
local function shaman()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "SHAMAN"
end
local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, id, 1)
    return ok and finite(value, 1, 3600000) or nil
end

local function profile()
    if PROFILE ~= nil then return PROFILE or nil,
        PROFILE and nil or "installed Stormstrike topology unavailable" end
    local parentOK = scalar(S.SPELL_ID, "school") == 0
        and scalar(S.SPELL_ID, "spellFamilyName") == 11
        and scalar(S.SPELL_ID, "spellFamilyFlags2") == 512
        and scalar(S.SPELL_ID, "category") == 971
        and scalar(S.SPELL_ID, "attributes") == 65536
        and scalar(S.SPELL_ID, "attributesEx") == 512
        and scalar(S.SPELL_ID, "attributesEx3") == 1024
        and scalar(S.SPELL_ID, "castingTimeIndex") == 1
        and scalar(S.SPELL_ID, "durationIndex") == 21
        and scalar(S.SPELL_ID, "categoryRecoveryTime") == 8000
        and scalar(S.SPELL_ID, "procChance") == 101
        and scalar(S.SPELL_ID, "spellLevel") == 30
        and scalar(S.SPELL_ID, "powerType") == 0
        and scalar(S.SPELL_ID, "manaCostPercentage") == 10
        and scalar(S.SPELL_ID, "rangeIndex") == 2
        and scalar(S.SPELL_ID, "equippedItemClass") == 2
        and scalar(S.SPELL_ID, "equippedItemSubClassMask") == 173555
        and scalar(S.SPELL_ID, "startRecoveryCategory") == 133
        and scalar(S.SPELL_ID, "startRecoveryTime") == 1500
        and scalar(S.SPELL_ID, "dmgClass") == 2
        and scalar(S.SPELL_ID, "preventionType") == 2
        and equals(triple(S.SPELL_ID, "effect"), 31, 64, 0)
        and equals(triple(S.SPELL_ID, "effectImplicitTargetA"), 6, 1, 0)
        and equals(triple(S.SPELL_ID, "effectTriggerSpell"), 0, S.AURA_ID, 0)
    local childOK = scalar(S.AURA_ID, "dispel") == 1
        and scalar(S.AURA_ID, "attributesEx3") == 67108864
        and scalar(S.AURA_ID, "spellFamilyName") == 11
        and scalar(S.AURA_ID, "spellFamilyFlags2") == 512
        and scalar(S.AURA_ID, "spellLevel") == 30
        and scalar(S.AURA_ID, "school") == 0
        and scalar(S.AURA_ID, "procChance") == 100
        and scalar(S.AURA_ID, "procFlags") == 69972
        and scalar(S.AURA_ID, "procCharges") == S.CHARGES
        and scalar(S.AURA_ID, "durationIndex") == 29
        and duration(S.AURA_ID) == S.DURATION * 1000
        and equals(triple(S.AURA_ID, "effect"), 6, 0, 0)
        and equals(triple(S.AURA_ID, "effectBasePoints"), 24, 0, 0)
        and equals(triple(S.AURA_ID, "effectApplyAuraName"), 79, 0, 0)
        and equals(triple(S.AURA_ID, "effectMiscValue"), S.NATURE_MASK, 0, 0)
        and equals(triple(S.AURA_ID, "effectImplicitTargetA"), 1, 0, 0)
    if not (parentOK and childOK) then PROFILE = false
        return nil, "installed Stormstrike topology unavailable" end
    PROFILE = { valid = true, exact = true, spellId = S.SPELL_ID,
        auraSpellId = S.AURA_ID, charges = S.CHARGES, duration = S.DURATION,
        cooldown = S.COOLDOWN, schoolMask = S.NATURE_MASK,
        damageTakenMultiplier = 1 + S.AMPLIFIER,
        directNatureOnly = true, periodicConsumptionUnknown = true,
        source = "installed Octo patch-5 numeric Stormstrike topology" }
    return PROFILE
end

function S:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then return nil, nil, false end
    if not shaman() then
        return nil, "player is not an exactly identified Shaman", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        melee = true, hostile = true, deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true,
        requiresExactUsability = true, submissionGuarded = true, school = 0,
        resourceType = "mana", cooldown = true, gcd = 1.5,
        shamanStormstrike = true, requiresShamanStormstrikeEvidence = true,
        shamanStormstrikeEvidence = copy(found, 3),
        source = found.source }, nil, true
end

function S:CaptureFacts(action, facts)
    if tonumber(action and action.spellId) ~= self.SPELL_ID then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local found, reason = profile()
    out.shamanStormstrike, out.shamanStormstrikeEvidence = true, copy(found, 3)
    out.requiresShamanStormstrikeEvidence = found == nil and true or nil
    out.shamanStormstrikeEvidenceReason = found and nil or reason
    return out
end

function S:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.shamanStormstrikeEvidence
    if not (facts and facts.shamanStormstrike == true and found
        and found.valid == true and found.exact == true
        and found.spellId == self.SPELL_ID and found.auraSpellId == self.AURA_ID
        and found.charges == self.CHARGES and found.duration == self.DURATION
        and found.schoolMask == self.NATURE_MASK
        and found.damageTakenMultiplier == 1 + self.AMPLIFIER
        and found.directNatureOnly == true) then return nil end
    return found
end

function S:Snapshot(token)
    local found, reason = profile()
    local out = { available = false, exact = false, profile = copy(found, 3),
        source = "numeric player Stormstrike aura" }
    if token ~= "SHAMAN" or not shaman() or not found then
        out.reason = reason or "Shaman Stormstrike evidence unavailable"; return out
    end
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "numeric Stormstrike aura evidence unavailable"; return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, self.AURA_ID)
    if not ok then out.reason = "numeric Stormstrike aura evidence unavailable"; return out end
    out.available, out.exact = true, true
    if aura == nil then out.active, out.charges, out.remaining = false, 0, 0; return out end
    local applications = type(aura) == "table" and finite(aura.applications, 1, 2)
    local now, duration, expiration
    if type(GetTime) == "function" then local timeOK, value = pcall(GetTime)
        now = timeOK and finite(value, 0, 1000000000) or nil end
    duration = type(aura) == "table" and finite(aura.duration, 0.001, self.DURATION)
    expiration = type(aura) == "table" and now
        and finite(aura.expirationTime, now, now + self.DURATION) or nil
    if not (applications and math.floor(applications) == applications
        and duration and expiration and duration <= self.DURATION) then
        out.available, out.exact = false, false
        out.reason = "active Stormstrike charge/lifetime unavailable"; return out
    end
    out.active, out.charges = true, applications
    out.remaining = math.max(0, expiration - now)
    return out
end

function S:Invalidate() PROFILE = nil end
