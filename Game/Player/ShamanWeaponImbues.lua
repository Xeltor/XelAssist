-- Installed Shaman weapon-imbue discovery and exact main-hand enchant state.
-- Rockbiter and Flametongue have representable ordinary hit consequences;
-- Frostbrand/Windfury remain recognized but effect-unknown where proc behavior
-- is private or conflicts with the installed enchant scalar.
XelAssist.Game.Player.ShamanWeaponImbues = {}
local W = XelAssist.Game.Player.ShamanWeaponImbues

W.SHAMAN, W.TEMP_ENCHANT_EFFECT = 11, 54
W.DURATION, W.MAIN_HAND = 3600, 16
W.RANKS = {
    [8017] = { family = "rockbiter", rank = 1, enchantId = 29, child = 10400 },
    [8018] = { family = "rockbiter", rank = 2, enchantId = 6, child = 15567 },
    [8019] = { family = "rockbiter", rank = 3, enchantId = 1, child = 15568 },
    [10399] = { family = "rockbiter", rank = 4, enchantId = 503, child = 15569 },
    [16314] = { family = "rockbiter", rank = 5, enchantId = 1663, child = 16311 },
    [16315] = { family = "rockbiter", rank = 6, enchantId = 683, child = 16312 },
    [16316] = { family = "rockbiter", rank = 7, enchantId = 1664, child = 16313 },
    [8024] = { family = "flametongue", rank = 1, enchantId = 5, child = 8026 },
    [8027] = { family = "flametongue", rank = 2, enchantId = 4, child = 8028 },
    [8030] = { family = "flametongue", rank = 3, enchantId = 3, child = 8029 },
    [16339] = { family = "flametongue", rank = 4, enchantId = 523, child = 10445 },
    [16341] = { family = "flametongue", rank = 5, enchantId = 1665, child = 16343 },
    [16342] = { family = "flametongue", rank = 6, enchantId = 1666, child = 16344 },
    [8033] = { family = "frostbrand", rank = 1, enchantId = 2, child = 8034 },
    [8038] = { family = "frostbrand", rank = 2, enchantId = 12, child = 8037 },
    [10456] = { family = "frostbrand", rank = 3, enchantId = 524, child = 10458 },
    [16355] = { family = "frostbrand", rank = 4, enchantId = 1667, child = 16352 },
    [16356] = { family = "frostbrand", rank = 5, enchantId = 1668, child = 16353 },
    [8232] = { family = "windfury", rank = 1, enchantId = 283, child = 8233 },
    [8235] = { family = "windfury", rank = 2, enchantId = 284, child = 8236 },
    [10486] = { family = "windfury", rank = 3, enchantId = 525, child = 10484 },
    [16362] = { family = "windfury", rank = 4, enchantId = 1669, child = 16361 },
}
local CACHE = {}

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
    value = ok and finite(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then value = value - 4294967296 end
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
        out[index] = finite(values[index], signed and -2147483648 or 0,
            4294967295)
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end
local function playerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    return ok and integer(level, 1, 255) or nil
end
local function enchantInfo(id)
    if not (C_Item and type(C_Item.GetEnchantInfo) == "function") then return nil end
    local ok, found = pcall(C_Item.GetEnchantInfo, id)
    if not ok or type(found) ~= "table" or found.enchantID ~= id
        or type(found.effects) ~= "table" then return nil end
    local effect = found.effects[1]
    if not (effect and integer(effect.type, 1, 7)
        and integer(effect.arg, 1, 4294967295)) then return nil end
    return found, effect
end

local function scaledMagnitude(id, index, level)
    local points, dice, sides = triple(id, "effectBasePoints", true),
        triple(id, "effectBaseDice"), triple(id, "effectDieSides", true)
    local perLevel = triple(id, "effectRealPointsPerLevel", true)
    local diceLevel = triple(id, "effectDicePerLevel", true)
    local spellLevel, baseLevel, maximum = scalar(id, "spellLevel"),
        scalar(id, "baseLevel"), scalar(id, "maxLevel")
    if not (points and dice and sides and perLevel and diceLevel
        and spellLevel and baseLevel and maximum and level) then return nil end
    local effective = math.max(baseLevel, level)
    if maximum > 0 then effective = math.min(effective, maximum) end
    local levels = math.max(0, effective - spellLevel)
    local die = sides[index] + diceLevel[index] * levels
    local roll = die > 1 and (dice[index] + die) / 2 or dice[index]
    return points[index] + perLevel[index] * levels + roll
end

local function parentTopology(id, spec)
    return scalar(id, "powerType", true) == 0
        and scalar(id, "durationIndex") == 0
        and equal(triple(id, "effect"), W.TEMP_ENCHANT_EFFECT, 0, 0)
        and equal(triple(id, "effectMiscValue", true), spec.enchantId, 0, 0)
end
local function childTopology(spec, level)
    local id = spec.child
    if spec.family == "rockbiter" then
        local ap, threat = scaledMagnitude(id, 1, level),
            scaledMagnitude(id, 2, level)
        if scalar(id, "spellFamilyName") ~= W.SHAMAN
            or not equal(triple(id, "effect"), 6, 6, 6)
            or not equal(triple(id, "effectApplyAuraName"), 99, 10, 87)
            or not equal(triple(id, "effectMiscValue", true), 0, 127, 127)
            or not ap or ap <= 0 or threat ~= 35 then return nil end
        return { effectKnown = true, attackPower = ap,
            threatMultiplier = 1.35 }
    elseif spec.family == "flametongue" then
        local magnitude = scaledMagnitude(id, 1, level)
        if scalar(id, "school") ~= 2
            or scalar(id, "spellFamilyName") ~= W.SHAMAN
            or not equal(triple(id, "effect"), 3, 0, 0)
            or not magnitude or magnitude <= 0 then return nil end
        return { effectKnown = true, school = 2,
            speedScalar = magnitude * (1 / 77 + 1 / 25) / 2,
            procChance = 1 }
    elseif spec.family == "frostbrand" then
        return { effectKnown = false,
            reason = "Frostbrand proc chance is private" }
    end
    return { effectKnown = false,
        reason = "Windfury installed proc chance conflicts with tooltip" }
end

local function classify(id)
    id = integer(id, 1, 4294967295)
    local spec = id and W.RANKS[id]
    if not spec then return nil, nil, false end
    local cached = CACHE[id]
    if cached then return cached.valid and copy(cached) or nil,
        cached.reason, true end
    local level = playerLevel()
    local info, enchant = enchantInfo(spec.enchantId)
    local child = level and childTopology(spec, level) or nil
    local valid = parentTopology(id, spec) and info and enchant
        and enchant.type == (spec.family == "rockbiter" and 3 or 1)
        and enchant.arg == spec.child and child
    local found = valid and { valid = true, exact = true, spellId = id,
        family = spec.family, rank = spec.rank, enchantId = spec.enchantId,
        childSpellId = spec.child, duration = W.DURATION,
        effectKnown = child.effectKnown, reason = child.reason,
        attackPower = child.attackPower,
        threatMultiplier = child.threatMultiplier,
        school = child.school, speedScalar = child.speedScalar,
        procChance = child.procChance, level = level,
        source = "installed patch-5 spell and ClassicAPI enchant topology" }
        or { valid = false, reason = "weapon imbue topology unavailable" }
    CACHE[id] = copy(found)
    return valid and copy(found) or nil, found.reason, true
end

function W:InferKnowledge(spellId)
    if classToken() ~= "SHAMAN" then return nil, nil, false end
    local found, reason, recognized = classify(spellId)
    if not found then return nil, reason, recognized end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, fixedTarget = "player", immediateDispatch = true,
        shamanWeaponImbue = true, requiresExactUsability = true,
        shamanWeaponImbueEvidence = found,
        requiresExactShamanWeaponImbue = found.effectKnown ~= true,
        source = found.source }, nil, true
end

function W:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.shamanWeaponImbueEvidence
    local spec = found and self.RANKS[found.spellId]
    if not (facts and facts.shamanWeaponImbue == true and spec
        and found.valid == true and found.exact == true
        and found.family == spec.family and found.rank == spec.rank
        and found.enchantId == spec.enchantId
        and found.childSpellId == spec.child and found.duration == 3600) then
        return nil
    end
    return copy(found)
end

function W:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = action and self:Evidence(action)
    if not found then return out end
    out.shamanWeaponImbue, out.shamanWeaponImbueEvidence = true, found
    out.immediateDispatch, out.duration = true, found.duration
    if found.effectKnown ~= true then out.requiresExactShamanWeaponImbue = true end
    return out
end

function W:Snapshot()
    local out = { available = false, exact = false }
    if classToken() ~= "SHAMAN" then out.reason = "player is not Shaman"; return out end
    if not (C_Item and type(C_Item.GetWeaponEnchantInfo) == "function") then
        out.reason = "weapon enchant API unavailable"; return out
    end
    local ok, has, remaining, charges, enchantId =
        pcall(C_Item.GetWeaponEnchantInfo)
    if not ok then out.reason = "weapon enchant state unavailable"; return out end
    remaining, charges, enchantId = tonumber(remaining),
        tonumber(charges), tonumber(enchantId)
    if has and (not remaining or remaining <= 0 or not enchantId
        or enchantId <= 0) then
        out.reason = "weapon enchant state incomplete"; return out
    end
    out.available, out.exact, out.active = true, true, has == true
    out.remaining = has and remaining / 1000 or nil
    out.charges, out.enchantId = has and charges or nil,
        has and enchantId or nil
    out.hand, out.replacementFamily = "main", "mainHandTemporaryEnchant"
    return out
end

function W:Invalidate() CACHE = {} end
