XelAssist = { Game = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Game/SpellClassification.lua")
local Classification = XelAssist.Game.SpellClassification

UnitLevel = function() return 20 end

local function classify(effects, auras, points, options)
    options = options or {}
    local arrays = {
        effect = effects, effectApplyAuraName = auras,
        effectBasePoints = points, effectBaseDice = { 0, 0, 0 },
        effectDieSides = { 0, 0, 0 }, effectDicePerLevel = { 0, 0, 0 },
        effectRealPointsPerLevel = { 0, 0, 0 },
        effectImplicitTargetA = options.targets or { 1, 1, 1 },
    }
    arrays.effectBaseDice = options.dice or arrays.effectBaseDice
    arrays.effectRealPointsPerLevel = options.perLevel
        or arrays.effectRealPointsPerLevel
    local scalars = { spellFamilyName = options.family,
        spellFamilyFlags = options.flags, baseLevel = options.baseLevel or 1,
        maxLevel = options.maxLevel or 60,
        spellLevel = options.spellLevel or 1 }
    local out = {}
    Classification:Apply({ facts = { kind = "threatDrop" } }, out,
        function(field) return scalars[field] end,
        function(field) return arrays[field] end)
    return out
end

local feign = classify({ 6, 0, 0 }, { 66, 0, 0 }, { 0, 0, 0 })
assert(feign.threatDropModel == "resistible-all-or-nothing",
    "the installed Feign Death aura must select a resistible projection")

local sanctuaryOnly = classify({ 79, 0, 0 }, { 0, 0, 0 },
    { 0, 0, 0 })
assert(sanctuaryOnly.threatDropModel == nil,
    "Sanctuary without the exact Rogue Vanish family must remain unknown")
local vanish = classify({ 0, 0, 79 }, { 0, 0, 0 }, { 0, 0, 0 },
    { family = 8, flags = 2048 })
assert(vanish.threatDropModel == "reference-clear",
    "the Rogue Vanish family plus self Sanctuary must select reference clearing")

local fade = classify({ 6, 6, 0 }, { 4, 4, 0 }, { -16, -56, 0 },
    { family = 6, flags = 16384, dice = { 1, 1, 0 },
        perLevel = { 0, -3, 0 }, baseLevel = 20, maxLevel = 60,
        spellLevel = 20 })
assert(fade.threatDropModel == "temporary-flat"
    and fade.threatDropAmount == 55,
    "the Priest Fade family must retain its exact signed dummy amount")

local wrongFade = classify({ 6, 6, 0 }, { 4, 4, 0 },
    { -16, -56, 0 }, { family = 6, flags = 0,
        dice = { 1, 1, 0 }, perLevel = { 0, -3, 0 } })
assert(wrongFade.threatDropModel == nil,
    "a generic Priest dummy aura must not inherit Fade semantics")

local unknown = classify({ 77, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 })
assert(unknown.threatDropModel == nil,
    "an unrelated script effect must not inherit threat-drop semantics")

print("ok: installed DBC fields classify threat-drop mechanics without names")
