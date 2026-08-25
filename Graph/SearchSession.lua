-- Explicit Lua 5.0-compatible graph search continuation. Each Resume call
-- advances table cursors until its active-time slice is spent. Only a fully
-- completed path reaches PlanBuilder; callers never observe a partial plan.
XelAssist.Graph.SearchSession = {}
local S = XelAssist.Graph.SearchSession
local G = XelAssist.Graph
local Targets = G.Targets
local Scoring = G.Scoring
local Transitions = G.Transitions
local Policy = G.SearchPolicy
local SearchBranches = G.SearchBranches
local Diagnostics = G.PlanDiagnostics
local MovementSetup = G.MovementSetup
local PlanBuilder = G.PlanBuilder
local Timeline = G.Timeline

local function stringField(value)
    if type(value) == "string" then return value end
    return ""
end

local function candidatePriority(candidate)
    local delay = math.max(0, tonumber(candidate.wait) or 0)
        + math.max(0, tonumber(candidate.cast) or 0)
    return (tonumber(candidate.value) or 0)
        / (1 + delay / Policy.DISCOUNT_SECONDS)
end

local function candidateBefore(a, b)
    local aValue, bValue = candidatePriority(a), candidatePriority(b)
    if aValue ~= bValue then return aValue > bValue end
    local aRank = tonumber(a.action and a.action.rank) or 0
    local bRank = tonumber(b.action and b.action.rank) or 0
    if aRank ~= bRank then return aRank > bRank end
    local aName = stringField(a.action and a.action.name)
    local bName = stringField(b.action and b.action.name)
    if aName ~= bName then return aName < bName end
    local aPriority, bPriority = tonumber(a.targetPriority) or 99,
        tonumber(b.targetPriority) or 99
    if aPriority ~= bPriority then return aPriority < bPriority end
    local aTarget = stringField(a.targetRelation) .. "\001"
        .. stringField(a.targetSource) .. "\001" .. stringField(a.target)
    local bTarget = stringField(b.targetRelation) .. "\001"
        .. stringField(b.targetSource) .. "\001" .. stringField(b.target)
    if aTarget ~= bTarget then return aTarget < bTarget end
    return (a.graphOrder or 0) < (b.graphOrder or 0)
end

local function availableActions()
    local out, actions, i = {}, XelAssist.Game.Actors:Actions(), nil
    for i = 1, table.getn(actions) do table.insert(out, actions[i]) end
    if XelAssist.Game.Inventory then
        actions = XelAssist.Game.Inventory:Actions()
        for i = 1, table.getn(actions) do table.insert(out, actions[i]) end
    end
    return out
end

local function retainCandidate(buckets, candidate, order)
    candidate.graphOrder = order
    local key = stringField(candidate.action.actor or "player") .. "\001"
        .. stringField(candidate.action.name)
    local bucket = buckets[key]
    if not bucket then bucket = {}; buckets[key] = bucket end
    local targetKey = candidate.targetKey
    if targetKey == nil then targetKey = candidate.target or false end
    local prior = bucket[targetKey]
    if not prior or candidateBefore(candidate, prior) then
        bucket[targetKey] = candidate
    end
end

local function flattenCandidates(buckets)
    local out, _, bucket, candidate = {}, nil, nil, nil
    for _, bucket in pairs(buckets) do
        for _, candidate in pairs(bucket) do table.insert(out, candidate) end
    end
    table.sort(out, candidateBefore)
    return out
end

local function copySteps(steps, candidate)
    local out, i = {}, nil
    for i = 1, table.getn(steps) do out[i] = steps[i] end
    table.insert(out, candidate)
    return out
end

local function inheritSpatial(candidate, path)
    if path.movementSetupTargetGUID
        and candidate.targetGUID == path.movementSetupTargetGUID then
        candidate.spatialConditions = candidate.spatialConditions or {}
        local condition = { kind = "range", stage = "command",
            actor = candidate.action.actor or "player",
            target = candidate.targetGUID, assumption = "move",
            conditionalOnly = true, movementSetup = true,
            detail = "player must complete the preceding range adjustment" }
        condition.fingerprint = "range:command:" .. tostring(condition.actor)
            .. ":" .. tostring(condition.target) .. ":move::"
        table.insert(candidate.spatialConditions, condition)
        candidate.spatialConditionFingerprint =
            candidate.spatialConditionFingerprint
                and candidate.spatialConditionFingerprint .. "|"
                    .. condition.fingerprint
                or condition.fingerprint
        candidate.spatialConditionalOnly = true
    end
    if not path.spatialConditions then return end
    if not candidate.spatialConditions then
        candidate.spatialConditions = path.spatialConditions
        candidate.spatialConditionFingerprint = path.spatialConditionFingerprint
    else
        local merged, i = {}, nil
        for i = 1, table.getn(path.spatialConditions) do
            table.insert(merged, path.spatialConditions[i])
        end
        for i = 1, table.getn(candidate.spatialConditions) do
            table.insert(merged, candidate.spatialConditions[i])
        end
        candidate.spatialConditions = merged
        candidate.spatialConditionFingerprint = path.spatialConditionFingerprint
            .. "|" .. candidate.spatialConditionFingerprint
    end
    if path.spatialConditionalOnly then candidate.spatialConditionalOnly = true end
end

local function pathBefore(a, b)
    if a.total ~= b.total then return a.total > b.total end
    if a.conditionalTotal ~= b.conditionalTotal then
        return a.conditionalTotal > b.conditionalTotal
    end
    return (a.graphOrder or 0) < (b.graphOrder or 0)
end

local function beginTop(session, path)
    session.top = { state = path.state, buckets = {}, blockers = {},
        order = 0, actionIndex = 1, targetIndex = 1, stage = "action" }
end

local function advanceTop(session)
    local top, actions = session.top, session.actions
    if top.stage == "action" then
        if top.actionIndex > table.getn(actions) then
            top.stage = "flatten"
        else
            top.targets = Targets:Targets(actions[top.actionIndex], top.state)
            top.targetIndex, top.stage = 1, "target"
        end
    elseif top.stage == "target" then
        if top.targetIndex > table.getn(top.targets) then
            top.actionIndex, top.targets = top.actionIndex + 1, nil
            top.stage = "action"
        else
            local action, target = actions[top.actionIndex],
                top.targets[top.targetIndex]
            top.targetIndex = top.targetIndex + 1
            session.counter.count = session.counter.count + 1
            local candidate, blocker = Scoring:Evaluate(action, top.state, target)
            if candidate then
                top.order = top.order + 1
                retainCandidate(top.buckets, candidate, top.order)
            elseif blocker then
                session.counter.blockers[blocker] =
                    (session.counter.blockers[blocker] or 0) + 1
                Diagnostics:Record(top.blockers, blocker, action, target)
            end
        end
    elseif top.stage == "flatten" then
        top.candidates = flattenCandidates(top.buckets)
        top.stage = "movement"
    elseif top.stage == "movement" then
        local candidate = MovementSetup and MovementSetup:Candidate(
            top.state, top.blockers)
        if candidate then table.insert(top.candidates, candidate) end
        top.stage = "channel"
    elseif top.stage == "channel" then
        local candidate = G.ChannelCommitment
            and G.ChannelCommitment:Candidate(top.state)
        if candidate then table.insert(top.candidates, candidate) end
        top.stage = "wand"
    elseif top.stage == "wand" then
        local candidate = G.WandCommitment
            and G.WandCommitment:Candidate(top.state)
        if candidate then table.insert(top.candidates, candidate) end
        top.stage = "retain"
    elseif top.stage == "retain" then
        SearchBranches:Retain(top.candidates, Policy.WIDTH, candidateBefore)
        top.stage = "done"
    end
    return top.stage == "done"
end

local function topFinished(session)
    local top, path = session.top, session.path
    session.candidates, session.blockers = top.candidates, top.blockers
    session.top = nil
    if session.level == 1 and session.pathIndex == 1 then
        session.counter.rootBlockers = session.blockers.byAction
    end
    if table.getn(session.candidates) == 0 then
        path.terminalBlockers = session.blockers
        table.insert(session.terminal, path)
    end
    session.candidateIndex, session.phase = 1, "candidate"
end

local function advanceCandidate(session)
    local candidate = session.candidates[session.candidateIndex]
    if not candidate then session.phase = "path_finish"; return end
    session.candidateIndex = session.candidateIndex + 1
    if candidate.value <= 0 then return end
    local path = session.path
    inheritSpatial(candidate, path)
    session.pathOrder = session.pathOrder + 1
    local advanced = Transitions:Advance(path.state, candidate)
    local weighted = candidate.value
        * Policy:Weight(session.rootTime, candidate)
    local conditional = candidate.spatialConditionalOnly == true
    table.insert(session.expanded, {
        state = advanced, steps = copySteps(path.steps, candidate),
        total = path.total + (conditional and 0 or weighted),
        conditionalTotal = path.conditionalTotal
            + (conditional and weighted or 0),
        spatialConditions = candidate.spatialConditions,
        spatialConditionFingerprint = candidate.spatialConditionFingerprint,
        spatialConditionalOnly = conditional,
        movementSetupTargetGUID = candidate.action and candidate.action.facts
            and candidate.action.facts.movementSetup and candidate.targetGUID
            or path.movementSetupTargetGUID,
        graphOrder = session.pathOrder,
    })
end

local function startBudget(session)
    session.budgetStarted = true
    session.budgetResumeStarted = Policy:ClockMilliseconds()
end

local function initializeSearch(session)
    session.rootTime = tonumber(session.state.time) or 0
    session.frontier = { { state = session.state, steps = {}, total = 0,
        conditionalTotal = 0, graphOrder = 1 } }
    session.terminal, session.pathOrder, session.level = {}, 1, 0
    session.phase = "level_start"
end

local function advancePreparation(session)
    local stage = session.prepareStage
    if stage == 1 and Timeline and Timeline.BeginEvaluation then
        Timeline:BeginEvaluation(session.state, session.actions)
    elseif stage == 2 and G.SoulShardReserve
        and G.SoulShardReserve:Relevant(session.actions) then
        G.SoulShardReserve:Prepare(session.state)
    elseif stage == 3 and G.CooldownLedger then
        G.CooldownLedger:Prepare(
            session.state, session.actions, session.observedAt)
    elseif stage == 4 and G.StealthSetup then
        G.StealthSetup:Prepare(session.state, session.actions)
    elseif stage == 5 and G.ChannelCommitment then
        G.ChannelCommitment:Prepare(session.state, session.actions)
    elseif stage == 6 and G.WandCommitment then
        G.WandCommitment:Prepare(session.state, session.actions)
    end
    session.prepareStage = stage + 1
    if session.prepareStage > 6 then initializeSearch(session) end
end

local function finalizePath(session)
    local paths, i = {}, nil
    for i = 1, table.getn(session.frontier) do
        table.insert(paths, session.frontier[i])
    end
    for i = 1, table.getn(session.terminal) do
        table.insert(paths, session.terminal[i])
    end
    table.sort(paths, pathBefore)
    session.path, session.phase = paths[1], "build"
end

local function advanceSearch(session)
    if session.phase == "level_start" then
        session.level = session.level + 1
        if session.level > session.depth then finalizePath(session); return end
        if session.level > 2
            and Policy:BudgetReached(session, session.counter) then
            session.counter.budgetLimited = true
            finalizePath(session)
            return
        end
        session.expanded, session.interrupted, session.pathIndex = {}, false, 1
        session.phase = "path_start"
    elseif session.phase == "path_start" then
        if session.pathIndex > table.getn(session.frontier) then
            session.phase = "level_finish"; return
        end
        session.path = session.frontier[session.pathIndex]
        if Policy:WithinHorizon(session.path.state, session.rootTime) then
            beginTop(session, session.path)
            session.phase = "top"
        else
            session.path.horizonLimited = true
            session.candidates, session.blockers = {}, {}
            session.candidateIndex, session.phase = 1, "candidate"
            if session.level == 1 and session.pathIndex == 1 then
                session.counter.rootBlockers = nil
            end
            session.path.terminalBlockers = session.blockers
            table.insert(session.terminal, session.path)
        end
    elseif session.phase == "top" then
        if advanceTop(session) then topFinished(session) end
    elseif session.phase == "candidate" then
        advanceCandidate(session)
    elseif session.phase == "path_finish" then
        if session.level > 1
            and session.pathIndex < table.getn(session.frontier)
            and Policy:BudgetReached(session, session.counter) then
            session.counter.budgetLimited, session.interrupted = true, true
            session.phase = "level_finish"
        else
            session.pathIndex = session.pathIndex + 1
            session.phase = "path_start"
        end
    elseif session.phase == "level_finish" then
        if table.getn(session.expanded) == 0 then finalizePath(session); return end
        table.sort(session.expanded, pathBefore)
        while table.getn(session.expanded) > Policy.WIDTH do
            table.remove(session.expanded)
        end
        session.frontier = session.expanded
        session.counter.completedDepth = session.level
        if session.interrupted or session.level >= 2
            and Policy:BudgetReached(session, session.counter) then
            session.counter.budgetLimited = true
            finalizePath(session)
        else
            session.phase = "level_start"
        end
    end
end

local function advance(session)
    if session.phase == "snapshot" then
        session.state = G:Snapshot(session.mode)
        session.observed = PlanBuilder:ObservedState(session.state)
        startBudget(session)
        session.phase = "limits"
    elseif session.phase == "limits" then
        session.depth = Policy:Depth()
        session.counter.maxStates, session.counter.maxMs =
            Policy:Limits(session.state)
        session.phase = "actions"
    elseif session.phase == "actions" then
        session.actions = availableActions()
        session.prepareStage, session.phase = 1, "prepare"
    elseif session.phase == "prepare" then
        advancePreparation(session)
    elseif session.phase == "build" then
        if not session.path.steps[1] then
            session.reason = Diagnostics:Reason(
                session.state, session.counter.blockers)
        else
            session.plan = PlanBuilder:Build(session.state, session.observed,
                session.path, session.counter, session, session.observedAt)
        end
        session.fallback, session.status, session.phase = false, "complete", "done"
    else
        advanceSearch(session)
    end
end

local function leaveResume(session)
    local now = Policy:ClockMilliseconds()
    local elapsed = math.max(0, now - (session.resumeStarted or now))
    session.maxSliceMs = math.max(session.maxSliceMs or 0, elapsed)
    if session.budgetResumeStarted ~= nil then
        session.activeMs = (session.activeMs or 0)
            + math.max(0, now - session.budgetResumeStarted)
    end
    session.resumeStarted, session.budgetResumeStarted = nil, nil
end

function S:Begin(mode, preview, observedAt)
    return { xelSearchSession = true, mode = mode, preview = preview,
        observedAt = tonumber(observedAt)
            or (type(GetTime) == "function" and GetTime() or 0),
        counter = { count = 0, blockers = {} }, phase = "snapshot",
        status = "pending", activeMs = 0, slices = 0, maxSliceMs = 0 }
end

function S:Resume(session, sliceMs)
    if type(session) ~= "table" or not session.xelSearchSession then
        return true, nil, "invalid evaluation", false
    end
    if session.status == "cancelled" then
        return true, nil, "cancelled", false
    end
    if session.status == "complete" then
        return true, session.plan, session.reason, session.fallback
    end
    local limit = sliceMs
    if limit == nil then limit = Policy.SLICE_MS end
    session.slices = session.slices + 1
    session.resumeStarted = Policy:ClockMilliseconds()
    if session.budgetStarted then
        session.budgetResumeStarted = session.resumeStarted
    end
    while session.status == "pending" do
        advance(session)
        if session.status == "pending"
            and Policy:SliceReached(session.resumeStarted, limit) then break end
    end
    leaveResume(session)
    if session.status == "complete" and session.plan then
        session.plan.elapsed = session.activeMs
        session.plan.slices = session.slices
        session.plan.maxSliceMs = session.maxSliceMs
    end
    return session.status ~= "pending", session.plan, session.reason,
        session.fallback
end

function S:Cancel(session)
    if type(session) ~= "table" or not session.xelSearchSession
        or session.status ~= "pending" then return false end
    session.status, session.phase, session.cancelled =
        "cancelled", "cancelled", true
    return true
end
