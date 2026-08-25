XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Combat/Knowledge.lua")
dofile("Combat/TriggeredActions.lua")
dofile("Combat/AutoShotRange.lua")
dofile("Combat/AutoShotFlights.lua")
dofile("Combat/AutoShot.lua")
dofile("Combat/AutoShotProjection.lua")
dofile("Combat/PetKnowledge.lua")
dofile("Game/SpellTiming.lua")
dofile("Game/SpellClassification.lua")
dofile("Game/Capabilities.lua")
dofile("Game/PlayerAttack.lua")
dofile("Game/Pets/Resources.lua")
dofile("Game/Pets/Actions.lua")
dofile("Game/Pets/Effects.lua")
dofile("Game/Actors.lua")
dofile("Game/Friendlies.lua")
dofile("Combat/TargetModifiers.lua")
dofile("Graph/HostileState.lua")
dofile("Graph/State.lua")
dofile("Graph/CompanionTargets.lua")
dofile("Graph/TargetSelection.lua")
dofile("Graph/CompanionThreat.lua")
dofile("Graph/CompanionEventThreat.lua")
dofile("Graph/ActionAdmission.lua")
dofile("Graph/Targets.lua")
dofile("Graph/Effects.lua")
dofile("Graph/AreaRecipients.lua")
dofile("Graph/HostileEffects.lua")
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
dofile("Graph/ActorScoring.lua")
dofile("Graph/ThreatScoring.lua")
dofile("Graph/OngoingEffects.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/ActionEffects.lua")
dofile("Graph/Timeline.lua")
dofile("Graph/Scoring.lua")
dofile("Graph/Transitions.lua")
dofile("Graph/Engine.lua")

local pendingAura
XelAssist.IsAuraPending = function(_, name) return pendingAura == name end
XelAssist.Combat.Observations = {
    Blocker = function() return nil end,
    ResistanceMultiplier = function(_, _, target, tooltip, s)
        local raw = target == "target" and s.targetResistances
            and tooltip.school and s.targetResistances[tooltip.school + 1]
        if raw and s.playerLevel then
            local ratio = math.min(1, raw / (math.max(20, s.playerLevel) * 5))
            local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
            return 1 - mitigation, "live resistance"
        end
        return 1
    end
}
XelAssist.Combat.Resistance = nil
local scenarioItems = {}
XelAssist.Game.Inventory = {
    Actions = function() return scenarioItems end,
    Blocker = function() return nil end,
    Cooldown = function() return 0 end
}
XelAssistCharDB = { toggles = { cooldowns = true, reagents = true, petActions = true, petControl = false },
    graphDepth = 1, role = "damage", allowAoe = false }
GetTime = function() return 0 end

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
        actors = actors, friendlies = friendlies,
        auras = {}, readyAt = {}, time = 0 }
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
            directDamage = facts.testDirectDamage, periodicDamage = facts.testPeriodicDamage,
            targetArmorReduction = facts.testArmorReduction,
            targetArmorPerCombo = facts.testArmorPerCombo,
            targetResistanceReduction = facts.testResistanceReduction,
            targetDamageTaken = facts.testDamageTaken,
            topology = facts.testTopology } }
end

local function petAction(name, kind, power, cost, extra)
    local value = action(name, 1, kind, power, cost, extra)
    value.actor = "pet"; value.executor = "petAbility"; value.actionSlot = 4
    value.facts.petAbility = true
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
    "the current victim's shield must not globally block shielding another ally")

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
scenarioActions = { action("Out There", 1, "damage", 900, 0) }
local missing = XelAssist.Graph:Evaluate("smart", true)
assert(missing == nil, "out-of-range action must not be recommended")
XelAssist.Graph.testRangeBlocked = false

currentState = state("smart"); currentState.distance = 4; XelAssist.Graph.testRangeUnknown = true
scenarioActions = { action("Dead Zone Shot", 1, "damage", 900, 0,
    { testMinRange = 8, testMaxRange = 35 }) }
local tooClose, tooCloseReason = XelAssist.Graph:Evaluate("smart", true)
assert(tooClose == nil and tooCloseReason == "Move farther away", "minimum range must block too-close actions")
currentState.distance = 40
local tooFar, tooFarReason = XelAssist.Graph:Evaluate("smart", true)
assert(tooFar == nil and tooFarReason == "Move into range", "maximum range must block too-far actions")
XelAssist.Graph.testRangeUnknown = false

currentState = state("smart"); XelAssistCharDB.toggles.cooldowns = false
scenarioActions = { action("Unknown Long Cooldown", 1, "damage", 2000, 0, { testCooldown = 60 }),
    action("Normal Filler", 1, "damage", 200, 0) }
expect("live major cooldown policy", "Normal Filler")
XelAssistCharDB.toggles.cooldowns = true

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Burn", 1, "dot", 500, 40), action("Bolt", 1, "damage", 200, 20) }
plan = expect("future aura state", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Bolt", "future action should respect the applied aura")

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
    "active periodic damage must change later health-gated graph actions")

currentState = state("smart"); currentState.targetHealth = 1000
currentState.targetMax = 1000; XelAssistCharDB.graphDepth = 1
scenarioActions = { action("Cadenced Burn", 1, "dot", 120, 20,
    { testDuration = 6, testPeriodicInterval = 2 }) }
plan = expect("DBC periodic cadence propagation", "Cadenced Burn")
local cadenced = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(cadenced.targetHealth == 1000
    and cadenced.auras["Cadenced Burn"].periodicInterval == 2
    and math.abs(cadenced.auras["Cadenced Burn"].periodicNextIn - 0.5) < 0.0001,
    "a projected DoT must retain cadence without inventing a partial tick")
local cadenceWaitAction = action("Cadence Wait", 1, "buff", 0, 0)
local cadenceWait = { action = cadenceWaitAction, target = "target",
    targetGUID = currentState.targetGUID, targetRelation = "hostile",
    cost = 0, cast = 0, occupancy = 1, wait = 0, downtime = 1,
    actionStart = cadenced.time, tooltip = cadenceWaitAction.mock,
    power = 0, effectDelivery = 1 }
local afterCadenceTick = XelAssist.Graph.Transitions:Advance(
    cadenced, cadenceWait)
assert(afterCadenceTick.targetHealth == 960
    and math.abs(afterCadenceTick.auras["Cadenced Burn"].periodicNextIn - 1.5)
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
assert(afterAutoFiller.autoShot.ammoCount == 8
    and afterAutoFiller.targetHealth == 899
    and table.getn(afterAutoFiller.autoShot.inFlight) == 1,
    "launches must spend arrows immediately while projectile damage lands on its own timeline")

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
plan = expect("action after armed channel", "Low Filler")
assert(plan.wait > 2.9,
    "ordinary Hunter actions must still wait for the armed channel to finish")
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

currentState.autoShot.active = true
currentState.autoShot.activeSource = "action bar repeat"
currentState.autoShot.nextLaunchIn = 2
XelAssistCharDB.graphDepth = 1
plan = expect("Auto Shot active repeat guard", "Low Filler")
assert(plan.action.name ~= "Auto Shot",
    "an active repeat must never re-enter the candidate graph as a toggle press")

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
        melee = true, whiteAttack = true, cast = 0 })
meleeStart.mock.gcd = 0
local meleeFiller = action("Melee Filler", 1, "damage", 1, 0)
meleeFiller.mock.gcd = 2.5
scenarioActions = { meleeStart, meleeFiller }
XelAssistCharDB.graphDepth = 2
plan = expect("player Attack ambient start", "Attack")
assert(plan.power == 0 and plan.path[1].rawPower == 0 and plan.threat == 0
    and plan.follow[1] and plan.follow[1].name == "Melee Filler",
    "Attack must be a zero-packet setup followed by an ordinary action")
local afterMeleeStart = XelAssist.Graph.Transitions:Advance(
    currentState, plan.path[1])
assert(afterMeleeStart.targetHealth == currentState.targetHealth
    and afterMeleeStart.playerAttack.active
    and afterMeleeStart.playerAttack.activeKnown
    and not afterMeleeStart.playerAttack.pending,
    "starting player Attack must not invent immediate damage or a swing")
currentState.playerAttack.active = true
XelAssistCharDB.graphDepth = 1
plan = expect("player Attack active repeat guard", "Melee Filler")
assert(plan.action.name ~= "Attack",
    "an active player Attack must never re-enter the graph as a toggle press")
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
UnitDistanceSquared = function() return 400 end
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
assert(afterReactive.readyAt["player:Reactive Lock"] == 60,
    "a reactive lockout must share the successful-application timestamp")

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
chosenDotCandidate.threat = 100
chosenDotCandidate.dotRawPeriodicPower = 100
chosenDotCandidate.dotPeriodicExpectedPower = 100
local afterChosenDot = XelAssist.Graph.Transitions:Advance(
    chosenDotState, chosenDotCandidate)
chosenDotRecord = afterChosenDot.hostiles.byKey["target-guid"]
assert(chosenDotRecord.health == 100
    and (not chosenDotRecord.projectedThreat
        or not chosenDotRecord.projectedThreat.player),
    "a chosen DoT must not front-load threat before its first tick")
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
assert(chosenDotRecord.health == 80
    and chosenDotRecord.projectedThreat.player == 20
    and chosenDotRecord.threat.playerDelta == 20,
    "chosen DoT threat must accrue from actual health-capped ticks")

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
local afterUnknownDot = XelAssist.Graph.Transitions:Advance(
    unknownDotState, chosenDotCandidate)
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

currentState = state("smart"); currentState.combo = 5; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Eviscerate", 1, "damage", 700, 35, { combo = true }),
    action("Sinister Strike", 1, "builder", 100, 45) }
plan = expect("finisher consumes combo", "Eviscerate")
assert(plan.follow[1] and plan.follow[1].name == "Sinister Strike",
    "a finisher must consume combo points in future state")

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
expect("player movement does not block pet cast", "Moving Firebolt")

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
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 5 }
currentState.actorReadyAt = { player = 0, pet = 3 }
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 100, 20) }
plan = expect("companion attack command", "Pet Attack")
assert(plan.wait < 0.2,
    "a companion command must execute now rather than inherit the pet cast clock")
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

print("ok: rank, aggro, interrupt, movement, range, aura, cooldown and beam scenarios")
