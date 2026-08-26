-- Exact build-5875 Frenzied Regeneration identity and root contract. The
-- server converts at most ten displayed rage into rank-scaled self-healing
-- every second. Mutable DBC, modifier, aura, and clock reads stop at root.
XelAssist.Game.Player.DruidFrenziedRegeneration = {}
local F = XelAssist.Game.Player.DruidFrenziedRegeneration

F.RANKS = {
    [22842] = { rank = 1, level = 36, lifePerRage = 6 },
    [22895] = { rank = 2, level = 46, lifePerRage = 7 },
    [22896] = { rank = 3, level = 56, lifePerRage = 8 },
}
F.TRIGGER_ID = 22845
F.DRUID_FAMILY, F.RAGE = 7, 1
F.BEAR_FORM, F.DIRE_BEAR_FORM = 5, 8
F.STANCE_MASK, F.PERIODIC_TRIGGER = 144, 23
F.DURATION, F.PERIOD, F.TICKS, F.RAGE_PER_TICK = 10, 1, 10, 10
F.ALL_EFFECTS_MOD, F.DAMAGE_MOD, F.ACTIVATION_TIME_MOD = 8, 0, 19
F.HEALING_TAKEN_PERCENT, F.HEALING_DONE_PERCENT = 118, 136
F.HEALING_THREAT, F.SPELL_THREAT_MULTIPLIER = 0.5, 1
F.SERVER_PROFILE = "VMaNGOS e5f3fd0 Frenzied Regeneration periodic handler"

local PROFILES, TRIGGER_PROFILE = {}, nil

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

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    return signed and signed32(value) or finite(value, 0, 4294967295)
end

-- SpellFamilyFlags is the one installed scalar wider than an unsigned DBC
-- word. Lua's double represents this build-5875 value exactly below 2^53;
-- other scalar fields retain the tighter unsigned-32 boundary above.
local function familyFlags(spellId)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, "spellFamilyFlags")
    if not ok then return nil end
    return finite(value, 0, 9007199254740991)
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
            or finite(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function scalarsMatch(spellId, rank)
    local expected = {
        school = 0, category = 1011, attributes = 262160,
        attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, stances = F.STANCE_MASK, stancesNot = 0,
        castingTimeIndex = 1, categoryRecoveryTime = 300000,
        durationIndex = 1, powerType = F.RAGE, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = 0, rangeIndex = 1,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        spellFamilyName = F.DRUID_FAMILY, maxAffectedTargets = 0,
        dmgClass = 0, preventionType = 2, baseLevel = rank.level,
        spellLevel = rank.level,
    }
    local field, value
    for field, value in pairs(expected) do
        if scalar(spellId, field) ~= value then return false end
    end
    return familyFlags(spellId) == 4398046511104
end

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"),
            rank.lifePerRage - 1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"),
            F.PERIODIC_TRIGGER, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 1000, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue", true), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function triggerTopology()
    if TRIGGER_PROFILE ~= nil then return TRIGGER_PROFILE == true end
    local expected = { school = 0, category = 0, attributes = 262160,
        attributesEx = 0, attributesEx2 = 268435456,
        attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
        durationIndex = 0, powerType = 0, rangeIndex = 1,
        equippedItemClass = -1, spellFamilyName = 0,
        spellFamilyFlags = 0, dmgClass = 0, preventionType = 0 }
    local field, value
    for field, value in pairs(expected) do
        if scalar(F.TRIGGER_ID, field, field == "equippedItemClass") ~= value then
            TRIGGER_PROFILE = false; return false
        end
    end
    local valid = equal(triple(F.TRIGGER_ID, "effect"), 10, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectDieSides"), 1, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectBaseDice"), 1, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectBasePoints"), 0, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(F.TRIGGER_ID, "effectTriggerSpell"), 0, 0, 0)
    TRIGGER_PROFILE = valid and true or false
    return valid
end

local function baseDuration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    return ok and integer(milliseconds, 1, 60000) or nil
end

local function installedProfile(spellId)
    local rank = F.RANKS[spellId]
    if not rank then return nil, "spell is not installed Frenzied Regeneration" end
    if PROFILES[spellId] then return copy(PROFILES[spellId]) end
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and triggerTopology() and baseDuration(spellId) == 10000) then
        return nil, "Frenzied Regeneration DBC topology is incomplete"
    end
    local out = { recognized = true, valid = true, exact = true,
        spellId = spellId, rank = rank.rank, level = rank.level,
        lifePerRage = rank.lifePerRage, triggerSpellId = F.TRIGGER_ID,
        family = F.DRUID_FAMILY, powerType = F.RAGE, cost = 0,
        stanceMask = F.STANCE_MASK, duration = F.DURATION,
        period = F.PERIOD, ticks = F.TICKS,
        ragePerTick = F.RAGE_PER_TICK, noCritical = true,
        coefficient = 0, healingThreat = F.HEALING_THREAT,
        spellThreatMultiplier = F.SPELL_THREAT_MULTIPLIER,
        serverProfileExact = true, runtimeVerified = false,
        source = "installed build-5875 DBC plus " .. F.SERVER_PROFILE }
    PROFILES[spellId] = copy(out)
    return copy(out)
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function modifier(spellId, operation)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, operation)
    flat, percent, changed = signed32(flat), signed32(percent),
        integer(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then return nil end
    return flat == 0 and percent == 0 and changed == 0
        and { flat = 0, percent = 0, changed = 0 } or nil
end

local function cleanSpellModifiers(spellId)
    local all = modifier(spellId, F.ALL_EFFECTS_MOD)
    local activation = all and modifier(spellId, F.ACTIVATION_TIME_MOD)
    local triggerAll = activation and modifier(F.TRIGGER_ID, F.ALL_EFFECTS_MOD)
    local triggerDamage = triggerAll and modifier(F.TRIGGER_ID, F.DAMAGE_MOD)
    if not triggerDamage then
        return nil, "modified Frenzied Regeneration is unresolved"
    end
    return { allEffects = all, activationTime = activation,
        triggerAllEffects = triggerAll, triggerDamage = triggerDamage }
end

local function cleanHealingAuras()
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        return nil, "player healing aura evidence unavailable"
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player")
    if not ok or type(list) ~= "table" or table.getn(list) > 48 then
        return nil, "player healing aura evidence unavailable"
    end
    local index, aura, spellId, types, count, key = nil, nil, nil, nil, 0, nil
    for key in pairs(list) do
        if integer(key, 1, 48) == nil then
            return nil, "player healing aura evidence incomplete"
        end
        count = count + 1
    end
    if count ~= table.getn(list) then
        return nil, "player healing aura evidence incomplete"
    end
    for index = 1, table.getn(list) do
        aura = list[index]
        spellId = type(aura) == "table"
            and integer(aura.spellId, 1, 4294967295) or nil
        if not spellId then return nil, "player healing aura evidence incomplete" end
        types = triple(spellId, "effectApplyAuraName")
        if not types then return nil, "player healing aura topology unavailable" end
        if types[1] == F.HEALING_TAKEN_PERCENT
            or types[2] == F.HEALING_TAKEN_PERCENT
            or types[3] == F.HEALING_TAKEN_PERCENT
            or types[1] == F.HEALING_DONE_PERCENT
            or types[2] == F.HEALING_DONE_PERCENT
            or types[3] == F.HEALING_DONE_PERCENT then
            return nil, "Frenzied Regeneration healing multiplier is unresolved"
        end
    end
    return { exact = true, scanned = table.getn(list), cap = 48 }
end

local function capturedProfile(found)
    local modifiers, reason = cleanSpellModifiers(found.spellId)
    local healing = modifiers and cleanHealingAuras() or nil
    local effective
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, found.spellId)
        effective = ok and integer(value, 1, 60000) or nil
    end
    if not modifiers or not healing or effective ~= 10000 then
        return nil, reason or not healing
            and "Frenzied Regeneration healing modifier evidence unavailable"
            or "Frenzied Regeneration effective duration is unresolved"
    end
    local out = copy(found)
    out.modifiers, out.healingAuras = modifiers, healing
    out.captureExact, out.effectiveDuration = true, effective / 1000
    return out
end

local function evidence(subject, captured)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.druidFrenziedRegenerationEvidence
    if not (facts and facts.druidFrenziedRegeneration == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and F.RANKS[found.spellId]
        and found.lifePerRage == F.RANKS[found.spellId].lifePerRage
        and found.rank == F.RANKS[found.spellId].rank
        and found.level == F.RANKS[found.spellId].level
        and found.triggerSpellId == F.TRIGGER_ID and found.family == F.DRUID_FAMILY
        and found.powerType == F.RAGE and found.cost == 0
        and found.stanceMask == F.STANCE_MASK and found.duration == F.DURATION
        and found.period == F.PERIOD and found.ticks == F.TICKS
        and found.ragePerTick == F.RAGE_PER_TICK
        and found.noCritical == true and found.coefficient == 0
        and found.healingThreat == F.HEALING_THREAT
        and found.spellThreatMultiplier == F.SPELL_THREAT_MULTIPLIER
        and found.serverProfileExact == true
        and found.runtimeVerified == false) then return nil end
    if captured and not (found.captureExact == true
        and found.effectiveDuration == F.DURATION and found.modifiers
        and found.modifiers.allEffects and found.modifiers.allEffects.flat == 0
        and found.modifiers.allEffects.percent == 0
        and found.modifiers.allEffects.changed == 0
        and found.modifiers.activationTime
        and found.modifiers.activationTime.flat == 0
        and found.modifiers.activationTime.percent == 0
        and found.modifiers.activationTime.changed == 0
        and found.modifiers.triggerAllEffects
        and found.modifiers.triggerAllEffects.flat == 0
        and found.modifiers.triggerAllEffects.percent == 0
        and found.modifiers.triggerAllEffects.changed == 0
        and found.modifiers.triggerDamage
        and found.modifiers.triggerDamage.flat == 0
        and found.modifiers.triggerDamage.percent == 0
        and found.modifiers.triggerDamage.changed == 0
        and found.healingAuras and found.healingAuras.exact == true
        and integer(found.healingAuras.scanned, 0, 48) ~= nil
        and found.healingAuras.cap == 48) then return nil end
    return found
end

function F:InferKnowledge(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not self.RANKS[spellId] then
        return nil, "spell is not installed Frenzied Regeneration", false
    end
    if classToken() ~= "DRUID" then
        return nil, "player is not an exactly identified Druid", false
    end
    local found, reason = installedProfile(spellId)
    if not found then return nil, reason, true end
    return { inferred = true, kind = "heal", kindExact = true,
        self = true, fixedTarget = "player", recipientRelation = "friendly",
        recipientRelationExact = true, resourceType = "rage",
        druidFrenziedRegeneration = true,
        requiresExactDruidFrenziedRegeneration = true,
        requiresExactUsability = true, submissionGuarded = true,
        runtimeUnverified = true,
        healingThreatActor = "player", threat = found.healingThreat,
        druidFrenziedRegenerationEvidence = copy(found) }, nil, true
end

function F:CaptureFacts(action, facts)
    local base = action and evidence(action) or evidence(facts)
    if not base then return facts end
    facts = copy(facts or {})
    local found, reason = capturedProfile(base)
    facts.druidFrenziedRegeneration = true
    facts.druidFrenziedRegenerationEvidence = found or {
        recognized = true, valid = false, exact = false,
        spellId = base.spellId, reason = reason,
    }
    if found then
        facts.cost, facts.powerType, facts.cast, facts.gcd = 0, self.RAGE, 0, 1.5
        facts.duration, facts.healingThreatActor, facts.threat =
            self.DURATION, "player", found.healingThreat
    end
    return facts
end

function F:Evidence(subject) return evidence(subject, false) end
function F:CapturedEvidence(subject)
    local found = evidence(subject, true)
    return found, found and nil
        or "Frenzied Regeneration root evidence unavailable"
end

local function activeAura()
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        return nil, "Frenzied Regeneration aura evidence unavailable"
    end
    local found, spellId, aura, rank
    for spellId, rank in pairs(F.RANKS) do
        local ok, value = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
        if not ok then return nil, "Frenzied Regeneration aura evidence unavailable" end
        if value ~= nil then
            if found then return nil, "multiple Frenzied Regeneration auras observed" end
            found, aura = spellId, value
        end
    end
    return found, nil, aura
end

function F:Snapshot(knownClass)
    local out = { available = false, exact = false, active = false,
        source = "numeric Frenzied Regeneration player aura" }
    if knownClass ~= "DRUID" and classToken() ~= "DRUID" then
        out.reason = "player is not an exactly identified Druid"; return out
    end
    local spellId, reason, aura = activeAura()
    if reason then out.reason = reason; return out end
    out.available, out.exact = true, true
    if not spellId then return out end
    if type(GetTime) ~= "function" then
        out.available, out.exact = false, false
        out.reason = "Frenzied Regeneration aura clock unavailable"; return out
    end
    local profile = installedProfile(spellId)
    local ok, now = pcall(GetTime)
    now = ok and finite(now, 0, 1000000000) or nil
    local duration = type(aura) == "table"
        and finite(aura.duration, 0.001, F.DURATION) or nil
    local expiration = type(aura) == "table" and now
        and finite(aura.expirationTime, now, now + F.DURATION) or nil
    if not (profile and now and duration and expiration and expiration > now
        and integer(aura.spellId, 1, 4294967295) == spellId
        and aura.isHelpful == true and integer(aura.applications, 1, 1) == 1) then
        out.available, out.exact = false, false
        out.reason = "active Frenzied Regeneration aura evidence is incomplete"
        return out
    end
    out.active, out.spellId, out.remaining = true, spellId, expiration - now
    out.duration, out.phaseKnown, out.epoch = duration, false, expiration
    out.available, out.exact = false, false
    out.reason = "active Frenzied Regeneration tick phase unavailable"
    return out
end

function F:IsBearForm(formID)
    return formID == self.BEAR_FORM or formID == self.DIRE_BEAR_FORM
end

function F:Invalidate()
    PROFILES, TRIGGER_PROFILE = {}, nil
end
