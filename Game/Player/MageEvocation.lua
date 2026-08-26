-- Explicit fail-closed contract for Octo Evocation. Its DBC enables mana
-- regeneration rather than carrying periodic mana amounts or cadence. Exact
-- value therefore depends on Spirit/MP5 regime and the player-global tick
-- phase; custom Mage talents add cooldown/timing and full-channel branches.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.MageEvocation = {}
local E = XelAssist.Game.Player.MageEvocation

E.SPELL_ID = 12051
E.ACCELERATED_ARCANA_ID = 51981
E.EVOCATION_MASTERY_ID = 52586
E.NETHER_OVERCHARGE_ID = 52594
E.NETHER_OVERCHARGE_EFFECT_ID = 52595

local PROFILE

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

local function learned(id)
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, id)
    if not ok then return nil end
    return value == true or value == 1
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function evocationTopology()
    return scalar(E.SPELL_ID, "school") == 6
        and scalar(E.SPELL_ID, "attributes") == 65536
        and scalar(E.SPELL_ID, "attributesEx") == 64
        and scalar(E.SPELL_ID, "recoveryTime") == 480000
        and scalar(E.SPELL_ID, "durationIndex") == 31
        and scalar(E.SPELL_ID, "spellFamilyName") == 3
        and scalar(E.SPELL_ID, "spellFamilyFlags") == 67108864
        and equal(triple(E.SPELL_ID, "effect"), 6, 6, 0)
        and equal(triple(E.SPELL_ID, "effectApplyAuraName"), 110, 134, 0)
        and equal(triple(E.SPELL_ID, "effectBasePoints"), 1499, 99, 0)
        and equal(triple(E.SPELL_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(E.SPELL_ID, "effectAmplitude"), 0, 0, 0)
end

local function acceleratedTopology()
    local id = E.ACCELERATED_ARCANA_ID
    return scalar(id, "attributes") == 464
        and scalar(id, "spellFamilyName") == 3
        and equal(triple(id, "effect"), 6, 6, 6)
        and equal(triple(id, "effectApplyAuraName"), 108, 108, 108)
        and equal(triple(id, "effectBasePoints"), -6, -6, -6)
        and equal(triple(id, "effectMiscValue"), 1, 19, 1)
end

local function masteryTopology()
    local id = E.EVOCATION_MASTERY_ID
    return scalar(id, "attributes") == 464
        and scalar(id, "procFlags") == 65536
        and scalar(id, "procChance") == 100
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 42, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 52591, 0, 0)
end

local function overchargeTopology()
    local id, effect = E.NETHER_OVERCHARGE_ID,
        E.NETHER_OVERCHARGE_EFFECT_ID
    return scalar(id, "attributes") == 464
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 4, 0, 0)
        and equal(triple(effect, "effect"), 6, 6, 0)
        and equal(triple(effect, "effectApplyAuraName"), 79, 72, 0)
        and equal(triple(effect, "effectBasePoints"), 9, 9, 0)
        and equal(triple(effect, "effectMiscValue"), 126, 126, 0)
end

local function profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    PROFILE = { recognized = true, valid = false, exact = false,
        spellId = E.SPELL_ID,
        source = "installed patch-5 Evocation and linked Mage talent DBC" }
    if not evocationTopology() then
        PROFILE.reason = "Evocation DBC topology is incomplete"
        return nil, PROFILE.reason
    end
    local accelerated, mastery, overcharge = learned(E.ACCELERATED_ARCANA_ID),
        learned(E.EVOCATION_MASTERY_ID), learned(E.NETHER_OVERCHARGE_ID)
    if accelerated == nil or mastery == nil or overcharge == nil then
        PROFILE.reason = "Evocation talent knowledge unavailable"
        return nil, PROFILE.reason
    end
    if accelerated and not acceleratedTopology()
        or mastery and not masteryTopology()
        or overcharge and not overchargeTopology() then
        PROFILE.reason = "Evocation linked talent topology is incomplete"
        return nil, PROFILE.reason
    end
    PROFILE.valid, PROFILE.exact = true, true
    PROFILE.channel = true
    PROFILE.baseCooldown = 480
    PROFILE.tickAmountSource = "dynamic Spirit and MP5 regeneration regime"
    PROFILE.tickTimingSource = "player-global mana tick phase"
    PROFILE.periodicAmplitudeAbsent = true
    PROFILE.acceleratedArcanaActive = accelerated
    PROFILE.evocationMasteryActive = mastery
    PROFILE.netherOverchargeActive = overcharge
    PROFILE.completionRequiredForNetherOvercharge = overcharge and true or false
    PROFILE.interruptionSuppressesNetherOvercharge = overcharge and true or false
    PROFILE.fullChannelConsequenceModeled = false
    return copy(PROFILE)
end

function E:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "spell is not Evocation", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    local blockers = { "Spirit/MP5 mana amount", "player-global mana phase" }
    if found.acceleratedArcanaActive then
        table.insert(blockers, "Accelerated Arcana effective tick timing")
    end
    if found.evocationMasteryActive then
        table.insert(blockers, "Evocation Mastery cooldown stacks")
    end
    if found.netherOverchargeActive then
        table.insert(blockers, "full-channel Nether Overcharge branch")
    end
    return { inferred = true, kind = "resource", kindExact = true,
        self = true, channel = true, cooldown = true,
        mageEvocation = true, mageEvocationEvidence = found,
        unmodeledUnsafe = "Evocation dynamic mana/timing consequences are not modeled",
        unsafeDependencies = blockers, source = found.source }, nil, true
end

function E:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.mageEvocationEvidence
    if not (facts and facts.mageEvocation == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.periodicAmplitudeAbsent == true
        and found.fullChannelConsequenceModeled == false) then return nil end
    return copy(found)
end

function E:Invalidate() PROFILE = nil end
