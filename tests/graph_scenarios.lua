XelAssist = { Core = {}, Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Combat/Knowledge.lua")
dofile("Combat/TriggeredActions.lua")
dofile("Combat/Wand.lua")
dofile("Combat/AutoShotRange.lua")
dofile("Combat/AutoShotFlights.lua")
dofile("Combat/AutoShot.lua")
dofile("Combat/AutoShotProjection.lua")
dofile("Combat/PetKnowledge.lua")
dofile("Game/SpellTiming.lua")
dofile("Game/SpellClassification.lua")
dofile("Game/SpellPower.lua")
dofile("Game/SpellEffectPower.lua")
dofile("Game/SpellFactCache.lua")
dofile("Game/Range.lua")
dofile("Game/ResourceCost.lua")
dofile("Game/ResourceExchange.lua")
dofile("Game/HealthTransfer.lua")
dofile("Game/CrowdControl.lua")
dofile("Game/Player/RogueFeint.lua")
dofile("Game/ActionInference.lua")
dofile("Game/CapabilityInvalidation.lua")
dofile("Game/Capabilities.lua")
dofile("Game/WeaponPower.lua")
dofile("Game/PlayerAttack.lua")
dofile("Game/Player/Engagement.lua")
-- Class-neutral form IDs constrain sealed DBC stance masks at every depth.
dofile("Game/Player/FormEvidence.lua")
-- Live Warrior evidence is inert until State:Snapshot observes a player.
dofile("Game/Player/WarriorStanceEffects.lua")
dofile("Game/Player/ReactiveEvidence.lua")
dofile("Game/Player/Resources.lua")
dofile("Game/Pets/Resources.lua")
dofile("Game/Pets/Actions.lua")
dofile("Game/Pets/CommandState.lua")
dofile("Game/Pets/Effects.lua")
dofile("Game/Actors.lua")
dofile("Game/Friendlies.lua")
dofile("Combat/TargetModifiers.lua")
dofile("Graph/HostileState.lua")
dofile("Graph/State.lua")
dofile("Graph/CrowdControl.lua")
dofile("Graph/HunterAspects.lua")
dofile("Graph/FormRequirements.lua")
dofile("Graph/EquipmentRequirements.lua")
dofile("Graph/WarriorStances.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/ThreatDrop.lua")
dofile("Graph/RogueFeint.lua")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassActionMechanics.lua")
dofile("Graph/ClassMechanics.lua")
dofile("Graph/ReactiveState.lua")
dofile("Graph/HostileCastState.lua")
dofile("Graph/IncomingAbsorbs.lua")
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/HostileCastEvents.lua")
dofile("Graph/IncomingScoring.lua")
dofile("Graph/HealingTriage.lua")
dofile("Graph/HealingTriageEvidence.lua")
dofile("Graph/ResourceExchange.lua")
dofile("Graph/HealthTransfer.lua")
dofile("Graph/ComboState.lua")
dofile("Graph/CompanionTargets.lua")
dofile("Graph/CompanionCommandPolicy.lua")
dofile("Graph/HostileTargetPolicy.lua")
dofile("Graph/TargetSelection.lua")
dofile("Graph/CompanionThreat.lua")
dofile("Graph/CompanionEventThreat.lua")
dofile("Graph/CooldownLedger.lua")
dofile("Graph/ActionAdmission.lua")
dofile("Graph/StealthSetup.lua")
dofile("Graph/ChannelBreakpoint.lua")
dofile("Graph/ChannelCommitment.lua")
dofile("Graph/MovementSetup.lua")
dofile("Graph/Charge.lua")
dofile("Graph/PlayerTaunt.lua")
dofile("Graph/SpatialEffects.lua")
dofile("Graph/SpatialRequirements.lua")
dofile("Graph/ActionContextPolicy.lua")
dofile("Graph/TargetAuras.lua")
dofile("Graph/Targets.lua")
dofile("Graph/StackedModifiers.lua")
dofile("Graph/Effects.lua")
dofile("Graph/AreaRecipients.lua")
dofile("Graph/PrimaryThreatEffects.lua")
dofile("Graph/HostileEffects.lua")
dofile("Graph/WandCommitment.lua")
dofile("Graph/AutoShotUncertainty.lua")
dofile("Graph/AutoShotEffects.lua")
dofile("Graph/CompanionTieScheduler.lua")
dofile("Graph/CompanionResources.lua")
dofile("Graph/CompanionCastEvents.lua")
dofile("Graph/CompanionScheduler.lua")
dofile("Graph/CompanionCastRuntime.lua")
dofile("Graph/CompanionSwings.lua")
dofile("Graph/CompanionEvents.lua")
dofile("Graph/EventAuras.lua")
dofile("Graph/ReadinessEffects.lua")
dofile("Graph/PlayerEngagement.lua")
dofile("Graph/ActorScoring.lua")
dofile("Graph/ManaOpportunity.lua")
dofile("Graph/ThreatScoring.lua")
dofile("Graph/PlayerRage.lua")
dofile("Graph/PlayerSwings.lua")
dofile("Graph/PlayerSwingScoring.lua")
dofile("Graph/PlayerAttackCommitment.lua")
dofile("Graph/ComboEffects.lua")
dofile("Graph/ComboScoring.lua")
dofile("Graph/OngoingEffects.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/DotProjection.lua")
dofile("Graph/FriendlyActionEffects.lua")
dofile("Graph/ActionEffects.lua")
dofile("Graph/AmbientTargetHealth.lua")
dofile("Graph/TimelineProbe.lua")
dofile("Graph/CrowdControlTimeline.lua")
dofile("Graph/Timeline.lua")
dofile("Graph/ActionPower.lua")
dofile("Graph/SurvivalPressure.lua")
dofile("Graph/PeriodicScoring.lua")
dofile("Graph/Candidate.lua")
dofile("Graph/StateUtilityScoring.lua")
dofile("Graph/Scoring.lua")
dofile("Graph/Transitions.lua")
dofile("Graph/SearchPolicy.lua")
dofile("Graph/SearchBranches.lua")
dofile("Graph/ResourceInvestment.lua")
dofile("Graph/PlanDiagnostics.lua")
dofile("Graph/PlanBuilder.lua")
dofile("Graph/RootActionFacts.lua")
if XelAssistGraphScenarioSetupOnly then
    dofile("Core/CombatRevision.lua")
    dofile("Graph/RootObservation.lua")
    dofile("Graph/SearchLifecycle.lua")
    dofile("Graph/SearchPreparation.lua")
end
dofile("Graph/SearchSession.lua")
dofile("Graph/Engine.lua")

local pendingAura
XelAssist.IsAuraPending = function(_, name) return pendingAura == name end
XelAssist.Combat.Observations = {
    Blocker = function() return nil end,
    ResistanceMultiplier = function(_, _, target, tooltip, s)
        if XelAssist.Graph.testDelivery then
            return XelAssist.Graph.testDelivery, "shared delivery test",
                { multiplier = XelAssist.Graph.testDelivery, landChance = 1,
                    source = "shared delivery test", unknown = false }
        end
        local raw = target == "target" and s.targetResistances
            and tooltip.school and s.targetResistances[tooltip.school + 1]
        if raw and s.playerLevel then
            local ratio = math.min(1, raw / (math.max(20, s.playerLevel) * 5))
            local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
            local multiplier = 1 - mitigation
            return multiplier, "live resistance",
                { multiplier = multiplier, landChance = 1,
                    source = "live resistance", unknown = false }
        end
        return 1, "scenario exact delivery",
            { multiplier = 1, landChance = 1,
                source = "scenario exact delivery", unknown = false }
    end
}
XelAssist.Combat.Resistance = nil
local scenarioItems = {}
XelAssist.Game.Inventory = {
    Actions = function() return scenarioItems end,
    Blocker = function() return nil end,
    Cooldown = function() return 0 end
}
XelAssistCharDB = { toggles = { cooldowns = true, reagents = true,
    petActions = true, petControl = false, engagedTargets = false },
    graphDepth = 1, role = "damage", allowAoe = false }
GetTime = function() return 0 end
QueueSpellByName = function() end

local scenarioActions = {}
XelAssist.Game.Capabilities.Actions = function() return scenarioActions end
XelAssist.Game.Actors.Actions = function() return scenarioActions end
XelAssist.Game.Capabilities.Facts = function(_, action) return action.mock end
XelAssist.Game.Actors.Facts = function(_, action) return action.mock end
XelAssist.Game.Actors.PetCooldown = function() return 0 end
local reagentAvailable = true
XelAssist.Game.Actors.HasReagent = function() return reagentAvailable end
local dispelTarget
XelAssist.Game.Actors.DispelTarget = function() return dispelTarget end
XelAssist.Game.Capabilities.IsReady = function() return true end
local rangeQueries = {}
XelAssist.Game.Capabilities.InRange = function(_, spell, unit)
    rangeQueries[spell] = (rangeQueries[spell] or 0) + 1
    if unit == "target" and XelAssist.Graph.testRangeBlocked then return false end
    if XelAssist.Graph.testRangeUnknown then return nil end
    return true
end
XelAssist.Game.Range.SpellVerdict = function(_, spellId, spell, unit)
    return XelAssist.Game.Capabilities:InRange(spell, unit)
end
XelAssist.Game.Capabilities.TargetHasDebuff = function() return false end
XelAssist.Game.Capabilities.UnitHasBuff = function() return false end
XelAssist.Game.Capabilities.WeaponDamage = function() return nil end
XelAssist.Game.Capabilities.RangedDamage = function() return nil end
XelAssist.Game.Capabilities.BonusDamage = function() return 0 end

local function state(mode)
    local player = { key = "g:player-guid", unit = "player", guid = "player-guid",
        relation = "self", source = "self", health = 1000, healthMax = 1000,
        healthExact = true, distance = 0, distanceKind = "self", lineOfSight = true,
        targetedByCurrentEnemy = false, priority = 2, auras = {}, absorbs = {},
        targetRef = { unit = "player", guid = "player-guid", relation = "self",
            source = "self", priority = 2 } }
    local ally = { key = "g:ally-guid", unit = "party1", guid = "ally-guid",
        relation = "ally", source = "party", health = 500, healthMax = 1000,
        healthExact = true, distance = nil, distanceKind = nil, lineOfSight = nil,
        targetedByCurrentEnemy = false, priority = 1, auras = {}, absorbs = {},
        targetRef = { unit = "party1", guid = "ally-guid", relation = "ally",
            source = "party", priority = 1 } }
    local actors = { player = { resource = 1000, resourceMax = 1000 } }
    local friendlies = { order = { ally.key, player.key },
        byKey = { [ally.key] = ally, [player.key] = player },
        byUnit = { party1 = ally.key, player = player.key }, primaryKey = ally.key,
        total = 2, capped = false }
    return { mode = mode or "smart", hostile = true, healUnit = "party1",
        health = 1000, healthMax = 1000, healHealth = 500, healMax = 1000,
        targetHealth = 1000, targetMax = 1000, targetHealthExact = true,
        targetGUID = "target-guid",
        targetRef = { unit = "target", guid = "target-guid",
            relation = "hostile", source = "selected" },
        resource = 1000, resourceMax = 1000,
        combo = 5, moving = false, pet = true, targetCasting = false,
        playerCasting = false, castRemaining = 0, groupSize = 0, hasAggro = false,
        tank = false, role = "auto", instantNext = false, distance = nil,
        targetLineOfSight = true, playerBehindTarget = true,
        actors = actors, friendlies = friendlies,
        auras = {}, readyAt = {}, playerGcdReadyAt = 0,
        actorReadyAt = { player = 0, pet = 0 }, time = 0 }
end

local function friendly(unit, guid, health, maximum, distance, extra)
    local relation = unit == "player" and "self" or unit == "pet" and "pet" or "ally"
    local value = { key = "g:" .. guid, unit = unit, guid = guid,
        relation = relation, source = relation, health = health, healthMax = maximum,
        healthExact = true, distance = distance, distanceKind = "test",
        lineOfSight = true, targetedByCurrentEnemy = false, explicit = 0,
        auras = {}, absorbs = {} }
    local key, entry
    for key, entry in pairs(extra or {}) do value[key] = entry end
    value.targetRef = { unit = unit, guid = guid, relation = relation,
        source = value.source, priority = value.priority }
    return value
end

local function setFriendlies(s, list)
    s.friendlies = { order = {}, byKey = {}, byUnit = {}, total = table.getn(list),
        capped = false }
    s.actors.allies = {}
    local i
    for i = 1, table.getn(list) do
        local record = list[i]
        record.priority = record.priority or i
        record.targetRef.priority = record.priority
        table.insert(s.friendlies.order, record.key)
        s.friendlies.byKey[record.key] = record
        s.friendlies.byUnit[record.unit] = record.key
        if record.unit ~= "player" and record.unit ~= "pet" then
            table.insert(s.actors.allies, record)
        end
    end
    s.friendlies.primaryKey = s.friendlies.order[1]
    local primary = s.friendlies.byKey[s.friendlies.primaryKey]
    if primary then
        s.healUnit, s.healHealth, s.healMax = primary.unit, primary.health, primary.healthMax
    end
    local player = s.friendlies.byKey[s.friendlies.byUnit.player]
    if player then s.health, s.healthMax = player.health, player.healthMax end
    s.groupSize = math.max(0, table.getn(list) - (player and 1 or 0))
end

local function setHostiles(s, list, selectedKey)
    s.hostiles = { order = {}, byKey = {}, byUnit = {},
        selectedKey = selectedKey, total = table.getn(list), capped = false,
        discoveryComplete = true }
    local i
    for i = 1, table.getn(list) do
        local record = list[i]
        table.insert(s.hostiles.order, record.key)
        s.hostiles.byKey[record.key] = record
        s.hostiles.byUnit[record.unit] = record.key
    end
    XelAssist.Graph.State:SyncSelectedHostile(s)
end

local currentState
XelAssist.Graph.Snapshot = function() return currentState end

local function action(name, rank, kind, power, cost, extra)
    local facts = { kind = kind }
    if extra then for key, value in pairs(extra) do facts[key] = value end end
    return { name = name, rank = rank, rankText = "Rank " .. rank, slot = rank,
        facts = facts, mock = { average = power, cost = cost or 0,
            cast = facts.cast or 0, cooldown = facts.testCooldown,
            cooldownGroup = facts.testGroup, categoryCooldown = facts.testCategoryCooldown,
            minRange = facts.testMinRange, maxRange = facts.testMaxRange, school = facts.testSchool,
            duration = facts.testDuration, periodicInterval = facts.testPeriodicInterval,
            channelInterval = facts.testChannelInterval,
            channelIntervalSource = facts.testChannelInterval
                and "client DBC effectAmplitude" or nil,
            durationBase = facts.testDurationBase,
            durationMax = facts.testDurationMax,
            durationComboScaled = facts.testDurationComboScaled,
            directDamage = facts.testDirectDamage, periodicDamage = facts.testPeriodicDamage,
            comboBonus = facts.testComboBonus,
            weaponCoefficient = facts.testWeaponCoefficient,
            weaponFlat = facts.testWeaponFlat,
            weaponComboFlat = facts.testWeaponComboFlat,
            weaponNormalized = facts.testWeaponNormalized,
            targetArmorReduction = facts.testArmorReduction,
            targetArmorPerCombo = facts.testArmorPerCombo,
            targetResistanceReduction = facts.testResistanceReduction,
            targetDamageTaken = facts.testDamageTaken,
            initiatesCombat = facts.testInitiatesCombat,
            requiresStealth = facts.testRequiresStealth,
            appliesStealth = facts.testAppliesStealth,
            stances = facts.testStances,
            stancesNot = facts.testStancesNot,
            equippedItemClass = facts.testEquippedItemClass,
            equippedItemSubClassMask = facts.testEquippedItemSubClassMask,
            equippedItemInventoryTypeMask = facts.testEquippedItemInventoryTypeMask,
            topology = facts.testTopology } }
end

local function petAction(name, kind, power, cost, extra)
    local value = action(name, 1, kind, power, cost, extra)
    value.actor = "pet"; value.executor = "petAbility"; value.actionSlot = 4
    value.facts.petAbility = true
    if value.mock.maxRange == nil and value.facts.melee then
        value.mock.minRange, value.mock.maxRange = 0, 5
    elseif value.mock.maxRange == nil and value.facts.ranged then
        value.mock.minRange, value.mock.maxRange = 0, 30
    end
    return value
end

local function itemAction(name, kind, power, extra)
    local value = action(name, 1, kind, power, 0, extra)
    value.actor = "player"; value.executor = "item"; value.bag = 0; value.bagSlot = 1
    value.itemId = 13446; value.count = 1
    value.facts.consumable = true; value.facts.self = true
    value.mock.cooldown = 120
    return value
end

local function expect(name, wanted)
    local plan, err = XelAssist.Graph:Evaluate(currentState.mode, true)
    assert(plan, name .. ": " .. tostring(err))
    assert(plan.action.name == wanted, name .. ": got " .. plan.action.name .. ", wanted " .. wanted)
    return plan
end

-- The sliced-search benchmark reuses this production-graph fixture without
-- executing the scenario catalogue below. Keep the small interface here so
-- the benchmark cannot drift into a second copy of this already-large setup.
if XelAssistGraphScenarioSetupOnly then
    return {
        State = state,
        Action = action,
        PetAction = petAction,
        Use = function(_, source, actions, items)
            currentState = source
            scenarioActions = actions or {}
            scenarioItems = items or {}
            pendingAura, dispelTarget = nil, nil
            reagentAvailable = true
            rangeQueries = {}
            XelAssist.Graph.testDelivery = nil
            XelAssist.Graph.testRangeBlocked = nil
            XelAssist.Graph.testRangeUnknown = nil
        end,
    }
end

do
local function scored(value, source)
    local targets = XelAssist.Graph.Targets:Targets(value, source)
    local candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
        value, source, targets[1])
    assert(candidate, value.name .. ": " .. tostring(blocker))
    return candidate
end

-- A normal instant advances only through its application boundary so an
-- independent action can be woven before the shared GCD is ready again.
currentState = state("smart")
local clockNormal = action("Clock Normal", 1, "damage", 300, 0, { gcd = 1.5 })
local clockIndependent = action(
    "Clock Independent", 1, "damage", 100, 0, { gcd = 0 })
local firstNormal = scored(clockNormal, currentState)
assert(firstNormal.normalGcd and firstNormal.gcd == 1.5
    and math.abs(firstNormal.downtime - 0.05) < 0.0001
    and math.abs(firstNormal.valueDowntime - 1.5) < 0.0001,
    "normal action valuation and causal advancement must use separate clocks")
local afterNormal = XelAssist.Graph.Transitions:Advance(
    currentState, firstNormal)
local woven = scored(clockIndependent, afterNormal)
local delayedNormal = scored(clockNormal, afterNormal)
assert(math.abs(afterNormal.time - 0.05) < 0.0001
    and math.abs(afterNormal.playerGcdReadyAt - 1.5) < 0.0001
    and not woven.normalGcd and math.abs(woven.actionStart - 0.05) < 0.0001
    and math.abs(delayedNormal.actionStart - 1.5) < 0.0001,
    "an independent player action must remain usable inside a normal GCD")
local afterWoven = XelAssist.Graph.Transitions:Advance(afterNormal, woven)
assert(math.abs(afterWoven.time - 0.1) < 0.0001
    and math.abs(afterWoven.playerGcdReadyAt - 1.5) < 0.0001,
    "an independent action must not consume or reset the shared GCD")
end

do
    currentState = state("smart")
    currentState.playerGcdReadyAt = 1.5
    XelAssistCharDB.graphDepth = 2
    scenarioActions = {}
    local i
    for i = 1, 5 do
        table.insert(scenarioActions,
            action("Delayed Normal " .. i, 1, "damage", 500, 0))
    end
    table.insert(scenarioActions, action("Immediate Weave", 1,
        "damage", 150, 0, { gcd = 0, testCooldown = 30 }))
    local weavePlan = expect("beam retains immediate independent action",
        "Immediate Weave")
    assert(weavePlan.follow[1]
        and string.find(weavePlan.follow[1].name,
            "Delayed Normal ", 1, true) == 1
        and math.abs(weavePlan.path[2].actionStart - 1.5) < 0.0001,
        "WIDTH pruning must retain an executable oGCD before delayed normal actions")
end

do
    local priorRootObservation = XelAssist.Graph.RootObservation
    dofile("Graph/RootObservation.lua")
    XelAssist.Graph.RootObservation.Facts = function(_, _, value)
        return value.mock, "known"
    end
    currentState = state("smart")
    currentState.resourceType, currentState.resource = 1, 20
    currentState.resourceMax, currentState.playerResourceExact = 100, true
    currentState.actors.player.resourceType = 1
    currentState.actors.player.resource = 20
    currentState.actors.player.resourceMax = 100
    currentState.actors.player.resourceExact = true
    currentState.role, currentState.tank = "auto", false
    currentState.playerForm = { available = true, formID = 17,
        warriorRageRetention = { available = true, exact = true,
            talentID = 57, rank = 3, retainedRageCap = 15 } }
    currentState.playerThreat = { actor = "player", formID = 17,
        exact = true, multiplier = 0.8 }
    local defensive = action("Unlocalized Defensive Stance", 1, "form", 0, 0,
        { self = true, warriorStance = true, resourceType = "rage", gcd = 0 })
    defensive.actor, defensive.executor, defensive.spellId =
        "player", "playerSpell", 71
    defensive.mock.warriorStanceEvidence = { recognized = true, valid = true,
        targetForm = 18, targetMask = 131072, cost = 0, powerType = 1 }
    local gated = action("Defensive-only outcome", 1, "damage", 500, 0,
        { testStances = 131072 })
    scenarioActions, XelAssistCharDB.graphDepth = { defensive, gated }, 2
    local stancePlan = expect("zero-value stance unlock is searchable",
        "Unlocalized Defensive Stance")
    assert(stancePlan.follow[1]
        and stancePlan.follow[1].name == "Defensive-only outcome"
        and stancePlan.path[1].value == 0,
        "a neutral stance edge must survive only when a later outcome pays for it")
    local projected = XelAssist.Graph.Transitions:Advance(
        currentState, stancePlan.path[1])
    assert(projected.playerForm.formID == 18 and projected.resource == 15
        and projected.tank == true,
        "the search-selected stance edge must project form, retention, and auto role")
    scenarioActions = { defensive }
    local useless = XelAssist.Graph:Evaluate("smart", true)
    assert(useless == nil,
        "a neutral stance with no valuable follow-up must not be published")
    XelAssist.Graph.RootObservation = priorRootObservation
end

scenarioActions = {
    action("Curse of Elements", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testResistanceReduction = { [2] = 45 },
            testDamageTaken = { [2] = 0.06 }, modifierGroup = "curseElements" }),
    action("Sunder Armor", 1, "debuff", 0, 0,
        { armorDebuff = true, stackable = 5, modifierGroup = "majorArmor",
            testArmorReduction = 300 }),
}
local modifierEncounter = { targetHarmful = { list = {
    { name = "Curse of Elements", mine = false, sourceUnit = "party1", remaining = 200 },
    { name = "Sunder Armor", playerOrPet = true, stacks = 3, remaining = 20 },
} } }
local activeReduction, activeTaken, activeSource, activeEffects, activeAuras =
    XelAssist.Graph:ActiveTargetModifiers(
    modifierEncounter, { live = nil })
assert(activeReduction[2] == 45 and activeReduction[0] == 900
    and activeTaken[2] == 0.06 and string.find(activeSource, "Curse of Elements", 1, true)
    and activeEffects["Curse of Elements"].resistanceReduction[2] == 45
    and activeAuras["Sunder Armor"].remaining == 20,
    "active group resistance modifiers must seed the root graph state")
local effectiveReduction, effectiveTaken = XelAssist.Graph:ActiveTargetModifiers(
    modifierEncounter, { live = { [0] = 1000, [2] = 50 } })
assert(effectiveReduction[2] == 45 and effectiveReduction[0] == 900
    and effectiveTaken[2] == 0.06,
    "live modifiers must retain an expiry baseline without being subtracted twice")

scenarioActions = {
    action("Minor Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.06 },
            modifierGroup = "sharedFireExposure" }),
    action("Major Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.10 },
            modifierGroup = "sharedFireExposure" }),
    action("Independent Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.15 },
            modifierGroup = "independentFireExposure" }),
}
local stackingEncounter = { targetHarmful = { list = {
    { name = "Minor Fire Exposure", remaining = 30 },
    { name = "Major Fire Exposure", remaining = 30 },
    { name = "Independent Fire Exposure", remaining = 30 },
} } }
local _, stackedTaken = XelAssist.Graph:ActiveTargetModifiers(stackingEncounter, nil)
assert(math.abs(stackedTaken[2] - 0.265) < 0.0001,
    "damage-taken modifiers must keep the strongest shared-group effect and multiply independent groups")

currentState = state("support"); currentState.healHealth = 880
currentState.friendlies.byKey["g:ally-guid"].health = 880
scenarioActions = { action("Heal", 1, "heal", 100, 20), action("Heal", 5, "heal", 500, 200) }
local plan = expect("downranked heal", "Heal")
assert(plan.action.rank == 1, "the efficient non-overhealing rank should win")
assert(rangeQueries["Heal(Rank 1)"] and rangeQueries["Heal(Rank 5)"],
    "legality must ask Nampower about each exact spell rank rather than the base name")

currentState = state("support")
setFriendlies(currentState, {
    friendly("party1", "ally-a", 750, 1000, 20),
    friendly("party2", "ally-b", 100, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = {
    action("Heal", 1, "heal", 220, 30, { cast = 1.5 }),
    action("Heal", 5, "heal", 900, 400, { cast = 3 }),
    action("Flash Heal", 3, "heal", 500, 220, { cast = 1.5 }),
}
plan = expect("action rank and recipient are co-optimized", "Flash Heal")
assert(plan.action.rank == 3 and plan.target == "party2"
    and plan.targetKey == "g:ally-b" and plan.targetGUID == "ally-b"
    and plan.targetRelation == "ally" and plan.targetRef.guid == "ally-b",
    "the chosen action, rank and immutable recipient must travel together")
currentState.friendlies.byKey["g:ally-b"].health = 1000
plan = expect("mild injury downranks independently", "Heal")
assert(plan.action.rank == 1 and plan.target == "party1" and plan.targetGUID == "ally-a",
    "a different ally must independently choose the efficient lower rank")

currentState = state("support"); XelAssistCharDB.graphDepth = 2
setFriendlies(currentState, {
    friendly("party1", "ally-a", 100, 1000, 20),
    friendly("party2", "ally-b", 400, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { action("Greater Heal", 1, "heal", 900, 200, { cast = 1.5 }) }
plan = expect("future direct heal switches recipients", "Greater Heal")
assert(plan.path[1].targetGUID == "ally-a" and plan.path[2]
    and plan.path[2].targetGUID == "ally-b",
    "future health must be target-local so the beam can switch allies: steps="
        .. tostring(table.getn(plan.path)) .. " prevented="
        .. tostring(plan.path[1] and plan.path[1].state
            and plan.path[1].state.chosenActionPrevented))

currentState = state("support")
setFriendlies(currentState, {
    friendly("party1", "ally-a", 450, 1000, 20),
    friendly("party2", "ally-b", 600, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { action("Renew", 1, "hot", 600, 120, { testDuration = 12 }) }
plan = expect("future hot switches recipients", "Renew")
assert(plan.path[1].targetGUID == "ally-a" and plan.path[2]
    and plan.path[2].targetGUID == "ally-b",
    "one ally's projected HoT must neither overwrite nor block another ally's HoT")

currentState = state("support")
setFriendlies(currentState, {
    friendly("party1", "ally-a", 700, 1000, 20,
        { targetedByCurrentEnemy = true }),
    friendly("party2", "ally-b", 700, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { action("Power Word: Shield", 1, "absorb", 500, 100,
    { testDuration = 30 }) }
plan = expect("future absorbs remain recipient local", "Power Word: Shield")
assert(plan.path[1].targetGUID == "ally-a" and plan.path[2]
    and plan.path[2].targetGUID == "ally-b",
    "the current victim's shield must not globally block shielding another ally: "
        .. tostring(table.getn(plan.path or {})) .. " / "
        .. tostring(plan.path[2] and plan.path[2].targetGUID))

currentState = state("support"); XelAssistCharDB.graphDepth = 1
setFriendlies(currentState, {
    friendly("party1", "ally-a", 700, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { action("Flash Heal", 1, "heal", 500, 100) }
plan = expect("effective healing drives threat", "Flash Heal")
assert(plan.path[1].rawPower == 500 and math.abs(plan.path[1].threat - 150) < 0.0001,
    "healing threat must use the 300 effective healing, not 500 raw power")

currentState = state("smart"); currentState.groupSize = 4; currentState.hasAggro = true
scenarioActions = { action("Threat Slam", 1, "damage", 500, 0, { threat = 2 }),
    action("Careful Strike", 1, "damage", 300, 0, { threat = 0.5 }) }
expect("aggro-aware damage", "Careful Strike")

currentState = state("smart"); currentState.groupSize = 4
scenarioActions = { action("Threat Slam", 1, "damage", 500, 0, { threat = 2 }),
    action("Careful Strike", 1, "damage", 300, 0, { threat = 0.5 }) }
expect("exact no-aggro damage", "Threat Slam")
currentState.autoShot = { unknownInFlight = {
    { targetGuid = currentState.targetGUID, timingUnknown = true } } }
XelAssist.Graph.AutoShotUncertainty:Apply(currentState, currentState.autoShot)
assert(not currentState.hasAggro
    and currentState.targetPlayerThreatDeltaExact == false,
    "an unresolved arrow must preserve the victim observation but invalidate threat certainty")
expect("unknown projectile threat reserve", "Careful Strike")

currentState = state("smart"); currentState.groupSize = 4; currentState.hasAggro = true
scenarioActions = { action("Bolt", 1, "damage", 300, 30), action("Bolt", 5, "damage", 500, 100) }
plan = expect("threat downrank", "Bolt")
assert(plan.action.rank == 1, "unwanted aggro should make the lower-threat rank win")

currentState = state("smart"); currentState.targetCasting = true
scenarioActions = { action("Stop Cast", 1, "interrupt", 0, 0), action("Bolt", 1, "damage", 600, 0) }
expect("interrupt", "Stop Cast")

currentState = state("smart"); currentState.targetCasting = true; currentState.targetCastRemaining = 0.5
currentState.actorReadyAt = { player = 1.5, pet = 0 }
scenarioActions = { action("Late Kick", 1, "interrupt", 0, 0), action("Bolt", 1, "damage", 200, 0) }
expect("interrupt deadline", "Bolt")

currentState = state("smart"); currentState.role = "healer"
scenarioActions = { action("Helpful Heal", 1, "heal", 200, 100),
    action("Damage Bolt", 1, "damage", 300, 100) }
expect("healer role", "Helpful Heal")
currentState.role = "damage"
expect("damage role", "Damage Bolt")

currentState = state("smart"); currentState.moving = true
scenarioActions = { action("Long Cast", 1, "damage", 900, 0, { cast = 3 }),
    action("Instant", 1, "damage", 250, 0, { cast = 0 }) }
expect("movement downtime", "Instant")

currentState = state("smart"); currentState.moving = true
XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Future Cast", 1, "damage", 900, 0, { cast = 3 }),
    action("Current Instant", 1, "damage", 250, 0,
        { cast = 0, testCooldown = 10 }) }
plan = expect("future movement remains causal", "Current Instant")
assert(not plan.path[2],
    "modeled time must not invent that the player stopped moving")

currentState = state("smart")
scenarioActions = { action("Mind Flay", 1, "damage", 900, 100,
    { channel = true, testDuration = 5 }) }
plan = expect("channel occupancy", "Mind Flay")
assert(plan.downtime >= 5, "a channel must occupy its discovered duration")

currentState = state("support"); currentState.moving = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Nature's Swiftness", 1, "modifier", 0, 0,
        { cooldown = true, nextInstant = true, testCooldown = 120 }),
    action("Healing Wave", 1, "heal", 500, 200, { cast = 3 }) }
plan = expect("modifier edge", "Nature's Swiftness")
assert(plan.follow[1] and plan.follow[1].name == "Healing Wave", "instant modifier should unlock the moving cast")

currentState = state("smart"); currentState.targetHealth = 50; currentState.targetMax = 100
currentState.targetHealthExact = false
scenarioActions = { action("Unknown Health Bolt", 1, "damage", 500, 0) }
plan = expect("percentage health safety", "Unknown Health Bolt")
assert(plan.reason ~= "finishes the target", "percentage-scaled hostile health must not drive finisher math")
assert(plan.confidence == "partial data" and table.getn(plan.unknowns) > 0,
    "exact potency with unknown range/health must expose partial confidence")

currentState = state("smart"); XelAssist.Graph.testRangeBlocked = true
XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Out There", 1, "damage", 900, 0) }
local missing = XelAssist.Graph:Evaluate("smart", true)
XelAssistTestAfterMovement = missing and XelAssist.Graph.Transitions:Advance(
    currentState, missing.path[1])
assert(missing and missing.action.name == "Move into range"
    and missing.action.executor == "instruction"
    and missing.follow[1] and missing.follow[1].name == "Out There"
    and missing.path[2].spatialConditionalOnly,
    "out-of-range actions must remain visible beyond a non-executable movement instruction")
assert(XelAssistTestAfterMovement
    and XelAssistTestAfterMovement.movementSetupTargetGUID
        == currentState.targetGUID
    and XelAssistTestAfterMovement.time > currentState.time,
    "the movement instruction must open a target-pinned future branch without changing live distance")
XelAssistTestAfterMovement = nil
XelAssist.Graph.testRangeBlocked = false

currentState = state("smart"); currentState.distance = 4; XelAssist.Graph.testRangeUnknown = true
scenarioActions = { action("Dead Zone Shot", 1, "damage", 900, 0,
    { testMinRange = 8, testMaxRange = 35 }) }
local tooClose, tooCloseReason = XelAssist.Graph:Evaluate("smart", true)
assert(tooClose == nil and tooCloseReason == "Move farther away",
    "minimum range must block too-close actions: " .. tostring(tooCloseReason))
currentState.distance = 40
local tooFar, tooFarReason = XelAssist.Graph:Evaluate("smart", true)
assert(tooFar and tooFar.action.name == "Move into range"
    and tooFar.follow[1] and tooFar.follow[1].name == "Dead Zone Shot",
    "maximum range must block too-far actions: " .. tostring(tooFarReason))
XelAssist.Graph.testRangeUnknown = false

currentState = state("smart"); currentState.distance = 40
scenarioActions = { action("Contradicted Bolt", 1, "damage", 900, 0,
    { testMinRange = 0, testMaxRange = 30 }) }
XelAssistTestContradicted = XelAssist.Graph:Evaluate("smart", true)
assert(XelAssistTestContradicted
    and XelAssistTestContradicted.action.name == "Move into range"
    and XelAssistTestContradicted.follow[1]
    and XelAssistTestContradicted.follow[1].name == "Contradicted Bolt",
    "a permissive native verdict must not override an exact DBC-distance rejection")
XelAssistTestContradicted = nil

currentState = state("smart"); XelAssistCharDB.toggles.cooldowns = false
scenarioActions = { action("Unknown Long Cooldown", 1, "damage", 2000, 0, { testCooldown = 60 }),
    action("Normal Filler", 1, "damage", 200, 0) }
expect("live major cooldown policy", "Normal Filler")
XelAssistCharDB.toggles.cooldowns = true

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Burn", 1, "dot", 500, 40), action("Bolt", 1, "damage", 200, 20) }
plan = expect("future aura state", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Bolt", "future action should respect the applied aura")

-- Installed OctoWoW rank-one values at player level seven.  These are generic
-- graph inputs, not a Warlock rotation: a fresh 80-health target lives long
-- enough for efficient overlapping damage, while a direct lethal remains best.
currentState = state("smart")
currentState.resource, currentState.resourceMax = 293, 293
currentState.actors.player.resource = 293
currentState.actors.player.resourceMax = 293
currentState.targetHealth, currentState.targetMax = 80, 80
currentState.pet = false
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Corruption", 1, "dot", 40, 35,
        { cast = 1.5, testDuration = 12, testPeriodicInterval = 3 }),
    action("Immolate", 1, "dot", 30.4, 25,
        { cast = 2, testDuration = 15, testPeriodicInterval = 3,
            testDirectDamage = 10.4, testPeriodicDamage = 20 }),
    action("Shadow Bolt", 1, "damage", 15.6, 25, { cast = 1.7 }),
}
expect("level seven warlock fresh target", "Corruption")
currentState.pet = true
expect("level seven warlock with solo companion", "Corruption")
currentState.targetHealth = 15
expect("level seven warlock direct lethal", "Shadow Bolt")
currentState = state("smart")
scenarioActions = { action("Zero-output periodic", 1, "dot", 0, 0,
        { testDuration = 12 }),
    action("Proven damage", 1, "damage", 1, 0) }
expect("zero-output periodic has no progress value", "Proven damage")

currentState = state("smart")
currentState.targetAuras = { Immolate = { mine = true, duration = 15, remaining = 10 } }
scenarioActions = { action("Immolate", 1, "dot", 700, 100, { testDuration = 15 }),
    action("Shadow Bolt", 1, "damage", 200, 100) }
expect("owned dot not clipped", "Shadow Bolt")
currentState.targetAuras.Immolate.remaining = 1
expect("owned dot refresh window", "Immolate")

currentState = state("smart"); currentState.targetHealth = 100; currentState.targetMax = 100
currentState.targetHealthExact = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Lethal Bolt", 1, "damage", 500, 0) }
plan = expect("terminal defeated target", "Lethal Bolt")
assert(not plan.follow[1], "a defeated projected target must not receive another damage action")

currentState = state("smart"); pendingAura = "Immolate"
scenarioActions = { action("Immolate", 1, "dot", 500, 100),
    action("Shoot", 1, "damage", 100, 0, { recovery = true }) }
expect("pending dot application", "Shoot")
pendingAura = nil

currentState = state("smart"); currentState.targetHealth = 100; currentState.targetMax = 1000
scenarioActions = { action("Immolate", 1, "dot", 500, 100),
    action("Shoot", 1, "damage", 80, 0, { recovery = true }) }
plan = expect("dot target lifetime", "Shoot")
assert(plan.reason == "preserves resources", "a dying target should favor the zero-mana finisher over wasted ticks")

currentState = state("smart")
currentState.targetSurvival = { available = true, incomingDps = 250,
    timeToDie = 4, lowerTimeToDie = 3, upperTimeToDie = 5.4,
    observedFor = 3.5, samples = 9, confidence = "observed",
    source = "exact hostile health trend" }
scenarioActions = { action("Immolate", 1, "dot", 500, 100,
        { testDuration = 15 }),
    action("Shoot", 1, "damage", 100, 0, { recovery = true }) }
plan = expect("learned target survival rejects wasted dot", "Shoot")
assert(plan.action.name == "Shoot"
    and plan.path[1].survival and plan.path[1].survival.decisionFactor == 1,
    "learned group damage pressure must favor immediate free damage over a dot that cannot pay back")

currentState = state("smart")
currentState.targetHealth, currentState.targetMax = 100, 1000
currentState.targetSurvival = { available = true, incomingDps = 200,
    timeToDie = 0.5, lowerTimeToDie = 0.25, upperTimeToDie = 0.75,
    observedFor = 3, samples = 7, confidence = "observed",
    source = "exact hostile health trend" }
XelAssistTestEndFightWeakness = action("Curse of Weakness", 1, "debuff", 0, 35,
    { ranged = true, attackSpeedReduction = true, testDuration = 120 })
XelAssistTestEndFightTargets = XelAssist.Graph.Targets:Targets(
    XelAssistTestEndFightWeakness, currentState)
XelAssistTestEndFightCandidate, XelAssistTestEndFightBlocker =
    XelAssist.Graph.Scoring:Evaluate(
        XelAssistTestEndFightWeakness, currentState,
        XelAssistTestEndFightTargets[1])
assert(XelAssistTestEndFightCandidate and not XelAssistTestEndFightBlocker
    and XelAssistTestEndFightCandidate.survival.utilityFactor == 0
    and XelAssistTestEndFightCandidate.value < 0
    and XelAssistTestEndFightCandidate.reason
        == "target may die before the utility pays back",
    "a dying target must not retain fixed positive value for a hostile utility debuff")
scenarioActions = { XelAssistTestEndFightWeakness,
    action("Shoot", 1, "damage", 20, 0, { recovery = true }) }
expect("dying target rejects utility debuff", "Shoot")

currentState = state("smart")
currentState.targetSurvival = { available = true, incomingDps = 50,
    timeToDie = 20, lowerTimeToDie = 15, upperTimeToDie = 25,
    observedFor = 3, samples = 7, confidence = "observed",
    source = "exact hostile health trend" }
XelAssistTestEndFightTargets = XelAssist.Graph.Targets:Targets(
    XelAssistTestEndFightWeakness, currentState)
XelAssistTestEndFightCandidate = XelAssist.Graph.Scoring:Evaluate(
    XelAssistTestEndFightWeakness, currentState,
    XelAssistTestEndFightTargets[1])
assert(XelAssistTestEndFightCandidate.value > 0
    and XelAssistTestEndFightCandidate.survival.utilityFactor == 1,
    "evidence-based end-of-fight gating must not disable utility on a durable target")
XelAssistTestEndFightWeakness, XelAssistTestEndFightTargets = nil, nil
XelAssistTestEndFightCandidate, XelAssistTestEndFightBlocker = nil, nil

currentState = state("smart"); currentState.playerLevel = 60
currentState.targetResistances = { 0, 0, 240, 0, 0, 0, 0 }
XelAssist.Combat.Resistance = {
    Estimate = function(_, _, target, tooltip, s)
        local school = tooltip.school
        local raw = target == "target" and school and s.targetResistances[school + 1]
        if raw then
            local ratio = math.min(1, raw / (math.max(20, s.playerLevel) * 5))
            local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
            return { school = school, schoolName = school == 2 and "Fire" or "Shadow",
                multiplier = 1 - mitigation, source = "test target data", unknown = false }
        end
        return { school = school, schoolName = school == 2 and "Fire" or "Shadow",
            multiplier = 1, source = "test target data", unknown = false }
    end,
    Contrast = function(_, _, chosen)
        if chosen.school == 5 then return "uses Shadow against elevated Fire resistance" end
    end,
}
scenarioActions = { action("Fireball", 1, "damage", 600, 100, { testSchool = 2 }),
    action("Shadow Bolt", 1, "damage", 430, 100, { testSchool = 5 }) }
plan = expect("pre-cast school resistance", "Shadow Bolt")
assert(plan.resistance and plan.resistance.school == 5
    and plan.reason == "uses Shadow against elevated Fire resistance",
    "the plan must expose why the better school won")
scenarioActions = { action("Fireball", 1, "damage", 600, 100,
    { testSchool = 2 }) }
plan = expect("selected damage uses expected resistance", "Fireball")
local resistedAfter = XelAssist.Graph.Transitions:Advance(currentState, plan)
assert(plan.path[1].rawPower == 600
    and math.abs(plan.path[1].power - 255) < 0.0001
    and math.abs(resistedAfter.targetHealth - 745) < 0.0001,
    "selected-hostile projection must subtract resistance-adjusted expected damage")
XelAssist.Combat.Resistance = nil

currentState = state("smart")
XelAssist.Combat.Resistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Mystery Bolt" then
            return { school = nil, schoolName = "Unknown", multiplier = 1,
                source = "damage school unknown", unknown = true }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Mystery Bolt", 1, "damage", 100, 20),
    action("Known Bolt", 1, "damage", 95, 20, { testSchool = 5 }) }
expect("unknown resistance reserve", "Known Bolt")
XelAssist.Combat.Resistance = nil

currentState = state("smart")
XelAssist.Combat.Resistance = {
    Estimate = function()
        return { school = 5, schoolName = "Shadow", multiplier = 0.8,
            source = "1 context outcome", confidence = "limited samples",
            samples = 1, unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Thin Evidence Bolt", 1, "damage", 100, 0,
    { testSchool = 5 }) }
plan = expect("limited resistance plan confidence", "Thin Evidence Bolt")
assert(plan.confidence == "partial data"
    and string.find(table.concat(plan.unknowns, ","),
        "limited resistance evidence", 1, true),
    "limited learned resistance must not be labeled as complete client data")
XelAssist.Combat.Resistance = nil

currentState = state("smart"); currentState.targetCasting = true
XelAssist.Combat.Resistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Unreliable Lock" then
            return { school = 5, schoolName = "Shadow", multiplier = 0.1,
                landChance = 0.1, source = "learned delivery", unknown = false }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            landChance = 1, source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Unreliable Lock", 1, "interrupt", 0, 0, { testSchool = 5 }),
    action("Known Bolt", 1, "damage", 400, 20, { testSchool = 5 }) }
expect("resistance-aware effect delivery", "Known Bolt")
scenarioActions = { action("Earth Shock", 1, "damage", 100, 0,
        { testSchool = 5, interrupt = true }),
    action("Known Bolt", 1, "damage", 400, 20, { testSchool = 5 }) }
XelAssist.Combat.Resistance.Estimate = function(_, candidate)
    if candidate.name == "Earth Shock" then
        return { school = 5, schoolName = "Shadow", multiplier = 0.1,
            landChance = 0.1, source = "learned delivery", unknown = false }
    end
    return { school = 5, schoolName = "Shadow", multiplier = 1,
        landChance = 1, source = "known target data", unknown = false }
end
expect("damage interrupt delivery", "Known Bolt")
XelAssist.Combat.Resistance = nil

currentState = state("smart"); currentState.targetHealth = 10000; currentState.targetMax = 10000
currentState.targetDamageTaken = { [3] = 1 }
XelAssist.Combat.Resistance = {
    Estimate = function()
        return { school = nil, schoolName = "Mixed", multiplier = 0.75,
            source = "component test", unknown = false, mode = "mixed", components = {
                { school = 0, multiplier = 0.5, componentWeight = 0.5, unknown = false },
                { school = 3, multiplier = 1, componentWeight = 0.5, unknown = false },
            } }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Mixed Strike", 1, "damage", 100, 0) }
plan = expect("component resistance vulnerability product", "Mixed Strike")
assert(math.abs(plan.path[1].power - 125) < 0.0001,
    "mixed damage must sum each component's resistance times vulnerability")
XelAssist.Combat.Resistance.Estimate = function()
    return { school = nil, schoolName = "Mixed", multiplier = 0.55,
        source = "partial component test", unknown = true, mode = "mixed", components = {
            { school = 0, multiplier = 0.5, componentWeight = 0.9, unknown = false },
            { school = 3, multiplier = 1, componentWeight = 0.1, unknown = true },
        } }
end
currentState.targetDamageTaken = nil
plan = expect("component-local uncertainty reserve", "Mixed Strike")
assert(math.abs(plan.path[1].power - 54) < 0.0001,
    "unknown reserve must apply only to the unresolved mixed component")
XelAssist.Combat.Resistance = nil

currentState = state("smart"); currentState.targetHealth = 300; currentState.targetMax = 300
XelAssistCharDB.graphDepth = 3
scenarioActions = { action("Burn", 1, "dot", 300, 20, { testDuration = 6 }),
    action("Filler", 1, "damage", 30, 0),
    action("Execute", 1, "damage", 20, 0, { execute = 50 }) }
plan = expect("future periodic transitions", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "active periodic damage must change later health-gated graph actions: "
        .. tostring(plan.follow[1] and plan.follow[1].name) .. " -> "
        .. tostring(plan.follow[2] and plan.follow[2].name))

currentState = state("smart"); currentState.targetHealth = 1000
currentState.targetMax = 1000; XelAssistCharDB.graphDepth = 1
scenarioActions = { action("Cadenced Burn", 1, "dot", 120, 20,
    { testDuration = 6, testPeriodicInterval = 2 }) }
plan = expect("DBC periodic cadence propagation", "Cadenced Burn")
local cadenced = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(cadenced.targetHealth == 1000
    and cadenced.auras["Cadenced Burn"].periodicInterval == 2
    and math.abs(cadenced.auras["Cadenced Burn"].periodicNextIn - 1.95) < 0.0001,
    "a projected DoT must retain cadence across its application boundary")
local cadenceWaitAction = action("Cadence Wait", 1, "buff", 0, 0)
local cadenceWait = { action = cadenceWaitAction, target = "target",
    targetGUID = currentState.targetGUID, targetRelation = "hostile",
    cost = 0, cast = 0, occupancy = 2, wait = 0, downtime = 2,
    actionStart = cadenced.time, tooltip = cadenceWaitAction.mock,
    power = 0, effectDelivery = 1 }
local afterCadenceTick = XelAssist.Graph.Transitions:Advance(
    cadenced, cadenceWait)
assert(afterCadenceTick.targetHealth == 960
    and math.abs(afterCadenceTick.auras["Cadenced Burn"].periodicNextIn - 1.95)
        < 0.0001,
    "the first exact DoT tick must land once and preserve its future phase")

currentState = state("smart"); currentState.targetHealth = 60; currentState.targetMax = 100
XelAssistCharDB.graphDepth = 2
XelAssist.Combat.Resistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Immolate" then
            return { school = 2, schoolName = "Fire", multiplier = 0.8275,
                source = "hybrid test", unknown = false, mode = "hybrid", components = {
                    { school = 2, multiplier = 0.625, componentWeight = 40,
                        componentPhase = "direct", unknown = false },
                    { school = 2, multiplier = 0.9625, componentWeight = 60,
                        componentPhase = "periodic", unknown = false },
                } }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Immolate", 1, "dot", 100, 10,
        { testSchool = 2, testDuration = 15, testDirectDamage = 40,
            testPeriodicDamage = 60 }),
    action("Execute", 1, "damage", 20, 0, { testSchool = 5, execute = 50 }) }
plan = expect("hybrid immediate direct transition", "Immolate")
assert(plan.follow[1] and plan.follow[1].name == "Execute",
    "hybrid direct damage and first periodic window must advance separately")
XelAssist.Combat.Resistance = nil; XelAssistCharDB.graphDepth = 1

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
currentState.targetResistance = { projectedReduction = {} }
XelAssist.Combat.Resistance = {
    Estimate = function(_, _, actionTarget, tooltip, s)
        local reduction = s.targetResistance and s.targetResistance.projectedReduction
            and s.targetResistance.projectedReduction[2] or 0
        return { school = tooltip.school, schoolName = "Fire",
            multiplier = reduction >= 80 and 1 or 0.1,
            landChance = actionTarget == "target" and 0.8 or 1,
            source = reduction >= 80 and "projected resistance debuff" or "test resistance",
            unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = {
    action("Curse of Elements", 1, "debuff", 0, 50,
        { ranged = true, testDuration = 300, testResistanceReduction = { [2] = 100 },
            testDamageTaken = { [2] = 0.06 } }),
    action("Fireball", 1, "damage", 600, 100, { testSchool = 2 }),
}
XelAssistCharDB.graphDepth = 1
expect("resistance debuff needs future value", "Fireball")
XelAssistCharDB.graphDepth = 2
plan = expect("projected resistance debuff cycle", "Curse of Elements")
assert(plan.follow[1] and plan.follow[1].name == "Fireball",
    "the future path must exploit its projected resistance reduction")
assert(math.abs(plan.path[2].resistance.damageTakenMultiplier - 1.048) < 0.0001,
    "the future path must probability-weight projected school vulnerability")
scenarioActions[1].mock.targetResistanceReduction = nil
scenarioActions[1].mock.targetDamageTaken = nil
expect("resistance debuff causal control", "Fireball")
scenarioActions[1].mock.targetResistanceReduction = { [2] = 100 }
scenarioActions[1].mock.targetDamageTaken = { [2] = 0.06 }
scenarioActions[1].mock.duration = 1
currentState.targetHealth, currentState.targetMax = 10000, 10000
XelAssistCharDB.graphDepth = 3
expect("modifier shorter than its GCD", "Fireball")
scenarioActions[1].mock.duration = 2
plan = expect("projected modifier expiry", "Curse of Elements")
assert(plan.path[2].resistance.multiplier == 1
    and plan.path[3].resistance.multiplier == 0.1
    and plan.path[3].resistance.damageTakenMultiplier == 1,
    "expired simulated debuffs must stop changing resistance and vulnerability")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetResistance = { live = { [2] = 55 }, projectedReduction = {} }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.06 }, {}
currentState.targetModifierEffects = { ["Curse of Elements"] = {
    resistanceReduction = { [2] = 45 }, damageTaken = { [2] = 0.06 },
    activeRoot = true, liveIncluded = true } }
currentState.auras = { ["Curse of Elements"] = { remaining = 1,
    target = "target", targetModifier = true } }
currentState.targetAuras = { ["Curse of Elements"] = { remaining = 1, mine = true } }
XelAssistCharDB.graphDepth = 2
XelAssist.Combat.Resistance.Estimate = function(_, _, _, tooltip, s)
    local delta = s.targetResistance and s.targetResistance.projectedReduction
        and s.targetResistance.projectedReduction[2] or 0
    return { school = tooltip.school, schoolName = "Fire",
        multiplier = delta < 0 and 0.5 or 1, source = "active expiry test", unknown = false }
end
scenarioActions = { action("Fireball", 1, "damage", 100, 0, { testSchool = 2 }) }
plan = expect("active live modifier expiry", "Fireball")
assert(plan.path[1].resistance.damageTakenMultiplier == 1.06
    and plan.path[2].resistance.multiplier == 0.5
    and plan.path[2].resistance.damageTakenMultiplier == 1,
    "an expiring active live modifier must restore resistance and remove vulnerability")
XelAssist.Combat.Resistance = nil; XelAssistCharDB.graphDepth = 1

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.265 }, {}
currentState.targetModifierEffects = {
    ["Minor Fire Exposure"] = { name = "Minor Fire Exposure",
        group = "sharedFireExposure", damageTaken = { [2] = 0.06 } },
    ["Major Fire Exposure"] = { name = "Major Fire Exposure",
        group = "sharedFireExposure", damageTaken = { [2] = 0.10 } },
    ["Independent Fire Exposure"] = { name = "Independent Fire Exposure",
        group = "independentFireExposure", damageTaken = { [2] = 0.15 } },
}
currentState.auras = {
    ["Minor Fire Exposure"] = { remaining = 5, targetModifier = true },
    ["Major Fire Exposure"] = { remaining = 1, targetModifier = true },
    ["Independent Fire Exposure"] = { remaining = 5, targetModifier = true },
}
XelAssist.Combat.Resistance = {
    Estimate = function()
        return { school = 2, schoolName = "Fire", multiplier = 1,
            source = "impact stacking test", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Slow Fireball", 1, "damage", 100, 0,
    { testSchool = 2, cast = 2 }) }
plan = expect("damage modifier expiry at impact", "Slow Fireball")
assert(math.abs(plan.path[1].resistance.damageTakenMultiplier - 1.219) < 0.0001,
    "impact state must drop an expired stronger shared-group modifier while preserving independent stacking")
XelAssist.Combat.Resistance = nil

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetResistance = { projectedReduction = {} }
XelAssistCharDB.graphDepth = 2
XelAssist.Combat.Resistance = {
    Estimate = function(_, _, _, tooltip, s)
        local reduction = s.targetResistance and s.targetResistance.projectedReduction
            and s.targetResistance.projectedReduction[2] or 0
        return { school = tooltip.school, schoolName = "Fire",
            multiplier = reduction >= 100 and 1 or 0.1,
            landChance = 1, source = "beam setup test", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = {
    action("Expose Fire", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDuration = 30,
            testResistanceReduction = { [2] = 100 } }),
}
local fillerIndex
for fillerIndex = 1, 6 do
    table.insert(scenarioActions, action("Fire " .. fillerIndex, 1,
        "damage", 600, 0, { testSchool = 2 }))
end
plan = expect("beam preserves resistance setup", "Expose Fire")
assert(plan.follow[1] and string.find(plan.follow[1].name, "Fire ", 1, true) == 1,
    "WIDTH pruning must retain a useful target-modifier branch long enough to exploit it")

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
XelAssist.Combat.Resistance.Estimate = function()
    return { school = 5, schoolName = "Shadow", multiplier = 0.1,
        landChance = 0.1, source = "uncertain application test", unknown = false }
end
scenarioActions = { action("Unreliable Hex", 1, "debuff", 0, 0,
    { testSchool = 5, testDuration = 10 }) }
plan = expect("uncertain application retry", "Unreliable Hex")
assert(plan.follow[1] and plan.follow[1].name == "Unreliable Hex",
    "a ten-percent projected debuff application must not become certainly active in next-X")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.actorReadyAt = { player = 0, pet = 1 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 20 }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.5 }, {}
currentState.targetModifierEffects = { ["Uncertain Exposure"] = {
    name = "Uncertain Exposure", group = "Uncertain Exposure",
    damageTaken = { [2] = 0.5 }, resistanceReduction = {}, activeRoot = true } }
currentState.auras = { ["Uncertain Exposure"] = { remaining = 4, duration = 20,
    mine = true, target = "target", targetModifier = true } }
currentState.targetAuras = { ["Uncertain Exposure"] = {
    remaining = 4, duration = 20, mine = true } }
XelAssist.Combat.Resistance.Estimate = function(_, _, _, tooltip)
    if tooltip.targetDamageTaken then
        return { school = 2, schoolName = "Fire", multiplier = 1,
            landChance = 0.1, source = "uncertain refresh test", unknown = false }
    end
    return { school = tooltip.school, schoolName = "Fire", multiplier = 1,
        landChance = 1, source = "uncertain refresh test", unknown = false }
end
scenarioActions = {
    action("Uncertain Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 20, testDamageTaken = { [2] = 0.5 } }),
    petAction("Pet Firebolt", "damage", 100, 0, { testSchool = 2, ranged = true }),
}
plan = expect("uncertain modifier refresh", "Uncertain Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Firebolt"
    and math.abs(plan.path[2].resistance.damageTakenMultiplier - 1.5) < 0.0001,
    "a failed uncertain refresh branch must preserve the still-active prior modifier")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 80, 100
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 1 }, {}
currentState.targetModifierEffects = { ["Short Fire Exposure"] = {
    name = "Short Fire Exposure", group = "Short Fire Exposure",
    damageTaken = { [2] = 1 }, resistanceReduction = {} } }
currentState.auras = { ["Short Fire Exposure"] = { remaining = 1,
    duration = 10, target = "target", targetModifier = true } }
XelAssistCharDB.graphDepth = 3
XelAssist.Combat.Resistance.Estimate = function(_, _, _, tooltip)
    return { school = tooltip.school, schoolName = "Fire", multiplier = 1,
        landChance = 1, source = "periodic overlap test", unknown = false }
end
scenarioActions = {
    action("Long Burn", 1, "dot", 100, 0, { testSchool = 2, testDuration = 10 }),
    action("Filler", 1, "damage", 1, 0, { testSchool = 2 }),
    action("Execute", 1, "damage", 1, 0, { testSchool = 2, execute = 50 }),
}
plan = expect("periodic modifier overlap", "Long Burn")
assert(math.abs(plan.path[1].power - 110) < 0.0001
    and plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "an expiring target modifier must affect only overlapping DoT time, including stored future damage")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 1000, 1000
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 1 }, {}
currentState.targetModifierEffects = { ["Short Fire Exposure"] = {
    name = "Short Fire Exposure", group = "Short Fire Exposure",
    damageTaken = { [2] = 1 }, resistanceReduction = {} } }
currentState.auras = { ["Short Fire Exposure"] = { remaining = 1,
    duration = 10, target = "target", targetModifier = true } }
XelAssistCharDB.graphDepth = 1
scenarioActions = { action("Long Channel", 1, "damage", 100, 0,
    { channel = true, testSchool = 2, testDuration = 5 }) }
plan = expect("channel modifier overlap", "Long Channel")
assert(math.abs(plan.path[1].power - 120) < 0.0001,
    "a channel must integrate target modifiers across its occupied window")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 100, 100
local lingeringDot = action("Lingering Dot", 1, "dot", 100, 0,
    { testSchool = 2, testDuration = 10 })
currentState.auras = { ["Lingering Dot"] = { remaining = 10, duration = 10,
    mine = true, target = "target", periodicRate = 10, periodicRawRate = 10,
    periodicAction = lingeringDot, periodicTooltip = { school = 2 },
    applicationProbability = 1 } }
XelAssistCharDB.graphDepth = 3
scenarioActions = {
    action("Fresh Fire Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 10, testDamageTaken = { [2] = 1 } }),
    action("Filler", 1, "damage", 1, 0, { testSchool = 2 }),
    action("Execute", 1, "damage", 1, 0, { testSchool = 2, execute = 50 }),
}
plan = expect("new modifier changes stored ticks", "Fresh Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "a newly applied modifier must affect subsequent damage from an already stored DoT")

XelAssist.Combat.Resistance = nil

currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetDistance, currentState.targetLineOfSight = 20, true
currentState.autoShot = { supported = true, active = false,
    rangeChecked = true, rangeVerdict = true,
    rangeIdentityVerified = true, rangeTargetGuid = "target-guid",
    rangeSpellId = 75,
    projectileDistance = 20, projectileDistanceKind = "center",
    projectileSpeed = 40,
    targetGuid = "target-guid", rangedSpeed = 2, ammoKnown = true,
    ammoCount = 10, shotDamage = 100 }
currentState.inventory = { ammo = { known = true, count = 10 } }
local autoStart = action("Auto Shot", 1, "autoRepeat", 0, 0,
    { autoRepeat = true, ambient = true, startOnly = true, cast = 0 })
autoStart.spellId = 75
autoStart.mock.gcd = 0
local autoFiller = action("Low Filler", 1, "damage", 1, 0)
autoFiller.mock.gcd = 2.5
currentState.autoShot.rangeVerdict = nil
scenarioActions = { autoStart }
local unknownAutoRange = XelAssist.Graph:Evaluate("smart", true)
assert(unknownAutoRange == nil,
    "unknown exact Auto Shot range must not fall through to tooltip geometry")
currentState.autoShot.rangeVerdict = true
local alternateAuto = action("Auto Shot", 1, "autoRepeat", 0, 0,
    { autoRepeat = true, ambient = true, startOnly = true, cast = 0 })
alternateAuto.spellId, alternateAuto.mock.gcd = 52636, 0
scenarioActions = { alternateAuto }
assert(XelAssist.Graph:Evaluate("smart", true) == nil,
    "range evidence for spell 75 must not admit an alternate Auto Shot spell")
currentState.autoShot.rangeSpellId = 52636
plan = expect("alternate Auto Shot range identity", "Auto Shot")
assert(plan.action.spellId == 52636,
    "matching alternate spell evidence must remain executable")
currentState.autoShot.rangeSpellId = 75
scenarioActions = { autoStart, autoFiller }
XelAssistCharDB.graphDepth = 2
plan = expect("Auto Shot ambient start", "Auto Shot")
assert(plan.follow[1] and plan.follow[1].name == "Low Filler",
    "the graph must start sustained fire once, then evaluate ordinary actions")
local afterAutoStart = XelAssist.Graph.Transitions:Advance(currentState, plan.path[1])
assert(afterAutoStart.autoShot.active and afterAutoStart.targetHealth == 1000,
    "starting Auto Shot must enable ambient state without inventing an immediate hit")
local afterAutoFiller = XelAssist.Graph.Transitions:Advance(afterAutoStart, plan.path[2])
assert(afterAutoFiller.autoShot.ammoCount == 10
    and afterAutoFiller.targetHealth == 999
    and table.getn(afterAutoFiller.autoShot.inFlight) == 0,
    "an instant normal action must stop at its application boundary for weaving")
do
    local targets = XelAssist.Graph.Targets:Targets(autoFiller, afterAutoFiller)
    local nextFiller = XelAssist.Graph.Scoring:Evaluate(
        autoFiller, afterAutoFiller, targets[1])
    local afterNextFiller = XelAssist.Graph.Transitions:Advance(
        afterAutoFiller, nextFiller)
    assert(math.abs(nextFiller.actionStart - 2.55) < 0.0001
        and afterNextFiller.autoShot.ammoCount == 9
        and afterNextFiller.targetHealth == 898
        and table.getn(afterNextFiller.autoShot.inFlight) == 0,
        "the next normal decision must carry ambient launch and impact timing across the GCD")
end

currentState.playerCasting, currentState.playerChanneling = true, true
currentState.castRemaining, currentState.actorReadyAt.player = 3, 3
scenarioActions, XelAssistCharDB.graphDepth = { autoStart }, 1
plan = expect("Auto Shot armed during channel", "Auto Shot")
assert(plan.wait < 0.2,
    "Auto Shot must arm now during a channel while its launches remain blocked")
local armedDuringChannel = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(armedDuringChannel.playerCasting and armedDuringChannel.playerChanneling
    and armedDuringChannel.castRemaining > 2.9
    and armedDuringChannel.actorReadyAt.player == 3,
    "arming Auto Shot must preserve and advance the channel's readiness state")
currentState = armedDuringChannel
scenarioActions = { autoFiller }
plan = expect("ordinary action preserves valuable channel", "Continue current channel")
assert(plan.action.executor == "instruction" and plan.wait == 0,
    "an ordinary action must not clip an unpriced channel merely because the macro was pressed")
currentState.playerCasting, currentState.playerChanneling = true, false
currentState.castRemaining, currentState.actorReadyAt.player = 3, 3
currentState.autoShot.active = false
scenarioActions = { autoStart }
local castBlockedAuto = XelAssist.Graph:Evaluate("smart", true)
assert(castBlockedAuto == nil,
    "a non-channel spell cast must still prevent an immediate Auto Shot toggle")
currentState.playerCasting, currentState.castRemaining = false, 0
currentState.actorReadyAt.player = 0
scenarioActions = { autoStart, autoFiller }

XelAssistTestHunterAfterCastState = currentState
XelAssistTestPriorGetCastInfo = GetCastInfo
GetCastInfo = function()
    if not (currentState and currentState.playerChanneling) then return nil end
    local remaining = tonumber(currentState.castRemaining) or 0
    return { spellId = currentState.playerCastSpellId, castType = 3,
        castStartS = GetTime() - (3 - remaining),
        castRemainingMs = remaining * 1000, castDurationMs = 3000 }
end
do
    currentState = state("smart")
    currentState.role = "damage"
    currentState.targetHealth, currentState.targetMax = 1000, 1000
    currentState.targetHealthExact = true
    currentState.playerCasting, currentState.playerChanneling = true, true
    currentState.playerCastName, currentState.playerCastSpellId = "Mind Flay", 15407
    currentState.playerCastTargetGUID = currentState.targetGUID
    currentState.castRemaining = 2
    currentState.actorReadyAt = { player = 2, pet = 0 }
    local activeChannel = action("Mind Flay", 1, "damage", 600, 45,
        { channel = true, cast = 3, testDuration = 3,
            testChannelInterval = 1, ranged = true })
    activeChannel.spellId = 15407
    local weakNuke = action("Weak Nuke", 1, "damage", 50, 0,
        { ranged = true })
    scenarioActions, XelAssistCharDB.graphDepth = { activeChannel, weakNuke }, 1
    plan = expect("valuable channel beats routine clip", "Continue Mind Flay")
    assert(plan.power == 200 and plan.cast == 1
        and plan.action.executor == "instruction",
        "continuation must price only the next completed channel tick")
    local afterChannel = XelAssist.Graph.Transitions:Advance(
        currentState, plan.path[1])
    assert(afterChannel.targetHealth == 800 and afterChannel.playerChanneling
        and afterChannel.castRemaining == 1,
        "a non-final tick must retain the channel for another graph choice")
    local finalTick = assert(XelAssist.Graph.ChannelCommitment:Candidate(
        afterChannel))
    local afterFinal = XelAssist.Graph.Transitions:Advance(
        afterChannel, finalTick)
    assert(afterFinal.targetHealth == 600 and not afterFinal.playerCasting
        and not afterFinal.playerChanneling,
        "the final tick must release the projected channel commitment")

    currentState.targetCasting, currentState.targetCastRemaining = true, 1
    local interrupt = action("Silence", 1, "interrupt", 0, 0,
        { interrupt = true, ranged = true })
    scenarioActions = { activeChannel, weakNuke, interrupt }
    assert(not XelAssist.Graph.ChannelCommitment:CanClip(currentState,
        { actor = "pet", facts = { kind = "interrupt" } }),
        "an independently controlled actor must never cancel the player's channel")
    plan = expect("urgent interrupt clips valuable channel", "Silence")
    assert(plan.clipsChannel and plan.wait == 0,
        "the weighted interrupt branch must start now and disclose that it clips")
    local afterClip = XelAssist.Graph.Transitions:Advance(
        currentState, plan.path[1])
    assert(not afterClip.playerCasting and not afterClip.playerChanneling
        and afterClip.castRemaining == 0,
        "a chosen clipping action must release the projected channel commitment")
end
do
    currentState = state("smart")
    currentState.role = "damage"
    currentState.actors.pet = { guid = "pet-guid", health = 100,
        healthMax = 1000, resource = 100, resourceMax = 100,
        targetExists = false, targetsCurrent = false, recovering = true,
        retreatFollowIssued = true, retreatPassiveIssued = true }
    setFriendlies(currentState, {
        friendly("pet", "pet-guid", 100, 1000, 0),
        friendly("player", "player-guid", 1000, 1000, 0),
    })
    currentState.playerCasting, currentState.playerChanneling = true, true
    currentState.playerCastName, currentState.playerCastSpellId = "Mend Pet", 136
    currentState.playerCastTargetGUID = "pet-guid"
    currentState.castRemaining = 2
    currentState.actorReadyAt = { player = 2, pet = 0 }
    local mend = action("Mend Pet", 1, "petHeal", 600, 40,
        { channel = true, cast = 3, testDuration = 3,
            testChannelInterval = 1, pet = true, fixedTarget = "pet" })
    mend.spellId = 136
    local weakShot = action("Weak recovery shot", 1, "damage", 20, 0,
        { ranged = true })
    scenarioActions, XelAssistCharDB.graphDepth = { mend, weakShot }, 1
    plan = expect("pet-heal channel commitment", "Continue Mend Pet")
    local recovered = XelAssist.Graph.Transitions:Advance(
        currentState, plan.path[1])
    assert(recovered.actors.pet.health == 300 and recovered.playerChanneling
        and XelAssist.Graph.State:FriendlyByUnit(recovered, "pet").health == 300,
        "a pet-heal breakpoint must apply one tick to both health mirrors")
    local finalMend = assert(XelAssist.Graph.ChannelCommitment:Candidate(
        recovered))
    recovered = XelAssist.Graph.Transitions:Advance(recovered, finalMend)
    assert(recovered.actors.pet.health == 500
        and XelAssist.Graph.State:FriendlyByUnit(recovered, "pet").health == 500
        and not recovered.actors.pet.recovering
        and not recovered.actors.pet.retreatFollowIssued
        and not recovered.actors.pet.retreatPassiveIssued,
        "the final Mend Pet tick must finish companion recovery causally")
end
GetCastInfo = XelAssistTestPriorGetCastInfo
XelAssistTestPriorGetCastInfo = nil
currentState = XelAssistTestHunterAfterCastState
XelAssistTestHunterAfterCastState = nil
scenarioActions = { autoStart, autoFiller }

currentState.autoShot.active = true
currentState.autoShot.activeSource = "action bar repeat"
currentState.autoShot.nextLaunchIn = 2
XelAssistCharDB.graphDepth = 1
plan = expect("Auto Shot active repeat guard", "Low Filler")
assert(plan.action.name ~= "Auto Shot",
    "an active repeat must never re-enter the candidate graph as a toggle press")

do
    currentState = state("smart")
    currentState.targetDistance, currentState.distance = 20, 20
    currentState.wand = { supported = true, active = false,
        activeKnown = true, pending = false, clockKnown = true,
        currentTargetGuid = currentState.targetGUID,
        speed = 2, damage = 12 }
    local wandStart = action("Shoot", 1, "autoRepeat", 0, 0,
        { autoRepeat = true, wandRepeat = true, ambient = true,
            startOnly = true, recovery = true, ranged = true, cast = 0 })
    wandStart.mock.gcd, wandStart.mock.minRange, wandStart.mock.maxRange = 0, 0, 30
    local strongerCast = action("Shadow Bolt", 1, "damage", 80, 20,
        { ranged = true, cast = 1.7 })
    scenarioActions, XelAssistCharDB.graphDepth = { wandStart, strongerCast }, 3
    plan = expect("wand start cannot farm setup value", "Shadow Bolt")
    assert(plan.path[1].action.name == "Shadow Bolt",
        "a zero-output wand toggle must not beat or precede a stronger cast")
    scenarioActions = { wandStart }
    plan = expect("wand remains a resource fallback", "Shoot")
    assert(plan.follow[1] and plan.follow[1].name == "Continue Shoot",
        "wand start must remain searchable through its actual future shot")
end

local savedAttackTarget = AttackTarget
AttackTarget = function() end
XelAssist.Game.PlayerAttack:Reset()
currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.playerAttack = { supported = true, active = false,
    activeKnown = true, pending = false, clockKnown = true,
    source = "Nampower current casting info" }
local meleeStart = action("Attack", 1, "command", 400, 0,
    { playerAttack = true, ambient = true, startOnly = true,
        melee = true, whiteAttack = true, cast = 0,
        effectMaxRange = 5, effectRangeHitbox = true })
meleeStart.mock.gcd = 0
local meleeFiller = action("Melee Filler", 1, "damage", 1, 0,
    { initiatesCombat = true, melee = true })
meleeFiller.mock.gcd = 2.5
do
    currentState.targetDistance, currentState.distance = 12, 12
    currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
    scenarioActions, XelAssistCharDB.graphDepth = { meleeStart }, 2
    local rangedAttack, rangedReason = XelAssist.Graph:Evaluate("smart", true)
    assert(rangedAttack and rangedAttack.action.name == "Move into range"
        and rangedAttack.follow[1]
        and rangedAttack.follow[1].name == "Attack",
        "Attack must require proven melee effect reach even when its command is accepted")
    scenarioActions = { action("Soft Trigger", 1, "damage", 100, 0,
        { effectMaxRange = 5, effectRangeHitbox = true }) }
    local softEffect, softReason = XelAssist.Graph:Evaluate("smart", true)
    assert(softEffect and softEffect.action.name == "Move into range"
        and softEffect.follow[1]
        and softEffect.follow[1].name == "Soft Trigger",
        "soft commands must not be valued when their payload has zero effect")
    currentState.targetDistance, currentState.distance = 4, 4
    expect("soft effect proven melee reach", "Soft Trigger")

    local futureReach = action("Future Reach", 1, "damage", 100, 0,
        { ranged = true, testMaxRange = 30,
            effectMaxRange = 5, effectRangeHitbox = true })
    currentState.time = 1
    local futureDescriptor = XelAssist.Graph.Targets:Targets(
        futureReach, currentState)[1]
    local priorFutureQueries = rangeQueries["Future Reach(Rank 1)"] or 0
    local futureLegal, futureReason, _, _, _, projectedDescriptor =
        XelAssist.Graph.Targets:Legal(
            futureReach, currentState, futureDescriptor)
    assert(futureLegal and futureReason == nil
        and projectedDescriptor.spatialConditionFingerprint
        and table.getn(projectedDescriptor.spatialConditions) >= 2
        and not projectedDescriptor.spatialConditionalOnly
        and (rangeQueries["Future Reach(Rank 1)"] or 0) == priorFutureQueries,
        "future spatial projection must use captured facts and explicit conditions, never live APIs")
    local repeatLegal, _, _, _, _, repeatDescriptor =
        XelAssist.Graph.Targets:Legal(
            futureReach, currentState, futureDescriptor)
    assert(repeatLegal and repeatDescriptor.spatialConditionFingerprint
            == projectedDescriptor.spatialConditionFingerprint,
        "equivalent future spatial conditions must have a stable fingerprint")
    currentState.targetDistance, currentState.distance = nil, nil
    futureLegal, futureReason, _, _, _, projectedDescriptor =
        XelAssist.Graph.Targets:Legal(
            futureReach, currentState, futureDescriptor)
    assert(futureLegal and futureReason == nil
        and projectedDescriptor.spatialConditionalOnly
        and projectedDescriptor.spatialConditionFingerprint,
        "unknown future reach must remain an explicit proof condition")
    currentState.time = 0
    currentState.targetDistance, currentState.distance = 4, 4
    currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
end
scenarioActions = { meleeStart, meleeFiller }
XelAssistCharDB.graphDepth = 2
plan = expect("productive melee action starts ambient Attack", "Melee Filler")
assert(plan.power > 0 and plan.path[1].startsPlayerAttack,
    "a productive opener must outrank the redundant bare Attack command")
local afterMeleeStart = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(afterMeleeStart.targetHealth < currentState.targetHealth
    and afterMeleeStart.playerAttack.active
    and afterMeleeStart.playerAttack.activeKnown
    and not afterMeleeStart.playerAttack.pending,
    "a productive melee opener must deal its own damage and establish Attack")
currentState.playerAttack.active = true
XelAssistCharDB.graphDepth = 1
plan = expect("player Attack active repeat guard", "Melee Filler")
assert(plan.action.name ~= "Attack",
    "an active player Attack must never re-enter the graph as a toggle press")

do
    local priorState, priorActions = currentState, scenarioActions
    currentState = state("smart")
    currentState.targetDistance, currentState.distance = 4, 4
    currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
    currentState.resource, currentState.resourceMax = 0, 100
    currentState.resourceType, currentState.playerLevel = 1, 1
    currentState.playerResourceExact, currentState.playerResourceReserved = true, 0
    currentState.targetHealth, currentState.targetMax = 500, 500
    currentState.playerAttack = { supported = true, active = true,
        activeKnown = true, onSwing = { occupied = false, pending = false,
            exact = true }, attackRound = { projectable = true,
            phaseKnown = true, verified = true,
            targetGuid = currentState.targetGUID, nextSwingIn = 1,
            interval = 2, power = 10, normalDamageKnown = true,
            phaseSource = "exact Warrior scenario" } }
    local heroic = action("Heroic Strike", 1, "damage", 20, 15,
        { melee = true, onNextSwing = true })
    scenarioActions, XelAssistCharDB.graphDepth = { meleeStart, heroic }, 3
    plan = expect("Warrior rage runway", "Continue Attack")
    assert(plan.action.executor == "instruction"
        and plan.follow[1] and plan.follow[1].name == "Heroic Strike"
        and plan.completedDepth == 3,
        "an exact zero-rage attack must expose its newly funded action, not wait again")
    currentState, scenarioActions = priorState, priorActions
end

currentState.playerAttack.active = false
currentState.targetDistance, currentState.distance = 12, 12
currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
do
    local rangedSetup = action("Ranged Setup", 1, "damage", 900, 0,
        { ranged = true, testMaxRange = 30, testCooldown = 10 })
    scenarioActions, XelAssistCharDB.graphDepth = { rangedSetup, meleeStart }, 3
    plan = expect("future melee keeps explicit movement edge", "Ranged Setup")
    assert(plan.path[2] and plan.path[2].action.name == "Move into range"
        and plan.path[2].action.executor == "instruction"
        and plan.path[3] and plan.path[3].action.name == "Attack"
        and plan.path[3].spatialConditionalOnly,
        "an out-of-range future must pass through a visible non-executable movement edge")
    currentState.targetDistance, currentState.distance = 4, 4
    plan = expect("future melee carries spatial condition", "Ranged Setup")
    assert(plan.path[2] and plan.path[2].action.name == "Attack"
        and plan.path[2].spatialConditionFingerprint
        and table.getn(plan.path[2].spatialConditions or {}) > 0,
        "a reachable future melee step must disclose the spatial facts it assumes")
end

do
    local losAction = action("LOS Boundary Probe", 1, "damage", 10, 0)
    local rootLosState = state("smart")
    rootLosState.targetLineOfSight = false
    local rootDescriptor = XelAssist.Graph.Targets:Targets(
        losAction, rootLosState)[1]
    local rootLegal, rootReason = XelAssist.Graph.Targets:Legal(
        losAction, rootLosState, rootDescriptor)
    assert(rootLegal and not rootReason,
        "an unproven line-of-sight hint must not block a live action")

    local futureLosState = state("smart")
    futureLosState.time, futureLosState.targetLineOfSight = 1, false
    local futureDescriptor = XelAssist.Graph.Targets:Targets(
        losAction, futureLosState)[1]
    local futureLegal, futureReason, _, _, _, projectedDescriptor =
        XelAssist.Graph.Targets:Legal(
            losAction, futureLosState, futureDescriptor)
    local losCondition, i
    for i = 1, table.getn(projectedDescriptor
        and projectedDescriptor.spatialConditions or {}) do
        local condition = projectedDescriptor.spatialConditions[i]
        if condition.kind == "line of sight" then losCondition = condition end
    end
    assert(futureLegal and not futureReason and not losCondition
        and projectedDescriptor.spatialConditionalOnly ~= true,
        "future search must not invent line-of-sight conditions from an untrusted hint")

    local priorBlocker = XelAssist.Combat.Observations.Blocker
    local blockerCalls = 0
    XelAssist.Combat.Observations.Blocker = function()
        blockerCalls = blockerCalls + 1
        return "observed immunity"
    end
    rootLosState.targetLineOfSight = true
    rootDescriptor = XelAssist.Graph.Targets:Targets(
        losAction, rootLosState)[1]
    rootLegal, rootReason = XelAssist.Graph.Targets:Legal(
        losAction, rootLosState, rootDescriptor)
    futureDescriptor = XelAssist.Graph.Targets:Targets(
        losAction, futureLosState)[1]
    futureLegal, futureReason = XelAssist.Graph.Targets:Legal(
        losAction, futureLosState, futureDescriptor)
    XelAssist.Combat.Observations.Blocker = priorBlocker
    assert(not rootLegal and rootReason == "observed immunity"
        and futureLegal and not futureReason and blockerCalls == 1,
        "short-lived live observation blockers must not leak into future nodes")
end

do
currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetDistance, currentState.distance = 4, 4
currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
currentState.resource, currentState.resourceMax = 100, 100
currentState.combo = 0
currentState.playerAttack = { supported = true, active = false,
    activeKnown = true, pending = false, clockKnown = true }
local productiveStrike = action("Sinister Strike", 1, "builder", 5, 40,
    { melee = true, testInitiatesCombat = true })
scenarioActions = { meleeStart, productiveStrike }
XelAssistCharDB.graphDepth = 2
plan = expect("productive melee start subsumes Attack", "Sinister Strike")
assert(plan.startsPlayerAttack and plan.value > 800
    and plan.path[1].startsPlayerAttack
    and not (plan.path[2] and plan.path[2].action.name == "Attack"),
    "a legal combat-initiating melee ability must own the Attack setup edge")
local afterProductiveStart = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(afterProductiveStart.playerAttack.active
    and afterProductiveStart.playerAttack.targetGuid == currentState.targetGUID
    and afterProductiveStart.combo == 1
    and afterProductiveStart.resource == 60,
    "the productive opener must pin sustained Attack without inventing another input")

currentState.resource = 0
XelAssistCharDB.graphDepth = 1
plan = expect("bare Attack remains no-resource fallback", "Attack")
assert(not plan.startsPlayerAttack,
    "the bare command must remain a fallback when the productive action is illegal")

currentState.playerStealthed, currentState.playerStealthKnown = true, true
scenarioActions = { meleeStart }
local protected, protectedReason = XelAssist.Graph:Evaluate("smart", true)
assert(protected == nil and protectedReason == "Preserving stealth for an opener",
    "bare Attack must never destroy an exactly observed stealth state")

currentState.resource = 100
local stealthOpener = action("Ambush", 1, "builder", 100, 60,
    { melee = true, behind = true, testInitiatesCombat = true,
        testRequiresStealth = true })
scenarioActions = { meleeStart, stealthOpener }
XelAssistCharDB.graphDepth = 2
plan = expect("stealth opener owns engagement", "Ambush")
local afterStealthOpener = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(plan.startsPlayerAttack and not plan.follow[1]
    and afterStealthOpener.playerStealthed == false
    and afterStealthOpener.playerStealthKnown
    and afterStealthOpener.playerAttack.active,
    "the opener must consume projected stealth and prevent a repeated stealth action")

currentState = state("smart")
currentState.inCombat, currentState.pet = false, false
currentState.playerStealthed, currentState.playerStealthKnown = true, true
currentState.playerBehindTarget = true
currentState.targetDistance, currentState.distance = 4, 4
currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
currentState.resource, currentState.resourceMax, currentState.combo = 100, 100, 0
currentState.playerAttack = { supported = true, active = false,
    activeKnown = true, pending = false, clockKnown = true }
XelAssistTestSavedWeaponDamage = XelAssist.Game.Capabilities.WeaponDamage
XelAssist.Game.Capabilities.WeaponDamage = function() return 10 end
XelAssistTestSavedWeaponBasis = XelAssist.Game.WeaponPower.Basis
XelAssist.Game.WeaponPower.Basis = function()
    return 10, { exact = true, damagePercent = 1 }
end
XelAssistTestBackstab = action("Backstab", 1, "builder", 999, 60,
    { melee = true, behind = true, testInitiatesCombat = true,
        testWeaponCoefficient = 1.5, testWeaponFlat = 15,
        testWeaponNormalized = true, gcd = 1 })
XelAssistTestSinister = action("Sinister Strike", 1, "builder", 999, 40,
    { melee = true, testInitiatesCombat = true,
        testWeaponCoefficient = 1, testWeaponFlat = 3,
        testWeaponNormalized = true, gcd = 1 })
scenarioActions = { meleeStart, XelAssistTestBackstab, XelAssistTestSinister }
XelAssist.Graph.testDelivery = 0.7
XelAssistCharDB.graphDepth = 2
plan = expect("rear dagger attack uses DBC weapon value", "Backstab")
assert(plan.path[1].rawPower == 30,
    "Backstab must be 1.5 times normalized weapon plus 15")
XelAssistTestAfterBackstab = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(XelAssistTestAfterBackstab.resource == 40
    and XelAssistTestAfterBackstab.combo == 1
    and XelAssistTestAfterBackstab.playerStealthed == false
    and XelAssistTestAfterBackstab.playerAttack.active,
    "Backstab must spend energy, build combo, break stealth and start Attack")
currentState.playerBehindTarget = false
plan = expect("rear dagger attack retains positional gate", "Sinister Strike")
assert(plan.rootBlockers
    and plan.rootBlockers["Backstab:1:player"]
    and plan.rootBlockers["Backstab:1:player"].reasons["must be behind target"],
    "the root plan must retain why the stronger rear attack was gated")
XelAssist.Graph.testDelivery = nil
XelAssist.Game.Capabilities.WeaponDamage = XelAssistTestSavedWeaponDamage
XelAssist.Game.WeaponPower.Basis = XelAssistTestSavedWeaponBasis
XelAssistTestSavedWeaponDamage, XelAssistTestBackstab = nil, nil
XelAssistTestSavedWeaponBasis = nil
XelAssistTestSinister, XelAssistTestAfterBackstab = nil, nil
end

do
currentState = state("smart")
currentState.inCombat = false
currentState.targetReaction = 2
currentState.playerStealthed, currentState.playerStealthKnown = false, true
currentState.playerBehindTarget = false
currentState.targetDistance, currentState.distance = 20, 20
currentState.targetDistanceKind, currentState.distanceKind = "hitbox", "hitbox"
currentState.resource, currentState.resourceMax, currentState.combo = 100, 100, 0
currentState.playerAttack = { supported = true, active = false,
    activeKnown = true, pending = false, clockKnown = true }
local stealth = action("Stealth", 1, "buff", 0, 0,
    { self = true, outOfCombat = true, stealthPreparation = true,
        testAppliesStealth = true })
stealth.facts.movementSpeedMultiplier = 0.5
local approachBackstab = action("Backstab", 1, "builder", 400, 60,
    { melee = true, behind = true, testMaxRange = 5,
        testInitiatesCombat = true })
local approachSinister = action("Sinister Strike", 1, "builder", 200, 40,
    { melee = true, testMaxRange = 5, testInitiatesCombat = true })
scenarioActions = { stealth, approachBackstab, approachSinister }
XelAssistCharDB.graphDepth = 3
XelAssist.Graph.testRangeBlocked = true
currentState.hostile, currentState.targetGUID = false, nil
local idleStealthPlan, idleStealthReason =
    XelAssist.Graph:Evaluate("smart", true)
assert(idleStealthPlan == nil and idleStealthReason
    and XelAssist.Graph.StealthSetup:Blocker(currentState)
        == "no stealth setup target",
    "Stealth must not become an idle permanent recommendation without a target; got "
        .. tostring(idleStealthPlan and idleStealthPlan.action
            and idleStealthPlan.action.name) .. " / " .. tostring(idleStealthReason))
currentState.hostile, currentState.targetGUID = true, "target-guid"
plan = expect("stealth opens conditional rear approach", "Stealth")
assert(plan.path[2] and plan.path[2].action.name == "Backstab"
    and plan.path[2].spatialConditionalOnly
    and plan.path[2].spatialConditionFingerprint,
    "Stealth against an aggressive target must expose the stronger rear opener as conditional")
local sawApproach, sawRear, i = false, false, nil
for i = 1, table.getn(plan.path[2].spatialConditions or {}) do
    local condition = plan.path[2].spatialConditions[i]
    if condition.assumption == "approach" then sawApproach = true end
    if condition.kind == "behind" and condition.assumption == "position" then
        sawRear = true
    end
end
assert(sawApproach and sawRear,
    "the setup must disclose both undetected approach and rear-position conditions")
local afterStealth = XelAssist.Graph.Transitions:Advance(currentState, plan.path[1])
assert(afterStealth.playerStealthed == true
    and afterStealth.stealthApproachTargetGUID == currentState.targetGUID,
    "Stealth must project the exact target-pinned approach opportunity")
currentState.targetReaction = 4
plan = expect("neutral Backstab does not justify Stealth", "Move into range")
assert(plan.path[2] and plan.path[2].action.name ~= "Stealth"
    and plan.path[2].spatialConditionalOnly
    and XelAssist.Graph.StealthSetup:Blocker(currentState)
        == "no stealth-enabled action",
    "a neutral target must use ordinary movement rather than paying Stealth's movement penalty")
currentState.targetDistance, currentState.distance = 4, 4
currentState.playerBehindTarget = true
XelAssist.Graph.testRangeBlocked = false
local ambush = action("Ambush", 1, "builder", 600, 60,
    { melee = true, behind = true, testMaxRange = 5,
        testInitiatesCombat = true, testRequiresStealth = true })
scenarioActions = { stealth, ambush, approachBackstab, approachSinister }
XelAssist.Graph.StealthSetup:Prepare(currentState, scenarioActions)
local stealthDescriptor = XelAssist.Graph.Targets:Targets(
    stealth, currentState)[1]
local stealthCandidate = XelAssist.Graph.Scoring:Evaluate(
    stealth, currentState, stealthDescriptor)
assert(XelAssist.Graph.StealthSetup:Blocker(currentState) == nil
    and stealthCandidate and stealthCandidate.reason == "unlocks Ambush",
    "a genuine stealth prerequisite must retain Stealth as a weighted graph setup edge")
XelAssist.Graph.testRangeBlocked = false
end
AttackTarget = savedAttackTarget

local function hunterAutoState(health, nextLaunch, distance)
    local value = state("smart")
    value.targetHealth, value.targetMax = health, health
    value.targetDistance, value.targetLineOfSight = distance, true
    value.actorReadyAt = { player = 0, pet = 0 }
    value.autoShot = { supported = true, active = true,
        activeSource = "action bar repeat", spellId = 75,
        rangeChecked = true, rangeVerdict = true,
        rangeIdentityVerified = true, rangeTargetGuid = value.targetGUID,
        rangeSpellId = 75,
        projectileDistance = distance, projectileDistanceKind = "center",
        targetGuid = value.targetGUID, currentTargetGuid = value.targetGUID,
        nextLaunchIn = nextLaunch, rangedSpeed = 2,
        projectileSpeed = 40, projectable = true,
        ammoKnown = true, ammoCount = 10, shotDamage = 100,
        inFlight = {} }
    value.inventory = { ammo = { known = true, count = 10 } }
    return value
end

local delayedShot = action("Delayed Shot", 1, "damage", 100, 30)
currentState = hunterAutoState(50, 0.1, 8)
currentState.actorReadyAt.player = 1
local delayedDescriptor = XelAssist.Graph.Targets:Targets(
    delayedShot, currentState)[1]
local delayedCandidate = XelAssist.Graph.Scoring:Evaluate(
    delayedShot, currentState, delayedDescriptor)
assert(delayedCandidate and delayedCandidate.value == -100000
    and delayedCandidate.reason == "ambient attack resolves first",
    "a projectile that lands first must suppress a redundant hostile action")
local ambientKill = XelAssist.Graph.Transitions:Advance(
    currentState, delayedCandidate)
assert(ambientKill.targetHealth == 0 and ambientKill.resource == 1000
    and ambientKill.autoShot.ammoCount == 9,
    "a lethal earlier projectile must spend one arrow but not the skipped action resource")

local instantShot = action("Instant Shot", 1, "damage", 100, 30)
currentState = hunterAutoState(50, 0.2, 8)
local instantDescriptor = XelAssist.Graph.Targets:Targets(
    instantShot, currentState)[1]
local instantCandidate = XelAssist.Graph.Scoring:Evaluate(
    instantShot, currentState, instantDescriptor)
local instantKill = XelAssist.Graph.Transitions:Advance(
    currentState, instantCandidate)
assert(instantKill.targetHealth == 0 and instantKill.resource == 970
    and instantKill.autoShot.ammoCount == 10,
    "an instant lethal action must stop a future launch before it spends ammunition")

currentState = hunterAutoState(100, 2, 100)
currentState.targetLineOfSight = false
currentState.autoShot.active = false
currentState.autoShot.projectable = false
currentState.autoShot.inFlight = {
    { power = 60, targetGuid = currentState.targetGUID, remaining = 0.1 }
}
local carriedHealth, carriedImpacts =
    XelAssist.Graph.AutoShotEffects:HealthBeforeImpact(currentState,
        { action = { actor = "pet", facts = {} }, wait = 1,
            cast = 0, occupancy = 1 })
assert(carriedHealth == 40 and carriedImpacts == 1,
    "an already-launched arrow must still land after range or line-of-sight changes")
currentState.autoShot.inFlight[1].targetGuid = "prior-target-guid"
carriedHealth, carriedImpacts =
    XelAssist.Graph.AutoShotEffects:HealthBeforeImpact(currentState,
        { action = { actor = "pet", facts = {} }, wait = 1,
            cast = 0, occupancy = 1 })
assert(carriedHealth == 100 and carriedImpacts == 0,
    "an arrow launched at a prior target must never damage the selected target")

-- Bridge the exact live CAST event through Combat's session ledger into the
-- graph. The arrow is already paid for by the client, but its earlier lethal
-- impact must prevent the later chosen action and its resource cost.
local priorUnitClass, priorUnitExists = UnitClass, UnitExists
local priorRangedSpeed, priorAmmo = UnitRangedDamage, GetAmmo
local priorCenterDistance, priorSpellRecord = UnitDistanceSquared, GetSpellRecField
local priorRangedDamage = XelAssist.Game.Capabilities.RangedDamage
local priorDistance = XelAssist.Game.Capabilities.Distance
local liveClock = 100
GetTime = function() return liveClock end
UnitClass = function() return "Hunter", "HUNTER" end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
    if unit == "target" then return true, "target-guid" end
    return false, nil
end
UnitRangedDamage = function() return 2 end
UnitDistanceSquared = function() return 400, true end
GetSpellRecField = function(_, field)
    if field == "speed" then return 40 end
end
GetAmmo = function() return 2516, 9 end
XelAssist.Game.Capabilities.RangedDamage = function() return 60 end
XelAssist.Game.Capabilities.Distance = function() return 20 end
XelAssist.Combat.AutoShot:Reset(true)
XelAssist.Combat.AutoShot:UnitCast(
    "player-guid", "target-guid", "CAST", 75)
liveClock = 100.1
local liveAuto = XelAssist.Combat.AutoShot:Snapshot({ hostile = true,
    distance = 20, lineOfSight = true })
UnitClass, UnitExists = priorUnitClass, priorUnitExists
UnitRangedDamage, GetAmmo = priorRangedSpeed, priorAmmo
UnitDistanceSquared, GetSpellRecField = priorCenterDistance, priorSpellRecord
XelAssist.Game.Capabilities.RangedDamage = priorRangedDamage
XelAssist.Game.Capabilities.Distance = priorDistance
GetTime = function() return 0 end
currentState = state("smart")
currentState.targetHealth, currentState.targetMax = 50, 50
currentState.targetDistance, currentState.targetLineOfSight = 20, true
currentState.actorReadyAt = { player = 1, pet = 0 }
currentState.autoShot = liveAuto
currentState.inventory = { ammo = { known = true, count = 9 } }
local liveArrowAction = action("Live Arrow Followup", 1, "damage", 100, 30)
local liveArrowDescriptor = XelAssist.Graph.Targets:Targets(
    liveArrowAction, currentState)[1]
local liveArrowCandidate = XelAssist.Graph.Scoring:Evaluate(
    liveArrowAction, currentState, liveArrowDescriptor)
assert(liveArrowCandidate.value == -100000
    and liveArrowCandidate.reason == "ambient attack resolves first",
    "a lethal live in-flight arrow must suppress the later chosen action")
local liveArrowResult = XelAssist.Graph.Transitions:Advance(
    currentState, liveArrowCandidate)
assert(liveArrowResult.targetHealth == 0
    and liveArrowResult.resource == 1000
    and liveArrowResult.autoShot.ammoCount == 9
    and liveArrowResult.chosenActionPrevented,
    "a carried live arrow must land without spending action resource or another arrow")
XelAssist.Combat.AutoShot:Reset(true)

local autoSpellIds = {}
XelAssist.Combat.Resistance = {
    Estimate = function(_, subject, _, tooltip)
        if subject.name == "Auto Shot" then autoSpellIds[subject.spellId] = true end
        return { school = tooltip.school or 0, multiplier = 1,
            landChance = 1, uncertaintyMultiplier = 1,
            source = "Auto Shot causal test" }
    end,
    Contrast = function() return nil end,
}
currentState = hunterAutoState(500, 0.1, 20)
currentState.autoShot.spellId = 52636
currentState.autoShot.rangeSpellId = 52636
currentState.autoShot.rangedSpeed = 1
currentState.actors.pet = { health = 100, healthMax = 100,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false }
local petExposure = petAction("Pet Exposure", "debuff", 0, 0,
    { cast = 0.2, testDuration = 10, testDamageTaken = { [0] = 0.5 } })
local exposureCandidate = { action = petExposure, target = "target",
    targetGUID = currentState.targetGUID, targetRelation = "hostile",
    cost = 0, cast = 0.2, occupancy = 0.2, wait = 0, downtime = 0.2,
    tooltip = petExposure.mock, power = 0, effectDelivery = 1 }
local afterExposure = XelAssist.Graph.Transitions:Advance(
    currentState, exposureCandidate)
assert(autoSpellIds[52636] and afterExposure.autoShot.inFlight[1]
    and afterExposure.autoShot.inFlight[1].power == 100
    and afterExposure.targetDamageTaken[0] == 0.5,
    "launch must preserve exact spell identity and lock power before a later modifier")
local petWait = petAction("Pet Follow", "command", 0, 0)
petWait.command = "follow"
local waitCandidate = { action = petWait, target = "pet",
    targetRelation = "pet", cost = 0, cast = 0, occupancy = 1,
    wait = 0, downtime = 1, tooltip = petWait.mock,
    power = 0, effectDelivery = 1 }
local afterModifierLaunch = XelAssist.Graph.Transitions:Advance(
    afterExposure, waitCandidate)
assert(afterModifierLaunch.targetHealth == 400
    and afterModifierLaunch.autoShot.inFlight[1]
    and afterModifierLaunch.autoShot.inFlight[1].power == 150,
    "a prior shot must stay unmodified while a later launch uses the active vulnerability")
XelAssist.Combat.Resistance = nil

local function causalCandidate(subject, wait, occupancy, cast, power, cost)
    return { action = subject, target = "target",
        targetGUID = "target-guid", targetRelation = "hostile",
        cost = cost or 0, cast = cast or 0, occupancy = occupancy,
        wait = wait, downtime = wait + occupancy, actionStart = wait,
        tooltip = subject.mock, power = power or 0, effectDelivery = 1 }
end

local function pinCombatHostile(s, health, exact)
    local record = { key = "target-guid", guid = "target-guid",
        unit = "target", source = "selected", selected = true,
        executable = true, engaged = true, dead = false,
        health = health, healthMax = health, healthExact = exact ~= false,
        geometry = { player = { distance = 3, lineOfSight = true },
            pet = { distance = 3, lineOfSight = true, behind = true } },
        targetRef = { unit = "target", guid = "target-guid",
            relation = "hostile", source = "selected" },
        targetAuras = {}, projectedAuras = {}, modifierEffects = {},
        damageTaken = {}, baseDamageTaken = {}, casting = false,
        castProbability = 0, threat = { playerHasAggro = true,
            petHasAggro = false, playerDelta = 0, petDelta = 0 } }
    setHostiles(s, { record }, record.key)
    return record
end

do
    local wandThreatState = state("smart")
    local wandThreatRecord = pinCombatHostile(wandThreatState, 100)
    wandThreatRecord.threat.playerHasAggro = false
    wandThreatRecord.threat.petHasAggro = true
    wandThreatState.hasAggro, wandThreatState.pet = false, true
    wandThreatState.targetDistance = 20
    wandThreatState.wand = { active = true, activeKnown = true,
        targetGuid = "target-guid", damage = 12, speed = 2,
        nextShotIn = 0.4, tooltip = { minRange = 0, maxRange = 30 } }
    local wandThreatCandidate = XelAssist.Graph.WandCommitment:Candidate(
        wandThreatState)
    assert(wandThreatCandidate and wandThreatCandidate.threat == 12
        and wandThreatCandidate.value < 24,
        "wand continuation must price its player-owned threat while the pet tanks")
    local afterWandThreat = XelAssist.Graph.Transitions:Advance(
        wandThreatState, wandThreatCandidate)
    wandThreatRecord = afterWandThreat.hostiles.byKey["target-guid"]
    assert(wandThreatRecord.health == 88
        and wandThreatRecord.projectedThreat.player == 12
        and wandThreatRecord.threat.playerDelta == 12,
        "a resolved wand shot must project both health loss and player threat")
end

local castCooldownState = state("smart")
pinCombatHostile(castCooldownState, 1000)
local castCooldown = action("Cast Cooldown", 1, "damage", 1, 0,
    { cast = 2, testCooldown = 10 })
local castCooldownCandidate = causalCandidate(castCooldown, 3, 2, 2, 1, 0)
castCooldownCandidate.targetKey = "target-guid"
local afterCastCooldown = XelAssist.Graph.Transitions:Advance(
    castCooldownState, castCooldownCandidate)
assert(afterCastCooldown.readyAt["player:Cast Cooldown"] == 15,
    "a cast cooldown must start at successful application, not cast start")
local reactiveState = state("smart")
pinCombatHostile(reactiveState, 1000)
local reactive = action("Reactive Lock", 1, "damage", 1, 0,
    { reactive = true })
local reactiveCandidate = causalCandidate(reactive, 0, 1.5, 0, 1, 0)
reactiveCandidate.targetKey = "target-guid"
local afterReactive = XelAssist.Graph.Transitions:Advance(
    reactiveState, reactiveCandidate)
assert(afterReactive.readyAt["player:Reactive Lock"] == nil,
    "a reactive action must not fabricate a sixty-second cooldown")

local chosenPetState = state("smart")
local chosenPetRecord = pinCombatHostile(chosenPetState, 100)
chosenPetState.actors.pet = { guid = "pet-guid", level = 60,
    health = 100, healthMax = 100, resource = 100, resourceMax = 100,
    targetExists = true, targetGuid = "target-guid", targetsCurrent = true,
    hasAggro = false, distance = 3, lineOfSight = true,
    happinessDamageMultiplier = 1, autocasts = {} }
local chosenBite = petAction("Chosen Bite", "damage", 40, 10,
    { melee = true, damageActor = "pet", testCooldown = 10 })
chosenBite.spellId = 17253
chosenPetState.actors.pet.autocasts = { { name = chosenBite.name,
    actor = "pet", kind = "damage", spellId = chosenBite.spellId,
    facts = chosenBite.facts, power = 40, cost = 10, cooldown = 10,
    readyIn = 0, tooltip = { school = 0, cooldown = 10 } } }
local chosenBiteCandidate = causalCandidate(chosenBite, 0, 0.1, 0, 40, 10)
chosenBiteCandidate.targetKey, chosenBiteCandidate.threat =
    "target-guid", 36
local afterChosenBite = XelAssist.Graph.Transitions:Advance(
    chosenPetState, chosenBiteCandidate)
local afterChosenRecord = afterChosenBite.hostiles.byKey["target-guid"]
assert(afterChosenRecord.health == 60
    and afterChosenBite.actors.pet.resource == 90
    and afterChosenRecord.projectedThreat.pet == 36
    and afterChosenRecord.threat.petDelta == 36
    and math.abs(afterChosenBite.actors.pet.actionReadyIn - 1.4) < 0.001
    and afterChosenBite.actorReadyAt.pet == 1.5
    and math.abs(afterChosenBite.actors.pet.autocasts[1].readyIn - 9.9) < 0.001,
    "a chosen autocast ability must spend, damage, threaten, and cool down once: resource="
        .. tostring(afterChosenBite.actors.pet.resource) .. " ready="
        .. tostring(afterChosenBite.actors.pet.actionReadyIn) .. " actor="
        .. tostring(afterChosenBite.actorReadyAt.pet) .. " cooldown="
        .. tostring(afterChosenBite.actors.pet.autocasts[1].readyIn))

local deferredState = XelAssist.Graph.State:Copy(chosenPetState)
deferredState.actors.pet.pendingMeleeEffects = { Intimidation = {
    remaining = 15, targetGuid = "target-guid", threatBase = 100,
    threatLevel = 60, threatPerLevel = 0, stunDuration = 3 } }
local afterDeferred = XelAssist.Graph.Transitions:Advance(
    deferredState, chosenBiteCandidate)
local deferredRecord = afterDeferred.hostiles.byKey["target-guid"]
assert(deferredRecord.projectedThreat.pet == 136
    and deferredRecord.threat.petDelta == 136
    and not afterDeferred.actors.pet.pendingMeleeEffects.Intimidation,
    "chosen pet melee must retain deferred-proc threat like ambient melee")

local tauntState = state("smart")
local tauntRecord = pinCombatHostile(tauntState, 100)
tauntState.hasAggro = true
tauntState.actors.pet = { guid = "pet-guid", health = 100, healthMax = 100,
    resource = 100, resourceMax = 100, targetExists = true,
    targetGuid = "target-guid", targetsCurrent = true, hasAggro = false,
    distance = 3, lineOfSight = true, autocasts = {} }
local uncertainTaunt = petAction("Uncertain Torment", "taunt", 0, 5,
    { melee = true })
local tauntCandidate = causalCandidate(uncertainTaunt, 0, 0.1, 0, 0, 5)
tauntCandidate.targetKey, tauntCandidate.effectDelivery = "target-guid", 0.5
local afterTaunt = XelAssist.Graph.Transitions:Advance(tauntState, tauntCandidate)
tauntRecord = afterTaunt.hostiles.byKey["target-guid"]
assert(afterTaunt.hasAggro and not afterTaunt.actors.pet.hasAggro
    and tauntRecord.threat.tauntDelivery == 0.5
    and tauntRecord.threat.projectedTauntUncertain
    and tauntRecord.threat.petHasAggro == false,
    "a probabilistic pet taunt must preserve live victim evidence")

local chosenDotState = state("smart")
local chosenDotRecord = pinCombatHostile(chosenDotState, 100)
local chosenDot = action("Chosen Poison", 1, "dot", 100, 20,
    { testDuration = 10, testPeriodicInterval = 2 })
local chosenDotCandidate = causalCandidate(chosenDot, 0, 1.5, 0, 100, 20)
chosenDotCandidate.targetKey = "target-guid"
chosenDotCandidate.power = 50
chosenDotCandidate.threat = 50
chosenDotCandidate.dotRawPeriodicPower = 100
chosenDotCandidate.dotPeriodicExpectedPower = 50
chosenDotCandidate.survival = { available = true, periodicFactor = 0.5,
    decisionFactor = 0.5 }
local afterChosenDot = XelAssist.Graph.Transitions:Advance(
    chosenDotState, chosenDotCandidate)
chosenDotRecord = afterChosenDot.hostiles.byKey["target-guid"]
assert(chosenDotRecord.health == 100
    and chosenDotRecord.projectedAuras["Chosen Poison"].periodicRawRate == 5
    and (not chosenDotRecord.projectedThreat
        or not chosenDotRecord.projectedThreat.player),
    "a chosen DoT must retain survival-adjusted periodic evidence without front-loading threat")
local waitAction = action("Threat Clock Wait", 1, "buff", 0, 0,
    { self = true })
local waitCandidate = { action = waitAction, target = "player",
    targetRelation = "self", targetKey = "g:player-guid", cost = 0,
    cast = 0, occupancy = 0.5, wait = 0, downtime = 0.5,
    actionStart = afterChosenDot.time, tooltip = waitAction.mock,
    power = 0, effectDelivery = 1 }
local afterChosenTick = XelAssist.Graph.Transitions:Advance(
    afterChosenDot, waitCandidate)
chosenDotRecord = afterChosenTick.hostiles.byKey["target-guid"]
assert(chosenDotRecord.health == 90
    and chosenDotRecord.projectedThreat.player == 10
    and chosenDotRecord.threat.playerDelta == 10,
    "survival-adjusted DoT threat must accrue from actual health-capped ticks")

local exclusiveClockState = state("smart")
local exclusiveClockRecord = pinCombatHostile(exclusiveClockState, 100)
exclusiveClockRecord.projectedAuras["Own Agony"] = {
    remaining = 10, duration = 10, mine = true, target = "target",
    exclusiveFamily = "warlockCurse", periodicRate = 10,
    periodicInterval = 2, periodicNextIn = 2, applicationProbability = 1 }
exclusiveClockRecord.targetAuras["Own Agony"] = {
    remaining = 10, duration = 10, mine = true,
    exclusiveFamily = "warlockCurse" }
local replacementCurse = action("Own Weakness", 1, "debuff", 0, 0,
    { testDuration = 20, exclusiveFamily = "warlockCurse" })
local replacementCurseCandidate = causalCandidate(
    replacementCurse, 0, 3, 0, 0, 0)
replacementCurseCandidate.targetKey = "target-guid"
local afterExclusiveReplacement = XelAssist.Graph.Transitions:Advance(
    exclusiveClockState, replacementCurseCandidate)
exclusiveClockRecord = afterExclusiveReplacement.hostiles.byKey["target-guid"]
assert(exclusiveClockRecord.health == 100
    and not exclusiveClockRecord.projectedAuras["Own Agony"]
    and exclusiveClockRecord.projectedAuras["Own Weakness"],
    "an exact exclusive-family replacement must invalidate the old periodic clock")

local uncertainClockState = state("smart")
local uncertainClockRecord = pinCombatHostile(uncertainClockState, 100)
uncertainClockRecord.projectedAuras["Own Agony"] = {
    remaining = 10, duration = 10, mine = true, target = "target",
    exclusiveFamily = "warlockCurse", periodicRate = 10,
    periodicInterval = 2, periodicNextIn = 2, applicationProbability = 1 }
local uncertainCurseCandidate = causalCandidate(
    replacementCurse, 0, 3, 0, 0, 0)
uncertainCurseCandidate.targetKey = "target-guid"
uncertainCurseCandidate.effectDelivery = 0.5
local afterUncertainReplacement = XelAssist.Graph.Transitions:Advance(
    uncertainClockState, uncertainCurseCandidate)
uncertainClockRecord = afterUncertainReplacement.hostiles.byKey["target-guid"]
assert(uncertainClockRecord.health == 90
    and uncertainClockRecord.projectedAuras["Own Agony"]
    and uncertainClockRecord.projectedAuras["Own Agony"].applicationProbability == 0.5,
    "an uncertain exclusive-family replacement must retain only the old clock's failure branch")
local uncertainClockWait = { action = waitAction, target = "player",
    targetRelation = "self", targetKey = "g:player-guid", cost = 0,
    cast = 0, occupancy = 2, wait = 0, downtime = 2,
    actionStart = afterUncertainReplacement.time, tooltip = waitAction.mock,
    power = 0, effectDelivery = 1 }
local afterUncertainWait = XelAssist.Graph.Transitions:Advance(
    afterUncertainReplacement, uncertainClockWait)
assert(afterUncertainWait.hostiles.byKey["target-guid"].health == 80,
    "an uncertain exclusive replacement must stay scaled on the next Timeline")

local sameClockState = state("smart")
local sameClockRecord = pinCombatHostile(sameClockState, 100)
sameClockRecord.projectedAuras["Shared Agony"] = {
    remaining = 10, duration = 10, mine = true, target = "target",
    periodicRate = 10, periodicInterval = 2, periodicNextIn = 2,
    periodicThreatActor = "player", periodicThreatMultiplier = 1,
    applicationProbability = 1 }
local sameClockDot = action("Shared Agony", 1, "dot", 100, 0,
    { testDuration = 10, testPeriodicInterval = 2 })
local sameClockCandidate = causalCandidate(sameClockDot, 0, 3, 0, 50, 0)
sameClockCandidate.targetKey, sameClockCandidate.effectDelivery =
    "target-guid", 0.5
sameClockCandidate.dotRawPeriodicPower = 100
sameClockCandidate.dotPeriodicExpectedPower = 50
local afterSameClock = XelAssist.Graph.Transitions:Advance(
    sameClockState, sameClockCandidate)
sameClockRecord = afterSameClock.hostiles.byKey["target-guid"]
assert(sameClockRecord.health == 80
    and sameClockRecord.projectedThreat.player == 20
    and sameClockRecord.threat.playerDelta == 20
    and sameClockRecord.projectedAuras["Shared Agony"]
    and sameClockRecord.projectedAuras["Shared Agony"].applicationProbability == 0.5
    and table.getn(sameClockRecord.projectedAuras["Shared Agony"].periodicBranches) == 1,
    "a resisted same-name refresh must retain the old failure clock beside the new success clock")
local sameClockWait = { action = waitAction, target = "player",
    targetRelation = "self", targetKey = "g:player-guid", cost = 0,
    cast = 0, occupancy = 2, wait = 0, downtime = 2,
    actionStart = afterSameClock.time, tooltip = waitAction.mock,
    power = 0, effectDelivery = 1 }
local carriedFailure = sameClockRecord.projectedAuras["Shared Agony"]
    .periodicBranches[1]
local afterSameClockWait = XelAssist.Graph.Transitions:Advance(
    afterSameClock, sameClockWait)
sameClockRecord = afterSameClockWait.hostiles.byKey["target-guid"]
assert(sameClockRecord.health == 60
    and sameClockRecord.projectedThreat.player == 40
    and sameClockRecord.threat.playerDelta == 40
    and carriedFailure.remaining == 7
    and sameClockRecord.projectedAuras["Shared Agony"]
        .periodicBranches[1].remaining == 5,
    "same-name success and failure clocks must both survive the next Timeline")

local exactSameClockCandidate = causalCandidate(
    sameClockDot, 0, 3, 0, 100, 0)
exactSameClockCandidate.targetKey = "target-guid"
exactSameClockCandidate.dotRawPeriodicPower = 100
exactSameClockCandidate.dotPeriodicExpectedPower = 100
local afterExactSameClock = XelAssist.Graph.Transitions:Advance(
    sameClockState, exactSameClockCandidate)
sameClockRecord = afterExactSameClock.hostiles.byKey["target-guid"]
assert(sameClockRecord.health == 80
    and sameClockRecord.projectedThreat.player == 20
    and sameClockRecord.threat.playerDelta == 20
    and not sameClockRecord.projectedAuras["Shared Agony"].periodicBranches,
    "an exact same-name refresh must cancel the old clock without double ticks")

local shorterRankState = state("smart")
local shorterRankRecord = pinCombatHostile(shorterRankState, 100)
shorterRankRecord.projectedAuras["Ranked Agony"] = {
    remaining = 1, duration = 1, mine = true, target = "target",
    periodicRate = 0, periodicInterval = 2, periodicNextIn = 1,
    applicationProbability = 0.5, periodicBranches = { {
        remaining = 4, duration = 4, mine = true, target = "target",
        periodicRate = 0, periodicInterval = 2, periodicNextIn = 1,
        applicationProbability = 0.5 } } }
local afterShorterRank = XelAssist.Graph.Transitions:Advance(
    shorterRankState, sameClockWait)
shorterRankRecord = afterShorterRank.hostiles.byKey["target-guid"]
assert(shorterRankRecord.projectedAuras["Ranked Agony"].remaining == 2
    and shorterRankRecord.projectedAuras["Ranked Agony"].duration == 4
    and shorterRankState.hostiles.byKey["target-guid"]
        .projectedAuras["Ranked Agony"].remaining == 1,
    "a longer old failure clock must survive a shorter-rank success expiry")

local expiredStackState = state("smart")
local expiredStackRecord = pinCombatHostile(expiredStackState, 100)
expiredStackRecord.targetAuras["Cast Poison"] = {
    remaining = 1, duration = 10, mine = true, stacks = 3 }
local castPoison = action("Cast Poison", 1, "dot", 100, 0,
    { cast = 2, stackable = 5, testDuration = 10,
        testPeriodicInterval = 2 })
local castPoisonCandidate = causalCandidate(castPoison, 0, 2, 2, 100, 0)
castPoisonCandidate.targetKey = "target-guid"
castPoisonCandidate.dotRawPeriodicPower = 100
castPoisonCandidate.dotPeriodicExpectedPower = 100
local afterCastPoison = XelAssist.Graph.Transitions:Advance(
    expiredStackState, castPoisonCandidate)
expiredStackRecord = afterCastPoison.hostiles.byKey["target-guid"]
assert(expiredStackRecord.projectedAuras["Cast Poison"].stacks == 1
    and expiredStackRecord.projectedAuras["Cast Poison"].expectedStacks == 1
    and expiredStackState.hostiles.byKey["target-guid"]
        .targetAuras["Cast Poison"].stacks == 3,
    "a chosen stack refresh must not carry live stacks that expired before impact")

local unknownDotState = state("smart")
local unknownDotRecord = pinCombatHostile(unknownDotState, 50, false)
XelAssistTestUnknownDotCandidate = causalCandidate(chosenDot, 0, 1.5, 0, 100, 20)
XelAssistTestUnknownDotCandidate.targetKey = "target-guid"
XelAssistTestUnknownDotCandidate.threat = 100
XelAssistTestUnknownDotCandidate.dotRawPeriodicPower = 100
XelAssistTestUnknownDotCandidate.dotPeriodicExpectedPower = 100
local afterUnknownDot = XelAssist.Graph.Transitions:Advance(
    unknownDotState, XelAssistTestUnknownDotCandidate)
XelAssistTestUnknownDotCandidate = nil
unknownDotRecord = afterUnknownDot.hostiles.byKey["target-guid"]
assert(unknownDotRecord.projectedThreat.player == 100
    and unknownDotRecord.projectedThreatTimingUnknown,
    "unknown hostile health must preserve uncertain expected DoT threat")

currentState = state("smart")
currentState.targetHealth, currentState.targetMax = 1000, 1000
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    happinessDamageMultiplier = 1,
    autocasts = { { name = "Scorpid Poison", actor = "pet", kind = "dot",
        facts = { kind = "dot", damageActor = "pet", melee = true,
            stackable = 5 }, power = 100, cost = 20, cooldown = 10,
        readyIn = 0, tooltip = { school = 3, duration = 10,
            periodicInterval = 2 } } } }
local dotFiller = action("Pet Dot Filler", 1, "damage", 1, 0)
local afterPetDot = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(dotFiller, 0, 1.5, 0, 1, 0))
assert(afterPetDot.targetHealth == 999
    and afterPetDot.actors.pet.resource == 80
    and afterPetDot.auras["Scorpid Poison"]
    and afterPetDot.auras["Scorpid Poison"].remaining == 8.5
    and afterPetDot.auras["Scorpid Poison"].periodicNextIn == 0.5,
    "an ambient pet DoT must create a timed aura instead of silently spending focus")
local afterPetDotTick = XelAssist.Graph.Transitions:Advance(afterPetDot,
    causalCandidate(dotFiller, 0, 1, 0, 1, 0))
assert(afterPetDotTick.targetHealth == 978
    and afterPetDotTick.auras["Scorpid Poison"].remaining == 7.5,
    "an ambient pet DoT must tick on its exact carried cadence")

local repeatedPetState = state("smart")
repeatedPetState.targetHealth, repeatedPetState.targetMax = 1000, 1000
repeatedPetState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    autocasts = { { name = "Repeated Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 10, cost = 10, cooldown = 1.5, readyIn = 0,
        tooltip = { school = 0 } } } }
local afterRepeatedPet = XelAssist.Graph.Transitions:Advance(repeatedPetState,
    causalCandidate(dotFiller, 0, 5, 0, 1, 0))
assert(afterRepeatedPet.targetHealth == 959
    and afterRepeatedPet.actors.pet.resource == 60
    and math.abs(afterRepeatedPet.actors.pet.autocasts[1].readyIn - 1) < 0.0001,
    "a long action window must carry every affordable pet autocast cooldown")

local observedGrowlState = state("smart")
observedGrowlState.groupSize = 4
observedGrowlState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    autocasts = { { name = "Observed Growl", actor = "pet", kind = "petThreat",
        facts = { kind = "petThreat", petThreatGain = 415 },
        power = 0, cost = 15, cooldown = 5, readyIn = 0,
        tooltip = {} } } }
XelAssistCharDB.petThreat = "avoid"
local afterObservedGrowl = XelAssist.Graph.Transitions:Advance(observedGrowlState,
    causalCandidate(dotFiller, 0, 1.5, 0, 1, 0))
assert(afterObservedGrowl.actors.pet.resource == 85
    and afterObservedGrowl.actors.pet.threatEstimate
    and afterObservedGrowl.actors.pet.threatEstimate.delta == 415,
    "an enabled Growl autocast must remain graph-visible despite recommendation policy")
XelAssistCharDB.petThreat = "auto"

local lethalPetDot = XelAssist.Graph.State:Copy(currentState)
lethalPetDot.targetHealth, lethalPetDot.targetMax = 15, 15
local latePetDotAction = action("Late After Pet Dot", 1, "damage", 100, 30)
local latePetDotCandidate = causalCandidate(
    latePetDotAction, 3, 1, 0, 100, 30)
local petDotProbe = XelAssist.Graph.Timeline:BeforeAction(
    lethalPetDot, latePetDotCandidate)
local afterLethalPetDot = XelAssist.Graph.Transitions:Advance(
    lethalPetDot, latePetDotCandidate)
assert(petDotProbe.defeated and petDotProbe.damageEvents == 1
    and afterLethalPetDot.chosenActionPrevented
    and afterLethalPetDot.resource == lethalPetDot.resource,
    "a lethal pet DoT tick must suppress a later action without spending its resource")

-- A launch, companion attack, and chosen action must share one causal clock.
-- The companion kills after the arrow leaves but before either its impact or
-- the delayed chosen action, so the arrow is spent and the action is not.
currentState = hunterAutoState(30, 0.1, 35)
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    autocasts = { { name = "Causal Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 30, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
local lateStrike = action("Late Strike", 1, "damage", 100, 30)
local petOnlyProbe = XelAssist.Graph.State:Copy(currentState)
petOnlyProbe.autoShot, petOnlyProbe.inventory = nil, nil
petOnlyProbe.actorReadyAt.player = 1
local petOnlyDescriptor = XelAssist.Graph.Targets:Targets(
    lateStrike, petOnlyProbe)[1]
local petSuppressed = XelAssist.Graph.Scoring:Evaluate(
    lateStrike, petOnlyProbe, petOnlyDescriptor)
assert(petSuppressed and petSuppressed.value == -100000
    and petSuppressed.reason == "ambient attack resolves first",
    "an earlier ambient pet kill must suppress a redundant recommendation")
assert(petOnlyProbe.actors.pet.autocasts[1].readyIn == 0.5,
    "the unified scoring probe must not mutate its source pet timeline")
local causalResult = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(lateStrike, 1, 0.5, 0, 100, 30))
assert(causalResult.targetHealth == 0 and causalResult.resource == 1000
    and causalResult.autoShot.ammoCount == 9
    and causalResult.autoShot.launches == 1
    and causalResult.chosenActionPrevented,
    "offset sorting must preserve an earlier launch, then pet kill, then skip the action")

-- Player pet effects are action-impact events too: an instant next-melee
-- trigger must exist before a later ambient pet melee in the same occupancy.
currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetHealth, currentState.targetMax = 100, 100
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    autocasts = { { name = "Triggered Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 1, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
local intimidation = action("Timeline Intimidation", 1, "combatBuff", 0, 0,
    { deferredUntilPetMelee = true, triggerWindow = 15, stunDuration = 3 })
local intimidationResult = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(intimidation, 0, 1.5, 0, 0, 0))
assert(not next(intimidationResult.actors.pet.pendingMeleeEffects or {})
    and intimidationResult.auras["Timeline Intimidation"]
    and math.abs(intimidationResult.auras[
        "Timeline Intimidation"].remaining - 2) < 0.0001,
    "a later pet melee trigger must age its new aura only after that event")

currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetHealth, currentState.targetMax = 100, 100
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    pendingMeleeEffects = {},
    autocasts = { { name = "Missing Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 10, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
XelAssist.Combat.Resistance = {
    Estimate = function()
        return { school = 0, multiplier = 0, landChance = 0,
            uncertaintyMultiplier = 1, source = "forced melee miss" }
    end,
}
local missedIntimidation = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(intimidation, 0, 1.5, 0, 0, 0))
assert(missedIntimidation.actors.pet.pendingMeleeEffects[
        "Timeline Intimidation"]
    and missedIntimidation.actors.pet.pendingMeleeEffects[
        "Timeline Intimidation"].chargeProbability == 1,
    "a missed ambient melee must preserve the Intimidation charge")
XelAssist.Combat.Resistance = nil

currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetHealth, currentState.targetMax = 100, 100
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    happinessDamageMultiplier = 1,
    autocasts = { { name = "Enraged Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 10, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
local bestial = action("Timeline Bestial Wrath", 1, "buff", 0, 0,
    { petCombatBuff = true, petCombatEffects = {
        { key = "damage", duration = 8, damageMultiplier = 1.4 } } })
local bestialResult = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(bestial, 0, 1.5, 0, 0, 0))
assert(math.abs(bestialResult.targetHealth - 86) < 0.0001,
    "an offset-zero pet damage buff must affect a later same-window autocast")

currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetHealth, currentState.targetMax = 100, 100
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    happinessDamageMultiplier = 1,
    combatEffects = { short = { remaining = 1, damageMultiplier = 2 } },
    autocasts = { { name = "Early Buffed Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 10, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
local harmlessBuff = action("Timeline Harmless Buff", 1, "buff", 0, 0)
local existingEffectResult = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(harmlessBuff, 0, 1.5, 0, 0, 0))
assert(existingEffectResult.targetHealth == 80
    and not existingEffectResult.actors.pet.combatEffects.short,
    "pet effects must remain active for earlier events then expire by window end")

currentState = state("smart")
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.targetHealth, currentState.targetMax = 100, 100
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3, lineOfSight = true,
    happinessDamageMultiplier = 1,
    autocasts = { { name = "Short Enraged Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 10, cost = 0, cooldown = 10, readyIn = 0.5,
        tooltip = { school = 0 } } } }
local shortEnrage = action("Timeline Short Enrage", 1, "buff", 0, 0,
    { petCombatBuff = true, petCombatEffects = {
        { key = "damage", duration = 1, damageMultiplier = 2 } } })
local newEffectResult = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(shortEnrage, 0, 1.5, 0, 0, 0))
assert(newEffectResult.targetHealth == 80
    and not next(newEffectResult.actors.pet.combatEffects or {}),
    "new pet effects must start at action impact, affect earlier events, and age once")

local function tickingState(nextTick)
    local value = state("smart")
    value.targetHealth, value.targetMax = 40, 40
    value.auras["Causal Burn"] = { remaining = 10, duration = 10,
        mine = true, target = "target", periodicRate = 25,
        periodicInterval = 2, periodicNextIn = nextTick,
        applicationProbability = 1 }
    return value
end

local timelineStrike = action("Timeline Strike", 1, "damage", 100, 30)
currentState = tickingState(0.5)
currentState.actorReadyAt = { player = 1, pet = 0 }
local tickDescriptor = XelAssist.Graph.Targets:Targets(
    timelineStrike, currentState)[1]
local tickSuppressed = XelAssist.Graph.Scoring:Evaluate(
    timelineStrike, currentState, tickDescriptor)
assert(tickSuppressed and tickSuppressed.value == -100000,
    "an earlier periodic kill must suppress a redundant recommendation")
local tickFirst = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(timelineStrike, 1, 1, 0, 100, 30))
assert(tickFirst.targetHealth == 0 and tickFirst.resource == 1000
    and tickFirst.chosenActionPrevented,
    "a lethal periodic tick before impact must prevent chosen-action spending")
currentState = tickingState(1.5)
local actionFirst = XelAssist.Graph.Transitions:Advance(currentState,
    causalCandidate(timelineStrike, 1, 1, 0, 100, 30))
assert(actionFirst.targetHealth == 0 and actionFirst.resource == 970
    and not actionFirst.chosenActionPrevented,
    "a chosen action before a lethal periodic tick must spend exactly once")

local function ambientState(unknownAmbient, health)
    local value = state("smart")
    value.targetHealth, value.targetMax = health, 120
    value.actorReadyAt = { player = 0, pet = 1 }
    value.actors.pet = { health = 1000, healthMax = 1000,
        resource = 300, resourceMax = 300, targetExists = true,
        targetsCurrent = true, hasAggro = false, distance = 20,
        lineOfSight = true,
        autocasts = { { name = "Ambient Firebolt", actor = "pet", kind = "damage",
            facts = { kind = "damage" }, power = 30, cost = 0,
            cooldown = 10, readyIn = 0.5, tooltip = { school = 2, gcd = 0.1 },
            unknownTest = unknownAmbient } } }
    return value
end

XelAssist.Combat.Resistance = {
    Estimate = function(_, candidate, _, tooltip)
        local unknown = candidate.unknownTest and true or false
        return { school = tooltip.school or 2, schoolName = "Fire", multiplier = 1,
            landChance = 1, source = "ambient modifier test", unknown = unknown }
    end,
    Contrast = function() return nil end,
}
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Ambient Fire Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 10, testDamageTaken = { [2] = 1 } }),
    petAction("Pet Execute", "damage", 1, 0, { testSchool = 2, execute = 50 }),
    petAction("Pet Filler", "damage", 1, 0, { testSchool = 2 }),
}
currentState = ambientState(false, 112)
plan = expect("ambient pet uses new modifier", "Ambient Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Execute",
    "a modifier applied before an ambient pet event must affect that event's damage")
currentState = ambientState(true, 116)
plan = expect("ambient pet uncertainty reserve", "Ambient Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Filler",
    "ambient pet damage must include the same uncertainty reserve as recommended actions")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.actorReadyAt = { player = 0, pet = 1 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 20 }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = {
    [2] = 1, [5] = 1 }, {}
currentState.targetModifierEffects = {
    ["Own Fire Curse"] = { name = "Own Fire Curse", group = "Own Fire Curse",
        exclusiveFamily = "warlockCurse", mine = true,
        damageTaken = { [2] = 1 }, resistanceReduction = {} },
    ["Party Shadow Curse"] = { name = "Party Shadow Curse", group = "Party Shadow Curse",
        exclusiveFamily = "warlockCurse", mine = false,
        damageTaken = { [5] = 1 }, resistanceReduction = {} },
}
currentState.auras = {
    ["Own Fire Curse"] = { remaining = 20, duration = 20, target = "target",
        targetModifier = true, exclusiveFamily = "warlockCurse", mine = true },
    ["Party Shadow Curse"] = { remaining = 20, duration = 20, target = "target",
        targetModifier = true, exclusiveFamily = "warlockCurse", mine = false },
}
currentState.targetAuras = {
    ["Own Fire Curse"] = { remaining = 20, duration = 20, mine = true },
    ["Party Shadow Curse"] = { remaining = 20, duration = 20, mine = false },
}
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Own Weakness Curse", 1, "debuff", 0, 0,
        { testDuration = 20, exclusiveFamily = "warlockCurse" }),
    petAction("Pet Fire", "damage", 100, 0, { testSchool = 2 }),
    petAction("Pet Shadow", "damage", 80, 0, { testSchool = 5 }),
}
plan = expect("exclusive own curse family", "Own Weakness Curse")
assert(plan.follow[1] and plan.follow[1].name == "Pet Shadow",
    "a new own curse must replace the prior own curse without erasing a party member's curse")
XelAssist.Combat.Resistance = nil

currentState = state("smart"); currentState.health = 150; currentState.healthMax = 1000
currentState.friendlies.byKey["g:player-guid"].health = 150
currentState.healHealth = 1000; currentState.healMax = 1000; currentState.inCombat = true
currentState.inventory = { itemCounts = { [13446] = 1 } }
XelAssistCharDB.toggles.consumables = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Shadow Bolt", 1, "damage", 200, 100) }
scenarioItems = { itemAction("Major Healing Potion", "heal", 700) }
plan = expect("effective self consumable", "Major Healing Potion")
assert(plan.target == "player", "a healing consumable must target the player")
assert(plan.follow[1] and plan.follow[1].name ~= "Major Healing Potion",
    "future graph state must put the consumed item on cooldown")
XelAssistCharDB.toggles.consumables = false; XelAssistCharDB.graphDepth = 1
expect("consumable opt-in", "Shadow Bolt")
scenarioItems = {}; XelAssistCharDB.graphDepth = 2

currentState = state("smart")
scenarioActions = { action("Burst", 1, "damage", 600, 40, { testCooldown = 10 }),
    action("Filler", 1, "damage", 250, 20) }
plan = expect("future cooldown", "Burst")
assert(plan.follow[1] and plan.follow[1].name == "Filler", "future action should respect own cooldown")

currentState = state("smart"); currentState.resource = 1000; currentState.resourceMax = 1000
scenarioActions = { action("All In", 1, "damage", 500, 1000),
    action("Sustainable", 1, "damage", 350, 500) }
plan = expect("path lookahead", "Sustainable")
assert(plan.follow[1] and plan.follow[1].name == "Sustainable", "beam should prefer the stronger complete path")

-- The live automatic policy must reason materially farther than the five rows
-- the HUD can show. A long-lived target and sustainable action make the full
-- decision horizon observable without introducing a class priority list.
currentState = state("smart")
currentState.resource, currentState.resourceMax = 1000, 1000
currentState.targetHealth, currentState.targetMax = 100000, 100000
XelAssistCharDB.graphDepth = nil
scenarioActions = { action("Long Run Filler", 1, "damage", 10, 0) }
plan = expect("automatic deep lookahead", "Long Run Filler")
assert(table.getn(plan.path) == 24 and plan.completedDepth == 24
    and plan.decisionHorizon == 24 and plan.timeHorizon == 45,
    "the automatic graph must complete a 24-decision runway when its state remains tractable")
XelAssistCharDB.graphDepth = 2

currentState = state("smart")
scenarioActions = { action("Shared One", 1, "damage", 600, 20,
        { testGroup = 7, testCategoryCooldown = 8 }),
    action("Shared Two", 1, "damage", 500, 20,
        { testGroup = 7, testCategoryCooldown = 8 }),
    action("Free Filler", 1, "damage", 200, 20) }
plan = expect("shared cooldown", "Shared One")
assert(plan.follow[1] and plan.follow[1].name == "Free Filler", "shared cooldown must block sibling actions")

-- Representative class mechanics still flow through the same evaluator.
XelAssistCharDB.graphDepth = 1
currentState = state("smart"); currentState.tank = true; currentState.role = "tank"; currentState.groupSize = 4
scenarioActions = { action("Shield Slam", 1, "damage", 300, 20, { threat = 2 }),
    action("Mortal Strike", 1, "damage", 350, 20, { threat = 1 }) }
expect("warrior tank threat", "Shield Slam")

currentState = state("smart"); currentState.targetCasting = true; currentState.pet = false
scenarioActions = { action("Spell Lock", 1, "interrupt", 0, 0, { pet = true }),
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("warlock missing pet", "Shadow Bolt")

currentState = state("smart"); currentState.pet = false
currentState.actors.pet = nil; currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.petLifecycle = { supported = true, lifecycle = "dead",
    health = 0, healthMax = 1000, focus = 35, focusMax = 100,
    lastKnown = { guid = "dead-pet-guid", family = "Cat" } }
currentState.actors.petLifecycle = currentState.petLifecycle
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Call Pet", 1, "summon", 0, 0, { petLifecycle = "call" }),
    action("Revive Pet", 1, "summon", 0, 0, { petLifecycle = "revive",
        requiresPetState = "dead", fixedTarget = "pet", cast = 10 }),
    action("Mend Pet", 1, "petHeal", 500, 50, { pet = true,
        fixedTarget = "pet", channel = true, cast = 5 }),
}
plan = expect("dead Hunter pet lifecycle", "Revive Pet")
assert(plan.target == "pet" and plan.follow[1]
    and plan.follow[1].name == "Mend Pet",
    "a defeated Hunter pet must remain graph-visible for Revive and later care")

currentState = state("smart"); currentState.pet = false
currentState.actors.pet = nil; currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.petLifecycle = { supported = true, lifecycle = "dismissed",
    lastKnown = { guid = "dismissed-pet-guid", family = "Wolf" } }
currentState.actors.petLifecycle = currentState.petLifecycle
XelAssistCharDB.graphDepth = 1
scenarioActions = {
    action("Call Pet", 1, "summon", 0, 0, { petLifecycle = "call" }),
    action("Revive Pet", 1, "summon", 0, 0, { petLifecycle = "revive",
        fixedTarget = "pet", cast = 10 }),
}
expect("dismissed Hunter pet lifecycle", "Call Pet")

currentState.petLifecycle.lifecycle = "unknown"
local unknownPetPlan = XelAssist.Graph:Evaluate("smart", true)
assert(unknownPetPlan == nil,
    "unexplained Hunter pet absence must not blindly alternate Call and Revive")

currentState = state("smart"); currentState.pet = true
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.actors.pet = { health = 100, healthMax = 1000,
    resource = 50, resourceMax = 100, targetExists = false,
    targetsCurrent = false, hasAggro = false }
currentState.petLifecycle = { supported = true, lifecycle = "alive" }
scenarioActions = { action("Mend Pet", 1, "petHeal", 500, 50,
    { pet = true, fixedTarget = "pet", channel = true, cast = 5 }) }
plan = expect("fixed Hunter Mend recipient", "Mend Pet")
assert(plan.target == "pet" and plan.targetRelation == "pet",
    "Mend Pet must never become a variable party heal")

local graphBestial = action("Bestial Wrath", 1, "buff", 0, 100,
    { pet = true, fixedTarget = "pet", petCombatBuff = true,
        combatBuff = true, testDuration = 18 })
scenarioActions = { graphBestial }
currentState.inCombat = false
local idleBestial = XelAssist.Graph:Evaluate("smart", true)
assert(idleBestial == nil,
    "the graph must not spend Bestial Wrath on an idle out-of-combat pet")
currentState.inCombat = true
currentState.actors.pet.targetExists = true
currentState.actors.pet.targetsCurrent = true
expect("engaged Hunter Bestial Wrath", "Bestial Wrath")

scenarioActions = { action("Feed Pet", 1, "petCare", 0, 0,
    { pet = true, fixedTarget = "pet", itemTarget = true }) }
local feedPlan = XelAssist.Graph:Evaluate("smart", true)
assert(feedPlan == nil, "Feed Pet must hold without a proven compatible configured food")
scenarioActions = { action("Dismiss Pet", 1, "petLifecycle", 0, 0,
    { pet = true, fixedTarget = "pet", petLifecycle = "dismiss" }) }
local dismissPlan = XelAssist.Graph:Evaluate("smart", true)
assert(dismissPlan == nil, "the graph must never autonomously dismiss a Hunter pet")

currentState = state("smart"); currentState.combo = 0
scenarioActions = { action("Eviscerate", 1, "damage", 700, 35, { combo = true }),
    action("Sinister Strike", 1, "builder", 200, 45) }
expect("rogue combo prerequisite", "Sinister Strike")

currentState = state("smart")
XelAssist.Graph.ComboState:Attach(currentState, 2, "other-target",
    { selectedExact = true, globalExact = true, source = "test owner" })
scenarioActions = { action("Target Finisher", 1, "damage", 700, 35,
        { combo = true }),
    action("Target Builder", 1, "builder", 200, 45) }
expect("off-target combo ownership", "Target Builder")

currentState = state("smart")
XelAssist.Graph.ComboState:Attach(currentState, 2, "target-guid",
    { selectedExact = true, globalExact = true, source = "test owner" })
scenarioActions = { action("Duration Finisher", 1, "dot", 180, 25,
    { combo = true, testDuration = 6, testDurationBase = 6,
        testDurationMax = 16, testDurationComboScaled = true,
        testPeriodicInterval = 2 }) }
plan = expect("target-owned combo duration", "Duration Finisher")
assert(plan.tooltip.duration == 10 and plan.tooltip.durationComboPoints == 2,
    "a combo-scaled graph action must use the points owned by its target")

currentState = state("smart"); currentState.combo = 5; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Eviscerate", 1, "damage", 700, 35, { combo = true }),
    action("Sinister Strike", 1, "builder", 100, 45) }
plan = expect("finisher consumes combo", "Eviscerate")
assert(plan.follow[1] and plan.follow[1].name == "Sinister Strike",
    "a finisher must consume combo points in future state")

-- Octo patch-5 R1-shaped facts: the graph must discover the builder/finisher
-- cycle from combo transitions and the DBC per-point curve, not a Rogue list.
currentState = state("smart"); currentState.combo = 1
currentState.resource, currentState.resourceMax = 100, 100
currentState.targetHealth, currentState.targetMax = 1000, 1000
XelAssistCharDB.graphDepth = 2
local dbcFinisher = action("Generic Finisher", 1, "damage", 3.5, 30,
    { combo = true, testComboBonus = 5 })
local dbcBuilder = action("Generic Builder", 1, "builder", 8, 40)
scenarioActions = { dbcFinisher, dbcBuilder }
expect("surviving target retains combo value", "Generic Builder")

currentState.targetHealth, currentState.targetMax = 8.2, 1000
expect("lethal one-point finisher", "Generic Finisher")

currentState.targetHealth, currentState.targetMax = 1000, 1000
currentState.combo = 5
expect("capped combo realizes value", "Generic Finisher")

currentState = state("smart"); currentState.combo = 0
currentState.resource, currentState.resourceMax, currentState.resourceType = 100, 100, 3
currentState.playerResourceClock = { verified = true, resourceType = 3,
    amount = 20, interval = 2.4, phaseKnown = false,
    externalEnergizeExcluded = true }
XelAssistCharDB.graphDepth = 4
scenarioActions = { dbcFinisher, dbcBuilder }
plan = expect("energy-clock combo runway", "Generic Builder")
assert(plan.path[2] and plan.path[2].action.name == "Generic Builder"
    and plan.path[3] and plan.path[3].action.name == "Generic Builder"
    and plan.path[3].actionStart >= 3,
    "a verified tick clock must extend an efficient builder runway through future affordability; got "
        .. tostring(plan.path[2] and plan.path[2].action.name) .. " -> "
        .. tostring(plan.path[3] and plan.path[3].action.name) .. " @ "
        .. tostring(plan.path[3] and plan.path[3].actionStart))

currentState = state("smart")
currentState.resource, currentState.resourceMax, currentState.resourceType = 100, 100, 3
currentState.playerResourceClock = nil
XelAssistCharDB.graphDepth = 4
scenarioActions = { action("Energy Builder", 1, "builder", 20, 45) }
plan = expect("unknown energy continuation", "Energy Builder")
assert(table.getn(plan.path) == 2
    and plan.terminal and plan.terminal.kind == "resource"
    and plan.terminal.current == 10 and plan.terminal.required == 45
    and plan.terminal.resourceName == "Energy"
    and not plan.terminal.timingKnown,
    "a terminal resource edge must be reported separately from graph horizon")
XelAssistTestImpossibleTerminal = XelAssist.Graph.PlanDiagnostics:Terminal({
    resource = 10, resourceMax = 40, resourceType = 3,
    playerResourceReserved = 0,
}, { resource = 1, resourceRequired = 45 })
assert(XelAssistTestImpossibleTerminal
    and XelAssistTestImpossibleTerminal.unreachable,
    "a resource requirement above the character's cap must not be called a wait")
XelAssistTestImpossibleTerminal = nil

currentState = state("smart"); XelAssistCharDB.toggles.reagents = false
scenarioActions = { action("Shadowburn", 1, "damage", 900, 100,
        { reagent = true, reagentName = "Soul Shard", execute = 20 }),
    action("Shadow Bolt", 1, "damage", 300, 100) }
expect("warlock reagent policy", "Shadow Bolt")
XelAssistCharDB.toggles.reagents = true
currentState.targetHealth = 100; currentState.targetMax = 1000
currentState.inventory = { reagentCounts = { ["Soul Shard"] = 0 } }
expect("warlock reagent count", "Shadow Bolt")

currentState = state("smart"); XelAssistCharDB.allowAoe = false
scenarioActions = { action("Blizzard", 1, "damage", 1200, 300, { aoe = true }),
    action("Frostbolt", 1, "damage", 300, 100) }
expect("mage smart area safety", "Frostbolt")

local areaTopology = { available = true, area = true, effects = {
    { index = 1, effect = 2, relation = "hostile", shape = "area",
        center = "caster", radius = 10, radiusKnown = true },
} }
local areaSelected = { key = "target-guid", guid = "target-guid",
    unit = "target", source = "selected", selected = true, executable = true,
    engaged = true, dead = false, health = 1000, healthMax = 1000,
    healthExact = true,
    distance = 3, distanceKind = "test", lineOfSight = true, behind = false,
    geometry = { player = { distance = 3 } }, encounter = { inCombat = true },
    targetRef = { unit = "target", guid = "target-guid",
        relation = "hostile", source = "selected" }, targetAuras = {},
    projectedAuras = {}, modifierEffects = {}, damageTaken = {},
    baseDamageTaken = {}, casting = false, castProbability = 0,
    threat = { playerHasAggro = false, petHasAggro = false } }
local areaOther = { key = "area-other", guid = "area-other",
    unit = "pettarget", source = "companion", selected = false,
    executable = false, engaged = true, dead = false,
    health = 160, healthMax = 500,
    healthExact = true, distance = 5, distanceKind = "test",
    lineOfSight = true, behind = nil,
    geometry = { player = { distance = 5 } }, encounter = { inCombat = true },
    targetRef = { unit = "pettarget", guid = "area-other",
        relation = "hostile", source = "companion" }, targetAuras = {},
    projectedAuras = {}, modifierEffects = {}, damageTaken = {},
    baseDamageTaken = {}, casting = nil, castProbability = nil,
    threat = { playerHasAggro = false, petHasAggro = true } }
currentState = state("aoe")
setHostiles(currentState, { areaSelected, areaOther }, areaSelected.key)
XelAssistCharDB.allowAoe = true
scenarioActions = { action("Arcane Burst", 1, "damage", 100, 50,
    { aoe = true, testTopology = areaTopology }) }
plan = expect("proven multi-hostile area scoring", "Arcane Burst")
assert(plan.totalExpectedPower == 200 and plan.totalEffectivePower == 200
    and table.getn(plan.recipientEffects.order) == 2
    and plan.reason == "hits 2 proven engaged enemies",
    "area value must come from actual recipient-local effects: expected="
        .. tostring(plan.totalExpectedPower) .. " effective="
        .. tostring(plan.totalEffectivePower) .. " recipients="
        .. tostring(plan.recipientEffects and table.getn(
            plan.recipientEffects.order or {}) or 0) .. " reason="
        .. tostring(plan.reason))
local areaAfter = XelAssist.Graph.Transitions:Advance(currentState, plan)
assert(areaAfter.resource == 950
    and areaAfter.hostiles.byKey[areaSelected.key].health == 900
    and areaAfter.hostiles.byKey[areaOther.key].health == 60,
    "one area action must spend resources once and damage each proven recipient: resource="
        .. tostring(areaAfter.resource) .. " selected="
        .. tostring(areaAfter.hostiles.byKey[areaSelected.key].health)
        .. " other=" .. tostring(areaAfter.hostiles.byKey[areaOther.key].health)
        .. " before=" .. tostring(currentState.hostiles.byKey[
            areaSelected.key].health) .. " power=" .. tostring(plan.power)
        .. " recipient=" .. tostring(plan.recipientEffects.byKey[
            areaSelected.key].expectedPower) .. " path="
        .. tostring(table.getn(plan.path or {})))
XelAssistCharDB.allowAoe = false

currentState = state("smart"); currentState.pet = true; currentState.targetCasting = true
currentState.actorReadyAt = { player = 3, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 20 }
scenarioActions = { petAction("Spell Lock", "interrupt", 0, 40, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 600, 100) }
plan = expect("felhunter interrupt", "Spell Lock")
assert(plan.actor == "pet", "the graph must retain the independently acting companion")
assert(plan.downtime < 0.2, "pet interrupt must remain independent of the player's cast/GCD clock")
currentState.actors.pet.targetsCurrent = false
scenarioActions = { petAction("Spell Lock", "interrupt", 0, 40, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 600, 100) }
expect("felhunter hostile target identity", "Shadow Bolt")
currentState.actors.pet.targetsCurrent = true

currentState.targetCasting = false; currentState.actors.pet.resource = 0
scenarioActions = { petAction("Firebolt", "damage", 800, 50, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 250, 100) }
expect("pet resource isolation", "Shadow Bolt")

currentState = state("smart"); currentState.moving = true
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 20,
    lineOfSight = true }
scenarioActions = { petAction("Moving Firebolt", "damage", 800, 50,
        { ranged = true, cast = 2 }),
    action("Moving Wand", 1, "damage", 100, 0) }
plan = expect("player movement does not block pet cast", "Moving Wand")
assert(plan.follow[1] and plan.follow[1].name == "Moving Firebolt"
    and plan.path[2].action.actor == "pet"
    and plan.path[2].actionStart < 0.2,
    "the independent companion cast must remain available after the instant player action")

local unknownCostPet = petAction(
    "Unreadable Bite", "damage", 1000, 0, { melee = true })
unknownCostPet.mock.cost = nil
local knownFreePet = petAction(
    "Free Bite", "damage", 100, 0, { melee = true })
knownFreePet.mock.cost = 0
currentState.moving, currentState.actors.pet.distance = false, 3
scenarioActions = { unknownCostPet, knownFreePet }
expect("unknown chosen pet cost is not free", "Free Bite")

currentState = state("smart")
currentState.resource, currentState.resourceMax = 5000, 5000
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3 }
XelAssistCharDB.graphDepth = 1
scenarioActions = {
    petAction("Focus Heavy Bite", "damage", 100, 35, { melee = true }),
    petAction("Focus Efficient Claw", "damage", 98, 25, { melee = true }),
}
expect("pet focus-normalized damage value", "Focus Efficient Claw")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 50,
    lineOfSight = false }
currentState.actorReadyAt = { player = 0, pet = 3 }
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 100, 20) }
plan = expect("companion attack command", "Pet Attack")
assert(plan.wait < 0.2,
    "a companion command must execute now without inheriting cast or effect geometry")
currentState.actors.pet.targetExists = true; currentState.actors.pet.targetsCurrent = true
currentState.actors.pet.attackActiveKnown = true
currentState.actors.pet.attackActive = false
currentState.actors.pet.attackRound = { projectable = true, phaseKnown = true,
    attackActive = true, nextSwingIn = 1, interval = 2, power = 50 }
plan = expect("inactive companion attack command", "Pet Attack")
local afterPetAttackCommand = XelAssist.Graph.Transitions:Advance(currentState, plan)
assert(afterPetAttackCommand.targetHealth == currentState.targetHealth
    and afterPetAttackCommand.actors.pet.attackActive
    and not afterPetAttackCommand.actors.pet.attackRound.projectable
    and not afterPetAttackCommand.actors.pet.attackRound.phaseKnown,
    "Pet Attack must start engagement without inventing an immediate swing")
currentState.actors.pet.attackActive = true
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } }, action("Shadow Bolt", 1, "damage", 100, 20) }
expect("no duplicate companion attack", "Shadow Bolt")

currentState.actors.pet.health = 100; currentState.actors.pet.targetExists = true
currentState.actors.pet.targetsCurrent = true
scenarioActions = { { name = "Pet Follow", rank = 1, actor = "pet", executor = "petCommand",
        command = "follow", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("endangered companion retreat", "Pet Follow")

currentState.actors.pet.stance = "defensive"
scenarioActions = { { name = "Pet Passive", rank = 1, actor = "pet", executor = "petCommand",
        command = "passive", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("endangered companion stance", "Pet Passive")

currentState.actors.pet.stance = "defensive"
currentState.actors.pet.attackActive = true
currentState.actors.pet.attackActiveKnown = true
currentState.actors.pet.attackRound = { attackActive = true,
    attackActiveKnown = true, projectable = false, phaseKnown = false }
XelAssistCharDB.graphDepth = 6
XelAssistTestRecoveryAttack = { name = "Pet Attack", rank = 1, actor = "pet",
    executor = "petCommand", command = "attack",
    facts = { kind = "command", petCommand = true },
    mock = { cost = 0, cast = 0, gcd = 0 } }
XelAssistTestRecoveryFollow = { name = "Pet Follow", rank = 1, actor = "pet",
    executor = "petCommand", command = "follow",
    facts = { kind = "command", petCommand = true },
    mock = { cost = 0, cast = 0, gcd = 0 } }
XelAssistTestRecoveryPassive = { name = "Pet Passive", rank = 1, actor = "pet",
    executor = "petCommand", command = "passive",
    facts = { kind = "command", petCommand = true },
    mock = { cost = 0, cast = 0, gcd = 0 } }
scenarioActions = { XelAssistTestRecoveryAttack, XelAssistTestRecoveryFollow,
    XelAssistTestRecoveryPassive,
    action("Recovery Shadow Bolt", 1, "damage", 50, 20) }
plan = expect("endangered companion recovery path", "Pet Passive")
for XelAssistTestRecoveryIndex = 1, table.getn(plan.path or {}) do
    assert(plan.path[XelAssistTestRecoveryIndex].action.name ~= "Pet Attack",
        "a recovery path must never retreat and immediately re-engage the pet")
end
assert(plan.follow[1] and plan.follow[1].name == "Pet Follow",
    "the graph should complete the endangered companion retreat once")

currentState.actors.pet.stance = "passive"
currentState.actors.pet.recovering = true
currentState.actors.pet.retreatPassiveIssued = true
currentState.actors.pet.retreatFollowIssued = true
currentState.actors.pet.attackActive = nil
currentState.actors.pet.attackActiveKnown = nil
currentState.actors.pet.attackRound.attackActive = false
currentState.actors.pet.attackRound.attackActiveKnown = true
XelAssistCharDB.graphDepth = 1
expect("acknowledged companion recovery is stable", "Recovery Shadow Bolt")

currentState.actors.pet.retreatPassiveIssued = false
currentState.actors.pet.retreatFollowIssued = false
currentState.actors.pet.stance = "defensive"
currentState.actors.pet.targetExists = true
currentState.actors.pet.channeling = true
currentState.actors.pet.castSpellId = 17767
currentState.actors.pet.ownerClass = "WARLOCK"
expect("active Consume Shadows recovery is preserved", "Recovery Shadow Bolt")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = false, attackActive = true, attackActiveKnown = true,
    distance = 3 }
XelAssistCharDB.graphDepth = 2
scenarioActions = { XelAssistTestRecoveryAttack, XelAssistTestRecoveryFollow,
    action("Retarget filler", 1, "damage", 50, 20) }
plan = expect("healthy companion retargets directly", "Pet Attack")
assert(not (plan.follow[1] and plan.follow[1].name == "Pet Follow"),
    "a healthy off-target companion must not bounce through Follow before Attack")

currentState = state("smart"); currentState.pet = true; currentState.hasAggro = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 3 }
XelAssistCharDB.petThreat = "auto"
scenarioActions = { petAction("Torment", "taunt", 0, 50, { melee = true, threat = 3 }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("solo voidwalker taunt", "Torment")
currentState.groupSize = 4
expect("group taunt avoidance", "Shadow Bolt")

currentState = state("smart"); currentState.pet = true; currentState.hasAggro = true
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 3 }
XelAssistCharDB.petThreat = "auto"
scenarioActions = { petAction("Growl", "petThreat", 0, 10,
        { melee = true, petThreatGain = 415 }),
    action("Low Shot", 1, "damage", 50, 0) }
plan = expect("Hunter Growl relative threat", "Growl")
local afterGrowl = XelAssist.Graph.Transitions:Advance(currentState, plan.path[1])
assert(afterGrowl.hasAggro and not afterGrowl.actors.pet.hasAggro
    and afterGrowl.actors.pet.threatEstimate.delta == 415,
    "Growl must add uncertain relative threat without claiming an aggro transfer")
currentState.groupSize, currentState.hasAggro = 4, false
expect("Hunter Growl group avoidance", "Low Shot")

currentState = state("smart"); currentState.pet = true; currentState.groupSize = 4
currentState.actorReadyAt = { player = 0, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 100, resourceMax = 100, targetExists = true,
    targetsCurrent = true, hasAggro = true, distance = 3 }
scenarioActions = { petAction("Cower", "petThreat", 0, 15,
    { self = true, petThreatDrop = 225 }) }
plan = expect("Hunter Cower relative threat", "Cower")
local afterCower = XelAssist.Graph.Transitions:Advance(currentState, plan.path[1])
assert(afterCower.hasAggro == currentState.hasAggro
    and afterCower.actors.pet.hasAggro
    and afterCower.actors.pet.threatEstimate.delta == -225,
    "Cower must reduce only the pet estimate and preserve live victim facts")
XelAssistCharDB.petThreat = "tank"
local tankCower = XelAssist.Graph:Evaluate("smart", true)
assert(tankCower == nil, "Cower must be blocked while the companion is the tank")
XelAssistCharDB.petThreat = "auto"

currentState = state("smart"); currentState.playerBehindTarget = false
scenarioActions = { action("Backstab", 1, "builder", 900, 60, { behind = true }),
    action("Sinister Strike", 1, "builder", 200, 45) }
expect("positional prerequisite", "Sinister Strike")

currentState = state("smart"); currentState.targetDistance = 5
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 40 }
scenarioActions = { petAction("Firebolt", "damage", 800, 20,
        { ranged = true, testMaxRange = 30 }), action("Shadow Bolt", 1, "damage", 200, 20) }
expect("independent pet range far", "Shadow Bolt")
currentState.targetDistance = 40; currentState.actors.pet.distance = 5
scenarioActions = { petAction("Firebolt", "damage", 800, 20, { ranged = true, testMaxRange = 30 }) }
expect("independent pet range near", "Firebolt")

currentState = state("support"); currentState.health = 1000; currentState.healthMax = 1000
currentState.hasAggro = true
scenarioActions = { action("Power Word: Shield", 1, "absorb", 500, 100, { self = true }) }
plan = expect("absorb is not healing", "Power Word: Shield")
assert(plan.observed.health == 1000, "observed health remains unchanged by a projected absorb")

currentState = state("smart"); currentState.pet = true; currentState.health = 300
currentState.actors.pet = { health = 900, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = true, distance = 3 }
XelAssistCharDB.graphDepth = 2
scenarioActions = { petAction("Sacrifice", "absorb", 700, 0, { petSacrifice = true }),
    action("Summon Voidwalker", 1, "summon", 0, 200,
        { summonRole = "tank", summonFamily = "Voidwalker", reagent = true, reagentName = "Soul Shard" }) }
plan = expect("voidwalker sacrifice", "Sacrifice")
assert(plan.target == "player", "Sacrifice must shield the player, not the demon")
assert(plan.follow[1] and plan.follow[1].name == "Summon Voidwalker",
    "the projected graph must remove the sacrificed demon before considering a replacement")

currentState = state("smart"); currentState.pet = false; currentState.actors.pet = nil
currentState.inCombat = false; XelAssistCharDB.graphDepth = 1
reagentAvailable = false
scenarioActions = { action("Summon Voidwalker", 1, "summon", 0, 200,
    { summonRole = "tank", summonFamily = "Voidwalker", reagent = true, reagentName = "Soul Shard" }) }
local noShard = XelAssist.Graph:Evaluate("smart", true)
assert(noShard == nil, "a shard-costing demon must not be recommended without a Soul Shard")
reagentAvailable = true
expect("missing solo companion", "Summon Voidwalker")

currentState = state("smart"); currentState.pet = true; currentState.inCombat = true
currentState.actors.pet = { health = 100, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 3 }
scenarioActions = { petAction("Consume Shadows", "petHeal", 700, 0,
        { channel = true, outOfCombat = true }), action("Shadow Bolt", 1, "damage", 200, 20) }
expect("consume shadows combat gate", "Shadow Bolt")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 20 }
dispelTarget = nil
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("devour requires magic aura", "Shadow Bolt")
dispelTarget = "target"
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }) }
expect("felhunter devour", "Devour Magic")
dispelTarget = "party1"
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("pet friendly target safety", "Shadow Bolt")
dispelTarget = "player"
expect("pet owner target safety", "Shadow Bolt")

currentState = state("smart")
setFriendlies(currentState, {
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { petAction("Fire Shield", "buff", 0, 60, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("pet off-target buff safety", "Shadow Bolt")

currentState = state("smart"); currentState.hostile = false
currentState.targetGUID = "selected-ally"
currentState.targetRef = { unit = "target", guid = "selected-ally",
    relation = "ally", source = "selected" }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = false,
    targetsCurrent = false, hasAggro = false, distance = 20,
    distanceKind = "hitbox", lineOfSight = true }
setFriendlies(currentState, {
    friendly("target", "selected-ally", 1000, 1000, 20),
    friendly("player", "player-guid", 1000, 1000, 0),
})
scenarioActions = { petAction("Fire Shield", "buff", 0, 60,
    { ranged = true }) }
plan = expect("pet selected-friendly recipient", "Fire Shield")
assert(plan.target == "target" and plan.targetGUID == "selected-ally",
    "stock CastPetAction may serve only the captured selected friendly")

currentState = state("buff")
local nextBuffTarget = friendly("party4", "ally-next", 1000, 1000, 20)
currentState.friendlies.byKey[nextBuffTarget.key] = nextBuffTarget
currentState.friendlies.byUnit.party4 = nextBuffTarget.key
currentState.friendlies.byAction = {
    ["Arcane Intellect"] = { nextBuffTarget.key },
}
scenarioActions = { action("Arcane Intellect", 1, "buff", 0, 60) }
plan = expect("action-specific group buff target", "Arcane Intellect")
assert(plan.target == "party4",
    "a missing buff outside the urgent-healing cap must remain reachable")

currentState = state("smart")
scenarioActions = {
    action("Unique Instant", 1, "damage", 30, 5),
    action("Unique Cast", 1, "damage", 40, 5, { cast = 1 }),
}
XelAssistCharDB.graphDepth = 1
expect("unique actions bypass causal memo allocation", "Unique Instant")
assert(currentState.xelTimelineProbeCache == nil,
    "an evaluation without a repeated actor/name must not allocate a causal memo")

-- An exact health forecast with no possible ambient damage does not need a
-- graph-state copy. Every modeled ambient damage lane retains the full probe.
XelAssistTestProbeSource = state("smart")
XelAssistTestProbeCandidate = { action = action(
        "Exact Probe", 1, "damage", 10, 0),
    tooltip = {}, target = "target", targetRelation = "hostile",
    targetGUID = XelAssistTestProbeSource.targetGUID,
    wait = 0, cast = 1, occupancy = 1.5, downtime = 1.5,
    advanceDowntime = 1.5, effectDelivery = 1 }
XelAssistTestStateCopy = XelAssist.Graph.State.Copy
XelAssistTestCopyCalls = 0
XelAssist.Graph.State.Copy = function(owner, source)
    XelAssistTestCopyCalls = XelAssistTestCopyCalls + 1
    return XelAssistTestStateCopy(owner, source)
end
XelAssistTestFastProbe = XelAssist.Graph.Timeline:BeforeScoredAction(
    XelAssistTestProbeSource, XelAssistTestProbeCandidate)
assert(XelAssistTestCopyCalls == 0,
    "a proven zero-ambient health forecast must avoid the deep state copy")
XelAssistTestFullProbe = XelAssist.Graph.Timeline:BeforeAction(
    XelAssistTestProbeSource, XelAssistTestProbeCandidate)
assert(XelAssistTestCopyCalls == 1
    and XelAssistTestFastProbe.targetHealth == XelAssistTestFullProbe.targetHealth
    and XelAssistTestFastProbe.defeated == XelAssistTestFullProbe.defeated,
    "the zero-ambient fast forecast must equal the established full timeline")
XelAssistTestProbeSource.auras["Exact Periodic"] = {
    remaining = 0.5, periodicRate = 20, target = "target" }
XelAssistTestPeriodicProbe = XelAssist.Graph.Timeline:BeforeScoredAction(
    XelAssistTestProbeSource, XelAssistTestProbeCandidate)
assert(XelAssistTestCopyCalls > 1
    and XelAssistTestPeriodicProbe.targetHealth == 990
    and XelAssistTestPeriodicProbe.damageEvents == 1,
    "periodic target damage must retain its exact full causal probe")
XelAssistTestProbeSource.auras = {}
XelAssistTestGuardProbe = function()
    local before = XelAssistTestCopyCalls
    XelAssist.Graph.Timeline:BeforeScoredAction(
        XelAssistTestProbeSource, XelAssistTestProbeCandidate)
    return XelAssistTestCopyCalls > before
end
XelAssistTestProbeSource.wand = { active = true, nextShotIn = 2, speed = 2 }
assert(XelAssistTestGuardProbe(), "active wand clocks must keep the full probe")
XelAssistTestProbeSource.wand = nil
XelAssistTestProbeSource.autoShot = { supported = false, active = false }
local copiesBeforeUnsupportedAuto = XelAssistTestCopyCalls
XelAssist.Graph.Timeline:BeforeScoredAction(
    XelAssistTestProbeSource, XelAssistTestProbeCandidate)
assert(XelAssistTestCopyCalls == copiesBeforeUnsupportedAuto,
    "an unsupported inactive Auto Shot snapshot must not block the exact fast path")
XelAssistTestProbeSource.autoShot = { supported = true, active = false,
    inFlight = { { targetGuid = XelAssistTestProbeSource.targetGUID,
        remaining = 0.5, power = 10 } } }
assert(XelAssistTestGuardProbe(), "an in-flight Auto Shot must keep the full probe")
XelAssistTestProbeSource.autoShot = nil
XelAssistTestProbeSource.playerAttack = { active = true,
    attackRound = { projectable = true, targetGuid = "prior-target" } }
assert(XelAssistTestGuardProbe(), "projectable player swings must keep the full probe")
XelAssistTestProbeSource.playerAttack = nil
XelAssistTestProbeSource.actors.pet = {
    targetExists = true, targetsCurrent = false }
assert(XelAssistTestGuardProbe(), "targeted pet events must keep the full probe")
XelAssistTestProbeSource.actors.pet = nil
XelAssistTestProbeSource.hostileCasts = {
    order = { "zero-cast" }, byCaster = {} }
assert(XelAssistTestGuardProbe(), "hostile cast ledgers must keep the full probe")
XelAssistTestProbeSource.hostileCasts = nil
XelAssistTestProbeSource.targetCasting = true
assert(XelAssistTestGuardProbe(), "legacy hostile casts must keep the full probe")
XelAssist.Graph.State.Copy = XelAssistTestStateCopy
XelAssistTestProbeSource, XelAssistTestProbeCandidate = nil, nil
XelAssistTestFastProbe, XelAssistTestFullProbe = nil, nil
XelAssistTestPeriodicProbe, XelAssistTestStateCopy = nil, nil
XelAssistTestCopyCalls, XelAssistTestGuardProbe = nil, nil

-- Equivalent player-spell ranks must share one pre-application forecast without
-- hiding an exact ambient companion hit that changes lethal damage at impact.
currentState = state("smart")
currentState.targetHealth, currentState.targetMax = 70, 70
currentState.actors.pet = { health = 100, healthMax = 100,
    resource = 100, resourceMax = 100, targetExists = true,
    targetGuid = currentState.targetGUID, targetsCurrent = true,
    hasAggro = false, distance = 3, lineOfSight = true,
    autocasts = { { name = "Causal Bite", actor = "pet", kind = "damage",
        facts = { kind = "damage", damageActor = "pet", melee = true },
        power = 30, cost = 0, cooldown = 10, readyIn = 0.25,
        tooltip = { school = 0 } } } }
scenarioActions = {
    action("Causal Bolt", 1, "damage", 35, 5, { cast = 1 }),
    action("Causal Bolt", 2, "damage", 48, 8, { cast = 1 }),
}
XelAssistCharDB.graphDepth = 1
XelAssistTestProbeBegin = XelAssist.Graph.Timeline.BeginEvaluation
XelAssistTestStateCopy = XelAssist.Graph.State.Copy
XelAssistTestCopyCalls = 0
XelAssist.Graph.State.Copy = function(owner, source)
    XelAssistTestCopyCalls = XelAssistTestCopyCalls + 1
    return XelAssistTestStateCopy(owner, source)
end
XelAssist.Graph.Timeline.BeginEvaluation = function(_, source)
    source.xelTimelineProbeCache, source.xelTimelineProbeState = nil, nil
end
XelAssistTestUncachedPlan = expect(
    "uncached causal rank forecast", "Causal Bolt")
XelAssistTestUncachedCopies = XelAssistTestCopyCalls
XelAssist.Graph.Timeline.BeginEvaluation = XelAssistTestProbeBegin
XelAssistTestCopyCalls = 0
plan = expect("cached causal rank forecast", "Causal Bolt")
XelAssistTestCachedCopies = XelAssistTestCopyCalls
XelAssist.Graph.State.Copy = XelAssistTestStateCopy
assert(plan.action.rank == 2 and plan.reason == "finishes the target"
    and XelAssistTestUncachedPlan.action.rank == plan.action.rank
    and XelAssistTestUncachedPlan.reason == plan.reason
    and XelAssistTestUncachedPlan.value == plan.value
    and XelAssistTestUncachedCopies == 3
    and XelAssistTestCachedCopies == 2
    and currentState.xelTimelineProbeCache.hits == 1
    and currentState.xelTimelineProbeCache.misses == 1,
    "rank memoization must preserve exact ambient lethal-health semantics while removing one deep copy")
XelAssistTestProbeBegin, XelAssistTestStateCopy = nil, nil
XelAssistTestCopyCalls, XelAssistTestUncachedCopies = nil, nil
XelAssistTestCachedCopies, XelAssistTestUncachedPlan = nil, nil

-- GetTime is frame-cached in the real client. The intra-frame profiler must
-- still stop a rank-heavy synchronous search while preserving the complete
-- root and one useful continuation.
currentState = state("smart")
scenarioActions = {}
XelAssistTestBudgetRank = 1
while XelAssistTestBudgetRank <= 48 do
    table.insert(scenarioActions,
        action("Warlock Bolt", XelAssistTestBudgetRank, "damage",
            XelAssistTestBudgetRank, 5))
    XelAssistTestBudgetRank = XelAssistTestBudgetRank + 1
end
table.insert(scenarioActions,
    action("Sinister Strike", 1, "builder", 200, 45))
XelAssistCharDB.graphDepth = 3
XelAssist.Graph.Snapshot = function() return currentState end
GetTime = function() return 100 end
XelAssistTestProfileClock = 100000
debugprofilestop = function()
    XelAssistTestProfileClock = XelAssistTestProfileClock + 9.1
    return XelAssistTestProfileClock
end
XelAssistTestProbeBegin = XelAssist.Graph.Timeline.BeginEvaluation
XelAssistTestStateCopy = XelAssist.Graph.State.Copy
XelAssistTestCopyCalls = 0
XelAssist.Graph.State.Copy = function(owner, source)
    XelAssistTestCopyCalls = XelAssistTestCopyCalls + 1
    return XelAssistTestStateCopy(owner, source)
end
XelAssist.Graph.Timeline.BeginEvaluation = function(_, source)
    source.xelTimelineProbeCache, source.xelTimelineProbeState = nil, nil
end
XelAssistTestUncachedPlan = expect(
    "uncached soft graph budget preserves immediate action", "Sinister Strike")
XelAssistTestUncachedCopies = XelAssistTestCopyCalls
XelAssist.Graph.Timeline.BeginEvaluation = XelAssistTestProbeBegin
XelAssistTestProfileClock, XelAssistTestCopyCalls = 100000, 0
plan = expect("soft graph budget preserves immediate action", "Sinister Strike")
XelAssistTestCachedCopies = XelAssistTestCopyCalls
XelAssist.Graph.State.Copy = XelAssistTestStateCopy
assert(plan.budgetLimited == true and table.getn(plan.path) == 2
    and plan.completedDepth == 2 and plan.expanded <= 98,
    "a frozen frame clock must still cap the rank-heavy graph after one continuation")
assert(XelAssistTestUncachedPlan.action.name == plan.action.name
    and XelAssistTestUncachedPlan.action.rank == plan.action.rank
    and XelAssistTestUncachedPlan.value == plan.value
    and XelAssistTestUncachedPlan.follow[1].name == plan.follow[1].name
    and XelAssistTestUncachedPlan.follow[1].rank == plan.follow[1].rank
    and XelAssistTestUncachedPlan.expanded == plan.expanded
    and XelAssistTestUncachedPlan.completedDepth == plan.completedDepth
    and currentState.xelTimelineProbeCache.hits == 94
    and currentState.xelTimelineProbeCache.misses == 2
    and currentState.xelTimelineProbeCache.bypasses == 2,
    "zero-ambient rank scoring must preserve the selected plan and memo accounting")
XelAssistTestProbeBegin, XelAssistTestStateCopy = nil, nil
XelAssistTestCopyCalls, XelAssistTestUncachedCopies = nil, nil
XelAssistTestCachedCopies, XelAssistTestUncachedPlan = nil, nil

print("ok: rank, aggro, interrupt, movement, range, aura, cooldown and beam scenarios")
