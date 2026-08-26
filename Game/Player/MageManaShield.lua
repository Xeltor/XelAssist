-- Exact Mana Shield mechanics from the installed build-5875 Spell.dbc.
-- Discovery and modifier capture happen before search. Search consumes only
-- sealed facts: the shield absorbs its DBC school mask after ordinary school
-- absorbs and spends the player's mana for each point actually absorbed.
XelAssist.Game.Player.MageManaShield = {}
local M = XelAssist.Game.Player.MageManaShield

M.MAGE_FAMILY = 3
M.FAMILY_FLAGS = 32768
M.MANA_SHIELD_AURA = 97
M.MANA_POWER = 0
M.MULTIPLE_VALUE_MOD = 27
M.MAX_CACHE = 256

local CACHE, CACHE_COUNT = {}, 0

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

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
end

local function triple(spellId, field, allowFloat)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index, value = {}, 0, nil, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        value = finite(values[index])
        if not value or not allowFloat
            and integer(value, -2147483648, 4294967295) == nil then return nil end
        out[index] = value
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and finite(milliseconds) or nil
    if not milliseconds or milliseconds <= 0 then return nil end
    return milliseconds / 1000
end

local function classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "spell identity unavailable", false end
    local cached = CACHE[spellId]
    if cached then
        return cached.found and copy(cached.found) or nil,
            cached.reason, cached.recognized
    end
    local family, flags = scalar(spellId, "spellFamilyName"),
        scalar(spellId, "spellFamilyFlags")
    if family == nil or flags == nil then
        return nil, "Mage DBC family evidence unavailable", false
    end
    local recognized = family == M.MAGE_FAMILY and flags == M.FAMILY_FLAGS
    local found, reason
    if not recognized then
        reason = "spell is not Mana Shield"
    else
        local effects = triple(spellId, "effect")
        local auras = triple(spellId, "effectApplyAuraName")
        local targetsA = triple(spellId, "effectImplicitTargetA")
        local targetsB = triple(spellId, "effectImplicitTargetB")
        local multipliers = triple(spellId, "effectMultipleValue", true)
        local misc = triple(spellId, "effectMiscValue")
        local triggers = triple(spellId, "effectTriggerSpell")
        local lifetime = duration(spellId)
        if equal(effects, 6, 0, 0)
            and equal(auras, M.MANA_SHIELD_AURA, 0, 0)
            and equal(targetsA, 1, 0, 0)
            and equal(targetsB, 0, 0, 0)
            and equal(multipliers, 2, 0, 0)
            and equal(misc, 1, 0, 0)
            and equal(triggers, 0, 0, 0)
            and scalar(spellId, "powerType") == M.MANA_POWER
            and lifetime then
            found = { valid = true, exact = true, spellId = spellId,
                family = family, familyFlags = flags,
                auraType = M.MANA_SHIELD_AURA, schoolMask = misc[1],
                baseManaPerDamage = multipliers[1], duration = lifetime,
                modifierSensitive = true,
                source = "installed build-5875 Mana Shield DBC topology" }
        else reason = "Mana Shield DBC topology is incomplete" end
    end
    if CACHE_COUNT < M.MAX_CACHE then
        CACHE[spellId] = { found = found and copy(found) or nil,
            reason = reason, recognized = recognized }
        CACHE_COUNT = CACHE_COUNT + 1
    end
    return found, reason, recognized
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.mageManaShieldEvidence
    if not (facts and facts.mageManaShield == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.family == M.MAGE_FAMILY
        and found.familyFlags == M.FAMILY_FLAGS
        and found.auraType == M.MANA_SHIELD_AURA
        and found.schoolMask == 1 and found.baseManaPerDamage == 2
        and found.duration and found.duration > 0) then return nil end
    return found
end

function M:InferKnowledge(spellId)
    if classToken() ~= "MAGE" then
        return nil, "player is not an exactly identified Mage", false
    end
    local found, reason, recognized = classify(spellId)
    if not found then return nil, reason, recognized == true end
    return { inferred = true, kind = "absorb", kindExact = true,
        self = true, fixedTarget = "player", mageManaShield = true,
        manaFundedAbsorb = true, requiresMageManaShieldEvidence = true,
        submissionGuarded = true, mageManaShieldEvidence = copy(found),
        source = found.source }, nil, true
end

-- Nampower exposes whether a live player modifier affects MULTIPLE_VALUE.
-- Modified values deliberately remain unknown: its unsigned percent return is
-- not an authoritative reconstruction of server ApplySpellMod arithmetic.
local function liveRatio(found)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Mana Shield player modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, found.spellId, M.MULTIPLE_VALUE_MOD)
    flat, percent, changed = finite(flat), finite(percent), finite(changed)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "Mana Shield player modifier evidence unavailable"
    end
    if changed ~= 0 or flat ~= 0 or percent ~= 0 then
        return nil, "modified Mana Shield mana ratio is unresolved"
    end
    return found.baseManaPerDamage
end

function M:CaptureFacts(action, facts)
    local found = evidence(action)
    if not found then return facts end
    local out = copy(facts)
    local ratio, reason = liveRatio(found)
    out.manaPerAbsorbedDamage = ratio
    out.manaPerAbsorbedDamageExact = ratio ~= nil
    out.mageManaShieldSchoolMask = found.schoolMask
    out.mageManaShieldDuration = found.duration
    out.mageManaShieldCaptureReason = reason
    return out
end

function M:Is(subject)
    return evidence(subject) ~= nil
end

function M:Blocker(action, state, tooltip)
    local found = evidence(action)
    if not found then return nil, false end
    tooltip = tooltip or {}
    if tooltip.manaPerAbsorbedDamageExact ~= true
        or finite(tooltip.manaPerAbsorbedDamage) == nil then
        return tooltip.mageManaShieldCaptureReason
            or "Mana Shield mana ratio unknown", true
    end
    if tonumber(state and state.resourceType) ~= self.MANA_POWER
        or state.playerResourceExact ~= true
        or finite(state.resource) == nil then
        return "Mana Shield resource evidence unavailable", true
    end
    return nil, true
end

function M:EffectiveCapacity(candidate, state)
    local action = candidate and candidate.action
    local blocker, handled = self:Blocker(action, state,
        candidate and candidate.tooltip)
    if not handled or blocker then return nil, blocker end
    local ratio = candidate.tooltip.manaPerAbsorbedDamage
    local reserved = math.max(0, finite(state.playerResourceReserved) or 0)
    local cost = math.max(0, finite(candidate.cost) or 0)
    local mana = math.max(0, state.resource - reserved - cost)
    local power = math.max(0, finite(candidate.power) or 0)
    return math.min(power, math.floor(mana / ratio))
end

function M:Entry(candidate)
    local action = candidate and candidate.action
    local tooltip = candidate and candidate.tooltip or {}
    local found = evidence(action)
    local ratio = finite(tooltip.manaPerAbsorbedDamage)
    local amount = finite(candidate and candidate.power)
    if not (found and tooltip.manaPerAbsorbedDamageExact == true
        and ratio and ratio > 0 and amount and amount > 0) then return nil end
    local probability = finite(candidate.effectDelivery) or 1
    probability = math.max(0, math.min(1, probability))
    local lifetime = finite(tooltip.duration)
        or found.duration
    return { amount = amount, duration = lifetime, remaining = lifetime,
        applicationProbability = probability, mageManaShield = true,
        manaPerDamage = ratio, schoolMask = found.schoolMask,
        spellId = found.spellId, evidenceExact = true }
end

function M:IsEntry(entry)
    return type(entry) == "table" and entry.mageManaShield == true
        and entry.evidenceExact == true and finite(entry.amount) ~= nil
        and finite(entry.manaPerDamage) ~= nil
        and integer(entry.schoolMask, 1, 127) ~= nil
end

local function schoolMatches(entry, school)
    school = integer(school, 0, 6)
    if school == nil then return nil end
    local mask = 2 ^ school
    return math.floor(entry.schoolMask / mask)
        - math.floor(entry.schoolMask / (mask * 2)) * 2 == 1
end

-- Called after ordinary school absorbs. Returns residual damage, expected
-- absorbed damage, expected mana spent, partial-evidence flag, handled flag.
function M:ConsumeEntry(state, absorbs, name, damage, castProbability, school)
    local entry = absorbs and absorbs[name]
    if not self:IsEntry(entry) then return damage, 0, 0, false, false end
    damage = math.max(0, finite(damage) or 0)
    castProbability = math.max(0, math.min(1,
        finite(castProbability) or 1))
    local matches = schoolMatches(entry, school)
    if matches == false then return damage, 0, 0, false, true end
    local resource = finite(state and state.resource)
    if matches == nil or not resource
        or tonumber(state.resourceType) ~= self.MANA_POWER
        or state.playerResourceExact ~= true then
        return damage, 0, 0, true, true
    end
    local ratio = entry.manaPerDamage
    local auraProbability = math.max(0, math.min(1,
        finite(entry.applicationProbability) or 1))
    local maximum = math.floor(math.max(0, resource) / ratio)
    local conditional = math.min(damage, entry.amount, maximum)
    local used = conditional * auraProbability
    local absorbed = used * castProbability
    local manaSpent = conditional * ratio * auraProbability * castProbability
    damage = math.max(0, damage - used)
    state.resource = math.max(0, resource - manaSpent)
    state.playerResourceProjected = true
    -- This debit is caused by incoming damage, not a spell payment paired to
    -- ManaEvents. Retaining a learned passive phase could award an unsafe tick
    -- to descendants, so any positive expected debit closes that phase.
    if manaSpent > 0 then state.playerResourceClock = nil end
    if state.actors and state.actors.player then
        state.actors.player.resource = state.resource
    end

    local hitRemaining = math.max(0, entry.amount - conditional)
    local survival = 1 - castProbability
        + (hitRemaining > 0 and castProbability or 0)
    local expectedRemaining = (1 - castProbability) * entry.amount
        + castProbability * hitRemaining
    local remainingProbability = auraProbability * survival
    if survival > 0 then expectedRemaining = expectedRemaining / survival end
    if remainingProbability <= 0 or expectedRemaining <= 0 then
        absorbs[name] = nil
    else
        entry.amount = expectedRemaining
        entry.applicationProbability = remainingProbability
    end
    local partial = auraProbability < 1 or castProbability < 1
        or manaSpent ~= math.floor(manaSpent)
    return damage, absorbed, manaSpent, partial, true
end

function M:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
