-- Deterministic mid-level hybrid-class band over the shipped graph. Catalogues
-- are unordered discovered actions, not rotations; every phase is evaluated in
-- both directions to prove that catalogue order cannot choose the result.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reverse(values)
    local out, index = {}, nil
    for index = table.getn(values), 1, -1 do
        table.insert(out, values[index])
    end
    return out
end

local function evaluate(source, actions, role)
    Fixture:Use(source, actions)
    XelAssistCharDB.graphDepth = 2
    XelAssistCharDB.role = role or "damage"
    return XelAssist.Graph:Evaluate("smart", true)
end

local function signature(plan)
    if not plan then return "nil" end
    local first = plan.path and plan.path[1]
    return table.concat({ tostring(plan.action and plan.action.name),
        tostring(first and first.targetKey or first and first.target or ""),
        string.format("%.3f", tonumber(plan.wait) or 0) }, "|")
end

local function orderIndependent(label, source, actions, role)
    local first, reason = evaluate(source, actions, role)
    assert(first, label .. ": " .. tostring(reason))
    local second, reverseReason = evaluate(source, reverse(actions), role)
    assert(second, label .. " reversed: " .. tostring(reverseReason))
    assert(signature(first) == signature(second),
        label .. " depended on catalogue order: " .. signature(first)
            .. " vs " .. signature(second))
    return first
end

local function setup(name)
    return Fixture.Action(name, 1, "buff", 0, 0,
        { self = true, testDuration = 1800 })
end

local function manaClock()
    return { verified = true, phaseKnown = true,
        externalEnergizeExcluded = true, resourceType = 0,
        amount = 20, interval = 2, nextIn = 1,
        source = "deterministic mid-band passive mana fixture" }
end

local function injuredAlly(state)
    local key = state.friendlies.byUnit.party1
    local ally = state.friendlies.byKey[key]
    ally.health, ally.healthMax, ally.healthExact = 1, 1000, true
    state.healUnit, state.healHealth, state.healMax = "party1", 1, 1000
    state.groupSize, state.inCombat = 1, true
    return ally
end

local function manaActions(values)
    local out, index = {}, nil
    for index = 1, table.getn(values) do
        if tonumber(values[index].mock and values[index].mock.cost) > 0 then
            table.insert(out, values[index])
        end
    end
    return out
end

local CASES = {
    { class = "SHAMAN", level = 40, setup = "Lightning Shield",
      engage = "Earth Shock", ranged = "Earth Shock", heal = "Healing Wave",
      actions = function()
        return {
            Fixture.Action("Attack", 1, "damage", 35, 0,
                { melee = true, testMaxRange = 5, testSchool = 0 }),
            Fixture.Action("Earth Shock", 5, "damage", 80, 30,
                { ranged = true, testMaxRange = 20, testSchool = 3 }),
            Fixture.Action("Lightning Bolt", 7, "damage", 125, 45,
                { cast = 2.5, ranged = true, testMaxRange = 30, testSchool = 3 }),
        }
      end,
      healAction = function()
        return Fixture.Action("Healing Wave", 6, "heal", 360, 70,
            { cast = 2.5, testMaxRange = 40, testSchool = 3 })
      end },
    { class = "PALADIN", level = 40, setup = "Devotion Aura",
      engage = "Holy Shock", ranged = "Holy Shock", heal = "Holy Light",
      tank = true,
      actions = function()
        return {
            Fixture.Action("Attack", 1, "damage", 40, 0,
                { melee = true, testMaxRange = 5, testSchool = 0 }),
            Fixture.Action("Judgement", 1, "damage", 70, 25,
                { ranged = true, testMaxRange = 10, testSchool = 1 }),
            Fixture.Action("Holy Shock", 1, "damage", 115, 45,
                { ranged = true, testMaxRange = 20, testSchool = 1 }),
        }
      end,
      healAction = function()
        return Fixture.Action("Holy Light", 5, "heal", 380, 75,
            { cast = 2.5, testMaxRange = 40, testSchool = 1 })
      end },
    { class = "DRUID", level = 40, setup = "Mark of the Wild",
      engage = "Moonfire", ranged = "Moonfire", heal = "Healing Touch", tank = true,
      actions = function()
        return {
            Fixture.Action("Attack", 1, "damage", 30, 0,
                { melee = true, testMaxRange = 5, testSchool = 0 }),
            Fixture.Action("Moonfire", 6, "damage", 75, 25,
                { ranged = true, testMaxRange = 30, testSchool = 6 }),
            Fixture.Action("Wrath", 6, "damage", 120, 45,
                { cast = 2, ranged = true, testMaxRange = 30, testSchool = 3 }),
        }
      end,
      healAction = function()
        return Fixture.Action("Healing Touch", 7, "heal", 400, 80,
            { cast = 3, testMaxRange = 40, testSchool = 3 })
      end },
}

local _, case
for _, case in pairs(CASES) do
    local ooc = Fixture.State("smart")
    ooc.classMechanicClass, ooc.playerLevel = case.class, case.level
    ooc.hostile, ooc.targetHealth, ooc.targetMax = false, 0, 0
    local plan = orderIndependent(case.class .. " OOC setup", ooc,
        { setup(case.setup) }, "damage")
    assert(plan.action.name == case.setup, case.class .. " skipped OOC setup")

    local engage = Fixture.State("smart")
    engage.classMechanicClass, engage.playerLevel = case.class, case.level
    engage.resourceType, engage.resource, engage.resourceMax = 0, 100, 100
    engage.playerResourceExact, engage.distance = true, 4
    plan = orderIndependent(case.class .. " engage", engage,
        case.actions(), "damage")
    assert(plan.action.name == case.engage,
        case.class .. " engage chose " .. tostring(plan.action.name))

    local starved = Fixture.State("smart")
    starved.classMechanicClass, starved.playerLevel = case.class, case.level
    starved.inCombat, starved.resourceType = true, 0
    starved.resource, starved.resourceMax = 0, 100
    starved.playerResourceExact, starved.distance = true, 18
    starved.playerResourceClock = manaClock()
    local starvedActions = manaActions(case.actions())
    local blocked, blockedReason = evaluate(starved, starvedActions, "damage")
    local reverseBlocked, reverseReason = evaluate(starved,
        reverse(starvedActions), "damage")
    assert(not blocked and not reverseBlocked
        and blockedReason == "Not enough resources"
        and reverseReason == blockedReason,
        case.class .. " starvation was not safely order-independent")
    XelAssist.Game.Player.Resources:Advance(starved, 5)
    assert(starved.resource == 60,
        case.class .. " exact passive mana clock did not recover resources")
    plan = orderIndependent(case.class .. " recovered sustain", starved,
        starvedActions, "damage")
    assert(plan.action, case.class .. " recovery produced no sustained action")

    local moving = Fixture.State("smart")
    moving.classMechanicClass, moving.playerLevel = case.class, case.level
    moving.inCombat, moving.moving, moving.distance = true, true, 18
    moving.resourceType, moving.resource, moving.resourceMax = 0, 100, 100
    moving.playerResourceExact = true
    plan = orderIndependent(case.class .. " movement/range", moving,
        case.actions(), "damage")
    assert(plan.action.name == case.ranged,
        case.class .. " movement/range chose " .. tostring(plan.action.name))

    local healer = Fixture.State("smart")
    healer.classMechanicClass, healer.playerLevel = case.class, case.level
    healer.resourceType, healer.resource, healer.resourceMax = 0, 100, 100
    healer.playerResourceExact = true
    injuredAlly(healer)
    local healingCatalogue = { case.healAction() }
    plan = orderIndependent(case.class .. " healer state", healer,
        healingCatalogue, "healer")
    assert(plan.action.name == case.heal,
        case.class .. " healer state chose " .. tostring(plan.action.name))

    if case.tank then
        local tank = Fixture.State("smart")
        tank.classMechanicClass, tank.playerLevel = case.class, case.level
        tank.inCombat, tank.tank, tank.hasAggro = true, true, true
        tank.resourceType, tank.resource, tank.resourceMax = 0, 100, 100
        tank.playerResourceExact, tank.distance = true, 4
        plan = orderIndependent(case.class .. " tank state", tank,
            case.actions(), "tank")
        assert(plan.action, case.class .. " tank state produced no action")
    end

    local dead = Fixture.State("smart")
    dead.classMechanicClass, dead.playerLevel = case.class, case.level
    dead.targetHealth, dead.targetMax, dead.targetHealthExact = 0, 100, true
    local deadPlan = evaluate(dead, case.actions(), "damage")
    assert(deadPlan == nil, case.class .. " acted on a defeated target")
    local reversedDead = evaluate(dead, reverse(case.actions()), "damage")
    assert(reversedDead == nil,
        case.class .. " reversed catalogue acted on a defeated target")

    local recovery = Fixture.State("smart")
    recovery.classMechanicClass, recovery.playerLevel = case.class, case.level
    recovery.hostile, recovery.targetHealth, recovery.targetMax = false, 0, 0
    recovery.inCombat, recovery.resourceType = false, 0
    recovery.resource, recovery.resourceMax = 40, 100
    recovery.playerResourceExact = true
    plan = orderIndependent(case.class .. " post-kill recovery", recovery,
        { setup(case.setup) }, "damage")
    assert(plan.action.name == case.setup,
        case.class .. " did not return to safe OOC setup")
end

print("ok: unordered Shaman Paladin Druid mid-band phases are deterministic")
