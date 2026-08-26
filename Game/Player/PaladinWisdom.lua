-- Exact single-recipient Blessing of Wisdom evidence from installed build
-- 5875. DBC topology identifies the mechanic; localized names and spell order
-- never participate. Mutable spell modifiers and duration are sealed at root.
XelAssist.Game.Player.PaladinWisdom = {}
local W = XelAssist.Game.Player.PaladinWisdom

W.PALADIN_FAMILY, W.FAMILY_FLAG = 10, 268500992
W.APPLY_AURA, W.PERIODIC_ENERGIZE = 6, 24
W.MANA, W.PERIOD_MS = 0, 5000
W.ALL_EFFECTS_MOD, W.ACTIVATION_TIME_MOD = 8, 19

local RANKS = {
    [19742] = { level = 14, cost = 30, amount = 10 },
    [19850] = { level = 24, cost = 45, amount = 15 },
    [19852] = { level = 34, cost = 65, amount = 20 },
    [19853] = { level = 44, cost = 90, amount = 25 },
    [19854] = { level = 54, cost = 115, amount = 30 },
    [25290] = { level = 60, cost = 125, amount = 33 },
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
        out[index] = finite(values[index], -4294967295, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classification(spellId, found)
    return type(found) == "table" and found.exact == true
        and tonumber(found.spellId) == spellId
        and found.family == W.PALADIN_FAMILY
        and found.flags == W.FAMILY_FLAG and found.kind == "blessing"
        and found.exclusiveFamily == "paladinBlessingByCaster"
end

local function scalarsMatch(spellId)
    local rank = RANKS[spellId]
    return rank and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "maxLevel") == 0
        and scalar(spellId, "manaCost") == rank.cost
        and scalar(spellId, "school") == 1 and scalar(spellId, "dispel") == 1
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 1024
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "durationIndex") == 6
        and scalar(spellId, "powerType") == W.MANA
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "rangeIndex") == 4
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "spellFamilyName") == W.PALADIN_FAMILY
        and scalar(spellId, "spellFamilyFlags") == W.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
end

local function arraysMatch(spellId)
    local rank = RANKS[spellId]
    local points = triple(spellId, "effectBasePoints")
    local base = points and integer(points[1], 0, 1000000)
    return rank and base == rank.amount - 1
        and equal(triple(spellId, "effect"), W.APPLY_AURA, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(points, base, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 21, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"),
            W.PERIODIC_ENERGIZE, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), W.PERIOD_MS, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), W.MANA, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
        and base or nil
end

local function inspect(spellId, sealedClassification)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Wisdom spell identity unavailable", false end
    local cached = CACHE[spellId]
    if not cached then
        local rank = RANKS[spellId]
        local family, flags = scalar(spellId, "spellFamilyName"),
            scalar(spellId, "spellFamilyFlags")
        if not rank and (family ~= W.PALADIN_FAMILY
            or flags ~= W.FAMILY_FLAG) then
            return nil, "spell is not installed single-target Wisdom", false
        end
        local base = scalarsMatch(spellId) and arraysMatch(spellId)
        cached = { recognized = true, valid = base ~= nil, exact = base ~= nil,
            portfolio = "paladinWisdom", spellId = spellId,
            source = "installed build-5875 periodic-energize blessing topology" }
        if base then
            cached.level, cached.baseCost = rank.level, rank.cost
            cached.baseAmount, cached.basePeriod = base + 1, W.PERIOD_MS / 1000
            cached.powerType, cached.zeroThreat = W.MANA, true
            cached.durationIndex, cached.recipientShape = 6, "single"
            cached.family, cached.familyFlag = W.PALADIN_FAMILY, W.FAMILY_FLAG
        else cached.reason = "Wisdom DBC topology is incomplete" end
        CACHE[spellId] = copy(cached)
    end
    local out = copy(cached)
    if not classification(spellId, sealedClassification) then
        out.valid, out.exact = false, false
        out.reason = "captured Wisdom blessing classification unavailable"
    end
    return out.valid and out or nil, out.reason, true
end

local function modifier(spellId, kind)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(GetSpellModifiers, spellId, kind)
    flat, percent = finite(flat, -1000000, 1000000),
        finite(percent, -100, 1000000)
    changed = integer(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil
        or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then return nil end
    return { kind = kind, flat = flat, percent = percent, changed = changed }
end

local function capturedProfile(found)
    local out = copy(found)
    local amountMod = modifier(found.spellId, W.ALL_EFFECTS_MOD)
    local periodMod = modifier(found.spellId, W.ACTIVATION_TIME_MOD)
    local ok, durationMs = false, nil
    if type(GetSpellDuration) == "function" then
        ok, durationMs = pcall(GetSpellDuration, found.spellId)
    end
    durationMs = ok and integer(durationMs, 1, 3600000) or nil
    local amount = amountMod and (found.baseAmount + amountMod.flat)
        * (100 + amountMod.percent) / 100 or nil
    local periodMs = periodMod and math.floor((found.basePeriod * 1000
        + periodMod.flat) * (100 + periodMod.percent) / 100) or nil
    if not integer(amount, 1, 1000000) or not integer(periodMs, 1, 3600000)
        or not durationMs or durationMs < periodMs
        or durationMs - math.floor(durationMs / periodMs) * periodMs ~= 0 then
        out.valid, out.exact = false, false
        out.reason = "Wisdom tick modifiers or duration are not deterministic"
        return out
    end
    out.amount, out.period, out.duration = amount, periodMs / 1000,
        durationMs / 1000
    out.allEffectsModifier, out.activationModifier = amountMod, periodMod
    out.source = out.source .. "; root modifiers and duration"
    return out
end

local function sealedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.paladinWisdomEvidence
    local rank = found and RANKS[found.spellId]
    return type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "paladinWisdom"
        and rank and found.level == rank.level and found.baseCost == rank.cost
        and found.baseAmount == rank.amount and found.durationIndex == 6
        and found.family == W.PALADIN_FAMILY
        and found.familyFlag == W.FAMILY_FLAG
        and found.powerType == W.MANA and found.zeroThreat == true
        and found.basePeriod == W.PERIOD_MS / 1000
        and found.recipientShape == "single" and found or nil
end

local function exactModifier(value, kind)
    local flat = value and finite(value.flat, -1000000, 1000000)
    local percent = value and finite(value.percent, -100, 1000000)
    local changed = value and integer(value.changed, 0, 4294967295)
    return type(value) == "table" and value.kind == kind
        and flat and percent and changed
        and (flat ~= 0 or percent ~= 0) == (changed ~= 0) and value or nil
end

function W:Profile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found, base = facts and facts.paladinWisdomProfile,
        sealedEvidence(facts)
    local amountMod = exactModifier(found and found.allEffectsModifier,
        self.ALL_EFFECTS_MOD)
    local periodMod = exactModifier(found and found.activationModifier,
        self.ACTIVATION_TIME_MOD)
    local amount = base and amountMod and (base.baseAmount + amountMod.flat)
        * (100 + amountMod.percent) / 100 or nil
    local period = base and periodMod and math.floor((base.basePeriod * 1000
        + periodMod.flat) * (100 + periodMod.percent) / 100) / 1000 or nil
    if not (found and base and found.valid == true and found.exact == true
        and found.spellId == base.spellId and found.baseAmount == base.baseAmount
        and found.baseCost == base.baseCost and found.level == base.level
        and integer(amount, 1, 1000000) == found.amount
        and finite(period, 0.001, 3600) == found.period
        and finite(found.duration, found.period, 3600)
        and found.duration / found.period
            == math.floor(found.duration / found.period)) then return nil end
    return copy(found)
end

function W:Promote(spellId, facts)
    if not (facts and facts.paladinBlessing == true) then return facts end
    local found = inspect(spellId, facts.paladinClassification)
    if not found then return facts end
    local out = copy(facts)
    out.paladinRepresentation = "exactSelfPeriodicMana"
    out.paladinEffectRepresented = true
    out.requiresExactPaladinWisdomProfile = true
    out.paladinWisdom = true
    out.paladinWisdomEvidence = copy(found)
    out.paladinDownstreamEffect = { exact = true,
        kind = "playerPeriodicManaEnergize", actor = "recipient",
        sourceSpellId = found.spellId, baseAmount = found.baseAmount,
        period = found.basePeriod, powerType = self.MANA, zeroThreat = true,
        recipientShape = "single", source = found.source }
    return out
end

function W:CaptureFacts(action, facts)
    local found = sealedEvidence(facts)
    if not (found and tonumber(action and action.spellId) == found.spellId) then
        return facts
    end
    local out = copy(facts)
    out.paladinWisdomProfile = capturedProfile(found)
    if not self:Profile(out) then
        out.paladinEffectRepresented = false
        out.paladinDownstreamEffect = nil
    else out.duration = out.paladinWisdomProfile.duration end
    return out
end

function W:Evidence(subject)
    local found = sealedEvidence(subject)
    return found and copy(found) or nil
end

function W:Inspect(spellId, sealedClassification)
    local found, reason, handled = inspect(spellId, sealedClassification)
    return found and copy(found) or nil, reason, handled
end

local function activeTiming(aura, profile, now)
    local duration = finite(aura and aura.duration, 0.001, 3600)
    local expiration = finite(aura and aura.expirationTime, 0.001, 100000000)
    local remaining = expiration and now and expiration - now or nil
    if not (duration == profile.duration and remaining and remaining > 0
        and remaining <= duration + 0.01) then return nil, nil end
    local cycles = math.floor(remaining / profile.period)
    local nextIn = remaining - cycles * profile.period
    if nextIn <= 0.0001 then nextIn = profile.period end
    return remaining, nextIn
end

function W:ObserveRoot(player, playerGUID)
    local out = { available = false, exact = false,
        portfolio = "paladinWisdom" }
    if classToken() ~= "PALADIN" or not (player and player.available == true
        and player.guid == playerGUID and player.playerGUID == playerGUID) then
        out.reason = "exact Paladin self blessing state unavailable"; return out
    end
    local ok, now = false, nil
    if type(GetTime) == "function" then ok, now = pcall(GetTime) end
    now = ok and finite(now, 0, 100000000) or nil
    if not now then out.reason = "Wisdom aura clock unavailable"; return out end
    local caster, aura
    for caster, aura in pairs(player.blessingsByCaster or {}) do
        local found, reason, handled = inspect(
            aura and aura.spellId, aura and aura.classification)
        if handled and not found then out.reason = reason; return out end
        if found then
            if caster ~= playerGUID or out.activeSpellId then
                out.reason = "external Wisdom stacking is unresolved"; return out
            end
            local profile = capturedProfile(found)
            local remaining, nextIn = activeTiming(aura, profile, now)
            if not (self:Profile({ paladinWisdomEvidence = found,
                paladinWisdomProfile = profile }) and remaining and nextIn) then
                out.reason = profile.reason or "active Wisdom timing unavailable"
                return out
            end
            out.activeSpellId, out.activeProfile = found.spellId, profile
            out.activeRemaining, out.activeNextIn = remaining, nextIn
        elseif caster == playerGUID then
            out.ownOtherBlessingSpellId = tonumber(aura and aura.spellId)
        end
    end
    out.available, out.exact = true, true
    out.source = "exact self aura and build-5875 Wisdom profile"
    return out
end

function W:Invalidate()
    CACHE = {}
end
