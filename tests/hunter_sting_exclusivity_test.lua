XelAssist = { Game = { Player = {} } }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {
    [1978] = { school = 3, dispel = 4, attributes = 65538,
        attributesEx2 = 131072, durationIndex = 8, powerType = 0,
        rangeIndex = 114, spellFamilyName = 9, spellFamilyFlags = 16384,
        effect = t(6), effectDieSides = t(1), effectBaseDice = t(1),
        effectImplicitTargetA = t(6), effectApplyAuraName = t(3),
        effectAmplitude = t(3000), effectTriggerSpell = t() },
    [3034] = { school = 3, dispel = 4, attributes = 65538,
        attributesEx2 = 131072, durationIndex = 31, powerType = 0,
        rangeIndex = 114, spellFamilyName = 9, spellFamilyFlags = 65536,
        effect = t(6), effectDieSides = t(1), effectBaseDice = t(1),
        effectImplicitTargetA = t(6), effectApplyAuraName = t(64),
        effectAmplitude = t(2000), effectTriggerSpell = t() },
    [90000] = { spellFamilyName = 9, dispel = 0 },
}
function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if value == nil then error("missing fixture " .. tostring(id) .. ":" .. field) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
GetSpellDuration = function(id, base)
    assert(id == 1978 and base == 1); return 15000
end
local token = "HUNTER"
UnitClass = function() return "Hunter", token end

dofile("Game/Player/HunterStings.lua")
local Stings = XelAssist.Game.Player.HunterStings
local serpent, reason, handled = Stings:InferKnowledge(1978)
assert(handled and not reason and serpent.kind == "dot"
    and serpent.kindExact and serpent.hunterSerpentSting
    and serpent.exclusiveFamily == "hunterSting",
    "exact Serpent topology must infer a supported exclusive Sting")
local viper, viperReason, viperHandled = Stings:InferKnowledge(3034)
assert(viperHandled and viper.unmodeledUnsafe == viperReason
    and viper.exclusiveFamily == "hunterSting"
    and viper.kindExact == false,
    "unowned Viper drain must be recognized and fail closed")
local promoted = Stings:CaptureFacts({ spellId = 1978 },
    { kind = "dot", preserved = true })
assert(promoted.preserved and promoted.hunterSting
    and promoted.exclusiveFamily == "hunterSting",
    "existing Serpent facts must gain exact exclusivity without mutation")
local original = { kind = "dot", preserved = true }
local copied = Stings:CaptureFacts({ spellId = 1978 }, original)
assert(copied ~= original and original.exclusiveFamily == nil,
    "capture must not mutate shared catalogue facts")
local family, observed = Stings:ObservedFamily(3034)
assert(family == "hunterSting" and observed.recognized,
    "observed own unsupported Stings still need replacement identity")
local foreign, _, foreignHandled = Stings:InferKnowledge(90000)
assert(not foreign and not foreignHandled,
    "a Hunter-family non-poison spell must remain outside Sting ownership")
token = "MAGE"
assert(not Stings:InferKnowledge(1978),
    "another class must never infer a Hunter Sting action")
token = "HUNTER"
Stings:Invalidate(); rows[1978].effectAmplitude = t(2000)
local malformed, malformedReason, malformedHandled = Stings:InferKnowledge(1978)
assert(malformedHandled and malformed.unmodeledUnsafe == malformedReason,
    "recognized malformed Serpent must not fall through generic knowledge")
print("ok: Hunter Stings are exclusive and unsafe downstreams fail closed")
