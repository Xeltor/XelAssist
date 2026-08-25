-- Public action-graph facade and bounded beam search. Domain modules own state
-- observation, target legality, scoring, effects, and transitions; this file
-- only coordinates them into a deterministic recommendation.
local G = XelAssist.Graph
local State = G.State
local Targets = G.Targets
local Scoring = G.Scoring
local Transitions = G.Transitions
local Policy = G.SearchPolicy
local SearchBranches = G.SearchBranches
local Diagnostics = G.PlanDiagnostics
local MovementSetup = G.MovementSetup
local PlanBuilder = G.PlanBuilder
local Timeline = G.Timeline

function G:ActiveTargetModifiers(encounter, targetResistance)
    return State:ActiveTargetModifiers(encounter, targetResistance)
end

function G:Snapshot(mode)
    return State:Snapshot(mode)
end

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

local function actionBucketKey(action)
    return stringField(action.actor or "player") .. "\001"
        .. stringField(action.name)
end

local function retainCandidate(buckets, candidate, order)
    candidate.graphOrder = order
    local actionKey = actionBucketKey(candidate.action)
    local bucket = buckets[actionKey]
    if not bucket then bucket = {}; buckets[actionKey] = bucket end
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

local function topCandidates(state, counter, actions)
    local buckets, blockers, order = {}, {}, 0
    local i, targets, targetIndex, candidate, blocker
    for i = 1, table.getn(actions) do
        targets = Targets:Targets(actions[i], state)
        for targetIndex = 1, table.getn(targets) do
            -- Count work performed, not only the five candidates retained by
            -- the beam. Rank-heavy classes otherwise never reach the state
            -- budget despite evaluating hundreds of action-target edges.
            counter.count = counter.count + 1
            candidate, blocker = Scoring:Evaluate(
                actions[i], state, targets[targetIndex])
            if candidate then
                order = order + 1
                retainCandidate(buckets, candidate, order)
            elseif blocker then
                counter.blockers[blocker] =
                    (counter.blockers[blocker] or 0) + 1
                Diagnostics:Record(
                    blockers, blocker, actions[i], targets[targetIndex])
            end
        end
    end
    local candidates = flattenCandidates(buckets)
    local movement = MovementSetup and MovementSetup:Candidate(state, blockers)
    if movement then table.insert(candidates, movement) end
    local channel = G.ChannelCommitment and G.ChannelCommitment:Candidate(state)
    if channel then table.insert(candidates, channel) end
    local wand = G.WandCommitment and G.WandCommitment:Candidate(state)
    if wand then table.insert(candidates, wand) end
    SearchBranches:Retain(candidates, Policy.WIDTH, candidateBefore)
    return candidates, blockers
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
        condition.fingerprint = "range:command:"
            .. tostring(condition.actor) .. ":" .. tostring(condition.target)
            .. ":move::"
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

local function bestSearchPath(state, started, counter, depth, actions)
    local rootTime = tonumber(state.time) or 0
    local frontier = { { state = state, steps = {}, total = 0,
        conditionalTotal = 0, graphOrder = 1 } }
    local terminal, pathOrder, level = {}, 1, nil
    for level = 1, depth do
        if level > 2 and Policy:BudgetReached(started, counter) then
            counter.budgetLimited = true
            break
        end
        local expanded, pathIndex, candidateIndex = {}, nil, nil
        local interrupted = false
        for pathIndex = 1, table.getn(frontier) do
            local path, candidates, blockers = frontier[pathIndex], nil, nil
            if Policy:WithinHorizon(path.state, rootTime) then
                candidates, blockers = topCandidates(path.state, counter, actions)
            else
                candidates, blockers = {}, {}
                path.horizonLimited = true
            end
            if level == 1 and pathIndex == 1 then
                counter.rootBlockers = blockers.byAction
            end
            if table.getn(candidates) == 0 then
                path.terminalBlockers = blockers
                table.insert(terminal, path)
            end
            for candidateIndex = 1, table.getn(candidates) do
                local candidate = candidates[candidateIndex]
                if candidate.value > 0 then
                    inheritSpatial(candidate, path)
                    pathOrder = pathOrder + 1
                    local advanced = Transitions:Advance(path.state, candidate)
                    local weighted = candidate.value
                        * Policy:Weight(rootTime, candidate)
                    local conditional = candidate.spatialConditionalOnly == true
                    table.insert(expanded, {
                        state = advanced,
                        steps = copySteps(path.steps, candidate),
                        total = path.total + (conditional and 0 or weighted),
                        conditionalTotal = path.conditionalTotal
                            + (conditional and weighted or 0),
                        spatialConditions = candidate.spatialConditions,
                        spatialConditionFingerprint =
                            candidate.spatialConditionFingerprint,
                        spatialConditionalOnly = conditional,
                        movementSetupTargetGUID = candidate.action
                            and candidate.action.facts
                            and candidate.action.facts.movementSetup
                            and candidate.targetGUID
                            or path.movementSetupTargetGUID,
                        graphOrder = pathOrder,
                    })
                end
            end
            -- Root admission is complete and deterministic. At every deeper
            -- level, always compute one continuation for the best path, then
            -- stop before scanning another full rank-heavy frontier branch.
            if level > 1 and pathIndex < table.getn(frontier)
                and Policy:BudgetReached(started, counter) then
                counter.budgetLimited, interrupted = true, true
                break
            end
        end
        if table.getn(expanded) == 0 then break end
        table.sort(expanded, pathBefore)
        while table.getn(expanded) > Policy.WIDTH do table.remove(expanded) end
        frontier = expanded
        counter.completedDepth = level
        if interrupted or level >= 2
            and Policy:BudgetReached(started, counter) then
            counter.budgetLimited = true
            break
        end
    end
    local paths, i = {}, nil
    for i = 1, table.getn(frontier) do table.insert(paths, frontier[i]) end
    for i = 1, table.getn(terminal) do table.insert(paths, terminal[i]) end
    table.sort(paths, pathBefore)
    return paths[1]
end

function G:Evaluate(mode, preview, observedAt)
    local counter = { count = 0, blockers = {} }
    observedAt = tonumber(observedAt)
        or (type(GetTime) == "function" and GetTime() or 0)
    local state = self:Snapshot(mode)
    local observed = PlanBuilder:ObservedState(state)
    -- Snapshot collection is a live-evidence boundary, not graph expansion.
    -- Start the soft horizon clock afterwards and always finish depth one so
    -- slow client APIs can shorten the runway without suppressing an action.
    local started = Policy:ClockMilliseconds()
    local depth = Policy:Depth()
    counter.maxStates, counter.maxMs = Policy:Limits(state)
    local actions = availableActions()
    if Timeline and Timeline.BeginEvaluation then
        Timeline:BeginEvaluation(state, actions)
    end
    if G.SoulShardReserve and G.SoulShardReserve:Relevant(actions) then
        G.SoulShardReserve:Prepare(state)
    end
    if G.CooldownLedger then G.CooldownLedger:Prepare(state, actions, observedAt) end
    if G.StealthSetup then G.StealthSetup:Prepare(state, actions) end
    if G.ChannelCommitment then G.ChannelCommitment:Prepare(state, actions) end
    if G.WandCommitment then G.WandCommitment:Prepare(state, actions) end
    local path = bestSearchPath(state, started, counter, depth, actions)
    if not path.steps[1] then
        return nil, Diagnostics:Reason(state, counter.blockers), false
    end
    return PlanBuilder:Build(
        state, observed, path, counter, started, observedAt), nil, false
end
