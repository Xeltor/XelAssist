-- Root-sealed Octo Spirit Armor threat evidence. The installed passive raises
-- all player threat only while a shield is equipped. Armor value is deliberately
-- left to a separate future consumer; this owner exposes only the exact aura-10
-- threat component and conservative bounds when live equipment is incomplete.
XelAssist.Game.Player.ShamanSpiritArmor = {}
local S = XelAssist.Game.Player.ShamanSpiritArmor

S.RANKS = { [1] = 45951, [2] = 45952 }
local PROFILES

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and tonumber(value) or nil
end

local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > 3
            or key ~= math.floor(key) then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = tonumber(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function installed()
    if PROFILES then return PROFILES end
    PROFILES = { exact = false, byRank = {}, maximum = 1.10,
        source = "installed Octo patch-5 Spirit Armor DBC topology" }
    local rank, id
    for rank = 1, 2 do
        id = S.RANKS[rank]
        if scalar(id, "attributes") ~= 2684354752
            or scalar(id, "spellFamilyName") ~= 11
            or scalar(id, "spellFamilyFlags") ~= 0
            or scalar(id, "spellFamilyFlags2") ~= 0
            or not equal(triple(id, "effect"), 6, 6, 0)
            or not equal(triple(id, "effectApplyAuraName"), 4, 10, 0)
            or not equal(triple(id, "effectBasePoints"),
                rank == 1 and 14 or 29, rank == 1 and 4 or 9, 0)
            or not equal(triple(id, "effectMiscValue"), 0, 127, 0)
            or not equal(triple(id, "effectImplicitTargetA"), 1, 1, 0) then
            PROFILES.reason = "Spirit Armor DBC topology is incomplete"
            return PROFILES
        end
        PROFILES.byRank[rank] = { rank = rank, spellId = id,
            threatPercent = rank * 5, multiplier = 1 + rank * 0.05,
            exact = true, source = PROFILES.source }
    end
    PROFILES.exact = true
    return PROFILES
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function learnedRank()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local found, rank, ok, value = 0, nil, nil, nil
    for rank = 1, 2 do
        ok, value = pcall(IsPlayerSpell, S.RANKS[rank])
        if not ok or type(value) ~= "boolean" then return nil end
        if value then
            if found ~= 0 then return nil end
            found = rank
        end
    end
    return found
end

local function shieldEvidence(state)
    local item = state and state.inventory and state.inventory.offHand
    if not (item and item.classificationKnown == true) then return nil end
    if item.empty or item.broken then return false end
    return tonumber(item.classID) == 4 and tonumber(item.subClassID) == 6
        and tonumber(item.inventoryType) == 14
end

function S:Snapshot(state)
    if classToken() ~= "SHAMAN" then return nil end
    local topology, rank, shield = installed(), learnedRank(), shieldEvidence(state)
    local out = { kind = "shamanSpiritArmor", actor = "player",
        playerOnly = true, component = "shamanSpiritArmor",
        source = topology.source, exact = false, minimum = 1, maximum = 1.10 }
    if topology.exact ~= true then out.reason = topology.reason; return out end
    if rank == nil then
        out.reason = "Spirit Armor ownership unavailable"
        return out
    end
    out.rank = rank
    out.spellId = rank > 0 and S.RANKS[rank] or nil
    local learned = rank > 0 and topology.byRank[rank] or nil
    out.talentMultiplier = learned and learned.multiplier or 1
    out.minimum, out.maximum = 1, out.talentMultiplier
    if shield == nil then
        out.reason = "equipped shield classification unavailable"
        return out
    end
    out.shieldEquipped, out.multiplier = shield, shield and out.talentMultiplier or 1
    out.minimum, out.maximum = out.multiplier, out.multiplier
    out.exact = true
    return copy(out)
end

function S:Invalidate() PROFILES = nil end
