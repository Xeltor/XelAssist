XelAssist = { Game = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerLevel = 7
UnitLevel = function(unit)
    assert(unit == "player")
    return playerLevel
end

dofile("Game/SpellEffectPower.lua")

local tooltipMarker = {}
assert(XelAssist.Game.SpellEffectPower:TooltipPeriodicTotal(
        "corrupts the target, causing 40 shadow damage over 12 sec", tooltipMarker) == 40
    and tooltipMarker.damageTotalSource == "tooltip",
    "explicit tooltip totals over a duration must remain valid evidence")
tooltipMarker = {}
assert(XelAssist.Game.SpellEffectPower:TooltipPeriodicTotal(
        "deals 10 shadow damage every 3 sec over 15 sec", tooltipMarker) == nil
    and tooltipMarker.damageTotalSource == nil,
    "per-tick wording must never masquerade as a complete tooltip total")

local function apply(record, duration, kind)
    local function scalar(field) return record[field] end
    local function array(field) return record[field] end
    local out = { duration = duration }
    XelAssist.Game.SpellEffectPower:Apply(
        { actor = "player", facts = { kind = kind or "dot" } },
        out, scalar, array)
    return out
end

local function record(effects, auras, points, sides, amplitudes, levels)
    return {
        effect = effects, effectApplyAuraName = auras,
        effectBasePoints = points, effectBaseDice = { 1, 1, 0 },
        effectDieSides = sides, effectDicePerLevel = { 0, 0, 0 },
        effectRealPointsPerLevel = levels or { 0, 0, 0 },
        effectAmplitude = amplitudes,
        spellLevel = 1, baseLevel = 1, maxLevel = 5,
    }
end

local corruption = apply(record({ 6, 0, 0 }, { 3, 0, 0 },
    { 9, 0, 0 }, { 1, 0, 0 }, { 3000, 0, 0 }), 12)
assert(corruption.dbcEffectPeriodicDamage == 40
    and corruption.dbcEffectAverage == 40
    and corruption.dbcEffectComplete,
    "Corruption must be four proven ticks, not one tooltip-sized tick")

local immolate = apply(record({ 6, 2, 0 }, { 3, 0, 0 },
    { 3, 7, 0 }, { 1, 1, 0 }, { 3000, 0, 0 }, { 0, 0.6, 0 }), 15)
assert(math.abs(immolate.dbcEffectPeriodicDamage - 20) < 0.0001
    and math.abs(immolate.dbcEffectDirectDamage - 10.4) < 0.0001
    and math.abs(immolate.dbcEffectAverage - 30.4) < 0.0001,
    "Immolate must retain separate direct and periodic installed-client totals")

local shadowBolt = apply(record({ 2, 0, 0 }, { 0, 0, 0 },
    { 11, 0, 0 }, { 5, 0, 0 }, { 0, 0, 0 }, { 0.4, 0, 0 }), nil, "damage")
assert(math.abs(shadowBolt.dbcEffectAverage - 15.6) < 0.0001,
    "direct DBC damage must retain capped level scaling")

playerLevel = 8
local agony = apply(record({ 6, 0, 0 }, { 3, 0, 0 },
    { 6, 0, 0 }, { 1, 0, 0 }, { 2000, 0, 0 }), 24)
assert(agony.dbcEffectPeriodicDamage == 84,
    "Curse of Agony must be twelve proven ticks rather than one tick")

local incomplete = apply(record({ 6, 0, 0 }, { 3, 0, 0 },
    { 9, 0, 0 }, { 1, 0, 0 }, { 0, 0, 0 }), 12)
assert(incomplete.dbcEffectAverage == nil and not incomplete.dbcEffectComplete,
    "unknown periodic cadence must remain unknown")

local comboRecord = record({ 6, 0, 0 }, { 3, 0, 0 },
    { 9, 0, 0 }, { 1, 0, 0 }, { 2000, 0, 0 })
local comboOut = { duration = 6, durationComboScaled = true }
XelAssist.Game.SpellEffectPower:Apply(
    { actor = "player", facts = { kind = "dot", combo = true } }, comboOut,
    function(field) return comboRecord[field] end,
    function(field) return comboRecord[field] end)
assert(comboOut.dbcEffectAverage == nil and not comboOut.dbcEffectComplete,
    "combo-scaled duration must not reuse one fixed periodic total")

local percentHealth = apply(record({ 6, 0, 0 }, { 89, 0, 0 },
    { 9, 0, 0 }, { 1, 0, 0 }, { 3000, 0, 0 }), 12)
assert(percentHealth.dbcEffectAverage == nil and not percentHealth.dbcEffectComplete,
    "percentage-health periodic auras must not be priced as flat damage points")

print("ok: installed-client direct and periodic spell totals")
