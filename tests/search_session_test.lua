XelAssist = { Core = {}, Game = {}, Graph = {} }
XelAssistCharDB = { graphDepth = 3 }
table.getn = table.getn or function(values) return #values end

local clock, snapshotCalls, buildCalls = 0, 0, 0
function GetTime() return 10 end
function debugprofilestop() return clock end

local actions = {
    { name = "Measured Bolt", rank = 1, actor = "player", facts = {} },
    { name = "Patient Bolt", rank = 1, actor = "player", facts = {} },
}
XelAssist.Game.Actors = { Actions = function() return actions end }

XelAssist.Graph.State = {
    Snapshot = function()
        snapshotCalls, clock = snapshotCalls + 1, clock + 50
        return { time = 0, inCombat = true, playerGcdReadyAt = 0,
            actorReadyAt = { player = 0 }, depth = 0 }
    end,
    ActiveTargetModifiers = function() return {} end,
}
XelAssist.Graph.Targets = {
    Targets = function(_, action)
        return { { unit = "target", key = action.name } }
    end,
}
XelAssist.Graph.Scoring = {
    Evaluate = function(_, action, state)
        clock = clock + 0.55
        local value = action.name == "Measured Bolt" and 10 or 8
        return { action = action, value = value, wait = 0, cast = 0,
            actionStart = state.time, target = "target",
            targetKey = "target", targetRelation = "hostile" }
    end,
}
XelAssist.Graph.Transitions = {
    Advance = function(_, state)
        clock = clock + 0.2
        return { time = state.time + 1, inCombat = true,
            playerGcdReadyAt = 0, actorReadyAt = { player = 0 },
            depth = (state.depth or 0) + 1 }
    end,
}
XelAssist.Graph.SearchBranches = {
    Retain = function(_, candidates, width, before)
        table.sort(candidates, before)
        while table.getn(candidates) > width do table.remove(candidates) end
    end,
}
XelAssist.Graph.PlanDiagnostics = {
    Record = function() end,
    Reason = function() return "No worthwhile action" end,
}
XelAssist.Graph.MovementSetup = { Candidate = function() return nil end }
XelAssist.Graph.PlanBuilder = {
    ObservedState = function(_, state) return { time = state.time } end,
    Build = function(_, state, observed, path, counter, started, observedAt)
        buildCalls = buildCalls + 1
        local names, i = {}, nil
        for i = 1, table.getn(path.steps) do
            table.insert(names, path.steps[i].action.name)
        end
        return { action = path.steps[1].action, names = names,
            expanded = counter.count, completedDepth = counter.completedDepth,
            elapsed = XelAssist.Graph.SearchPolicy:ElapsedMilliseconds(started),
            observedAt = observedAt }
    end,
}

dofile("Graph/SearchPolicy.lua")
dofile("Core/CombatRevision.lua")
dofile("Graph/SearchLifecycle.lua")
local maxStates, maxMilliseconds = 1000, 1000
XelAssist.Graph.SearchPolicy.Limits = function()
    return maxStates, maxMilliseconds
end
dofile("Graph/SearchSession.lua")
dofile("Graph/Engine.lua")

local function signature(plan)
    return table.concat(plan.names, ",") .. ":" .. tostring(plan.expanded)
        .. ":" .. tostring(plan.completedDepth)
end

clock, snapshotCalls, buildCalls = 0, 0, 0
local synchronous = XelAssist.Graph:Evaluate("smart", false, 123)
assert(synchronous and synchronous.action.name == "Measured Bolt",
    "the synchronous compatibility facade must still produce a plan")
assert(snapshotCalls == 1 and buildCalls == 1,
    "a synchronous evaluation must snapshot and publish exactly once")
assert(synchronous.elapsed < 50,
    "snapshot collection must remain outside the search CPU budget")

clock, snapshotCalls, buildCalls = 0, 0, 0
local session = XelAssist.Graph:BeginEvaluation("smart", false, 123)
assert(snapshotCalls == 0 and buildCalls == 0,
    "beginning an evaluation must not synchronously collect live state")
local complete, plan, reason, fallback = false, nil, nil, nil
while not complete do
    complete, plan, reason, fallback =
        XelAssist.Graph:ResumeEvaluation(session)
    if not complete then
        assert(plan == nil and reason == nil,
            "an incomplete slice must never expose a partial plan")
        XelAssist.Core.CombatRevision:Touch("health", "test damage")
        clock = clock + 1000
    end
end
assert(plan and reason == nil and fallback == false,
    "the completed sliced evaluation must publish its final plan")
assert(signature(plan) == signature(synchronous),
    "slicing must preserve the exact selected path and expansion budget")
assert(session.slices > 1 and buildCalls == 1 and snapshotCalls == 1,
    "the default 3 ms policy must genuinely resume across multiple slices")
assert(plan.slices == session.slices and plan.maxSliceMs == session.maxSliceMs,
    "completed plans must retain slice telemetry for live stutter diagnosis")
assert(plan.elapsed < 50,
    "inter-frame idle time must not consume or appear in active graph time")
assert(session.softChanged,
    "ordinary combat drift must be retained without starving completion")

-- The two mandatory levels and aggregate state bound must stop at exactly the
-- same accepted frontier whether that work is continuous or frame-sliced.
XelAssistCharDB.graphDepth, maxStates = 24, 4
clock = 0
local boundedSync = XelAssist.Graph:Evaluate("smart", false, 125)
clock = 0
local boundedSession = XelAssist.Graph:BeginEvaluation("smart", false, 125)
local boundedDone, boundedPlan = false, nil
while not boundedDone do
    boundedDone, boundedPlan =
        XelAssist.Graph:ResumeEvaluation(boundedSession, 1)
    if not boundedDone then clock = clock + 1000 end
end
assert(signature(boundedPlan) == signature(boundedSync)
    and boundedPlan.completedDepth == 2 and boundedPlan.expanded == 4,
    "aggregate state limits must retain the exact mandatory two-level path: "
        .. signature(boundedPlan) .. " / " .. signature(boundedSync))

maxStates, maxMilliseconds, clock = 1000, 2, 0
local timedSync = XelAssist.Graph:Evaluate("smart", false, 125)
clock = 0
local timedSession = XelAssist.Graph:BeginEvaluation("smart", false, 125)
local timedDone, timedPlan = false, nil
while not timedDone do
    timedDone, timedPlan = XelAssist.Graph:ResumeEvaluation(timedSession, 1)
    if not timedDone then clock = clock + 1000 end
end
assert(signature(timedPlan) == signature(timedSync)
    and timedPlan.completedDepth == 2,
    "aggregate active-CPU limits must be identical across frame waits")

-- A generous aggregate budget must remain capable of producing the complete
-- strategic runway even though no individual frame owns the whole search.
maxStates, maxMilliseconds, XelAssistCharDB.graphDepth, clock =
    1000, 1000, 24, 0
local deep = XelAssist.Graph:BeginEvaluation("smart", false, 126)
local deepDone, deepPlan = false, nil
while not deepDone do
    deepDone, deepPlan = XelAssist.Graph:ResumeEvaluation(deep, 1)
    if not deepDone then clock = clock + 1000 end
end
assert(table.getn(deepPlan.names) == 24 and deepPlan.completedDepth == 24,
    "frame slicing must not shorten the full 24-decision graph runway")

local cancelled = XelAssist.Graph:BeginEvaluation("smart", false, 124)
local beforeCancelBuilds = buildCalls
assert(XelAssist.Graph:CancelEvaluation(cancelled),
    "a pending evaluation must be cancellable")
complete, plan, reason, fallback =
    XelAssist.Graph:ResumeEvaluation(cancelled, 1)
assert(complete and plan == nil and reason == "cancelled"
    and fallback == false and buildCalls == beforeCancelBuilds,
    "a cancelled evaluation must never reach PlanBuilder")
assert(not XelAssist.Graph:CancelEvaluation(cancelled),
    "cancellation must be idempotent for an already terminal session")

local stale = XelAssist.Graph:BeginEvaluation("smart", false, 127)
local staleDone = XelAssist.Graph:ResumeEvaluation(stale, 0.1)
assert(not staleDone, "the hard-change fixture must pause between slices")
local buildsBeforeHardChange = buildCalls
XelAssist.Core.CombatRevision:Hard("target topology changed")
local stalePlan, staleReason
staleDone, stalePlan, staleReason =
    XelAssist.Graph:ResumeEvaluation(stale, 0.1)
assert(staleDone and stalePlan == nil and stale.status == "stale"
    and stale.stale and staleReason ==
        "combat topology changed during evaluation"
    and buildCalls == buildsBeforeHardChange,
    "a hard revision must terminate old work without reaching PlanBuilder")

print("search session tests passed")
