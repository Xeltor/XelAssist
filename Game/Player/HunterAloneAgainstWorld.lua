-- Installed patch-5 Alone Against the World ownership and active-state
-- evidence. The server-visible passive aura is the engine's predicate result;
-- pet lifecycle must independently prove that no controlled pet exists.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.HunterAloneAgainstWorld = {}
local A = XelAssist.Game.Player.HunterAloneAgainstWorld

A.RANKS = { 52892, 52891 }
A.HUNTER_FAMILY = 9
A.ALL_SCHOOLS_MASK = 127
A.DAMAGE_DONE_PERCENT_AURA = 79

local CACHE = {}

local function finite(value)
    return type(value) == "number" and value == value and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value) or nil
end

local function triple(id, field)
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
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equals(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function profile(id)
    if CACHE[id] ~= nil then return CACHE[id] or nil end
    local points = triple(id, "effectBasePoints")
    local dice = triple(id, "effectBaseDice")
    local percent = points and dice and points[1] + dice[1] or nil
    local expected = id == 52891 and 3 or id == 52892 and 6 or nil
    local valid = expected ~= nil
        and scalar(id, "spellFamilyName") == A.HUNTER_FAMILY
        and scalar(id, "durationIndex") == 21
        and scalar(id, "powerType") == 0
        and scalar(id, "manaCost") == 0
        and scalar(id, "rangeIndex") == 1
        and equals(triple(id, "effect"), 6, 6, 0)
        and equals(triple(id, "effectApplyAuraName"), 79, 4, 0)
        and equals(triple(id, "effectImplicitTargetA"), 1, 1, 0)
        and equals(triple(id, "effectImplicitTargetB"), 0, 0, 0)
        and equals(triple(id, "effectMiscValue"), 127, 0, 0)
        and equals(triple(id, "effectTriggerSpell"), 0, 0, 0)
        and percent == expected
    CACHE[id] = valid and { valid = true, exact = true, spellId = id,
        damagePercent = percent, damageMultiplier = (100 + percent) / 100,
        schoolMask = A.ALL_SCHOOLS_MASK,
        source = "installed patch-5 Alone Against the World aura topology" }
        or false
    return CACHE[id] or nil
end

local function learnedRank()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Alone Against the World ownership unavailable"
    end
    local learned, index, id = nil, nil, nil
    for index = 1, table.getn(A.RANKS) do
        id = A.RANKS[index]
        local ok, known = pcall(IsPlayerSpell, id)
        if not ok or type(known) ~= "boolean" then
            return nil, "Alone Against the World ownership unavailable"
        end
        if known and not learned then learned = id end
    end
    return learned
end

local function activeAura()
    if type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function" then return nil, false end
    local found, index = nil, nil
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil, false end
        if slot and slot ~= -1 then
            local idOK, id = pcall(GetPlayerBuffID, slot)
            if not idOK then return nil, false end
            if id == 52891 or id == 52892 then
                if found and found ~= id then return nil, false end
                found = id
            end
        end
    end
    return found, true
end

local function noControlledPet()
    local owner = XelAssist.Game and XelAssist.Game.Pets
        and XelAssist.Game.Pets.State
    if not owner or type(owner.Snapshot) ~= "function" then
        return false, "controlled-pet lifecycle unavailable"
    end
    local ok, pet = pcall(owner.Snapshot, owner)
    if not ok or type(pet) ~= "table" or pet.supported ~= true then
        return false, "controlled-pet lifecycle unavailable"
    end
    if pet.present == true then return false, "controlled pet present" end
    if pet.present ~= false or pet.lifecycle ~= "dismissed"
        or pet.hasPetUIKnown ~= true or pet.hasPetUI ~= false then
        return false, "controlled-pet absence is ambiguous"
    end
    return true
end

function A:Snapshot(knownClass)
    if knownClass ~= nil and knownClass ~= "HUNTER" then return nil end
    local learned, reason = learnedRank()
    if not learned then
        return { available = learned == nil and reason ~= nil, exact = reason == nil,
            learned = false, reason = reason }
    end
    local found = profile(learned)
    if not found then return { available = false, exact = false, learned = true,
        spellId = learned, reason = "Alone Against the World topology incomplete" } end
    local absent, petReason = noControlledPet()
    local aura, auraExact = activeAura()
    local active = absent and auraExact and aura == learned
    return { available = true, exact = true, learned = true,
        spellId = learned, damagePercent = found.damagePercent,
        damageMultiplier = found.damageMultiplier, schoolMask = found.schoolMask,
        noControlledPet = absent, auraExact = auraExact, activeAura = aura,
        active = active, reason = active and nil or petReason
            or (not auraExact and "passive aura evidence unavailable")
            or "engine passive aura inactive", source = found.source }
end

function A:ResetCache() CACHE = {} end
