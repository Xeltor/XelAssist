-- Exact build-5875 Righteous Fury evidence. The module promotes only the
-- installed numeric identity after its complete DBC consequence remains
-- intact. It assigns no tank role, action order, or fixed utility.
XelAssist.Game.Player.PaladinRighteousFury = {}
local R = XelAssist.Game.Player.PaladinRighteousFury

R.SPELL_ID = 25780
R.PALADIN_FAMILY = 10
R.FAMILY_FLAG = 1
R.APPLY_AURA = 6
R.THREAT_AURA = 10
R.HOLY_SCHOOL = 1
R.HOLY_MASK = 2
R.BASE_PERCENT = 60
R.ALL_EFFECTS_MOD = 8

local STATIC_CACHE = nil

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

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, R.SPELL_ID, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, R.SPELL_ID, field, 1)
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

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local SCALARS = {
    school = 1, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327680, attributesEx = 0, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
    auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
    procChance = 101, procCharges = 0, maxLevel = 0, baseLevel = 16,
    spellLevel = 16, durationIndex = 21, powerType = 0, manaCost = 0,
    manaCostPerlevel = 0, manaPerSecond = 0, manaPerSecondPerLevel = 0,
    rangeIndex = 1, speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = -1, equippedItemSubClassMask = -1,
    equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    maxTargetLevel = 0, spellFamilyName = 10, spellFamilyFlags = 1,
    maxAffectedTargets = 0, dmgClass = 0, preventionType = 0,
}

local function scalarsMatch()
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(field) ~= expected then return false end
    end
    return true
end

local function arraysMatch()
    return equal(triple("effect"), R.APPLY_AURA, 0, 0)
        and equal(triple("effectDieSides"), 1, 0, 0)
        and equal(triple("effectBaseDice"), 1, 0, 0)
        and equal(triple("effectDicePerLevel"), 0, 0, 0)
        and equal(triple("effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple("effectBasePoints"), 59, 0, 0)
        and equal(triple("effectMechanic"), 0, 0, 0)
        and equal(triple("effectImplicitTargetA"), 1, 0, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectRadiusIndex"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"), R.THREAT_AURA, 0, 0)
        and equal(triple("effectAmplitude"), 0, 0, 0)
        and equal(triple("effectMultipleValue"), 0, 0, 0)
        and equal(triple("effectChainTarget"), 0, 0, 0)
        and equal(triple("effectItemType"), 0, 0, 0)
        and equal(triple("effectMiscValue"), R.HOLY_MASK, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
        and equal(triple("effectPointsPerComboPoint"), 0, 0, 0)
end

local function staticProfile()
    if STATIC_CACHE then return copy(STATIC_CACHE) end
    local out = { recognized = true, available = false, valid = false,
        exact = false, portfolio = "paladinRighteousFury",
        spellId = R.SPELL_ID,
        source = "installed build-5875 Righteous Fury DBC topology" }
    if not (scalarsMatch() and arraysMatch()) then
        out.reason = "Righteous Fury DBC topology is incomplete"
    else
        out.available, out.valid, out.exact = true, true, true
        out.family, out.familyFlag = R.PALADIN_FAMILY, R.FAMILY_FLAG
        out.school, out.schoolMask = R.HOLY_SCHOOL, R.HOLY_MASK
        out.basePercent, out.baseMultiplier = R.BASE_PERCENT, 1.60
        out.auraType, out.recipient = R.THREAT_AURA, "self"
        out.durationModel, out.gcd, out.cast = "untilCancelled", 1.5, 0
    end
    STATIC_CACHE = copy(out)
    return copy(out)
end

local function exactClassification(found)
    return type(found) == "table" and found.exact == true
        and tonumber(found.spellId) == R.SPELL_ID
        and found.family == R.PALADIN_FAMILY
        and found.flags == R.FAMILY_FLAG
        and found.kind == "righteousFury"
        and found.recipientRelation == "self"
end

local function modifiers()
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Righteous Fury modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, R.SPELL_ID, R.ALL_EFFECTS_MOD)
    flat = ok and finite(flat, -10000, 10000) or nil
    percent = ok and finite(percent, -100, 10000) or nil
    changed = ok and integer(changed, 0, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil then
        return nil, "Righteous Fury modifier evidence unavailable"
    end
    if (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then
        return nil, "Righteous Fury modifier evidence is incoherent"
    end
    local modified = (R.BASE_PERCENT + flat) * (100 + percent) / 100
    if not finite(modified, 0.0001, 10000) then
        return nil, "Righteous Fury threat magnitude is outside its safe domain"
    end
    return { flat = flat, percent = percent, changed = changed,
        effectivePercent = modified, multiplier = (100 + modified) / 100,
        exact = true,
        source = "root-captured ALL_EFFECTS spell modifiers" }, nil
end

local function effect(profile)
    if not (profile and profile.valid == true and profile.exact == true
        and profile.portfolio == "paladinRighteousFury"
        and profile.spellId == R.SPELL_ID and profile.school == R.HOLY_SCHOOL
        and profile.schoolMask == R.HOLY_MASK
        and finite(profile.multiplier, 1.000001, 101)) then return nil end
    return { exact = true, kind = "schoolThreatMultiplier",
        actor = "player", sourceSpellId = R.SPELL_ID,
        school = profile.school, schoolMask = profile.schoolMask,
        percent = profile.effectivePercent,
        multiplier = profile.multiplier, recipient = "self",
        source = profile.source }
end

local function capturedProfile()
    local base = staticProfile()
    if not (base and base.valid == true) then return base end
    local found, reason = modifiers()
    local out = copy(base)
    if not found then
        out.available, out.valid, out.exact = false, false, false
        out.reason = reason
        return out
    end
    out.basePercent, out.modifierFlat, out.modifierPercent =
        R.BASE_PERCENT, found.flat, found.percent
    out.effectivePercent, out.multiplier =
        found.effectivePercent, found.multiplier
    out.source = base.source .. " plus " .. found.source
    return out
end

function R:Inspect(classification)
    local found = staticProfile()
    if not exactClassification(classification) then
        found.available, found.valid, found.exact = false, false, false
        found.reason = "captured Righteous Fury classification unavailable"
    end
    return found
end

function R:Promote(spellId, facts)
    if tonumber(spellId) ~= self.SPELL_ID or not (facts
        and facts.paladinRighteousFury == true) then return facts end
    local found = self:Inspect(facts.paladinClassification)
    if not (found.valid == true and found.exact == true) then return facts end
    local out = copy(facts)
    out.paladinRepresentation = "exactSchoolThreatAura"
    out.paladinLifecycleRepresented = true
    out.paladinEffectRepresented = true
    out.paladinRighteousFuryEvidence = found
    out.requiresExactPaladinRighteousFuryProfile = true
    return out
end

function R:CaptureFacts(action, facts)
    if not (facts and facts.paladinRighteousFury == true
        and tonumber(action and action.spellId) == self.SPELL_ID) then
        return facts
    end
    local out, profile = copy(facts), capturedProfile()
    out.paladinRighteousFuryProfile = profile
    out.paladinDownstreamEffect = effect(profile)
    if not out.paladinDownstreamEffect then
        out.paladinEffectRepresented = false
    end
    return out
end

function R:CapturedEffect(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    return effect(facts and facts.paladinRighteousFuryProfile)
end

function R:Snapshot()
    if classToken() ~= "PALADIN" then
        return { available = false, valid = false, exact = false,
            reason = "player is not an exactly identified Paladin" }
    end
    return capturedProfile()
end

function R:Invalidate()
    STATIC_CACHE = nil
end
