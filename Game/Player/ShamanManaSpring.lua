-- Exact Mana Spring Totem discovery for installed build 5875.  The generic
-- Shaman adapter owns water-slot replacement and lifetime; this leaf seals the
-- passive area-aura topology and the player's live spell modifiers before
-- graph search.  Only deterministic solo-self ticks are promoted.
XelAssist.Game.Player.ShamanManaSpring = {}
local M = XelAssist.Game.Player.ShamanManaSpring

M.ELEMENT, M.SLOT, M.RADIUS = "water", 3, 30
M.MANA, M.ALL_EFFECTS_MOD, M.ACTIVATION_TIME_MOD = 0, 8, 19
M.PERIOD_MS, M.AURA_TYPE, M.AREA_EFFECT = 2000, 24, 35

local RANKS = {
    [5675] = { aura = 5677, creature = 3573, level = 26,
        cost = 40, amount = 4 },
    [10495] = { aura = 10491, creature = 7414, level = 36,
        cost = 60, amount = 6 },
    [10496] = { aura = 10493, creature = 7415, level = 46,
        cost = 80, amount = 8 },
    [10497] = { aura = 10494, creature = 7416, level = 56,
        cost = 100, amount = 10 },
}
local PROFILE = {}

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
    for key, value in pairs(source or {}) do
        if type(value) == "table" then out[key] = copy(value)
        else out[key] = value end
    end
    return out
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 9007199254740991) or nil
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

local ZERO_FIELDS = { "effectDicePerLevel", "effectRealPointsPerLevel",
    "effectMechanic", "effectMultipleValue", "effectChainTarget",
    "effectItemType", "effectPointsPerComboPoint" }

local function zeroFields(spellId)
    local index
    for index = 1, table.getn(ZERO_FIELDS) do
        if not equal(triple(spellId, ZERO_FIELDS[index]), 0, 0, 0) then
            return false
        end
    end
    return true
end

local function commonScalar(spellId, school, level, duration, cost, flags)
    return scalar(spellId, "school") == school
        and scalar(spellId, "attributes") == (school == 4 and 65536 or 0)
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "baseLevel") == level
        and scalar(spellId, "spellLevel") == level
        and scalar(spellId, "durationIndex") == duration
        and scalar(spellId, "powerType") == M.MANA
        and scalar(spellId, "manaCost") == cost
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "spellFamilyName") == 11
        and scalar(spellId, "spellFamilyFlags") == flags
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end

local function actionTopology(spellId, rank)
    return commonScalar(spellId, 4, rank.level, 3, rank.cost,
            4504149383184384)
        and zeroFields(spellId)
        and scalar(spellId, "startRecoveryCategory") == 107
        and scalar(spellId, "startRecoveryTime") == 1500
        and equal(triple(spellId, "effect"), 89, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), 4, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 42, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), rank.creature, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
end

local function auraTopology(rank)
    local spellId = rank.aura
    return commonScalar(spellId, 3, rank.level, 21, 0, 16384)
        and zeroFields(spellId)
        and scalar(spellId, "startRecoveryCategory") == 0
        and scalar(spellId, "startRecoveryTime") == 0
        and equal(triple(spellId, "effect"), M.AREA_EFFECT,
            M.AREA_EFFECT, M.AREA_EFFECT)
        and equal(triple(spellId, "effectDieSides"), 1, 1, 1)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 1)
        and equal(triple(spellId, "effectBasePoints"),
            rank.amount - 1, -1, -1)
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 1, 1)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 10, 10, 10)
        and equal(triple(spellId, "effectApplyAuraName"),
            M.AURA_TYPE, M.AURA_TYPE, M.AURA_TYPE)
        and equal(triple(spellId, "effectAmplitude"),
            M.PERIOD_MS, M.PERIOD_MS, M.PERIOD_MS)
        and equal(triple(spellId, "effectMiscValue"), 0, 1, 3)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
end

local function profile(spellId)
    local rank = RANKS[integer(spellId, 1, 4294967295) or 0]
    if not rank then return nil, "spell is not Mana Spring Totem", false end
    local cached = PROFILE[spellId]
    if cached then
        return cached.valid and copy(cached) or nil, cached.reason, true
    end
    if not (actionTopology(spellId, rank) and auraTopology(rank)) then
        PROFILE[spellId] = { valid = false, exact = false,
            reason = "Mana Spring Totem DBC chain is incomplete" }
        return nil, PROFILE[spellId].reason, true
    end
    local out = { valid = true, exact = true, spellId = spellId,
        auraSpellId = rank.aura, creatureId = rank.creature,
        slot = M.SLOT, element = M.ELEMENT, radius = M.RADIUS,
        baseAmount = rank.amount, basePeriod = M.PERIOD_MS / 1000,
        powerType = M.MANA, zeroThreat = true,
        source = "installed build-5875 DBC and VMaNGOS periodic energize" }
    PROFILE[spellId] = copy(out)
    return out, nil, true
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.shamanManaSpringEvidence
    local rank = found and RANKS[found.spellId]
    if not (facts and facts.shamanManaSpring == true and rank
        and found.valid == true and found.exact == true
        and found.auraSpellId == rank.aura
        and found.creatureId == rank.creature
        and found.slot == M.SLOT and found.element == M.ELEMENT
        and found.radius == M.RADIUS and found.baseAmount == rank.amount
        and found.basePeriod == M.PERIOD_MS / 1000
        and found.powerType == M.MANA and found.zeroThreat == true) then
        return nil
    end
    return found
end

local function modifier(spellId, kind)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(GetSpellModifiers, spellId, kind)
    flat, percent = signed32(flat), signed32(percent)
    changed = finite(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil
        or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then return nil end
    return flat, percent
end

local function contract(found)
    local amountFlat, amountPercent = modifier(
        found.auraSpellId, M.ALL_EFFECTS_MOD)
    local periodFlat, periodPercent = modifier(
        found.auraSpellId, M.ACTIVATION_TIME_MOD)
    if amountFlat == nil or periodFlat == nil then
        return nil, "Mana Spring modifier evidence unavailable"
    end
    local amount = (found.baseAmount + amountFlat)
        * (100 + amountPercent) / 100
    local periodMs = math.floor((found.basePeriod * 1000 + periodFlat)
        * (100 + periodPercent) / 100)
    if not finite(amount, 0.0001, 1000000)
        or math.floor(amount) ~= amount
        or not integer(periodMs, 1, 3600000) then
        return nil, "Mana Spring tick is stochastic or invalid"
    end
    return { valid = true, exact = true, deterministic = true,
        spellId = found.spellId, auraSpellId = found.auraSpellId,
        amount = amount, period = periodMs / 1000,
        powerType = M.MANA, zeroThreat = true,
        amountFlat = amountFlat, amountPercent = amountPercent,
        periodFlat = periodFlat, periodPercent = periodPercent,
        source = found.source .. "; root-captured aura spell modifiers" }
end

function M:Promote(spellId, facts)
    local found = profile(spellId)
    if not (found and facts and facts.shamanTotem == true
        and facts.shamanLifecycleRepresented == true
        and facts.shamanRepresentationExact == true
        and facts.totemElementExact == true
        and facts.totemReplacementExact == true
        and facts.totemLifetimeExact == true
        and facts.totemSlot == self.SLOT
        and facts.totemReplacementSlot == self.SLOT
        and facts.totemElement == self.ELEMENT) then return facts end
    local out = copy(facts)
    out.shamanRepresentation = "manaSpringTotemSolo"
    out.shamanEffectRepresented = true
    out.shamanRangeRepresented = true
    out.shamanRecipientsRepresented = true
    out.shamanManaSpring = true
    out.shamanManaSpringEvidence = copy(found)
    out.shamanTotemDownstream = { exact = true,
        sourceSpellId = found.spellId, element = self.ELEMENT,
        effect = { exact = true, kind = "playerPeriodicManaEnergize",
            auraSpellId = found.auraSpellId,
            baseAmount = found.baseAmount, period = found.basePeriod,
            powerType = self.MANA, zeroThreat = true,
            phase = "freshPlacement" },
        range = { exact = true, center = "totem", minimum = 0,
            maximum = found.radius },
        recipients = { exact = true, center = "totem", relation = "party",
            shape = "area", graphScope = "soloSelf" }, source = found.source }
    return out
end

function M:CaptureFacts(action, facts)
    local found = evidence(facts)
    if not (found and action and action.spellId == found.spellId) then
        return facts
    end
    local out, exact, reason = copy(facts), nil, nil
    exact, reason = contract(found)
    out.shamanManaSpringContract = exact or { valid = false, exact = false,
        recognized = true, spellId = found.spellId, reason = reason }
    return out
end

function M:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function groupCount(api, maximum)
    if type(api) ~= "function" then return nil end
    local ok, count = pcall(api)
    return ok and integer(count, 0, maximum) or nil
end

function M:ObserveRoot()
    local out = { available = false, exact = false,
        source = "exact player class and group membership" }
    if classToken() ~= "SHAMAN" then
        out.reason = "player is not an exactly identified Shaman"; return out
    end
    local raid = groupCount(GetNumRaidMembers, 40)
    local party = groupCount(GetNumPartyMembers, 4)
    if raid == nil or party == nil then
        out.reason = "group membership evidence unavailable"; return out
    end
    out.available, out.exact = true, true
    out.raidMembers, out.partyMembers = raid, party
    out.grouped, out.solo = raid > 0 or party > 0, raid == 0 and party == 0
    if out.grouped then out.reason = "Mana Spring party fanout is unresolved" end
    return out
end

function M:Inspect(spellId)
    local found, reason, recognized = profile(spellId)
    if found then
        found.available, found.recognized = true, true
        return found
    end
    return { available = not recognized, exact = not recognized,
        recognized = recognized and true or false, reason = reason }
end

function M:Invalidate()
    PROFILE = {}
end
