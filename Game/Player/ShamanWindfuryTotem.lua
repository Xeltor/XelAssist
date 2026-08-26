-- Exact Windfury Totem consequence from the installed build-5875 spell
-- topology.  The generic Shaman adapter owns slot/lifetime mechanics; this
-- leaf promotes only the custom 8512 -> 51367 -> 51368 chain.  Party fanout
-- is deliberately not represented by the graph yet.
XelAssist.Game.Player.ShamanWindfuryTotem = {}
local W = XelAssist.Game.Player.ShamanWindfuryTotem

W.ACTION_ID = 8512
W.AURA_ID = 51367
W.TRIGGER_ID = 51368
W.ELEMENT = "air"
W.SLOT = 4
W.RADIUS = 30
W.PROC_FLAGS = 4194320
W.PROC_CHANCE = 0.20
W.EXTRA_ATTACKS = 1

local PROFILE_CACHE = nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        if type(value) == "table" then out[key] = copy(value)
        else out[key] = value end
    end
    return out
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
end

local function triple(spellId, field)
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
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, expected)
    return values and expected and values[1] == expected[1]
        and values[2] == expected[2] and values[3] == expected[3]
end

local SCALAR_PROFILE = {
    [8512] = {
        school = 3, attributes = 65536, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        castingTimeIndex = 1, procFlags = 0, procChance = 101,
        procCharges = 0, baseLevel = 32, spellLevel = 32,
        durationIndex = 4, powerType = 0, manaCost = 115,
        rangeIndex = 1, startRecoveryCategory = 108,
        startRecoveryTime = 1500, spellFamilyName = 11,
        spellFamilyFlags = 4503600164241408, dmgClass = 1,
        preventionType = 1,
    },
    [51367] = {
        school = 3, attributes = 320, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        castingTimeIndex = 1, procFlags = 4194320, procChance = 20,
        procCharges = 0, baseLevel = 32, spellLevel = 32,
        durationIndex = 21, powerType = 0, manaCost = 0,
        rangeIndex = 1, startRecoveryCategory = 0,
        startRecoveryTime = 0, spellFamilyName = 11,
        spellFamilyFlags = 67108864, dmgClass = 1,
        preventionType = 1,
    },
    [51368] = {
        school = 3, attributes = 1, attributesEx = 268435456,
        attributesEx2 = 16777216, attributesEx3 = 0, attributesEx4 = 0,
        castingTimeIndex = 1, procFlags = 4, procChance = 100,
        procCharges = 2, baseLevel = 32, spellLevel = 32,
        durationIndex = 65, powerType = 0, manaCost = 0,
        rangeIndex = 6, startRecoveryCategory = 0,
        startRecoveryTime = 0, spellFamilyName = 11,
        spellFamilyFlags = 8589934592, dmgClass = 0,
        preventionType = 0,
    },
}

local ARRAY_PROFILE = {
    [8512] = {
        effect = { 90, 0, 0 }, effectDieSides = { 1, 0, 0 },
        effectBaseDice = { 1, 0, 0 }, effectBasePoints = { 4, 0, 0 },
        effectImplicitTargetA = { 43, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectApplyAuraName = { 0, 0, 0 },
        effectMiscValue = { 52144, 0, 0 },
        effectTriggerSpell = { 0, 0, 0 },
    },
    [51367] = {
        effect = { 35, 0, 0 }, effectDieSides = { 1, 0, 0 },
        effectBaseDice = { 1, 0, 0 }, effectBasePoints = { -1, 0, 0 },
        effectImplicitTargetA = { 1, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 10, 0, 0 },
        effectApplyAuraName = { 42, 0, 0 },
        effectMiscValue = { 0, 0, 0 },
        effectTriggerSpell = { 51368, 0, 0 },
    },
    [51368] = {
        effect = { 19, 6, 0 }, effectDieSides = { 1, 1, 0 },
        effectBaseDice = { 1, 1, 0 }, effectBasePoints = { 0, 0, 0 },
        effectImplicitTargetA = { 1, 1, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectApplyAuraName = { 0, 4, 0 },
        effectMiscValue = { 0, 0, 0 },
        effectTriggerSpell = { 0, 0, 0 },
    },
}

local ZERO = { 0, 0, 0 }
local COMPLETE_ZERO_FIELDS = { "effectDicePerLevel",
    "effectRealPointsPerLevel", "effectMechanic", "effectAmplitude",
    "effectMultipleValue", "effectChainTarget", "effectItemType",
    "effectPointsPerComboPoint" }

local function topology(spellId)
    local key, expected, index
    for key, expected in pairs(SCALAR_PROFILE[spellId] or {}) do
        if scalar(spellId, key) ~= expected then return false end
    end
    for key, expected in pairs(ARRAY_PROFILE[spellId] or {}) do
        if not equal(triple(spellId, key), expected) then return false end
    end
    for index = 1, table.getn(COMPLETE_ZERO_FIELDS) do
        if not equal(triple(spellId, COMPLETE_ZERO_FIELDS[index]), ZERO) then
            return false
        end
    end
    return true
end

local function installedProfile()
    if PROFILE_CACHE then return copy(PROFILE_CACHE) end
    if not (topology(W.ACTION_ID) and topology(W.AURA_ID)
        and topology(W.TRIGGER_ID)) then
        return nil, "Windfury Totem DBC chain is incomplete"
    end
    local out = { valid = true, exact = true, spellId = W.ACTION_ID,
        auraSpellId = W.AURA_ID, triggerSpellId = W.TRIGGER_ID,
        slot = W.SLOT, element = W.ELEMENT, radius = W.RADIUS,
        procFlags = W.PROC_FLAGS, procChance = W.PROC_CHANCE,
        extraAttacks = W.EXTRA_ATTACKS, weaponHand = "main",
        mainHandWhite = true, mainHandMeleeAbility = true,
        resetsMainHandTimer = true, recursive = false,
        source = "installed build-5875 Windfury chain and server proc semantics" }
    PROFILE_CACHE = copy(out)
    return copy(out)
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.shamanWindfuryEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == W.ACTION_ID
        and found.auraSpellId == W.AURA_ID
        and found.triggerSpellId == W.TRIGGER_ID
        and found.slot == W.SLOT and found.element == W.ELEMENT
        and found.radius == W.RADIUS and found.procFlags == W.PROC_FLAGS
        and found.procChance == W.PROC_CHANCE
        and found.extraAttacks == W.EXTRA_ATTACKS
        and found.weaponHand == "main" and found.mainHandWhite == true
        and found.mainHandMeleeAbility == true
        and found.resetsMainHandTimer == true
        and found.recursive == false) then return nil end
    return found
end

local function effect(found)
    return { exact = true, kind = "playerMainHandExtraAttackProc",
        auraSpellId = found.auraSpellId,
        triggerSpellId = found.triggerSpellId,
        procFlags = found.procFlags, procChance = found.procChance,
        extraAttacks = found.extraAttacks, weaponHand = found.weaponHand,
        mainHandWhite = found.mainHandWhite,
        mainHandMeleeAbility = found.mainHandMeleeAbility,
        resetsMainHandTimer = found.resetsMainHandTimer,
        recursive = found.recursive }
end

function W:Promote(spellId, facts)
    if integer(spellId, 1, 4294967295) ~= self.ACTION_ID
        or not (facts and facts.shamanTotem == true
            and facts.shamanLifecycleRepresented == true
            and facts.shamanRepresentationExact == true
            and facts.totemElementExact == true
            and facts.totemReplacementExact == true
            and facts.totemLifetimeExact == true
            and facts.totemSlot == self.SLOT
            and facts.totemReplacementSlot == self.SLOT
            and facts.totemElement == self.ELEMENT) then return facts end
    local found = installedProfile()
    if not found then return facts end
    local out = copy(facts)
    out.shamanRepresentation = "windfuryTotemSolo"
    out.shamanEffectRepresented = true
    out.shamanRangeRepresented = true
    out.shamanRecipientsRepresented = true
    out.shamanWindfuryEvidence = copy(found)
    out.shamanTotemDownstream = { exact = true,
        sourceSpellId = self.ACTION_ID, element = self.ELEMENT,
        effect = effect(found),
        range = { exact = true, center = "totem", minimum = 0,
            maximum = found.radius },
        recipients = { exact = true, center = "totem", relation = "party",
            shape = "area", graphScope = "soloSelf" }, source = found.source }
    return out
end

function W:Inspect(spellId)
    if integer(spellId, 1, 4294967295) ~= self.ACTION_ID then
        return { available = true, exact = true, recognized = false }
    end
    local found, reason = installedProfile()
    if found then found.available, found.recognized = true, true; return found end
    return { available = false, exact = false, recognized = true,
        reason = reason }
end

function W:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function groupCount(api, maximum)
    if type(api) ~= "function" then return nil end
    local ok, count = pcall(api)
    return ok and integer(count, 0, maximum) or nil
end

local function activeAura()
    if not (C_UnitAuras
        and type(C_UnitAuras.GetUnitAuras) == "function") then return nil end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok or type(list) ~= "table" or table.getn(list) > 40 then return nil end
    local active, index = 0, nil
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table"
            and integer(aura.spellId, 1, 4294967295) or nil
        if not spellId then return nil end
        if spellId == W.AURA_ID then active = active + 1 end
    end
    if active > 1 then return nil end
    return active == 1
end

-- Group membership is exact, but group recipient attribution/fanout is not.
-- Grouped roots are therefore reported and rejected by the graph leaf.
function W:ObserveRoot()
    local out = { available = false, exact = false,
        source = "exact group membership and numeric player aura identity" }
    if classToken() ~= "SHAMAN" then
        out.reason = "player is not an exactly identified Shaman"
        return out
    end
    local raid = groupCount(GetNumRaidMembers, 40)
    local party = groupCount(GetNumPartyMembers, 4)
    if raid == nil or party == nil then
        out.reason = "group membership evidence unavailable"
        return out
    end
    out.raidMembers, out.partyMembers = raid, party
    out.grouped, out.solo = raid > 0 or party > 0, raid == 0 and party == 0
    if out.grouped then
        out.available, out.exact = true, true
        out.reason = "Windfury Totem party fanout is unresolved"
        return out
    end
    local active = activeAura()
    if active == nil then
        out.reason = "numeric Windfury aura evidence unavailable"
        return out
    end
    out.available, out.exact, out.auraActive = true, true, active
    return out
end

function W:Invalidate()
    PROFILE_CACHE = nil
end
