-- Exact Druid Prowl discovery from the installed build-5875 Spell.dbc.
-- Localized names and rank lists are deliberately absent: the Druid family
-- bit, Cat-form gate, self stealth aura and deterministic movement modifier
-- identify the action. Graph search consumes only the copied scalar facts.
XelAssist.Game.Player.DruidProwl = {}
local P = XelAssist.Game.Player.DruidProwl

P.DRUID_FAMILY = 7
P.PROWL_FAMILY_FLAG = 16384
P.CAT_FORM_MASK = 1
P.APPLY_AURA = 6
P.STEALTH_AURA = 16
P.MOVEMENT_AURA = 33
P.CANT_USE_IN_COMBAT = 268435456
P.INDEFINITE_DURATION_INDEX = 21
P.INSTALLED_AURA_INTERRUPT_FLAGS = 15367
P.ENERGY = 3
P.MAX_CACHE = 16

local CACHE, CACHE_COUNT = {}, 0

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
    return value
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok or type(value) ~= "number" then return nil end
    if signed and value >= 2147483648 then value = value - 4294967296 end
    return value
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
        if type(values[index]) ~= "number" then return nil end
        out[index] = values[index]
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function flagSet(value, flag)
    value = integer(value, 0, 4294967295)
    return value and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function remember(spellId, result)
    if CACHE_COUNT < P.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = result, CACHE_COUNT + 1
    end
    return result
end

local function inspect(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return { recognized = false } end
    if CACHE[spellId] then return CACHE[spellId] end

    local family = scalar(spellId, "spellFamilyName")
    local flags = scalar(spellId, "spellFamilyFlags")
    if family ~= P.DRUID_FAMILY or flags ~= P.PROWL_FAMILY_FLAG then
        -- Do not let unrelated spellbook rows consume the small exact-action
        -- cache before the owned Prowl ranks are encountered.
        return { recognized = false }
    end

    local found = { recognized = true, valid = false, spellId = spellId,
        source = "installed-client Druid Prowl DBC topology" }
    local effects = triple(spellId, "effect")
    local auras = triple(spellId, "effectApplyAuraName")
    local targetsA = triple(spellId, "effectImplicitTargetA")
    local targetsB = triple(spellId, "effectImplicitTargetB")
    local points = triple(spellId, "effectBasePoints")
    local dice = triple(spellId, "effectBaseDice")
    local sides = triple(spellId, "effectDieSides")
    local diceLevel = triple(spellId, "effectDicePerLevel")
    local pointsLevel = triple(spellId, "effectRealPointsPerLevel")
    local perCombo = triple(spellId, "effectPointsPerComboPoint")
    local attributes = scalar(spellId, "attributes")

    if not (equal(effects, P.APPLY_AURA, P.APPLY_AURA, 0)
        and equal(auras, P.STEALTH_AURA, P.MOVEMENT_AURA, 0)
        and equal(targetsA, 1, 1, 0) and equal(targetsB, 0, 0, 0)
        and points and dice and sides and diceLevel and pointsLevel and perCombo) then
        found.reason = "Prowl aura topology is incomplete"
        return remember(spellId, found)
    end
    if scalar(spellId, "stances") ~= P.CAT_FORM_MASK
        or scalar(spellId, "stancesNot") ~= 0
        or scalar(spellId, "powerType", true) ~= P.ENERGY
        or scalar(spellId, "manaCost") ~= 0 then
        found.reason = "Prowl form or resource evidence is incomplete"
        return remember(spellId, found)
    end
    if not flagSet(attributes, P.CANT_USE_IN_COMBAT)
        or scalar(spellId, "durationIndex") ~= P.INDEFINITE_DURATION_INDEX
        or scalar(spellId, "auraInterruptFlags")
            ~= P.INSTALLED_AURA_INTERRUPT_FLAGS then
        found.reason = "Prowl lifecycle evidence is incomplete"
        return remember(spellId, found)
    end
    if dice[2] ~= 1 or sides[2] ~= 1 or diceLevel[2] ~= 0
        or pointsLevel[2] ~= 0 or perCombo[2] ~= 0 then
        found.reason = "Prowl movement modifier is not deterministic"
        return remember(spellId, found)
    end
    local movementPercent = points[2] + dice[2]
    if movementPercent >= 0 or movementPercent <= -100 then
        found.reason = "Prowl movement modifier is outside its safe domain"
        return remember(spellId, found)
    end

    found.valid = true
    found.movementSpeedPercent = movementPercent
    found.movementSpeedMultiplier = (100 + movementPercent) / 100
    found.formMask = P.CAT_FORM_MASK
    found.indefinite = true
    found.auraInterruptFlags = P.INSTALLED_AURA_INTERRUPT_FLAGS
    return remember(spellId, found)
end

-- The third return follows ActionInference's recognized/fail-closed contract.
-- A changed Prowl-family row is handled with no facts so it cannot fall
-- through to localized tooltip inference as an ordinary generic buff.
function P:InferKnowledge(spellId)
    if classToken() ~= "DRUID" then return nil, nil, false end
    local evidence = inspect(spellId)
    if not evidence.recognized then return nil, nil, false end
    if evidence.valid ~= true then
        return nil, evidence.reason or "Prowl evidence unavailable", true
    end
    return { inferred = true, kind = "buff", self = true,
        outOfCombat = true, stealthPreparation = true,
        appliesStealth = true, druidProwl = true,
        movementSpeedMultiplier = evidence.movementSpeedMultiplier,
        druidProwlMovementPercent = evidence.movementSpeedPercent,
        druidProwlFormMask = evidence.formMask,
        persistentBuff = evidence.indefinite,
        source = evidence.source }, nil, true
end

function P:Evidence(spellId)
    local found = inspect(spellId)
    return copy(found)
end

function P:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
