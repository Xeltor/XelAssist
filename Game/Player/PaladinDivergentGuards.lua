-- Fail-closed ownership for installed Paladin actions whose visible generic
-- shape omits a material private consequence. Crusader Strike's DBC owns a
-- stacking flat Holy vulnerability, while its direct packet is server-private;
-- neither may silently become an ordinary generic melee hit.
XelAssist.Game.Player.PaladinDivergentGuards = {}
local G = XelAssist.Game.Player.PaladinDivergentGuards

G.PALADIN_FAMILY, G.CRUSADER_FLAG = 10, 536870912
G.CRUSADER = {
    [45409] = { rank = 1, level = 10, holyFlat = 6 },
    [45410] = { rank = 2, level = 22, holyFlat = 10 },
    [45411] = { rank = 3, level = 34, holyFlat = 15 },
    [45412] = { rank = 4, level = 46, holyFlat = 22 },
    [45413] = { rank = 5, level = 58, holyFlat = 30 },
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
local function scalar(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then
        value = value - 4294967296
    end
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
        out[index] = integer(values[index], signed and -2147483648 or 0,
            4294967295)
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
local function paladin()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "PALADIN"
end

local function profile(id)
    if CACHE[id] then return CACHE[id] end
    local rank = G.CRUSADER[id]
    if not rank then return nil end
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, id, 1)
        duration = ok and integer(value, 1, 600000) or nil
    end
    local points, dice = triple(id, "effectBasePoints", true),
        triple(id, "effectBaseDice")
    local valid = scalar(id, "dispel") == 1
        and scalar(id, "attributes") == 2424832
        and scalar(id, "attributesEx") == 512
        and scalar(id, "attributesEx2") == 536870912
        and scalar(id, "durationIndex") == 9 and duration == 30000
        and scalar(id, "cumulativeAura") == 5
        and scalar(id, "baseLevel") == rank.level
        and scalar(id, "spellLevel") == rank.level
        and scalar(id, "rangeIndex") == 2
        and scalar(id, "equippedItemClass", true) == 2
        and scalar(id, "spellFamilyName") == G.PALADIN_FAMILY
        and scalar(id, "spellFamilyFlags") == G.CRUSADER_FLAG
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(dice, 1, 0, 0)
        and points and points[1] + dice[1] == rank.holyFlat
        and equal(triple(id, "effectImplicitTargetA"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 14, 0, 0)
        and equal(triple(id, "effectMiscValue"), 2, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
    local out = { recognized = true, valid = valid, exact = valid,
        spellId = id, rank = rank.rank, holyFlatPerStack = rank.holyFlat,
        maximumStacks = 5, duration = 30,
        privateDirectPacket = true, flatModifierUnsupported = true,
        source = "installed Octo patch-5 Crusader Strike topology" }
    out.reason = valid
        and "Crusader Strike private damage and flat Holy vulnerability lifecycle unresolved"
        or "Crusader Strike installed topology is incomplete"
    CACHE[id] = out
    return out
end

function G:InferKnowledge(spellId)
    spellId = integer(spellId, 1, 4294967295)
    local found = spellId and profile(spellId) or nil
    if not found then return nil, "not guarded Paladin divergence", false end
    if not paladin() then
        return nil, "player is not an exactly identified Paladin", false
    end
    return { inferred = true, kind = "damage", kindExact = false,
        melee = true, paladinCrusaderStrike = true,
        unmodeledUnsafe = found.reason,
        requiresPaladinCrusaderStrikeEvidence = true,
        paladinCrusaderStrikeEvidence = found,
        source = found.source }, found.reason, true
end

function G:Invalidate() CACHE = {} end
