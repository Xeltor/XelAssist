-- Exact installed-client Ruthlessness evidence. Talent and Spell.dbc APIs are
-- read only while root facts are captured; graph descendants consume the
-- sealed rank and finisher-family contracts without localized spell names.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.RogueRuthlessness = {}
local R = XelAssist.Game.Player.RogueRuthlessness

R.ROGUE_FAMILY = 8
R.ASSASSINATION_TAB = 1
R.TALENT_INDEX = 4
R.TALENT_ID = 131
R.MAX_RANK = 3
R.PROC_FLAGS = 87376
R.FINISHER_MASK = 4063232
R.TRIGGER_SPELL_ID = 14157
R.ADD_COMBO_EFFECT = 80

local RANKS = {
    [1] = { spellId = 14156, chance = 33, target = 6 },
    [2] = { spellId = 14160, chance = 66, target = 6 },
    [3] = { spellId = 14161, chance = 100, target = 1 },
}
local TALENT_CACHE, FINISHER_CACHE = {}, {}

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
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

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function playerExists()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    return ok and (exists == true or exists == 1)
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    value = integer(value, -2147483648, 4294967295)
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
        local value = finite(values[index], -2147483648, 4294967295)
        if signed and value and value >= 2147483648 then
            value = value - 4294967296
        end
        if value == nil then return nil end
        out[index] = value
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function flagSet(value, flag)
    value, flag = integer(value, 0, 9007199254740991),
        integer(flag, 1, 9007199254740991)
    return value and flag and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end

local function intersects(value, mask)
    local bit = 1
    while bit <= mask do
        if flagSet(mask, bit) and flagSet(value, bit) then return true end
        bit = bit * 2
    end
    return false
end

local ZERO = { 0, 0, 0 }

local function talentTopology(rank)
    local expected = RANKS[rank]
    if not expected then return nil end
    local cached = TALENT_CACHE[expected.spellId]
    if cached ~= nil then return cached and copy(cached) or nil end
    local spellId = expected.spellId
    local valid = scalar(spellId, "school") == 0
        and scalar(spellId, "attributes") == 464
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "procFlags") == R.PROC_FLAGS
        and scalar(spellId, "procChance") == expected.chance
        and scalar(spellId, "procCharges") == 0
        and scalar(spellId, "durationIndex") == 21
        and scalar(spellId, "powerType", true) == 0
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "spellFamilyName") == R.ROGUE_FAMILY
        and scalar(spellId, "spellFamilyFlags") == 0
        and equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides", true), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true), -1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"),
            expected.target, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 42, 0, 0)
        and equal(triple(spellId, "effectItemType"),
            R.FINISHER_MASK, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"),
            R.TRIGGER_SPELL_ID, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue", true), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
        and equal(triple(spellId, "dmgMultiplier"), 1, 0, 0)
    local out = valid and { exact = true, rank = rank, spellId = spellId,
        chancePercent = expected.chance, procFlags = R.PROC_FLAGS,
        finisherMask = R.FINISHER_MASK, triggerSpellId = R.TRIGGER_SPELL_ID,
        source = "installed build-5875 Ruthlessness proc topology" } or false
    TALENT_CACHE[spellId] = out and copy(out) or false
    return out and copy(out) or nil
end

local function triggerTopology()
    local spellId = R.TRIGGER_SPELL_ID
    return scalar(spellId, "attributes") == 16
        and scalar(spellId, "attributesEx") == 1024
        and scalar(spellId, "durationIndex") == 0
        and scalar(spellId, "rangeIndex") == 2
        and scalar(spellId, "spellFamilyName") == 0
        and scalar(spellId, "spellFamilyFlags") == 0
        and equal(triple(spellId, "effect"), R.ADD_COMBO_EFFECT, 0, 0)
        and equal(triple(spellId, "effectDieSides", true), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints", true), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue", true), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
        and equal(triple(spellId, "dmgMultiplier"), 1, 0, 0)
end

local function finisherTopology(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = FINISHER_CACHE[spellId]
    if cached ~= nil then return cached and copy(cached) or nil end
    local family = scalar(spellId, "spellFamilyName")
    local flags = scalar(spellId, "spellFamilyFlags")
    local attributes = scalar(spellId, "attributes")
    local attributesEx = scalar(spellId, "attributesEx")
    local powerType = scalar(spellId, "powerType", true)
    local valid = family == R.ROGUE_FAMILY and flags
        and intersects(flags, R.FINISHER_MASK)
        and attributes and not flagSet(attributes, 64)
        and attributesEx and (flagSet(attributesEx, 1048576)
            or flagSet(attributesEx, 4194304))
        and powerType == 3
    local out = valid and { exact = true, spellId = spellId,
        family = family, familyFlags = flags,
        finisherMask = R.FINISHER_MASK,
        source = "installed Rogue finisher family-mask topology" } or false
    FINISHER_CACHE[spellId] = out and copy(out) or false
    return out and copy(out) or nil
end

function R:Snapshot()
    local out = { available = false, exact = false,
        talentID = self.TALENT_ID,
        source = "exact Talent.dbc identity and installed Ruthlessness payload" }
    if classToken() ~= "ROGUE" or not playerExists() then
        out.reason = "Rogue player evidence unavailable"; return out
    end
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function"
        or type(GetTalentSpellID) ~= "function" then
        out.reason = "Ruthlessness talent evidence unavailable"; return out
    end
    local okID, talentID = pcall(GetTalentIDByIndex,
        self.ASSASSINATION_TAB, self.TALENT_INDEX)
    talentID = okID and integer(talentID, 1, 4294967295) or nil
    if talentID ~= self.TALENT_ID then
        out.reason = "Ruthlessness talent identity mismatch"; return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        self.ASSASSINATION_TAB, self.TALENT_INDEX)
    rank = ok and integer(rank, 0, self.MAX_RANK) or nil
    maximum = ok and integer(maximum, 1, self.MAX_RANK) or nil
    if rank == nil or maximum ~= self.MAX_RANK then
        out.reason = "Ruthlessness rank evidence unavailable"; return out
    end
    out.available, out.exact, out.rank = true, true, rank
    out.active, out.chancePercent = rank > 0, 0
    if rank == 0 then return out end
    local okSpell, spellId = pcall(GetTalentSpellID,
        self.ASSASSINATION_TAB, self.TALENT_INDEX, rank)
    spellId = okSpell and integer(spellId, 1, 4294967295) or nil
    local profile = spellId and talentTopology(rank) or nil
    if not (profile and profile.spellId == spellId and triggerTopology()) then
        out.available, out.exact, out.active = false, false, false
        out.reason = "Ruthlessness trigger topology unavailable"; return out
    end
    out.spellId, out.chancePercent = spellId, profile.chancePercent
    out.procFlags, out.finisherMask = profile.procFlags, profile.finisherMask
    out.triggerSpellId, out.comboGain = profile.triggerSpellId, 1
    return out
end

function R:CaptureFacts(action, facts)
    local out = copy(facts)
    if not (action and action.spellId and facts
        and (facts.combo == true or facts.comboSpendAll == true)) then return out end
    local found = finisherTopology(action.spellId)
    if not found then return out end
    out.rogueRuthlessnessFinisher = true
    out.rogueRuthlessnessFinisherEvidence = found
    return out
end

function R:Invalidate()
    TALENT_CACHE, FINISHER_CACHE = {}, {}
end
