-- Exact Soul Link talent/effect evidence from the installed build-5875 DBC.
-- Mutable spell knowledge is sampled only at the graph root. Descendants use
-- the sealed numeric profile and the retained controlled-demon state.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarlockSoulLink = {}
local S = XelAssist.Game.Player.WarlockSoulLink

S.TALENT_SPELL_ID = 19028
S.EFFECT_SPELL_ID = 25228
S.WARLOCK_FAMILY = 5
S.ALL_SCHOOLS_MASK = 127
S.DAMAGE_PERCENT_AURA = 79
S.SPLIT_DAMAGE_PERCENT_AURA = 81

local PROFILE_CACHE = nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
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

local function field(spellId, name)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, name)
    return ok and value or nil
end

local function numberField(spellId, name)
    return finite(field(spellId, name))
end

local function triple(spellId, name)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, name, 1)
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

local function talentScalarTopology()
    local id = S.TALENT_SPELL_ID
    return numberField(id, "school") == 5
        and numberField(id, "attributes") == 336
        and numberField(id, "attributesEx") == 268435456
        and numberField(id, "attributesEx2") == 0
        and numberField(id, "attributesEx3") == 0
        and numberField(id, "attributesEx4") == 0
        and numberField(id, "durationIndex") == 21
        and numberField(id, "baseLevel") == 40
        and numberField(id, "spellLevel") == 40
        and numberField(id, "powerType") == 0
        and numberField(id, "manaCost") == 0
        and numberField(id, "rangeIndex") == 1
        and numberField(id, "spellFamilyName") == S.WARLOCK_FAMILY
end

local function talentEffectTopology()
    local id = S.TALENT_SPELL_ID
    return equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 4, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function linkedDescription()
    local description = field(S.TALENT_SPELL_ID, "description")
    if type(description) ~= "string" then return false end
    return string.find(description, "$25228s1", 1, true) ~= nil
        and string.find(description, "$25228s2", 1, true) ~= nil
end

local function effectScalarTopology()
    local id = S.EFFECT_SPELL_ID
    return numberField(id, "school") == 5
        and numberField(id, "attributes") == 537198656
        and numberField(id, "attributesEx") == 0
        and numberField(id, "attributesEx2") == 0
        and numberField(id, "attributesEx3") == 1048576
        and numberField(id, "attributesEx4") == 0
        and numberField(id, "durationIndex") == 21
        and numberField(id, "baseLevel") == 40
        and numberField(id, "spellLevel") == 40
        and numberField(id, "powerType") == 0
        and numberField(id, "manaCost") == 0
        and numberField(id, "rangeIndex") == 1
        and numberField(id, "targetCreatureType") == 4
        and numberField(id, "spellFamilyName") == S.WARLOCK_FAMILY
end

local function effectTopology()
    local id = S.EFFECT_SPELL_ID
    local effects = triple(id, "effect")
    local auras = triple(id, "effectApplyAuraName")
    local points = triple(id, "effectBasePoints")
    local dice = triple(id, "effectBaseDice")
    local targetsA = triple(id, "effectImplicitTargetA")
    local targetsB = triple(id, "effectImplicitTargetB")
    local misc = triple(id, "effectMiscValue")
    local multiple = triple(id, "effectMultipleValue")
    if not (equal(effects, 119, 119, 0)
        and equal(auras, S.DAMAGE_PERCENT_AURA,
            S.SPLIT_DAMAGE_PERCENT_AURA, 0)
        and equal(points, 4, 19, 0) and equal(dice, 1, 1, 0)
        and equal(targetsA, 1, 1, 0) and equal(targetsB, 0, 0, 0)
        and equal(misc, S.ALL_SCHOOLS_MASK, S.ALL_SCHOOLS_MASK, 0)
        and equal(multiple, 0, 1, 0)) then return nil end
    local damagePercent = points[1] + dice[1]
    local splitPercent = points[2] + dice[2]
    if damagePercent ~= 5 or splitPercent ~= 20 then return nil end
    return damagePercent, splitPercent
end

local function installedProfile()
    if PROFILE_CACHE then return copy(PROFILE_CACHE) end
    local damagePercent, splitPercent = effectTopology()
    if not (talentScalarTopology() and talentEffectTopology()
        and linkedDescription() and effectScalarTopology()
        and damagePercent and splitPercent) then
        return nil, "Soul Link DBC topology is incomplete"
    end
    local out = { available = true, exact = true,
        talentSpellId = S.TALENT_SPELL_ID,
        effectSpellId = S.EFFECT_SPELL_ID,
        family = S.WARLOCK_FAMILY,
        schoolMask = S.ALL_SCHOOLS_MASK,
        damagePercent = damagePercent,
        damageMultiplier = (100 + damagePercent) / 100,
        splitPercent = splitPercent,
        splitFraction = splitPercent / 100,
        source = "installed build-5875 Soul Link DBC topology" }
    PROFILE_CACHE = copy(out)
    return copy(out)
end

local function knownTalent()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "broad player spell knowledge API unavailable"
    end
    local ok, value = pcall(IsPlayerSpell, S.TALENT_SPELL_ID)
    if not ok or value ~= true and value ~= false
        and value ~= 1 and value ~= 0 then
        return nil, "Soul Link talent knowledge unavailable"
    end
    return value == true or value == 1
end

function S:Snapshot(knownClass)
    local token = knownClass
    if token == nil then token = classToken() end
    if token ~= "WARLOCK" then return nil end
    local profile, reason = installedProfile()
    if not profile then return { available = false, exact = false,
        reason = reason, source = "installed build-5875 Soul Link DBC" } end
    local learned, knowledgeReason = knownTalent()
    if learned == nil then
        profile.available, profile.exact = false, false
        profile.reason = knowledgeReason
        return profile
    end
    profile.learned, profile.talentKnown = learned, true
    return profile
end

function S:Evidence(subject)
    if type(subject) ~= "table" or subject.available ~= true
        or subject.exact ~= true or subject.talentKnown ~= true
        or type(subject.learned) ~= "boolean"
        or subject.talentSpellId ~= self.TALENT_SPELL_ID
        or subject.effectSpellId ~= self.EFFECT_SPELL_ID
        or subject.family ~= self.WARLOCK_FAMILY
        or subject.schoolMask ~= self.ALL_SCHOOLS_MASK
        or subject.damagePercent ~= 5 or subject.damageMultiplier ~= 1.05
        or subject.splitPercent ~= 20 or subject.splitFraction ~= 0.20 then
        return nil
    end
    return subject
end

function S:Invalidate()
    PROFILE_CACHE = nil
end
