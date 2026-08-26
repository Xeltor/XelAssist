-- Exact installed Octo Shield Bash identity and legality. The DBC proves the
-- shield requirement, stance mask, physical melee delivery and interrupt
-- packet. Its private supplemental threat is deliberately left unknown.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorShieldBash = {}
local B = XelAssist.Game.Player.WarriorShieldBash

B.WARRIOR_FAMILY = 4
B.FAMILY_FLAG = 2048
B.STANCE_MASK = 196608

local RANKS = {
    [72] = { rank = 1, level = 12, damage = 6 },
    [1671] = { rank = 2, level = 32, damage = 18 },
    [1672] = { rank = 3, level = 52, damage = 45 },
}
local CACHE = {}

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function integer(value)
    value = tonumber(value)
    return value and value == value and math.floor(value) == value
        and value >= -2147483648 and value <= 4294967295 and value or nil
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and integer(value) or nil
end

local function triple(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = integer(values[index])
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function rangeExact(spellId)
    if scalar(spellId, "rangeIndex") ~= 2
        or type(GetSpellRangeData) ~= "function" then return false end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and minimum == 0 and maximum == 5
end

local function topology(spellId, rank)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 88
        and scalar(spellId, "attributes") == 327696
        and scalar(spellId, "attributesEx") == 134218240
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 8
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == B.STANCE_MASK
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 12000
        and scalar(spellId, "durationIndex") == 32
        and scalar(spellId, "powerType") == 1
        and scalar(spellId, "manaCost") == 100
        and scalar(spellId, "equippedItemClass") == 4
        and scalar(spellId, "equippedItemSubClassMask") == 64
        and scalar(spellId, "equippedItemInventoryTypeMask") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == B.WARRIOR_FAMILY
        and scalar(spellId, "spellFamilyFlags") == B.FAMILY_FLAG
        and scalar(spellId, "dmgClass") == 2
        and scalar(spellId, "preventionType") == 2
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and equal(triple(spellId, "effect"), 68, 2, 0)
        and equal(triple(spellId, "effectDieSides", true), 1, 1, 0)
        and equal(triple(spellId, "effectBasePoints", true),
            -1, rank.damage - 1, 0)
        and equal(triple(spellId, "effectMechanic"), 26, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 6, 0)
        and rangeExact(spellId)
end

local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

function B:Classify(spellId)
    spellId = integer(spellId)
    local rank = spellId and RANKS[spellId]
    if not rank then return nil, "not an installed Shield Bash identity", false end
    local cached = CACHE[spellId]
    if cached then
        return cached.valid and copy(cached) or nil, cached.reason, true
    end
    cached = { recognized = true, valid = false, exact = false,
        spellId = spellId, rank = rank.rank, level = rank.level,
        source = "installed Octo patch-5 Shield Bash DBC topology" }
    if not topology(spellId, rank) then
        cached.reason = "Shield Bash DBC topology is incomplete"
        CACHE[spellId] = cached
        return nil, cached.reason, true
    end
    cached.valid, cached.exact = true, true
    cached.damage, cached.cost = rank.damage, 10
    cached.stances, cached.minRange, cached.maxRange = B.STANCE_MASK, 0, 5
    cached.cooldown, cached.gcd, cached.cast = 12, 1.5, 0
    cached.requiresShield, cached.interruptsSpellcasting = true, true
    cached.actionSpecificThreatKnown = false
    CACHE[spellId] = cached
    return copy(cached), nil, true
end

function B:InferKnowledge(spellId)
    if not warrior() then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not found then return nil, reason, handled end
    return { inferred = true, kind = "damage", kindExact = true,
        warriorShieldBash = true, melee = true, hostile = true,
        interrupt = true, requiresShield = true,
        resourceType = "rage", stanceMask = found.stances,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, requiresExactUsability = true,
        submissionGuarded = true, school = 0,
        warriorShieldBashEvidence = copy(found), source = found.source }, nil, true
end

function B:Invalidate() CACHE = {} end
