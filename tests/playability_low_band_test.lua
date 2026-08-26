-- First deterministic playable-1.0 catalogue band. These are unordered action
-- catalogues evaluated by the production graph, never scripted rotations.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reverse(values)
    local out, index = {}, nil
    for index = table.getn(values), 1, -1 do table.insert(out, values[index]) end
    return out
end

local function evaluate(source, actions)
    Fixture:Use(source, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 2, "damage"
    local plan, reason = XelAssist.Graph:Evaluate("smart", true)
    return plan, reason
end

local function setupAction(name)
    return Fixture.Action(name, 1, "buff", 0, 0,
        { self = true, testDuration = 1800 })
end

local CASES = {
    { class = "DRUID", level = 4, setup = "Mark of the Wild",
      expected = "Wrath", actions = function()
        return { Fixture.Action("Attack", 1, "damage", 25, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Wrath", 1, "damage", 95, 25,
                    { cast = 1.5, ranged = true, testMaxRange = 30 }) }
      end },
    { class = "HUNTER", level = 10, setup = "Aspect of the Hawk",
      expected = "Arcane Shot", actions = function()
        return { Fixture.Action("Raptor Strike", 1, "damage", 55, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Arcane Shot", 1, "damage", 90, 20,
                    { ranged = true, testMinRange = 8, testMaxRange = 35 }) }
      end },
    { class = "MAGE", level = 4, setup = "Frost Armor",
      expected = "Frostbolt", sustainExpected = "Fire Blast", actions = function()
        return { Fixture.Action("Fire Blast", 1, "damage", 45, 25,
                    { ranged = true, testMaxRange = 20 }),
            Fixture.Action("Frostbolt", 1, "damage", 100, 30,
                    { cast = 1.5, ranged = true, testMaxRange = 30 }) }
      end },
    { class = "PALADIN", level = 4, setup = "Devotion Aura",
      expected = "Attack", actions = function()
        return { Fixture.Action("Attack", 1, "damage", 35, 0,
                    { melee = true, testMaxRange = 5 }) }
      end },
    { class = "PRIEST", level = 4, setup = "Power Word: Fortitude",
      expected = "Smite", actions = function()
        return { Fixture.Action("Attack", 1, "damage", 20, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Smite", 1, "damage", 100, 25,
                    { cast = 1.5, ranged = true, testMaxRange = 30 }) }
      end },
    { class = "ROGUE", level = 8, setup = "Evasion",
      expected = "Sinister Strike", resourceType = 3, actions = function()
        return { Fixture.Action("Attack", 1, "damage", 30, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Sinister Strike", 1, "builder", 85, 45,
                    { melee = true, comboBuild = 1, testMaxRange = 5 }) }
      end },
    { class = "SHAMAN", level = 8, setup = "Lightning Shield",
      expected = "Lightning Bolt", actions = function()
        return { Fixture.Action("Attack", 1, "damage", 30, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Lightning Bolt", 1, "damage", 100, 30,
                    { cast = 1.5, ranged = true, testMaxRange = 30 }) }
      end },
    { class = "WARLOCK", level = 4, setup = "Demon Skin",
      expected = "Corruption", actions = function()
        return { Fixture.Action("Shadow Bolt", 1, "damage", 90, 30,
                    { cast = 1.5, ranged = true, testMaxRange = 30 }),
            Fixture.Action("Corruption", 1, "dot", 180, 35,
                    { ranged = true, testMaxRange = 30,
                      testDuration = 12, testPeriodicInterval = 3 }) }
      end },
    { class = "WARRIOR", level = 4, setup = "Battle Shout",
      expected = "Rend", resourceType = 1, actions = function()
        return { Fixture.Action("Attack", 1, "damage", 30, 0,
                    { melee = true, testMaxRange = 5 }),
            Fixture.Action("Rend", 1, "dot", 120, 10,
                    { melee = true, testMaxRange = 5,
                      testDuration = 9, testPeriodicInterval = 3 }) }
      end },
}

local _, case
for _, case in pairs(CASES) do
    local setupState = Fixture.State("smart")
    setupState.classMechanicClass, setupState.playerLevel = case.class, case.level
    setupState.hostile, setupState.targetHealth, setupState.targetMax = false, 0, 0
    local setup = setupAction(case.setup)
    local plan, reason = evaluate(setupState, { setup })
    assert(plan and plan.action.name == case.setup,
        case.class .. " low setup failed: " .. tostring(reason))

    local engage = Fixture.State("smart")
    engage.classMechanicClass, engage.playerLevel = case.class, case.level
    engage.resourceType = case.resourceType or 0
    engage.resource, engage.resourceMax = case.resourceType == 1 and 20 or 100,
        case.resourceType == 1 and 100 or 100
    engage.playerResourceExact, engage.distance = true,
        case.class == "HUNTER" and 20 or 4
    local actions = case.actions()
    plan, reason = evaluate(engage, actions)
    assert(plan and plan.action.name == case.expected,
        case.class .. " low engage got "
            .. tostring(plan and plan.action.name or reason))
    local reversed = evaluate(engage, reverse(actions))
    assert(reversed and reversed.action.name == case.expected,
        case.class .. " low engage depended on catalogue order")

    local sustain = Fixture.State("smart")
    sustain.classMechanicClass, sustain.playerLevel = case.class, case.level
    sustain.inCombat, sustain.resourceType = true, case.resourceType or 0
    sustain.resource, sustain.resourceMax = case.resourceType == 1 and 20 or 55, 100
    sustain.playerResourceExact, sustain.distance = true, engage.distance
    plan, reason = evaluate(sustain, case.actions())
    local sustainExpected = case.sustainExpected or case.expected
    assert(plan and plan.action.name == sustainExpected,
        case.class .. " low sustain got "
            .. tostring(plan and plan.action.name or reason)
            .. ", wanted " .. sustainExpected)

    local defeated = Fixture.State("smart")
    defeated.classMechanicClass, defeated.playerLevel = case.class, case.level
    defeated.targetHealth, defeated.targetMax = 0, 100
    defeated.targetHealthExact = true
    plan = evaluate(defeated, case.actions())
    assert(plan == nil, case.class .. " recommended an action on a defeated target")
end

print("ok: all nine unordered low-level catalogues cover setup engage sustain and death")
