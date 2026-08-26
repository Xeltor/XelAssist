-- Exact build-5875 Presence of Mind discovery and root cast-time evidence.
-- DBC family masks and the engine's current spell modifiers are frozen before
-- search. Descendants never read localized names or mutable client APIs.
XelAssist.Game.Player.MagePresenceOfMind = {}
local P = XelAssist.Game.Player.MagePresenceOfMind

P.SPELL_ID = 12043
P.MAGE_FAMILY = 3
P.FAMILY_FLAGS = 17179869184
P.AFFECT_MASK = 1073741824
P.ADD_PCT_MODIFIER = 108
P.CASTING_TIME_MODIFIER = 10
P.MODIFIER_PERCENT = -100
P.IGNORE_CASTER_MODIFIERS = 536870912
P.USES_RANGED_SLOT = 2
P.IS_ABILITY = 16
P.IS_TRADESKILL = 32
P.MAX_CACHE = 256

-- Every casting-time record reached by the installed PoM family mask has no
-- level scaling. Unknown indices fail closed instead of borrowing a proxy.
local CASTS = {
    [1] = { base = 0, perLevel = 0, minimum = 0 },
    [5] = { base = 2000, perLevel = 0, minimum = 2000 },
    [14] = { base = 3000, perLevel = 0, minimum = 3000 },
    [16] = { base = 1500, perLevel = 0, minimum = 1500 },
    [19] = { base = 2500, perLevel = 0, minimum = 2500 },
    [21] = { base = 2600, perLevel = 0, minimum = 2600 },
    [22] = { base = 3500, perLevel = 0, minimum = 3500 },
    [23] = { base = 1800, perLevel = 0, minimum = 1800 },
    [24] = { base = 2200, perLevel = 0, minimum = 2200 },
    [171] = { base = 6000, perLevel = 0, minimum = 6000 },
}

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

local function setupTopology()
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, P.SPELL_ID, 1)
        if ok then duration = tonumber(value) end
    end
    return scalar(P.SPELL_ID, "school") == 0
        and scalar(P.SPELL_ID, "category") == 1151
        and scalar(P.SPELL_ID, "dispel") == 1
        and scalar(P.SPELL_ID, "attributes") == 33882112
        and scalar(P.SPELL_ID, "castingTimeIndex") == 1
        and scalar(P.SPELL_ID, "categoryRecoveryTime") == 180000
        and scalar(P.SPELL_ID, "interruptFlags") == 12
        and scalar(P.SPELL_ID, "procFlags") == 87376
        and scalar(P.SPELL_ID, "procChance") == 100
        and scalar(P.SPELL_ID, "procCharges") == 1
        and scalar(P.SPELL_ID, "durationIndex") == 21 and duration == 0
        and scalar(P.SPELL_ID, "powerType", true) == 0
        and scalar(P.SPELL_ID, "manaCost") == 0
        and scalar(P.SPELL_ID, "rangeIndex") == 1
        and scalar(P.SPELL_ID, "spellFamilyName") == P.MAGE_FAMILY
        and scalar(P.SPELL_ID, "spellFamilyFlags") == P.FAMILY_FLAGS
        and scalar(P.SPELL_ID, "maxAffectedTargets") == 0
        and equal(triple(P.SPELL_ID, "effect"), 6, 6, 0)
        and equal(triple(P.SPELL_ID, "effectBasePoints", true), -101, -1, 0)
        and equal(triple(P.SPELL_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(P.SPELL_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(P.SPELL_ID, "effectApplyAuraName"),
            P.ADD_PCT_MODIFIER, P.ADD_PCT_MODIFIER, 0)
        and equal(triple(P.SPELL_ID, "effectItemType"),
            P.AFFECT_MASK, P.AFFECT_MASK, 0)
        and equal(triple(P.SPELL_ID, "effectMiscValue", true),
            P.CASTING_TIME_MODIFIER, 0, 0)
        and equal(triple(P.SPELL_ID, "effectTriggerSpell"), 0, 0, 0)
end

local function installedProfile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    if not setupTopology() then
        PROFILE = { valid = false, exact = false,
            reason = "Presence of Mind DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = P.SPELL_ID,
        family = P.MAGE_FAMILY, familyFlags = P.FAMILY_FLAGS,
        affectMask = P.AFFECT_MASK, modifier = P.CASTING_TIME_MODIFIER,
        modifierPercent = P.MODIFIER_PERCENT, charges = 1, indefinite = true,
        source = "installed build-5875 Presence of Mind DBC and VMaNGOS spellmod" }
    return copy(PROFILE)
end

local function spellInfo(spellId)
    if not (C_Spell and type(C_Spell.GetSpellInfo) == "function") then
        return nil, "base cast-time evidence unavailable"
    end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if not ok or type(info) ~= "table" then
        return nil, "base cast-time evidence unavailable"
    end
    local id = integer(info.spellID, 1, 4294967295)
    local cast = integer(info.castTime, 0, 600000)
    if id ~= spellId or cast == nil then
        return nil, "base cast-time evidence unavailable"
    end
    return cast
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return copy(cached) end
    local family = scalar(spellId, "spellFamilyName")
    local flags = scalar(spellId, "spellFamilyFlags")
    local castIndex = scalar(spellId, "castingTimeIndex")
    local attributes = unsigned32(scalar(spellId, "attributes"))
    local attributesEx3 = unsigned32(scalar(spellId, "attributesEx3"))
    local complete = family ~= nil and flags ~= nil and castIndex ~= nil
        and attributes ~= nil and attributesEx3 ~= nil
    local out = { complete = complete, spellId = spellId, family = family,
        familyFlags = flags, castIndex = castIndex, attributes = attributes }
    if complete then
        local lowFlags = flags - math.floor(flags / 4294967296) * 4294967296
        out.maskMatches = flagSet(lowFlags, P.AFFECT_MASK) == true
        out.ignoresModifiers = flagSet(
            attributesEx3, P.IGNORE_CASTER_MODIFIERS) == true
        out.rangedSlot = flagSet(attributes, P.USES_RANGED_SLOT) == true
        out.nonSpellCastSpeed = flagSet(attributes, P.IS_ABILITY) == true
            or flagSet(attributes, P.IS_TRADESKILL) == true
        if out.maskMatches then
            local cast, reason = spellInfo(spellId)
            local profile = CASTS[castIndex]
            if not (profile and profile.perLevel == 0 and cast == profile.base
                and profile.minimum == profile.base)
                or cast > 0 and out.nonSpellCastSpeed then
                out.complete, out.reason = false,
                    reason or "installed cast-time record is unrecognized"
            else out.baseCastMs = cast end
        end
    end
    if ACTION_COUNT < P.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = copy(out), ACTION_COUNT + 1
    end
    return out
end

local function modifierSnapshot(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "casting-time modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, P.CASTING_TIME_MODIFIER)
    flat, percent = signed32(flat), signed32(percent)
    changed = finite(changed, -4294967295, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "casting-time modifier evidence unavailable"
    end
    return { flat = flat, percent = percent, changed = changed }
end

local function castSpeedMultiplier()
    if type(GetUnitField) ~= "function" then
        return nil, "cast-speed evidence unavailable"
    end
    local ok, multiplier = pcall(GetUnitField, "player", "modCastSpeed")
    multiplier = ok and finite(multiplier, 0.000001, 10000) or nil
    if not multiplier then return nil, "cast-speed evidence unavailable" end
    return multiplier
end

local function effectiveCast(profile, modifier, multiplier)
    local base = profile and profile.baseCastMs
    if not (base and base > 0 and base < 10000 and modifier and multiplier) then
        return nil
    end
    if modifier.percent <= -100 then return nil end
    local modified = math.floor((base + modifier.flat)
        * (100 + modifier.percent) / 100)
    modified = math.max(0, modified)
    modified = math.floor(modified * multiplier)
    if profile.rangedSlot then modified = modified + 500 end
    return modified > 0 and modified or nil
end

local function observeAura(profile)
    local out = { available = false, exact = false, profile = copy(profile),
        source = "ClassicAPI numeric Presence of Mind aura identity" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "Presence of Mind aura evidence unavailable"
        return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, P.SPELL_ID)
    if not ok then out.reason = "Presence of Mind aura evidence unavailable"; return out end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local valid = type(aura) == "table"
        and integer(aura.spellId, 1, 4294967295) == P.SPELL_ID
        and aura.isHelpful == true
        and integer(aura.applications, 1, 255) == 1
        and finite(aura.duration, 0, 0) == 0
        and finite(aura.expirationTime, 0, 0) == 0
    if not valid then
        out.available, out.exact = false, false
        out.reason = "active Presence of Mind aura identity is incomplete"
        return out
    end
    out.active = true
    return out
end

local function castContract(action, state)
    local spellId = action and action.spellId
    local found = actionProfile(spellId)
    if not found then return nil end
    local out = { claimed = true, exact = false, spellId = spellId,
        family = found.family, familyFlags = found.familyFlags,
        maskMatches = found.maskMatches == true }
    if not found.complete then
        out.reason = found.reason or "Presence of Mind action evidence incomplete"
        return out
    end
    if found.family ~= P.MAGE_FAMILY or not found.maskMatches
        or found.ignoresModifiers then
        out.exact, out.eligible = true, false
        out.source = "DBC excludes action from Presence of Mind consumption"
        return out
    end
    if not found.baseCastMs or found.baseCastMs <= 0
        or found.baseCastMs >= 10000 then
        out.reason = "affected cast lifecycle is not a positive PoM cast"
        return out
    end
    local modifier, reason = modifierSnapshot(spellId)
    local multiplier
    if modifier then multiplier, reason = castSpeedMultiplier() end
    if not modifier or not multiplier then out.reason = reason; return out end
    local active = state and state.magePresenceOfMind
        and state.magePresenceOfMind.active == true
    if not active then
        local cast = effectiveCast(found, modifier, multiplier)
        if not cast then
            out.reason = "positive baseline Mage cast time unavailable"
            return out
        end
        out.exact, out.eligible, out.baselineCast = true, true, cast / 1000
        out.source = "clean root Mage cast time plus installed PoM mask"
        return out
    end
    -- The exact active aura contributes one -100 percentage modifier. Strip
    -- that known component from the aggregate root snapshot; all simultaneous
    -- talent/debuff modifiers remain in the reconstructed baseline.
    local stripped = { flat = modifier.flat,
        percent = modifier.percent - P.MODIFIER_PERCENT }
    local cast = effectiveCast(found, stripped, multiplier)
    if cast then
        out.exact, out.eligible, out.baselineCast = true, true, cast / 1000
        out.source = "engine-confirmed active Presence of Mind cast delta"
        return out
    end
    out.reason = "Presence of Mind baseline or active cast delta unavailable"
    return out
end

function P:InferKnowledge(spellId)
    if classToken() ~= "MAGE" then
        return nil, "player is not an exactly identified Mage", false
    end
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "spell is not Presence of Mind", false
    end
    local profile, reason = installedProfile()
    if not profile then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        self = true, combatBuff = true, cooldown = true,
        magePresenceOfMind = true, requiresMagePresenceOfMindEvidence = true,
        submissionGuarded = true, magePresenceOfMindEvidence = copy(profile),
        source = profile.source }, nil, true
end

function P:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.magePresenceOfMindEvidence
    if not (facts and facts.magePresenceOfMind == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.family == self.MAGE_FAMILY
        and found.familyFlags == self.FAMILY_FLAGS
        and found.affectMask == self.AFFECT_MASK
        and found.modifier == self.CASTING_TIME_MODIFIER
        and found.modifierPercent == self.MODIFIER_PERCENT
        and found.charges == 1 and found.indefinite == true) then return nil end
    return found
end

function P:Is(subject)
    return self:Evidence(subject) ~= nil
end

function P:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.magePresenceOfMind = nil
    if (knownClass or classToken()) ~= "MAGE" then return false end
    local profile, reason = installedProfile()
    if not profile then
        state.magePresenceOfMind = { available = false, exact = false,
            reason = reason, source = "installed build-5875 Presence of Mind DBC" }
        return false
    end
    state.magePresenceOfMind = observeAura(profile)
    return state.magePresenceOfMind.exact == true
end

function P:CaptureFacts(action, facts, state)
    local evidence = state and state.magePresenceOfMind
    if not (evidence and evidence.available == true and evidence.exact == true
        and action and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return facts end
    local contract = castContract(action, state)
    if not contract then return facts end
    local out = copy(facts)
    out.magePresenceOfMindCast = contract
    return out
end

function P:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
end
