-- Exact Fel Domination discovery and root sealing for build 5875. Numeric DBC
-- topology selects the setup and affected summons; localized names never do.
-- Mutable aura, talent, modifier, cost, and unit fields are read only here.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarlockFelDomination = {}
local F = XelAssist.Game.Player.WarlockFelDomination

F.SPELL_ID, F.WARLOCK_FAMILY = 18708, 5
F.SUMMON_MASK, F.MANA = 536870912, 0
F.CAST_MODIFIER, F.COST_MODIFIER = 10, 14
F.CAST_FLAT, F.COST_PERCENT = -4500, -40
F.DURATION, F.MAX_ACTIONS = 15, 256

local MASTER = {
    [18709] = { rank = 1, castFlat = -2000, costPercent = -30,
        cooldownPercent = -25, points = { -2001, -31, -26 } },
    [18710] = { rank = 2, castFlat = -4000, costPercent = -60,
        cooldownPercent = -50, points = { -4001, -61, -51 } },
}
local PROFILE, MASTER_VALID, ACTIONS, ACTION_COUNT = nil, nil, {}, 0
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
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
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
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function flagSet(value, flag)
    value = unsigned32(value)
    if not value then return nil end
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end
local function setupScalars()
    local id = F.SPELL_ID
    return scalar(id, "school") == 5 and scalar(id, "category") == 0
        and scalar(id, "castUI") == 0 and scalar(id, "dispel") == 1
        and scalar(id, "mechanic") == 0 and scalar(id, "attributes") == 65536
        and scalar(id, "attributesEx") == 131072
        and scalar(id, "attributesEx2") == 0
        and scalar(id, "attributesEx3") == 0
        and scalar(id, "attributesEx4") == 0
        and scalar(id, "castingTimeIndex") == 1
        and scalar(id, "recoveryTime") == 300000
        and scalar(id, "categoryRecoveryTime") == 0
        and scalar(id, "interruptFlags") == 0
        and scalar(id, "auraInterruptFlags") == 0
        and scalar(id, "channelInterruptFlags") == 0
        and scalar(id, "procFlags") == 87376
        and scalar(id, "procChance") == 100
        and scalar(id, "procCharges") == 1
        and scalar(id, "durationIndex") == 8
        and scalar(id, "powerType") == F.MANA
        and scalar(id, "manaCost") == 0
        and scalar(id, "manaCostPerlevel") == 0
        and scalar(id, "manaCostPercentage") == 0
        and scalar(id, "rangeIndex") == 1
        and scalar(id, "startRecoveryCategory") == 0
        and scalar(id, "startRecoveryTime") == 0
        and scalar(id, "spellFamilyName") == F.WARLOCK_FAMILY
        and scalar(id, "spellFamilyFlags") == 0
        and scalar(id, "maxAffectedTargets") == 0
        and scalar(id, "dmgClass") == 1
        and scalar(id, "preventionType") == 1
end
local function setupEffects()
    local id = F.SPELL_ID
    return equal(triple(id, "effect"), 6, 6, 0)
        and equal(triple(id, "effectDieSides"), 1, 1, 1)
        and equal(triple(id, "effectBaseDice"), 1, 1, 0)
        and equal(triple(id, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(id, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(id, "effectBasePoints"), -4501, -41, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(id, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 107, 108, 0)
        and equal(triple(id, "effectAmplitude"), 0, 0, 0)
        and equal(triple(id, "effectItemType"),
            F.SUMMON_MASK, F.SUMMON_MASK, F.SUMMON_MASK)
        and equal(triple(id, "effectMiscValue"),
            F.CAST_MODIFIER, F.COST_MODIFIER, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end
local function installedProfile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not (setupScalars() and setupEffects()) then
        PROFILE = { recognized = true, valid = false, exact = false,
            reason = "Fel Domination DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { recognized = true, valid = true, exact = true,
        spellId = F.SPELL_ID, family = F.WARLOCK_FAMILY,
        summonMask = F.SUMMON_MASK, charges = 1, duration = F.DURATION,
        castModifier = F.CAST_MODIFIER, castFlat = F.CAST_FLAT,
        costModifier = F.COST_MODIFIER, costPercent = F.COST_PERCENT,
        source = "installed build-5875 Fel Domination DBC spellmods" }
    return copy(PROFILE)
end

local function masterEffects(id, rank)
    return equal(triple(id, "effect"), 6, 6, 6)
        and equal(triple(id, "effectDieSides"), 1, 1, 1)
        and equal(triple(id, "effectBaseDice"), 1, 1, 1)
        and equal(triple(id, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(id, "effectBasePoints"),
            rank.points[1], rank.points[2], rank.points[3])
        and equal(triple(id, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(id, "effectApplyAuraName"), 107, 108, 108)
        and equal(triple(id, "effectItemType"),
            F.SUMMON_MASK, F.SUMMON_MASK, 0)
        and equal(triple(id, "effectMiscValue"), 10, 14, 11)
end

local function masterTopology(id, rank)
    return scalar(id, "school") == 0 and scalar(id, "attributes") == 464
        and scalar(id, "attributesEx") == 0
        and scalar(id, "attributesEx2") == 0
        and scalar(id, "attributesEx3") == 0
        and scalar(id, "durationIndex") == 21
        and scalar(id, "castingTimeIndex") == 1
        and scalar(id, "recoveryTime") == 0
        and scalar(id, "powerType") == F.MANA
        and scalar(id, "manaCost") == 0
        and scalar(id, "rangeIndex") == 1
        and scalar(id, "spellFamilyName") == F.WARLOCK_FAMILY
        and scalar(id, "spellFamilyFlags") == 0
        and masterEffects(id, rank)
end

local function masterRank()
    if MASTER_VALID == nil then
        MASTER_VALID = masterTopology(18709, MASTER[18709])
            and masterTopology(18710, MASTER[18710])
    end
    if not MASTER_VALID or type(IsPlayerSpell) ~= "function" then
        return nil, "Master Summoner evidence unavailable"
    end
    local okOne, one = pcall(IsPlayerSpell, 18709)
    local okTwo, two = pcall(IsPlayerSpell, 18710)
    if not okOne or not okTwo
        or one ~= true and one ~= false and one ~= 1 and one ~= 0
        or two ~= true and two ~= false and two ~= 1 and two ~= 0 then
        return nil, "Master Summoner evidence unavailable"
    end
    if two == true or two == 1 then return copy(MASTER[18710]) end
    if one == true or one == 1 then return copy(MASTER[18709]) end
    return { rank = 0, castFlat = 0, costPercent = 0,
        cooldownPercent = 0 }
end

local function summonProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    if ACTIONS[spellId] then return copy(ACTIONS[spellId]) end
    local family = scalar(spellId, "spellFamilyName")
    local flags = scalar(spellId, "spellFamilyFlags")
    local masked = family == F.WARLOCK_FAMILY and flagSet(flags, F.SUMMON_MASK)
    local out = { claimed = masked == true, exact = false,
        eligible = false, spellId = spellId, family = family, familyFlags = flags }
    if not masked then out.exact = family ~= nil and flags ~= nil
    else
        local effects, targets = triple(spellId, "effect"),
            triple(spellId, "effectImplicitTargetA")
        local misc = triple(spellId, "effectMiscValue")
        local costPercent = scalar(spellId, "manaCostPercentage")
        local exact = scalar(spellId, "school") == 5
            and scalar(spellId, "attributes") == 65536
            and scalar(spellId, "attributesEx") == 131073
            and scalar(spellId, "attributesEx2") == 0
            and scalar(spellId, "attributesEx3") == 0
            and scalar(spellId, "castingTimeIndex") == 7
            and scalar(spellId, "durationIndex") == 21
            and scalar(spellId, "powerType") == F.MANA
            and scalar(spellId, "manaCost") == 0
            and scalar(spellId, "manaCostPerlevel") == 0
            and integer(costPercent, 1, 100)
            and equal(effects, 56, 0, 0) and equal(targets, 32, 0, 0)
            and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
            and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
            and misc and integer(misc[1], 1, 4294967295)
            and misc[2] == 0 and misc[3] == 0
        out.exact, out.eligible = exact and true or false, exact and true or false
        out.reason = not exact and "affected Warlock summon topology is incomplete" or nil
        out.baseCastMs, out.costPercent, out.summonEffect = 10000,
            costPercent, exact and 56 or nil
    end
    if ACTION_COUNT < F.MAX_ACTIONS then
        ACTIONS[spellId], ACTION_COUNT = copy(out), ACTION_COUNT + 1
    end
    return out
end

local function modifiers(spellId, operation)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(GetSpellModifiers, spellId, operation)
    flat, percent = ok and signed32(flat) or nil, ok and signed32(percent) or nil
    changed = ok and finite(changed, -4294967295, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil then return nil end
    return { flat = flat, percent = percent, changed = changed }
end

local function playerFields()
    if type(GetUnitField) ~= "function" then return nil end
    local okMana, baseMana = pcall(GetUnitField, "player", "baseMana")
    local okSpeed, speed = pcall(GetUnitField, "player", "modCastSpeed")
    local okFlat, schoolFlat = pcall(GetUnitField,
        "player", "powerCostModifier", 1)
    local okPct, schoolPct = pcall(GetUnitField,
        "player", "powerCostMultiplier", 1)
    baseMana = okMana and integer(baseMana, 1, 1000000000) or nil
    speed = okSpeed and finite(speed, 0.000001, 1000) or nil
    if not (okFlat and okPct and type(schoolFlat) == "table"
        and type(schoolPct) == "table") then return nil end
    local flat = integer(schoolFlat[6], -1000000000, 1000000000)
    local percent = finite(schoolPct[6], -0.999999, 1000)
    if not (baseMana and speed and flat and percent) then return nil end
    return { baseMana = baseMana, castSpeed = speed,
        schoolFlat = flat, schoolMultiplier = percent }
end

local function engineCost(spellId)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok or type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then return nil end
    local entry = costs[1]
    local cost = integer(entry.cost, 0, 1000000000)
    if not cost or entry.type ~= F.MANA or entry.minCost ~= cost
        or entry.costPerSec ~= 0 or entry.requiredAuraID ~= 0
        or entry.hasRequiredAura ~= false then return nil end
    return cost
end

local function spellInfo(spellId)
    if not (C_Spell and type(C_Spell.GetSpellInfo) == "function") then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if not ok or type(info) ~= "table" or info.spellID ~= spellId
        or integer(info.castTime, 0, 600000) ~= 10000 then return nil end
    return info
end

local function calculate(profile, fields, castMod, costMod)
    local castMs = math.max(0, profile.baseCastMs + castMod.flat)
    castMs = math.floor(castMs * (100 + castMod.percent) / 100)
    castMs = math.floor(castMs * fields.castSpeed)
    local cost = math.floor(profile.costPercent * fields.baseMana / 100)
        + fields.schoolFlat + costMod.flat
    if cost < 0 or costMod.percent < -100 then return nil end
    cost = math.floor(cost * (100 + costMod.percent) / 100)
    cost = math.max(0, math.floor(cost * (1 + fields.schoolMultiplier)))
    return castMs / 1000, cost
end

local function consumerContract(action, state)
    local found = summonProfile(action and action.spellId)
    if not (found and found.claimed) then return nil end
    local out = copy(found)
    if not found.exact then return out end
    local master, reason = masterRank()
    local fields = playerFields()
    local castMod = modifiers(found.spellId, F.CAST_MODIFIER)
    local costMod = modifiers(found.spellId, F.COST_MODIFIER)
    local active = state and state.warlockFelDomination
        and state.warlockFelDomination.active == true
    local expectedCast = master and master.castFlat + (active and F.CAST_FLAT or 0)
    local expectedCost = master and master.costPercent
        + (active and F.COST_PERCENT or 0)
    if not (master and fields and castMod and costMod and spellInfo(found.spellId)
        and castMod.flat == expectedCast and castMod.percent == 0
        and costMod.flat == 0 and costMod.percent == expectedCost) then
        out.exact, out.eligible = false, false
        out.reason = reason or "Fel Domination modifier stack is not exact"
        return out
    end
    local baseCastMod = { flat = master.castFlat, percent = 0 }
    local baseCostMod = { flat = 0, percent = master.costPercent }
    local felCastMod = { flat = master.castFlat + F.CAST_FLAT, percent = 0 }
    local felCostMod = { flat = 0,
        percent = master.costPercent + F.COST_PERCENT }
    local baselineCast, baselineCost = calculate(
        found, fields, baseCastMod, baseCostMod)
    local affectedCast, affectedCost = calculate(
        found, fields, felCastMod, felCostMod)
    local observed = engineCost(found.spellId)
    local expectedObserved = active and affectedCost or baselineCost
    if not (baselineCast and baselineCost and affectedCast and affectedCost
        and observed == expectedObserved and baselineCast > affectedCast
        and baselineCost >= affectedCost) then
        out.exact, out.eligible = false, false
        out.reason = "Fel Domination summon cost or cast delta is unavailable"
        return out
    end
    out.exact, out.eligible = true, true
    out.baselineCast, out.affectedCast = baselineCast, affectedCast
    out.baselineCost, out.affectedCost = baselineCost, affectedCost
    out.savedCast, out.savedMana = baselineCast - affectedCast,
        baselineCost - affectedCost
    out.masterSummonerRank = master.rank
    out.stackVerified = master.rank > 0
    out.source = "root-verified Fel Domination and Master Summoner aggregate"
    return out
end

function F:InferKnowledge(spellId)
    if integer(spellId, 1, 4294967295) ~= F.SPELL_ID then
        return nil, "spell is not Fel Domination", false
    end
    if classToken() ~= "WARLOCK" then
        return nil, "player is not an exactly identified Warlock", false
    end
    local found, reason = installedProfile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        self = true, combatBuff = true, cooldown = true,
        warlockFelDomination = true, requiresWarlockFelDominationEvidence = true,
        submissionGuarded = true, warlockFelDominationEvidence = copy(found),
        source = found.source }, nil, true
end

function F:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warlockFelDominationEvidence
    if not (facts and facts.warlockFelDomination == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == F.SPELL_ID
        and found.family == F.WARLOCK_FAMILY
        and found.summonMask == F.SUMMON_MASK and found.charges == 1
        and found.duration == F.DURATION
        and found.castModifier == F.CAST_MODIFIER
        and found.castFlat == F.CAST_FLAT
        and found.costModifier == F.COST_MODIFIER
        and found.costPercent == F.COST_PERCENT) then return nil end
    return found
end

function F:Is(subject) return self:Evidence(subject) ~= nil end

local function observe(profile)
    local out = { available = false, exact = false, active = false,
        profile = copy(profile), source = "numeric Fel Domination aura snapshot" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
        and type(GetTime) == "function") then
        out.reason = "Fel Domination aura evidence unavailable"; return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, F.SPELL_ID)
    local timeOK, now = pcall(GetTime)
    now = timeOK and finite(now, 0, 1000000000) or nil
    if not ok or not now then out.reason = "Fel Domination aura evidence unavailable"; return out end
    out.available, out.exact = true, true
    if aura == nil then return out end
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime, now, now + F.DURATION + 0.001) or nil
    if integer(aura.spellId, 1, 4294967295) ~= F.SPELL_ID
        or aura.isHelpful ~= true or integer(aura.applications, 1, 1) ~= 1
        or finite(aura.duration, F.DURATION, F.DURATION) ~= F.DURATION
        or not expiration or expiration <= now then
        out.available, out.exact = false, false
        out.reason = "active Fel Domination aura evidence is incomplete"
        return out
    end
    out.active, out.remaining = true, expiration - now
    out.epoch = tostring(F.SPELL_ID) .. ":" .. tostring(expiration)
    return out
end

function F:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.warlockFelDomination = nil
    if (knownClass or classToken()) ~= "WARLOCK" then return false end
    local profile, reason = installedProfile()
    if not profile then
        state.warlockFelDomination = { available = false, exact = false,
            reason = reason }; return false
    end
    state.warlockFelDomination = observe(profile)
    return state.warlockFelDomination.exact == true
end

function F:CaptureFacts(action, facts, state)
    local out, setup = facts, self:Evidence(action) or self:Evidence(facts)
    if setup then
        out = copy(facts)
        out.warlockFelDominationEvidence = copy(setup)
    end
    if not (state and state.warlockFelDomination
        and state.warlockFelDomination.available == true
        and state.warlockFelDomination.exact == true and action
        and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return out end
    local contract = consumerContract(action, state)
    if not contract then return out end
    if out == facts then out = copy(facts) end
    out.warlockFelDominationSummon = contract
    return out
end

function F:Invalidate()
    PROFILE, MASTER_VALID, ACTIONS, ACTION_COUNT = nil, nil, {}, 0
end
