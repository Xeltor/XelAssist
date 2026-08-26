-- Exact installed ordinary Rogue poison identities and live dual-hand state.
-- This owner deliberately stops before proc/application consequences: custom
-- poison scripts, weapon targeting and server charge ordering belong elsewhere.
XelAssist.Game.Player.RoguePoisons = {}
local P = XelAssist.Game.Player.RoguePoisons

P.ROGUE, P.TEMP_ENCHANT, P.COMBAT_PROC = 8, 54, 1
P.RANKS = {
    [2823] = { family="deadly", rank=1, enchantId=7, child=2818,
        createSpell=2835, itemId=2892, chance=30 },
    [2824] = { family="deadly", rank=2, enchantId=8, child=2819,
        createSpell=2837, itemId=2893, chance=30 },
    [11355] = { family="deadly", rank=3, enchantId=626, child=11353,
        createSpell=11357, itemId=8984, chance=30 },
    [11356] = { family="deadly", rank=4, enchantId=627, child=11354,
        createSpell=11358, itemId=8985, chance=30 },
    [25351] = { family="deadly", rank=5, enchantId=2630, child=25349,
        createSpell=25347, itemId=20844, chance=30 },
    [8679] = { family="instant", rank=1, enchantId=323, child=8680,
        createSpell=8681, itemId=6947, chance=20 },
    [8686] = { family="instant", rank=2, enchantId=324, child=8685,
        createSpell=8687, itemId=6949, chance=20 },
    [8688] = { family="instant", rank=3, enchantId=325, child=8689,
        createSpell=8691, itemId=6950, chance=20 },
    [11338] = { family="instant", rank=4, enchantId=623, child=11335,
        createSpell=11341, itemId=8926, chance=20 },
    [11339] = { family="instant", rank=5, enchantId=624, child=11336,
        createSpell=11342, itemId=8927, chance=20 },
    [11340] = { family="instant", rank=6, enchantId=625, child=11337,
        createSpell=11343, itemId=8928, chance=20 },
    [3408] = { family="crippling", rank=1, enchantId=22, child=3409,
        createSpell=3420, itemId=3775, chance=30 },
    [11202] = { family="crippling", rank=2, enchantId=603, child=11201,
        createSpell=3421, itemId=3776, chance=30 },
    [5761] = { family="mindNumbing", rank=1, enchantId=35, child=5760,
        createSpell=5763, itemId=5237, chance=20, duration=10 },
    [8693] = { family="mindNumbing", rank=2, enchantId=23, child=8692,
        createSpell=8694, itemId=6951, chance=20, duration=12 },
    [11399] = { family="mindNumbing", rank=3, enchantId=643, child=11398,
        createSpell=11400, itemId=9186, chance=20, duration=14 },
}
local CACHE, BY_ENCHANT, BY_CHILD = {}, {}, {}
local id, spec
for id, spec in pairs(P.RANKS) do
    BY_ENCHANT[spec.enchantId], BY_CHILD[spec.child] = id, id
end

local function integer(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    value = ok and integer(value, 0, 4294967295) or nil
    if signed and value and value >= 2147483648 then value = value - 4294967296 end
    return value
end
local function triple(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = integer(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b
        and values[3] == c
end
local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, spellId)
    value = ok and tonumber(value) or nil
    return value and value >= 0 and value / 1000 or nil
end
local function itemSpell(itemId)
    if not (C_Item and type(C_Item.GetItemSpell) == "function") then return nil end
    local ok, _, spellId = pcall(C_Item.GetItemSpell, itemId)
    return ok and integer(spellId, 1, 4294967295) or nil
end

local function parentValid(spellId, found)
    return scalar(spellId, "spellFamilyName") == P.ROGUE
        and scalar(spellId, "castingTimeIndex") == 15
        and scalar(spellId, "equippedItemClass", true) == 2
        and scalar(spellId, "equippedItemSubClassMask") == 173555
        and scalar(spellId, "procChance") == found.chance
        and equal(triple(spellId, "effect"), P.TEMP_ENCHANT, 0, 0)
        and equal(triple(spellId, "effectMiscValue", true),
            found.enchantId, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 0, 0)
end
local function creatorValid(found)
    return equal(triple(found.createSpell, "effect"), 24, 0, 0)
        and equal(triple(found.createSpell, "effectItemType"),
            found.itemId, 0, 0)
        and equal(triple(found.createSpell, "effectImplicitTargetA"), 1, 0, 0)
        and itemSpell(found.itemId) == found.spellId
end
local function enchantValid(found)
    if not (C_Item and type(C_Item.GetEnchantInfo) == "function") then return false end
    local ok, value = pcall(C_Item.GetEnchantInfo, found.enchantId)
    if not ok or type(value) ~= "table" or value.enchantID ~= found.enchantId
        or type(value.effects) ~= "table" or value.effects[1] == nil
        or value.effects[2] ~= nil then
        return false
    end
    local effect = value.effects[1]
    return effect.type == P.COMBAT_PROC and effect.amount == found.chance
        and effect.arg == found.child and value.spellID == found.child
end
local function magnitude(spellId)
    local points = triple(spellId, "effectBasePoints", true)
    local dice = triple(spellId, "effectBaseDice")
    local sides = triple(spellId, "effectDieSides", true)
    local diceLevel = triple(spellId, "effectDicePerLevel", true)
    local pointsLevel = triple(spellId, "effectRealPointsPerLevel", true)
    if not (points and dice and sides
        and equal(diceLevel, 0, 0, 0)
        and equal(pointsLevel, 0, 0, 0)
        and dice[1] >= 0 and sides[1] >= dice[1]) then return nil end
    local low = points[1] + dice[1]
    local high = points[1] + math.max(dice[1], sides[1])
    if low <= 0 or high < low then return nil end
    return low, high, (low + high) / 2
end
local function childValid(found)
    local child = found.child
    if scalar(child, "school") ~= 3 or scalar(child, "dispel") ~= 4
        or not equal(triple(child, "effectImplicitTargetA"), 6, 0, 0) then
        return false
    end
    local effects, auras, amplitudes = triple(child, "effect"),
        triple(child, "effectApplyAuraName"), triple(child, "effectAmplitude")
    if found.family == "instant" then
        local low, high, average = magnitude(child)
        local valid = low and duration(child) == 0
            and scalar(child, "stackAmount") == 0
            and equal(effects, 2, 0, 0) and equal(auras, 0, 0, 0)
            and equal(amplitudes, 0, 0, 0)
        if valid then
            found.damageMin, found.damageMax, found.damageAverage =
                low, high, average
        end
        return valid and true or false
    end
    local expectedAura = found.family == "deadly" and 3
        or found.family == "crippling" and 33 or 65
    local expectedDuration = found.duration or 12
    local expectedStacks = found.family == "deadly" and 5 or 0
    local expectedAmplitude = found.family == "deadly" and 3000 or 0
    local valid = duration(child) == expectedDuration
        and scalar(child, "stackAmount") == expectedStacks
        and equal(effects, 6, 0, 0) and equal(auras, expectedAura, 0, 0)
        and equal(amplitudes, expectedAmplitude, 0, 0)
    if not valid then return false end
    found.duration, found.interval, found.stackCap =
        expectedDuration, expectedAmplitude / 1000, expectedStacks
    if found.family == "deadly" then
        local low, high = magnitude(child)
        if not low or low ~= high then return false end
        found.damagePerStackTick = low
    end
    return true
end

function P:Profile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    local found = spellId and self.RANKS[spellId]
    if not found then return nil, "not an ordinary Rogue poison", false end
    local cached = CACHE[spellId]
    if cached then return cached.valid and copy(cached) or nil,
        cached.reason, true end
    local profile = copy(found); profile.spellId = spellId
    local valid = parentValid(spellId, profile) and creatorValid(profile)
        and enchantValid(profile) and childValid(profile)
    profile.valid, profile.exact = valid, valid
    profile.source = "installed Octo spell, item and enchant topology"
    if not valid then profile.reason = "ordinary Rogue poison topology unavailable" end
    CACHE[spellId] = copy(profile)
    return valid and copy(profile) or nil, profile.reason, true
end

function P:ByEnchant(enchantId)
    local spellId = BY_ENCHANT[integer(enchantId, 1, 4294967295)]
    if not spellId then return nil, "temporary enchant is not an ordinary poison" end
    return self:Profile(spellId)
end

function P:ByChild(childId)
    local spellId = BY_CHILD[integer(childId, 1, 4294967295)]
    if not spellId then return nil, "triggered spell is not an ordinary poison" end
    return self:Profile(spellId)
end

local function hand(active, remaining, charges, enchantId, name, owner)
    if active ~= true and active ~= false then return nil end
    local out = { available=true, exact=true, hand=name, active=active }
    if not active then return out end
    remaining, charges, enchantId = tonumber(remaining),
        integer(charges, 0, 1000000), integer(enchantId, 1, 4294967295)
    if not remaining or remaining <= 0 or not charges or not enchantId then return nil end
    out.remaining, out.charges, out.enchantId = remaining / 1000, charges, enchantId
    local spellId = BY_ENCHANT[enchantId]
    if spellId then
        local profile = owner:Profile(spellId)
        if not profile then return nil end
        out.isPoison, out.profile, out.spellId, out.childSpellId =
            true, profile, profile.spellId, profile.child
    else out.isPoison = false end
    return out
end

function P:Stock()
    local out = { available=false, exact=false, byItem={}, bySpell={} }
    if not (C_Item and type(C_Item.GetItemCount) == "function") then
        out.reason = "item count API unavailable"; return out
    end
    local spellId, found
    for spellId, found in pairs(self.RANKS) do
        local profile = self:Profile(spellId)
        if not profile then out.reason = "poison item topology unavailable"; return out end
        local ok, count = pcall(C_Item.GetItemCount, found.itemId, false, false)
        count = ok and integer(count, 0, 1000000) or nil
        if count == nil then out.reason = "poison stock unavailable"; return out end
        out.byItem[found.itemId], out.bySpell[spellId] = count, count
    end
    out.available, out.exact, out.reason = true, true, nil
    return out
end

function P:Snapshot()
    local out = { available=false, exact=false }
    if type(UnitClass) ~= "function" then out.reason="class API unavailable"; return out end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok or token ~= "ROGUE" then out.reason="player is not Rogue"; return out end
    if not (C_Item and type(C_Item.GetWeaponEnchantInfo) == "function") then
        out.reason="weapon enchant API unavailable"; return out
    end
    local values = { pcall(C_Item.GetWeaponEnchantInfo) }
    if not values[1] then out.reason="weapon enchant state unavailable"; return out end
    local main = hand(values[2], values[3], values[4], values[5], "main", self)
    local off = hand(values[6], values[7], values[8], values[9], "off", self)
    if not main or not off then out.reason="weapon enchant state incomplete"; return out end
    out.available, out.exact, out.hands = true, true, { main=main, off=off }
    out.stock = self:Stock()
    return out
end

function P:Invalidate() CACHE = {} end
