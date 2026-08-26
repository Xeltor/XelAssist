-- End-to-end resource investment paths over the production graph. Life Tap is
-- only fixture data here; the search rule itself keys off generic conversion
-- and later resource consumption semantics.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

GetTime = function() return 100 end
debugprofilestop = function() return 0 end
GetSpellCooldown = function() return 0, 0, 1 end
GetPetActionCooldown = function() return 0, 0, 1 end
GetPetActionsUsable = function() return true end
IsSpellUsable = function() return 1, 0 end

local function source(health, activeWand)
    local state = Fixture.State("smart")
    state.inCombat = true
    state.health, state.healthMax = health or 150, 150
    local player = state.friendlies.byKey[state.friendlies.byUnit.player]
    player.health, player.healthMax = state.health, state.healthMax
    state.resource, state.resourceMax, state.resourceType = 0, 293, 0
    state.actors.player.resource, state.actors.player.resourceMax = 0, 293
    state.targetHealth, state.targetMax = 500, 500
    state.targetDistance, state.distance = 20, 20
    state.targetDistanceKind, state.distanceKind = "hitbox", "hitbox"
    state.wand = { supported = true, active = activeWand and true or false,
        activeKnown = true,
        targetGuid = state.targetGUID, damage = 12, speed = 2,
        nextShotIn = 0.4 }
    state.pet, state.actors.pet = false, nil
    return state
end

local function tap()
    local action = Fixture.Action("Life Tap", 1, "resource", 27, 0, {
        self = true, transientResource = true, healthConversion = true,
        resourceType = "mana" })
    action.executor, action.spellId = "playerSpell", 1454
    action.mock.healthCost, action.mock.resourceGain = 27, 27
    action.mock.resourceType = "mana"
    return action
end

local function levelSevenTap()
    local action = tap()
    action.mock.healthCost, action.mock.resourceGain = 21, 21
    action.mock.average = 21
    return action
end

local function shoot()
    local action = Fixture.Action("Shoot", 1, "autoRepeat", 12, 0, {
        autoRepeat = true, wandRepeat = true, recovery = true,
        ranged = true, weaponRanged = true, cast = 0, gcd = 0,
        testMinRange = 0, testMaxRange = 30 })
    action.executor, action.spellId = "playerSpell", 5019
    return action
end

local function bolt(cost, power)
    local action = Fixture.Action("Shadow Bolt", 1, "damage", power, cost, {
        cast = 1.7, ranged = true, testMinRange = 0,
        testMaxRange = 30, testSchool = 5 })
    action.executor, action.spellId = "playerSpell", 686
    return action
end

local function evaluate(state, cost, power, depth)
    local actions = { tap(), bolt(cost, power) }
    if state.wand and state.wand.active then
        table.insert(actions, 2, shoot())
    end
    Fixture:Use(state, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = depth, "damage"
    XelAssistCharDB.petThreat = "auto"
    return XelAssist.Graph:Evaluate("smart", true, 100)
end

local function evaluateMageWand(state, cost, power)
    Fixture:Use(state, { shoot(), bolt(cost, power) })
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 2, "damage"
    XelAssistCharDB.petThreat = "auto"
    return XelAssist.Graph:Evaluate("smart", true, 100)
end

local function levelSevenWarlock(hasAggro)
    local state = source(163, false)
    state.healthMax = 163
    state.hasAggro = hasAggro and true or false
    local player = state.friendlies.byKey[state.friendlies.byUnit.player]
    player.health, player.healthMax = 163, 163
    state.actors.player.health, state.actors.player.healthMax = 163, 163
    state.targetHealth, state.targetMax = 80, 80
    local actions = {
        levelSevenTap(),
        Fixture.Action("Corruption", 1, "dot", 40, 35,
            { cast = 1.5, testDuration = 12,
                testPeriodicInterval = 3, testSchool = 5 }),
        Fixture.Action("Immolate", 1, "dot", 30.4, 25,
            { cast = 2, testDuration = 15, testPeriodicInterval = 3,
                testDirectDamage = 10.4, testPeriodicDamage = 20,
                testSchool = 2 }),
        Fixture.Action("Shadow Bolt", 1, "damage", 15.6, 25,
            { cast = 1.7, testSchool = 5 }),
    }
    actions[2].executor, actions[2].spellId = "playerSpell", 172
    actions[3].executor, actions[3].spellId = "playerSpell", 348
    actions[4].executor, actions[4].spellId = "playerSpell", 686
    return state, actions
end

local function evaluateLevelSeven(state, actions)
    Fixture:Use(state, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 6, "damage"
    XelAssistCharDB.petThreat = "auto"
    return XelAssist.Graph:Evaluate("smart", true, 100)
end

local plan, reason = evaluate(source(), 25, 60, 3)
assert(plan and plan.action.name == "Life Tap" and plan.path[2]
    and plan.path[2].action.name == "Shadow Bolt", tostring(reason)
        .. ": one safe conversion must expose its downstream damage payoff")

plan, reason = evaluate(source(), 40, 60, 4)
assert(plan and plan.action.name == "Life Tap" and plan.path[2]
    and plan.path[2].action.name == "Life Tap" and plan.path[3]
    and plan.path[3].action.name == "Shadow Bolt", tostring(reason)
        .. ": a temporarily negative second conversion must reach its payoff")

local stranded = source()
Fixture:Use(stranded, { tap() })
XelAssistCharDB.graphDepth, XelAssistCharDB.role = 4, "damage"
plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
assert(not plan and reason == "No worthwhile action",
    "a health conversion without a later resource spender must never be published")

local fullManaWand = source()
fullManaWand.resource = fullManaWand.resourceMax
plan, reason = evaluateMageWand(fullManaWand, 25, 50)
assert(plan and plan.action.name == "Shadow Bolt", tostring(reason)
        .. ": full mana must retain the faster spell when its opportunity cost is low")
local lowManaWand = source()
lowManaWand.resource = 25
plan, reason = evaluateMageWand(lowManaWand, 25, 50)
assert(plan and plan.action.name == "Shoot" and plan.path[2]
    and plan.path[2].action.name == "Continue Shoot", tostring(reason)
        .. ": got " .. tostring(plan and plan.action and plan.action.name)
        .. " -> " .. tostring(plan and plan.path[2]
            and plan.path[2].action and plan.path[2].action.name)
        .. ": scarce mana must preserve Shoot until its first real wand impact")

plan = evaluate(source(55, true), 25, 12, 4)
assert(plan and plan.action.name == "Continue Shoot",
    "low health must let the real wand damage beat an unsafe conversion path")

local aggro, levelSevenActions = levelSevenWarlock(true)
plan, reason = evaluateLevelSeven(aggro, levelSevenActions)
assert(plan and plan.action.name == "Life Tap" and plan.path[2]
    and plan.path[2].action.name == "Life Tap" and plan.path[3]
    and plan.path[3].action.name == "Corruption", tostring(reason)
        .. ": real level-seven aggro must not veto the two-Tap damage runway")

local safeScore = XelAssist.Graph.Scoring:Evaluate(
    levelSevenActions[1], aggro,
    XelAssist.Graph.Targets:Targets(levelSevenActions[1], aggro)[1])
local pressured, pressuredActions = levelSevenWarlock(true)
pressured.hostileCasts = { order = { "enemy-guid" }, byCaster = {
    ["enemy-guid"] = { casterGuid = "enemy-guid",
        targetGuid = "player-guid", generation = 1, remaining = 1,
        probability = 1, consequence = { kind = "damage",
            targetMode = "target", targetGuid = "player-guid", amount = 80 } },
} }
local pressuredScore = XelAssist.Graph.Scoring:Evaluate(
    pressuredActions[1], pressured,
    XelAssist.Graph.Targets:Targets(pressuredActions[1], pressured)[1])
assert(safeScore and safeScore.value > 0 and pressuredScore
    and pressuredScore.value < 0,
    "aggro alone must not veto a safe Tap, while proven incoming damage must")

local lowLevelSeven, lowLevelSevenActions = levelSevenWarlock(false)
lowLevelSeven.health = 45
lowLevelSeven.actors.player.health = 45
lowLevelSeven.friendlies.byKey[
    lowLevelSeven.friendlies.byUnit.player].health = 45
lowLevelSeven.wand.active = true
table.insert(lowLevelSevenActions, 2, shoot())
plan, reason = evaluateLevelSeven(lowLevelSeven, lowLevelSevenActions)
assert(plan and plan.action.name == "Continue Shoot", tostring(reason)
    .. ": a level-seven Warlock at low health must keep the live wand escape")

local dying = source(nil, true)
dying.targetHealth, dying.targetMax = 12, 500
plan = evaluate(dying, 25, 60, 3)
assert(plan and plan.action.name == "Continue Shoot",
    "an already launched lethal wand path must beat spending health for mana")

local threatState, threatTap = source(), tap()
threatState.pet = true
threatState.actors.pet = { health = 100, healthMax = 100,
    resource = 100, resourceMax = 100 }
Fixture:Use(threatState, { threatTap })
local descriptor = XelAssist.Graph.Targets:Targets(threatTap, threatState)[1]
local candidate = XelAssist.Graph.Scoring:Evaluate(
    threatTap, threatState, descriptor)
assert(candidate and candidate.threat == 0
    and candidate.reason == "trades health for needed mana",
    "resource gained must never be mistaken for hostile threat")

print("ok: graph-native resource investments survive only to real payoffs")
