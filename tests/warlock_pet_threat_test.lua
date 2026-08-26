-- Installed-client Voidwalker threat spells are flat-threat mechanics, not
-- forced taunts. Torment also keeps its independently delivered damage lane.
XelAssist = { Combat = {}, Game = { Pets = {} }, Graph = {} }
XelAssistCharDB = { petThreat = "tank" }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Combat/PetKnowledge.lua")
dofile("Game/Pets/Effects.lua")
dofile("Graph/CompanionThreat.lua")
dofile("Graph/CompanionEventThreat.lua")
dofile("Graph/ThreatScoring.lua")
XelAssist.Graph.State = {
    ActiveHostile = function(_, state) return state.activeHostile end,
    SelectedHostile = function(_, state) return state.activeHostile end,
}
XelAssist.Graph.PlayerThreat = {
    AddScaled = function(_, record, actor, amount)
        record.primaryThreatActor = actor
        record.primaryThreatAdded = amount
    end,
}
dofile("Graph/PrimaryThreatEffects.lua")
dofile("Graph/HostileEffects.lua")

local torment = {
    [3716] = 45, [7809] = 75, [7810] = 125, [7811] = 215,
    [11774] = 300, [11775] = 395,
}
local suffering = {
    [17735] = 150, [17750] = 300, [17751] = 450, [17752] = 600,
}
local spellId, amount
for spellId, amount in pairs(torment) do
    local facts = XelAssist.Combat.PetKnowledge:Facts(
        spellId, "localized", "WARLOCK")
    assert(facts and facts.kind == "damage" and facts.melee
        and facts.hybridPetThreat and facts.petThreatGain == amount
        and facts.threat == nil,
        "Torment rank must retain exact damage plus DBC flat threat")
end
for spellId, amount in pairs(suffering) do
    local facts = XelAssist.Combat.PetKnowledge:Facts(
        spellId, "localized", "WARLOCK")
    assert(facts and facts.kind == "petThreat" and facts.aoe
        and facts.petThreatLowerBound and facts.petThreatGain == amount,
        "Suffering rank must be a conservative exact threat lower bound")
end
assert(XelAssist.Combat.PetKnowledge:Facts(
        nil, "Torment", "WARLOCK") == nil
    and XelAssist.Combat.PetKnowledge:Facts(
        nil, "Suffering", "WARLOCK") == nil,
    "flat-threat hybrids must fail closed without exact rank identity")

local facts = XelAssist.Combat.PetKnowledge:Facts(
    3716, "localized", "WARLOCK")
local action = { name = "localized", spellId = 3716, actor = "pet",
    facts = facts }
local pet = { guid = "pet-guid", health = 100, healthMax = 100,
    resource = 100, resourceMax = 100, hasAggro = false,
    combatEffects = { test = { remaining = 10, threatMultiplier = 1.2 } } }
local record = { guid = "enemy-guid", threat = {
    petHasAggro = false, petDelta = 0 } }
local state = { actors = { pet = pet }, groupSize = 0,
    hasAggro = true, tank = false }

local context = { action = action, facts = facts, kind = "damage",
    state = state, cost = 15, effectDelivery = 0.5,
    effectivePower = 7, expectedPower = 7, power = 7,
    value = 100, reason = "damage" }
XelAssist.Graph.ThreatScoring:Apply(context)
local expected = 7 * 0.9 * 1.2 + 45 * 0.5 * 1.2
assert(math.abs(context.threat - expected) < 0.001
    and context.value > 100
    and context.reason == "builds companion tank threat",
    "hybrid scoring must price damage and exact delivered flat threat: threat="
        .. tostring(context.threat) .. " expected=" .. tostring(expected)
        .. " value=" .. tostring(context.value)
        .. " reason=" .. tostring(context.reason))

local applied = XelAssist.Graph.CompanionEventThreat:ConsumeMelee(
    state, state, action, record.guid, 0.5, record, true)
assert(applied and applied.hybridPetThreat
    and math.abs(record.threat.petDelta - 27) < 0.001
    and math.abs(record.projectedThreat.petThreatAction - 27) < 0.001
    and pet.hasAggro == false
    and record.projectedTauntedByPet == nil
    and record.threat.projectedPetHasAggro == nil,
    "Torment must add probabilistic pet threat without inventing a taunt")

state.activeHostile = record
local candidate = { targetRelation = "hostile", targetGUID = record.guid,
    threat = context.threat, effectDelivery = context.effectDelivery }
local transition = { facts = facts, action = action,
    appliedHostileDamage = nil }
XelAssist.Graph.HostileEffects:ApplyPrimaryThreat(
    state, candidate, transition)
local damageThreat = 7 * 0.9 * 1.2
assert(math.abs(record.primaryThreatAdded - damageThreat) < 0.001
    and math.abs(record.threat.petDelta - 27) < 0.001,
    "inexact target health must apply hybrid flat threat exactly once")

record.primaryThreatAdded = nil
transition.appliedHostileDamage = 7
XelAssist.Graph.HostileEffects:ApplyPrimaryThreat(
    state, candidate, transition)
assert(math.abs(record.primaryThreatAdded - damageThreat) < 0.001,
    "exact and inexact health paths must retain identical damage threat")

local sufferingFacts = XelAssist.Combat.PetKnowledge:Facts(
    17735, "localized", "WARLOCK")
local sufferingAction = { name = "localized area threat", spellId = 17735,
    actor = "pet", facts = sufferingFacts }
local sufferingState = { actors = { pet = { guid = "pet-guid",
    health = 100, healthMax = 100, resource = 100, resourceMax = 100,
    hasAggro = false } }, groupSize = 0 }
local ok, estimate = XelAssist.Graph.CompanionThreat:Apply(
    sufferingState, sufferingAction, nil, 1)
assert(ok and estimate.amountKnown and estimate.stepDelta == 150
    and sufferingState.actors.pet.hasAggro == false,
    "Suffering must retain an exact selected-recipient lower bound")

print("ok: Voidwalker threat spells use exact damage and flat-threat consequences")
