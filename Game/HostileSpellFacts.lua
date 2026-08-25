-- Conservative DBC consequences for hostile casts. Only one unambiguous,
-- direct, single-recipient damage or heal effect is accepted. This deliberately
-- refuses to interpret scripted, periodic, triggered or multi-effect spells.
XelAssist.Game.HostileSpellFacts = {}
local F = XelAssist.Game.HostileSpellFacts
local Topology = XelAssist.Game.SpellTopology

F.MAX_CACHE = 64

local function exactGuid(value)
    if value == nil then return nil end
    if type(value) == "string" then
        if value == "" or string.find(value, "^0+$")
            or string.find(value, "^0[xX]0+$") then return nil end
    end
    return value
end

local function scalar(spellId, field)
    if not GetSpellRecField then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if ok then return tonumber(value) end
    return nil
end

local function array(spellId, field)
    if not GetSpellRecField then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if ok and type(value) == "table" then return value end
    return nil
end

local function flagSet(value, flag)
    value = tonumber(value)
    if not value or value < 0 then return false end
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function anyNonzero(values)
    local index
    if type(values) ~= "table" then return nil end
    for index = 1, table.getn(values) do
        if (tonumber(values[index]) or 0) ~= 0 then return true end
    end
    return false
end

local function scaledLevels(spellId, casterLevel)
    casterLevel = tonumber(casterLevel)
    if not casterLevel or casterLevel <= 0 then return nil end
    casterLevel = math.floor(casterLevel)
    local spellLevel = scalar(spellId, "spellLevel")
    local baseLevel = scalar(spellId, "baseLevel")
    local maxLevel = scalar(spellId, "maxLevel")
    if spellLevel == nil or baseLevel == nil or maxLevel == nil then return nil end
    local level = math.max(baseLevel, casterLevel)
    if maxLevel > 0 then level = math.min(level, maxLevel) end
    return math.max(0, level - spellLevel), casterLevel
end

local function magnitude(spellId, index, levels)
    local points = array(spellId, "effectBasePoints")
    local dice = array(spellId, "effectBaseDice")
    local sides = array(spellId, "effectDieSides")
    local diceLevel = array(spellId, "effectDicePerLevel")
    local pointsLevel = array(spellId, "effectRealPointsPerLevel")
    if not (points and dice and sides and diceLevel and pointsLevel) then return nil end
    local base = tonumber(points[index]) or 0
    local low = tonumber(dice[index]) or 0
    local high = (tonumber(sides[index]) or 0)
        + (tonumber(diceLevel[index]) or 0) * levels
    local roll = high > 1 and (low + high) / 2 or low
    local mean = base + (tonumber(pointsLevel[index]) or 0) * levels + roll
    if mean <= 0 then return nil end
    return mean
end

local function targetMode(effect)
    if effect.shape ~= "single" or effect.maxTargets and effect.maxTargets > 1 then
        return nil
    end
    if effect.effect == 2 and effect.relation == "hostile"
        and effect.center == "target" then return "target", "damage" end
    if effect.effect ~= 10 then return nil end
    if effect.relation == "self" and effect.center == "caster" then
        return "self", "heal"
    end
    if effect.center == "target" and (effect.relation == "friendly"
        or effect.relation == "party" or effect.relation == "raid"
        or effect.relation == "pet") then return "target", "heal" end
    return nil
end

local function build(spellId, casterLevel)
    if not Topology or not Topology.Facts then
        return nil, "spell topology unavailable"
    end
    local topology = Topology:Facts(spellId)
    if not topology.available then return nil, "spell DBC unavailable" end
    if table.getn(topology.effects) ~= 1 then
        return nil, "spell has mixed or additional effects"
    end
    local effect = topology.effects[1]
    if effect.effect ~= 2 and effect.effect ~= 10 then
        return nil, "spell effect is not direct damage or healing"
    end
    if topology.area or topology.chain or topology.cone
        or effect.shape == "ground" then
        return nil, "spell recipient topology is not single-target"
    end
    local mode, kind = targetMode(effect)
    if not mode then return nil, "spell recipient relation is ambiguous" end

    local attributesEx = scalar(spellId, "attributesEx")
    if attributesEx == nil then return nil, "spell channel flags unavailable" end
    if flagSet(attributesEx, 4) or flagSet(attributesEx, 64) then
        return nil, "channeled spell"
    end
    local auras = array(spellId, "effectApplyAuraName")
    local triggers = array(spellId, "effectTriggerSpell")
    local amplitudes = array(spellId, "effectAmplitude")
    if auras == nil or triggers == nil or amplitudes == nil then
        return nil, "spell side-effect fields unavailable"
    end
    if anyNonzero(auras) then return nil, "spell applies an aura" end
    if anyNonzero(triggers) then return nil, "spell triggers another spell" end
    if anyNonzero(amplitudes) then return nil, "spell has periodic timing" end

    local levels, level = scaledLevels(spellId, casterLevel)
    if levels == nil then return nil, "caster level scaling unavailable" end
    local amount = magnitude(spellId, effect.index, levels)
    if not amount then return nil, "spell magnitude unavailable" end
    return { kind = kind, direct = true, singleTarget = true,
        targetMode = mode, effectIndex = effect.index, amount = amount,
        average = amount, estimated = true, magnitudeEstimated = true,
        casterLevel = level, school = scalar(spellId, "school"),
        source = "Octowow Spell.dbc direct-effect estimate" }
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function remember(owner, key, value)
    owner.cache, owner.cacheOrder = owner.cache or {}, owner.cacheOrder or {}
    if not owner.cache[key] then
        if table.getn(owner.cacheOrder) >= owner.MAX_CACHE then
            local oldest = table.remove(owner.cacheOrder, 1)
            owner.cache[oldest] = nil
        end
        table.insert(owner.cacheOrder, key)
    end
    owner.cache[key] = value
end

function F:ForCast(cast, casterLevel)
    if type(cast) ~= "table" then return nil, "cast evidence unavailable" end
    local casterGuid = exactGuid(cast.casterGuid)
    local targetGuid = exactGuid(cast.targetGuid)
    if casterGuid == nil then return nil, "caster identity unavailable" end
    if targetGuid == nil then return nil, "target identity unavailable" end
    if cast.channel then return nil, "channeled cast" end
    local spellId = tonumber(cast.spellId)
    if not spellId or spellId <= 0 then return nil, "spell identity unavailable" end
    casterLevel = casterLevel or cast.casterLevel
    self.cache = self.cache or {}
    local cacheKey = tostring(spellId) .. ":" .. tostring(casterLevel)
    local cached = self.cache[cacheKey]
    if not cached then
        local facts, reason = build(spellId, casterLevel)
        cached = { facts = facts, reason = reason }
        remember(self, cacheKey, cached)
    end
    if not cached.facts then return nil, cached.reason end
    if cached.facts.targetMode == "self" and casterGuid ~= targetGuid then
        return nil, "self-only spell target does not match caster"
    end
    local out = copy(cached.facts)
    out.spellId, out.casterGuid, out.targetGuid = spellId, casterGuid, targetGuid
    return out
end

function F:Invalidate()
    self.cache = nil
    self.cacheOrder = nil
end
