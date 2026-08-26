-- Exact Octo Soul Fire ranks added by patch-5. Their direct Fire packet stays
-- owned by the generic DBC power reader; this identity owner proves that the
-- cast consumes exactly one Soul Shard and cannot fall through as free damage.
XelAssist.Game.Player.WarlockSoulFire = {}
local S = XelAssist.Game.Player.WarlockSoulFire

S.WARLOCK_FAMILY, S.SOUL_SHARD = 5, 6265
S.RANKS = {
    [51683] = { mana = 305, base = 623, sides = 161,
        level = 46, maxLevel = 52 },
    [51684] = { mana = 335, base = 703, sides = 179,
        level = 54, maxLevel = 60 },
}
local CACHE = {}

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and type(value) == "number" and value or nil
end

local function array(spellId, field, length)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, index = {}, 0, nil
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > length
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= length then return nil end
    for index = 1, length do
        if type(values[index]) ~= "number" then return nil end
        out[index] = values[index]
    end
    return out
end

local function triple(spellId, field, a, b, c)
    local values = array(spellId, field, 3)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function reagentShape(spellId)
    local reagents, counts = array(spellId, "reagent", 8),
        array(spellId, "reagentCount", 8)
    if not (reagents and counts and reagents[1] == S.SOUL_SHARD
        and counts[1] == 1) then return false end
    local index
    for index = 2, 8 do
        if reagents[index] ~= 0 or counts[index] ~= 0 then return false end
    end
    return true
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function classify(spellId)
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local rank = S.RANKS[spellId]
    if not rank then return nil end
    local points, dice, sides = array(spellId, "effectBasePoints", 3),
        array(spellId, "effectBaseDice", 3),
        array(spellId, "effectDieSides", 3)
    local found = { recognized = true, valid = false, exact = false,
        spellId = spellId, shardItemId = S.SOUL_SHARD, shardCount = 1,
        source = "installed Octo patch-5 Soul Fire direct/reagent topology" }
    if not (scalar(spellId, "spellFamilyName") == S.WARLOCK_FAMILY
        and scalar(spellId, "school") == 2
        and scalar(spellId, "category") == 631
        and scalar(spellId, "castingTimeIndex") == 171
        and scalar(spellId, "categoryRecoveryTime") == 30000
        and scalar(spellId, "rangeIndex") == 4
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == rank.mana
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and triple(spellId, "effect", 2, 0, 0)
        and triple(spellId, "effectImplicitTargetA", 6, 0, 0)
        and triple(spellId, "effectTriggerSpell", 0, 0, 0)
        and points and dice and sides and points[1] + dice[1] == rank.base
        and dice[1] == 1 and sides[1] == rank.sides
        and points[2] == 0 and points[3] == 0
        and reagentShape(spellId)) then
        found.reason = "Octo Soul Fire DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found
    end
    found.valid, found.exact = true, true
    found.baseDamage, found.manaCost = rank.base, rank.mana
    CACHE[spellId] = copy(found)
    return found
end

function S:InferKnowledge(spellId)
    if classToken() ~= "WARLOCK" then return nil, nil, false end
    local found = classify(tonumber(spellId))
    if not found then return nil, nil, false end
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        ranged = true, reagent = true, reagentName = "Soul Shard",
        warlockSoulFire = true, soulFireEvidence = copy(found),
        source = found.source }, nil, true
end

function S:Invalidate() CACHE = {} end
