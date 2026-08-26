-- Exact Aspect-of-the-Hawk discovery and root aura evidence for build 5875.
-- Numeric identities and complete DBC shapes select the mechanic; no localized
-- name, rank priority, or preferred action participates in inference.
XelAssist.Game.Player.HunterHawk = {}
local H = XelAssist.Game.Player.HunterHawk

H.HUNTER_FAMILY = 9
H.FAMILY_FLAG = 1048576
H.RANGED_AP_AURA = 124
H.ALL_EFFECTS_MOD = 8
H.ATTACK_POWER_MOD = 3
H.MAX_AURAS = 48

local RANKS = {
    [13165] = { rank = 1, level = 10, cost = 20, base = 19, amount = 20 },
    [14318] = { rank = 2, level = 18, cost = 35, base = 34, amount = 35 },
    [14319] = { rank = 3, level = 28, cost = 50, base = 49, amount = 50 },
    [14320] = { rank = 4, level = 38, cost = 70, base = 69, amount = 70 },
    [14321] = { rank = 5, level = 48, cost = 90, base = 89, amount = 90 },
    [14322] = { rank = 6, level = 58, cost = 110, base = 109, amount = 110 },
    [25296] = { rank = 7, level = 60, cost = 120, base = 119, amount = 120 },
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
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 3
        and scalar(spellId, "category") == 0
        and scalar(spellId, "castUI") == 0
        and scalar(spellId, "dispel") == 0
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 16
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "targetCreatureType") == 0
        and scalar(spellId, "requiresSpellFocus") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "procFlags") == 0
        and scalar(spellId, "procChance") == 0
        and scalar(spellId, "procCharges") == 0
        and scalar(spellId, "maxLevel") == 0
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "durationIndex") == 21
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == rank.cost
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "modalNextSpell") == 0
        and scalar(spellId, "stackAmount") == 0
        and scalar(spellId, "equippedItemClass") == -1
        and scalar(spellId, "equippedItemSubClassMask") == -1
        and scalar(spellId, "equippedItemInventoryTypeMask") == 0
        and scalar(spellId, "spellVisual") == 0
        and scalar(spellId, "spellIconID") == 112
        and scalar(spellId, "activeIconID") == 122
        and scalar(spellId, "spellPriority") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "maxTargetLevel") == 0
        and scalar(spellId, "spellFamilyName") == H.HUNTER_FAMILY
        and scalar(spellId, "spellFamilyFlags") == H.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.base, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), H.RANGED_AP_AURA, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function raw(spellId)
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        return found, found.reason, true
    end
    local rank = RANKS[spellId]
    if not rank then return nil, "not an installed Hawk identity", false end
    local out = { recognized = true, available = false, valid = false,
        exact = false, portfolio = "hunterHawk", spellId = spellId,
        source = "installed build-5875 Hawk DBC aura-124 topology" }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)) then
        out.reason = "Hawk DBC topology is incomplete"
    else
        out.available, out.valid, out.exact = true, true, true
        out.rank, out.level, out.cost = rank.rank, rank.level, rank.cost
        out.baseRangedAttackPower = rank.amount
        out.family, out.familyFlag = H.HUNTER_FAMILY, H.FAMILY_FLAG
        out.auraType, out.recipient = H.RANGED_AP_AURA, "self"
        out.durationModel, out.gcd, out.cast = "untilCancelled", 1.5, 0
    end
    CACHE[spellId] = copy(out)
    return copy(out), out.reason, true
end

local function modifiers(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Hawk modifier evidence unavailable"
    end
    local amount, trace = RANKS[spellId].amount, {}
    local kinds, index = { H.ALL_EFFECTS_MOD, H.ATTACK_POWER_MOD }, nil
    for index = 1, table.getn(kinds) do
        local ok, flat, percent, changed = pcall(
            GetSpellModifiers, spellId, kinds[index])
        flat = ok and finite(flat, -10000, 10000) or nil
        percent = ok and finite(percent, -100, 10000) or nil
        changed = ok and integer(changed, 0, 4294967295) or nil
        if flat == nil or percent == nil or changed == nil
            or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then
            return nil, "Hawk modifier evidence unavailable"
        end
        trace[index] = { kind = kinds[index], flat = flat,
            percent = percent, changed = changed }
        amount = (amount + flat) * (100 + percent) / 100
    end
    if not finite(amount, 0.0001, 100000) then
        return nil, "Hawk ranged attack power is outside its safe domain"
    end
    return amount, trace
end

local function profile(spellId)
    local out, reason, handled = raw(spellId)
    if not (handled and out and out.valid == true) then return out, reason end
    local amount, trace
    amount, trace = modifiers(spellId)
    if not amount then
        out.available, out.valid, out.exact, out.reason =
            false, false, false, trace
        return out, trace
    end
    out.rangedAttackPower = amount
    out.allEffectsModifier, out.attackPowerModifier = trace[1], trace[2]
    out.source = out.source .. " plus root-captured AP modifiers"
    return out, nil
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterHawkEvidence
    local rank = found and RANKS[found.spellId]
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "hunterHawk" and found.rank == rank.rank
        and found.level == rank.level and found.cost == rank.cost
        and found.baseRangedAttackPower == rank.amount
        and found.family == H.HUNTER_FAMILY
        and found.familyFlag == H.FAMILY_FLAG
        and found.auraType == H.RANGED_AP_AURA
        and found.recipient == "self" and found.gcd == 1.5
        and found.cast == 0 and found.durationModel == "untilCancelled") then
        return nil
    end
    return found
end

function H:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Hawk identity unavailable", false end
    return raw(spellId)
end

function H:InferKnowledge(spellId)
    if classToken() ~= "HUNTER" then
        return nil, "player is not an exactly identified Hunter", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, fixedTarget = "player", hunterAspect = true,
        exclusiveFamily = "hunterAspect", hunterHawk = true,
        hunterAspectEffectRepresented = true,
        requiresExactHunterHawkDownstream = true,
        requiresExactUsability = true, submissionGuarded = true,
        hunterHawkEvidence = found, powerType = 0, cost = found.cost,
        gcd = found.gcd, cast = found.cast, source = found.source }, nil, true
end

function H:CaptureFacts(action, facts)
    if not (facts and facts.hunterHawk == true) then return facts end
    local found = sealed(facts)
    if not (found and tonumber(action and action.spellId) == found.spellId) then
        return facts
    end
    local out, captured = copy(facts), profile(found.spellId)
    out.hunterHawkProfile = captured
    if not (captured and captured.valid == true) then
        out.hunterAspectEffectRepresented = false
    end
    return out
end

function H:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

function H:Profile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterHawkProfile
    local base = found and sealed({ hunterHawkEvidence = found })
    local first, second = found and found.allEffectsModifier,
        found and found.attackPowerModifier
    local function modifier(value, kind)
        local flat = value and finite(value.flat, -10000, 10000)
        local percent = value and finite(value.percent, -100, 10000)
        local changed = value and integer(value.changed, 0, 4294967295)
        return type(value) == "table" and value.kind == kind
            and flat and percent and changed
            and (flat ~= 0 or percent ~= 0) == (changed ~= 0)
            and flat, percent
    end
    local firstFlat, firstPercent = modifier(first, self.ALL_EFFECTS_MOD)
    local secondFlat, secondPercent = modifier(second, self.ATTACK_POWER_MOD)
    local expected = base and firstFlat and firstPercent
        and (base.baseRangedAttackPower + firstFlat)
            * (100 + firstPercent) / 100 or nil
    expected = expected and secondFlat and secondPercent
        and (expected + secondFlat) * (100 + secondPercent) / 100 or nil
    if not (base and expected and finite(expected, 0.0001, 100000)
        and found.rangedAttackPower == expected) then return nil end
    return copy(found)
end

local function identity()
    local guid
    if type(UnitExists) == "function" then
        local ok, exists, found = pcall(UnitExists, "player")
        if ok and (exists == true or exists == 1) then guid = found end
    end
    if (guid == nil or guid == "") and type(UnitGUID) == "function" then
        local ok, found = pcall(UnitGUID, "player")
        if ok then guid = found end
    end
    return guid ~= nil and guid ~= "" and guid or nil
end

function H:Observe(expectedGUID)
    local out = { available = false, exact = false,
        source = "numeric player aura scan plus installed Hawk rank set" }
    local before = identity()
    if classToken() ~= "HUNTER" or before == nil or before ~= expectedGUID
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        out.reason = "Hunter self aura evidence unavailable"
        return out
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    local after = identity()
    if not ok or type(list) ~= "table" or after ~= before
        or table.getn(list) > self.MAX_AURAS then
        out.reason = "Hunter self aura evidence unavailable"
        return out
    end
    local index, aura, active
    for index = 1, table.getn(list) do
        aura = list[index]
        local spellId = type(aura) == "table"
            and integer(aura.spellId, 1, 4294967295) or nil
        if not spellId then
            out.reason = "numeric Hunter self aura evidence unavailable"
            return out
        end
        if RANKS[spellId] then
            if active then
                out.reason = "multiple Hawk ranks are incoherent"
                return out
            end
            active = profile(spellId)
            if not (active and active.valid == true) then
                out.reason = active and active.reason
                    or "active Hawk profile unavailable"
                return out
            end
        end
    end
    out.available, out.exact, out.guid = true, true, before
    out.activeSpellId = active and active.spellId or nil
    out.activeRangedAttackPower = active and active.rangedAttackPower or 0
    out.activeProfile = active
    return out
end

function H:Invalidate()
    CACHE = {}
end
