-- Deterministic sliced-search benchmark over the production graph modules.
-- Client APIs are fixture boundaries, while Targets, Scoring, Timeline,
-- Transitions, SearchSession and PlanBuilder remain the shipped code.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local SLICE_MS = XelAssist.Graph.SearchPolicy.SLICE_MS
local FRAME_CEILING_MS = 3.23
local FRAME_IDLE_MS = 16.667
local EPSILON = 0.0001
local profilerClock = 0
local metrics

GetTime = function() return 100 end
debugprofilestop = function() return profilerClock end

local function charge(kind, milliseconds)
    if not metrics then return end
    profilerClock = profilerClock + milliseconds
    metrics.active = metrics.active + milliseconds
    metrics.calls[kind] = (metrics.calls[kind] or 0) + 1
    if milliseconds > metrics.maxAtomic then metrics.maxAtomic = milliseconds end
end

local productionTargets = XelAssist.Graph.Targets.Targets
XelAssist.Graph.Targets.Targets = function(owner, action, source)
    local result = productionTargets(owner, action, source)
    charge("targets", 0.04)
    return result
end

local productionScoring = XelAssist.Graph.Scoring.Evaluate
XelAssist.Graph.Scoring.Evaluate = function(owner, action, source, target)
    local candidate, blocker = productionScoring(owner, action, source, target)
    charge("scoring", 0.34)
    return candidate, blocker
end

local productionTransition = XelAssist.Graph.Transitions.Advance
XelAssist.Graph.Transitions.Advance = function(owner, source, candidate)
    local result = productionTransition(owner, source, candidate)
    charge("transition", 0.18)
    return result
end

local productionActorActions = XelAssist.Game.Actors.Actions
XelAssist.Game.Actors.Actions = function(owner)
    local result = productionActorActions(owner)
    charge("actor actions", 0.08)
    return result
end

local productionFacts = XelAssist.Game.Actors.Facts
XelAssist.Game.Actors.Facts = function(owner, action)
    local result = productionFacts(owner, action)
    charge("action facts", 0.16)
    return result
end

local productionRange = XelAssist.Game.Range.SpellVerdict
XelAssist.Game.Range.SpellVerdict = function(owner, ...)
    local result = productionRange(owner, ...)
    charge("root range", 0.07)
    return result
end

GetSpellCooldown = function()
    charge("spell cooldown", 0.04)
    return 0, 0, 1
end
GetPetActionCooldown = function()
    charge("pet cooldown", 0.04)
    return 0, 0, 1
end
GetPetActionsUsable = function()
    charge("pet usability", 0.03)
    return true
end
IsSpellUsable = function()
    charge("spell usability", 0.03)
    return 1, 0
end

local productionItemActions = XelAssist.Game.Inventory.Actions
XelAssist.Game.Inventory.Actions = function(owner)
    local result = productionItemActions(owner)
    charge("item actions", 0.03)
    return result
end

local productionBuild = XelAssist.Graph.PlanBuilder.Build
XelAssist.Graph.PlanBuilder.Build = function(owner, ...)
    local result = productionBuild(owner, ...)
    charge("plan build", 0.12)
    metrics.builds = metrics.builds + 1
    return result
end

local function approximately(left, right)
    return math.abs((left or 0) - (right or 0)) <= EPSILON
end

local function pathSignature(plan)
    local parts, index = {}, nil
    for index = 1, table.getn(plan.path or {}) do
        local step = plan.path[index]
        table.insert(parts, table.concat({
            tostring(step.action and step.action.actor or "player"),
            tostring(step.action and step.action.name or ""),
            tostring(step.action and step.action.rank or 0),
            tostring(step.targetKey or step.target or ""),
            string.format("%.6f", tonumber(step.value) or 0),
        }, ":"))
    end
    return table.concat(parts, "|") .. ";expanded=" .. tostring(plan.expanded)
        .. ";depth=" .. tostring(plan.completedDepth)
        .. ";limited=" .. tostring(plan.budgetLimited and true or false)
end

local function newMetrics()
    return { active = 0, idle = 0, resumes = 0, builds = 0,
        maxAtomic = 0, calls = {} }
end

local function configure(depth)
    XelAssistCharDB.graphDepth = depth
    XelAssistCharDB.role = "damage"
    XelAssistCharDB.petThreat = "tank"
    XelAssistCharDB.allowAoe = false
    XelAssistCharDB.toggles.cooldowns = true
    XelAssistCharDB.toggles.reagents = true
    XelAssistCharDB.toggles.petActions = true
    XelAssistCharDB.toggles.petControl = false
    XelAssistCharDB.toggles.engagedTargets = false
end

local function prepare(case)
    local source, actions = case.Build()
    local index
    for index = 1, table.getn(actions) do
        if (actions[index].actor or "player") == "player"
            and not actions[index].executor then
            actions[index].executor = "playerSpell"
        end
    end
    case.actionCount = table.getn(actions)
    Fixture:Use(source, actions)
    configure(case.depth)
end

local function synchronous(case)
    prepare(case)
    profilerClock, metrics = 0, newMetrics()
    local plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
    assert(plan, case.name .. " synchronous: " .. tostring(reason))
    assert(metrics.builds == 1,
        case.name .. " synchronous evaluation must build exactly once")
    local result = { plan = plan, metrics = metrics,
        signature = pathSignature(plan), wall = profilerClock }
    metrics = nil
    return result
end

local function sliced(case)
    prepare(case)
    profilerClock, metrics = 0, newMetrics()
    local session = XelAssist.Graph:BeginEvaluation("smart", true, 100)
    local complete, plan, reason, fallback = false, nil, nil, nil
    local measuredActive = 0
    while not complete do
        local before = profilerClock
        metrics.resumes = metrics.resumes + 1
        complete, plan, reason, fallback =
            XelAssist.Graph:ResumeEvaluation(session, SLICE_MS)
        measuredActive = measuredActive + profilerClock - before
        if not complete then
            assert(plan == nil and reason == nil and fallback == nil,
                case.name .. " pending slice exposed partial output")
            profilerClock = profilerClock + FRAME_IDLE_MS
            metrics.idle = metrics.idle + FRAME_IDLE_MS
        end
    end
    assert(plan and reason == nil and fallback == false,
        case.name .. " sliced completion did not publish one final plan")
    assert(metrics.builds == 1,
        case.name .. " sliced evaluation must build exactly once")
    assert(metrics.resumes == session.slices and session.slices > 1,
        case.name .. " did not genuinely span multiple slices")
    assert(approximately(measuredActive, metrics.active)
        and approximately(plan.elapsed, metrics.active),
        case.name .. " active CPU accounting included an idle frame")
    assert(profilerClock > plan.elapsed + FRAME_IDLE_MS,
        case.name .. " wall time did not remain separate from active time")
    assert(plan.maxSliceMs <= SLICE_MS + metrics.maxAtomic + EPSILON,
        case.name .. " exceeded slice plus indivisible-call bound: "
            .. tostring(plan.maxSliceMs) .. " > "
            .. tostring(SLICE_MS + metrics.maxAtomic))
    assert(plan.maxSliceMs <= FRAME_CEILING_MS + EPSILON,
        case.name .. " exceeded the production frame ceiling: "
            .. tostring(plan.maxSliceMs) .. " > " .. tostring(FRAME_CEILING_MS))

    local builds = metrics.builds
    local again, samePlan, sameReason, sameFallback =
        XelAssist.Graph:ResumeEvaluation(session, SLICE_MS)
    assert(again and samePlan == plan and sameReason == nil
        and sameFallback == false and metrics.builds == builds,
        case.name .. " completed Resume was not idempotent")

    local result = { plan = plan, metrics = metrics, session = session,
        signature = pathSignature(plan), wall = profilerClock }
    metrics = nil
    return result
end

local function levelSevenWarlock()
    local source = Fixture.State("smart")
    source.inCombat = true
    source.resource, source.resourceMax = 293, 293
    source.actors.player.resource, source.actors.player.resourceMax = 293, 293
    source.targetHealth, source.targetMax = 80, 80
    source.targetDistance, source.distance = 20, 20
    source.targetDistanceKind, source.distanceKind = "hitbox", "hitbox"
    source.targetAuras = {}
    source.pet = true
    source.actors.pet = {
        health = 105, healthMax = 105, resource = 100, resourceMax = 100,
        targetExists = true, targetGuid = source.targetGUID,
        targetsCurrent = true, hasAggro = true, distance = 20,
        distanceKind = "hitbox", lineOfSight = true, behind = false,
        autocasts = { {
            name = "Firebolt", actor = "pet", kind = "damage",
            facts = { kind = "damage", damageActor = "pet", ranged = true },
            power = 8.5, cost = 10, cooldown = 2, readyIn = 0.35,
            tooltip = { school = 2, cost = 10, cast = 0 },
        } },
    }
    return source, {
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
end

local function rankHeavyWarlock()
    local source = Fixture.State("smart")
    source.inCombat = true
    source.resource, source.resourceMax = 1000, 1000
    source.actors.player.resource, source.actors.player.resourceMax = 1000, 1000
    source.targetHealth, source.targetMax = 2000, 2000
    source.targetDistance, source.distance = 20, 20
    source.targetDistanceKind, source.distanceKind = "hitbox", "hitbox"
    source.targetAuras = {}
    source.pet, source.actors.pet = false, nil
    local actions, rank = {}, nil
    for rank = 1, 48 do
        table.insert(actions, Fixture.Action("Shadow Bolt", rank, "damage",
            rank * 2, 5, { cast = 1.7, testSchool = 5 }))
    end
    table.insert(actions, Fixture.Action("Corruption", 1, "dot", 400, 35,
        { cast = 1.5, testDuration = 12,
            testPeriodicInterval = 3, testSchool = 5 }))
    return source, actions
end

local function rankHeavyCaster(spellName, school)
    local source = Fixture.State("smart")
    source.inCombat = true
    source.resource, source.resourceMax = 4200, 4200
    source.actors.player.resource, source.actors.player.resourceMax = 4200, 4200
    source.targetHealth, source.targetMax = 12000, 12000
    source.targetDistance, source.distance = 24, 24
    source.targetDistanceKind, source.distanceKind = "hitbox", "hitbox"
    source.targetAuras = {}
    source.pet, source.actors.pet = false, nil
    local actions, rank = {}, nil
    for rank = 1, 48 do
        table.insert(actions, Fixture.Action(spellName, rank, "damage",
            80 + rank * 4, 20 + rank, { cast = 2.5,
                testSchool = school, ranged = true }))
    end
    return source, actions
end

local function rankHeavyDruid()
    return rankHeavyCaster("Wrath", 3)
end

local function rankHeavyMage()
    return rankHeavyCaster("Frostbolt", 4)
end

local function rankHeavyShaman()
    return rankHeavyCaster("Lightning Bolt", 3)
end

local function levelFourWarrior()
    local source = Fixture.State("smart")
    source.inCombat = false
    source.resource, source.resourceMax, source.resourceType = 0, 100, 1
    source.actors.player.resource, source.actors.player.resourceMax = 0, 100
    source.targetHealth, source.targetMax = 200, 200
    source.targetDistance, source.distance = 15, 15
    source.targetDistanceKind, source.distanceKind = "hitbox", "hitbox"
    source.playerBehindTarget = false
    source.playerAttack = { supported = true, active = false,
        activeKnown = true, pending = false, clockKnown = true }
    AttackTarget = function() end
    local facts, key, value = {}, nil, nil
    for key, value in pairs(XelAssist.Combat.Knowledge.Charge) do
        facts[key] = value
    end
    facts.testMinRange, facts.testMaxRange = 8, 25
    facts.testCategoryCooldown, facts.testGroup = 15, 44
    local charge = Fixture.Action("Charge", 1, "engage", 0, 0, facts)
    charge.executor, charge.spellId = "playerSpell", 100
    local attack = Fixture.Action("Attack", 1, "command", 0, 0,
        { playerAttack = true, ambient = true, startOnly = true,
            recovery = true, melee = true, whiteAttack = true,
            weaponHand = "main", gcd = 0, effectMaxRange = 5,
            effectRangeHitbox = true })
    attack.executor, attack.spellId = "playerSpell", 6603
    local rend = Fixture.Action("Rend", 1, "dot", 45, 10,
        { melee = true, testMinRange = 0, testMaxRange = 5,
            testDuration = 9, testPeriodicInterval = 3 })
    rend.executor, rend.spellId = "playerSpell", 772
    return source, { charge, attack, rend }
end

local cases = {
    { name = "level-4 Warrior Charge", depth = 3,
        Build = levelFourWarrior, expected = "Charge",
        maxFactCalls = 3, rootRangeCalls = 2,
        maxSlices = 5, maxActive = 10, maxSlice = 3.23, maxExpanded = 20 },
    { name = "level-7 Warlock pet and DoTs", depth = 4,
        Build = levelSevenWarlock, expected = "Corruption" },
    { name = "rank-heavy Warlock", depth = 3,
        Build = rankHeavyWarlock, expected = "Corruption" },
    { name = "rank-heavy Druid caster", depth = 3,
        Build = rankHeavyDruid, expected = "Wrath" },
    { name = "rank-heavy Mage caster", depth = 3,
        Build = rankHeavyMage, expected = "Frostbolt" },
    { name = "rank-heavy Shaman caster", depth = 3,
        Build = rankHeavyShaman, expected = "Lightning Bolt" },
}

local index
for index = 1, table.getn(cases) do
    local case = cases[index]
    local sync = synchronous(case)
    local split = sliced(case)
    assert(sync.signature == split.signature,
        case.name .. " sync/sliced plan mismatch:\n" .. sync.signature
            .. "\n" .. split.signature)
    assert(sync.metrics.active == split.metrics.active,
        case.name .. " slicing changed production operation cost")
    assert(sync.metrics.calls.scoring == split.metrics.calls.scoring
        and sync.metrics.calls.transition == split.metrics.calls.transition,
        case.name .. " slicing repeated or skipped a graph edge")
    local factCalls = split.metrics.calls["action facts"] or 0
    local factsBounded = case.maxFactCalls
        and factCalls >= case.actionCount and factCalls <= case.maxFactCalls
        or factCalls == case.actionCount
    local rangeCalls = split.metrics.calls["root range"] or 0
    local rangeExpected = case.rootRangeCalls or case.actionCount
    assert(factsBounded
        and split.metrics.calls["spell cooldown"] == case.actionCount
        and split.metrics.calls["spell usability"] == case.actionCount
        and rangeCalls == rangeExpected,
        case.name .. " performed a mutable root query after sealing evidence: facts="
            .. tostring(factCalls) .. " cooldown="
            .. tostring(split.metrics.calls["spell cooldown"]) .. " usability="
            .. tostring(split.metrics.calls["spell usability"]) .. " range="
            .. tostring(split.metrics.calls["root range"]) .. " actions="
            .. tostring(case.actionCount))
    assert(split.plan.action.name == case.expected,
        case.name .. " fixture drifted to " .. tostring(split.plan.action.name))
    if case.maxSlices then
        assert(split.session.slices <= case.maxSlices
            and split.plan.elapsed <= case.maxActive
            and split.plan.maxSliceMs <= case.maxSlice
            and split.plan.expanded <= case.maxExpanded,
            case.name .. " exceeded its low-level performance ceiling: slices="
                .. tostring(split.session.slices) .. " active="
                .. tostring(split.plan.elapsed) .. " max="
                .. tostring(split.plan.maxSliceMs) .. " expanded="
                .. tostring(split.plan.expanded))
    end
    print(string.format(
        "ok: %s slices=%d active=%.2fms wall=%.2fms max-slice=%.2fms expanded=%d",
        case.name, split.session.slices, split.plan.elapsed, split.wall,
        split.plan.maxSliceMs, split.plan.expanded))
end

print("search session production graph benchmark passed")
