-- Exact build-5875 Blessing-of-Might evidence. Numeric identities and complete
-- DBC topology select the mechanic; localized names and action priorities do
-- not. Mutable modifiers, duration, aura timing and melee lane are root-only.
XelAssist.Game.Player.PaladinMight = {}
local M = XelAssist.Game.Player.PaladinMight

M.PALADIN_FAMILY = 10
M.FAMILY_FLAG = 268435458
M.APPLY_AURA = 6
M.ATTACK_POWER_AURA = 99
M.ALL_EFFECTS_MOD = 8
M.ATTACK_POWER_MOD = 3

local RANKS = {
    [19740] = { rank = 1, level = 4, cost = 20, base = 19,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19834] = { rank = 2, level = 12, cost = 30, base = 34,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19835] = { rank = 3, level = 22, cost = 45, base = 54,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19836] = { rank = 4, level = 32, cost = 60, base = 84,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19837] = { rank = 5, level = 42, cost = 85, base = 114,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19838] = { rank = 6, level = 52, cost = 110, base = 154,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [25291] = { rank = 7, level = 60, maxLevel = 60, cost = 130, base = 184,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [25782] = { rank = 1, level = 52, cost = 220, base = 154,
        durationIndex = 30, range = 5, target = 61, radius = 12, greater = true },
    [25916] = { rank = 2, level = 60, maxLevel = 60, cost = 260, base = 184,
        durationIndex = 30, range = 5, target = 61, radius = 12, greater = true },
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

local function exactClassification(spellId, found)
    return type(found) == "table" and found.exact == true
        and tonumber(found.spellId) == spellId
        and found.family == M.PALADIN_FAMILY and found.flags == M.FAMILY_FLAG
        and found.kind == "blessing"
        and found.exclusiveFamily == "paladinBlessingByCaster"
end

local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 1
        and scalar(spellId, "dispel") == 1
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "maxLevel") == (rank.maxLevel or 0)
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "durationIndex") == rank.durationIndex
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == rank.cost
        and scalar(spellId, "rangeIndex") == rank.range
        and scalar(spellId, "spellFamilyName") == M.PALADIN_FAMILY
        and scalar(spellId, "spellFamilyFlags") == M.FAMILY_FLAG
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), M.APPLY_AURA, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.base, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), rank.target, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), rank.radius, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"),
            M.ATTACK_POWER_AURA, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function inspect(spellId, classification)
    spellId = integer(spellId, 1, 4294967295)
    local rank = spellId and RANKS[spellId] or nil
    if not rank then return nil, "not an installed Might identity", false end
    if CACHE[spellId] then
        local found = copy(CACHE[spellId])
        if not exactClassification(spellId, classification) then
            found.available, found.valid, found.exact = false, false, false
            found.reason = "captured Might blessing classification unavailable"
        end
        return found, found.reason, true
    end
    local out = { recognized = true, available = false, valid = false,
        exact = false, portfolio = "paladinMight", spellId = spellId,
        source = "installed build-5875 Might aura-99 DBC topology" }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)) then
        out.reason = "Might DBC topology is incomplete"
    else
        out.available, out.valid, out.exact = true, true, true
        out.rank, out.level, out.baseCost = rank.rank, rank.level, rank.cost
        out.maxLevel, out.baseAttackPower = rank.maxLevel or 0, rank.base + 1
        out.durationIndex, out.family, out.familyFlag = rank.durationIndex,
            M.PALADIN_FAMILY, M.FAMILY_FLAG
        out.auraType, out.gcd, out.cast = M.ATTACK_POWER_AURA, 1.5, 0
        out.recipientShape = rank.single and "single" or "classGroup"
        out.actionRepresented = rank.single and true or false
    end
    CACHE[spellId] = copy(out)
    if not exactClassification(spellId, classification) then
        out.available, out.valid, out.exact = false, false, false
        out.reason = "captured Might blessing classification unavailable"
    end
    return out, out.reason, true
end

local function modifierAmount(found)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Might modifier evidence unavailable"
    end
    local amount, trace = found.baseAttackPower, {}
    local kinds, index = { M.ALL_EFFECTS_MOD, M.ATTACK_POWER_MOD }, nil
    for index = 1, table.getn(kinds) do
        local ok, flat, percent, changed = pcall(
            GetSpellModifiers, found.spellId, kinds[index])
        flat = ok and finite(flat, -10000, 10000) or nil
        percent = ok and finite(percent, -100, 10000) or nil
        changed = ok and integer(changed, 0, 4294967295) or nil
        if flat == nil or percent == nil or changed == nil
            or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then
            return nil, "Might modifier evidence unavailable"
        end
        trace[index] = { kind = kinds[index], flat = flat,
            percent = percent, changed = changed }
        amount = (amount + flat) * (100 + percent) / 100
    end
    return finite(amount, 0.0001, 100000) and amount or nil,
        trace
end

local function capturedProfile(found)
    local out = copy(found)
    local amount, trace = modifierAmount(found)
    local ok, milliseconds = false, nil
    if type(GetSpellDuration) == "function" then
        ok, milliseconds = pcall(GetSpellDuration, found.spellId)
    end
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    if not amount or type(trace) ~= "table" or not milliseconds then
        out.available, out.valid, out.exact = false, false, false
        out.reason = type(trace) == "string" and trace
            or "Might duration evidence unavailable"
        return out
    end
    out.attackPower, out.duration = amount, milliseconds / 1000
    out.allEffectsModifier, out.attackPowerModifier = trace[1], trace[2]
    out.source = out.source .. " plus root modifiers and duration"
    return out
end

local function sealedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.paladinMightEvidence
    local rank = found and RANKS[found.spellId]
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "paladinMight" and found.rank == rank.rank
        and found.level == rank.level and found.maxLevel == (rank.maxLevel or 0)
        and found.baseCost == rank.cost and found.baseAttackPower == rank.base + 1
        and found.durationIndex == rank.durationIndex
        and found.family == M.PALADIN_FAMILY and found.familyFlag == M.FAMILY_FLAG
        and found.auraType == M.ATTACK_POWER_AURA
        and found.recipientShape == (rank.single and "single" or "classGroup")
        and found.actionRepresented == (rank.single and true or false)
        and found.gcd == 1.5 and found.cast == 0) then return nil end
    return found
end

local function modifier(value, kind)
    local flat = value and finite(value.flat, -10000, 10000)
    local percent = value and finite(value.percent, -100, 10000)
    local changed = value and integer(value.changed, 0, 4294967295)
    if not (type(value) == "table" and value.kind == kind
        and flat and percent and changed
        and (flat ~= 0 or percent ~= 0) == (changed ~= 0)) then return nil end
    return flat, percent
end

function M:Profile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found, base = facts and facts.paladinMightProfile,
        sealedEvidence(facts)
    local firstFlat, firstPercent = modifier(
        found and found.allEffectsModifier, self.ALL_EFFECTS_MOD)
    local secondFlat, secondPercent = modifier(
        found and found.attackPowerModifier, self.ATTACK_POWER_MOD)
    local expected = base and firstFlat and firstPercent
        and (base.baseAttackPower + firstFlat) * (100 + firstPercent) / 100
    expected = expected and secondFlat and secondPercent
        and (expected + secondFlat) * (100 + secondPercent) / 100
    if not (found and base and found.available == true and found.valid == true
        and found.exact == true and found.portfolio == "paladinMight"
        and found.spellId == base.spellId and found.rank == base.rank
        and found.level == base.level and found.maxLevel == base.maxLevel
        and found.baseCost == base.baseCost
        and found.baseAttackPower == base.baseAttackPower
        and found.durationIndex == base.durationIndex
        and found.recipientShape == base.recipientShape
        and found.actionRepresented == base.actionRepresented
        and expected and found.attackPower == expected
        and finite(found.duration, 0.001, 3600)) then return nil end
    return copy(found)
end

local function effect(profile)
    if not profile then return nil end
    return { exact = true, kind = "playerMeleeAttackPowerAura",
        actor = "recipient", sourceSpellId = profile.spellId,
        attackPower = profile.attackPower, duration = profile.duration,
        recipientShape = profile.recipientShape, source = profile.source }
end

function M:Promote(spellId, facts)
    if not (facts and facts.paladinBlessing == true) then return facts end
    local found = inspect(spellId, facts.paladinClassification)
    if not (found and found.valid == true and found.actionRepresented == true) then
        return facts
    end
    local out = copy(facts)
    out.paladinRepresentation = "exactMeleeAttackPowerAura"
    out.paladinEffectRepresented = true
    out.requiresExactPaladinMightProfile = true
    out.paladinMightEvidence = copy(found)
    return out
end

local WEAPON_EFFECT = { [17] = true, [31] = true, [58] = true, [121] = true }
local function meleeWeapon(action, facts)
    local coefficient = type(facts) == "table"
        and finite(facts.weaponCoefficient, 0.0001, 100) or nil
    if not (action and action.actor ~= "pet"
        and integer(action.spellId, 1, 4294967295) and coefficient
        and facts.weaponFormulaSource == "OctoWoW VMaNGOS weapon effects"
        and classToken() == "PALADIN"
        and scalar(action.spellId, "dmgClass") == 2) then return nil end
    local attributes, effects = scalar(action.spellId, "attributesEx3"),
        triple(action.spellId, "effect")
    if not attributes or not effects
        or math.floor(attributes / 16777216)
            - math.floor(attributes / 33554432) * 2 == 1 then return nil end
    local count, normalized, index = 0, false, nil
    for index = 1, 3 do
        local opcode = effects[index]
        if opcode == 2 then return nil end
        if WEAPON_EFFECT[opcode] then
            count = count + 1
            if opcode == 121 then normalized = true end
        end
    end
    if count ~= 1 then return nil end
    return { valid = true, exact = true, portfolio = "paladinMight",
        spellId = action.spellId, attackType = "main", weaponEffectCount = 1,
        normalized = normalized, weaponCoefficient = coefficient,
        source = "installed-client main-hand weapon effect and DmgClass" }
end

function M:CaptureFacts(action, facts)
    local found = sealedEvidence(facts)
    local weapon = meleeWeapon(action, facts)
    if not found and not weapon then return facts end
    local out = copy(facts)
    if found then
        if tonumber(action and action.spellId) == found.spellId then
            out.paladinMightProfile = capturedProfile(found)
            out.paladinDownstreamEffect = effect(self:Profile(out))
            if not out.paladinDownstreamEffect then
                out.paladinEffectRepresented = false
            else out.duration = out.paladinMightProfile.duration end
        else
            out.paladinEffectRepresented = false
            out.paladinDownstreamEffect = nil
        end
    end
    if weapon then out.paladinMainHandWeaponEvidence = weapon end
    return out
end

function M:CapturedEffect(subject)
    return effect(self:Profile(subject))
end

function M:Inspect(spellId, classification)
    local found, reason, handled = inspect(spellId, classification)
    return found and copy(found) or nil, reason, handled
end

local function meleeLane()
    if type(UnitAttackSpeed) ~= "function" or type(UnitDamage) ~= "function" then
        return nil, "Paladin melee damage lane unavailable"
    end
    local speedOk, speed = pcall(UnitAttackSpeed, "player")
    local damageOk, low, high, _, _, _, _, percent = pcall(UnitDamage, "player")
    speed, low, high, percent = tonumber(speed), tonumber(low),
        tonumber(high), tonumber(percent)
    if not (speedOk and damageOk and finite(speed, 0.01, 20)
        and finite(low, 0, 10000000) and finite(high, low, 10000000)
        and finite(percent, 0.0001, 100)) then
        return nil, "Paladin melee damage lane unavailable"
    end
    return { valid = true, exact = true, speed = speed,
        damageMultiplier = percent, damageMultiplierUnits = "factor",
        observedLow = low, observedHigh = high,
        source = "root-captured UnitAttackSpeed and UnitDamage multiplier" }
end

local function activeTiming(aura, profile, now)
    local duration = finite(aura and aura.duration, 0.001, 3600)
    local expiration = finite(aura and aura.expirationTime, 0.001, 100000000)
    if not (duration and expiration and now and expiration > now
        and math.abs(duration - profile.duration) <= 0.01
        and expiration - now <= duration + 0.01) then return nil end
    return expiration - now
end

function M:ObserveRoot(player, playerGUID)
    local out = { available = false, exact = false, portfolio = "paladinMight",
        baselineAttackPower = 0 }
    if classToken() ~= "PALADIN" or not (player and player.available == true
        and player.guid == playerGUID and player.playerGUID == playerGUID) then
        out.reason = "exact Paladin self blessing state unavailable"; return out
    end
    local lane, reason = meleeLane()
    local ok, now = false, nil
    if type(GetTime) == "function" then ok, now = pcall(GetTime) end
    now = finite(now, 0, 100000000)
    if not lane or not now then
        out.reason = reason or "Paladin aura clock unavailable"; return out
    end
    local caster, aura
    for caster, aura in pairs(player.blessingsByCaster or {}) do
        local rank = RANKS[tonumber(aura and aura.spellId)]
        if rank then
            local found, foundReason = inspect(aura.spellId, aura.classification)
            if not (found and found.valid == true) then
                out.reason = foundReason or "active Might evidence unavailable"
                return out
            end
            if caster ~= playerGUID then
                out.reason = "external Might stacking is unresolved"; return out
            end
            local profile = capturedProfile(found)
            local remaining = profile.valid and activeTiming(aura, profile, now)
            if not remaining then
                out.reason = profile.reason or "active Might timing unavailable"
                return out
            end
            out.activeSpellId, out.activeProfile = found.spellId, profile
            out.activeRemaining = remaining
            out.baselineAttackPower = profile.attackPower
        elseif caster == playerGUID then
            out.ownOtherBlessingSpellId = tonumber(aura and aura.spellId)
        end
    end
    out.available, out.exact, out.lane = true, true, lane
    out.source = "frozen Paladin blessings plus root melee lane"
    return out
end

function M:Invalidate()
    CACHE = {}
end
