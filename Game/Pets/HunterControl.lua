-- Exact Hunter control chains from the installed Octowow Spell.dbc.  Numeric
-- identities select candidate rows; every row still has to match its complete
-- recipient/trigger shape before the graph may use it.  Display names and
-- tooltip prose are never mechanics.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.HunterControl = {}
local H = XelAssist.Game.Pets.HunterControl

H.MAX_CACHE = 12

local WEB = { [36533] = true }
local CHARGE = { [7371] = true, [26177] = true, [26178] = true,
    [26179] = true, [26201] = true, [27685] = true }
local INTIMIDATION = { [19577] = true }
local WEB_SLOW, CHARGE_ROOT, INTIMIDATION_STUN, INTIMIDATION_THREAT =
    36534, 25999, 24394, 51556
local CACHE, CACHE_COUNT = {}, 0

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
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
    return ok and integer(value, 0, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key = {}, 0, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    local index
    for index = 1, 3 do
        out[index] = integer(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function signedTriple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key = {}, 0, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    local index, value
    for index = 1, 3 do
        value = values[index]
        if type(value) ~= "number" or value ~= value
            or value < -2147483648 or value > 2147483647
            or math.floor(value) ~= value then return nil end
        out[index] = value
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
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end

local function range(spellId)
    local index = scalar(spellId, "rangeIndex")
    if not index or type(GetSpellRangeData) ~= "function" then return nil end
    local ok, minimum, maximum = pcall(GetSpellRangeData, index)
    minimum, maximum = tonumber(minimum), tonumber(maximum)
    if not ok or not minimum or not maximum or minimum < 0
        or maximum <= 0 or minimum > maximum then return nil end
    return minimum, maximum
end

local function common(spellId, controlSpellId, controlType, mode,
    sourceActor, controlDuration, minimum, maximum)
    local interruptFlags = scalar(controlSpellId, "auraInterruptFlags")
    -- Every supported result has zero aura-interrupt flags in this installed
    -- client.  A changed bit is a changed break lifecycle, not permission to
    -- retain the old no-break projection.
    if interruptFlags ~= 0 then return nil end
    return { valid = true, recognized = true, portfolio = "hunterControl",
        spellId = spellId, controlSpellId = controlSpellId,
        controlType = controlType, applicationMode = mode,
        sourceActor = sourceActor, recipient = "hostile",
        duration = controlDuration, minRange = minimum, maxRange = maximum,
        effectRangeHitbox = true, auraInterruptFlags = interruptFlags,
        breaksOnAnyDamage = false, breaksOnDirectDamage = false,
        damageBreakSpecified = true,
        source = "installed-client Hunter control DBC trigger topology" }
end

local function webSlow()
    local effects, auras = triple(WEB_SLOW, "effect"),
        triple(WEB_SLOW, "effectApplyAuraName")
    local targetsA, targetsB = triple(WEB_SLOW, "effectImplicitTargetA"),
        triple(WEB_SLOW, "effectImplicitTargetB")
    local mechanics = triple(WEB_SLOW, "effectMechanic")
    local points, dice = signedTriple(WEB_SLOW, "effectBasePoints"),
        signedTriple(WEB_SLOW, "effectBaseDice")
    local magnitude = points and dice and points[1] + dice[1]
    return equal(effects, 6, 0, 0) and equal(auras, 33, 0, 0)
        and equal(targetsA, 6, 0, 0) and equal(targetsB, 0, 0, 0)
        and equal(mechanics, 11, 0, 0) and duration(WEB_SLOW) == 2
        and magnitude and magnitude < 0, magnitude
end

local function rootRecord(spellId, expectedDuration)
    local effects, auras = triple(spellId, "effect"),
        triple(spellId, "effectApplyAuraName")
    local targetsA, targetsB = triple(spellId, "effectImplicitTargetA"),
        triple(spellId, "effectImplicitTargetB")
    return equal(effects, 6, 0, 0) and equal(auras, 26, 0, 0)
        and equal(targetsA, 6, 0, 0) and equal(targetsB, 0, 0, 0)
        and scalar(spellId, "mechanic") == 7
        and duration(spellId) == expectedDuration
end

local function classifyWeb(spellId)
    local triggers = triple(spellId, "effectTriggerSpell")
    local linked, movementPercent = webSlow()
    if not (rootRecord(spellId, 2)
        and equal(triggers, WEB_SLOW, 0, 0) and linked) then
        return nil, "Web DBC topology is incomplete"
    end
    local minimum, maximum = range(spellId)
    if minimum ~= 0 or maximum ~= 20
        or scalar(spellId, "spellFamilyName") ~= 9
        or scalar(spellId, "maxAffectedTargets") ~= 0 then
        return nil, "Web recipient or range evidence is incomplete"
    end
    local out = common(spellId, spellId, "root", "immediate", "pet",
        2, minimum, maximum)
    if not out then return nil, "Web break evidence is incomplete" end
    out.interruptsCasting = false
    out.linkedSpellId, out.movementSpeedPercent = WEB_SLOW, movementPercent
    return out
end

local function classifyCharge(spellId)
    local effects, auras = triple(spellId, "effect"),
        triple(spellId, "effectApplyAuraName")
    local targetsA, targetsB = triple(spellId, "effectImplicitTargetA"),
        triple(spellId, "effectImplicitTargetB")
    local triggers = triple(spellId, "effectTriggerSpell")
    if not (equal(effects, 96, 6, 64) and equal(auras, 0, 99, 0)
        and equal(targetsA, 6, 1, 6) and equal(targetsB, 0, 0, 0)
        and equal(triggers, 0, 0, CHARGE_ROOT)
        and duration(spellId) == 4 and rootRecord(CHARGE_ROOT, 1)) then
        return nil, "Charge DBC trigger topology is incomplete"
    end
    local minimum, maximum = range(spellId)
    local rootMinimum, rootMaximum = range(CHARGE_ROOT)
    if minimum ~= 8 or maximum ~= 25
        or rootMinimum ~= 8 or rootMaximum ~= 25 then
        return nil, "Charge range evidence is incomplete"
    end
    local out = common(spellId, CHARGE_ROOT, "root", "chargeImpact",
        "pet", 1, minimum, maximum)
    if not out then return nil, "Charge break evidence is incomplete" end
    out.interruptsCasting, out.movesSourceToTarget = false, true
    out.triggerSpellId = CHARGE_ROOT
    return out
end

local function intimidationResult()
    local effects, auras = triple(INTIMIDATION_STUN, "effect"),
        triple(INTIMIDATION_STUN, "effectApplyAuraName")
    local targetsA, targetsB = triple(INTIMIDATION_STUN,
        "effectImplicitTargetA"), triple(INTIMIDATION_STUN,
        "effectImplicitTargetB")
    local minimum, maximum = range(INTIMIDATION_STUN)
    return equal(effects, 63, 6, 0) and equal(auras, 0, 12, 0)
        and equal(targetsA, 6, 6, 0) and equal(targetsB, 0, 0, 0)
        and scalar(INTIMIDATION_STUN, "mechanic") == 12
        and duration(INTIMIDATION_STUN) == 3
        and minimum == 0 and maximum == 5, minimum, maximum
end

local function intimidationThreat()
    local points = signedTriple(INTIMIDATION_THREAT, "effectBasePoints")
    local dice = signedTriple(INTIMIDATION_THREAT, "effectBaseDice")
    local percent = points and dice and points[1] + dice[1]
    local valid = equal(triple(INTIMIDATION_THREAT, "effect"), 6, 0, 0)
        and equal(triple(INTIMIDATION_THREAT, "effectApplyAuraName"),
            10, 0, 0)
        and equal(triple(INTIMIDATION_THREAT, "effectImplicitTargetA"),
            5, 0, 0)
        and equal(triple(INTIMIDATION_THREAT, "effectImplicitTargetB"),
            0, 0, 0)
        and equal(triple(INTIMIDATION_THREAT, "effectMiscValue"),
            127, 0, 0)
        and duration(INTIMIDATION_THREAT) == 8
        and percent and percent > 0
    return valid, percent
end

local function classifyIntimidation(spellId)
    local effects, auras = triple(spellId, "effect"),
        triple(spellId, "effectApplyAuraName")
    local targetsA, targetsB = triple(spellId, "effectImplicitTargetA"),
        triple(spellId, "effectImplicitTargetB")
    local triggers = triple(spellId, "effectTriggerSpell")
    local result, minimum, maximum = intimidationResult()
    local threat, threatPercent = intimidationThreat()
    if not (equal(effects, 6, 64, 0) and equal(auras, 42, 0, 0)
        and equal(targetsA, 5, 5, 0) and equal(targetsB, 0, 0, 0)
        and equal(triggers, INTIMIDATION_STUN, INTIMIDATION_THREAT, 0)
        and scalar(spellId, "procFlags") == 20
        and scalar(spellId, "procChance") == 100
        and scalar(spellId, "procCharges") == 1
        and duration(spellId) == 15 and result and threat) then
        return nil, "Intimidation DBC trigger chain is incomplete"
    end
    local out = common(spellId, INTIMIDATION_STUN, "stun",
        "nextPetMelee", "pet", 3, minimum, maximum)
    if not out then return nil, "Intimidation break evidence is incomplete" end
    out.interruptsCasting, out.requiresSuccessfulPetMelee = true, true
    out.triggerWindow, out.resultSpellId = 15, INTIMIDATION_STUN
    out.threatSpellId, out.threatDuration = INTIMIDATION_THREAT, 8
    out.threatRecipient, out.threatMultiplier = "pet", 1 + threatPercent / 100
    out.castRecipient, out.effectRecipient = "pet", "hostile"
    out.procChance, out.procCharges = 1, 1
    return out
end

local function raw(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, cached.recognized == true
    end
    local found, reason
    if WEB[spellId] then found, reason = classifyWeb(spellId)
    elseif CHARGE[spellId] then found, reason = classifyCharge(spellId)
    elseif INTIMIDATION[spellId] then
        found, reason = classifyIntimidation(spellId)
    else return nil, "not an installed Hunter control identity", false end
    if not found then found = { valid = false, recognized = true,
        portfolio = "hunterControl", spellId = spellId,
        reason = reason } end
    if CACHE_COUNT < H.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = copy(found), CACHE_COUNT + 1
    end
    if not found.valid then return copy(found), reason, true end
    return copy(found), nil, true
end

function H:Classify(action)
    local spellId = integer(action and action.spellId, 1, 4294967295)
    if not spellId then return nil, "Hunter control identity unavailable", false end
    local found, reason, recognized = raw(spellId)
    if not (found and found.valid) then return found, reason, recognized end
    local facts = action.facts or {}
    if WEB[spellId] or CHARGE[spellId] then
        if action.actor ~= "pet" or facts.hunterPet ~= true then
            found.valid, found.reason = false,
                "Hunter pet actor evidence is incomplete"
        end
    elseif action.actor ~= "player" or facts.fixedTarget ~= "pet"
        or facts.effectTarget ~= "target" then
        found.valid, found.reason = false,
            "Intimidation cast/effect recipients are incomplete"
    end
    return found, found.reason, true
end

function H:CaptureFacts(action, facts)
    local out = copy(facts)
    if not (action and action.facts
        and action.facts.kind == "crowdControl") then return out end
    local found = self:Classify(action)
    if not (found and found.valid) then return out end
    out.crowdControlEvidence = copy(found)
    out.hunterControlEvidence = copy(found)
    return out
end

function H:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
