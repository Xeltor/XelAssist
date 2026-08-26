-- Deterministic mid-level caster band. Each phase evaluates an unordered
-- discovered-style catalogue through the production graph; this is not a
-- scripted spell sequence and no production admission gate is replaced.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reorder(values, mode)
    local out, index = {}, nil
    if mode == 2 then
        for index = table.getn(values), 1, -1 do table.insert(out, values[index]) end
    elseif mode == 3 then
        for index = 2, table.getn(values) do table.insert(out, values[index]) end
        if values[1] then table.insert(out, values[1]) end
    else
        for index = 1, table.getn(values) do table.insert(out, values[index]) end
    end
    return out
end

local function resources(state, current, maximum)
    state.resource, state.resourceMax = current, maximum
    state.playerResourceExact = true
    state.actors.player.resource = current
    state.actors.player.resourceMax = maximum
    state.actors.player.resourceExact = true
end
local function wandState(state)
    state.wand = { supported=true,active=false,activeKnown=true,pending=false,
        clockKnown=true,currentTargetGuid=state.targetGUID,speed=2,damage=70 }
end

local function evaluate(label, state, actions, wanted)
    local mode, plan, reason
    for mode = 1, 3 do
        Fixture:Use(state, reorder(actions, mode))
        XelAssistCharDB.graphDepth, XelAssistCharDB.role = 3, "damage"
        plan, reason = XelAssist.Graph:Evaluate("smart", true)
        assert(plan and plan.action.name == wanted,
            label .. " order " .. mode .. " got "
                .. tostring(plan and plan.action.name or reason)
                .. ", wanted " .. wanted)
    end
    return plan
end

local function noDefeatedTargetAction(label, state, actions)
    local mode, plan
    for mode = 1, 3 do
        Fixture:Use(state, reorder(actions, mode))
        XelAssistCharDB.graphDepth = 2
        plan = XelAssist.Graph:Evaluate("smart", true)
        assert(plan == nil, label .. " recommended "
            .. tostring(plan and plan.action.name) .. " on a defeated target")
    end
end

local function spell(name, kind, power, cost, extra)
    return Fixture.Action(name, 1, kind, power, cost, extra)
end
local function setup(name)
    return spell(name, "buff", 0, 0,
        { self=true, testDuration=1800 })
end
local function wand()
    local action=spell("Shoot", "autoRepeat", 0, 0,
        { autoRepeat=true,wandRepeat=true,ambient=true,startOnly=true,
          recovery=true,ranged=true,cast=0,testMaxRange=30 })
    action.mock.gcd=0
    return action
end
local function recovery(name, power, extra)
    extra = extra or {}; extra.self, extra.recovery = true, true
    return spell(name, "resource", power or 0, 0, extra)
end

local CASES = {
    { class="MAGE", setup="Frost Armor",
      combat=function()
        return { spell("Frostbolt","damage",180,55,
                    {cast=2.5,ranged=true,slow=true,testMaxRange=30,testSchool=4}),
            spell("Fire Blast","damage",300,40,
                    {ranged=true,testMaxRange=20,testSchool=2}), wand() }
      end,
      engage="Frostbolt", movement="Fire Blast",
      recovery=function() return recovery("Evocation",400,{channel=true}) end },
    { class="PRIEST", setup="Power Word: Fortitude",
      combat=function()
        return { spell("Smite","damage",170,55,
                    {cast=2.5,ranged=true,testMaxRange=30,testSchool=1}),
            spell("Shadow Word: Pain","dot",240,45,
                    {ranged=true,testMaxRange=30,testSchool=5,
                     testDuration=18,testPeriodicInterval=3}), wand() }
      end,
      engage="Shadow Word: Pain", interrupt="Silence",
      recovery=function() return recovery("Drink",400,{channel=true}) end },
    { class="WARLOCK", setup="Demon Armor",
      combat=function()
        return { spell("Shadow Bolt","damage",190,55,
                    {cast=2.5,ranged=true,testMaxRange=30,testSchool=5}),
            spell("Corruption","dot",250,50,
                    {ranged=true,testMaxRange=30,testSchool=5,
                     testDuration=18,testPeriodicInterval=3}), wand() }
      end,
      engage="Corruption", movement="Corruption",
      recovery=function()
        return recovery("Drink",400,{channel=true})
      end },
}

local _, case
for _, case in pairs(CASES) do
    local state = Fixture.State("smart")
    state.classMechanicClass, state.playerLevel = case.class, 32
    state.hostile, state.inCombat = false, false
    resources(state, 500, 500)
    evaluate(case.class .. " OOC setup",state,{setup(case.setup)},case.setup)

    state = Fixture.State("smart")
    state.classMechanicClass, state.playerLevel = case.class, 32
    state.distance, state.targetDistance, state.inCombat = 24, 24, false
    wandState(state)
    resources(state,500,500)
    local combat=case.combat()
    evaluate(case.class .. " engage",state,combat,case.engage)

    state = Fixture.State("smart")
    state.classMechanicClass, state.playerLevel = case.class, 32
    state.distance, state.targetDistance, state.inCombat = 24, 24, true
    wandState(state)
    resources(state,20,500)
    evaluate(case.class .. " starvation",state,case.combat(),"Shoot")

    if case.movement then
        state.moving=true; state.distance,state.targetDistance=18,18
        resources(state,500,500)
        evaluate(case.class .. " movement",state,case.combat(),case.movement)
    elseif case.interrupt then
        local silence=spell(case.interrupt,"interrupt",0,40,
            {ranged=true,testMaxRange=30})
        state.targetCasting=true; resources(state,100,500)
        local actions=case.combat(); table.insert(actions,silence)
        evaluate(case.class .. " interrupt",state,actions,case.interrupt)
    else
        state.targetResistances={[6]=500}; resources(state,100,500)
        evaluate(case.class .. " resistance",state,case.combat(),case.resistance)
    end

    local defeated=Fixture.State("smart")
    defeated.classMechanicClass, defeated.playerLevel = case.class, 32
    defeated.targetHealth, defeated.targetMax = 0, 1000
    defeated.targetHealthExact, defeated.inCombat = true, true
    defeated.distance,defeated.targetDistance=24,24; resources(defeated,20,500)
    wandState(defeated)
    noDefeatedTargetAction(case.class .. " death",defeated,case.combat())

    local recovered=Fixture.State("smart")
    recovered.classMechanicClass, recovered.playerLevel = case.class, 32
    recovered.hostile, recovered.inCombat = false, false
    resources(recovered,20,500)
    evaluate(case.class .. " recovery",recovered,{case.recovery()},
        case.class=="MAGE" and "Evocation"
            or "Drink")
end

print("ok: unordered Mage Priest Warlock mid-band setup combat starvation disruption death recovery")
