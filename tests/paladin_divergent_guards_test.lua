XelAssist = { Game = { Player = {} } }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local ranks = {
    [45409] = { level = 10, points = 5 },
    [45410] = { level = 22, points = 9 },
    [45411] = { level = 34, points = 14 },
    [45412] = { level = 46, points = 21 },
    [45413] = { level = 58, points = 29 },
}
local rows, id, rank = {}, nil, nil
for id, rank in pairs(ranks) do
    rows[id] = { dispel = 1, attributes = 2424832, attributesEx = 512,
        attributesEx2 = 536870912, durationIndex = 9, cumulativeAura = 5,
        baseLevel = rank.level, spellLevel = rank.level, rangeIndex = 2,
        equippedItemClass = 2, spellFamilyName = 10,
        spellFamilyFlags = 536870912, effect = t(6),
        effectBaseDice = t(1), effectBasePoints = t(rank.points),
        effectImplicitTargetA = t(6), effectApplyAuraName = t(14),
        effectMiscValue = t(2), effectTriggerSpell = t() }
end
function GetSpellRecField(spellId, field, copied)
    local value = rows[spellId] and rows[spellId][field]
    if value == nil then error("missing guard fixture " .. tostring(field)) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
GetSpellDuration = function(id, base)
    assert(ranks[id] and base == 1); return 30000
end
local token = "PALADIN"
UnitClass = function() return "Paladin", token end

dofile("Game/Player/PaladinDivergentGuards.lua")
local Guards = XelAssist.Game.Player.PaladinDivergentGuards
for id, rank in pairs(ranks) do
    local facts, reason, handled = Guards:InferKnowledge(id)
    assert(handled and facts.unmodeledUnsafe == reason
        and facts.paladinCrusaderStrike
        and facts.paladinCrusaderStrikeEvidence.exact
        and facts.paladinCrusaderStrikeEvidence.holyFlatPerStack
            == rank.points + 1
        and facts.paladinCrusaderStrikeEvidence.maximumStacks == 5,
        "every installed Crusader rank must be owned and blocked safely")
end
local unrelated, _, unrelatedHandled = Guards:InferKnowledge(1)
assert(not unrelated and not unrelatedHandled,
    "unrelated Paladin actions must remain outside this guard")
token = "MAGE"
assert(not Guards:InferKnowledge(45409),
    "another class must not inherit Paladin divergence ownership")
token = "PALADIN"
Guards:Invalidate(); rows[45409].effectApplyAuraName = t(87)
local malformed, malformedReason, malformedHandled = Guards:InferKnowledge(45409)
assert(malformedHandled and malformed.unmodeledUnsafe == malformedReason
    and malformedReason == "Crusader Strike installed topology is incomplete",
    "recognized topology drift must fail closed before generic fallthrough")
print("ok: private Crusader Strike packets cannot fall through generic damage")
