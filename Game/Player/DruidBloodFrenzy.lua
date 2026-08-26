-- Exact installed Blood Frenzy evidence. The talent's immediate Enrage rage
-- packet and linked melee-haste aura are sealed separately; Tiger's Fury's
-- duration extension remains outside this Enrage-specific leaf.
XelAssist.Game.Player.DruidBloodFrenzy = {}
local B = XelAssist.Game.Player.DruidBloodFrenzy

B.DRUID_FAMILY, B.RAGE = 7, 1
B.FERAL_TAB, B.TALENT_INDEX, B.TALENT_ID = 2, 12, 278
B.ENRAGE_ID, B.BEAR_MASK = 5229, 144
B.RANKS = {
    [1] = { talentSpellId = 45721, triggerSpellId = 17080,
        hasteSpellId = 45729, bonusRage = 5,
        hastePercent = 10, hasteDuration = 9, hasteDurationIndex = 105 },
    [2] = { talentSpellId = 45722, triggerSpellId = 17081,
        hasteSpellId = 45730, bonusRage = 10,
        hastePercent = 20, hasteDuration = 18, hasteDurationIndex = 85 },
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
local function scalar(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then
        value = value - 4294967296
    end
    return value
end
local function triple(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
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
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b
        and values[3] == c
end
local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, id, 1)
    value = ok and integer(value, 0, 3600000) or nil
    return value and value / 1000 or nil
end

local function talentTopology(rank)
    local spec, id = B.RANKS[rank], B.RANKS[rank].talentSpellId
    return scalar(id, "attributes") == 208
        and scalar(id, "stances") == 145
        and scalar(id, "procFlags") == 87376
        and scalar(id, "procChance") == 100
        and scalar(id, "durationIndex") == 21
        and scalar(id, "spellFamilyName") == B.DRUID_FAMILY
        and equal(triple(id, "effect"), 6, 6, 6)
        and equal(triple(id, "effectDieSides"), 1, 1, 0)
        and equal(triple(id, "effectBasePoints", true),
            rank == 1 and 5999 or 11999, -1, 100)
        and equal(triple(id, "effectApplyAuraName"), 107, 42, 109)
        and equal(triple(id, "effectTriggerSpell"),
            0, spec.triggerSpellId, spec.hasteSpellId)
        and equal(triple(id, "effectMiscValue", true),
            1, 0, rank == 1 and 0 or 7)
end

local function triggerTopology(rank)
    local spec, id = B.RANKS[rank], B.RANKS[rank].triggerSpellId
    local points, dice = triple(id, "effectBasePoints", true),
        triple(id, "effectBaseDice")
    return scalar(id, "attributes") == 384
        and scalar(id, "procChance") == 101
        and scalar(id, "rangeIndex") == 1
        and equal(triple(id, "effect"), 30, 0, 0)
        and equal(dice, 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectMiscValue"), B.RAGE, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
        and points and (points[1] + dice[1]) / 10 == spec.bonusRage
end

local function hasteTopology(rank)
    local spec, id = B.RANKS[rank], B.RANKS[rank].hasteSpellId
    local points, dice = triple(id, "effectBasePoints", true),
        triple(id, "effectBaseDice")
    return scalar(id, "attributes") == 0
        and scalar(id, "procFlags") == 4
        and scalar(id, "procChance") == 100
        and scalar(id, "durationIndex") == spec.hasteDurationIndex
        and duration(id) == spec.hasteDuration
        and scalar(id, "rangeIndex") == 1
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectDieSides"), 1, 0, 0)
        and equal(dice, 1, 0, 0)
        and points and points[1] + dice[1] == spec.hastePercent
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 138, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function enrageTopology()
    local id = B.ENRAGE_ID
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, id, 1)
        duration = ok and integer(value, 0, 60000) or nil
    end
    return scalar(id, "attributes") == 262416
        and scalar(id, "stances") == B.BEAR_MASK
        and scalar(id, "recoveryTime") == 60000
        and scalar(id, "durationIndex") == 1 and duration == 10000
        and scalar(id, "powerType", true) == B.RAGE
        and scalar(id, "spellFamilyName") == B.DRUID_FAMILY
        and scalar(id, "spellFamilyFlags") == 524288
        and equal(triple(id, "effect"), 6, 3, 6)
        and equal(triple(id, "effectDieSides"), 1, 1, 0)
        and equal(triple(id, "effectBasePoints", true), 19, -76, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 1)
        and equal(triple(id, "effectApplyAuraName"), 24, 0, 94)
        and equal(triple(id, "effectAmplitude"), 1000, 0, 0)
        and equal(triple(id, "effectMiscValue"), B.RAGE, 0, 0)
end

local function profile(rank)
    if CACHE[rank] ~= nil then
        return CACHE[rank].valid and copy(CACHE[rank]) or nil
    end
    local spec = B.RANKS[rank]
    local valid = spec and talentTopology(rank)
        and triggerTopology(rank) and hasteTopology(rank)
        and enrageTopology()
    CACHE[rank] = valid and { available = true, valid = true, exact = true,
        rank = rank, talentID = B.TALENT_ID,
        talentSpellId = spec.talentSpellId,
        triggerSpellId = spec.triggerSpellId,
        hasteSpellId = spec.hasteSpellId, enrageSpellId = B.ENRAGE_ID,
        bonusRage = spec.bonusRage, powerType = B.RAGE,
        hastePercent = spec.hastePercent,
        hasteDuration = spec.hasteDuration,
        bearMask = B.BEAR_MASK,
        source = "installed Octo Talent.dbc and patch-5 Spell.dbc topology" }
        or { valid = false }
    return valid and copy(CACHE[rank]) or nil
end

local function activeHaste(spellId, maximum)
    if type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function"
        or type(GetPlayerBuffTimeLeft) ~= "function" then return nil, false end
    local index
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil, false end
        if slot and slot ~= -1 then
            local idOK, id = pcall(GetPlayerBuffID, slot)
            if not idOK then return nil, false end
            if tonumber(id) == spellId then
                local timeOK, remaining = pcall(GetPlayerBuffTimeLeft, slot)
                remaining = timeOK and tonumber(remaining) or nil
                if not remaining or remaining < 0 or remaining > maximum + 0.25 then
                    return nil, false
                end
                return remaining, true
            end
        end
    end
    return nil, true
end
local function druid()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "DRUID"
end

function B:Snapshot()
    local out = { available = false, exact = false,
        talentID = self.TALENT_ID, source = "installed Octo Blood Frenzy" }
    if not druid() then
        out.reason = "player is not an exactly identified Druid"; return out
    end
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function"
        or type(GetTalentSpellID) ~= "function" then
        out.reason = "Blood Frenzy talent evidence unavailable"; return out
    end
    local okID, id = pcall(GetTalentIDByIndex,
        self.FERAL_TAB, self.TALENT_INDEX)
    if not okID or id ~= self.TALENT_ID then
        out.reason = "Blood Frenzy talent identity mismatch"; return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        self.FERAL_TAB, self.TALENT_INDEX)
    rank, maximum = ok and integer(rank, 0, 2) or nil,
        ok and integer(maximum, 1, 2) or nil
    if rank == nil or maximum ~= 2 then
        out.reason = "Blood Frenzy rank evidence unavailable"; return out
    elseif rank == 0 then
        out.available, out.exact, out.rank, out.bonusRage =
            true, true, 0, 0
        return out
    end
    local okSpell, spellId = pcall(GetTalentSpellID,
        self.FERAL_TAB, self.TALENT_INDEX, rank)
    local found = okSpell and spellId == self.RANKS[rank].talentSpellId
        and profile(rank) or nil
    if found then return found end
    out.reason = "Blood Frenzy installed topology unavailable"
    return out
end

function B:CaptureFacts(action, facts)
    if not (action and tonumber(action.spellId) == self.ENRAGE_ID) then
        return facts
    end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local found = self:Snapshot()
    out.druidBloodFrenzyEnrage = true
    out.druidBloodFrenzyEvidence = found
    if not (found.available and found.exact) then
        out.requiresExactDruidBloodFrenzy = true
    end
    return out
end

function B:HasteSnapshot()
    local found = self:Snapshot()
    if not (found and found.available == true and found.exact == true) then
        return { available = false, exact = false,
            reason = found and found.reason or "Blood Frenzy unavailable" }
    end
    if found.rank == 0 then
        return { available = true, exact = true, active = false, rank = 0 }
    end
    local remaining, observed = activeHaste(
        found.hasteSpellId, found.hasteDuration)
    if not observed then return { available = false, exact = false,
        reason = "Blood Frenzy haste aura evidence unavailable" } end
    return { available = true, exact = true, rank = found.rank,
        active = remaining ~= nil and remaining > 0,
        remaining = remaining, profile = found }
end

function B:Invalidate() CACHE = {} end
