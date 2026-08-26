-- Exact Power Word: Shield lockout evidence. VMaNGOS applies spell 6788 on a
-- successful shield hit; installed DBC topology proves both the shield family
-- and the linked Weakened Soul aura without using localized names or ranks.
XelAssist.Game.Player.PriestShield = {}
local P = XelAssist.Game.Player.PriestShield

P.PRIEST_FAMILY = 6
P.SHIELD_FLAGS = 1
P.LOCKOUT_FLAGS = 536870912
P.LOCKOUT_SPELL_ID = 6788
P.PROJECTION_KEY = "__xel_priest_shield_lockout"
P.MAX_AURAS = 40
P.MAX_CACHE = 256

local CACHE, CACHE_COUNT, LOCKOUT_CACHE = {}, 0, nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
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
        out[index] = integer(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and finite(milliseconds) or nil
    if not milliseconds or milliseconds <= 0 then return nil end
    return milliseconds / 1000
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function identity(unit)
    if type(unit) ~= "string" or type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not (exists == true or exists == 1) then return nil end
    if not validGUID(guid) and type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, unit)
        if not ok then guid = nil end
    end
    return validGUID(guid) and guid or nil
end

local function lockoutEvidence()
    if LOCKOUT_CACHE then return copy(LOCKOUT_CACHE) end
    local spellId = P.LOCKOUT_SPELL_ID
    local effects = triple(spellId, "effect")
    local auras = triple(spellId, "effectApplyAuraName")
    local targets = triple(spellId, "effectImplicitTargetA")
    local misc = triple(spellId, "effectMiscValue")
    local lifetime = duration(spellId)
    if scalar(spellId, "spellFamilyName") ~= P.PRIEST_FAMILY
        or scalar(spellId, "spellFamilyFlags") ~= P.LOCKOUT_FLAGS
        or not equal(effects, 6, 0, 0)
        or not equal(auras, 77, 0, 0)
        or not equal(targets, 25, 0, 0)
        or not equal(misc, 19, 0, 0) or not lifetime then
        return nil
    end
    LOCKOUT_CACHE = { valid = true, exact = true, spellId = spellId,
        duration = lifetime, family = P.PRIEST_FAMILY,
        familyFlags = P.LOCKOUT_FLAGS, auraType = 77, mechanic = 19,
        source = "installed DBC plus VMaNGOS Power Word Shield hit script" }
    return copy(LOCKOUT_CACHE)
end

local function classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "spell identity unavailable", false end
    local cached = CACHE[spellId]
    if cached then
        return cached.found and copy(cached.found) or nil,
            cached.reason, cached.recognized
    end
    local family, flags = scalar(spellId, "spellFamilyName"),
        scalar(spellId, "spellFamilyFlags")
    if family == nil or flags == nil then
        return nil, "Priest DBC family evidence unavailable", false
    end
    local recognized = family == P.PRIEST_FAMILY and flags == P.SHIELD_FLAGS
    local found, reason
    if not recognized then reason = "spell is not Power Word Shield"
    else
        local lockout = lockoutEvidence()
        local effects = triple(spellId, "effect")
        local auras = triple(spellId, "effectApplyAuraName")
        local targetsA = triple(spellId, "effectImplicitTargetA")
        local targetsB = triple(spellId, "effectImplicitTargetB")
        local misc = triple(spellId, "effectMiscValue")
        local triggers = triple(spellId, "effectTriggerSpell")
        local lifetime = duration(spellId)
        if lockout and equal(effects, 6, 0, 0)
            and equal(auras, 69, 0, 0)
            and equal(targetsA, 57, 0, 0)
            and equal(targetsB, 0, 0, 0)
            and equal(misc, 127, 0, 0)
            and equal(triggers, 0, 0, 0)
            and scalar(spellId, "powerType") == 0 and lifetime then
            found = { valid = true, exact = true, spellId = spellId,
                family = family, familyFlags = flags, auraType = 69,
                schoolMask = misc[1], duration = lifetime,
                lockoutSpellId = lockout.spellId,
                lockoutDuration = lockout.duration,
                source = lockout.source }
        else reason = "Power Word Shield DBC or lockout topology is incomplete" end
    end
    if CACHE_COUNT < P.MAX_CACHE then
        CACHE[spellId] = { found = found and copy(found) or nil,
            reason = reason, recognized = recognized }
        CACHE_COUNT = CACHE_COUNT + 1
    end
    return found, reason, recognized
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestShieldEvidence
    if not (facts and facts.priestShield == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.family == P.PRIEST_FAMILY
        and found.familyFlags == P.SHIELD_FLAGS and found.auraType == 69
        and found.schoolMask == 127
        and found.lockoutSpellId == P.LOCKOUT_SPELL_ID
        and found.lockoutDuration and found.lockoutDuration > 0) then return nil end
    return found
end

function P:InferKnowledge(spellId)
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    local found, reason, recognized = classify(spellId)
    if not found then return nil, reason, recognized == true end
    return { inferred = true, kind = "absorb", kindExact = true,
        recipientRelation = "friendly", recipientRelationExact = true,
        priestShield = true, appliesWeakenedSoul = true,
        requiresPriestShieldEvidence = true, submissionGuarded = true,
        priestShieldEvidence = copy(found), source = found.source }, nil, true
end

local function auraSpellId(value)
    value = integer(value, -65535, 4294967295)
    if value and value < -1 then value = value + 65536 end
    return integer(value, 1, 4294967295)
end

function P:Observe(unit, expectedGUID)
    local out = { known = false, active = false, complete = false,
        unit = unit, recipientGUID = expectedGUID,
        source = "ClassicAPI harmful aura identity" }
    if classToken() ~= "PRIEST" then
        out.reason = "player is not an exactly identified Priest"
        return out
    end
    local before = identity(unit)
    if not validGUID(expectedGUID) or before ~= expectedGUID then
        out.reason = "Priest shield recipient identity unavailable"
        return out
    end
    if not (C_UnitAuras
        and type(C_UnitAuras.GetUnitAuras) == "function") then
        out.reason = "Priest harmful aura observation unavailable"
        return out
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL")
    local after = identity(unit)
    if after ~= before then
        out.reason = "Priest shield recipient changed during observation"
        return out
    end
    if not ok or type(list) ~= "table" then
        out.reason = "Priest harmful aura observation unavailable"
        return out
    end
    if table.getn(list) > self.MAX_AURAS then
        out.reason = "Priest harmful aura observation budget exceeded"
        return out
    end
    local complete, index, aura = true, nil, nil
    for index = 1, table.getn(list) do
        aura = list[index]
        local spellId = type(aura) == "table"
            and auraSpellId(aura.spellId) or nil
        if not spellId then complete = false end
        if spellId == self.LOCKOUT_SPELL_ID then
            out.active, out.known = true, true
            out.spellId = spellId
            local expiration = finite(aura.expirationTime)
            local now
            if type(GetTime) == "function" then
                local timeOK, value = pcall(GetTime)
                now = timeOK and finite(value) or nil
            end
            if expiration and expiration > 0 and now then
                out.remaining = math.max(0, expiration - now)
            end
        end
    end
    out.complete = complete
    if not out.active and complete then out.known = true end
    if not out.known then out.reason = "Weakened Soul identity evidence incomplete" end
    return out
end

local function recipientKey(descriptor)
    if type(descriptor) ~= "table" then return nil end
    return descriptor.key or descriptor.guid or descriptor.unit
end

function P:Capture(observed, action, descriptor)
    if not evidence(action) then return false, nil end
    local key = recipientKey(descriptor)
    if type(observed) ~= "table" or not key or not descriptor.unit
        or descriptor.relation == "hostile" then return true, nil end
    observed.priestShieldEvidence = observed.priestShieldEvidence or {}
    local record = observed.priestShieldEvidence[key]
    if not record then
        record = self:Observe(descriptor.unit, descriptor.guid)
        observed.priestShieldEvidence[key] = record
    end
    return true, record
end

local function projectedRecord(state, descriptor)
    local record = descriptor and descriptor.record
    if not record and state and state.friendlies and state.friendlies.byKey then
        record = state.friendlies.byKey[recipientKey(descriptor)]
    end
    return record and record.auras and record.auras[P.PROJECTION_KEY] or nil
end

local function rootRecord(state, descriptor)
    local root = state and state.rootObservation
    local records = root and root.priestShieldEvidence
    return records and records[recipientKey(descriptor)] or nil
end

function P:Blocker(action, state, descriptor)
    if not evidence(action) then return nil, false end
    local projected = projectedRecord(state, descriptor)
    if projected then
        local probability = finite(projected.applicationProbability) or 1
        local expiresAt = finite(projected.expiresAt)
        if probability >= 0.75 and (not expiresAt
            or expiresAt > (finite(state and state.time) or 0)) then
            return "Weakened Soul active", true
        end
    end
    local record = rootRecord(state, descriptor)
    if not (record and record.known == true) then
        return "Weakened Soul evidence unknown", true
    end
    if record.active then
        local remaining = finite(record.remaining)
        if not remaining or (finite(state and state.time) or 0) < remaining then
            return "Weakened Soul active", true
        end
    end
    return nil, true
end

function P:Apply(state, candidate)
    local action = candidate and candidate.action
    local found = evidence(action)
    local key = candidate and candidate.targetKey
    local records = state and state.friendlies and state.friendlies.byKey
    local target = records and records[key]
    if not (found and target and target.guid == candidate.targetGUID) then
        return false
    end
    local probability = finite(candidate.effectDelivery) or 1
    probability = math.max(0, math.min(1, probability))
    local now = finite(state.time) or 0
    target.auras = target.auras or {}
    target.auras[self.PROJECTION_KEY] = {
        spellId = self.LOCKOUT_SPELL_ID, exact = true,
        remaining = found.lockoutDuration,
        expiresAt = now + found.lockoutDuration,
        applicationProbability = probability }
    return true
end

function P:Is(subject)
    return evidence(subject) ~= nil
end

function P:Invalidate()
    CACHE, CACHE_COUNT, LOCKOUT_CACHE = {}, 0, nil
end
