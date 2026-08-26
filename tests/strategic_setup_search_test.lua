XelAssist = { Core = {}, Game = { Player = { PriestInnerFocus = {
    SPELL_ID = 14751, COST_MASK = 3606577115,
    CRIT_MASK = 3646176912, COST_PERCENT = -100,
} } }, Graph = {} }
XelAssistCharDB = { graphDepth = 3 }
table.getn = table.getn or function(values) return #values end

local clock = 0
function GetTime() return 10 end
function debugprofilestop() return clock end

dofile("Graph/PriestInnerFocus.lua")
dofile("Graph/Candidate.lua")
local Candidate = XelAssist.Graph.Candidate

local function built(action, state, value, tooltip)
    local relation = tooltip and (tooltip.warriorStanceTransition
        or tooltip.druidFormTransition or tooltip.priestShadowformTransition
        or tooltip.priestInnerFocusTransition)
        and "self" or "hostile"
    return Candidate:Build({ action = action, facts = action.facts,
        state = state or {}, tooltip = tooltip or {}, value = value,
        reason = value > 0 and "positive outcome" or "mechanical setup",
        descriptor = { key = action.name, guid = action.name,
            relation = relation, source = "test", castUnit = relation == "self"
                and "player" or "target" },
        target = relation == "self" and "player" or "target",
        cost = 0, costKnown = true, cast = 0, advanceDowntime = 1,
        downtime = 1, wait = 0, occupancy = 1, gcd = 1.5,
        normalGcd = true, actionStart = tonumber(state and state.time) or 0,
        expectedPower = math.max(0, value), power = math.max(0, value),
        effectDelivery = 1 })
end

local warriorAction = { name = "Haltung", rank = 1, actor = "player",
    facts = { kind = "buff" } }
local warriorTransition = { kind = "warriorStance", sourceForm = 17,
    targetForm = 18 }
local warrior = built(warriorAction, {}, 0,
    { warriorStanceTransition = warriorTransition })
local translated = built({ name = "Postura", rank = 1, actor = "player",
    facts = warriorAction.facts }, {}, 0,
    { warriorStanceTransition = warriorTransition })
assert(warrior.strategicSetup == true
    and warrior.strategicSetupKey == "warriorStance:17>18"
    and warrior.strategicSetupSourceForm == 17
    and warrior.strategicSetupTargetForm == 18
    and warrior.strategicSetupConsumerKey == "playerForm:18"
    and translated.strategicSetupKey == warrior.strategicSetupKey,
    "stance setup identity must derive only from its mechanical transition")

local druid = built({ name = "Forma", rank = 1, actor = "player",
    facts = { kind = "buff" } }, {}, 0, { druidFormTransition = {
        kind = "shift", sourceForm = 0, targetForm = 1 } })
assert(druid.strategicSetup == true
    and druid.strategicSetupKey == "druidForm:0>1",
    "Druid shifts must receive a distinct stable mechanical setup key")
local priest = built({ name = "Opaque form", rank = 1, actor = "player",
    facts = { kind = "form" } }, {}, 0, { priestShadowformTransition = {
        kind = "priestShadowform", sourceForm = 0, targetForm = 28 } })
assert(priest.strategicSetup == true
    and priest.strategicSetupKey == "priestShadowform:0>28"
    and priest.strategicSetupConsumerKey == "playerForm:28"
    and priest.priestShadowformTransition.targetForm == 28,
    "Shadowform must use the same neutral destination-consumer setup lane")
local focusTransition = { kind = "priestInnerFocus", spellId = 14751,
    charges = 1, indefinite = true, costMask = 3606577115,
    critMask = 3646176912, costPercent = -100, evidenceExact = true }
local focus = built({ name = "Opaque modifier", rank = 1, actor = "player",
    facts = { kind = "modifier" } }, {}, 0,
    { priestInnerFocusTransition = focusTransition })
assert(focus.strategicSetup == true
    and focus.strategicSetupKey == "priestInnerFocus:14751"
    and focus.strategicSetupSourceForm == nil
    and focus.strategicSetupTargetForm == nil
    and focus.strategicSetupConsumerKey
        == "priestInnerFocus:affectedCost",
    "Inner Focus must open a stable non-form setup lane with no fixed utility")
local malformed = built(warriorAction, {}, 0, { warriorStanceTransition = {
    kind = "warriorStance", sourceForm = 17, targetForm = "18" } })
assert(malformed.strategicSetup == nil
    and malformed.strategicSetupKey == nil,
    "coerced transition identities must fail closed")

dofile("Graph/SearchBranches.lua")
dofile("Graph/ResourceInvestment.lua")
local Branches, Investment = XelAssist.Graph.SearchBranches,
    XelAssist.Graph.ResourceInvestment

local movement = built({ name = "Move into range", rank = 0,
    actor = "player", facts = { kind = "movement", movementSetup = true } },
    {}, 0, { targetGUID = "enemy" })
movement.targetGUID = "enemy"
local afterMovement = Investment:Advance({ state = { resource = 100 } },
    movement, {})
local movedAttack = built({ name = "Frostbolt", rank = 1,
    actor = "player", facts = { kind = "damage" } }, {}, 100,
    { targetGUID = "enemy" })
movedAttack.targetGUID, movedAttack.spatialConditionalOnly = "enemy", true
local completedMovement = Investment:Advance(afterMovement, movedAttack, {})
assert(Investment:Expandable(movement, { state = {} })
    and afterMovement.movementSetupOpen == true
    and not Investment:Eligible(afterMovement)
    and completedMovement.movementSetupOpen == nil
    and Investment:Eligible(completedMovement),
    "movement must remain unpublished until a worthwhile target-matched action consumes it")
local wrongTarget = built({ name = "Frostbolt", rank = 1,
    actor = "player", facts = { kind = "damage" } }, {}, 100,
    { targetGUID = "other" })
wrongTarget.targetGUID, wrongTarget.spatialConditionalOnly = "other", true
assert(not Investment:Eligible(Investment:Advance(
        afterMovement, wrongTarget, {})),
    "movement must not be justified by a different target's future action")

local druidCancel = built({ name = "Cancel Form", rank = 1,
    actor = "player", facts = { kind = "buff" } }, {}, 0,
    { druidFormTransition = { kind = "cancel", sourceForm = 1,
        targetForm = 0 } })
local casterOnly = built({ name = "Caster Consumer", rank = 1,
    actor = "player", facts = { kind = "damage" } }, {}, 50,
    { stancesNot = 1 })
local openCancel = Investment:Advance({ state = { resource = 0 } },
    druidCancel, {})
local closedCancel = Investment:Advance(openCancel, casterOnly, {})
assert(openCancel.strategicSetupOpen == true
    and closedCancel.strategicSetupOpen == nil,
    "an exact excluded-source mask must consume a Druid cancellation setup")

local explicitConsumer = built({ name = "Explicit Consumer", rank = 1,
    actor = "player", facts = { kind = "damage" } }, {}, 50,
    { setupConsumerKey = "playerForm:18" })
local openWarrior = Investment:Advance({ state = { resource = 0 } },
    warrior, {})
assert(Investment:Advance(openWarrior, explicitConsumer, {})
        .strategicSetupOpen == nil,
    "an explicit mechanical consumer key must close only its matching setup")
assert(Investment:PotentialConsumer(openWarrior, {}, { stances = 131072 })
    and not Investment:PotentialConsumer(openWarrior, {},
        { stances = "131072" })
    and not Investment:PotentialConsumer(openWarrior, {}, nil)
    and not Investment:PotentialConsumer(openWarrior, {},
        { stances = 65536 + 131072 }),
    "setup consumer prefiltering must require an exact sealed destination mask")

local focusConsumer = built({ name = "Opaque heal", rank = 1,
    actor = "player", facts = { kind = "heal" } }, {}, 50,
    { priestInnerFocusCost = { claimed = true, exact = true,
        costAffected = true, baselineCost = 155 } })
local openFocus = Investment:Advance({ state = { resource = 500 } }, focus, {})
assert(Investment:IsStrategic(focus)
    and openFocus.strategicSetupOpen == true
    and Investment:PotentialConsumer(openFocus, focusConsumer.action,
        focusConsumer.tooltip)
    and Investment:Advance(openFocus, focusConsumer, {})
        .strategicSetupOpen == nil,
    "one exact affected-cost action must close the bounded Inner Focus lane")
local falseConsumer = { priestInnerFocusCost = { claimed = true, exact = false,
    costAffected = true, baselineCost = 155 } }
assert(not Investment:PotentialConsumer(
    openFocus, focusConsumer.action, falseConsumer),
    "an unsealed cost contract must not keep the Inner Focus setup lane alive")

local function candidateBefore(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return (a.graphOrder or 0) < (b.graphOrder or 0)
end

local function branch(name, value, key, order)
    return { action = { name = name, facts = {} }, value = value,
        graphOrder = order, actionStart = 0, tooltip = {},
        strategicSetup = key and true or nil, strategicSetupKey = key }
end

local branchFixture = {
    branch("ordinary one", 20, nil, 1),
    branch("ordinary two", 19, nil, 2),
    branch("ordinary three", 18, nil, 3),
    branch("inferior A", -1, "druidForm:0>1", 4),
    branch("best A", 0, "druidForm:0>1", 5),
    branch("only B", 0, "warriorStance:17>18", 6),
}
Branches:Retain(branchFixture, 4, candidateBefore)
local counts, name, i = {}, nil, nil
for i = 1, table.getn(branchFixture) do
    local item = branchFixture[i]
    if item.strategicSetupKey then
        counts[item.strategicSetupKey] =
            (counts[item.strategicSetupKey] or 0) + 1
        if item.strategicSetupKey == "druidForm:0>1" then
            name = item.action.name
        end
    end
end
assert(table.getn(branchFixture) == 4
    and counts["druidForm:0>1"] == 1
    and counts["warriorStance:17>18"] == 1 and name == "best A",
    "candidate pruning must add exactly one best lane per setup key")

local paths = {
    { total = 50, conditionalTotal = 0, graphOrder = 1 },
    { total = 2, conditionalTotal = 0, graphOrder = 2,
        strategicSetupOpen = true, strategicSetupKey = "druidForm:0>1" },
    { total = 3, conditionalTotal = 0, graphOrder = 3,
        strategicSetupOpen = true, strategicSetupKey = "druidForm:0>1" },
    { total = 1, conditionalTotal = 0, graphOrder = 4,
        strategicSetupOpen = true,
        strategicSetupKey = "warriorStance:17>18" },
}
local function pathBefore(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.graphOrder < b.graphOrder
end
Investment:Retain(paths, 3, pathBefore)
assert(table.getn(paths) == 3 and paths[1].strategicSetupOpen
    and paths[2].strategicSetupOpen and paths[3].total == 50
    and paths[1].strategicSetupKey == "druidForm:0>1"
    and paths[1].total == 3,
    "frontier pruning must retain and schedule one best open lane per key")

local defensiveAction = { name = "Defensive Stance", rank = 1,
    actor = "player", facts = { kind = "buff" } }
local berserkerAction = { name = "Berserker Stance", rank = 1,
    actor = "player", facts = { kind = "buff" } }
local returnAction = { name = "Return Battle", rank = 1,
    actor = "player", facts = { kind = "buff" } }
local gatedAction = { name = "Huge Gated", rank = 1, actor = "player",
    facts = { kind = "damage", stances = 262144 } }
local timedAction = { name = "Timed Unrelated", rank = 1, actor = "player",
    facts = { kind = "damage" } }
local targetForms = { [defensiveAction] = 18, [berserkerAction] = 19,
    [returnAction] = 17 }
local directActions, directValues, index = {}, {}, nil
for index = 1, 99 do
    local action = { name = string.format("Direct %03d", index), rank = 1,
        actor = "player", facts = { kind = "damage" } }
    directActions[index], directValues[action] = action, index
end

local actionList, gatedValue, depthOneOrder, seenDepthStates = {}, 1000, {}, {}
local advancedTransitions, consumerProbes, stateLimit = {}, {}, 5
local rootProbeCount = 0
local function configure(kind, huge, strongestDirect, reverse)
    actionList, gatedValue, depthOneOrder, seenDepthStates = {}, huge, {}, {}
    advancedTransitions, consumerProbes, rootProbeCount = {}, {}, 0
    local actions = {}
    if kind == "setupOnly" then
        table.insert(actions, defensiveAction)
    elseif kind == "implicitWait" then
        table.insert(actions, defensiveAction)
        table.insert(actions, timedAction)
    else
        for index = 1, table.getn(directActions) do
            directValues[directActions[index]] = 10
            table.insert(actions, directActions[index])
        end
        if strongestDirect then directValues[directActions[99]] = strongestDirect end
        table.insert(actions, defensiveAction)
        table.insert(actions, berserkerAction)
        table.insert(actions, returnAction)
        table.insert(actions, gatedAction)
    end
    if reverse then
        for index = table.getn(actions), 1, -1 do
            table.insert(actionList, actions[index])
        end
    else
        actionList = actions
    end
end

XelAssist.Game.Actors = { Actions = function() return actionList end }
XelAssist.Graph.State = { Snapshot = function()
    return { time = 0, depth = 0, form = 17, pathName = "root",
        inCombat = true, playerGcdReadyAt = 0,
        actorReadyAt = { player = 0 } }
end }
function XelAssist.Graph:Snapshot(mode) return self.State:Snapshot(mode) end
XelAssist.Graph.Targets = { Targets = function() return { "target" } end }
XelAssist.Graph.Scoring = { Evaluate = function(_, action, state)
    clock = clock + 0.01
    if state.depth == 0 then rootProbeCount = rootProbeCount + 1 end
    if state.depth == 1 then table.insert(consumerProbes, action.name) end
    if directValues[action] then
        return built(action, state, directValues[action])
    end
    local targetForm = targetForms[action]
    if targetForm then
        if state.form == targetForm then return nil, "already in stance" end
        return built(action, state, 0, { warriorStanceTransition = {
            kind = "warriorStance", sourceForm = state.form,
            targetForm = targetForm } })
    end
    if action == gatedAction then
        if state.form ~= 19 then return nil, "required stance" end
        return built(action, state, gatedValue, { stances = 262144 })
    end
    if action == timedAction then
        if state.time < 1.5 then return nil, "not ready" end
        return built(action, state, 1000)
    end
    return nil, "unavailable"
end }
XelAssist.Graph.Transitions = { Advance = function(_, state, candidate)
    clock = clock + 0.005
    if candidate.strategicSetup then
        table.insert(advancedTransitions, candidate.action.name)
    end
    return { time = state.time + 1.5, depth = state.depth + 1,
        form = candidate.strategicSetupTargetForm or state.form,
        pathName = candidate.action.name, inCombat = true,
        playerGcdReadyAt = 0, actorReadyAt = { player = 0 } }
end }
XelAssist.Graph.PlanDiagnostics = {
    Record = function() end,
    Reason = function() return "No eligible endpoint" end,
}
XelAssist.Graph.MovementSetup = { Candidate = function() return nil end }
XelAssist.Graph.RootObservation = { Facts = function(_, state, action)
    if state.depth == 1 and not seenDepthStates[state] then
        seenDepthStates[state] = true
        table.insert(depthOneOrder, state.pathName)
    end
    return action.facts, "known"
end }
XelAssist.Graph.PlanBuilder = {
    ObservedState = function() return {} end,
    Build = function(_, _, _, path, counter)
        local names = {}
        for index = 1, table.getn(path.steps) do
            table.insert(names, path.steps[index].action.name)
        end
        return { action = path.steps[1].action, names = names,
            total = path.total, expanded = counter.count }
    end,
}

dofile("Graph/SearchPolicy.lua")
XelAssist.Graph.SearchPolicy.WIDTH = 5
XelAssist.Graph.SearchPolicy.Limits = function()
    return stateLimit, 1000000
end
dofile("Graph/SearchSession.lua")
local Session = XelAssist.Graph.SearchSession

local function evaluate(kind, huge, strongestDirect, slice, reverse, limit)
    configure(kind, huge, strongestDirect, reverse)
    stateLimit = limit or 5
    clock = 0
    local session = Session:Begin("smart", false, 100)
    local done, plan, reason = false, nil, nil
    while not done do
        done, plan, reason = Session:Resume(session, slice)
        if not done then clock = clock + 1000 end
    end
    return plan, reason, table.concat(depthOneOrder, ","), session.slices,
        table.concat(advancedTransitions, ","), session.counter.budgetLimited,
        rootProbeCount, session.counter.count, table.concat(consumerProbes, ",")
end

local setupPlan, setupReason, setupExpansion, setupSlices,
    setupTransitions, setupBudget, setupRootProbes, setupTotalProbes,
    setupConsumerProbes =
    evaluate("crowded", 1000, nil, 0.2)
assert(setupPlan and setupReason == nil and setupPlan.action == berserkerAction
    and table.concat(setupPlan.names, ",") == "Berserker Stance,Huge Gated"
    and setupExpansion == "Defensive Stance,Berserker Stance"
    and not string.find(setupTransitions, "Return Battle", 1, true)
    and setupSlices > 1 and setupBudget == true
    and setupTotalProbes <= setupRootProbes + 2
    and setupConsumerProbes == "Huge Gated",
    "both reserved setup keys must expand once before the tight budget ends")
local continuous = evaluate("crowded", 1000, nil, 1000)
assert(continuous and table.concat(continuous.names, ",")
        == table.concat(setupPlan.names, ",")
    and continuous.expanded == setupPlan.expanded,
    "frame slicing must preserve deterministic strategic setup results")
local reversed, _, reversedExpansion =
    evaluate("crowded", 1000, nil, 0.2, true)
assert(reversed and table.concat(reversed.names, ",")
        == table.concat(setupPlan.names, ",")
    and reversed.expanded == setupPlan.expanded
    and reversedExpansion == setupExpansion,
    "action insertion reversal must not change setup scheduling or result")

local directPlan, directReason, directExpansion =
    evaluate("crowded", 1000, 2000, 0.2)
assert(directPlan and directReason == nil and directPlan.action == directActions[99]
    and table.getn(directPlan.names) == 1
    and directExpansion == "Defensive Stance,Berserker Stance",
    "an unexpanded stronger direct endpoint must remain available and win")

local setupOnly, setupOnlyReason = evaluate("setupOnly", 0, nil, 0.2)
assert(setupOnly == nil and setupOnlyReason == "No eligible endpoint",
    "an unresolved setup-only path must never become a recommendation")

local waited, waitedReason, _, _, waitTransitions =
    evaluate("implicitWait", 0, nil, 0.2)
assert(waited == nil and waitedReason == "No eligible endpoint"
    and waitTransitions == "Defensive Stance",
    "setup time must not unlock an unrelated positive endpoint or a cycle")

print("strategic setup search: ok")
