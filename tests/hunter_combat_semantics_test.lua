table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, petGuid, targetGuid = {}, {}, {}
local clock = 100
XelAssist = { Game = { Pets = {}, Capabilities = {} }, Combat = {}, Graph = {} }
XelAssist.Game.Capabilities.UnitRef = function(_, unit, relation, source)
    local guid = unit == "pet" and petGuid or unit == "target" and targetGuid
        or unit == "player" and playerGuid or nil
    return guid and { unit = unit, guid = guid,
        relation = relation, source = source } or nil
end
UnitLevel = function() return 60 end
GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "player" then return true, playerGuid end
    if unit == "pet" then return true, petGuid end
    if unit == "target" then return true, targetGuid end
    return false, nil
end
GetSpellRecField = function(spellId, field, indexed)
    if spellId ~= 41828 then return nil end
    if field == "school" then return 0 end
    if field == "spellLevel" then return 60 end
    if indexed and field == "effectBasePoints" then return { 99, 0, 0 } end
    if indexed and field == "effectDieSides" then return { 0, 0, 0 } end
    if indexed and field == "effectRealPointsPerLevel" then return { 0, 0, 0 } end
    return nil
end

dofile("Game/Pets/Actions.lua")
dofile("Game/Pets/Effects.lua")
dofile("Game/Pets/EffectRuntime.lua")
dofile("Graph/State.lua")
dofile("Graph/TargetSelection.lua")
dofile("Combat/TriggeredActions.lua")
dofile("Graph/ActorScoring.lua")

local state = { hostile = true, targetGUID = targetGuid,
    targetRef = { unit = "target", guid = targetGuid,
        relation = "hostile", source = "selected" },
    actors = { pet = { unit = "pet", guid = petGuid,
        actorRef = { unit = "pet", guid = petGuid,
            relation = "pet", source = "companion" },
        health = 600, healthMax = 1000, resource = 100, resourceMax = 100,
        targetExists = true, targetsCurrent = true,
        happinessDamageMultiplier = 1.25, level = 60,
        attackPower = 500, attackPowerKnown = true } } }

local killCommand = { name = "Kill Command", spellId = 41827,
    actor = "player", facts = { kind = "damage", fixedTarget = "pet",
        effectTarget = "target", effectActor = "pet", damageActor = "pet",
        resultSpellId = 41828, petAttackPowerCoefficient = 0.8,
        serverScriptPower = true } }
local descriptor = XelAssist.Graph.TargetSelection:Fixed(killCommand, state)
assert(descriptor.unit == "target" and descriptor.guid == targetGuid
    and descriptor.relation == "hostile" and descriptor.castUnit == "pet"
    and descriptor.castGuid == petGuid and descriptor.castTargetRef.guid == petGuid,
    "a Hunter pet-mediated spell must carry enemy effect and pet cast identities")

local result = XelAssist.Combat.TriggeredActions:ResultAction(killCommand)
local resultFacts = XelAssist.Combat.TriggeredActions:EffectFacts(killCommand, {})
assert(result ~= killCommand and result.spellId == 41828 and result.actor == "pet"
    and result.facts.dynamicSchool == nil and resultFacts.school == 0
    and resultFacts.dbcAverage == 100,
    "Kill Command must score and learn from its exact pet result spell")
local scriptedPower, scriptedEstimated =
    XelAssist.Combat.TriggeredActions:ScriptedPower(result, state)
assert(scriptedPower == 400 and scriptedEstimated,
    "Kill Command must derive its advertised private-script estimate from live pet AP")

local bestial = { name = "Bestial Wrath", spellId = 19574,
    facts = { kind = "buff", petCombatBuff = true,
        petCombatEffects = {
            { key = "control-immunity", duration = 18,
                crowdControlImmune = true, sourceSpellId = 19574 },
            { key = "damage-enrage", duration = 8,
                damageMultiplier = 1.4, sourceSpellId = 52995 },
        } } }
local applied = XelAssist.Game.Pets.Effects:Apply(state,
    { action = bestial, tooltip = { duration = 18 } },
    { applicationElapsed = 1.5 })
assert(applied and state.actors.pet.damageMultiplier == 1.75
    and state.actors.pet.combatEffects[
        "Bestial Wrath:damage-enrage"].remaining == 6.5
    and state.actors.pet.combatEffects[
        "Bestial Wrath:control-immunity"].remaining == 16.5,
    "Bestial Wrath must keep its 8-second damage and 18-second immunity windows separate")
XelAssist.Game.Pets.Effects:Advance(state, 6.5)
assert(state.actors.pet.damageMultiplier == 1.25
    and not state.actors.pet.combatEffects["Bestial Wrath:damage-enrage"]
    and XelAssist.Game.Pets.Effects:CrowdControlImmune(state.actors.pet),
    "Bestial Wrath damage must expire while its control immunity remains")
XelAssist.Game.Pets.Effects:Advance(state, 10)
assert(not XelAssist.Game.Pets.Effects:CrowdControlImmune(state.actors.pet),
    "Bestial Wrath control immunity must expire after its independent 18-second window")

local intimidation = { name = "Intimidation", spellId = 19577,
    facts = { kind = "crowdControl", deferredUntilPetMelee = true,
        triggerWindow = 15, stunDuration = 3, effectActor = "pet",
        runtimeUnverified = true,
        resultMelee = true, resultSpellId = 24394,
        deferredResultSpellId = 24394,
        deferredThreatBase = 580, deferredThreatLevel = 40,
        deferredThreatPerLevel = 21,
        petCombatEffects = {
            { key = "threat", duration = 8, threatMultiplier = 1.5,
                sourceSpellId = 51556 },
        } } }
local intimidationResult =
    XelAssist.Combat.TriggeredActions:ResultAction(intimidation)
local intimidationPower = XelAssist.Combat.TriggeredActions:ScriptedPower(
    intimidationResult, state)
assert(intimidationResult.spellId == 24394 and intimidationResult.actor == "pet"
    and intimidationResult.facts.melee and intimidationPower == 1000,
    "Intimidation must evaluate its pet-level physical result without making the cast a melee hit")
applied = XelAssist.Game.Pets.Effects:Apply(state,
    { action = intimidation, targetGUID = targetGuid, tooltip = {} },
    { applicationElapsed = 1.5 })
assert(applied and state.actors.pet.pendingMeleeEffects.Intimidation.remaining == 13.5
    and state.actors.pet.combatEffects["Intimidation:threat"].remaining == 6.5
    and not state.auras,
    "Intimidation must independently arm its proc and immediate threat window")
local ranged = { actor = "pet", facts = { kind = "damage", ranged = true } }
assert(not XelAssist.Game.Pets.Effects:ConsumeMelee(state, ranged, targetGuid))
local melee = { actor = "pet", facts = { kind = "damage", melee = true } }
assert(not XelAssist.Game.Pets.Effects:ConsumeMelee(state, melee, {}),
    "a melee hit on another enemy must not consume the captured Intimidation")
local triggered = XelAssist.Game.Pets.Effects:ConsumeMelee(
    state, melee, targetGuid)
assert(triggered
    and state.auras.Intimidation.remaining == 3
    and triggered.resultSpellId == 24394
    and triggered.threat == 1000 and triggered.projectedThreat == 1500
    and not state.actors.pet.pendingMeleeEffects.Intimidation,
    "the next matching pet melee must consume Intimidation into its scaled pet threat and stun")

local runtime = XelAssist.Game.Pets.EffectRuntime
local function freshPet()
    return { guid = petGuid, level = 60, happinessDamageMultiplier = 1.25 }
end

runtime:Reset()
assert(runtime:Submitted(bestial, petGuid, nil, playerGuid))
local fresh = runtime:Merge(freshPet())
assert(not fresh.combatEffects,
    "a submitted cast without positive lifecycle evidence must not become an active pet buff")
assert(runtime:ObserveCast(19574, playerGuid, petGuid, "failed")
    and not runtime:Merge(freshPet()).combatEffects,
    "an exact failed cast must discard its tentative pet-effect record")
assert(runtime:Submitted(bestial, petGuid, nil, playerGuid))
assert(runtime:ObserveCast(19574, playerGuid, petGuid, "go"))
fresh = runtime:Merge(freshPet())
assert(fresh.combatEffects["Bestial Wrath:damage-enrage"].remaining == 8
    and fresh.combatEffects["Bestial Wrath:control-immunity"].remaining == 18
    and fresh.damageMultiplier == 1.75,
    "a confirmed Bestial Wrath must reconstruct both windows in a fresh snapshot")
clock = clock + 9
fresh = runtime:Merge(freshPet())
assert(not fresh.combatEffects["Bestial Wrath:damage-enrage"]
    and fresh.combatEffects["Bestial Wrath:control-immunity"].remaining == 9,
    "fresh snapshots must age the split Bestial Wrath windows from cast evidence")

runtime:Reset()
XelAssist.Game.Encounter = { Auras = function()
    return { available = true, list = {
        { spellId = 19574, remaining = 12 },
        { spellId = 52995, remaining = 2 },
    } }
end }
fresh = runtime:Merge(freshPet())
assert(fresh.combatEffects["Bestial Wrath:control-immunity"].observed
    and fresh.combatEffects["Bestial Wrath:control-immunity"].remaining == 12
    and fresh.combatEffects["Bestial Wrath:damage-enrage"].remaining == 2,
    "exact live pet aura IDs must reconstruct observable Bestial Wrath windows")
XelAssist.Game.Encounter = nil

runtime:Reset()
clock = 200
assert(runtime:Submitted(intimidation, petGuid, targetGuid, playerGuid)
    and runtime:ObserveCast(19577, playerGuid, targetGuid, "go"),
    "a hostile-target lifecycle packet must correlate to the captured dual-target cast")
fresh = runtime:Merge(freshPet())
assert(fresh.pendingMeleeEffects.Intimidation.targetGuid == targetGuid
    and fresh.pendingMeleeEffects.Intimidation.confirmedCast
    and fresh.pendingMeleeEffects.Intimidation.runtimeUnverified
    and fresh.combatEffects["Intimidation:threat"].remaining == 8,
    "fresh snapshots must retain target-scoped Intimidation with explicit evidence limits")
local otherTarget = {}
assert(not runtime:ObserveAutoAttack(petGuid, otherTarget,
        { actor = "pet", evidence = "hit" })
    and not runtime:ObserveAutoAttack(petGuid, targetGuid,
        { actor = "pet", evidence = "ordinary-miss" }),
    "wrong-target hits and exact misses must preserve the hidden next-melee charge")
assert(runtime:Merge(freshPet()).pendingMeleeEffects.Intimidation)
assert(runtime:ObserveAutoAttack(petGuid, targetGuid,
    { actor = "pet", evidence = "hit" }))
fresh = runtime:Merge(freshPet())
assert(not fresh.pendingMeleeEffects
    and fresh.combatEffects["Intimidation:threat"],
    "an exact successful pet swing must consume only the pending proc, not its threat window")

runtime:Reset()
assert(runtime:Submitted(intimidation, petGuid, targetGuid, playerGuid)
    and runtime:ObserveCast(19577, playerGuid, petGuid, "go"))
assert(not runtime:ObserveSpellDamage(targetGuid, petGuid, 41828,
    { periodic = true, basis = 25 }, 25),
    "periodic damage must never be mistaken for the next melee")
assert(runtime:ObserveSpellDamage(targetGuid, petGuid, 41828,
    { periodic = false, basis = 25 }, 25)
    and not runtime:Merge(freshPet()).pendingMeleeEffects,
    "an exact direct pet melee ability result must consume Intimidation")

runtime:Reset()
assert(runtime:Submitted(intimidation, petGuid, targetGuid, playerGuid)
    and runtime:ObserveCast(19577, playerGuid, petGuid, "go"))
clock = clock + 16
assert(not runtime:Merge(freshPet()).pendingMeleeEffects,
    "an unobserved Intimidation charge must expire after its exact 15-second window")
runtime:Reset()
clock = 250
assert(runtime:Submitted(bestial, petGuid, nil, playerGuid)
    and runtime:ObserveCast(19574, playerGuid, petGuid, "go"))
local replacedPet = {}
runtime:IdentityChanged(petGuid, replacedPet)
petGuid = replacedPet
assert(not runtime:Merge(freshPet()).combatEffects,
    "projected effects must never cross a companion identity change")

local low = { state = state, facts = {}, kind = "petHeal", power = 400,
    cost = 40, downtime = 5, action = { name = "Mend Pet" } }
local high = { state = state, facts = {}, kind = "petHeal", power = 1000,
    cost = 200, downtime = 5, action = { name = "Mend Pet" } }
XelAssist.Graph.ActorScoring:Score(low)
XelAssist.Graph.ActorScoring:Score(high)
assert(low.value > high.value,
    "Mend Pet rank scoring must prefer the efficient non-overhealing rank")

print("ok: dual-target Hunter actions, result spells, pet buffs and deferred melee effects")
