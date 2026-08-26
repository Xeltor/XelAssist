-- Lay on Hands has an exact installed maximum-health heal, but its all-mana
-- drain is absent from the DBC cost fields. A generic zero-cost heal would be
-- resource-destructive, so numeric topology owns and withholds the action.
XelAssist.Game.Player.PaladinLayOnHands = {}
local L = XelAssist.Game.Player.PaladinLayOnHands

local UINT32_MAX = 4294967295
local INT32_MIN = -2147483648
local INT32_SIGN_BIT = 2147483648
local UINT32_SIZE = 4294967296

L.PALADIN_FAMILY = 10
L.FAMILY_FLAG = 32768
L.HOLY = 1
L.MANA = 0
L.MAX_HEALTH_HEAL = 67
L.ENERGIZE = 30
L.RANKS = {
    [633] = { rank = 1, level = 10, targetMana = 0 },
    [2800] = { rank = 2, level = 30, targetMana = 250 },
    [10310] = { rank = 3, level = 50, targetMana = 550 },
}
local CACHE = {}

local function integer(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value then return nil end
    if value < low or value > high then return nil end
    if math.floor(value) ~= value then return nil end
    return value
end
local function scalar(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    if not ok then return nil end
    local minimum = signed and INT32_MIN or 0
    value = integer(value, minimum, UINT32_MAX)
    if signed and value and value >= INT32_SIGN_BIT then
        value = value - UINT32_SIZE
    end
    return value
end
local function triple(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out = {}
    local count = 0
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    local minimum = signed and INT32_MIN or 0
    for index = 1, 3 do
        out[index] = integer(values[index], minimum, UINT32_MAX)
        if out[index] == nil then return nil end
        if signed and out[index] >= INT32_SIGN_BIT then
            out[index] = out[index] - UINT32_SIZE
        end
    end
    return out
end
local function equal(values, first, second, third)
    if not values then return false end
    return values[1] == first
        and values[2] == second
        and values[3] == third
end
local function paladin()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "PALADIN"
end
local function copy(source)
    local out = {}
    for key, value in pairs(source or {}) do
        out[key] = value
    end
    return out
end
local function scalars(id, rank)
    return scalar(id,"school")==L.HOLY and scalar(id,"category")==56
        and scalar(id,"attributes")==327680
        and scalar(id,"attributesEx")==131074
        and scalar(id,"attributesEx2")==0 and scalar(id,"attributesEx3")==0
        and scalar(id,"attributesEx4")==0
        and scalar(id,"castingTimeIndex")==1 and scalar(id,"recoveryTime")==0
        and scalar(id,"categoryRecoveryTime")==3600000
        and scalar(id,"baseLevel")==rank.level
        and scalar(id,"spellLevel")==rank.level
        and scalar(id,"durationIndex")==0 and scalar(id,"powerType")==L.MANA
        and scalar(id,"manaCost")==0 and scalar(id,"manaCostPerlevel")==0
        and scalar(id,"manaCostPercentage")==0 and scalar(id,"rangeIndex")==5
        and scalar(id,"equippedItemClass",true)==-1
        and scalar(id,"spellIconID")==79
        and scalar(id,"startRecoveryCategory")==133
        and scalar(id,"startRecoveryTime")==1500
        and scalar(id,"spellFamilyName")==L.PALADIN_FAMILY
        and scalar(id,"spellFamilyFlags")==L.FAMILY_FLAG
        and scalar(id,"maxAffectedTargets")==0 and scalar(id,"dmgClass")==1
        and scalar(id,"preventionType")==1
end
local function arrays(id, rank)
    local hasTargetMana = rank.targetMana > 0
    local manaPoint = hasTargetMana and rank.targetMana - 1 or 0
    local secondEffect = hasTargetMana and L.ENERGIZE or 0
    local secondDice = hasTargetMana and 1 or 0
    local secondTarget = hasTargetMana and 21 or 0
    return equal(triple(id, "effect"), L.MAX_HEALTH_HEAL, secondEffect, 0)
        and equal(triple(id, "effectDieSides"), 1, secondDice, 0)
        and equal(triple(id, "effectBaseDice"), 1, secondDice, 0)
        and equal(triple(id, "effectBasePoints", true), -1, manaPoint, 0)
        and equal(triple(id, "effectImplicitTargetA"), 0, 0, 0)
        and equal(triple(id, "effectImplicitTargetB"), 21, secondTarget, 0)
        and equal(triple(id, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(id, "effectMiscValue"), 0, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end
local function profile(id)
    id = integer(id, 1, UINT32_MAX)
    local rank = id and L.RANKS[id]
    if not rank then return nil end
    if CACHE[id] then return copy(CACHE[id]) end
    local valid = scalars(id, rank) and arrays(id, rank)
    local out = {
        recognized = true,
        valid = valid and true or false,
        exact = valid and true or false,
        spellId = id,
        rank = rank.rank,
        targetMana = rank.targetMana,
        maximumHealthHeal = true,
        privateAllManaDrain = true,
        source = "installed Octo patch-5 Lay on Hands topology",
    }
    out.reason = valid and "Lay on Hands private all-mana drain is unavailable"
        or "Lay on Hands installed topology is incomplete"
    CACHE[id] = copy(out)
    return out
end
function L:InferKnowledge(spellId)
    local found = profile(spellId)
    if not found then return nil, "not Lay on Hands", false end
    if not paladin() then
        return nil, "player is not an exactly identified Paladin", false
    end
    return nil, found.reason, true
end
function L:Profile(spellId)
    local found = profile(spellId)
    return found and copy(found) or nil
end
function L:Invalidate()
    CACHE = {}
end
