-- Authoritative periodic cadence from Nampower's copied SpellRec arrays.
-- Unknown, non-damage, or conflicting effects deliberately remain nil.
XelAssist.Game.SpellTiming = {}
local T = XelAssist.Game.SpellTiming

local APPLY_AURA = 6
local PERIODIC_DAMAGE = 3

local function array(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if ok and type(value) == "table" then return value end
    return nil
end

function T:DamageInterval(action)
    if not (action and action.spellId and action.facts
        and action.facts.kind == "dot") then return nil end
    local effects = array(action.spellId, "effect")
    local auras = array(action.spellId, "effectApplyAuraName")
    local amplitudes = array(action.spellId, "effectAmplitude")
    if not (effects and auras and amplitudes) then return nil end
    local interval, i
    for i = 1, math.max(table.getn(effects), table.getn(auras)) do
        local amplitude = tonumber(amplitudes[i])
        if effects[i] == APPLY_AURA and auras[i] == PERIODIC_DAMAGE
            and amplitude and amplitude > 0 then
            local seconds = amplitude / 1000
            if interval and math.abs(interval - seconds) > 0.0001 then
                return nil
            end
            interval = seconds
        end
    end
    return interval
end

function T:Apply(action, facts)
    if not facts then return end
    local interval = self:DamageInterval(action)
    local duration = tonumber(facts.duration)
    if not (interval and duration and duration > 0) then return end
    local covered = 0
    while covered + interval <= duration + 0.0001 do
        covered = covered + interval
    end
    if math.abs(covered - duration) > 0.0001 then return end
    facts.periodicInterval = interval
    facts.periodicIntervalSource = "client DBC effectAmplitude"
end

function T:Next(interval, elapsed)
    interval, elapsed = tonumber(interval), math.max(0, tonumber(elapsed) or 0)
    if not interval or interval <= 0 then return nil end
    local nextTick = interval
    while nextTick <= elapsed + 0.0001 do nextTick = nextTick + interval end
    return math.max(0.0001, nextTick - elapsed)
end

function T:AppliedPower(power, duration, elapsed, interval)
    power, duration = math.max(0, tonumber(power) or 0), tonumber(duration)
    interval, elapsed = tonumber(interval), math.max(0, tonumber(elapsed) or 0)
    if not (duration and duration > 0 and interval and interval > 0) then
        return duration and duration > 0 and power * math.min(duration, elapsed)
            / duration or 0
    end
    local total, completed, at = 0, 0, interval
    while at <= duration + 0.0001 do
        total = total + 1
        if at <= elapsed + 0.0001 then completed = completed + 1 end
        at = at + interval
    end
    return total > 0 and power * completed / total or 0
end
