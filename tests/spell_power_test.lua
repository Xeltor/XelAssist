XelAssist = { Game = {}, Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
UnitLevel = function() return 4 end

dofile("Game/SpellPower.lua")

local function formula(record)
    local out = {}
    local function dbc(field) return record[field] end
    local function array(field) return record[field] end
    XelAssist.Game.SpellPower:Apply({}, out, dbc, array)
    return out
end

local backstab = formula({ spellLevel = 4, baseLevel = 4,
    effect = { 121, 31, 80 }, effectBasePoints = { 9, 149, 0 },
    effectBaseDice = { 1, 1, 1 }, effectDieSides = { 1, 1, 1 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectPointsPerComboPoint = { 0, 0, 0 } })
assert(backstab.weaponCoefficient == 1.5 and backstab.weaponFlat == 15
    and backstab.weaponNormalized,
    "Backstab must be 1.5 times normalized weapon plus 15")

local sinister = formula({ spellLevel = 1, baseLevel = 1,
    effect = { 121, 80, 0 }, effectBasePoints = { 2, 0, 0 },
    effectBaseDice = { 1, 1, 0 }, effectDieSides = { 1, 1, 0 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectPointsPerComboPoint = { 0, 0, 0 } })
assert(sinister.weaponCoefficient == 1 and sinister.weaponFlat == 3
    and sinister.weaponNormalized,
    "Sinister Strike must be normalized weapon plus 3")

local ordered = formula({ spellLevel = 1, baseLevel = 1,
    effect = { 31, 121, 0 }, effectBasePoints = { 149, 9, 0 },
    effectBaseDice = { 1, 1, 0 }, effectDieSides = { 1, 1, 0 } })
assert(ordered.weaponCoefficient == 1.5 and ordered.weaponFlat == 15,
    "weapon percent effects must scale every VMaNGOS fixed bonus lane")

local mixed = formula({ spellLevel = 1, baseLevel = 1,
    effect = { 121, 31, 2 }, effectBasePoints = { 9, 149, 24 },
    effectBaseDice = { 1, 1, 1 }, effectDieSides = { 1, 1, 1 } })
assert(mixed.weaponCoefficient == 1.5 and mixed.weaponFlat == 15
    and mixed.weaponDirectFlat == 25,
    "a separate direct-damage effect must remain outside the weapon multiplier")

XelAssist.Game.Capabilities = {
    WeaponDamage = function() return 10 end,
    RangedDamage = function() return nil end,
    BonusDamage = function() return 0 end,
}
dofile("Graph/ActionPower.lua")
local state = { combo = 0 }
local backstabPower, estimated = XelAssist.Graph.ActionPower:Estimate(
    { rank = 1, actor = "player", facts = { kind = "builder", melee = true } },
    { average = 999, weaponCoefficient = backstab.weaponCoefficient,
        weaponFlat = backstab.weaponFlat, school = 0, cost = 60 }, state)
local sinisterPower = XelAssist.Graph.ActionPower:Estimate(
    { rank = 1, actor = "player", facts = { kind = "builder", melee = true } },
    { average = 999, weaponCoefficient = sinister.weaponCoefficient,
        weaponFlat = sinister.weaponFlat, school = 0, cost = 40 }, state)
assert(backstabPower == 30 and sinisterPower == 13 and estimated,
    "ordered DBC weapon power must override misleading tooltip magnitudes")
local mixedPower = XelAssist.Graph.ActionPower:Estimate(
    { rank = 1, actor = "player", facts = { kind = "damage", melee = true } },
    { weaponCoefficient = mixed.weaponCoefficient,
        weaponFlat = mixed.weaponFlat, weaponDirectFlat = mixed.weaponDirectFlat,
        school = 0, cost = 10 }, state)
assert(mixedPower == 55,
    "mixed direct-plus-weapon power must sum the separately aggregated effects")

print("ok: VMaNGOS DBC weapon formula extraction and action power")
