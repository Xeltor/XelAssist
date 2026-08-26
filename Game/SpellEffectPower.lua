-- Complete scalar damage from installed-client Spell.dbc effects.  Tooltip
-- prose remains useful evidence, but periodic totals must not depend on an
-- English verb form or on mistaking one tick for the whole aura.
XelAssist.Game.SpellEffectPower = {}
local P = XelAssist.Game.SpellEffectPower

local DIRECT_DAMAGE = 2
local APPLY_AURA = 6
local PERIODIC_DAMAGE = { [3] = true, [53] = true }

-- Only grammar that explicitly states one total over a duration may outrank
-- the installed-client tick calculation.  "N damage every tick over ..." is
-- deliberately not accepted here.
function P:TooltipPeriodicTotal(text, out)
    local _, _, value = string.find(text or "",
        "causes (%d+) %a* ?damage over")
    if not value then
        _, _, value = string.find(text or "",
            "causing (%d+) %a* ?damage over")
    end
    if not value then return nil end
    if out then out.damageTotalSource = "tooltip" end
    return tonumber(value)
end

local function scaledLevels(action, dbc)
    local unit = action and action.actor == "pet" and "pet" or "player"
    local actor = UnitLevel and tonumber(UnitLevel(unit)) or nil
    local spell = tonumber(dbc("spellLevel"))
    local base = tonumber(dbc("baseLevel"))
    local maximum = tonumber(dbc("maxLevel"))
    if not (actor and spell and base and maximum) then return nil end
    local level = math.max(base, actor)
    if maximum > 0 then level = math.min(level, maximum) end
    return math.max(0, level - spell)
end

local function meanMagnitude(index, arrays, levels)
    local points = tonumber(arrays.points[index])
    local dice = tonumber(arrays.dice[index])
    local sides = tonumber(arrays.sides[index])
    local diceLevel = tonumber(arrays.diceLevel[index])
    local pointsLevel = tonumber(arrays.pointsLevel[index])
    if points == nil or dice == nil or sides == nil
        or diceLevel == nil or pointsLevel == nil then return nil end
    sides = sides + diceLevel * levels
    local roll = sides > 1 and (dice + sides) / 2 or dice
    return math.max(0, points + pointsLevel * levels + roll)
end

local function exactTicks(duration, amplitude)
    duration, amplitude = tonumber(duration), tonumber(amplitude)
    if not (duration and duration > 0 and amplitude and amplitude > 0) then
        return nil
    end
    local interval = amplitude / 1000
    local covered, ticks = 0, 0
    while covered + interval <= duration + 0.0001 do
        covered, ticks = covered + interval, ticks + 1
    end
    if ticks <= 0 or math.abs(covered - duration) > 0.0001 then return nil end
    return ticks
end

function P:Apply(action, out, dbc, dbcArray)
    local kind = action and action.facts and action.facts.kind
    if kind ~= "dot" and kind ~= "damage" and kind ~= "builder" then return end
    if not (out and dbc and dbcArray) then return end
    if kind == "dot" and (action.facts.combo or out.durationComboScaled) then
        out.damageTotalSource = nil
        return
    end
    if kind == "dot" and out.average
        and out.directDamage and out.periodicDamage then
        out.damageTotalSource = "tooltip"
    end
    local arrays = {
        effects = dbcArray("effect"),
        auras = dbcArray("effectApplyAuraName"),
        points = dbcArray("effectBasePoints"),
        dice = dbcArray("effectBaseDice"),
        sides = dbcArray("effectDieSides"),
        diceLevel = dbcArray("effectDicePerLevel"),
        pointsLevel = dbcArray("effectRealPointsPerLevel"),
        amplitudes = dbcArray("effectAmplitude"),
    }
    if not (arrays.effects and arrays.auras and arrays.points
        and arrays.dice and arrays.sides and arrays.diceLevel
        and arrays.pointsLevel and arrays.amplitudes) then return end
    local levels = scaledLevels(action, dbc)
    if levels == nil then return end

    local direct, periodic, periodicSeen, periodicComplete = 0, 0, false, true
    local index
    for index = 1, table.getn(arrays.effects) do
        local effect = tonumber(arrays.effects[index]) or 0
        local magnitude = meanMagnitude(index, arrays, levels)
        if effect == DIRECT_DAMAGE then
            if magnitude == nil then return end
            direct = direct + magnitude
        elseif effect == APPLY_AURA
            and PERIODIC_DAMAGE[tonumber(arrays.auras[index])] then
            periodicSeen = true
            local ticks = exactTicks(out.duration, arrays.amplitudes[index])
            if magnitude == nil or ticks == nil then
                periodicComplete = false
            else
                periodic = periodic + magnitude * ticks
            end
        end
    end

    if direct > 0 then out.dbcEffectDirectDamage = direct end
    if periodicSeen and periodicComplete and periodic > 0 then
        out.dbcEffectPeriodicDamage = periodic
    end
    if kind == "dot" then
        if not (periodicSeen and periodicComplete and periodic > 0) then return end
        out.dbcEffectAverage = direct + periodic
        out.dbcEffectComplete = true
    elseif direct > 0 then
        out.dbcEffectAverage = direct
        out.dbcEffectComplete = true
    end
    if not out.dbcEffectComplete then return end
    out.dbcEffectSource = "installed-client Spell.dbc effect total"
    if direct > 0 and out.directDamage == nil then
        out.directDamage = direct
        out.directDamageSource = out.dbcEffectSource
    end
    if periodic > 0 and out.periodicDamage == nil then
        out.periodicDamage = periodic
        out.periodicDamageSource = out.dbcEffectSource
    end
    local persistent = XelAssist.Game.Caster
        and XelAssist.Game.Caster.PersistentDamage
    if persistent then persistent:ApplyPower(action, out) end
end
