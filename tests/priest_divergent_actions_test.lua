XelAssist = { Game = { Player = {} } }
local class = "PRIEST"
local rows = {
    [45554] = { school = 5, family = 6, flag = 268435456, mana = 270,
        range = 5, effect = { 10, 0, 0 }, target = { 21, 0, 0 },
        points = { 758, 0, 0 }, sides = { 136, 0, 0 },
        description = "Heals a friendly target, but damages you for 50% of the amount healed. This spell generates reduced threat." },
    [45555] = { school = 5, family = 6, flag = 8388608, mana = 80,
        range = 4, effect = { 2, 3, 0 }, target = { 6, 6, 0 },
        points = { 65, 0, 0 }, sides = { 20, 1, 0 } },
    [57701] = { school = 5, family = 6, flag = 8388608, mana = 140,
        range = 4, effect = { 2, 3, 0 }, target = { 6, 6, 0 },
        points = { 148, 0, 0 }, sides = { 24, 1, 0 } },
    [57704] = { school = 5, family = 6, flag = 8388608, mana = 185,
        range = 4, effect = { 2, 3, 0 }, target = { 6, 6, 0 },
        points = { 208, 0, 0 }, sides = { 32, 1, 0 } },
    [57707] = { school = 5, family = 6, flag = 8388608, mana = 265,
        range = 4, effect = { 2, 3, 0 }, target = { 6, 6, 0 },
        points = { 332, 0, 0 }, sides = { 46, 1, 0 } },
}

function UnitClass() return "Priest", class end
function GetSpellRecField(id, field, array)
    local row = rows[id]
    if not row then return nil end
    if field == "school" then return row.school end
    if field == "spellFamilyName" then return row.family end
    if field == "spellFamilyFlags" then return row.flag end
    if field == "powerType" then return 0 end
    if field == "manaCost" then return row.mana end
    if field == "rangeIndex" then return row.range end
    if field == "description" then return row.description end
    if array and field == "effect" then return row.effect end
    if array and field == "effectImplicitTargetA" then return row.target end
    if array and field == "effectBasePoints" then return row.points end
    if array and field == "effectDieSides" then return row.sides end
    if array and field == "effectTriggerSpell" then return { 0, 0, 0 } end
end

dofile("Game/Player/PriestDivergentActions.lua")
local P = XelAssist.Game.Player.PriestDivergentActions
local facts, reason, handled = P:InferKnowledge(45554)
assert(facts and handled and not reason and facts.kind == "heal"
    and facts.shadowMend and facts.shadowMendSelfDamageRatio == 0.5
    and facts.threatProfileExact == false,
    "Shadow Mend must expose its exact bounded health transfer")
local shadow = P:Evidence(45554)
assert(shadow and shadow.exact and shadow.kind == "shadowMend",
    "the exact Shadow Mend identity must remain inspectable")

local id
for id in pairs(P.PAIN_SPIKE) do
    facts, reason, handled = P:InferKnowledge(id)
    assert(not facts and handled
        and reason == "Pain Spike delayed self-healing is unavailable",
        "every Pain Spike rank must be withheld from generic damage inference")
    local evidence = P:Evidence(id)
    assert(evidence and evidence.exact and evidence.kind == "painSpike",
        "each exact Pain Spike rank must retain its private-effect boundary")
end

facts, reason, handled = P:InferKnowledge(589)
assert(not facts and not reason and not handled,
    "ordinary Priest spells must remain available to other inference")

class = "PALADIN"
facts, reason, handled = P:InferKnowledge(45554)
assert(not facts and not reason and not handled,
    "another class must not claim Priest private actions")

class = "PRIEST"
rows[45554].target = { 1, 0, 0 }
P:Invalidate()
facts, reason, handled = P:InferKnowledge(45554)
assert(not facts and handled
    and reason == "Octo Priest divergent action topology is incomplete",
    "shifted private action topology must fail closed")

rows[45554].target = { 21, 0, 0 }
P:Invalidate()
dofile("Game/ActionInference.lua")
facts, reason, handled = XelAssist.Game.ActionInference:ClassKnowledge(45554)
assert(facts and handled and not reason and facts.shadowMend,
    "root class inference must preserve exact Shadow Mend semantics")

print("ok: exact Shadow Mend transfer and withheld Pain Spike")
