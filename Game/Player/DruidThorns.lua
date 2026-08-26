-- Exact installed Thorns ranks. The graph values only retaliation against an
-- observed attacker; this module owns identity, effective player modifiers,
-- cost, duration, and the live self-aura boundary.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.DruidThorns = {}
local T = XelAssist.Game.Player.DruidThorns

T.DRUID_FAMILY = 7
T.FAMILY_FLAG = 256
T.THORNS_AURA = 15
T.DURATION_MOD = 1
T.ALL_EFFECTS_MOD = 8
T.IMPROVED_ID = 52354
T.RANKS = {
    [467] = { rank = 1, level = 6, cost = 35, damage = 3 },
    [782] = { rank = 2, level = 14, cost = 60, damage = 6 },
    [1075] = { rank = 3, level = 24, cost = 105, damage = 9 },
    [8914] = { rank = 4, level = 34, cost = 170, damage = 12 },
    [9756] = { rank = 5, level = 44, cost = 240, damage = 15 },
    [9910] = { rank = 6, level = 54, cost = 320, damage = 18 },
}
local CACHE = {}

local function finite(value, low, high)
    value = tonumber(value)
    return value and value == value and value ~= math.huge
        and value ~= -math.huge and value >= low and value <= high
        and value or nil
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
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
    local out, key, count, index = {}, nil, 0, nil
    for key in pairs(values) do
        if not integer(key, 1, 3) then return nil end
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

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function duration(spellId, base)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, base and 1 or nil)
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end

local function shape(spellId, rank)
    return scalar(spellId, "school") == 3
        and scalar(spellId, "dispel") == 1
        and scalar(spellId, "attributes") == 65536
        and scalar(spellId, "attributesEx2") == 524288
        and scalar(spellId, "stances") == 1073741824
        and scalar(spellId, "castingTimeIndex") == 8
        and scalar(spellId, "auraInterruptFlags") == 101
        and scalar(spellId, "durationIndex") == 6
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == rank.cost
        and scalar(spellId, "rangeIndex") == 4
        and scalar(spellId, "spellFamilyName") == T.DRUID_FAMILY
        and scalar(spellId, "spellFamilyFlags") == T.FAMILY_FLAG
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), rank.damage - 1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 21, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), T.THORNS_AURA, 0, 0)
        and duration(spellId, true) == 600
end

local function improvedShape()
    return scalar(T.IMPROVED_ID, "attributes") == 448
        and scalar(T.IMPROVED_ID, "durationIndex") == 21
        and scalar(T.IMPROVED_ID, "spellFamilyName") == T.DRUID_FAMILY
        and equal(triple(T.IMPROVED_ID, "effect"), 6, 6, 0)
        and equal(triple(T.IMPROVED_ID, "effectBasePoints"), 99, 99, 0)
        and equal(triple(T.IMPROVED_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(T.IMPROVED_ID, "effectApplyAuraName"), 108, 108, 0)
        and equal(triple(T.IMPROVED_ID, "effectMiscValue"),
            T.DURATION_MOD, T.ALL_EFFECTS_MOD, 0)
end

local function staticProfile(spellId)
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local rank = T.RANKS[spellId]
    if not rank then return nil end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "druidThorns", spellId = spellId,
        source = "installed Octo patch-5 Thorns DBC topology" }
    if shape(spellId, rank) then
        found.valid, found.exact = true, true
        found.rank, found.level = rank.rank, rank.level
        found.baseDamage, found.baseCost = rank.damage, rank.cost
        found.baseDuration, found.powerType = 600, 0
        found.school, found.auraType = 3, T.THORNS_AURA
    else found.reason = "Thorns DBC topology is incomplete" end
    CACHE[spellId] = copy(found)
    return copy(found)
end

function T:InferKnowledge(spellId)
    spellId = integer(spellId, 1, 4294967295)
    local found = spellId and staticProfile(spellId) or nil
    if not found then return nil, "not an installed Thorns identity", false end
    if classToken() ~= "DRUID" then
        return nil, "player is not an exactly identified Druid", true
    end
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, fixedTarget = "player", druidThorns = true,
        requiresExactDruidThorns = true, requiresExactUsability = true,
        submissionGuarded = true, spell = true, school = found.school,
        druidThornsEvidence = found, source = found.source }, nil, true
end

local function modifier(spellId, operation)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, operation)
    flat, percent, changed = tonumber(flat), tonumber(percent), tonumber(changed)
    if not ok or flat == nil or percent == nil or changed == nil then return nil end
    return { flat = flat, percent = percent, changed = changed }
end

local function improvedKnown()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, learned = pcall(IsPlayerSpell, T.IMPROVED_ID)
    if not ok then return nil end
    return learned and true or false
end

local function effectiveCost(spellId)
    local api = C_Spell and C_Spell.GetSpellPowerCost
    if type(api) ~= "function" then return nil end
    local ok, costs = pcall(api, spellId)
    local row = ok and type(costs) == "table" and costs[1] or nil
    return row and row.type == 0 and integer(row.cost, 0, 100000) or nil
end

local function capture(found)
    local out, effectMod, durationMod, improved = copy(found),
        modifier(found.spellId, T.ALL_EFFECTS_MOD),
        modifier(found.spellId, T.DURATION_MOD), improvedKnown()
    local cost, actualDuration = effectiveCost(found.spellId),
        duration(found.spellId, false)
    if not (effectMod and durationMod and improved ~= nil
        and cost and actualDuration) then
        out.valid, out.exact = false, false
        out.reason = "effective Thorns evidence is unavailable"
        return out
    end
    local expectedPercent = improved and 100 or 0
    local expectedDuration = improved and 1200 or 600
    if improved and not improvedShape()
        or effectMod.flat ~= 0 or effectMod.percent ~= expectedPercent
        or durationMod.flat ~= 0 or durationMod.percent ~= expectedPercent
        or actualDuration ~= expectedDuration then
        out.valid, out.exact = false, false
        out.reason = "effective Thorns modifiers are unresolved"
        return out
    end
    out.improved, out.effectPercent = improved, expectedPercent
    out.damage = found.baseDamage * (1 + expectedPercent / 100)
    out.duration, out.cost = actualDuration, cost
    out.valid, out.exact = true, true
    return out
end

function T:Evidence(subject)
    local facts = type(subject) == "table" and (subject.facts or subject) or nil
    local found = facts and facts.druidThornsEvidence
    local rank = found and self.RANKS[found.spellId]
    if not (facts and facts.druidThorns == true and rank
        and found.valid == true and found.exact == true
        and found.portfolio == "druidThorns" and found.rank == rank.rank
        and found.baseDamage == rank.damage and found.baseCost == rank.cost
        and found.damage == rank.damage * (found.improved and 2 or 1)
        and found.duration == (found.improved and 1200 or 600)
        and found.cost and found.cost >= 0 and found.powerType == 0
        and found.school == 3 and found.auraType == self.THORNS_AURA) then
        return nil
    end
    return copy(found)
end

function T:CaptureFacts(action, facts)
    local base = self:Evidence(facts) or self:Evidence(action)
    if base then return facts end
    local source = type(facts) == "table" and facts.druidThornsEvidence
        or action and action.facts and action.facts.druidThornsEvidence
    if not (source and source.portfolio == "druidThorns") then return facts end
    local found = capture(staticProfile(source.spellId))
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.druidThornsEvidence = found
    out.cost, out.powerType, out.duration = found.cost, 0, found.duration
    return out
end

local function activeAura(found)
    local api = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(api) ~= "function" or type(GetTime) ~= "function" then
        return nil, "Thorns aura evidence unavailable"
    end
    local ok, aura = pcall(api, found.spellId)
    if not ok or aura == nil then return false end
    local nowOk, now = pcall(GetTime)
    local expiration = type(aura) == "table" and tonumber(aura.expirationTime)
    now = nowOk and tonumber(now) or nil
    if tonumber(aura.spellId) ~= found.spellId or aura.isHelpful ~= true
        or not now or not expiration or expiration <= now
        or expiration - now > found.duration + 0.01 then
        return nil, "active Thorns aura is incomplete"
    end
    return true, nil, expiration - now
end

local function learned(spellId)
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, spellId)
    if not ok then return nil end
    return value and true or false
end

function T:Snapshot(token)
    if (token or classToken()) ~= "DRUID" then return nil end
    local best, activeProfile, activeRemaining, spellId
    for spellId in pairs(self.RANKS) do
        local known, static = learned(spellId), staticProfile(spellId)
        if known == nil then return { available = false, exact = false,
            reason = "learned Thorns ranks are unavailable" } end
        if known and static and static.valid then
            local found = capture(static)
            if found.valid and (not best or found.rank > best.rank) then best = found end
            if found.valid then
                local active, reason, remaining = activeAura(found)
                if active == nil then return { available = false, exact = false,
                    reason = reason } end
                if active then activeProfile, activeRemaining = found, remaining end
            end
        end
    end
    if not best then return { available = false, exact = false,
        reason = "effective Thorns rank evidence unavailable" } end
    return { available = true, exact = true, active = activeProfile ~= nil,
        remaining = activeRemaining, profile = best,
        activeProfile = activeProfile }
end

function T:Invalidate()
    CACHE = {}
end
