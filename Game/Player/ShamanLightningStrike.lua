-- Exact Octo Lightning Strike cast/result pairs. The spellbook button owns a
-- Physical weapon packet and triggers a second Nature weapon packet. Patch-5
-- also declares a shield trigger, but its shield-specific consequence is a
-- private-server script and remains recorded rather than valued here.
XelAssist.Game.Player.ShamanLightningStrike = {}
local L = XelAssist.Game.Player.ShamanLightningStrike

L.SHAMAN_FAMILY = 11
L.SHIELD_TRIGGER = 52679
L.RANKS = {
    [51387] = { resultSpellId = 51386, physical = 0.20, nature = 0.10 },
    [52420] = { resultSpellId = 52419, physical = 0.40, nature = 0.15 },
    [52422] = { resultSpellId = 52421, physical = 0.60, nature = 0.20 },
}

local CACHE = {}

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok or type(value) ~= "number" or value ~= value then return nil end
    return value
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, index = {}, 0, nil
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > 3
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        if type(values[index]) ~= "number" or values[index] ~= values[index] then
            return nil
        end
        out[index] = values[index]
    end
    return out
end

local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function percentPoints(spellId, expected)
    local points, dice = triple(spellId, "effectBasePoints"),
        triple(spellId, "effectBaseDice")
    return points and dice and points[1] + dice[1] == expected * 100
        and dice[1] == 1
end

local function classify(spellId)
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local rank = L.RANKS[spellId]
    if not rank then return nil end
    local result = rank.resultSpellId
    local found = { recognized = true, valid = false, exact = false,
        spellId = spellId, resultSpellId = result,
        shieldTriggerSpellId = L.SHIELD_TRIGGER,
        physicalWeaponCoefficient = rank.physical,
        natureWeaponCoefficient = rank.nature,
        source = "installed Octo patch-5 Lightning Strike topology" }
    if not (scalar(spellId, "spellFamilyName") == L.SHAMAN_FAMILY
        and scalar(result, "spellFamilyName") == L.SHAMAN_FAMILY
        and scalar(spellId, "school") == 0
        and scalar(result, "school") == 3
        and scalar(spellId, "rangeIndex") == 2
        and scalar(result, "rangeIndex") == 6
        and equal(triple(spellId, "effect"), 31, 64, 64)
        and equal(triple(result, "effect"), 31, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0,
            result, L.SHIELD_TRIGGER)
        and equal(triple(result, "effectTriggerSpell"), 0, 0, 0)
        and percentPoints(spellId, rank.physical)
        and percentPoints(result, rank.nature)) then
        found.reason = "Octo Lightning Strike DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found
    end
    found.valid, found.exact = true, true
    found.totalWeaponCoefficient = rank.physical + rank.nature
    CACHE[spellId] = copy(found)
    return found
end

function L:InferKnowledge(spellId)
    if classToken() ~= "SHAMAN" then return nil, nil, false end
    local found = classify(tonumber(spellId))
    if not found then return nil, nil, false end
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        melee = true, mixedDamage = true,
        dynamicSchool = "damageComponents",
        shamanLightningStrike = true,
        requiresExactShamanLightningStrike = true,
        shamanLightningStrikeEvidence = copy(found),
        damageComponents = {
            { school = 0, schoolMask = 1, mitigation = "armor",
                weaponMultiplier = found.physicalWeaponCoefficient },
            { school = 3, schoolMask = 8, mitigation = "resistance",
                weaponMultiplier = found.natureWeaponCoefficient },
        },
        shamanShieldTrigger = { spellId = found.shieldTriggerSpellId,
            exactTrigger = true, consequenceRepresented = false },
        source = found.source }, nil, true
end

function L:CaptureFacts(action, facts)
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local evidence = action and action.facts
        and action.facts.shamanLightningStrikeEvidence
    local rank = evidence and L.RANKS[evidence.spellId]
    if not (rank and evidence.valid == true and evidence.exact == true
        and evidence.resultSpellId == rank.resultSpellId
        and evidence.shieldTriggerSpellId == L.SHIELD_TRIGGER
        and evidence.physicalWeaponCoefficient == rank.physical
        and evidence.natureWeaponCoefficient == rank.nature
        and evidence.totalWeaponCoefficient == rank.physical + rank.nature) then
        return out
    end
    out.weaponCoefficient = evidence.totalWeaponCoefficient
    out.weaponFlat, out.weaponDirectFlat = 0, 0
    out.damageComponents = action.facts.damageComponents
    out.shamanLightningStrikeEvidence = copy(evidence)
    out.shamanShieldTrigger = action.facts.shamanShieldTrigger
    return out
end

function L:Invalidate() CACHE = {} end
