-- Installed patch-5 Consecration identity. Spell.dbc proves the ground shape,
-- cadence, and nominal total, but not Octowow's runtime pulse weighting.
XelAssist.Game.Player.PaladinConsecration = {}
local C = XelAssist.Game.Player.PaladinConsecration

C.RANKS = { [26573] = 1, [20116] = 2, [20922] = 3,
    [20923] = 4, [20924] = 5 }

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and tonumber(value) or nil
end

local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, i, count = {}, nil, 0
    for i in pairs(values) do
        if type(i) ~= "number" or i < 1 or i > 3
            or math.floor(i) ~= i then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for i = 1, 3 do
        out[i] = tonumber(values[i])
        if out[i] == nil then return nil end
    end
    return out
end

local function equal(values, one, two, three)
    return values and values[1] == one and values[2] == two
        and values[3] == three
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        if type(value) == "table" then out[key] = copy(value)
        else out[key] = value end
    end
    return out
end

function C:Inspect(spellId)
    local rank = self.RANKS[tonumber(spellId)]
    if not rank then return nil, "Consecration rank identity unavailable" end
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, milliseconds = pcall(GetSpellDuration, spellId)
        duration = ok and tonumber(milliseconds) or nil
    end
    local coefficients = triple(spellId, "effectBonusCoefficient")
    local coefficient = coefficients and coefficients[1]
    local valid = scalar(spellId, "school") == 1
        and scalar(spellId, "durationIndex") == 31
        and scalar(spellId, "spellFamilyName") == 10
        and scalar(spellId, "spellFamilyFlags") == 32
        and equal(triple(spellId, "effect"), 27, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 3, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 18, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 16, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 14, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 1000, 0, 0)
        and coefficient and coefficient > 0 and coefficient <= 1
        and coefficients[2] == 0 and coefficients[3] == 0
        and duration == 8000
    if not valid then return nil, "Consecration DBC topology is incomplete" end
    return { exact = true, spellId = spellId, rank = rank, school = 1,
        duration = 8, interval = 1, ticks = 8, radius = 8,
        spellBonusCoefficient = coefficient,
        nominalUniformPulses = true, runtimePulseWeightsVerified = false,
        recipientBound = "selected hostile inside the ground at cast time",
        persistsOnTarget = false,
        source = "installed patch-5 Spell.dbc and local ClassicAPI fields" }
end

function C:CaptureFacts(action, facts)
    if not (facts and facts.paladinConsecration == true) then return facts end
    local out, profile = copy(facts), self:Inspect(action and action.spellId)
    out.paladinConsecrationProfile = profile
    out.paladinConsecrationExact = profile and true or false
    out.spellBonusCoefficient = profile
        and profile.spellBonusCoefficient or nil
    out.periodicRecipientBounded = profile and true or nil
    return out
end

function C:Blocker(action, state, descriptor, tooltip)
    local facts = action and action.facts or {}
    if facts.paladinConsecration ~= true then return nil, false end
    local profile = facts.paladinConsecrationProfile
    if not (facts.paladinConsecrationExact == true and profile
        and profile.exact == true and tooltip
        and tonumber(tooltip.duration) == profile.duration
        and tonumber(tooltip.periodicInterval) == profile.interval) then
        return "Consecration periodic evidence unavailable", true
    end
    if not (descriptor and descriptor.relation == "hostile"
        and descriptor.guid ~= nil) then
        return "Consecration hostile recipient unavailable", true
    end
    local selectedKey = state and state.hostiles and state.hostiles.selectedKey
    local selected = selectedKey and state.hostiles.byKey
        and state.hostiles.byKey[selectedKey] or nil
    if selectedKey == nil or descriptor.key ~= selectedKey
        or not selected or descriptor.guid ~= selected.guid then
        return "Consecration recipient is not the selected hostile", true
    end
    local distance = tonumber(state and state.targetDistance)
    if not distance then return "Consecration recipient range unknown", true end
    if distance > profile.radius then
        return "Consecration recipient outside ground radius", true
    end
    return nil, true
end

-- Credit only the cast-time recipient's first nominal pulse. Later ground
-- pulses cannot be attached to that hostile: it may leave while another enters.
function C:Prepare(context)
    local facts = context and context.facts or {}
    if facts.paladinConsecration ~= true then return false end
    local profile = facts.paladinConsecrationProfile
    if not (profile and profile.ticks and profile.ticks > 0) then return false end
    local raw = math.max(0, tonumber(context.power) or 0)
    local expected = math.max(0, tonumber(context.expectedPower) or 0)
    context.dotRawDirectPower = 0
    context.dotRawPeriodicPower = context.dotRawPeriodicPower or raw
    context.dotPeriodicExpectedPower = context.dotPeriodicExpectedPower or expected
    context.power = raw / profile.ticks
    context.expectedPower = expected / profile.ticks
    context.estimated = true
    context.consecrationRuntimePulseWeightsUnverified = true
    return true
end
