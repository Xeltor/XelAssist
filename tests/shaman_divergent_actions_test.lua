XelAssist = { Game = { Player = {} } }
local class = "SHAMAN"
local rows = {
    [45500] = { school = 0, family = 11, range = 2, recovery = 90000,
        itemClass = 4, itemSubclass = 64, effect = { 2, 64, 0 },
        target = { 6, 6, 0 }, points = { 0, 0, 0 },
        aura = { 0, 0, 0 }, misc = { 0, 0, 0 },
        trigger = { 0, 51364, 0 } },
    [45502] = { school = 3, family = 11, range = 1, category = 900000,
        itemClass = 4294967295, itemSubclass = 0, effect = { 6, 6, 6 },
        target = { 1, 1, 0 }, points = { 29, 4294967295, 0 },
        aura = { 126, 27, 0 }, misc = { 1, 0, 0 }, trigger = { 0, 0, 0 } },
}

function UnitClass() return "Shaman", class end
function GetSpellRecField(id, field, array)
    local row = rows[id]
    if not row then return nil end
    if field == "school" then return row.school end
    if field == "spellFamilyName" then return row.family end
    if field == "rangeIndex" then return row.range end
    if field == "recoveryTime" then return row.recovery or 0 end
    if field == "categoryRecoveryTime" then return row.category or 0 end
    if field == "equippedItemClass" then return row.itemClass end
    if field == "equippedItemSubClassMask" then return row.itemSubclass end
    if array and field == "effect" then return row.effect end
    if array and field == "effectImplicitTargetA" then return row.target end
    if array and field == "effectBasePoints" then return row.points end
    if array and field == "effectApplyAuraName" then return row.aura end
    if array and field == "effectMiscValue" then return row.misc end
    if array and field == "effectTriggerSpell" then return row.trigger end
end

dofile("Game/Player/ShamanDivergentActions.lua")
local S = XelAssist.Game.Player.ShamanDivergentActions
local facts, reason, handled = S:InferKnowledge(45500)
assert(not facts and handled
    and reason == "Totemic Slam private attack-power packet is unavailable",
    "Totemic Slam must not fall through as one point of generic damage")
local slam = S:Evidence(45500)
assert(slam and slam.exact and slam.kind == "totemicSlam",
    "Totemic Slam must retain an inspectable exact identity")

facts, reason, handled = S:InferKnowledge(45502)
assert(not facts and handled
    and reason == "Ethereal Form spellcasting lock is not represented",
    "Ethereal Form must not become a consequence-free defensive buff")
local form = S:Evidence(45502)
assert(form and form.exact and form.kind == "etherealForm",
    "Ethereal Form must retain an inspectable exact identity")

facts, reason, handled = S:InferKnowledge(403)
assert(not facts and not reason and not handled,
    "ordinary Shaman spells must remain available to other inference")
class = "PRIEST"
facts, reason, handled = S:InferKnowledge(45500)
assert(not facts and not reason and not handled,
    "another class must not claim Shaman private actions")

class = "SHAMAN"; rows[45500].trigger = { 0, 99999, 0 }
S:Invalidate()
facts, reason, handled = S:InferKnowledge(45500)
assert(not facts and handled
    and reason == "Octo Shaman divergent action topology is incomplete",
    "shifted private topology must remain fail closed")

print("ok: Octo Shaman private action fallthrough is blocked")
