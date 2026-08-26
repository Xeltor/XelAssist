-- Exact patch-5 Barkskin action plus its linked 22839 aura. The linked row
-- proves the physical mitigation and both opportunity costs; graph descendants
-- consume only this sealed root contract.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.DruidBarkskin = {}
local B = XelAssist.Game.Player.DruidBarkskin

B.SPELL_ID = 22812
B.AURA_ID = 22839
B.DRUID_FAMILY = 7
local PROFILE_CACHE

local function finite(value, low, high)
    value = tonumber(value)
    return value and value == value and value >= low and value <= high
        and value or nil
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
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
        if not integer(key, 1, 3) then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -4294967295, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function duration(spellId, base)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, spellId, base and 1 or nil)
    value = ok and integer(value, 1, 60000) or nil
    return value and value / 1000 or nil
end

local function actionShapeMatches()
    return scalar(B.SPELL_ID, "school") == 3
        and scalar(B.SPELL_ID, "attributes") == 65536
        and scalar(B.SPELL_ID, "recoveryTime") == 60000
        and scalar(B.SPELL_ID, "durationIndex") == 8
        and scalar(B.SPELL_ID, "powerType") == 0
        and scalar(B.SPELL_ID, "manaCost") == 0
        and scalar(B.SPELL_ID, "spellFamilyName") == B.DRUID_FAMILY
        and equal(triple(B.SPELL_ID, "effect"), 6, 6, 6)
        and equal(triple(B.SPELL_ID, "effectBasePoints"), 99, 0, 999)
        and equal(triple(B.SPELL_ID, "effectImplicitTargetA"), 1, 0, 1)
        and equal(triple(B.SPELL_ID, "effectApplyAuraName"), 149, 192, 107)
        and equal(triple(B.SPELL_ID, "effectTriggerSpell"), 0, B.AURA_ID, 0)
end

local function linkedAuraMatches()
    return scalar(B.AURA_ID, "school") == 3
        and scalar(B.AURA_ID, "attributes") == 65920
        and scalar(B.AURA_ID, "durationIndex") == 8
        and equal(triple(B.AURA_ID, "effect"), 6, 6, 0)
        and equal(triple(B.AURA_ID, "effectBasePoints"), -26, -21, 0)
        and equal(triple(B.AURA_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(B.AURA_ID, "effectApplyAuraName"), 138, 87, 0)
        and equal(triple(B.AURA_ID, "effectMiscValue"), 0, 1, 0)
end

local function discover()
    if PROFILE_CACHE then return copy(PROFILE_CACHE) end
    local found = {
        recognized = true, valid = false, exact = false,
        portfolio = "druidBarkskin", spellId = B.SPELL_ID,
        auraId = B.AURA_ID,
        source = "installed Octo patch-5 Barkskin linked topology",
    }
    if not (actionShapeMatches() and linkedAuraMatches()
        and duration(B.SPELL_ID, true) == 10
        and duration(B.AURA_ID, true) == 10) then
        found.reason = "Barkskin patch-5 topology is incomplete"
    else
        found.duration = duration(B.SPELL_ID, false)
        if found.duration ~= 10 then
            found.reason = "Barkskin effective duration is unavailable"
        else
            found.valid, found.exact = true, true
            found.cost, found.powerType = 0, 0
            found.cooldown, found.gcd, found.cast = 60, 1, 0
            found.physicalDamageMultiplier = 0.8
            found.nonInstantCastTimeAdded = 1
            found.meleeAttackRateMultiplier = 0.75
            found.pushbackImmune = true
        end
    end
    PROFILE_CACHE = copy(found)
    return copy(found)
end

function B:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "not installed Barkskin", false
    end
    if classToken() ~= "DRUID" then
        return nil, "player is not an exactly identified Druid", false
    end
    local found = discover()
    if not found.valid then return nil, found.reason, true end
    return {
        inferred = true, kind = "defensive", kindExact = true,
        self = true, fixedTarget = "player", druidBarkskin = true,
        requiresExactDruidBarkskin = true, requiresExactUsability = true,
        submissionGuarded = true, cost = 0, powerType = 0,
        cooldown = 60, gcd = 1, cast = 0,
        druidBarkskinEvidence = copy(found), source = found.source,
    }, nil, true
end

function B:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.druidBarkskinEvidence
    if not (facts and facts.druidBarkskin == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "druidBarkskin"
        and found.spellId == self.SPELL_ID and found.auraId == self.AURA_ID
        and found.duration == 10 and found.physicalDamageMultiplier == 0.8
        and found.nonInstantCastTimeAdded == 1
        and found.meleeAttackRateMultiplier == 0.75
        and found.pushbackImmune == true) then return nil end
    return copy(found)
end

function B:CaptureFacts(action, facts)
    local found = self:Evidence(facts) or self:Evidence(action)
    if not found then return facts end
    local out = copy(facts)
    out.druidBarkskinEvidence = copy(found)
    out.cost, out.powerType, out.duration = 0, 0, found.duration
    out.gcd, out.cast = 1, 0
    return out
end

local function auraSnapshot(found)
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
        and type(GetTime) == "function") then
        return { available = false, exact = false,
            reason = "Barkskin aura evidence unavailable" }
    end
    local ok, aura = pcall(
        C_UnitAuras.GetPlayerAuraBySpellID, B.SPELL_ID)
    local timeOk, now = pcall(GetTime)
    now = timeOk and tonumber(now) or nil
    if not ok or not now then
        return { available = false, exact = false,
            reason = "Barkskin aura evidence unavailable" }
    end
    local out = { available = true, exact = true, active = false,
        profile = copy(found) }
    if aura == nil then return out end
    local expiration = type(aura) == "table" and tonumber(aura.expirationTime)
    if tonumber(aura and aura.spellId) ~= B.SPELL_ID
        or aura.isHelpful ~= true or not expiration or expiration <= now
        or expiration - now > found.duration + 0.01 then
        return { available = false, exact = false,
            reason = "active Barkskin aura is incomplete" }
    end
    out.active, out.remaining, out.epoch = true, expiration - now, expiration
    return out
end

function B:Snapshot(knownClass)
    if (knownClass or classToken()) ~= "DRUID" then return nil end
    local found = discover()
    if not found.valid then
        return { available = false, exact = false, reason = found.reason }
    end
    return auraSnapshot(found)
end

function B:Invalidate()
    PROFILE_CACHE = nil
end
