-- Deterministic mid-level scenario bands.  Each phase supplies an unordered
-- discovered-style action catalogue to the production graph; this is not a
-- scripted rotation and deliberately avoids mechanics lacking exact facts.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reverse(values)
    local out, i = {}, nil
    for i = table.getn(values), 1, -1 do table.insert(out, values[i]) end
    return out
end

local function run(source, actions, role)
    Fixture:Use(source, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 3, role or "damage"
    return XelAssist.Graph:Evaluate("smart", true)
end

local function expect(label, source, actions, wanted, role)
    local plan, reason = run(source, actions, role)
    assert(plan and plan.action.name == wanted,
        label .. " got " .. tostring(plan and plan.action.name or reason)
            .. ", wanted " .. wanted)
    local reversed, reversedReason = run(source, reverse(actions), role)
    assert(reversed and reversed.action.name == wanted,
        label .. " depended on catalogue order: "
            .. tostring(reversed and reversed.action.name or reversedReason))
    return plan
end

local function expectNone(label, source, actions, role)
    local plan = run(source, actions, role)
    local reversed = run(source, reverse(actions), role)
    assert(plan == nil and reversed == nil,
        label .. " death gate depended on catalogue order")
end

local function base(class, resourceType, resource, distance)
    local value = Fixture.State("smart")
    value.classMechanicClass, value.playerLevel = class, 30
    value.resourceType, value.resource, value.resourceMax = resourceType,
        resource, 100
    value.playerResourceExact = true
    value.distance, value.targetDistance = distance, distance
    value.distanceKind, value.targetDistanceKind = "hitbox", "hitbox"
    value.combo = 0
    value.pet = false
    value.playerAttack = { supported = true, active = false,
        activeKnown = true, pending = false, clockKnown = true }
    return value
end

local function setupState(class)
    local value = base(class, class == "WARRIOR" and 1 or 0, 100, 0)
    value.hostile, value.targetHealth, value.targetMax = false, 0, 0
    return value
end

local function defeated(class, resourceType)
    local value = base(class, resourceType, 100, 4)
    value.targetHealth, value.targetMax, value.targetHealthExact = 0, 100, true
    return value
end

local attack = Fixture.Action("Attack", 1, "damage", 30, 0,
    { melee = true, testMaxRange = 5 })

-- Hunter: Aspect setup, ranged engagement, exact living-pet contribution,
-- focus starvation/recovery, a melee-range transition, death, then recovery.
local aspect = Fixture.Action("Aspect of the Hawk", 2, "buff", 0, 0,
    { self = true, testDuration = 1800 })
local arcane = Fixture.Action("Arcane Shot", 3, "damage", 120, 35,
    { ranged = true, testMinRange = 8, testMaxRange = 35, testSchool = 6 })
local serpent = Fixture.Action("Serpent Sting", 3, "dot", 210, 30,
    { ranged = true, testMinRange = 8, testMaxRange = 35,
      testDuration = 15, testPeriodicInterval = 3, testSchool = 3 })
local raptor = Fixture.Action("Raptor Strike", 3, "damage", 85, 15,
    { melee = true, testMaxRange = 5 })
local autoShot = Fixture.Action("Auto Shot", 1, "damage", 50, 0,
    { ranged = true, testMinRange = 8, testMaxRange = 35 })
local bite = Fixture.PetAction("Bite", "damage", 55, 35,
    { melee = true })
expect("Hunter OOC setup", setupState("HUNTER"), { aspect }, "Aspect of the Hawk")
local hunter = base("HUNTER", 0, 100, 20)
hunter.pet = true
hunter.actors.pet = { lifecycle = "alive", health = 700, healthMax = 700,
    resource = 70, resourceMax = 100, readyAt = 0, distance = 4,
    distanceKind = "hitbox", targetGuid = hunter.targetGUID }
expect("Hunter engage", hunter, { bite, arcane, serpent }, "Serpent Sting")
hunter.inCombat, hunter.resource, hunter.actors.pet.resource = true, 0, 70
expect("Hunter starvation with living pet", hunter,
    { bite, arcane, serpent, autoShot }, "Auto Shot")
hunter.resource, hunter.actors.pet.resource = 70, 0
expect("Hunter resource recovery", hunter, { bite, arcane }, "Arcane Shot")
hunter.distance, hunter.targetDistance = 4, 4
expect("Hunter melee transition", hunter, { arcane, raptor }, "Raptor Strike")
expectNone("Hunter", defeated("HUNTER", 0), { arcane, serpent })
expect("Hunter post-fight recovery", setupState("HUNTER"), { aspect },
    "Aspect of the Hawk")

-- Rogue: stealth setup/opener, energy starvation and recovery, an exact cast
-- interrupt opportunity, death, and return to stealth preparation.
local stealth = Fixture.Action("Stealth", 2, "buff", 0, 0,
    { self = true, testAppliesStealth = true })
local ambush = Fixture.Action("Ambush", 2, "builder", 210, 60,
    { melee = true, behind = true, comboBuild = 1,
      testRequiresStealth = true, testInitiatesCombat = true })
local sinister = Fixture.Action("Sinister Strike", 4, "builder", 105, 45,
    { melee = true, comboBuild = 1, testInitiatesCombat = true })
local kick = Fixture.Action("Kick", 2, "interrupt", 0, 25,
    { melee = true, testMaxRange = 5 })
expect("Rogue OOC setup", setupState("ROGUE"), { stealth }, "Stealth")
local rogue = base("ROGUE", 3, 100, 4)
rogue.playerStealthed, rogue.playerStealthKnown = true, true
rogue.playerBehindTarget = true
expect("Rogue engage", rogue, { attack, sinister, ambush }, "Ambush")
rogue.inCombat, rogue.playerStealthed, rogue.resource = true, false, 0
expect("Rogue starvation", rogue, { attack, sinister }, "Attack")
rogue.resource = 55
expect("Rogue energy recovery", rogue, { attack, sinister }, "Sinister Strike")
rogue.targetCasting, rogue.targetCastRemaining = true, 1
expect("Rogue interrupt", rogue, { sinister, kick }, "Kick")
expectNone("Rogue", defeated("ROGUE", 3), { attack, sinister })
expect("Rogue post-fight recovery", setupState("ROGUE"), { stealth }, "Stealth")

-- Warrior: durable shout setup, engagement, rage runway/recovery, and a tank
-- cast stop.  The tank flag is truthful state, not a synthetic threat result.
local shout = Fixture.Action("Battle Shout", 3, "buff", 0, 10,
    { self = true, testDuration = 120 })
local rend = Fixture.Action("Rend", 4, "dot", 180, 10,
    { melee = true, testDuration = 12, testPeriodicInterval = 3,
      testInitiatesCombat = true })
local slam = Fixture.Action("Heroic Strike", 4, "damage", 125, 15,
    { melee = true })
local shieldBash = Fixture.Action("Shield Bash", 2, "interrupt", 0, 10,
    { melee = true, testMaxRange = 5 })
expect("Warrior OOC setup", setupState("WARRIOR"), { shout }, "Battle Shout")
local warrior = base("WARRIOR", 1, 25, 4)
expect("Warrior engage", warrior, { attack, rend, slam }, "Rend")
warrior.inCombat, warrior.resource = true, 0
expect("Warrior rage starvation", warrior, { attack, slam }, "Attack")
warrior.resource = 25
expect("Warrior rage recovery", warrior, { attack, slam }, "Heroic Strike")
warrior.targetHealth, warrior.targetMax = 30, 204
warrior.targetSurvival = { available = true, incomingDps = 7.2,
    timeToDie = 4.1667, lowerTimeToDie = 3.75, upperTimeToDie = 4.58,
    observedFor = 12, samples = 4, confidence = "limited samples" }
warrior.playerAttack.active = true
expect("Warrior late Rend restraint", warrior,
    { attack, rend, slam }, "Heroic Strike")
warrior.tank, warrior.role, warrior.groupSize = true, "tank", 4
warrior.targetCasting, warrior.targetCastRemaining = true, 1
expect("Warrior tank interrupt", warrior, { slam, shieldBash }, "Shield Bash", "tank")
expectNone("Warrior", defeated("WARRIOR", 1), { attack, rend })
expect("Warrior post-fight recovery", setupState("WARRIOR"), { shout },
    "Battle Shout")

print("ok: unordered Hunter Rogue Warrior mid-level scenario bands")
