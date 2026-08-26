-- Exact Cat Form all-school threat consequence. Installed build-5875 passive
-- 3025 carries the threat aura, and the server's shapeshift boost map attaches
-- that passive only to form ID 1. This leaf describes mechanics, not strategy.
XelAssist.Game.Player.DruidCatThreat = {}
local C = XelAssist.Game.Player.DruidCatThreat

C.PASSIVE_ID = 3025
C.DRUID_FAMILY = 7
C.CAT_FORM = 1
C.ALL_SCHOOLS = 127
C.THREAT_AURA = 10
-- The installed negative payload is -30 base points plus one base die. The
-- VMaNGOS aura path evaluates that deterministic row to -29, not -30.
C.THREAT_PERCENT = -29
C.THREAT_MULTIPLIER = 0.71

local PROFILE_CACHE = nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, C.PASSIVE_ID, field)
    return ok and finite(value) or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, C.PASSIVE_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function scalarsMatch()
    return scalar("school") == 3
        and scalar("category") == 0 and scalar("mechanic") == 0
        and scalar("attributes") == 208
        and scalar("attributesEx") == 0
        and scalar("attributesEx2") == 0
        and scalar("attributesEx3") == 0
        and scalar("attributesEx4") == 0
        and scalar("stances") == 1 and scalar("stancesNot") == 0
        and scalar("targets") == 0 and scalar("castingTimeIndex") == 1
        and scalar("procFlags") == 0 and scalar("procChance") == 101
        and scalar("procCharges") == 0 and scalar("baseLevel") == 20
        and scalar("spellLevel") == 20 and scalar("durationIndex") == 21
        and scalar("powerType") == 0 and scalar("manaCost") == 0
        and scalar("rangeIndex") == 1
        and scalar("startRecoveryCategory") == 0
        and scalar("startRecoveryTime") == 0
        and scalar("spellFamilyName") == C.DRUID_FAMILY
        and scalar("spellFamilyFlags") == 134217728
        and scalar("dmgClass") == 0 and scalar("preventionType") == 0
end

local function arraysMatch()
    return equal(triple("effect"), 6, 6, 0)
        and equal(triple("effectDieSides"), 1, 1, 0)
        and equal(triple("effectBaseDice"), 1, 1, 0)
        and equal(triple("effectDicePerLevel"), 0, 0, 0)
        and equal(triple("effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple("effectBasePoints"), 39, -30, 0)
        and equal(triple("effectMechanic"), 0, 0, 0)
        and equal(triple("effectImplicitTargetA"), 1, 1, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectRadiusIndex"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"), 99, C.THREAT_AURA, 0)
        and equal(triple("effectAmplitude"), 0, 0, 0)
        and equal(triple("effectMultipleValue"), 0, 0, 0)
        and equal(triple("effectChainTarget"), 0, 0, 0)
        and equal(triple("effectItemType"), 0, 0, 0)
        and equal(triple("effectMiscValue"), 0, C.ALL_SCHOOLS, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
        and equal(triple("effectPointsPerComboPoint"), 0, 0, 0)
end

local function installedProfile()
    if PROFILE_CACHE then return copy(PROFILE_CACHE) end
    if not (scalarsMatch() and arraysMatch()) then
        return nil, "Cat all-school threat passive topology is incomplete"
    end
    local points, dice = triple("effectBasePoints"),
        triple("effectBaseDice")
    local percent = points and dice and points[2] + dice[2] or nil
    if percent ~= C.THREAT_PERCENT then
        return nil, "Cat threat modifier is outside its exact profile"
    end
    local out = { available = true, valid = true, exact = true,
        passiveSpellId = C.PASSIVE_ID, family = C.DRUID_FAMILY,
        catForm = C.CAT_FORM, schoolMask = C.ALL_SCHOOLS,
        percent = percent, multiplier = (100 + percent) / 100,
        source = "installed build-5875 passive plus server shapeshift boost map" }
    PROFILE_CACHE = copy(out)
    return copy(out)
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

function C:Snapshot()
    if classToken() ~= "DRUID" then
        return { available = false, valid = false, exact = false,
            reason = "player is not an exactly identified Druid" }
    end
    local found, reason = installedProfile()
    if found then return found end
    return { available = false, valid = false, exact = false,
        reason = reason, source = "installed build-5875 Cat threat passive" }
end

function C:Profile()
    return installedProfile()
end

function C:IsCatForm(formID)
    return integer(formID, 0, 32) == self.CAT_FORM
end

function C:Invalidate()
    PROFILE_CACHE = nil
end
