-- Exact Octo Ancient Brutality Cat-side evidence. Talent.dbc identifies the
-- learned rank; Spell.dbc links periodic player damage to a fixed energize
-- payload. The Bear dodge branch is intentionally not projected here.
XelAssist.Game.Player.DruidAncientBrutality = {}
local A = XelAssist.Game.Player.DruidAncientBrutality

A.DRUID_FAMILY, A.ENERGY, A.CAT_FORM = 7, 3, 1
A.FERAL_TAB, A.TALENT_INDEX, A.TALENT_ID = 2, 14, 280
A.MAX_RANK = 2
A.RANKS = {
    [1] = { talentSpellId = 51415, triggerSpellId = 51412, energy = 3 },
    [2] = { talentSpellId = 51416, triggerSpellId = 51413, energy = 5 },
}

local CACHE = {}

local function integer(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then
        value = value - 4294967296
    end
    return value
end

local function triple(spellId, field, signed)
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
        out[index] = integer(values[index], signed and -2147483648 or 0,
            4294967295)
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function passiveTopology(rank)
    local spec = A.RANKS[rank]
    if not spec then return false end
    local id = spec.talentSpellId
    return scalar(id, "attributes") == 464
        and scalar(id, "stances") == A.CAT_FORM
        and scalar(id, "procFlags") == 262144
        and scalar(id, "procChance") == 100
        and scalar(id, "durationIndex") == 21
        and scalar(id, "spellFamilyName") == A.DRUID_FAMILY
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectBasePoints", true), rank - 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 42, 0, 0)
        and equal(triple(id, "effectTriggerSpell"),
            spec.triggerSpellId, 0, 0)
end

local function triggerTopology(rank)
    local spec = A.RANKS[rank]
    if not spec then return false end
    local id = spec.triggerSpellId
    local points, dice = triple(id, "effectBasePoints", true),
        triple(id, "effectBaseDice")
    return scalar(id, "attributes") == 0
        and scalar(id, "procChance") == 101
        and scalar(id, "baseLevel") == 60
        and scalar(id, "spellLevel") == 60
        and scalar(id, "rangeIndex") == 1
        and scalar(id, "spellFamilyName") == A.DRUID_FAMILY
        and equal(triple(id, "effect"), 30, 0, 0)
        and equal(dice, 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectMiscValue"), A.ENERGY, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
        and points and points[1] + dice[1] == spec.energy
end

local function profile(rank)
    if CACHE[rank] ~= nil then
        return CACHE[rank].valid and copy(CACHE[rank]) or nil
    end
    local spec = A.RANKS[rank]
    local valid = spec and passiveTopology(rank) and triggerTopology(rank)
    CACHE[rank] = valid and { available = true, valid = true,
        exact = true, rank = rank,
        talentID = A.TALENT_ID, talentSpellId = spec.talentSpellId,
        triggerSpellId = spec.triggerSpellId, energy = spec.energy,
        powerType = A.ENERGY, formID = A.CAT_FORM,
        source = "installed Octo Talent.dbc and patch-5 Spell.dbc topology" }
        or { valid = false }
    return valid and copy(CACHE[rank]) or nil
end

local function druid()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "DRUID"
end

function A:Snapshot()
    local out = { available = false, exact = false,
        talentID = self.TALENT_ID,
        source = "installed Octo Ancient Brutality evidence" }
    if not druid() then
        out.reason = "player is not an exactly identified Druid"
        return out
    end
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function"
        or type(GetTalentSpellID) ~= "function" then
        out.reason = "Ancient Brutality talent evidence unavailable"
        return out
    end
    local okID, talentID = pcall(GetTalentIDByIndex,
        self.FERAL_TAB, self.TALENT_INDEX)
    if not okID or talentID ~= self.TALENT_ID then
        out.reason = "Ancient Brutality talent identity mismatch"
        return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        self.FERAL_TAB, self.TALENT_INDEX)
    rank, maximum = ok and integer(rank, 0, self.MAX_RANK) or nil,
        ok and integer(maximum, 1, self.MAX_RANK) or nil
    if rank == nil or maximum ~= self.MAX_RANK then
        out.reason = "Ancient Brutality rank evidence unavailable"
        return out
    end
    if rank == 0 then
        out.available, out.exact, out.rank, out.energy = true, true, 0, 0
        return out
    end
    local okSpell, spellId = pcall(GetTalentSpellID,
        self.FERAL_TAB, self.TALENT_INDEX, rank)
    local found = okSpell and spellId == self.RANKS[rank].talentSpellId
        and profile(rank) or nil
    if not found then
        out.reason = "Ancient Brutality installed topology unavailable"
        return out
    end
    return found
end

function A:Invalidate() CACHE = {} end
