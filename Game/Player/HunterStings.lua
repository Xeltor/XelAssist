-- Numeric Hunter Sting ownership. Build-5875 and VMaNGOS classify every
-- Hunter-family poison-dispel spell as one per caster/target. Serpent's direct
-- periodic shape is supported; resource drains, mitigation and delayed-control
-- Stings fail closed instead of falling through localized generic knowledge.
XelAssist.Game.Player.HunterStings = {}
local S = XelAssist.Game.Player.HunterStings

S.HUNTER_FAMILY, S.POISON_DISPEL = 9, 4
S.SERPENT_FLAG, S.FAMILY = 16384, "hunterSting"
S.NATURE, S.MANA, S.PERIOD, S.DURATION = 3, 0, 3, 15
S.MAX_CACHE = 256
local CACHE, CACHE_COUNT = {}, 0

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
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function scalar(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        9007199254740991) or nil
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
local function hunter()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "HUNTER"
end

local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, id, 1)
    return ok and integer(value, 1, 3600000) or nil
end
local function serpent(id)
    return scalar(id, "school") == S.NATURE
        and scalar(id, "attributes") == 65538
        and scalar(id, "attributesEx2") == 131072
        and scalar(id, "durationIndex") == 8
        and duration(id) == S.DURATION * 1000
        and scalar(id, "powerType", true) == S.MANA
        and scalar(id, "rangeIndex") == 114
        and scalar(id, "spellFamilyFlags") == S.SERPENT_FLAG
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectDieSides"), 1, 0, 0)
        and equal(triple(id, "effectBaseDice"), 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 3, 0, 0)
        and equal(triple(id, "effectAmplitude"), 3000, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function classify(id)
    id = integer(id, 1, 4294967295)
    if not id then return nil end
    if CACHE[id] then return copy(CACHE[id]) end
    local family, dispel = scalar(id, "spellFamilyName"),
        scalar(id, "dispel")
    if family == nil or dispel == nil then return nil end
    local sting = family == S.HUNTER_FAMILY and dispel == S.POISON_DISPEL
    local out = { recognized = sting, exact = sting, spellId = id,
        family = family, dispel = dispel, exclusiveFamily = S.FAMILY,
        supported = sting and serpent(id) or false,
        source = "installed Octo DBC plus VMaNGOS e5f3fd0 SpellSpecific" }
    if sting and not out.supported then
        out.reason = "Hunter Sting downstream consequence is not fully modeled"
    end
    if CACHE_COUNT < S.MAX_CACHE then
        CACHE[id], CACHE_COUNT = copy(out), CACHE_COUNT + 1
    end
    return copy(out)
end

local function supportedFacts(found)
    return { inferred = true, kind = "dot", kindExact = true,
        ranged = true, weaponRanged = true, ammunition = true,
        hunterSting = true, hunterSerpentSting = true,
        exclusiveFamily = S.FAMILY, requiresExactUsability = true,
        submissionGuarded = true, runtimeUnverified = true,
        hunterStingEvidence = found, source = found.source }
end
local function blockedFacts(found)
    return { inferred = true, kind = "debuff", kindExact = false,
        ranged = true, weaponRanged = true, ammunition = true,
        hunterSting = true, exclusiveFamily = S.FAMILY,
        unmodeledUnsafe = found.reason,
        requiresHunterStingEvidence = true,
        hunterStingEvidence = found, source = found.source }
end

function S:InferKnowledge(spellId)
    local found = classify(spellId)
    if not (found and found.recognized) then
        return nil, "not an installed Hunter Sting", false
    elseif not hunter() then
        return nil, "player is not an exactly identified Hunter", false
    elseif found.supported then return supportedFacts(found), nil, true end
    return blockedFacts(found), found.reason, true
end

function S:CaptureFacts(action, facts)
    local found = classify(action and action.spellId)
    if not (found and found.recognized) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.hunterSting, out.exclusiveFamily = true, self.FAMILY
    out.hunterStingEvidence = found
    if found.supported then out.hunterSerpentSting = true
    else
        out.requiresHunterStingEvidence = true
        out.unmodeledUnsafe = found.reason
    end
    return out
end

-- Root target-aura capture may use this to tag observed own Stings so a new
-- delivered Sting replaces them through the generic exclusive-family owner.
function S:ObservedFamily(spellId)
    local found = classify(spellId)
    if found and found.recognized then return self.FAMILY, found end
    return nil
end

function S:Invalidate() CACHE, CACHE_COUNT = {}, 0 end
