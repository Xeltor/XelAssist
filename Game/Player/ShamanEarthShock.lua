-- Exact installed build-5875 Earth Shock evidence. Numeric rank topology
-- identifies the action; mutable caster modifiers and hostile cast flags are
-- sealed at the graph root so descendants never read live APIs.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.ShamanEarthShock = {}
local E = XelAssist.Game.Player.ShamanEarthShock

E.SHAMAN_FAMILY = 11
E.FAMILY_FLAG = 1048576
E.NATURE_SCHOOL = 3
E.INTERRUPT_DURATION = 2
E.ALL_EFFECTS_MOD = 8
E.DAMAGE_MOD = 0
E.BONUS_COEFFICIENT_MOD = 24
E.NORMAL_INTERRUPT_FLAG = 2
E.CHANNEL_INTERRUPT_FLAG = 4
E.MAX_CAST_CACHE = 256

E.RANKS = {
    [8042] = { maxLevel = 9, baseLevel = 4, spellLevel = 4,
        mana = 30, points = 16, sides = 3, perLevel = 0.5,
        coefficient = 0.154 },
    [8044] = { maxLevel = 13, baseLevel = 8, spellLevel = 8,
        mana = 50, points = 31, sides = 3, perLevel = 0.7,
        coefficient = 0.212 },
    [8045] = { maxLevel = 19, baseLevel = 14, spellLevel = 14,
        mana = 85, points = 59, sides = 5, perLevel = 1,
        coefficient = 0.299 },
    [8046] = { maxLevel = 29, baseLevel = 24, spellLevel = 24,
        mana = 145, points = 118, sides = 9, perLevel = 1.4,
        coefficient = 0.386 },
    [10412] = { maxLevel = 41, baseLevel = 36, spellLevel = 36,
        mana = 240, points = 224, sides = 15, perLevel = 2,
        coefficient = 0.386 },
    [10413] = { maxLevel = 53, baseLevel = 48, spellLevel = 48,
        mana = 345, points = 358, sides = 23, perLevel = 2.6,
        coefficient = 0.386 },
    [10414] = { maxLevel = 65, baseLevel = 60, spellLevel = 60,
        mana = 450, points = 516, sides = 29, perLevel = 3.1,
        coefficient = 0.386 },
}

local PROFILES, CASTS, CAST_COUNT = {}, {}, 0

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

local function signed32(value)
    value = integer(value, -2147483648, 4294967295)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function identityField(field)
    if type(field) ~= "string" then return false end
    field = string.lower(field)
    return field == "key" or string.sub(field, -3) == "key"
        or string.sub(field, -4) == "guid"
end

local function copy(source, field)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and not identityField(key)
            and copy(value, key) or value
    end
    return out
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    return signed and signed32(value)
        or finite(value, -2147483648, 137438953471)
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
        out[index] = signed and signed32(values[index])
            or finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function near(first, second)
    return first ~= nil and math.abs(first - second) <= 0.00001
end

local function hasFlag(value, flag)
    value = integer(value, 0, 4294967295)
    return value and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function topology(spellId, rank)
    local levels = triple(spellId, "effectRealPointsPerLevel")
    local coefficients = triple(spellId, "effectBonusCoefficient")
    return scalar(spellId, "school") == E.NATURE_SCHOOL
        and scalar(spellId, "category") == 19
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 512
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 6000
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "baseLevel") == rank.baseLevel
        and scalar(spellId, "spellLevel") == rank.spellLevel
        and scalar(spellId, "durationIndex") == 39
        and scalar(spellId, "powerType", true) == 0
        and scalar(spellId, "manaCost") == rank.mana
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "rangeIndex") == 3
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == E.SHAMAN_FAMILY
        and scalar(spellId, "spellFamilyFlags") == E.FAMILY_FLAG
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
        and equal(triple(spellId, "effect"), 2, 68, 0)
        and equal(triple(spellId, "effectDieSides", true), rank.sides, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and levels and near(levels[1], rank.perLevel)
        and levels[2] == 0 and levels[3] == 0
        and coefficients and near(coefficients[1], rank.coefficient)
        and coefficients[2] == 0 and coefficients[3] == 0
        and equal(triple(spellId, "effectBasePoints", true), rank.points, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 26, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 6, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
end

local function profile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    local rank = spellId and E.RANKS[spellId]
    if not rank then return nil, "spell is not an Earth Shock rank", false end
    local cached = PROFILES[spellId]
    if cached then return cached.valid and copy(cached) or nil,
        cached.reason, true end
    local valid = topology(spellId, rank)
    cached = copy(rank)
    cached.spellId, cached.valid, cached.exact = spellId, valid, valid
    cached.recognized, cached.school = true, E.NATURE_SCHOOL
    cached.interruptDuration = E.INTERRUPT_DURATION
    cached.source = "installed build-5875 Earth Shock DBC and VMaNGOS effect"
    if not valid then cached.reason = "Earth Shock DBC topology is incomplete" end
    PROFILES[spellId] = copy(cached)
    return valid and copy(cached) or nil, cached.reason, true
end

local function modifier(spellId, operation)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(GetSpellModifiers, spellId, operation)
    flat, percent = ok and signed32(flat) or nil, ok and signed32(percent) or nil
    changed = ok and integer(changed, 0, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil
        or ((flat ~= 0 or percent ~= 0) ~= (changed ~= 0)) then return nil end
    return { operation = operation, flat = flat, percent = percent,
        changed = changed, exact = true }
end

local function playerLevel(state)
    local level = state and state.actors and state.actors.player
        and state.actors.player.level
    if not level and type(UnitLevel) == "function" then
        local ok, found = pcall(UnitLevel, "player")
        if ok then level = found end
    end
    return integer(level, 1, 255)
end

local function naturePower()
    if type(GetSpellPower) ~= "function" then return nil end
    local ok, _, _, _, nature = pcall(GetSpellPower)
    return ok and finite(nature, -1000000, 1000000) or nil
end

local function auraSpellId(value)
    value = integer(value, -65535, 4294967295)
    if value and value < -1 then value = value + 65536 end
    return integer(value, 1, 4294967295)
end

local OUTGOING_AURA = { [59] = true, [79] = true, [112] = true,
    [168] = true, [180] = true }

-- These server aura lanes depend on the hostile creature or multiply the
-- whole hit outside SpellMod. Their magnitude cannot be recovered from
-- GetSpellPower/GetSpellModifiers, so an active one makes exact raw power
-- unavailable instead of being silently approximated.
local function outgoingLaneSafe()
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        return nil
    end
    local filters, filterIndex, auraIndex = { "HELPFUL", "HARMFUL" }, nil, nil
    for filterIndex = 1, 2 do
        local ok, list = pcall(C_UnitAuras.GetUnitAuras,
            "player", filters[filterIndex])
        if not ok or type(list) ~= "table" or table.getn(list) > 64 then
            return nil
        end
        for auraIndex = 1, table.getn(list) do
            local aura = list[auraIndex]
            local spellId = type(aura) == "table" and auraSpellId(aura.spellId)
            local effects = spellId and triple(spellId, "effect")
            local names = spellId and triple(spellId, "effectApplyAuraName")
            if not (effects and names) then return nil end
            local effectIndex
            for effectIndex = 1, 3 do
                if effects[effectIndex] == 6
                    and OUTGOING_AURA[names[effectIndex]] then return nil end
            end
        end
    end
    return true
end

local function powerProfile(found, state)
    local level, all, damage, coefficient = playerLevel(state),
        modifier(found.spellId, E.ALL_EFFECTS_MOD),
        modifier(found.spellId, E.DAMAGE_MOD),
        modifier(found.spellId, E.BONUS_COEFFICIENT_MOD)
    local power = naturePower()
    local durationOK, durationMs = false, nil
    if type(GetSpellDuration) == "function" then
        durationOK, durationMs = pcall(GetSpellDuration, found.spellId)
    end
    durationMs = integer(durationMs, 1, 3600000)
    if not (level and all and damage and coefficient and power
        and outgoingLaneSafe()
        and durationMs == E.INTERRUPT_DURATION * 1000) then return nil end
    local scaled = math.min(found.maxLevel, math.max(found.baseLevel, level))
    local base = found.points + found.perLevel * (scaled - found.spellLevel)
        + (1 + found.sides) / 2
    base = (base + all.flat) * (100 + all.percent) / 100
    local bonus = (found.coefficient * 100 + coefficient.flat)
        * (100 + coefficient.percent) / 100 / 100
    local mean = (base + power * bonus + damage.flat)
        * (100 + damage.percent) / 100
    if not finite(mean, 0.0001, 100000000)
        or not finite(bonus, 0, 1000) then return nil end
    local out = copy(found)
    out.playerLevel, out.scaledLevel = level, scaled
    out.allEffectsModifier, out.damageModifier = all, damage
    out.bonusCoefficientModifier = coefficient
    out.natureSpellPower, out.effectiveBonusCoefficient = power, bonus
    out.rawNoncriticalMean, out.interruptDurationMs, out.complete =
        mean, durationMs, true
    out.source = out.source .. "; root-captured spell modifiers and Nature power"
    return out
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.shamanEarthShockEvidence
    local rank = found and E.RANKS[found.spellId]
    local level = found and integer(found.playerLevel, 1, 255)
    local scaled = level and math.min(rank and rank.maxLevel or 0,
        math.max(rank and rank.baseLevel or 0, level))
    local all, damage, coefficient = found and found.allEffectsModifier,
        found and found.damageModifier, found and found.bonusCoefficientModifier
    local function exactModifier(value, operation)
        return type(value) == "table" and value.exact == true
            and value.operation == operation
            and signed32(value.flat) ~= nil and signed32(value.percent) ~= nil
            and integer(value.changed, 0, 4294967295) ~= nil
            and ((value.flat ~= 0 or value.percent ~= 0)
                == (value.changed ~= 0))
    end
    if not (facts and facts.shamanEarthShock == true and rank
        and found.valid == true and found.exact == true and found.complete == true
        and found.school == E.NATURE_SCHOOL
        and found.interruptDuration == E.INTERRUPT_DURATION
        and found.interruptDurationMs == E.INTERRUPT_DURATION * 1000
        and level and found.scaledLevel == scaled
        and exactModifier(all, E.ALL_EFFECTS_MOD)
        and exactModifier(damage, E.DAMAGE_MOD)
        and exactModifier(coefficient, E.BONUS_COEFFICIENT_MOD)
        and finite(found.natureSpellPower, -1000000, 1000000)
        and finite(found.rawNoncriticalMean, 0.0001, 100000000)) then return nil end
    local base = rank.points + rank.perLevel * (scaled - rank.spellLevel)
        + (1 + rank.sides) / 2
    base = (base + all.flat) * (100 + all.percent) / 100
    local bonus = (rank.coefficient * 100 + coefficient.flat)
        * (100 + coefficient.percent) / 100 / 100
    local mean = (base + found.natureSpellPower * bonus + damage.flat)
        * (100 + damage.percent) / 100
    if not near(found.effectiveBonusCoefficient, bonus)
        or not near(found.rawNoncriticalMean, mean) then return nil end
    return found
end

function E:InferKnowledge(spellId)
    if classToken() ~= "SHAMAN" then
        return nil, "player is not an exactly identified Shaman", false
    end
    local found, reason, recognized = profile(spellId)
    if not found then return nil, reason, recognized end
    return { inferred = true, kind = "damage", kindExact = true,
        ranged = true, hostile = true, interrupt = true, binary = true,
        school = self.NATURE_SCHOOL, shamanEarthShock = true,
        requiresExactShamanEarthShock = true,
        source = found.source }, nil, true
end

function E:CaptureFacts(action, facts, state)
    if type(facts) ~= "table" or facts.shamanEarthShock ~= true then return facts end
    local found = profile(action and action.spellId)
    local out = copy(facts)
    out.shamanEarthShockEvidence = found and powerProfile(found, state) or {
        recognized = true, valid = false, exact = false,
        reason = "Earth Shock root power evidence is incomplete" }
    return out
end

function E:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

local function castDescriptor(spellId, channel)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or type(channel) ~= "boolean" then return nil end
    local key = tostring(spellId) .. (channel and ":c" or ":n")
    local cached = CASTS[key]
    if cached then return copy(cached) end
    local school = scalar(spellId, "school")
    local prevention = scalar(spellId, "preventionType")
    local normal = scalar(spellId, "interruptFlags")
    local channeled = scalar(spellId, "channelInterruptFlags")
    if not (integer(school, 0, 6) and integer(prevention, 0, 2)
        and integer(normal, 0, 4294967295)
        and integer(channeled, 0, 4294967295)) then return nil end
    local can = prevention == 1 and (channel
        and hasFlag(channeled, E.CHANNEL_INTERRUPT_FLAG)
        or not channel and hasFlag(normal, E.NORMAL_INTERRUPT_FLAG))
    cached = { valid = true, exact = true, spellId = spellId,
        channel = channel, school = school, schoolMask = 2 ^ school,
        preventionType = prevention, interruptFlags = normal,
        channelInterruptFlags = channeled, interruptible = can and true or false,
        source = "root-captured hostile spell DBC interrupt predicate" }
    if CAST_COUNT >= E.MAX_CAST_CACHE then CASTS, CAST_COUNT = {}, 0 end
    CASTS[key], CAST_COUNT = copy(cached), CAST_COUNT + 1
    return copy(cached)
end

function E:CaptureCast(cast)
    if type(cast) ~= "table" then return cast end
    local out = copy(cast)
    out.shamanEarthShockInterrupt = castDescriptor(
        cast.spellId, cast.channel == true) or { valid = false, exact = false,
        reason = "hostile cast interrupt evidence is incomplete" }
    return out
end

function E:CastEvidence(cast)
    local found = cast and cast.shamanEarthShockInterrupt
    local prevention = found and integer(found.preventionType, 0, 2)
    local normal = found and integer(found.interruptFlags, 0, 4294967295)
    local channeled = found
        and integer(found.channelInterruptFlags, 0, 4294967295)
    local channel = cast and cast.channel == true
    local interruptible = prevention == 1 and (channel
        and hasFlag(channeled, self.CHANNEL_INTERRUPT_FLAG)
        or not channel and hasFlag(normal, self.NORMAL_INTERRUPT_FLAG))
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == cast.spellId
        and found.channel == channel and prevention and normal and channeled
        and integer(found.school, 0, 6)
        and found.schoolMask == 2 ^ found.school
        and type(found.interruptible) == "boolean"
        and found.interruptible == (interruptible and true or false)) then
        return nil
    end
    return copy(found)
end

function E:Invalidate()
    PROFILES, CASTS, CAST_COUNT = {}, {}, 0
end
