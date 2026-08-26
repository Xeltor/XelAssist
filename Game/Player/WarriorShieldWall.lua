-- Exact installed Shield Wall identity and root-only aura contract.  The
-- action is discovered from numeric DBC topology; localized names never
-- select it. Mutable duration, modifier, and aura APIs are sealed before
-- graph search so descendants remain API-pure.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorShieldWall = {}
local W = XelAssist.Game.Player.WarriorShieldWall

W.SPELL_ID = 871
W.WARRIOR_FAMILY = 4
W.FAMILY_FLAG = 8192
W.DEFENSIVE_STANCE_MASK = 131072
W.RAGE = 1
W.APPLY_AURA = 6
W.DAMAGE_PERCENT_TAKEN = 87
W.ALL_SCHOOLS = 127
W.ALL_EFFECTS_MOD = 8
W.SERVER_PROFILE = "VMaNGOS e5f3fd0 build-5875 damage-taken multiplier"

local PROFILE_CACHE = nil

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
    if value and value > 2147483647 then value = value - 4294967296 end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, W.SPELL_ID, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, W.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -4294967295, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local SCALARS = {
    school = 0, category = 132, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 131072, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0,
    stances = 131072, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 1800000,
    interruptFlags = 0, auraInterruptFlags = 0,
    channelInterruptFlags = 0, procFlags = 0, procChance = 101,
    procCharges = 0, maxLevel = 0, baseLevel = 28, spellLevel = 28,
    durationIndex = 1, powerType = 1, manaCost = 0,
    manaCostPerlevel = 0, manaPerSecond = 0,
    manaPerSecondPerLevel = 0, rangeIndex = 1, speed = 0,
    modalNextSpell = 0, stackAmount = 0, equippedItemClass = 4,
    equippedItemSubClassMask = 64, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 8192,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
}

local function scalarsMatch()
    local field, expected
    for field, expected in pairs(SCALARS) do
        if scalar(field) ~= expected then return false end
    end
    return true
end

local function arraysMatch()
    return equal(triple("effect"), W.APPLY_AURA, 0, 0)
        and equal(triple("effectDieSides"), 1, 0, 0)
        and equal(triple("effectBaseDice"), 1, 0, 0)
        and equal(triple("effectDicePerLevel"), 0, 0, 0)
        and equal(triple("effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple("effectBasePoints"), -76, 0, 0)
        and equal(triple("effectMechanic"), 0, 0, 0)
        and equal(triple("effectImplicitTargetA"), 1, 0, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectRadiusIndex"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"),
            W.DAMAGE_PERCENT_TAKEN, 0, 0)
        and equal(triple("effectAmplitude"), 0, 0, 0)
        and equal(triple("effectMultipleValue"), 0, 0, 0)
        and equal(triple("effectChainTarget"), 0, 0, 0)
        and equal(triple("effectItemType"), 0, 0, 0)
        and equal(triple("effectMiscValue"), W.ALL_SCHOOLS, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
        and equal(triple("effectPointsPerComboPoint"), 0, 0, 0)
end

local function baseDuration()
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, W.SPELL_ID, 1)
    return ok and integer(value, 1, 60000) or nil
end

local function installedProfile()
    if PROFILE_CACHE then return copy(PROFILE_CACHE), nil end
    if not (scalarsMatch() and arraysMatch() and baseDuration() == 10000) then
        return nil, "Shield Wall DBC topology is incomplete"
    end
    local out = { recognized = true, valid = true, exact = true,
        spellId = W.SPELL_ID, family = W.WARRIOR_FAMILY,
        familyFlag = W.FAMILY_FLAG, stanceMask = W.DEFENSIVE_STANCE_MASK,
        powerType = W.RAGE, cost = 0, baseDuration = 10,
        auraType = W.DAMAGE_PERCENT_TAKEN, schoolMask = W.ALL_SCHOOLS,
        damageTakenPercent = -75, damageTakenMultiplier = 0.25,
        equipmentClass = 4, equipmentSubclassMask = 64,
        serverProfileExact = true, runtimeVerified = false,
        source = "installed build-5875 Shield Wall DBC plus "
            .. W.SERVER_PROFILE }
    PROFILE_CACHE = copy(out)
    return copy(out), nil
end

local function staticEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorShieldWallEvidence
    if not (facts and facts.warriorShieldWall == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == W.SPELL_ID
        and found.family == W.WARRIOR_FAMILY
        and found.familyFlag == W.FAMILY_FLAG
        and found.stanceMask == W.DEFENSIVE_STANCE_MASK
        and found.powerType == W.RAGE and found.cost == 0
        and found.baseDuration == 10
        and found.auraType == W.DAMAGE_PERCENT_TAKEN
        and found.schoolMask == W.ALL_SCHOOLS
        and found.damageTakenPercent == -75
        and found.damageTakenMultiplier == 0.25
        and found.equipmentClass == 4
        and found.equipmentSubclassMask == 64
        and found.serverProfileExact == true
        and found.runtimeVerified == false) then return nil end
    return found
end

local function cleanMagnitude()
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Shield Wall magnitude modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, W.SPELL_ID, W.ALL_EFFECTS_MOD)
    flat, percent, changed = signed32(flat), signed32(percent),
        integer(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "Shield Wall magnitude modifier evidence unavailable"
    end
    if flat ~= 0 or percent ~= 0 or changed ~= 0 then
        return nil, "modified Shield Wall magnitude is unresolved"
    end
    return { flat = 0, percent = 0, changed = 0 }
end

local function effectiveDuration()
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, W.SPELL_ID)
    value = ok and integer(value, 1, 60000) or nil
    return value and value / 1000 or nil
end

local function capturedProfile(found)
    local modifier, reason = cleanMagnitude()
    local duration = modifier and effectiveDuration() or nil
    if not duration then
        return nil, reason or "Shield Wall effective duration unavailable"
    end
    local out = copy(found)
    out.duration, out.allEffectsModifier = duration, modifier
    out.captureExact = true
    out.source = out.source .. "; root effective duration and clean magnitude"
    return out, nil
end

local function validContract(found)
    return type(found) == "table" and found.captureExact == true
        and found.valid == true and found.exact == true
        and found.spellId == W.SPELL_ID and found.duration
        and found.duration >= 0.001 and found.duration <= 60
        and found.damageTakenMultiplier == 0.25
        and found.damageTakenPercent == -75
        and found.schoolMask == W.ALL_SCHOOLS
        and found.auraType == W.DAMAGE_PERCENT_TAKEN
        and found.allEffectsModifier
        and found.allEffectsModifier.flat == 0
        and found.allEffectsModifier.percent == 0
        and found.allEffectsModifier.changed == 0 and found or nil
end

local function observeAura(profile)
    local out = { available = false, exact = false, active = false,
        profile = copy(profile), source = "numeric player Shield Wall aura" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function")
        or type(GetTime) ~= "function" then
        out.reason = "Shield Wall aura evidence unavailable"; return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, W.SPELL_ID)
    local timeOK, now = pcall(GetTime)
    now = timeOK and finite(now, 0, 1000000000) or nil
    if not ok or not now then
        out.reason = "Shield Wall aura evidence unavailable"; return out
    end
    out.available, out.exact = true, true
    if aura == nil then return out end
    local duration = type(aura) == "table"
        and finite(aura.duration, 0.001, profile.duration) or nil
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime, now, now + profile.duration) or nil
    if integer(aura and aura.spellId, 1, 4294967295) ~= W.SPELL_ID
        or aura.isHelpful ~= true
        or integer(aura.applications, 1, 1) ~= 1
        or not duration or not expiration or expiration <= now
        or expiration - now > duration + 0.001 then
        out.available, out.exact = false, false
        out.reason = "active Shield Wall aura evidence is incomplete"
        return out
    end
    out.active, out.duration = true, duration
    out.remaining, out.epoch = expiration - now, expiration
    return out
end

function W:InferKnowledge(spellId)
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "spell is not installed Shield Wall", false
    end
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason = installedProfile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "defensive", kindExact = true,
        self = true, fixedTarget = "player", recipientRelation = "friendly",
        recipientRelationExact = true, resourceType = "rage", cooldown = true,
        combatBuff = true, warriorShieldWall = true,
        requiresExactWarriorShieldWall = true,
        requiresExactUsability = true, submissionGuarded = true,
        runtimeUnverified = true, stances = found.stanceMask,
        equippedItemClass = found.equipmentClass,
        equippedItemSubClassMask = found.equipmentSubclassMask,
        equippedItemInventoryTypeMask = 0,
        warriorShieldWallEvidence = copy(found), source = found.source }, nil, true
end

function W:CaptureFacts(action, facts)
    local found = staticEvidence(facts)
    if not found then return facts end
    local out, profile, reason = copy(facts), nil, nil
    profile, reason = capturedProfile(found)
    out.warriorShieldWallProfile = profile
    out.warriorShieldWallCaptureExact = profile ~= nil
    out.warriorShieldWallCaptureReason = reason
    out.cost, out.powerType = 0, self.RAGE
    return out
end

function W:Evidence(subject)
    local found = staticEvidence(subject)
    return found and copy(found) or nil
end

function W:CapturedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local static = staticEvidence(facts)
    local found = static and validContract(
        facts and facts.warriorShieldWallProfile) or nil
    if not found then return nil, facts and facts.warriorShieldWallCaptureReason
        or "Shield Wall captured evidence unavailable" end
    return copy(found), nil
end

function W:Snapshot(knownClass)
    if (knownClass or classToken()) ~= "WARRIOR" then return nil end
    local found, reason = installedProfile()
    local profile
    if found then profile, reason = capturedProfile(found) end
    if not profile then return { available = false, exact = false,
        active = false, reason = reason,
        source = "installed Shield Wall root evidence" } end
    return observeAura(profile)
end

function W:Is(subject)
    return staticEvidence(subject) ~= nil
end

function W:Invalidate()
    PROFILE_CACHE = nil
end
