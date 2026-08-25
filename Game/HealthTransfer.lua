-- Installed-client semantics for health-funded companion channels.  The DBC
-- keeps the initial health payment, per-second upkeep and periodic pet heal in
-- separate fields; treating manaCost as mana or the heal as caster damage is
-- incorrect for Health Funnel.
XelAssist.Game.HealthTransfer = {}
local H = XelAssist.Game.HealthTransfer

local APPLY_AURA = 6
local PERIODIC_HEAL = 8
local TARGET_SELF = 1
local TARGET_PET = 5
local MOD_HEALTH_REGEN_PERCENT = 88
local POWER_HEALTH = -2
local HEALTH_FUNNEL_ATTRIBUTE = 2048
local CAST_RANKS = { [755] = true, [3698] = true, [3699] = true,
    [3700] = true, [11693] = true, [11694] = true, [11695] = true }

local function castRank(spellId)
    return CAST_RANKS[tonumber(spellId)] == true
end

local function signed32(value)
    value = tonumber(value)
    if not value then return nil end
    if value > 2147483647 then return value - 4294967296 end
    return value
end

local function flagSet(value, flag)
    value = math.max(0, tonumber(value) or 0)
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function liveScalar(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if ok then return value end
    return nil
end

local function liveArray(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if ok and type(value) == "table" then return value end
    return nil
end

local function funnelEffect(arrays)
    local i
    for i = 1, math.max(table.getn(arrays.effects or {}),
        table.getn(arrays.auras or {})) do
        if tonumber(arrays.effects[i]) == APPLY_AURA
            and tonumber(arrays.auras[i]) == PERIODIC_HEAL
            and tonumber(arrays.targets[i]) == TARGET_PET then
            return i
        end
    end
    return nil
end

local function suppressesNaturalRegen(arrays)
    local i
    for i = 1, math.max(table.getn(arrays.effects or {}),
        table.getn(arrays.auras or {})) do
        if tonumber(arrays.effects[i]) == APPLY_AURA
            and tonumber(arrays.auras[i]) == MOD_HEALTH_REGEN_PERCENT
            and tonumber(arrays.targets[i]) == TARGET_SELF
            and (tonumber(arrays.points[i]) or 0) + 1 == -100 then
            return true
        end
    end
    return false
end

local function arrays(readArray)
    return {
        effects = readArray("effect"),
        auras = readArray("effectApplyAuraName"),
        targets = readArray("effectImplicitTargetA"),
        points = readArray("effectBasePoints"),
        dice = readArray("effectBaseDice"),
        sides = readArray("effectDieSides"),
        diceLevel = readArray("effectDicePerLevel"),
        pointsLevel = readArray("effectRealPointsPerLevel"),
        amplitudes = readArray("effectAmplitude"),
    }
end

local function signature(readScalar, readArray)
    local found = arrays(readArray)
    if type(found.effects) ~= "table" or type(found.auras) ~= "table"
        or type(found.targets) ~= "table" or type(found.points) ~= "table"
        or type(found.dice) ~= "table" or type(found.sides) ~= "table"
        or type(found.diceLevel) ~= "table"
        or type(found.pointsLevel) ~= "table"
        or type(found.amplitudes) ~= "table" then return nil end
    local index = funnelEffect(found)
    if not index or signed32(readScalar("powerType")) ~= POWER_HEALTH
        or not flagSet(readScalar("attributesEx2"), HEALTH_FUNNEL_ATTRIBUTE)
        or not suppressesNaturalRegen(found) then return nil end
    return found, index
end

local function scaledLevels(action, readScalar)
    local actor = UnitLevel and tonumber(UnitLevel(
        action and action.actor == "pet" and "pet" or "player")) or nil
    local spell = tonumber(readScalar("spellLevel"))
    local base = tonumber(readScalar("baseLevel"))
    local maximum = tonumber(readScalar("maxLevel"))
    if not (actor and spell and base and maximum) then return nil end
    local level = math.max(base, actor)
    if maximum > 0 then level = math.min(level, maximum) end
    return math.max(0, level - spell)
end

local function meanMagnitude(index, found, levels)
    local points = tonumber(found.points[index])
    local dice = tonumber(found.dice[index])
    local sides = tonumber(found.sides[index])
    local diceLevel = tonumber(found.diceLevel[index])
    local pointsLevel = tonumber(found.pointsLevel[index])
    if points == nil or dice == nil or sides == nil
        or diceLevel == nil or pointsLevel == nil then return nil end
    sides = sides + diceLevel * levels
    local roll = sides > 1 and (dice + sides) / 2 or dice
    return math.max(0, points + pointsLevel * levels + roll)
end

local function exactTicks(duration, interval)
    if not (duration and duration > 0 and interval and interval > 0) then
        return nil
    end
    local covered, ticks = 0, 0
    while covered + interval <= duration + 0.0001 do
        covered, ticks = covered + interval, ticks + 1
    end
    if ticks <= 0 or math.abs(covered - duration) > 0.0001 then return nil end
    return ticks
end

function H:InferDBC(spellId)
    -- Same-name teaching wrappers and the NPC spell 16569 are not castable
    -- player ranks. The explicit installed-client IDs exclude both families.
    if not castRank(spellId) then return nil end
    local function scalar(field) return liveScalar(spellId, field) end
    local function array(field) return liveArray(spellId, field) end
    local found = signature(scalar, array)
    if not found then return nil end
    return { kind = "petHeal", pet = true, fixedTarget = "pet",
        channel = true, duration = 10, channelTicks = 10,
        healthFundedChannel = true, movementInterrupts = true,
        actionInterrupts = true, healingThreatActor = "player",
        dbcHealthTransfer = true }
end

function H:Apply(action, out, readScalar, readArray)
    if not (action and action.facts and action.facts.healthFundedChannel
        and castRank(action.spellId) and out and readScalar and readArray) then
        return nil
    end
    local found, index = signature(readScalar, readArray)
    local levels = found and scaledLevels(action, readScalar) or nil
    local duration = tonumber(out.duration)
        or tonumber(action.facts.duration)
    local amplitude = found and tonumber(found.amplitudes[index]) or nil
    local interval = amplitude and amplitude / 1000 or nil
    local ticks = exactTicks(duration, interval)
    local heal = levels ~= nil and meanMagnitude(index, found, levels) or nil
    local initial = tonumber(readScalar("manaCost"))
    local upkeep = tonumber(readScalar("manaPerSecond"))
    if initial ~= nil then initial = math.max(0, initial) end
    if upkeep ~= nil then upkeep = math.max(0, upkeep) end
    if not (found and heal and heal > 0 and ticks and initial ~= nil
        and upkeep > 0) then return nil end

    out.cost, out.costSource = 0, "client DBC health power"
    out.healthTransfer = { initialHealthCost = initial,
        periodicHealthCost = upkeep, healPerTick = heal,
        interval = interval, ticks = ticks, duration = duration,
        totalHealing = heal * ticks,
        totalHealthCost = initial + upkeep * ticks,
        exact = true,
        source = "installed-client Spell.dbc health funnel" }
    out.healthTransferExact = true
    return out.healthTransfer
end
