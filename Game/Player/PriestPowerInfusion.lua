-- Exact Power Infusion discovery and root evidence for installed build 5875.
-- This leaf identifies mechanics only by numeric DBC topology. Mutable spell
-- modifiers and recipient auras are frozen before graph search.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestPowerInfusion = {}
local P = XelAssist.Game.Player.PriestPowerInfusion

P.SPELL_ID = 10060
P.PRIEST_FAMILY = 6
P.FAMILY_FLAG = 2147483648
P.HEALING_DONE_PERCENT = 136
P.DAMAGE_DONE_PERCENT = 79
P.MAGIC_SCHOOL_MASK = 126
P.ALL_EFFECTS_MOD = 8
P.PROJECTION_KEY = "__xel_priest_power_infusion"
P.MAX_AURAS = 40

local PROFILE = nil

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

local function unsigned32(value)
    value = integer(value, -2147483648, 4294967295)
    if value and value < 0 then value = value + 4294967296 end
    return integer(value, 0, 4294967295)
end

local function signed32(value)
    value = unsigned32(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
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
    return ok and finite(value, -2147483648, 4294967295) or nil
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
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalarTopology(spellId)
    return scalar(spellId, "school") == 1
        and scalar(spellId, "category") == 0
        and scalar(spellId, "castUI") == 0
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 180000
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "durationIndex") == 8
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "rangeIndex") == 4
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "startRecoveryCategory") == 0
        and scalar(spellId, "startRecoveryTime") == 0
        and scalar(spellId, "spellFamilyName") == P.PRIEST_FAMILY
        and unsigned32(scalar(spellId, "spellFamilyFlags")) == P.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 0
        and scalar(spellId, "preventionType") == 1
end

local function effectTopology(spellId)
    return equal(triple(spellId, "effect"), 6, 6, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 1, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 1, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectBasePoints"), 19, 19, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 21, 21, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"),
            P.HEALING_DONE_PERCENT, P.DAMAGE_DONE_PERCENT, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"),
            P.MAGIC_SCHOOL_MASK, P.MAGIC_SCHOOL_MASK, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end

local function profile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    if not (scalarTopology(P.SPELL_ID) and effectTopology(P.SPELL_ID)) then
        PROFILE = { recognized = true, valid = false, exact = false,
            reason = "Power Infusion DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { recognized = true, valid = true, exact = true,
        spellId = P.SPELL_ID, family = P.PRIEST_FAMILY,
        familyFlag = P.FAMILY_FLAG, basePercent = 20,
        healingAura = P.HEALING_DONE_PERCENT,
        damageAura = P.DAMAGE_DONE_PERCENT,
        schoolMask = P.MAGIC_SCHOOL_MASK,
        source = "installed build-5875 DBC and VMaNGOS percent-done auras" }
    return copy(PROFILE)
end

local function modifierContract(found)
    if type(GetSpellModifiers) ~= "function"
        or type(GetSpellDuration) ~= "function" then
        return nil, "Power Infusion modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, P.SPELL_ID, P.ALL_EFFECTS_MOD)
    flat, percent = signed32(flat), signed32(percent)
    changed = finite(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil
        or (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then
        return nil, "Power Infusion modifier evidence unavailable"
    end
    local durationOK, milliseconds = pcall(GetSpellDuration, P.SPELL_ID)
    milliseconds = durationOK and integer(milliseconds, 1, 3600000) or nil
    local amount = (found.basePercent + flat) * (100 + percent) / 100
    amount = finite(amount, 0.0001, 1000)
    if not milliseconds or not amount then
        return nil, "Power Infusion magnitude or duration unavailable"
    end
    amount = math.floor(amount)
    if amount <= 0 then return nil, "Power Infusion magnitude unavailable" end
    return { valid = true, exact = true, spellId = P.SPELL_ID,
        duration = milliseconds / 1000, percent = amount,
        multiplier = 1 + amount / 100, family = found.family,
        familyFlag = found.familyFlag, healingAura = found.healingAura,
        damageAura = found.damageAura, schoolMask = found.schoolMask,
        modifierFlat = flat, modifierPercent = percent,
        source = found.source .. "; root-captured ALL_EFFECTS and duration" }
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestPowerInfusionEvidence
    if not (facts and facts.priestPowerInfusion == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == P.SPELL_ID
        and found.family == P.PRIEST_FAMILY
        and found.familyFlag == P.FAMILY_FLAG
        and found.healingAura == P.HEALING_DONE_PERCENT
        and found.damageAura == P.DAMAGE_DONE_PERCENT
        and found.schoolMask == P.MAGIC_SCHOOL_MASK
        and found.basePercent == 20) then return nil end
    return found
end

function P:InferKnowledge(spellId)
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "spell is not Power Infusion", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "modifier", kindExact = true,
        recipientRelation = "friendly", recipientRelationExact = true,
        combatBuff = true, priestPowerInfusion = true,
        requiresPriestPowerInfusionEvidence = true,
        submissionGuarded = true,
        priestPowerInfusionEvidence = found, source = found.source }, nil, true
end

function P:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

function P:Is(subject)
    return evidence(subject) ~= nil
end

local function consumer(action, facts)
    if not (action and facts and (action.actor or "player") == "player"
        and action.executor == "playerSpell"
        and integer(action.spellId, 1, 4294967295)) then return nil end
    local kind = facts.kind
    local healing = kind == "heal" or kind == "hot"
    local damage = kind == "damage" or kind == "dot" or kind == "builder"
    if not healing and not damage then return nil end
    local school = integer(scalar(action.spellId, "school"), 0, 6)
    if school == nil then
        return { claimed = true, exact = false,
            reason = "Power Infusion consumer school unavailable" }
    end
    local affected = healing or damage and school >= 1 and school <= 6
    return { claimed = affected and true or false, exact = true,
        healing = healing and true or false,
        damage = damage and affected and true or false, school = school,
        source = "root-captured DBC school and action consequence kind" }
end

function P:CaptureFacts(action, facts)
    if type(facts) ~= "table" or classToken() ~= "PRIEST" then return facts end
    local out, found = facts, evidence(facts)
    if found and action and action.spellId == self.SPELL_ID then
        local contract, reason = modifierContract(found)
        out = copy(facts)
        out.priestPowerInfusionContract = contract or {
            valid = false, exact = false, recognized = true,
            spellId = self.SPELL_ID, reason = reason }
        return out
    end
    local marker = consumer(action, facts)
    if marker then
        out = copy(facts)
        out.priestPowerInfusionConsumer = marker
    end
    return out
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

local function auraSpellId(value)
    value = integer(value, -65535, 4294967295)
    if value and value < -1 then value = value + 65536 end
    return integer(value, 1, 4294967295)
end

function P:Observe(unit, expectedGUID, contract)
    local out = { known = false, active = false, exact = false,
        unit = unit, recipientGUID = expectedGUID,
        source = "ClassicAPI numeric helpful-aura identity" }
    local before, playerGUID = identity(unit), identity("player")
    if not validGUID(expectedGUID) or before ~= expectedGUID
        or not validGUID(playerGUID) then
        out.reason = "Power Infusion recipient identity unavailable"; return out
    end
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        out.reason = "Power Infusion aura observation unavailable"; return out
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    local after = identity(unit)
    if not ok or type(list) ~= "table" or after ~= before
        or table.getn(list) > self.MAX_AURAS then
        out.reason = "Power Infusion aura observation unavailable"; return out
    end
    local nowOK, now = false, nil
    if type(GetTime) == "function" then nowOK, now = pcall(GetTime) end
    now = nowOK and finite(now, 0, 1000000000) or nil
    local complete, matches, index = now ~= nil, 0, nil
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table" and auraSpellId(aura.spellId)
        if not spellId then complete = false end
        if spellId == self.SPELL_ID then
            matches = matches + 1
            local expiration = finite(aura.expirationTime, 0, 1000000000)
            if aura.isHelpful ~= true or not expiration or expiration <= now then
                complete = false
            else
                out.active, out.remaining = true, expiration - now
                out.sourceGUID = aura.sourceGUID
                -- AuraData exposes identity and expiry but not its snapshotted
                -- amount. Even our own current modifier contract may differ
                -- from the contract at the earlier cast, so active magnitude
                -- deliberately remains unknown.
                out.reason = "active Power Infusion magnitude snapshot unavailable"
            end
        end
    end
    if matches > 1 then complete = false end
    if complete then
        out.known = true
        if not out.active then out.exact = true end
    else out.reason = out.reason or "Power Infusion aura identity incomplete" end
    return out
end

local function recipientKey(descriptor)
    return descriptor and (descriptor.key or descriptor.guid or descriptor.unit)
end

function P:CaptureRecipient(observed, action, descriptor)
    if not evidence(action) then return false, nil end
    local key = recipientKey(descriptor)
    if type(observed) ~= "table" or key == nil or not descriptor.unit
        or descriptor.relation == "hostile" then return true, nil end
    observed.priestPowerInfusionEvidence =
        observed.priestPowerInfusionEvidence or {}
    local record = observed.priestPowerInfusionEvidence[key]
    if not record then
        local facts = observed.currentRecord and observed.currentRecord.facts
        local contract = facts and facts.priestPowerInfusionContract
        record = self:Observe(descriptor.unit, descriptor.guid, contract)
        if not record.active and contract and contract.exact == true then
            record.contract = copy(contract)
        end
        observed.priestPowerInfusionEvidence[key] = record
    end
    return true, record
end

function P:Invalidate()
    PROFILE = nil
end
