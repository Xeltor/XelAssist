-- Numeric build-5875 Rapid Fire evidence. Mutable aura, spell-modifier and
-- cast-speed reads are frozen at the root; graph descendants consume only the
-- sealed reset/cast contracts produced here.
XelAssist.Game.Player.HunterRapidFire = {}
local R = XelAssist.Game.Player.HunterRapidFire

R.SPELL_ID = 3045
R.HUNTER_FAMILY = 9
R.AFFECT_MASK = 131072
R.ATTACK_SPEED_AURA = 9
R.CAST_MOD_AURA = 108
R.CAST_MOD_OPERATION = 10
R.HASTE_PERCENT = 40
R.CAST_PERCENT = -40
R.DURATION = 15
R.RANGED_SLOT = 2
R.IGNORE_CASTER_MODIFIERS = 536870912
R.MAX_ACTION_CACHE = 128

local PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0

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
    return signed and signed32(value)
        or finite(value, -2147483648, 9007199254740991)
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

local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function flagSet(value, mask)
    value, mask = unsigned32(value), unsigned32(mask)
    if not value or not mask then return nil end
    return math.floor(value / mask) - math.floor(value / (mask * 2)) * 2 == 1
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function installedTopology()
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, R.SPELL_ID, 1)
        if ok then duration = finite(value, 0, 3600) end
    end
    return scalar(R.SPELL_ID, "school") == 6
        and scalar(R.SPELL_ID, "category") == 55
        and scalar(R.SPELL_ID, "dispel") == 1
        and scalar(R.SPELL_ID, "mechanic") == 0
        and scalar(R.SPELL_ID, "attributes") == 65536
        and scalar(R.SPELL_ID, "castingTimeIndex") == 1
        and scalar(R.SPELL_ID, "recoveryTime") == 300000
        and scalar(R.SPELL_ID, "categoryRecoveryTime") == 0
        and scalar(R.SPELL_ID, "durationIndex") == 8
        and duration == R.DURATION
        and scalar(R.SPELL_ID, "powerType", true) == 0
        and scalar(R.SPELL_ID, "manaCost") == 100
        and scalar(R.SPELL_ID, "rangeIndex") == 1
        and scalar(R.SPELL_ID, "startRecoveryCategory") == 0
        and scalar(R.SPELL_ID, "startRecoveryTime") == 0
        and scalar(R.SPELL_ID, "spellFamilyName") == R.HUNTER_FAMILY
        and scalar(R.SPELL_ID, "spellFamilyFlags") == 32
        and scalar(R.SPELL_ID, "maxAffectedTargets") == 0
        and equal(triple(R.SPELL_ID, "effect"), 6, 6, 0)
        and equal(triple(R.SPELL_ID, "effectDieSides"), 1, 1, 0)
        and equal(triple(R.SPELL_ID, "effectBasePoints", true), 39, -41, 0)
        and equal(triple(R.SPELL_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(R.SPELL_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(R.SPELL_ID, "effectApplyAuraName"),
            R.ATTACK_SPEED_AURA, R.CAST_MOD_AURA, 0)
        and equal(triple(R.SPELL_ID, "effectItemType"), 0, R.AFFECT_MASK, 0)
        and equal(triple(R.SPELL_ID, "effectMiscValue", true),
            0, R.CAST_MOD_OPERATION, 0)
        and equal(triple(R.SPELL_ID, "effectTriggerSpell"), 0, 0, 0)
end

local function profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not installedTopology() then
        PROFILE = { valid = false, exact = false,
            reason = "Rapid Fire DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = R.SPELL_ID,
        family = R.HUNTER_FAMILY, affectMask = R.AFFECT_MASK,
        hastePercent = R.HASTE_PERCENT, castPercent = R.CAST_PERCENT,
        duration = R.DURATION, attackAura = R.ATTACK_SPEED_AURA,
        castAura = R.CAST_MOD_AURA, castOperation = R.CAST_MOD_OPERATION,
        runtimeUnverified = true,
        source = "installed build-5875 Rapid Fire topology" }
    return copy(PROFILE)
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    if ACTIONS[spellId] then return copy(ACTIONS[spellId]) end
    local family = scalar(spellId, "spellFamilyName")
    local flags = scalar(spellId, "spellFamilyFlags")
    local castIndex = scalar(spellId, "castingTimeIndex")
    local attributes = unsigned32(scalar(spellId, "attributes"))
    local attributesEx3 = unsigned32(scalar(spellId, "attributesEx3"))
    local out = { claimed = false, exact = false, spellId = spellId,
        family = family, familyFlags = flags }
    if not (family and flags and castIndex and attributes and attributesEx3) then
        out.reason = "Rapid Fire action DBC evidence is incomplete"
    else
        local low = flags - math.floor(flags / 4294967296) * 4294967296
        out.maskMatches = family == R.HUNTER_FAMILY
            and flagSet(low, R.AFFECT_MASK) == true
        out.claimed = out.maskMatches
        out.ignoresModifiers = flagSet(
            attributesEx3, R.IGNORE_CASTER_MODIFIERS) == true
        out.rangedSlot = flagSet(attributes, R.RANGED_SLOT) == true
        if not out.maskMatches or out.ignoresModifiers then
            out.exact, out.eligible = true, false
        elseif castIndex ~= 5 then
            out.reason = "affected Rapid Fire cast record is unrecognized"
        elseif not (C_Spell and type(C_Spell.GetSpellInfo) == "function") then
            out.reason = "Rapid Fire base cast evidence is unavailable"
        else
            local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
            local id = ok and type(info) == "table"
                and integer(info.spellID, 1, 4294967295) or nil
            local cast = ok and type(info) == "table"
                and integer(info.castTime, 0, 600000) or nil
            if id ~= spellId or cast ~= 2000 or not out.rangedSlot then
                out.reason = "affected Rapid Fire cast shape is unrecognized"
            else
                out.exact, out.eligible, out.baseCastMs = true, true, cast
            end
        end
    end
    if ACTION_COUNT < R.MAX_ACTION_CACHE then
        ACTIONS[spellId], ACTION_COUNT = copy(out), ACTION_COUNT + 1
    end
    return copy(out)
end

local function modifier(spellId)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, R.CAST_MOD_OPERATION)
    flat, percent = signed32(flat), signed32(percent)
    if not ok or flat == nil or percent == nil
        or finite(changed, -4294967295, 4294967295) == nil then return nil end
    return { flat = flat, percent = percent }
end

local function castSpeed()
    if type(GetUnitField) ~= "function" then return nil end
    local ok, value = pcall(GetUnitField, "player", "modCastSpeed")
    return ok and finite(value, 0.000001, 10000) or nil
end

local function effectiveCast(found, mod, speed)
    if not (found and found.baseCastMs and mod and speed
        and mod.percent > -100) then return nil end
    local cast = math.floor((found.baseCastMs + mod.flat)
        * (100 + mod.percent) / 100)
    cast = math.floor(math.max(0, cast) * speed)
    if found.rangedSlot then cast = cast + 500 end
    return cast > 0 and cast / 1000 or nil
end

local function castContract(action, active)
    local found = actionProfile(action and action.spellId)
    if not found then return nil end
    if found.exact ~= true or found.eligible ~= true then return found end
    local mod, speed = modifier(found.spellId), castSpeed()
    if not (mod and speed) then
        found.exact, found.reason = false,
            "Rapid Fire mutable cast evidence is unavailable"
        return found
    end
    local clean = { flat = mod.flat, percent = mod.percent }
    if active then clean.percent = clean.percent - R.CAST_PERCENT end
    local hasted = { flat = clean.flat,
        percent = clean.percent + R.CAST_PERCENT }
    found.baselineCast = effectiveCast(found, clean, speed)
    found.activeCast = effectiveCast(found, hasted, speed)
    if not (found.baselineCast and found.activeCast
        and found.activeCast < found.baselineCast) then
        found.exact, found.reason = false,
            "Rapid Fire cast-time delta is unavailable"
    end
    return found
end

local function auraSnapshot(found)
    local out = { available = false, exact = false, profile = copy(found) }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "numeric Rapid Fire aura evidence unavailable"
        return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, R.SPELL_ID)
    if not ok then out.reason = "numeric Rapid Fire aura evidence unavailable"; return out end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local now
    if type(GetTime) == "function" then
        local clockOk, clock = pcall(GetTime)
        if clockOk then now = finite(clock, 0, 1000000000) end
    end
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime, 0, 1000000000) or nil
    local remaining = expiration and now and expiration - now or nil
    if not (type(aura) == "table" and aura.spellId == R.SPELL_ID
        and aura.isHelpful == true and finite(aura.duration, 15, 15) == 15
        and remaining and remaining > 0) then
        out.available, out.exact = false, false
        out.reason = "active Rapid Fire aura evidence is incomplete"
        return out
    end
    out.active, out.remaining = true, remaining
    return out
end

function R:InferKnowledge(spellId)
    if classToken() ~= "HUNTER" or tonumber(spellId) ~= self.SPELL_ID then
        return nil, "spell is not an exact Hunter Rapid Fire identity", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        self = true, cooldown = true, gcd = 0, combatBuff = true,
        hunterRapidFire = true, requiresHunterRapidFireEvidence = true,
        submissionGuarded = true, hunterRapidFireEvidence = copy(found),
        source = found.source }, nil, true
end

function R:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterRapidFireEvidence
    if not (facts and facts.hunterRapidFire == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.family == self.HUNTER_FAMILY
        and found.affectMask == self.AFFECT_MASK
        and found.hastePercent == self.HASTE_PERCENT
        and found.castPercent == self.CAST_PERCENT
        and found.duration == self.DURATION
        and found.attackAura == self.ATTACK_SPEED_AURA
        and found.castAura == self.CAST_MOD_AURA
        and found.castOperation == self.CAST_MOD_OPERATION
        and found.runtimeUnverified == true) then return nil end
    return found
end

function R:Snapshot(knownClass)
    if (knownClass or classToken()) ~= "HUNTER" then return nil end
    local found, reason = profile()
    if not found then return { available = false, exact = false, reason = reason } end
    return auraSnapshot(found)
end

function R:CaptureFacts(action, facts, state)
    local out = copy(facts)
    local setup = self:Evidence(action) or self:Evidence(facts)
    if setup then
        out.hunterRapidFire, out.self = true, true
        out.kind, out.kindExact, out.gcd = "modifier", true, 0
        out.hunterRapidFireEvidence = copy(setup)
    end
    if action and (action.actor or "player") == "player"
        and action.executor == "playerSpell" then
        local root = state and state.hunterRapidFire
        local active = root and root.available == true and root.exact == true
            and root.active == true or false
        out.hunterRapidFireCast = castContract(action, active)
    end
    return out
end

function R:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
end
