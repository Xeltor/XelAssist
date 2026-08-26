table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {} } }

local rows = {
    [51387] = { family = 11, school = 0, range = 2,
        effect = { 31, 64, 64 }, points = { 19, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 51386, 52679 } },
    [51386] = { family = 11, school = 3, range = 6,
        effect = { 31, 0, 0 }, points = { 9, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 0, 0 } },
    [52420] = { family = 11, school = 0, range = 2,
        effect = { 31, 64, 64 }, points = { 39, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 52419, 52679 } },
    [52419] = { family = 11, school = 3, range = 6,
        effect = { 31, 0, 0 }, points = { 14, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 0, 0 } },
    [52422] = { family = 11, school = 0, range = 2,
        effect = { 31, 64, 64 }, points = { 59, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 52421, 52679 } },
    [52421] = { family = 11, school = 3, range = 6,
        effect = { 31, 0, 0 }, points = { 19, 0, 0 },
        dice = { 1, 0, 0 }, trigger = { 0, 0, 0 } },
}

function UnitClass() return "Shaman", "SHAMAN" end
function GetSpellRecField(spellId, field, array)
    local row = rows[spellId]
    if not row then return nil end
    if field == "spellFamilyName" then return row.family end
    if field == "school" then return row.school end
    if field == "rangeIndex" then return row.range end
    if field == "effect" and array then return row.effect end
    if field == "effectBasePoints" and array then return row.points end
    if field == "effectBaseDice" and array then return row.dice end
    if field == "effectTriggerSpell" and array then return row.trigger end
end

dofile("Game/Player/ShamanLightningStrike.lua")
local L = XelAssist.Game.Player.ShamanLightningStrike
local expected = {
    [51387] = { 0.20, 0.10 },
    [52420] = { 0.40, 0.15 },
    [52422] = { 0.60, 0.20 },
}
local spellId, coefficients
for spellId, coefficients in pairs(expected) do
    local facts, reason, handled = L:InferKnowledge(spellId)
    assert(handled and not reason and facts and facts.kind == "damage"
        and facts.kindExact and facts.mixedDamage
        and facts.damageComponents[1].weaponMultiplier == coefficients[1]
        and facts.damageComponents[2].weaponMultiplier == coefficients[2],
        "each Lightning Strike rank must retain its own physical/Nature split")
    assert(facts.shamanShieldTrigger.spellId == 52679
        and facts.shamanShieldTrigger.exactTrigger
        and not facts.shamanShieldTrigger.consequenceRepresented,
        "the exact shield trigger must remain explicit but unvalued")
    local captured = L:CaptureFacts({ spellId = spellId, facts = facts }, {
        weaponCoefficient = coefficients[1] })
    assert(captured.weaponCoefficient == coefficients[1] + coefficients[2]
        and captured.weaponFlat == 0 and captured.weaponDirectFlat == 0,
        "root power must use the sum of both exact weapon packets")
end

local unrelated, unrelatedReason, unrelatedHandled = L:InferKnowledge(403)
assert(not unrelated and not unrelatedReason and not unrelatedHandled,
    "unrelated Shaman spells must not be claimed")

rows[51387].trigger = { 0, 51386, 99999 }
L:Invalidate()
local malformed, malformedReason, malformedHandled = L:InferKnowledge(51387)
assert(not malformed and malformedHandled
    and malformedReason == "Octo Lightning Strike DBC topology is incomplete",
    "a shifted shield/result topology must fail closed without name fallback")

UnitClass = function() return "Warrior", "WARRIOR" end
L:Invalidate()
local wrongClass, _, wrongClassHandled = L:InferKnowledge(52422)
assert(not wrongClass and not wrongClassHandled,
    "numeric identities must only be claimed for the Shaman player")

print("ok: exact Octo Lightning Strike ranks and unresolved shield trigger")
