-- Exact installed Accelerated Arcana timing for Arcane Missiles.  The passive
-- makes casting-speed effects shorten both the channel and its tick interval.
-- Root-only engine modifier evidence supplies the effective five-tick clock;
-- graph search consumes the sealed duration/cadence without mutable API reads.
XelAssist.Game.Player.MageAcceleratedArcana = {}
local A = XelAssist.Game.Player.MageAcceleratedArcana

A.PASSIVE_ID = 51981
A.MAGE_FAMILY = 3
A.ARCANE_MISSILES_FLAGS = 264192
A.DURATION_MODIFIER = 1
A.TICKS = 5
A.SOURCE = "engine-effective Accelerated Arcana cadence"

local PROFILE, ACTIONS = nil, {}

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value < low or value > high then
        return nil
    end
    return value
end

local function signed(value)
    value = finite(value, -2147483648, 4294967295)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function scalar(id, field, asSigned)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    if not ok then return nil end
    return asSigned and signed(value) or finite(value, 0, 4294967295)
end

local function triple(id, field, asSigned)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or table.getn(values) ~= 3 then
        return nil
    end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = asSigned and signed(values[index])
            or finite(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function passiveProfile()
    if PROFILE then return PROFILE.valid and PROFILE or nil, PROFILE.reason end
    PROFILE = { valid = false, exact = false, spellId = A.PASSIVE_ID,
        source = "installed patch-5 Accelerated Arcana topology" }
    if scalar(A.PASSIVE_ID, "attributes") ~= 464
        or scalar(A.PASSIVE_ID, "spellFamilyName") ~= A.MAGE_FAMILY
        or not equal(triple(A.PASSIVE_ID, "effect"), 6, 6, 6)
        or not equal(triple(A.PASSIVE_ID, "effectApplyAuraName"), 108, 108, 108)
        or not equal(triple(A.PASSIVE_ID, "effectBasePoints", true), -6, -6, -6)
        or not equal(triple(A.PASSIVE_ID, "effectMiscValue", true), 1, 19, 1) then
        PROFILE.reason = "Accelerated Arcana DBC topology is incomplete"
        return nil, PROFILE.reason
    end
    PROFILE.valid, PROFILE.exact = true, true
    return PROFILE
end

local function actionProfile(id)
    id = tonumber(id)
    if not id then return nil end
    if ACTIONS[id] then return ACTIONS[id].valid and ACTIONS[id] or nil end
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, id)
        if ok then duration = tonumber(value) end
    end
    local found = { valid = scalar(id, "school") == 6
        and scalar(id, "spellFamilyName") == A.MAGE_FAMILY
        and scalar(id, "spellFamilyFlags") == A.ARCANE_MISSILES_FLAGS
        and scalar(id, "durationIndex") == 27
        and equal(triple(id, "effect"), 6, 6, 0)
        and equal(triple(id, "effectApplyAuraName"), 23, 4, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 6, 0)
        and equal(triple(id, "effectAmplitude"), 1000, 0, 0)
        and duration == 5000, spellId = id }
    ACTIONS[id] = found
    return found.valid and found or nil
end

local function learned()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Accelerated Arcana ownership unavailable"
    end
    local ok, value = pcall(IsPlayerSpell, A.PASSIVE_ID)
    if not ok or type(value) ~= "boolean" then
        return nil, "Accelerated Arcana ownership unavailable"
    end
    return value
end

local function effectiveDuration(id)
    if type(GetSpellModifiers) ~= "function"
        or type(GetUnitField) ~= "function" then
        return nil, "Arcane Missiles timing evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, id, A.DURATION_MODIFIER)
    flat, percent, changed = signed(flat), signed(percent), signed(changed)
    if not ok or flat == nil or percent == nil or changed == nil
        or percent <= -100 then
        return nil, "Arcane Missiles duration modifier unavailable"
    end
    local speedOK, speed = pcall(GetUnitField, "player", "modCastSpeed")
    speed = speedOK and finite(speed, 0.000001, 10000) or nil
    if not speed then return nil, "player cast-speed evidence unavailable" end
    local milliseconds = math.floor((5000 + flat) * (100 + percent) / 100)
    milliseconds = math.floor(milliseconds * speed)
    if milliseconds <= 0 or milliseconds > 60000 then
        return nil, "effective Arcane Missiles duration is invalid"
    end
    return milliseconds / 1000, nil, { flat = flat, percent = percent,
        changed = changed, castSpeedMultiplier = speed }
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function A:CaptureFacts(action, facts)
    if not actionProfile(action and action.spellId) then return facts end
    local out, active, reason = copy(facts), learned()
    if active == false then return out end
    local profile = active and passiveProfile() or nil
    if not active then reason = reason or "Accelerated Arcana ownership unavailable" end
    local duration, timingReason, modifiers
    if profile then duration, timingReason, modifiers = effectiveDuration(action.spellId) end
    if not (profile and duration and modifiers) then
        out.mageAcceleratedArcana = { exact = false,
            spellId = action.spellId,
            reason = reason or timingReason
                or "Accelerated Arcana timing unavailable" }
        out.unmodeledUnsafe = out.mageAcceleratedArcana.reason
        return out
    end
    out.duration, out.channelInterval = duration, duration / self.TICKS
    out.channelIntervalSource = self.SOURCE
    out.mageAcceleratedArcana = { exact = true, active = true,
        spellId = action.spellId, passiveSpellId = self.PASSIVE_ID,
        ticks = self.TICKS, duration = duration,
        interval = duration / self.TICKS, modifiers = modifiers,
        source = self.SOURCE }
    return out
end

function A:Invalidate()
    PROFILE, ACTIONS = nil, {}
end
