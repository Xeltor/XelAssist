-- Exact Inner Focus discovery and root evidence for installed build 5875.
-- DBC family masks identify affected spells; mutable aura and spell-modifier
-- APIs are read only while the root is open. The graph leaf consumes the
-- sealed one-charge cost contract without choosing a Priest spell order.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestInnerFocus = {}
local I = XelAssist.Game.Player.PriestInnerFocus

I.SPELL_ID = 14751
I.PRIEST_FAMILY = 6
I.MANA = 0
I.COST_MASK = 3606577115
I.CRIT_MASK = 3646176912
I.COST_MODIFIER = 14
I.CRIT_MODIFIER = 7
I.COST_PERCENT = -100
I.CRIT_FLAT = 25
I.IGNORE_CASTER_MODIFIERS = 536870912
I.MAX_CACHE = 256

local PROFILE, ACTIONS, ACTION_COUNT, BASELINES = nil, {}, 0, {}

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
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function overlaps(left, right)
    left, right = unsigned32(left), unsigned32(right)
    if not left or not right then return nil end
    local index
    for index = 0, 31 do
        local bit = 2 ^ index
        local a = math.floor(left / bit) - math.floor(left / (bit * 2)) * 2
        local b = math.floor(right / bit) - math.floor(right / (bit * 2)) * 2
        if a == 1 and b == 1 then return true end
    end
    return false
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalarTopology(spellId)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 0
        and scalar(spellId, "castUI") == 0
        and scalar(spellId, "dispel") == 1
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 33882112
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 524288
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 134217728
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "targetCreatureType") == 0
        and scalar(spellId, "requiresSpellFocus") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 180000
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "procFlags") == 87376
        and scalar(spellId, "procChance") == 100
        and scalar(spellId, "procCharges") == 1
        and scalar(spellId, "maxLevel") == 0
        and scalar(spellId, "baseLevel") == 0
        and scalar(spellId, "spellLevel") == 0
        and scalar(spellId, "durationIndex") == 21
        and scalar(spellId, "powerType") == I.MANA
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "modalNextSpell") == 0
        and scalar(spellId, "stackAmount") == 0
        and scalar(spellId, "equippedItemClass") == -1
        and scalar(spellId, "equippedItemSubClassMask") == 0
        and scalar(spellId, "equippedItemInventoryTypeMask") == 0
        and scalar(spellId, "startRecoveryCategory") == 0
        and scalar(spellId, "startRecoveryTime") == 0
        and scalar(spellId, "maxTargetLevel") == 0
        and scalar(spellId, "spellFamilyName") == I.PRIEST_FAMILY
        and scalar(spellId, "spellFamilyFlags") == 0
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end

local function effectTopology(spellId)
    return equal(triple(spellId, "effect"), 6, 6, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 1, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), -101, 24, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 108, 107, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"),
            I.COST_MASK, I.CRIT_MASK, 0)
        and equal(triple(spellId, "effectMiscValue"),
            I.COST_MODIFIER, I.CRIT_MODIFIER, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function installedProfile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    if not (scalarTopology(I.SPELL_ID) and effectTopology(I.SPELL_ID)) then
        PROFILE = { valid = false, exact = false,
            reason = "Inner Focus DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = I.SPELL_ID,
        family = I.PRIEST_FAMILY, charges = 1, indefinite = true,
        costMask = I.COST_MASK, critMask = I.CRIT_MASK,
        costModifier = I.COST_MODIFIER, costPercent = I.COST_PERCENT,
        critModifier = I.CRIT_MODIFIER, critFlat = I.CRIT_FLAT,
        source = "installed build-5875 Inner Focus DBC and VMaNGOS spellmod" }
    return copy(PROFILE)
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return copy(cached) end
    local family = scalar(spellId, "spellFamilyName")
    local flags = unsigned32(scalar(spellId, "spellFamilyFlags"))
    local powerType = scalar(spellId, "powerType")
    local attributesEx3 = unsigned32(scalar(spellId, "attributesEx3"))
    local complete = family ~= nil and flags ~= nil and powerType ~= nil
        and attributesEx3 ~= nil
    cached = { complete = complete, spellId = spellId, family = family,
        flags = flags, powerType = powerType,
        ignoresModifiers = complete and overlaps(
            attributesEx3, I.IGNORE_CASTER_MODIFIERS) or nil }
    if complete then
        cached.costMask = overlaps(flags, I.COST_MASK)
        cached.critMask = overlaps(flags, I.CRIT_MASK)
    end
    if ACTION_COUNT < I.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = copy(cached), ACTION_COUNT + 1
    end
    return copy(cached)
end

local function modifierSnapshot(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Priest COST modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, I.COST_MODIFIER)
    flat, percent = signed32(flat), signed32(percent)
    changed = finite(changed, -4294967295, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "Priest COST modifier evidence unavailable"
    end
    return { flat = flat, percent = percent, changed = changed }
end

local function exactPowerCost(spellId, zeroAllowed)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "effective Priest mana cost unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok then return nil, "effective Priest mana cost unavailable" end
    if costs == nil and zeroAllowed then return 0 end
    if type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "effective Priest mana cost unavailable"
    end
    local entry = costs[1]
    local cost = finite(entry.cost, 0, 1000000000)
    if integer(entry.type, 0, 4) ~= I.MANA or cost == nil
        or finite(entry.minCost, 0, 1000000000) ~= cost
        or finite(entry.costPercent, 0, 100) ~= 0
        or finite(entry.costPerSec, 0, 1000000000) ~= 0
        or finite(entry.requiredAuraID, 0, 4294967295) ~= 0
        or entry.hasRequiredAura ~= false then
        return nil, "effective Priest mana cost is not exact"
    end
    if not zeroAllowed and cost <= 0 then
        return nil, "positive Priest mana cost unavailable"
    end
    return cost
end

local function playerLevel(state)
    return integer(state and state.actors and state.actors.player
        and state.actors.player.level, 1, 255)
end

local function observeAura(profile)
    local out = { available = false, exact = false, profile = copy(profile),
        source = "ClassicAPI numeric Inner Focus aura identity" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "Inner Focus aura evidence unavailable"
        return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, I.SPELL_ID)
    if not ok then out.reason = "Inner Focus aura evidence unavailable"; return out end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local spellId = type(aura) == "table"
        and integer(aura.spellId, 1, 4294967295) or nil
    local applications = type(aura) == "table"
        and integer(aura.applications, 1, 255) or nil
    if spellId ~= I.SPELL_ID or aura.isHelpful ~= true or applications ~= 1 then
        out.available, out.exact = false, false
        out.reason = "active Inner Focus aura identity is incomplete"
        return out
    end
    out.active = true
    return out
end

local function contractFor(action, facts, state, profile)
    local spellId = action.spellId
    local found = actionProfile(spellId)
    if not found or not found.complete or found.family ~= I.PRIEST_FAMILY
        or found.powerType ~= I.MANA then return nil end
    local out = { claimed = true, exact = false, spellId = spellId,
        family = found.family, familyFlags = found.flags,
        costMask = found.costMask == true, critMask = found.critMask == true,
        critFlatUnvalued = found.critMask and profile.critFlat or nil }
    if found.ignoresModifiers then
        out.exact, out.costAffected = true, false
        out.source = "DBC excludes caster spell modifiers"
        return out
    end
    if not found.costMask and not found.critMask then
        out.exact, out.costAffected = true, false
        out.source = "DBC family flags exclude both Inner Focus modifiers"
        return out
    end
    if not found.costMask then
        out.reason = "Inner Focus critical-only consequence is unmodeled"
        return out
    end
    local level = playerLevel(state)
    local modifiers, reason = modifierSnapshot(spellId)
    local active = state.priestInnerFocus.active == true
    local cost
    if modifiers then cost, reason = exactPowerCost(spellId, active) end
    if not level or not modifiers or cost == nil then
        out.reason = reason or "Priest level evidence unavailable"
        return out
    end
    if active then
        local baseline = BASELINES[spellId]
        if baseline and baseline.level == level and modifiers.flat == 0
            and modifiers.percent == I.COST_PERCENT and cost == 0 then
            out.exact, out.costAffected = true, true
            out.baselineCost, out.source = baseline.cost,
                "engine-confirmed active Inner Focus cost delta"
        else out.reason = "Inner Focus baseline or active cost delta unavailable" end
    elseif modifiers.flat == 0 and modifiers.percent == 0 then
        BASELINES[spellId] = { level = level, cost = cost }
        out.exact, out.costAffected, out.baselineCost = true, true, cost
        out.source = "clean root cost plus installed Inner Focus family mask"
    else out.reason = "another Priest COST modifier is active" end
    return out
end

function I:InferKnowledge(spellId)
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    if integer(spellId, 1, 4294967295) ~= I.SPELL_ID then
        return nil, "spell is not Inner Focus", false
    end
    local profile, reason = installedProfile()
    if not profile then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        self = true, combatBuff = true, priestInnerFocus = true,
        requiresPriestInnerFocusEvidence = true, submissionGuarded = true,
        priestInnerFocusEvidence = copy(profile), source = profile.source }, nil, true
end

function I:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestInnerFocusEvidence
    if not (facts and facts.priestInnerFocus == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == I.SPELL_ID
        and found.family == I.PRIEST_FAMILY and found.charges == 1
        and found.indefinite == true and found.costMask == I.COST_MASK
        and found.critMask == I.CRIT_MASK
        and found.costPercent == I.COST_PERCENT
        and found.critFlat == I.CRIT_FLAT) then return nil end
    return found
end

function I:Is(subject)
    return self:Evidence(subject) ~= nil
end

function I:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.priestInnerFocus = nil
    local token = knownClass or classToken()
    if token ~= "PRIEST" then return false end
    local profile, reason = installedProfile()
    if not profile then
        state.priestInnerFocus = { available = false, exact = false,
            reason = reason, source = "installed build-5875 Inner Focus DBC" }
        return false
    end
    state.priestInnerFocus = observeAura(profile)
    return state.priestInnerFocus.exact == true
end

function I:CaptureFacts(action, facts, state)
    local evidence = state and state.priestInnerFocus
    if not (evidence and evidence.available == true and evidence.exact == true
        and action and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return facts end
    local profile = evidence.profile
    if not (profile and profile.valid == true and profile.exact == true) then
        return facts
    end
    local contract = contractFor(action, facts, state, profile)
    if not contract then return facts end
    local out = copy(facts)
    out.priestInnerFocusCost = contract
    if contract.exact == true and contract.costAffected == true then
        out.cost = evidence.active == true and 0 or contract.baselineCost
    end
    return out
end

function I:InvalidateCosts()
    BASELINES = {}
end

function I:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT, BASELINES = nil, {}, 0, {}
end
