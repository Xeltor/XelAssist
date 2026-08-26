XelAssist = { Game = { Pets = {} }, Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
XelAssistCharDB = { petThreat = "tank" }

local syncs, resistanceTargets, consumed, removedModifiers = 0, {}, {}, {}
XelAssist.Graph.State = {
    FriendlyByKey = function(_, state, key)
        return state.friendlies and state.friendlies.byKey[key]
    end,
    HostileContext = function(_, state, key)
        local record = state.hostiles and state.hostiles.byKey[key]
        if not record then return nil end
        return { hostiles = state.hostiles, actors = state.actors,
            groupSize = state.groupSize, targetGUID = record.guid,
            targetHealth = record.health, targetHealthExact = record.healthExact,
            targetResistance = record.resistance,
            targetDamageTaken = record.damageTaken,
            targetModifierEffects = record.modifierEffects,
            auras = record.projectedAuras, targetAuras = record.targetAuras,
            hasAggro = record.threat and record.threat.playerHasAggro }
    end,
    SyncSelectedHostile = function(_, state)
        syncs = syncs + 1
        local record = state.hostiles.byKey[state.hostiles.selectedKey]
        state.targetGUID, state.targetHealth = record.guid, record.health
        state.targetHealthExact = record.healthExact == true
        state.hasAggro = record.threat and record.threat.playerHasAggro
        state.auras = record.projectedAuras
        state.targetAuras = record.targetAuras
        state.hostile = record.dead ~= true
    end,
    Copy = function(_, state) return state end,
}
XelAssist.Graph.State.RefreshHostileRecord = function(self, state, key)
    if state.targetContextKey == nil and key == state.hostiles.selectedKey then
        return self:SyncSelectedHostile(state)
    end
    return state
end
XelAssist.Graph.Effects = {
    StateAtImpact = function(_, state) return state end,
    Decision = function(_, estimate)
        return estimate.multiplier, estimate.delivery or 1
    end,
    OverWindow = function() return 1 end,
    AdvanceModifierFallbacks = function() end,
    RemoveTargetModifier = function(_, state, name)
        table.insert(removedModifiers, { guid = state.targetGUID, name = name })
        if state.targetModifierEffects then
            state.targetModifierEffects[name] = nil
        end
    end,
}
XelAssist.Combat.Resistance = {
    Estimate = function(_, _, target, _, state)
        assert(target == "target", "target-local contexts retain target API semantics")
        table.insert(resistanceTargets, state.targetGUID)
        return { multiplier = state.targetResistance.multiplier,
            delivery = state.targetResistance.delivery }
    end,
}
XelAssist.Graph.CompanionThreat = {
    Apply = function(_, state, ambient)
        local facts = ambient.facts or {}
        local amount = tonumber(facts.petThreatGain)
            or -tonumber(facts.petThreatDrop) or 1
        local pet = state.actors.pet
        local prior = pet.threatEstimate and pet.threatEstimate.delta or 0
        pet.threatEstimate = { delta = prior + amount,
            projected = true, source = "test threat" }
        return true, pet.threatEstimate
    end,
}
local defensiveApplications = 0
XelAssist.Game.Pets.Effects = {
    DamageMultiplier = function() return 1 end,
    ThreatMultiplier = function() return 1 end,
    Advance = function() end,
    Apply = function(_, state)
        defensiveApplications = defensiveApplications + 1
        state.actors.pet.shellShieldApplied = true
        return true
    end,
    ConsumeMelee = function(_, _, _, targetGuid, delivery)
        table.insert(consumed, { guid = targetGuid, delivery = delivery })
    end,
}
XelAssist.Game.SpellTiming = {
    Next = function(_, interval) return interval or 1 end,
}

dofile("Game/Pets/Resources.lua")
dofile("Graph/CompanionTargets.lua")

local guidA, guidB, guidMissing, petActorGuid = {}, {}, {}, {}
local keyA, keyB = {}, {}

local function autocasts()
    return {
        { name = "Bite", actor = "pet", kind = "damage",
            spellId = 17253,
            facts = { kind = "damage", damageActor = "pet", melee = true },
            power = 40, cost = 10, cooldown = 10, readyIn = 0,
            tooltip = { school = 0 } },
        { name = "Scorpid Poison", actor = "pet", kind = "dot",
            spellId = 24640,
            facts = { kind = "dot", damageActor = "pet", melee = true,
                stackable = 5 },
            power = 100, cost = 20, cooldown = 10, readyIn = 0,
            tooltip = { school = 3, duration = 10, periodicInterval = 2 } },
        { name = "Growl", actor = "pet", kind = "petThreat",
            spellId = 2649,
            facts = { kind = "petThreat", petThreatGain = 415 },
            power = 0, cost = 15, cooldown = 10, readyIn = 0, tooltip = {} },
        { name = "Torment", actor = "pet", kind = "taunt",
            spellId = 3716,
            facts = { kind = "taunt", threat = 3 },
            power = 0, cost = 5, cooldown = 10, readyIn = 0, tooltip = {} },
    }
end

local function hostileRecord(key, guid, selected, health, multiplier)
    return { key = key, guid = guid, selected = selected, dead = false,
        health = health, healthMax = health, healthExact = true,
        geometry = { pet = { distance = 3, lineOfSight = true,
            behind = true, source = "test" } },
        resistance = { multiplier = multiplier }, projectedAuras = {},
        targetAuras = {}, modifierEffects = {},
        threat = { playerHasAggro = selected, petHasAggro = false,
            playerDelta = 0, petDelta = 0 } }
end

local function targetLocalState(petGuid, current)
    local first = hostileRecord(keyA, guidA, false, 100, 0.5)
    local selected = hostileRecord(keyB, guidB, true, 200, 0.1)
    return { hostile = true, targetGUID = guidB, targetHealth = 200, time = 0,
        targetHealthExact = true, hasAggro = true, groupSize = 0,
        targetResistance = selected.resistance,
        auras = selected.projectedAuras,
        hostiles = { order = { keyA, keyB }, byKey = {
                [keyA] = first, [keyB] = selected },
            byUnit = { pettarget = keyA }, selectedKey = keyB,
            total = 2, capped = false },
        actors = { pet = { guid = petActorGuid,
            resource = 100, resourceMax = 100,
            distance = 3, lineOfSight = true, behind = true,
            targetExists = true, targetGuid = petGuid,
            targetsCurrent = current, hasAggro = false,
            autocasts = autocasts() } } }
end

dofile("Graph/CompanionEventThreat.lua")
dofile("Game/Pets/DefensiveActions.lua")
dofile("Graph/CompanionDefensives.lua")
dofile("Graph/CompanionTieScheduler.lua")
dofile("Graph/CompanionResources.lua")
dofile("Graph/CompanionCastEvents.lua")
dofile("Graph/CompanionScheduler.lua")
dofile("Graph/CompanionCastRuntime.lua")
dofile("Graph/CompanionSwings.lua")
dofile("Graph/CompanionEvents.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/EventAuras.lua")
local C = XelAssist.Graph.CompanionEvents
local EventAuras = XelAssist.Graph.EventAuras
local candidate = { downtime = 1, targetKey = keyB,
    targetGUID = guidB }
local context = { applicationOffset = 0,
    ChangesHostileTarget = function() return false end }

local function causalSort(values)
    table.sort(values, function(left, right)
        if left.offset ~= right.offset then return left.offset < right.offset end
        return (left.priority or 50) < (right.priority or 50)
    end)
end

local state = targetLocalState(guidA, false)
local longCandidate = { downtime = 7, targetKey = keyB, targetGUID = guidB }
local i
for i = 1, table.getn(state.actors.pet.autocasts) do
    state.actors.pet.autocasts[i].readyIn = (i - 1) * 2
end
local events = C:Events(state, longCandidate)
assert(table.getn(events) == 4,
    "the shared pet clock must retain four non-overlapping ready autocasts")
for i = 1, table.getn(events) do
    assert(events[i].targetGuid == guidA and events[i].targetKey == keyA
        and events[i].targetLocal,
        "every companion event must capture the exact opaque hostile identity")
    assert(C:Apply(state, state, longCandidate, context, events[i]),
        "a known living off-selected target must resolve")
end
local first, selected = state.hostiles.byKey[keyA], state.hostiles.byKey[keyB]
assert(first.health == 80 and selected.health == 200
    and state.targetHealth == 200,
    "pet damage must use off-target resistance without touching selected health")
assert(first.projectedAuras["Scorpid Poison"]
    and not selected.projectedAuras["Scorpid Poison"]
    and not state.auras["Scorpid Poison"],
    "a passive pet DoT must live only on its exact hostile record")
assert(first.threat.petDelta > 415
    and first.companionThreatEstimate.delta == 415
    and first.threat.playerHasAggro == false
    and first.threat.petHasAggro == false
    and first.threat.projectedPlayerHasAggro == false
    and first.threat.projectedPetHasAggro == true
    and first.threat.projectedVictimGuid == petActorGuid
    and first.threat.tauntDelivery == 1
    and first.threat.projectedSource == "Torment"
    and first.projectedThreat.petThreatAction == 415
    and math.abs(first.threat.petDelta
        - first.projectedThreat.pet - 415) < 0.001
    and first.projectedTauntedByPet,
    "projected threat and taunt must be additive without rewriting live evidence")
assert(state.actors.pet.resource == 50 and not state.actors.pet.threatEstimate
    and not state.actors.pet.hasAggro and syncs == 0,
    "off-selected events must not rewrite companion or selected compatibility mirrors")
assert(table.getn(resistanceTargets) == 4
    and resistanceTargets[1] == guidA and resistanceTargets[2] == guidA
    and resistanceTargets[3] == guidA and resistanceTargets[4] == guidA
    and table.getn(consumed) == 2
    and consumed[1].guid == guidA and consumed[2].guid == guidA,
    "resistance and deferred melee hooks must receive the captured target")

local simultaneous = targetLocalState(guidA, false)
local simultaneousEvents = C:Events(simultaneous, candidate)
local tiedBefore = simultaneous.actors.pet.autocasts
simultaneous.actors.pet.autocasts = { tiedBefore[4], tiedBefore[2],
    tiedBefore[1], tiedBefore[3] }
assert(table.getn(simultaneousEvents) == 1
    and simultaneousEvents[1].kind == "petAutocastUnknown"
    and simultaneousEvents[1].tiedReservation
    and table.getn(simultaneousEvents[1].tiedAutocasts) == 4
    and simultaneousEvents[1].autocastCost == 20
    and simultaneous.actors.pet.autocastOrderUnknown
    and C:Apply(simultaneous, simultaneous, candidate, context,
        simultaneousEvents[1])
    and simultaneous.actors.pet.resource == 80
    and simultaneous.actors.pet.actionReadyIn == 0.5
    and simultaneous.actors.pet.autocasts[1].readyIn == 0
    and simultaneous.actors.pet.autocasts[2].readyIn == 9
    and simultaneous.actors.pet.autocasts[3].readyIn == 0
    and simultaneous.actors.pet.autocasts[4].readyIn == 0
    and simultaneous.hostiles.byKey[keyA].health == 100,
    "simultaneous-ready autocasts must reserve a stable worst-case identity without invented damage")

local longTie = targetLocalState(guidA, false)
local longTieCandidate = { downtime = 4, targetKey = keyB,
    targetGUID = guidB }
local longTieEvents = C:Events(longTie, longTieCandidate)
assert(table.getn(longTieEvents) == 3
    and longTieEvents[1].kind == "petAutocastUnknown"
    and longTieEvents[2].kind == "petAutocastUnknown"
    and longTieEvents[3].kind == "petAutocastUnknown",
    "an unresolved tie must reserve every possible later shared-clock slot as unknown")
for i = 1, table.getn(longTieEvents) do
    assert(C:Apply(longTie, longTie, longTieCandidate, context,
        longTieEvents[i]),
        "every sequential tied reservation must resolve conservatively")
end
assert(longTie.actors.pet.resource == 55
    and longTie.actors.pet.actionReadyIn == 0.5
    and longTie.actors.pet.autocasts[1].readyIn == 9
    and longTie.actors.pet.autocasts[2].readyIn == 6
    and longTie.actors.pet.autocasts[3].readyIn == 7.5
    and longTie.actors.pet.autocasts[4].readyIn == 0
    and longTie.hostiles.byKey[keyA].health == 100,
    "long tied windows must reserve descending worst-case focus and one causal cooldown per slot")

local tiedCasts = targetLocalState(guidA, false)
local longCast = { name = "Long", kind = "damage", spellId = 90001,
    facts = { kind = "damage", ranged = true }, power = 1, cost = 10,
    cooldown = 1, readyIn = 0,
    tooltip = { cast = 2, gcd = 0.1, maxRange = 30 } }
local shortCast = { name = "Short", kind = "damage", spellId = 90002,
    facts = { kind = "damage", ranged = true }, power = 1, cost = 10,
    cooldown = 10, readyIn = 0,
    tooltip = { cast = 1, gcd = 0.1, maxRange = 30 } }
tiedCasts.actors.pet.autocasts = { longCast, shortCast }
local tiedCastEvents = C:Events(tiedCasts,
    { downtime = 4, targetKey = keyB, targetGUID = guidB })
causalSort(tiedCastEvents)
local tiedStarts = {}
for i = 1, table.getn(tiedCastEvents) do
    local entry = tiedCastEvents[i]
    assert(C:Apply(tiedCasts, tiedCasts, longTieCandidate,
        context, entry), "every reserved tied cast record must resolve")
    if entry.kind == "petAutocastStart" then
        table.insert(tiedStarts, { offset = entry.offset,
            choice = entry.castTicket.choice.autocastSpellId })
    end
end
assert(table.getn(tiedStarts) == 3
    and tiedStarts[1].offset == 0 and tiedStarts[1].choice == 90001
    and tiedStarts[2].offset == 2 and tiedStarts[2].choice == 90002
    and tiedStarts[3].offset == 3 and tiedStarts[3].choice == 90001
    and tiedCasts.actors.pet.resource == 70
    and shortCast.readyIn == 9 and longCast.readyIn == 2,
    "tied casts must commit the reserved busy/cast identity and repeat only after its cooldown")

local rapidTie = targetLocalState(guidA, false)
local slow = { name = "Slow", kind = "damage", spellId = 90101,
    facts = { kind = "damage", melee = true }, power = 1, cost = 20,
    cooldown = 10, readyIn = 0, tooltip = { gcd = 0.1 } }
local fast = { name = "Fast", kind = "damage", spellId = 90102,
    facts = { kind = "damage", melee = true }, power = 1, cost = 5,
    cooldown = 0.5, readyIn = 0, tooltip = { gcd = 0.1 } }
rapidTie.actors.pet.autocasts = { slow, fast }
local rapidEvents = C:Events(rapidTie,
    { downtime = 2, targetKey = keyB, targetGUID = guidB })
local rapidOffsets, rapidChoices = { 0, 0.1, 0.6, 1.1, 1.6 },
    { 90101, 90102, 90102, 90102, 90102 }
assert(table.getn(rapidEvents) == 5)
for i = 1, table.getn(rapidEvents) do
    assert(math.abs(rapidEvents[i].offset - rapidOffsets[i]) < 0.001
        and rapidEvents[i].reservedChoice.autocastSpellId == rapidChoices[i]
        and C:Apply(rapidTie, rapidTie, candidate, context, rapidEvents[i]),
        "a tied lane may repeat whenever its own committed cooldown expires")
end
assert(rapidTie.actors.pet.resource == 60,
    "runtime tie arbitration must accept every scheduler-reserved repeat")

local divergentTie = targetLocalState(guidA, false)
local hostileChoice, independentChoice = autocasts()[1], {
    name = "Shell Shield", kind = "petDefensive", spellId = 90202,
    facts = { kind = "petDefensive", self = true }, power = 0,
    cost = 10, cooldown = 0.5, readyIn = 0, tooltip = { gcd = 0.1 } }
hostileChoice.cost, hostileChoice.tooltip.gcd = 20, 0.1
divergentTie.actors.pet.autocasts = { hostileChoice, independentChoice }
local divergentEvents = C:Events(divergentTie, candidate)
divergentTie.actors.pet.targetExists, divergentTie.actors.pet.targetGuid = false, nil
assert(table.getn(divergentEvents) > 1
    and C:Apply(divergentTie, divergentTie, candidate,
        context, divergentEvents[1])
    and not C:Apply(divergentTie, divergentTie, candidate,
        context, divergentEvents[2])
    and divergentTie.actors.pet.resource == 90
    and divergentTie.actors.pet.resourceExact == false
    and divergentTie.actors.pet.actionReadyExact == false,
    "target-loss fallback must invalidate prebuilt tied follow-ups instead of repeating the fallback")

local mixedTie = targetLocalState(guidA, false)
local mixedBite = autocasts()[1]
mixedBite.cost = 20
local mixedShell = { name = "Shell Shield", kind = "petDefensive",
    spellId = 26064, facts = { kind = "petDefensive", self = true },
    power = 0, cost = 10, cooldown = 20, readyIn = 0, tooltip = {} }
mixedTie.actors.pet.autocasts = { mixedBite, mixedShell }
local mixedEvents = C:Events(mixedTie, candidate)
mixedTie.actors.pet.targetExists = false
mixedTie.actors.pet.targetGuid = nil
assert(table.getn(mixedEvents) == 1
    and C:Apply(mixedTie, mixedTie, candidate, context, mixedEvents[1])
    and mixedTie.actors.pet.resource == 90
    and mixedBite.readyIn == 0 and mixedShell.readyIn == 19,
    "a mixed tie must reserve the worst still-valid self autocast after hostile target loss")

local rangedOut = targetLocalState(guidA, false)
rangedOut.actors.pet.autocasts = { autocasts()[1] }
rangedOut.hostiles.byKey[keyA].geometry.pet.distance = 20
assert(table.getn(C:Events(rangedOut, candidate)) == 0,
    "an exact out-of-melee pet target must not receive an ambient Bite")
local blockedLos = targetLocalState(guidA, false)
blockedLos.actors.pet.autocasts = { autocasts()[1] }
blockedLos.hostiles.byKey[keyA].geometry.pet.lineOfSight = false
assert(table.getn(C:Events(blockedLos, candidate)) == 1,
    "an unproven line-of-sight hint must not suppress a ranged-valid ambient ability")
local unknownGeometry = targetLocalState(guidA, false)
unknownGeometry.actors.pet.autocasts = { autocasts()[1] }
unknownGeometry.hostiles.byKey[keyA].geometry.pet = {}
local unknownGeometryEvents = C:Events(unknownGeometry, candidate)
assert(table.getn(unknownGeometryEvents) == 1
    and unknownGeometryEvents[1].kind == "petAutocastUnknown"
    and unknownGeometry.actors.pet.autocastGeometryUnknown
    and C:Apply(unknownGeometry, unknownGeometry, candidate, context,
        unknownGeometryEvents[1])
    and unknownGeometry.actors.pet.resource == 90
    and unknownGeometry.hostiles.byKey[keyA].health == 100,
    "unknown pet geometry must reserve cost without claiming a hit")
local castingPet = targetLocalState(guidA, false)
castingPet.actors.pet.autocasts = { { name = "Firebolt", kind = "damage",
    spellId = 3110,
    facts = { kind = "damage", damageActor = "pet", ranged = true },
    power = 40, cost = 20, cooldown = 3, readyIn = 0,
    tooltip = { school = 2, cast = 2, gcd = 1.5, maxRange = 30 } } }
local castingEvents = C:Events(castingPet, candidate)
assert(table.getn(castingEvents) == 1
    and castingEvents[1].kind == "petAutocastStart"
    and castingEvents[1].offset == 0
    and castingPet.actors.pet.resource == 100
    and C:Apply(castingPet, castingPet, candidate, context,
        castingEvents[1])
    and castingPet.actors.pet.casting
    and castingPet.actors.pet.castRemaining == 1
    and castingPet.actorReadyAt.pet == 2
    and castingPet.actors.pet.resource == 80
    and castingPet.actors.pet.pendingAutocast
    and castingPet.actors.pet.pendingAutocast.costPaid
    and castingPet.actors.pet.pendingAutocast.autocastSpellId == 3110
    and castingPet.actors.pet.pendingAutocast.targetGuid == guidA
    and castingPet.hostiles.byKey[keyA].health == 100,
    "a projected cast crossing the window must pay once and retain its completion identity")

local projectedFirebolt = castingPet.actors.pet.autocasts[1]
local dormantBite = autocasts()[1]
dormantBite.spellId, dormantBite.readyIn = 17253, 20
castingPet.actors.pet.autocasts = { dormantBite, projectedFirebolt }
castingPet.actors.pet.targetGuid = guidB
castingPet.hostiles.byUnit.pettarget = keyB
local completionCandidate = { downtime = 2, targetKey = keyB,
    targetGUID = guidB }
local completionEvents = C:Events(castingPet, completionCandidate)
assert(table.getn(completionEvents) == 1
    and completionEvents[1].pendingCompletion
    and completionEvents[1].autocastSpellId == 3110
    and completionEvents[1].targetGuid == guidA
    and completionEvents[1].targetKey == keyA
    and completionEvents[1].offset == 1
    and C:Apply(castingPet, castingPet, completionCandidate, context,
        completionEvents[1])
    and castingPet.actors.pet.resource == 80
    and castingPet.hostiles.byKey[keyA].health == 80
    and castingPet.hostiles.byKey[keyB].health == 200
    and castingPet.actors.pet.autocasts[2].readyIn == 2
    and not castingPet.actors.pet.pendingAutocast
    and not castingPet.actors.pet.casting
    and castingPet.actors.pet.actionReadyIn == 0
    and table.getn(C:Events(castingPet, { downtime = 0,
        targetKey = keyB, targetGUID = guidB })) == 0,
    "a pending cast must complete once on its captured target and spell after both identities move")

local liveCast = targetLocalState(guidA, false)
liveCast.actors.pet.resource = 80
liveCast.actors.pet.autocasts = { { name = "Firebolt", kind = "damage",
    spellId = 3110,
    facts = { kind = "damage", damageActor = "pet", ranged = true },
    power = 40, cost = 20, cooldown = 3, readyIn = 1,
    tooltip = { school = 2, cast = 2, gcd = 1.5, maxRange = 30 } } }
liveCast.actors.pet.castRemaining = 1
liveCast.actors.pet.castSpellId = 3110
liveCast.actors.pet.casting = true
local liveEvents = C:Events(liveCast, completionCandidate)
assert(table.getn(liveEvents) == 1 and liveEvents[1].pendingCompletion
    and liveEvents[1].costPaid and liveEvents[1].offset == 1
    and C:Apply(liveCast, liveCast, completionCandidate, context,
        liveEvents[1])
    and liveCast.actors.pet.resource == 80
    and liveCast.hostiles.byKey[keyA].health == 80
    and liveCast.actors.pet.autocasts[1].readyIn == 2
    and not liveCast.actors.pet.casting
    and liveCast.actors.pet.actionReadyIn == 0,
    "a live cast identified by spell ID must finish without paying its observed cost twice")

local unsupported = targetLocalState(guidA, false)
unsupported.actors.pet.autocasts = { { name = "Prowl", kind = "buff",
    spellId = 24450, facts = { kind = "buff", self = true }, power = 0,
    cost = 15, cooldown = 10, readyIn = 2, tooltip = {} } }
local unsupportedCandidate = { downtime = 1, targetKey = keyB,
    targetGUID = guidB }
assert(table.getn(C:Events(unsupported, unsupportedCandidate)) == 0
    and unsupported.actors.pet.autocasts[1].readyIn == 1
    and unsupported.actors.pet.autocastEffectUnknown,
    "an unsupported enabled autocast must still age on the shared pet clock")
local unsupportedEvents = C:Events(unsupported, unsupportedCandidate)
assert(table.getn(unsupportedEvents) == 1
    and unsupportedEvents[1].kind == "petAutocastUnknown"
    and unsupportedEvents[1].unknownReason == "companion autocast effect"
    and C:Apply(unsupported, unsupported, unsupportedCandidate, context,
        unsupportedEvents[1])
    and unsupported.actors.pet.resource == 85
    and unsupported.actors.pet.autocasts[1].readyIn == 10,
    "an unsupported enabled autocast must reserve focus and cooldown without inventing its effect")

local noTarget = targetLocalState(guidA, false)
noTarget.actors.pet.targetExists = false
noTarget.actors.pet.targetGuid = nil
noTarget.actors.pet.targetsCurrent = false
local shellShield, targetBite = {
    name = "Shell Shield", kind = "petDefensive", spellId = 26064,
    facts = { kind = "petDefensive", self = true,
        petDefensiveProfile = { exact = true, kind = "shellShield",
            spellId = 26064, duration = 12,
            incomingDamageMultiplier = 0.5,
            meleeAttackTimeMultiplier = 1.35,
            offensiveTimingExact = false },
        petCombatEffects = { { duration = 12,
            incomingDamageMultiplier = 0.5 } } }, power = 0,
    cost = 10, cooldown = 60, readyIn = 0, tooltip = { gcd = 1.5 },
}, autocasts()[1]
targetBite.spellId = 17253
noTarget.actors.pet.autocasts = { shellShield, targetBite }
local noTargetEvents = C:Events(noTarget, candidate)
assert(table.getn(noTargetEvents) == 1
    and noTargetEvents[1].targetIndependent
    and noTargetEvents[1].autocastSpellId == 26064
    and noTargetEvents[1].kind == "petAutocast"
    and C:Apply(noTarget, noTarget, candidate, context,
        noTargetEvents[1])
    and noTarget.actors.pet.resource == 90
    and noTarget.actors.pet.shellShieldApplied
    and defensiveApplications == 1
    and noTarget.companionDefensiveTimingUnknown
    and shellShield.readyIn == 59
    and targetBite.readyIn == 0,
    "an exact self defensive must reserve its clock and apply only its proven effect")

local unaffordable = targetLocalState(guidA, false)
local expensiveBite, affordableTorment = autocasts()[1], autocasts()[4]
expensiveBite.spellId, expensiveBite.cost = 17253, 20
affordableTorment.spellId = 3716
unaffordable.actors.pet.resource = 5
unaffordable.actors.pet.autocasts = { expensiveBite, affordableTorment }
local affordableEvents = C:Events(unaffordable, candidate)
assert(table.getn(affordableEvents) == 1
    and affordableEvents[1].autocastSpellId == 3716
    and affordableEvents[1].offset == 0
    and not unaffordable.actors.pet.autocastOrderUnknown
    and C:Apply(unaffordable, unaffordable, candidate, context,
        affordableEvents[1])
    and unaffordable.actors.pet.resource == 0
    and expensiveBite.readyIn == 0,
    "a known unaffordable autocast must not reserve the actor clock or create a false tie")

local chosenFocus = targetLocalState(guidA, false)
chosenFocus.actors.pet.resource = 30
local ambientBite = autocasts()[1]
ambientBite.spellId = 17253
chosenFocus.actors.pet.autocasts = { ambientBite }
local chosenCandidate = { downtime = 3.5, wait = 2, cast = 0, cost = 30,
    targetKey = keyA, targetGUID = guidA,
    tooltip = { gcd = 1.5 }, action = { name = "Chosen Claw",
        actor = "pet", executor = "petAbility", spellId = 16827,
        facts = { kind = "damage" } } }
local beforeChosen = C:Events(chosenFocus, chosenCandidate)
assert(table.getn(beforeChosen) == 0
    and chosenFocus.actors.pet.resource >= chosenCandidate.cost,
    "ambient autocasts must reserve the selected pet action's known focus cost")
chosenFocus.actors.pet.resource = math.max(0,
    chosenFocus.actors.pet.resource - chosenCandidate.cost)
assert(chosenFocus.actors.pet.resource == 0,
    "the selected pet action must retain all focus required when it executes")

local nilIdentity = targetLocalState(guidA, false)
local nilAmbient = autocasts()[1]
nilAmbient.spellId = nil
nilIdentity.actors.pet.autocasts = { nilAmbient }
local nilChosen = { downtime = 3, wait = 2, cast = 0,
    occupancy = 1, cost = 10, costKnown = true,
    targetKey = keyA, targetGUID = guidA,
    tooltip = { cost = 10, gcd = 1.5, cooldown = 10 },
    action = { name = "Bite", actor = "pet", executor = "petAbility",
        spellId = nil, facts = { kind = "damage" } } }
assert(table.getn(C:Events(nilIdentity, nilChosen)) == 0,
    "a chosen nil-ID pet action must exclude its exact nil-ID named autocast")
C:SyncChosenCooldown(nilIdentity, nilChosen, { applicationOffset = 2 })
assert(nilAmbient.readyIn == 9,
    "the same nil-ID identity must receive the chosen cooldown")

local mixedIdentity = targetLocalState(guidA, false)
local identifiedAmbient = autocasts()[1]
mixedIdentity.actors.pet.autocasts = { identifiedAmbient }
local mixedIdentityEvents = C:Events(mixedIdentity, nilChosen)
assert(table.getn(mixedIdentityEvents) == 1
    and mixedIdentityEvents[1].autocastSpellId == 17253,
    "a nil-ID chosen action must never cross-match a same-name identified autocast")
C:SyncChosenCooldown(mixedIdentity, nilChosen, { applicationOffset = 2 })
assert(identifiedAmbient.readyIn == 0,
    "cooldown sync must use the same no-cross-match identity rule as scheduling")

local function verifiedFocus(state, focus, amount, interval, nextIn)
    local pet = state.actors.pet
    pet.ownerClass, pet.resourceType = "HUNTER", 2
    pet.resource, pet.resourceMax = focus, 100
    pet.resourceRegen = { verified = true, resourceType = 2,
        amount = amount, interval = interval, nextIn = nextIn,
        phaseKnown = true, sourceGuid = pet.guid,
        source = "focused scheduler test",
        externalEnergizeExcluded = true }
    pet.resourceRegenKnown = true
    return pet
end

local focusWait = targetLocalState(guidA, false)
local focusBite = autocasts()[1]
focusWait.actors.pet.autocasts = { focusBite }
local focusPet = verifiedFocus(focusWait, 0, 10, 4, 2)
local focusCandidate = { downtime = 3, targetKey = keyB,
    targetGUID = guidB }
local focusEvents = C:Events(focusWait, focusCandidate)
assert(table.getn(focusEvents) == 1 and focusEvents[1].offset == 2
    and focusEvents[1].kind == "petAutocast"
    and focusPet.resource == 0,
    "zero-focus Bite must wait for the first verified lower-envelope tick without prepayment")
XelAssist.Game.Pets.Resources:AdvanceActor(focusPet, 2)
assert(focusPet.resource == 10
    and C:Apply(focusWait, focusWait, focusCandidate, context, focusEvents[1])
    and focusPet.resource == 0
    and focusWait.hostiles.byKey[keyA].health == 80,
    "an instant ambient ability must gain and spend focus only at its causal event time")

local noClock = targetLocalState(guidA, false)
noClock.actors.pet.autocasts = { autocasts()[1] }
noClock.actors.pet.ownerClass, noClock.actors.pet.resourceType = "HUNTER", 2
noClock.actors.pet.resource = 0
assert(table.getn(C:Events(noClock, focusCandidate)) == 0,
    "an unverified Hunter focus clock must never manufacture an executable event")
local unknownPhase = targetLocalState(guidA, false)
local unknownPet = verifiedFocus(unknownPhase, 0, 10, 4, 2)
unknownPet.resourceRegen.phaseKnown, unknownPet.resourceRegen.nextIn = false, nil
unknownPhase.actors.pet.autocasts = { autocasts()[1] }
assert(table.getn(C:Events(unknownPhase, focusCandidate)) == 0,
    "verified cadence without verified phase must remain non-executable")
local warlockClock = targetLocalState(guidA, false)
local warlockPet = verifiedFocus(warlockClock, 0, 10, 4, 1)
warlockPet.ownerClass = "WARLOCK"
warlockClock.actors.pet.autocasts = { autocasts()[1] }
assert(table.getn(C:Events(warlockClock, focusCandidate)) == 0,
    "a Hunter-shaped clock must not regenerate focus for a Warlock demon")

local protectedChosen = targetLocalState(guidA, false)
local protectedPet = verifiedFocus(protectedChosen, 10, 10, 10, 2)
protectedChosen.actors.pet.autocasts = { autocasts()[1] }
local delayedChosen = { downtime = 7, wait = 5, cast = 1, cost = 10,
    targetKey = keyA, targetGUID = guidA, tooltip = { gcd = 1.5 },
    action = { name = "Delayed Claw", actor = "pet",
        executor = "petAbility", spellId = 16827,
        facts = { kind = "damage" } } }
local protectedEvents = C:Events(protectedChosen, delayedChosen)
assert(table.getn(protectedEvents) == 1 and protectedEvents[1].offset == 2
    and protectedPet.resource == 10,
    "a wait-plus-cast chosen action must protect its focus from time zero while allowing proven surplus")
XelAssist.Game.Pets.Resources:AdvanceActor(protectedPet, 2)
assert(C:Apply(protectedChosen, protectedChosen, delayedChosen,
        context, protectedEvents[1]) and protectedPet.resource == 10)
XelAssist.Game.Pets.Resources:AdvanceActor(protectedPet, 4)
local chosenPaid = XelAssist.Game.Pets.Resources:SpendActor(protectedPet, 10)
assert(chosenPaid and protectedPet.resource == 0,
    "the delayed chosen pet action must still own its protected focus at application")
local noSurplus = targetLocalState(guidA, false)
noSurplus.actors.pet.ownerClass, noSurplus.actors.pet.resourceType = "HUNTER", 2
noSurplus.actors.pet.resource = 10
noSurplus.actors.pet.autocasts = { autocasts()[1] }
assert(table.getn(C:Events(noSurplus, delayedChosen)) == 0,
    "ambient lanes must not steal a future chosen cost when no verified surplus exists")

local unknownCost = targetLocalState(guidA, false)
unknownCost.actors.pet.resource = 10
local mystery = { name = "Mystery", kind = "damage", spellId = 90301,
    facts = { kind = "damage", melee = true }, power = 1,
    cooldown = 10, readyIn = 0, tooltip = { gcd = 0.1 } }
local laterBite = autocasts()[1]
laterBite.readyIn, laterBite.tooltip.gcd = 1.5, 0.1
unknownCost.actors.pet.autocasts = { mystery, laterBite }
local unknownChosen = { downtime = 6.5, wait = 5, cast = 0,
    occupancy = 1.5, cost = 10, costKnown = true,
    targetKey = keyA, targetGUID = guidA,
    tooltip = { cost = 10, gcd = 1.5 },
    action = { name = "Chosen Bite", actor = "pet",
        executor = "petAbility", spellId = 90302,
        facts = { kind = "damage" } } }
local unknownEvents = C:Events(unknownCost, unknownChosen)
assert(table.getn(unknownEvents) == 1
    and unknownEvents[1].autocastSpellId == 90301
    and unknownEvents[1].autocastCostKnown == false
    and C:Apply(unknownCost, unknownCost, unknownChosen,
        context, unknownEvents[1])
    and unknownCost.actors.pet.resource == 10
    and unknownCost.actors.pet.resourceExact == false
    and not XelAssist.Graph.CompanionResources:BeginChosen(
        unknownCost, unknownChosen, {}),
    "unknown ambient cost must poison exact focus without charging zero or admitting later paid actions")

local regenTie = targetLocalState(guidA, false)
local tiePet = verifiedFocus(regenTie, 0, 20, 2, 1)
regenTie.actors.pet.autocasts = autocasts()
local tieCandidate = { downtime = 7, targetKey = keyB,
    targetGUID = guidB }
local regenTieEvents = C:Events(regenTie, tieCandidate)
local tieCosts, tieOffsets = { 20, 15, 5, 10 }, { 1, 3, 4.5, 6 }
assert(table.getn(regenTieEvents) == 4,
    "regeneration must not collapse a simultaneous tie into one optimistic lane")
local lastOffset = 0
for i = 1, table.getn(regenTieEvents) do
    local entry = regenTieEvents[i]
    XelAssist.Game.Pets.Resources:AdvanceActor(
        tiePet, entry.offset - lastOffset)
    assert(entry.kind == "petAutocastUnknown"
        and entry.tiedReservation
        and entry.autocastCost == tieCosts[i]
        and math.abs(entry.offset - tieOffsets[i]) < 0.001
        and C:Apply(regenTie, regenTie, tieCandidate, context, entry),
        "each post-regeneration tie slot must reserve its sequential worst remaining cost")
    lastOffset = entry.offset
end
assert(tiePet.resource == 10,
    "sequential tied reservations must never spend more focus than verified ticks provide")

local splitCast = targetLocalState(guidA, false)
local splitPet = verifiedFocus(splitCast, 0, 20, 4, 1)
splitCast.actors.pet.autocasts = { { name = "Focus Firebolt",
    kind = "damage", spellId = 3110,
    facts = { kind = "damage", damageActor = "pet", ranged = true },
    power = 40, cost = 20, cooldown = 3, readyIn = 0,
    tooltip = { school = 2, cast = 2, gcd = 1.5, maxRange = 30 } } }
local splitFirst = { downtime = 2, targetKey = keyB, targetGUID = guidB }
local splitStart = C:Events(splitCast, splitFirst)
assert(table.getn(splitStart) == 1
    and splitStart[1].kind == "petAutocastStart"
    and splitStart[1].offset == 1 and splitPet.resource == 0
    and splitCast.actors.pet.pendingAutocast
    and splitCast.actors.pet.pendingAutocast.remaining == 1,
    "a regenerated cast crossing the window must persist an unpaid start ticket")
XelAssist.Game.Pets.Resources:AdvanceActor(splitPet, 1)
assert(C:Apply(splitCast, splitCast, splitFirst, context, splitStart[1])
    and splitPet.resource == 0
    and splitCast.actors.pet.pendingAutocast.costPaid,
    "the crossing cast must spend exactly once at its verified causal start")
XelAssist.Game.Pets.Resources:AdvanceActor(splitPet, 1)
local splitSecond = { downtime = 1, targetKey = keyB, targetGUID = guidB }
local splitCompletion = C:Events(splitCast, splitSecond)
assert(table.getn(splitCompletion) == 1
    and splitCompletion[1].pendingCompletion
    and splitCompletion[1].offset == 1)
XelAssist.Game.Pets.Resources:AdvanceActor(splitPet, 1)
assert(C:Apply(splitCast, splitCast, splitSecond, context,
        splitCompletion[1]) and splitPet.resource == 0
    and splitCast.hostiles.byKey[keyA].health == 80,
    "a split-window completion must not repay a cast that spent in the prior window")

do
local function verifiedSwing(state, nextIn, interval, power)
    local pet = state.actors.pet
    pet.autocasts, pet.resource, pet.actionReadyIn = {}, 0, 20
    pet.attackActive, pet.attackActiveKnown = true, true
    pet.attackRound = { projectable = true, verified = true,
        phaseKnown = true, attackActive = true,
        nextSwingIn = nextIn, interval = interval, power = power,
        damageSource = "test full pet damage", phaseSource = "resolved test round" }
    state.hostiles.byKey[keyA].geometry.pet = {
        distance = 3, distanceKind = "hitbox", lineOfSight = true }
    return pet
end

local whiteSwing = targetLocalState(guidA, false)
local whitePet = verifiedSwing(whiteSwing, 0.5, 2, 20)
local priorConsumed = table.getn(consumed)
local whiteEvents = C:Events(whiteSwing,
    { downtime = 1, targetKey = keyB, targetGUID = guidB })
local appliedWhite = whiteEvents[1]
    and C:Apply(whiteSwing, whiteSwing, candidate, context, whiteEvents[1])
assert(table.getn(whiteEvents) == 1
    and whiteEvents[1].kind == "petWhiteSwing"
    and whiteEvents[1].offset == 0.5
    and whiteEvents[1].targetGuid == guidA
    and whiteEvents[1].ambient.facts.whiteAttack and appliedWhite
    and whiteSwing.hostiles.byKey[keyA].health == 100
    and not whiteSwing.hostiles.byKey[keyA].healthExact
    and whiteSwing.hostiles.byKey[keyB].health == 200
    and whiteSwing.hostiles.byKey[keyA].projectedThreat == nil
    and whiteSwing.hostiles.byKey[keyA].threat.whiteSwingDamageUnknown
    and whitePet.whiteSwingMagnitudeUnknown
    and whitePet.resource == 0 and whitePet.actionReadyIn == 19
    and table.getn(consumed) == priorConsumed + 1
    and consumed[table.getn(consumed)].guid == guidA,
    "a verified white swing must run target-locally outside focus and pet GCD: events="
        .. tostring(table.getn(whiteEvents)) .. " applied=" .. tostring(appliedWhite)
        .. " first=" .. tostring(whiteSwing.hostiles.byKey[keyA].health)
        .. " second=" .. tostring(whiteSwing.hostiles.byKey[keyB].health)
        .. " threat=" .. tostring(whiteSwing.hostiles.byKey[keyA].projectedThreat
            and whiteSwing.hostiles.byKey[keyA].projectedThreat.pet)
        .. " resource=" .. tostring(whitePet.resource)
        .. " ready=" .. tostring(whitePet.actionReadyIn)
        .. " consumed=" .. tostring(table.getn(consumed) - priorConsumed))

local redirectedSwing = targetLocalState(guidA, false)
verifiedSwing(redirectedSwing, 0.5, 2, 20)
local redirectedEvent = C:Events(redirectedSwing,
    { downtime = 1, targetKey = keyB, targetGUID = guidB })[1]
redirectedSwing.actors.pet.targetGuid = guidB
redirectedSwing.hostiles.byUnit.pettarget = keyB
assert(not C:Apply(redirectedSwing, redirectedSwing, candidate,
        context, redirectedEvent)
    and redirectedSwing.hostiles.byKey[keyA].health == 100
    and redirectedSwing.hostiles.byKey[keyB].health == 200,
    "a target change before resolution must discard, never redirect, a white swing")

local tiedSwing = targetLocalState(guidA, false)
local tiedPet = verifiedSwing(tiedSwing, 0.5, 2, 20)
local tiedBite = autocasts()[1]
tiedBite.readyIn = 0.5
tiedPet.resource, tiedPet.actionReadyIn = 100, 0
tiedPet.autocasts = { tiedBite }
tiedPet.pendingMeleeEffects = { Intimidation = {
    remaining = 15, targetGuid = guidA, chargeProbability = 1 } }
local tiedCandidate = { downtime = 1, targetKey = keyB, targetGUID = guidB }
local tiedEvents = C:Events(tiedSwing, tiedCandidate)
local tiedApplied = tiedEvents[1]
    and C:Apply(tiedSwing, tiedSwing, tiedCandidate, context, tiedEvents[1])
assert(table.getn(tiedEvents) == 1
    and tiedEvents[1].kind == "petAutocastUnknown"
    and tiedEvents[1].meleeOrderUnknown and tiedEvents[1].tiedWhiteAmbient
    and tiedApplied and tiedPet.resource == 90
    and tiedPet.resourceExact == false and tiedPet.actionReadyExact == false
    and tiedSwing.hostiles.byKey[keyA].health == 100
    and not tiedSwing.hostiles.byKey[keyA].healthExact
    and tiedSwing.hostiles.byKey[keyA].projectedThreat == nil
    and tiedPet.pendingMeleeEffects.Intimidation.outcomeUnknown
    and tiedPet.pendingMeleeEffectsExact == false
    and tiedCandidate.companionUnknowns[2] == "companion melee order",
    "same-offset Bite and white swing must reserve cost and withhold invented order")

local boundary = targetLocalState(guidA, false)
local boundaryPet = verifiedSwing(boundary, 0.5, 3, 20)
local boundaryBite = autocasts()[1]
boundaryBite.readyIn, boundaryBite.cooldown = 0.5, 0.2
boundaryBite.tooltip.gcd = 0.1
boundaryPet.resource, boundaryPet.actionReadyIn = 100, 0
boundaryPet.autocasts = { boundaryBite }
local boundaryCandidate = {
    downtime = 1.2, targetKey = keyB, targetGUID = guidB }
local boundaryEvents = C:Events(boundary, boundaryCandidate)
causalSort(boundaryEvents)
assert(table.getn(boundaryEvents) > 1
    and boundaryEvents[1].kind == "petAutocastUnknown"
    and C:Apply(boundary, boundary, boundaryCandidate,
        context, boundaryEvents[1]),
    "a white-swing/autocast tie must establish a causal boundary")
for i = 2, table.getn(boundaryEvents) do
    assert(not C:Apply(boundary, boundary, boundaryCandidate,
        context, boundaryEvents[i]),
        "events after an unresolved companion order must be withheld")
end
assert(boundaryPet.resource == 90
    and boundaryPet.companionTimelineExact == false
    and not boundary.hostiles.byKey[keyA].healthExact,
    "the boundary must prevent later focus, damage, threat and cooldown commits")

local stoppedSwing = targetLocalState(guidA, false)
local stoppedPet = verifiedSwing(stoppedSwing, 0.5, 2, 20)
local stoppedEvent = C:Events(stoppedSwing,
    { downtime = 1, targetKey = keyB, targetGUID = guidB })[1]
stoppedPet.attackActive = false
assert(not C:Apply(stoppedSwing, stoppedSwing, candidate, context, stoppedEvent)
    and stoppedSwing.hostiles.byKey[keyA].health == 100,
    "a stopped companion must invalidate a previously scheduled white swing")

local heldSwing = targetLocalState(guidA, false)
local heldPet = verifiedSwing(heldSwing, 0.5, 2, 20)
heldSwing.hostiles.byKey[keyA].geometry.pet = {}
local heldCandidate = { downtime = 1, targetKey = keyB, targetGUID = guidB }
local heldEvents = C:Events(heldSwing, heldCandidate)
assert(table.getn(heldEvents) == 0 and heldPet.attackRound.readyHeld
    and heldPet.whiteSwingGeometryUnknown
    and heldCandidate.companionUnknowns[1] == "companion melee geometry",
    "unknown pet geometry must hold a ready swing without inventing damage")
heldSwing.hostiles.byKey[keyA].geometry.pet = {
    distance = 3, distanceKind = "hitbox", lineOfSight = true }
local releasedEvents = C:Events(heldSwing,
    { downtime = 0.1, targetKey = keyB, targetGUID = guidB })
assert(table.getn(releasedEvents) == 1
    and releasedEvents[1].offset == 0.05,
    "a held swing may resume only after exact legal geometry returns")
end

local failedCast = targetLocalState(guidA, false)
failedCast.actors.pet.resource = 20
failedCast.actors.pet.autocasts = { { name = "Lost Firebolt",
    kind = "damage", spellId = 3110,
    facts = { kind = "damage", damageActor = "pet", ranged = true },
    power = 40, cost = 20, cooldown = 3, readyIn = 0,
    tooltip = { school = 2, cast = 2, gcd = 1.5, maxRange = 30 } } }
local lostStart = C:Events(failedCast, candidate)
failedCast.actors.pet.targetExists, failedCast.actors.pet.targetGuid = false, nil
assert(table.getn(lostStart) == 1
    and not C:Apply(failedCast, failedCast, candidate, context, lostStart[1])
    and failedCast.actors.pet.resource == 20
    and not failedCast.actors.pet.pendingAutocast
    and failedCast.actors.pet.actionReadyIn == 0
    and (failedCast.actorReadyAt and failedCast.actorReadyAt.pet or 0) == 0
    and table.getn(C:Events(failedCast, completionCandidate)) == 0,
    "target loss before cast start must spend nothing and make completion impossible")

local cappedStarts = targetLocalState(guidA, false)
cappedStarts.actors.pet.resource, cappedStarts.actors.pet.resourceMax = 1000, 1000
cappedStarts.actors.pet.autocasts = { { name = "Rapid Cast",
    kind = "damage", spellId = 99901,
    facts = { kind = "damage", damageActor = "pet", ranged = true },
    power = 1, cost = 1, cooldown = 0.1, readyIn = 0,
    tooltip = { school = 2, cast = 0.1, gcd = 0.1, maxRange = 30 } } }
local cappedEvents = C:Events(cappedStarts,
    { downtime = 2, targetKey = keyB, targetGUID = guidB })
local starts, completions = 0, 0
for i = 1, table.getn(cappedEvents) do
    if cappedEvents[i].kind == "petAutocastStart" then starts = starts + 1
    elseif cappedEvents[i].kind == "petAutocast"
        or cappedEvents[i].kind == "petAutocastUnknown" then
        completions = completions + 1
    end
end
assert(starts == 8 and completions == 8
    and cappedStarts.actors.pet.autocastTimelineCapped,
    "cast-start records must share the eight-ability cap: starts="
        .. tostring(starts) .. " completions=" .. tostring(completions)
        .. " events=" .. tostring(table.getn(cappedEvents)))

local lethalBite = targetLocalState(guidA, false)
lethalBite.actors.pet.autocasts = { autocasts()[1] }
lethalBite.hostiles.byKey[keyA].health = 5
local lethalBiteEvent = C:Events(lethalBite, candidate)[1]
assert(C:Apply(lethalBite, lethalBite, candidate, context, lethalBiteEvent)
    and lethalBite.hostiles.byKey[keyA].dead
    and math.abs(lethalBite.hostiles.byKey[keyA].projectedThreat.pet - 4.5)
        < 0.001,
    "lethal passive Bite threat must stop at actual health-capped damage")

local probabilistic = targetLocalState(guidA, false)
probabilistic.actors.pet.autocasts = { autocasts()[2] }
probabilistic.hostiles.byKey[keyA].resistance.delivery = 0.5
local probabilisticBefore = EventAuras:Snapshot(probabilistic)
local probabilisticEvent = C:Events(probabilistic, candidate)[1]
assert(C:Apply(probabilistic, probabilistic, candidate, context,
        probabilisticEvent)
    and probabilistic.hostiles.byKey[keyA].projectedThreat == nil,
    "periodic threat must not be front-loaded before a tick deals damage")
local probabilisticTracked = {}
EventAuras:Track(probabilistic, probabilisticBefore, probabilisticTracked)
EventAuras:Advance(probabilistic, probabilisticTracked, 2)
assert(math.abs(probabilistic.hostiles.byKey[keyA].projectedThreat.pet - 9)
        < 0.001,
    "periodic threat must accrue once from health-capped tick damage")

probabilistic.actors.pet.autocasts[1].readyIn = 0
local replacementBefore = EventAuras:Snapshot(probabilistic)
local replacementEvent = C:Events(probabilistic, candidate)[1]
assert(C:Apply(probabilistic, probabilistic, candidate, context,
    replacementEvent), "a refreshed pet DoT must replace its prior clock")
EventAuras:Track(probabilistic, replacementBefore, probabilisticTracked)
EventAuras:Advance(probabilistic, probabilisticTracked, 2)
assert(math.abs(probabilistic.hostiles.byKey[keyA].projectedThreat.pet - 27)
        < 0.001,
    "replacing a stacking pet DoT must run only its new stronger threat clock")

local lethal = targetLocalState(guidA, false)
lethal.actors.pet.autocasts = { autocasts()[2] }
lethal.hostiles.byKey[keyA].health = 5
lethal.hostiles.byKey[keyA].resistance.delivery = 0.5
local lethalBefore = EventAuras:Snapshot(lethal)
assert(C:Apply(lethal, lethal, candidate, context,
    C:Events(lethal, candidate)[1]))
local lethalTracked = {}
EventAuras:Track(lethal, lethalBefore, lethalTracked)
EventAuras:Advance(lethal, lethalTracked, 10)
assert(lethal.hostiles.byKey[keyA].dead
    and math.abs(lethal.hostiles.byKey[keyA].projectedThreat.pet - 4.5) < 0.001,
    "pet DoT threat must stop at actual lethal damage, not its full duration")

local areaState = targetLocalState(guidA, false)
areaState.actors.pet.autocasts = { { name = "Thunderstomp", kind = "damage",
    facts = { kind = "damage", damageActor = "pet", aoe = true },
    power = 80, cost = 20, cooldown = 10, readyIn = 0, tooltip = {} } }
local areaEvents = C:Events(areaState, candidate)
assert(table.getn(areaEvents) == 1
    and areaEvents[1].kind == "petAutocastUnknown"
    and areaState.actors.pet.areaAutocastUnknown
    and C:Apply(areaState, areaState, candidate, context, areaEvents[1])
    and areaState.actors.pet.resource == 80
    and areaState.actors.pet.autocasts[1].readyIn > 0
    and areaState.hostiles.byKey[keyA].health == 100,
    "pet area autocasts must reserve focus/cooldown without invented recipients")

local aliasState = targetLocalState(nil, false)
aliasState.actors.pet.autocasts = { autocasts()[1] }
local aliasEvents = C:Events(aliasState, candidate)
assert(table.getn(aliasEvents) == 1 and aliasEvents[1].targetGuid == guidA,
    "pettarget aliases must provide exact off-selected identity for non-Hunter pets")

local conflictState = targetLocalState(guidB, false)
assert(table.getn(C:Events(conflictState, candidate)) == 0,
    "disagreeing pet lifecycle and pettarget identities must withhold projection")

local selectedState = targetLocalState(guidB, true)
selectedState.actors.pet.autocasts = { autocasts()[1] }
selectedState.hostiles.byUnit.pettarget = keyB
local selectedEvents = C:Events(selectedState, candidate)
assert(C:Apply(selectedState, selectedState, candidate, context,
        selectedEvents[1])
    and selectedState.hostiles.byKey[keyB].health == 196
    and selectedState.targetHealth == 196 and syncs == 1,
    "a selected-record change must sync its legacy mirror exactly once")

local missingState = targetLocalState(guidA, false)
missingState.actors.pet.autocasts = { autocasts()[1] }
local missingEvent = C:Events(missingState, candidate)[1]
missingState.hostiles.byKey[keyA] = nil
assert(not C:Apply(missingState, missingState, candidate, context, missingEvent)
    and missingState.targetHealth == 200
    and missingState.actors.pet.resource == 100,
    "a missing captured target must be withheld, never redirected to selection")
missingState.actors.pet.targetGuid = guidMissing
assert(table.getn(C:Events(missingState, candidate)) == 0,
    "an unobserved pet target must receive no projected event")

local legacy = targetLocalState(nil, true)
legacy.hostiles, legacy.actors.pet.autocasts = nil, { autocasts()[1] }
legacy.actors.pet.targetGuid = nil
local legacyEvent = C:Events(legacy, candidate)[1]
assert(legacyEvent and not legacyEvent.targetLocal
    and legacyEvent.targetGuid == guidB
    and C:Apply(legacy, legacy, candidate, context, legacyEvent)
    and legacy.targetHealth == 196,
    "legacy no-hostiles states must retain conservative selected-target behavior")

dofile("Graph/OngoingEffects.lua")
local O = XelAssist.Graph.OngoingEffects

local function periodicAura(rate, remaining)
    return { remaining = remaining, duration = remaining, mine = true,
        target = "target", periodicRate = rate, periodicInterval = 2,
        periodicNextIn = 2, applicationProbability = 1 }
end

XelAssist.Graph.ActionEffects = {
    Consume = function() end,
    Apply = function() end,
}
XelAssist.Graph.AutoShotEffects = {
    CreateTimeline = function() return nil end,
}
dofile("Graph/Timeline.lua")
local Timeline = XelAssist.Graph.Timeline
local function passiveWindow(out, source, duration)
    local window = { action = { name = "Wait", actor = "player",
            facts = { kind = "buff", self = true } },
        target = "player", targetRelation = "self", targetKey = keyB,
        targetGUID = guidB, downtime = duration }
    local windowContext = { applicationOffset = 0,
        ChangesHostileTarget = function() return false end }
    return Timeline:Run(out, source, window, windowContext)
end

local cappedSource = targetLocalState(guidA, false)
local cappedOut = targetLocalState(guidA, false)
local function rapidAutocast()
    return { name = "Rapid Cast", kind = "damage", spellId = 99901,
        facts = { kind = "damage", damageActor = "pet", ranged = true },
        power = 1, cost = 1, cooldown = 0.1, readyIn = 0,
        tooltip = { school = 2, cast = 0.1, gcd = 0.1, maxRange = 30 } }
end
cappedSource.actors.pet.resource, cappedOut.actors.pet.resource = 1000, 1000
cappedSource.actors.pet.resourceMax, cappedOut.actors.pet.resourceMax = 1000, 1000
cappedSource.actors.pet.autocasts = { rapidAutocast() }
cappedOut.actors.pet.autocasts = { rapidAutocast() }
passiveWindow(cappedOut, cappedSource, 2)
local cappedChosen = { action = { name = "Paid Bite", actor = "pet",
        executor = "petAbility", facts = { kind = "damage" } },
    cost = 1, costKnown = true, tooltip = { cost = 1 },
    wait = 0, occupancy = 0.1, downtime = 0.1 }
assert(cappedOut.actors.pet.resource == 992
    and cappedOut.actors.pet.resourceExact == false
    and cappedOut.actors.pet.actionReadyExact == false
    and not XelAssist.Graph.CompanionResources:BeginChosen(
        cappedOut, cappedChosen, {}),
    "a Timeline cap must causally invalidate resource and readiness before later actions")

local replacedSource = targetLocalState(guidA, false)
local replacedOut = targetLocalState(guidA, false)
replacedSource.actors.pet.autocasts = { autocasts()[2] }
replacedOut.actors.pet.autocasts = { autocasts()[2] }
replacedSource.actors.pet.autocasts[1].readyIn = 1
replacedOut.actors.pet.autocasts[1].readyIn = 1
replacedSource.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"] =
    periodicAura(10, 10)
replacedOut.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"] =
    periodicAura(10, 10)
passiveWindow(replacedOut, replacedSource, 4)
local replacedRecord = replacedOut.hostiles.byKey[keyA]
assert(replacedRecord.health == 80
    and replacedOut.hostiles.byKey[keyB].health == 200
    and replacedRecord.projectedAuras["Scorpid Poison"].remaining == 7
    and math.abs(replacedRecord.projectedThreat.pet - 18) < 0.001,
    "ambient pet DoT replacement must invalidate the old scheduled clock on only its GUID")

local uncertainSource = targetLocalState(guidA, false)
local uncertainOut = targetLocalState(guidA, false)
uncertainSource.actors.pet.autocasts = { autocasts()[2] }
uncertainOut.actors.pet.autocasts = { autocasts()[2] }
uncertainSource.actors.pet.autocasts[1].readyIn = 1
uncertainOut.actors.pet.autocasts[1].readyIn = 1
uncertainSource.hostiles.byKey[keyA].health = 500
uncertainOut.hostiles.byKey[keyA].health = 500
uncertainSource.hostiles.byKey[keyA].resistance.delivery = 0.5
uncertainOut.hostiles.byKey[keyA].resistance.delivery = 0.5
local uncertainPrior = periodicAura(30, 10)
uncertainPrior.stacks, uncertainPrior.expectedStacks = 3, 3
uncertainPrior.periodicThreatActor = "pet"
uncertainPrior.periodicThreatMultiplier = 0.9
uncertainSource.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"] =
    uncertainPrior
local uncertainOutPrior = periodicAura(30, 10)
uncertainOutPrior.stacks, uncertainOutPrior.expectedStacks = 3, 3
uncertainOutPrior.periodicThreatActor = "pet"
uncertainOutPrior.periodicThreatMultiplier = 0.9
uncertainOut.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"] =
    uncertainOutPrior
passiveWindow(uncertainOut, uncertainSource, 4)
local uncertainRecord = uncertainOut.hostiles.byKey[keyA]
local uncertainAura = uncertainRecord.projectedAuras["Scorpid Poison"]
assert(uncertainRecord.health == 400
    and uncertainOut.hostiles.byKey[keyB].health == 200
    and uncertainAura.expectedStacks == 3.5
    and uncertainAura.periodicRate == 20
    and table.getn(uncertainAura.periodicBranches) == 1
    and uncertainAura.periodicBranches[1].periodicRate == 15
    and math.abs(uncertainRecord.projectedThreat.pet - 90) < 0.001,
    "an uncertain ambient stack refresh must split success and old failure clocks")
passiveWindow(uncertainOut, uncertainOut, 2)
uncertainRecord = uncertainOut.hostiles.byKey[keyA]
assert(uncertainRecord.health == 330
    and math.abs(uncertainRecord.projectedThreat.pet - 153) < 0.001,
    "ambient success and failure clocks must both survive the next Timeline")

local stackedSource = targetLocalState(guidA, false)
local stackedOut = targetLocalState(guidA, false)
stackedSource.actors.pet.autocasts = { autocasts()[2] }
stackedOut.actors.pet.autocasts = { autocasts()[2] }
stackedSource.actors.pet.autocasts[1].readyIn = 0.5
stackedOut.actors.pet.autocasts[1].readyIn = 0.5
stackedSource.hostiles.byKey[keyA].health = 500
stackedOut.hostiles.byKey[keyA].health = 500
local liveStack = { spellId = 1978, stacks = 3, remaining = 1,
    duration = 10, playerOrPet = true }
stackedSource.hostiles.byKey[keyA].targetAuras["Scorpid Poison"] = liveStack
local outLiveStack = { spellId = 1978, stacks = 3, remaining = 1,
    duration = 10, playerOrPet = true }
stackedOut.hostiles.byKey[keyA].targetAuras["Scorpid Poison"] = outLiveStack
stackedSource.actors.pet.autocasts[1].spellId = 1978
stackedOut.actors.pet.autocasts[1].spellId = 1978
passiveWindow(stackedOut, stackedSource, 2.5)
local stackedRecord = stackedOut.hostiles.byKey[keyA]
local projectedStack = stackedRecord.projectedAuras["Scorpid Poison"]
assert(stackedRecord.health == 420
    and stackedOut.hostiles.byKey[keyB].health == 200
    and projectedStack ~= outLiveStack
    and projectedStack.stacks == 4 and projectedStack.expectedStacks == 4
    and not stackedRecord.targetAuras["Scorpid Poison"]
    and outLiveStack.stacks == 3
    and math.abs(stackedRecord.projectedThreat.pet - 72) < 0.001,
    "an event-time live pet stack must seed one separate projected damage/threat clock")

local laterSource = targetLocalState(guidA, false)
local laterOut = targetLocalState(guidA, false)
laterSource.actors.pet.autocasts, laterOut.actors.pet.autocasts = {}, {}
local laterAura = periodicAura(10, 4)
laterAura.periodicThreatActor, laterAura.periodicThreatMultiplier = "pet", 0.9
laterSource.hostiles.byKey[keyA].projectedAuras.Poison = laterAura
laterOut.hostiles.byKey[keyA].projectedAuras.Poison = periodicAura(10, 4)
laterOut.hostiles.byKey[keyA].projectedAuras.Poison.periodicThreatActor = "pet"
laterOut.hostiles.byKey[keyA].projectedAuras.Poison.periodicThreatMultiplier = 0.9
local laterPersistent = O:PersistentAuraSnapshot(laterOut)
local laterEvents = O:Prepare(laterOut, laterSource,
    { downtime = 2, targetKey = keyB, targetGUID = guidB }, context)
assert(table.getn(laterEvents) == 1)
O:AdvanceState(laterOut, laterEvents[1].offset, laterPersistent)
O:ApplyEvent(laterOut, laterSource, candidate, context, laterEvents[1])
assert(laterOut.hostiles.byKey[keyA].health == 80
    and math.abs(laterOut.hostiles.byKey[keyA].projectedThreat.pet - 18) < 0.001,
    "a pet DoT carried into a later transition must retain tick-time threat")

local ongoingSource = targetLocalState(guidA, false)
local ongoingOut = targetLocalState(guidA, false)
ongoingSource.actors.pet.autocasts, ongoingOut.actors.pet.autocasts = {}, {}
local sourceA = ongoingSource.hostiles.byKey[keyA]
local outA = ongoingOut.hostiles.byKey[keyA]
sourceA.projectedAuras.Poison = periodicAura(10, 2)
outA.projectedAuras.Poison = periodicAura(10, 2)
outA.projectedAuras.Curse = { remaining = 1, targetModifier = true }
outA.modifierEffects.Curse = { active = true }
outA.targetAuras.Observed = { remaining = 1 }
local ongoingCandidate = { downtime = 2, targetKey = keyB,
    targetGUID = guidB }
local ongoingPersistent = O:PersistentAuraSnapshot(ongoingOut)
local ongoingEvents = O:Prepare(
    ongoingOut, ongoingSource, ongoingCandidate, context)
assert(table.getn(ongoingEvents) == 1
    and ongoingEvents[1].targetKey == keyA
    and ongoingEvents[1].targetGuid == guidA
    and ongoingOut.time == 0 and outA.projectedAuras.Poison
    and outA.projectedAuras.Curse and outA.targetAuras.Observed,
    "event collection must retain identity without pre-aging graph state")
O:AdvanceState(ongoingOut, ongoingEvents[1].offset, ongoingPersistent)
O:ApplyEvent(ongoingOut, ongoingSource, ongoingCandidate,
    context, ongoingEvents[1])
assert(ongoingOut.time == 2 and outA.health == 80
    and ongoingOut.targetHealth == 200
    and not outA.projectedAuras.Poison
    and not outA.projectedAuras.Curse
    and not outA.targetAuras.Observed
    and removedModifiers[table.getn(removedModifiers)].guid == guidA,
    "off-selected periodic damage, expiration, and modifier removal must stay local")

local causalState = { time = 10, playerCasting = true,
    playerChanneling = true, playerCastName = "Test Channel",
    castRemaining = 2, auras = {}, targetAuras = {
        Observed = { remaining = 1 } }, actors = {},
    friendlies = { order = { "ally" }, byKey = { ally = {
        health = 50, healthMax = 100,
        auras = { Renew = { remaining = 4, periodicHealRate = 10 } },
        absorbs = { Shield = { remaining = 1 } } } } } }
local causalPersistent = O:PersistentAuraSnapshot(causalState)
O:AdvanceState(causalState, 0.5, causalPersistent)
assert(causalState.time == 10.5 and causalState.castRemaining == 1.5
    and causalState.friendlies.byKey.ally.health == 55
    and causalState.friendlies.byKey.ally.auras.Renew.remaining == 3.5
    and causalState.friendlies.byKey.ally.absorbs.Shield.remaining == 0.5
    and causalState.targetAuras.Observed.remaining == 0.5,
    "the persistent graph clock must expose state at each event boundary")
O:AdvanceState(causalState, 1.5, causalPersistent)
assert(causalState.time == 12 and not causalState.playerCasting
    and not causalState.playerChanneling and not causalState.playerCastName
    and causalState.friendlies.byKey.ally.health == 70
    and causalState.friendlies.byKey.ally.auras.Renew.remaining == 2
    and not causalState.friendlies.byKey.ally.absorbs.Shield
    and not causalState.targetAuras.Observed,
    "segmented advancement must equal the final persistent state")

local dynamic = targetLocalState(guidA, false)
dynamic.actors.pet.autocasts = { autocasts()[2] }
local before = O:AuraSnapshot(dynamic)
local dynamicEvent = C:Events(dynamic, candidate)[1]
assert(C:Apply(dynamic, dynamic, candidate, context, dynamicEvent),
    "off-selected pet DoT application must resolve before clock tracking")
local tracked, syncBeforeDynamic = {}, syncs
O:TrackEventAuras(dynamic, before, tracked)
O:AdvanceEventAuras(dynamic, tracked, 2)
assert(dynamic.hostiles.byKey[keyA].health == 80
    and dynamic.hostiles.byKey[keyB].health == 200
    and dynamic.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"].remaining == 8,
    "an event-created off-selected DoT must tick and age on its own record")
O:AdvanceEventAuras(dynamic, tracked, 8)
assert(dynamic.hostiles.byKey[keyA].health == 0
    and dynamic.hostiles.byKey[keyA].dead
    and not dynamic.hostiles.byKey[keyA].projectedAuras["Scorpid Poison"]
    and dynamic.targetHealth == 200 and syncs == syncBeforeDynamic,
    "off-selected DoTs must continue through death and expiry without mirror sync")

local sameName = targetLocalState(guidA, false)
sameName.actors.pet.autocasts = {}
local sameBefore = O:AuraSnapshot(sameName)
sameName.hostiles.byKey[keyA].projectedAuras.Poison = periodicAura(10, 4)
sameName.hostiles.byKey[keyB].projectedAuras.Poison = periodicAura(5, 4)
local sameTracked = {}
O:TrackEventAuras(sameName, sameBefore, sameTracked)
O:AdvanceEventAuras(sameName, sameTracked, 2)
assert(sameName.hostiles.byKey[keyA].health == 80
    and sameName.hostiles.byKey[keyB].health == 190
    and sameName.targetHealth == 190
    and sameName.hostiles.byKey[keyA].projectedAuras.Poison.remaining == 2
    and sameName.hostiles.byKey[keyB].projectedAuras.Poison.remaining == 2,
    "same-named hostile DoTs must keep independent opaque-keyed clocks")

local unknownHealth = targetLocalState(guidA, false)
unknownHealth.actors.pet.autocasts = {}
local unknownRecord = unknownHealth.hostiles.byKey[keyA]
unknownRecord.health, unknownRecord.healthExact = nil, false
local unknownBefore = O:AuraSnapshot(unknownHealth)
unknownRecord.projectedAuras.Poison = periodicAura(50, 4)
local unknownTracked = {}
O:TrackEventAuras(unknownHealth, unknownBefore, unknownTracked)
O:AdvanceEventAuras(unknownHealth, unknownTracked, 2)
assert(unknownRecord.health == nil and not unknownRecord.dead
    and unknownRecord.projectedAuras.Poison.remaining == 2
    and unknownHealth.hostiles.byKey[keyB].health == 200
    and unknownHealth.targetHealth == 200,
    "unknown off-target health must not borrow selected certainty or health")

-- A chosen friendly HoT is created at its application event. Its remaining
-- occupancy is then advanced by the shared clock, so application must not
-- pre-age the same healing interval.
XelAssist.Graph.State.PrimaryFriendly = function(_, value)
    local friendlies = value.friendlies
    return friendlies and friendlies.byKey[friendlies.primaryKey]
end
XelAssist.Graph.State.FriendlyByUnit = function() return nil end
XelAssist.Graph.HostileEffects = {
    Apply = function() return false end,
    ApplyPrimaryThreat = function() end,
    FinalizeSelected = function() end,
}
XelAssist.Graph.ReadinessEffects = { Apply = function() end }
XelAssist.Graph.DotProjection = {
    Candidate = function() return 0, 0, 1, 0 end,
}
XelAssist.Graph.ResourceExchange = { Apply = function() return false end }
XelAssist.Graph.WandCommitment = {
    Apply = function() return false end,
    Advance = function() end,
    AfterAction = function() end,
}
XelAssist.Graph.ComboEffects = { Apply = function() end }
XelAssist.Graph.CompanionThreat = { Apply = function() return false end }
XelAssist.Graph.CompanionEventThreat = nil
XelAssist.Graph.ActionConsumption = { Consume = function() return true end }
XelAssist.Game.Pets.Effects.Apply = function() return false end
XelAssist.Graph.AutoShotEffects = {
    CreateTimeline = function() return nil end,
    FinishTimeline = function() end,
}
dofile("Graph/FriendlyActionEffects.lua")
dofile("Graph/ActionEffects.lua")
dofile("Graph/Timeline.lua")

local hotTarget = { key = "ally", unit = "party1", guid = "ally-guid",
    health = 450, healthMax = 1000, exact = true, auras = {}, absorbs = {} }
local hotState = { time = 0, hostile = false, health = 100, healthMax = 100,
    resource = 100, resourceMax = 100, targetHealth = 0,
    targetHealthExact = false, auras = {}, targetAuras = {}, actors = {},
    actorReadyAt = { player = 0 }, absorbs = {},
    friendlies = { order = { "ally" }, primaryKey = "ally",
        byKey = { ally = hotTarget } } }
local hotAction = { name = "Causal Renew", actor = "player",
    facts = { kind = "hot" } }
local hotCandidate = { action = hotAction, target = "party1",
    targetKey = "ally", targetGUID = "ally-guid", targetRelation = "friendly",
    wait = 0, cast = 0, occupancy = 1.5, downtime = 1.5,
    cost = 0, power = 600, actionStart = 0,
    tooltip = { duration = 12 } }
local hotContext = XelAssist.Graph.ActionEffects:Context(
    hotState, hotCandidate)
XelAssist.Graph.Timeline:Run(hotState, hotState, hotCandidate, hotContext)
assert(hotTarget.health == 525
    and hotTarget.auras[hotAction.name].remaining == 10.5,
    "a chosen friendly HoT must heal and age exactly once after application")

print("ok: exact target-local passive companion events and aura clocks")
