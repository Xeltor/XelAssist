-- Octo patch-5 Blade Flurry is a permanent tradeoff toggle.  Until its
-- server-selected nearby recipient is observable, the graph must not mistake
-- it for direct damage or recommend a harmful single-target aura.
XelAssist = { Game = { Player = {} }, Graph = {} }

local row = {
    school = 0, attributes = 262160, castingTimeIndex = 1,
    recoveryTime = 4000, categoryRecoveryTime = 0, durationIndex = 21,
    powerType = 3, manaCost = 25, rangeIndex = 1,
    startRecoveryCategory = 133, startRecoveryTime = 1000,
    spellFamilyName = 8, spellFamilyFlags = 0,
    effect = { 6, 6, 6 }, effectBasePoints = { -21, 0, -21 },
    effectImplicitTargetA = { 1, 1, 1 },
    effectApplyAuraName = { 110, 4, 79 },
    effectMiscValue = { 3, 0, 127 },
}

function UnitClass() return "Rogue", "ROGUE" end
local reads = 0
function GetSpellRecField(id, field, array)
    assert(id == 13877, "only exact patch-5 Blade Flurry may be queried")
    reads = reads + 1
    local value = row[field]
    if array then
        assert(type(value) == "table", "array field expected")
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/RogueBladeFlurry.lua")
local Runtime = XelAssist.Game.Player.RogueBladeFlurry
local facts, reason, handled = Runtime:InferKnowledge(13877)
assert(handled and not reason and facts and facts.kind == "buff"
    and facts.self == true and facts.rogueBladeFlurry == true,
    "the installed toggle must replace generic direct-damage classification")
local exact = Runtime:Evidence(facts)
assert(exact and exact.permanentToggle == true
    and exact.additionalNearbyWeaponRecipient == true
    and exact.damageMultiplier == 0.8
    and exact.energyRegenMultiplier == 0.8
    and exact.recipientSelectionObservable == false,
    "sealed evidence must retain both penalties and the unknown recipient")
assert(Runtime:InferKnowledge(22482) == nil,
    "the server proc must not become a player-cast graph action")

dofile("Graph/RogueBladeFlurry.lua")
local Graph = XelAssist.Graph.RogueBladeFlurry
local projection, blocker, claimed = Graph:Prepare(
    { spellId = 13877, facts = facts }, {},
    { unit = "player", relation = "self" }, facts)
assert(claimed and projection == nil
    and blocker == "Blade Flurry nearby recipient is not observable",
    "unknown server recipient selection must withhold the toggle")

local forged = {}
for key, value in pairs(facts) do forged[key] = value end
forged.rogueBladeFlurryEvidence = {}
for key, value in pairs(facts.rogueBladeFlurryEvidence) do
    forged.rogueBladeFlurryEvidence[key] = value
end
forged.rogueBladeFlurryEvidence.damageMultiplier = 1
projection, blocker, claimed = Graph:Prepare(
    { spellId = 13877, facts = forged }, {}, nil, forged)
assert(claimed and projection == nil
    and blocker == "exact Blade Flurry evidence unavailable",
    "changed tradeoff arithmetic must fail closed")

local before = reads
facts, reason, handled = Runtime:InferKnowledge(13877)
assert(handled and facts and not reason and reads == before,
    "sealed discovery must not reread DBC during graph evaluation")

row.effectApplyAuraName = { 110, 4, 0 }
Runtime:Invalidate()
facts, reason, handled = Runtime:InferKnowledge(13877)
assert(handled and facts == nil
    and reason == "Blade Flurry patch-5 topology is incomplete",
    "a changed Octo patch must stop the stale model")

print("ok: Octo Blade Flurry toggle is exact and recipient-guarded")
