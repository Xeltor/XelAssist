-- Exact Shadowform identity and effect profile from the installed build-5875
-- Spell.dbc. Localized names never select this mechanic. Mutable effective
-- mana cost is captured once at the root; graph descendants consume only the
-- copied numeric profile and cost.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestShadowform = {}
local P = XelAssist.Game.Player.PriestShadowform

P.SPELL_ID = 15473
P.PRIEST_FAMILY = 6
P.FAMILY_FLAGS = 2147483648
P.FORM_ID = 28
P.FORM_MASK = 134217728
P.MANA = 0
P.SHADOW_SCHOOL = 5
P.SHADOW_MASK = 32
P.PHYSICAL_SCHOOL = 0
P.PHYSICAL_MASK = 1

local PROFILE_CACHE = nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
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

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
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
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function scalarTopology(spellId)
    return scalar(spellId, "school") == P.SHADOW_SCHOOL
        and scalar(spellId, "category") == 39
        and scalar(spellId, "attributes") == 33882112
        and scalar(spellId, "attributesEx") == 131072
        and scalar(spellId, "attributesEx2") == 2
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 1500
        and scalar(spellId, "durationIndex") == 21
        and scalar(spellId, "powerType") == P.MANA
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 40
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == P.PRIEST_FAMILY
        and scalar(spellId, "spellFamilyFlags") == P.FAMILY_FLAGS
end

local function effectTopology(spellId)
    local effects = triple(spellId, "effect")
    local auras = triple(spellId, "effectApplyAuraName")
    local points = triple(spellId, "effectBasePoints")
    local dice = triple(spellId, "effectBaseDice")
    local sides = triple(spellId, "effectDieSides")
    local targetsA = triple(spellId, "effectImplicitTargetA")
    local targetsB = triple(spellId, "effectImplicitTargetB")
    local misc = triple(spellId, "effectMiscValue")
    local triggers = triple(spellId, "effectTriggerSpell")
    if not (equal(effects, 6, 6, 6)
        and equal(auras, 36, 79, 87)
        and equal(points, 0, 14, -16)
        and equal(dice, 0, 1, 1)
        and equal(sides, 0, 1, 1)
        and equal(targetsA, 1, 1, 1)
        and equal(targetsB, 0, 0, 0)
        and equal(misc, P.FORM_ID, P.SHADOW_MASK, P.PHYSICAL_MASK)
        and equal(triggers, 0, 0, 0)) then return nil end
    local shadowPercent = points[2] + dice[2]
    local physicalPercent = points[3] + dice[3]
    if shadowPercent ~= 15 or physicalPercent ~= -15 then return nil end
    return shadowPercent, physicalPercent
end

local function installedProfile()
    if PROFILE_CACHE then return copy(PROFILE_CACHE) end
    local spellId = P.SPELL_ID
    local shadowPercent, physicalPercent = effectTopology(spellId)
    if not (scalarTopology(spellId) and shadowPercent and physicalPercent) then
        return nil, "Shadowform DBC topology is incomplete"
    end
    local out = { valid = true, available = true, exact = true,
        spellId = spellId,
        family = P.PRIEST_FAMILY, familyFlags = P.FAMILY_FLAGS,
        formID = P.FORM_ID, formMask = P.FORM_MASK,
        powerType = P.MANA, manaCostPercentage = 40,
        shadowSchool = P.SHADOW_SCHOOL, shadowSchoolMask = P.SHADOW_MASK,
        physicalSchool = P.PHYSICAL_SCHOOL,
        physicalSchoolMask = P.PHYSICAL_MASK,
        shadowDamagePercent = shadowPercent,
        shadowDamageMultiplier = (100 + shadowPercent) / 100,
        physicalDamageTakenPercent = physicalPercent,
        physicalDamageTakenMultiplier = (100 + physicalPercent) / 100,
        source = "installed build-5875 Shadowform DBC topology" }
    PROFILE_CACHE = copy(out)
    return copy(out)
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestShadowformEvidence
    if not (facts and facts.priestShadowform == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == P.SPELL_ID
        and found.family == P.PRIEST_FAMILY
        and found.familyFlags == P.FAMILY_FLAGS
        and found.formID == P.FORM_ID and found.formMask == P.FORM_MASK
        and found.powerType == P.MANA
        and found.shadowSchool == P.SHADOW_SCHOOL
        and found.shadowSchoolMask == P.SHADOW_MASK
        and found.physicalSchool == P.PHYSICAL_SCHOOL
        and found.physicalSchoolMask == P.PHYSICAL_MASK
        and found.shadowDamagePercent == 15
        and found.shadowDamageMultiplier == 1.15
        and found.physicalDamageTakenPercent == -15
        and found.physicalDamageTakenMultiplier == 0.85) then return nil end
    return found
end

local function effectiveCost(spellId)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "Shadowform effective mana cost unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok or type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "Shadowform effective mana cost unavailable"
    end
    local entry = costs[1]
    local cost, minimum = finite(entry.cost), finite(entry.minCost)
    if tonumber(entry.type) ~= P.MANA or not cost or cost < 0
        or minimum ~= cost or tonumber(entry.costPercent) ~= 40
        or tonumber(entry.costPerSec) ~= 0
        or tonumber(entry.requiredAuraID) ~= 0
        or entry.hasRequiredAura ~= false then
        return nil, "Shadowform is not exactly mana funded"
    end
    return cost
end

function P:Snapshot(knownClass)
    local token = knownClass
    if token == nil then token = classToken() end
    if token ~= "PRIEST" then return nil end
    local found, reason = installedProfile()
    if found then return found end
    return { valid = false, exact = false, available = false,
        reason = reason, source = "installed build-5875 Shadowform DBC" }
end

function P:InferKnowledge(spellId)
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "not the installed Shadowform identity", false
    end
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    local found, reason = installedProfile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "form", kindExact = true,
        self = true, fixedTarget = "player", recipientRelation = "friendly",
        recipientRelationExact = true, resourceType = "mana",
        priestShadowform = true, requiresPriestShadowformEvidence = true,
        requiresExactUsability = true, submissionGuarded = true,
        priestShadowformEvidence = copy(found), source = found.source }, nil, true
end

function P:CaptureFacts(action, facts)
    local found = evidence(action)
    if not found then return facts end
    local out, captured = copy(facts), copy(found)
    local cost, reason = effectiveCost(found.spellId)
    captured.effectiveCost, captured.costExact = cost, cost ~= nil
    captured.captureReason = reason
    out.priestShadowformEvidence = captured
    out.priestShadowformCostExact = cost ~= nil
    out.priestShadowformCaptureReason = reason
    out.powerType = self.MANA
    out.cost = cost
    return out
end

function P:Evidence(subject)
    return evidence(subject)
end

function P:CapturedEvidence(subject)
    local found = evidence(subject)
    if not (found and found.costExact == true
        and finite(found.effectiveCost) and found.effectiveCost >= 0) then
        return nil, found and found.captureReason
            or "Shadowform evidence unavailable"
    end
    return found
end

function P:Is(subject)
    return evidence(subject) ~= nil
end

function P:Invalidate()
    PROFILE_CACHE = nil
end
