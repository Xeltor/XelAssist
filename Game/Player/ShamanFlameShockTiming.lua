-- Root-captured Octo Improved Flame Shock duration.  The installed client has
-- two mutually exclusive duration modifiers (+3s and +6s); the graph consumes
-- only the engine-effective duration and never derives it from tooltip text.
XelAssist.Game.Player.ShamanFlameShockTiming = {}
local T = XelAssist.Game.Player.ShamanFlameShockTiming

T.SHAMAN_FAMILY = 11
T.FLAME_FLAG = 268435456
T.DURATION_MODIFIER = 1
T.BASE_DURATION_MS = 12000
T.FLAME = { [8050] = true, [8052] = true, [8053] = true,
    [10447] = true, [10448] = true, [29228] = true }
T.TALENTS = { [16085] = 3000, [51864] = 6000 }
local CACHE = {}

local function number(value)
    value = tonumber(value)
    return value and value == value and value or nil
end

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and number(value) or nil
end

local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = number(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function validFlame(id)
    return scalar(id, "spellFamilyName") == T.SHAMAN_FAMILY
        and scalar(id, "spellFamilyFlags") == T.FLAME_FLAG
        and equal(triple(id, "effect"), 2, 6, 0)
        and equal(triple(id, "effectApplyAuraName"), 0, 3, 0)
        and equal(triple(id, "effectAmplitude"), 0, 3000, 0)
end

local function validTalent(id, milliseconds)
    local points = triple(id, "effectBasePoints")
    return scalar(id, "spellFamilyName") == T.SHAMAN_FAMILY
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 107, 0, 0)
        and equal(triple(id, "effectMiscValue"), T.DURATION_MODIFIER, 0, 0)
        and scalar(id, "spellFamilyFlags") == 0
        and points and points[1] + 1 == milliseconds
end

local function identity(id)
    if CACHE[id] ~= nil then return CACHE[id] end
    CACHE[id] = T.FLAME[id] and validFlame(id) or false
    return CACHE[id]
end

local function talentOwnership()
    if type(IsPlayerSpell) ~= "function" then
        return nil, nil, "Improved Flame Shock ownership unavailable"
    end
    local found, amount, count, id, milliseconds = nil, nil, 0, nil, nil
    for id, milliseconds in pairs(T.TALENTS) do
        local ok, active = pcall(IsPlayerSpell, id)
        if not ok or (active ~= true and active ~= false
            and active ~= 1 and active ~= 0) then
            return nil, nil, "Improved Flame Shock ownership unavailable"
        end
        if active == true or active == 1 then
            if not validTalent(id, milliseconds) then
                return nil, nil, "Octo Improved Flame Shock topology shifted"
            end
            found, amount, count = id, milliseconds, count + 1
        end
    end
    if count > 1 then
        return nil, nil, "multiple Improved Flame Shock ranks are active"
    end
    return found, amount, nil
end

function T:Promote(spellId, facts)
    local id = tonumber(spellId)
    if not (id and self.FLAME[id] and type(facts) == "table") then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts) do out[key] = value end
    out.shamanFlameShockTiming = true
    out.requiresExactShamanFlameShockTiming = true
    return out
end

function T:CaptureFacts(action, facts)
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local id = tonumber(action and action.spellId)
    if not (id and out.shamanFlameShockTiming) then return out end
    if not identity(id) or type(GetSpellDuration) ~= "function" then
        out.shamanFlameShockTimingReason = "Flame Shock duration evidence unavailable"
        return out
    end
    local baseOK, baseMs = pcall(GetSpellDuration, id, true)
    local liveOK, liveMs = pcall(GetSpellDuration, id)
    baseMs, liveMs = baseOK and number(baseMs), liveOK and number(liveMs)
    if baseMs ~= self.BASE_DURATION_MS or not liveMs or liveMs < baseMs
        or liveMs > baseMs + 6000 or liveMs / 3000 ~= math.floor(liveMs / 3000) then
        out.shamanFlameShockTimingReason = "effective Flame Shock duration is not exact"
        return out
    end
    local talentId, talentMs, ownershipReason = talentOwnership()
    out.duration = liveMs / 1000
    out.shamanFlameShockDurationExact = true
    out.shamanFlameShockBaseDuration = baseMs / 1000
    out.shamanFlameShockTalentSpellId = talentId
    out.shamanFlameShockTalentDuration = talentMs and talentMs / 1000 or nil
    out.shamanFlameShockTalentOwnershipReason = ownershipReason
    if talentMs and liveMs ~= baseMs + talentMs then
        out.shamanFlameShockTalentOwnershipReason =
            "engine duration and Improved Flame Shock ownership disagree"
        out.shamanFlameShockTalentSpellId = nil
        out.shamanFlameShockTalentDuration = nil
    end
    out.shamanFlameShockTimingSource =
        "engine-effective duration plus installed Octo modifier topology"
    return out
end

function T:Invalidate() CACHE = {} end
