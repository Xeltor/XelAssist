table.getn = table.getn or function(t) return #t end
dofile("XelAssist_Actions.lua")
dofile("XelAssist_Capabilities.lua")
dofile("XelAssist_Actors.lua")
dofile("XelAssist_Graph.lua")

XelAssist = {}
local pendingAura
XelAssist.IsAuraPending = function(_, name) return pendingAura == name end
XelAssistObservations = {
    Blocker = function() return nil end,
    ResistanceMultiplier = function(_, _, target, tooltip, s)
        local raw = target == "target" and s.targetResistances
            and tooltip.school and s.targetResistances[tooltip.school + 1]
        if raw and s.playerLevel then return 1 - math.min(0.75, raw / (s.playerLevel * 5)), "live resistance" end
        return 1
    end
}
local scenarioItems = {}
XelAssistInventory = {
    Actions = function() return scenarioItems end,
    Blocker = function() return nil end,
    Cooldown = function() return 0 end
}
XelAssistCharDB = { toggles = { cooldowns = true, reagents = true, petActions = true, petControl = false },
    graphDepth = 1, role = "damage", allowAoe = false }
GetTime = function() return 0 end

local scenarioActions = {}
XelAssistCapabilities.Actions = function() return scenarioActions end
XelAssistActors.Actions = function() return scenarioActions end
XelAssistCapabilities.Facts = function(_, action) return action.mock end
XelAssistActors.Facts = function(_, action) return action.mock end
XelAssistActors.PetCooldown = function() return 0 end
local reagentAvailable = true
XelAssistActors.HasReagent = function() return reagentAvailable end
local dispelTarget
XelAssistActors.DispelTarget = function() return dispelTarget end
XelAssistCapabilities.IsReady = function() return true end
XelAssistCapabilities.InRange = function(_, _, unit)
    if unit == "target" and XelAssistGraph.testRangeBlocked then return false end
    if XelAssistGraph.testRangeUnknown then return nil end
    return true
end
XelAssistCapabilities.TargetHasDebuff = function() return false end
XelAssistCapabilities.UnitHasBuff = function() return false end
XelAssistCapabilities.WeaponDamage = function() return nil end
XelAssistCapabilities.RangedDamage = function() return nil end
XelAssistCapabilities.BonusDamage = function() return 0 end

local function state(mode)
    local actors = { player = { resource = 1000, resourceMax = 1000 } }
    return { mode = mode or "smart", hostile = true, healUnit = "party1",
        health = 1000, healthMax = 1000, healHealth = 500, healMax = 1000,
        targetHealth = 1000, targetMax = 1000, targetHealthExact = true,
        resource = 1000, resourceMax = 1000,
        combo = 5, moving = false, pet = true, targetCasting = false,
        playerCasting = false, castRemaining = 0, groupSize = 0, hasAggro = false,
        tank = false, role = "auto", instantNext = false, distance = nil, actors = actors,
        auras = {}, readyAt = {}, time = 0 }
end

local currentState
XelAssistGraph.Snapshot = function() return currentState end

local function action(name, rank, kind, power, cost, extra)
    local facts = { kind = kind }
    if extra then for key, value in pairs(extra) do facts[key] = value end end
    return { name = name, rank = rank, rankText = "Rank " .. rank, slot = rank,
        facts = facts, mock = { average = power, cost = cost or 0,
            cast = facts.cast or 0, cooldown = facts.testCooldown,
            cooldownGroup = facts.testGroup, categoryCooldown = facts.testCategoryCooldown,
            minRange = facts.testMinRange, maxRange = facts.testMaxRange, school = facts.testSchool,
            duration = facts.testDuration } }
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
    local plan, err = XelAssistGraph:Evaluate(currentState.mode, true)
    assert(plan, name .. ": " .. tostring(err))
    assert(plan.action.name == wanted, name .. ": got " .. plan.action.name .. ", wanted " .. wanted)
    return plan
end

currentState = state("support"); currentState.healHealth = 880
scenarioActions = { action("Heal", 1, "heal", 100, 20), action("Heal", 5, "heal", 500, 200) }
local plan = expect("downranked heal", "Heal")
assert(plan.action.rank == 1, "the efficient non-overhealing rank should win")

currentState = state("smart"); currentState.groupSize = 4; currentState.hasAggro = true
scenarioActions = { action("Threat Slam", 1, "damage", 500, 0, { threat = 2 }),
    action("Careful Strike", 1, "damage", 300, 0, { threat = 0.5 }) }
expect("aggro-aware damage", "Careful Strike")

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

currentState = state("smart"); XelAssistGraph.testRangeBlocked = true
scenarioActions = { action("Out There", 1, "damage", 900, 0) }
local missing = XelAssistGraph:Evaluate("smart", true)
assert(missing == nil, "out-of-range action must not be recommended")
XelAssistGraph.testRangeBlocked = false

currentState = state("smart"); currentState.distance = 4; XelAssistGraph.testRangeUnknown = true
scenarioActions = { action("Dead Zone Shot", 1, "damage", 900, 0,
    { testMinRange = 8, testMaxRange = 35 }) }
local tooClose, tooCloseReason = XelAssistGraph:Evaluate("smart", true)
assert(tooClose == nil and tooCloseReason == "Move farther away", "minimum range must block too-close actions")
currentState.distance = 40
local tooFar, tooFarReason = XelAssistGraph:Evaluate("smart", true)
assert(tooFar == nil and tooFarReason == "Move into range", "maximum range must block too-far actions")
XelAssistGraph.testRangeUnknown = false

currentState = state("smart"); XelAssistCharDB.toggles.cooldowns = false
scenarioActions = { action("Unknown Long Cooldown", 1, "damage", 2000, 0, { testCooldown = 60 }),
    action("Normal Filler", 1, "damage", 200, 0) }
expect("live major cooldown policy", "Normal Filler")
XelAssistCharDB.toggles.cooldowns = true

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Burn", 1, "dot", 500, 40), action("Bolt", 1, "damage", 200, 20) }
plan = expect("future aura state", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Bolt", "future action should respect the applied aura")

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
scenarioActions = { action("Fireball", 1, "damage", 600, 100, { testSchool = 2 }),
    action("Shadow Bolt", 1, "damage", 430, 100, { testSchool = 5 }) }
plan = expect("pre-cast school resistance", "Shadow Bolt")
assert(plan.reason ~= "live resistance lowers expected damage",
    "the selected unresisted school should retain its own reason")

currentState = state("smart"); currentState.health = 150; currentState.healthMax = 1000
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

currentState = state("smart"); currentState.pet = true; currentState.targetCasting = true
currentState.actorReadyAt = { player = 3, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 20 }
scenarioActions = { petAction("Spell Lock", "interrupt", 0, 40, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 600, 100) }
plan = expect("felhunter interrupt", "Spell Lock")
assert(plan.actor == "pet", "the graph must retain the independently acting companion")
assert(plan.downtime < 0.2, "pet interrupt must remain independent of the player's cast/GCD clock")

currentState.targetCasting = false; currentState.actors.pet.resource = 0
scenarioActions = { petAction("Firebolt", "damage", 800, 50, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 250, 100) }
expect("pet resource isolation", "Shadow Bolt")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 5 }
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 100, 20) }
expect("companion attack command", "Pet Attack")
currentState.actors.pet.targetExists = true; currentState.actors.pet.targetsCurrent = true
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
local noShard = XelAssistGraph:Evaluate("smart", true)
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

print("ok: rank, aggro, interrupt, movement, range, aura, cooldown and beam scenarios")
