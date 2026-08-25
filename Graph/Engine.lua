-- Public action-graph facade and bounded beam search. Domain modules own state
-- observation, target legality, scoring, effects, and transitions; this file
-- only coordinates them into a deterministic recommendation.
local G = XelAssist.Graph
local State = G.State
local Targets = G.Targets
local Effects = G.Effects
local Scoring = G.Scoring
local Transitions = G.Transitions
local Policy = G.SearchPolicy

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

local function setupValue(candidate)
    local tooltip = candidate.tooltip or {}
    local remaining = (tonumber(tooltip.duration) or 0)
        - math.max(0, (candidate.occupancy or 0) - (candidate.cast or 0))
    if candidate.targetRelation ~= "hostile" or remaining <= 0
        or (candidate.effectDelivery or 1) <= 0 then return 0 end
    local value, _, amount = math.max(0,
        tonumber(tooltip.targetArmorReduction) or 0), nil, nil
    for _, amount in pairs(tooltip.targetResistanceReduction or {}) do
        value = value + math.max(0, tonumber(amount) or 0)
    end
    for _, amount in pairs(tooltip.targetDamageTaken or {}) do
        value = value + math.max(0, tonumber(amount) or 0) * 100
    end
    return value * remaining * (candidate.effectDelivery or 1)
end

local function retainSetupBranch(candidates)
    local best, bestValue, i = nil, 0, nil
    for i = 1, table.getn(candidates) do
        local value = setupValue(candidates[i])
        if value > bestValue then best, bestValue = candidates[i], value end
    end
    while table.getn(candidates) > Policy.WIDTH do table.remove(candidates) end
    if not best then return end
    for i = 1, table.getn(candidates) do
        if candidates[i] == best then return end
    end
    if table.getn(candidates) >= Policy.WIDTH then
        candidates[Policy.WIDTH] = best
    else table.insert(candidates, best) end
    table.sort(candidates, candidateBefore)
end

local function topCandidates(state, counter, actions)
    local buckets, order = {}, 0
    local i, targets, targetIndex, candidate, blocker
    for i = 1, table.getn(actions) do
        targets = Targets:Targets(actions[i], state)
        for targetIndex = 1, table.getn(targets) do
            candidate, blocker = Scoring:Evaluate(
                actions[i], state, targets[targetIndex])
            if candidate then
                order = order + 1
                retainCandidate(buckets, candidate, order)
            elseif blocker then
                counter.blockers[blocker] =
                    (counter.blockers[blocker] or 0) + 1
            end
        end
    end
    local candidates = flattenCandidates(buckets)
    retainSetupBranch(candidates)
    counter.count = counter.count + table.getn(candidates)
    return candidates
end

local function copySteps(steps, candidate)
    local out, i = {}, nil
    for i = 1, table.getn(steps) do out[i] = steps[i] end
    table.insert(out, candidate)
    return out
end

local function inheritSpatial(candidate, path)
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
        for pathIndex = 1, table.getn(frontier) do
            local path, candidates = frontier[pathIndex], nil
            if Policy:WithinHorizon(path.state, rootTime) then
                candidates = topCandidates(path.state, counter, actions)
            else candidates = {} end
            if table.getn(candidates) == 0 then table.insert(terminal, path) end
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
                        graphOrder = pathOrder,
                    })
                end
            end
        end
        if table.getn(expanded) == 0 then break end
        table.sort(expanded, pathBefore)
        while table.getn(expanded) > Policy.WIDTH do table.remove(expanded) end
        frontier = expanded
        counter.completedDepth = level
        if level >= 2 and Policy:BudgetReached(started, counter) then
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

local function observedState(state)
    return { health = state.health, healthMax = state.healthMax,
        targetHealth = state.targetHealth, targetMax = state.targetMax,
        targetHealthExact = state.targetHealthExact,
        resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, hasAggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind,
        talentPoints = state.talentPoints }
end

local function blockerReason(state, blockers)
    if (blockers["minimum range"] or 0) > 0 then return "Move farther away" end
    if (blockers.range or 0) > 0 then return "Move into range" end
    if (blockers.moving or 0) > 0 then return "Finish moving" end
    if (blockers.resource or 0) > 0 then return "Not enough resources" end
    if (blockers.cooldown or 0) > 0 then return "Waiting for cooldown" end
    if (blockers["stealth opener protection"] or 0) > 0 then
        return "Preserving stealth for an opener"
    end
    local i, injured = nil, false
    for i = 1, table.getn(state.friendlies and state.friendlies.order or {}) do
        if State:Missing(State:FriendlyByKey(
            state, state.friendlies.order[i])) > 0 then
            injured = true
            break
        end
    end
    if not state.hostile and not injured then
        return "Select a target or injured ally"
    end
    return "No worthwhile action"
end

local function targetObservation(state, best, observed)
    if best.targetRelation == "hostile" then
        observed.distance, observed.distanceKind =
            state.targetDistance, state.targetDistanceKind
    elseif best.target == "player" then
        observed.distance, observed.distanceKind = 0, "self"
    else
        local friendly = State:FriendlyByKey(state, best.targetKey)
        observed.distance, observed.distanceKind = friendly and friendly.distance,
            friendly and friendly.distanceKind
    end
end

local function addResistanceUnknowns(best, unknowns)
    local resistance, kind = best.resistance, best.action.facts.kind
    local affected = kind == "damage" or kind == "dot" or kind == "builder"
        or kind == "debuff" or kind == "crowdControl"
        or kind == "interrupt" or kind == "taunt"
    if not (affected and resistance) then return end
    if resistance.school == nil and resistance.mode ~= "mixed" then
        table.insert(unknowns, (kind == "damage" or kind == "dot"
            or kind == "builder") and "damage school" or "effect delivery")
    elseif resistance.unknown then
        table.insert(unknowns, resistance.school == 0 and "target armor"
            or string.lower(resistance.schoolName or "school") .. " resistance")
    end
    if resistance.penetrationUnknown then
        table.insert(unknowns,
            (best.action.facts.damageActor == "pet"
                or best.action.actor == "pet")
            and "companion penetration" or "equipped penetration")
    end
    local confidence = resistance.confidence
    if not resistance.unknown and (confidence == "limited samples"
        or confidence == "partial" or confidence == "inferred field") then
        table.insert(unknowns, "limited resistance evidence")
    end
end

local function recommendationUnknowns(state, best)
    local out, kind = {}, best.action.facts.kind
    local distance, lineOfSight = state.targetDistance, state.targetLineOfSight
    if best.action.actor == "pet" and state.actors and state.actors.pet then
        distance, lineOfSight = state.actors.pet.distance,
            state.actors.pet.lineOfSight
    end
    if best.targetRelation == "hostile" and distance == nil then
        table.insert(out, "range")
    end
    if best.targetRelation == "hostile" and lineOfSight == nil then
        table.insert(out, "line of sight")
    end
    if best.targetRelation ~= "hostile" and best.target ~= "player" then
        local friendly = State:FriendlyByKey(state, best.targetKey)
        if not friendly or friendly.distance == nil then
            table.insert(out, "ally range")
        end
        if not friendly or friendly.lineOfSight == nil then
            table.insert(out, "ally line of sight")
        end
        if not best.targetGUID then table.insert(out, "ally identity") end
    end
    if best.supportAoeUnknown then
        table.insert(out, "additional healing recipients")
    end
    if state.actors and state.actors.pet
        and state.actors.pet.areaAutocastUnknown then
        table.insert(out, "companion area recipients")
    end
    local i
    for i = 1, table.getn(best.areaUnknowns or {}) do
        local reason = best.areaUnknowns[i]
        local found, j = false, nil
        for j = 1, table.getn(out) do
            if out[j] == reason then found = true; break end
        end
        if not found then table.insert(out, reason) end
    end
    for i = 1, table.getn(best.companionUnknowns or {}) do
        local reason = best.companionUnknowns[i]
        local found, j = false, nil
        for j = 1, table.getn(out) do
            if out[j] == reason then found = true; break end
        end
        if not found then table.insert(out, reason) end
    end
    for i = 1, table.getn(best.playerSwingUnknowns or {}) do
        local reason = best.playerSwingUnknowns[i]
        local found, j = false, nil
        for j = 1, table.getn(out) do
            if out[j] == reason then found = true; break end
        end
        if not found then table.insert(out, reason) end
    end
    if (kind == "damage" or kind == "dot" or kind == "builder")
        and not state.targetHealthExact then
        table.insert(out, "exact target health")
    end
    addResistanceUnknowns(best, out)
    return out
end

local function applyResistanceContrast(state, best)
    local kind, resistance = best.action.facts.kind, best.resistance
    local damage = kind == "damage" or kind == "dot" or kind == "builder"
    if not (XelAssist.Combat.Resistance and resistance and damage) then return end
    local impact = Effects:StateAtImpact(state, best.impactDelay
        or (best.wait or 0) + (best.cast or 0))
    local contrast = XelAssist.Combat.Resistance:Contrast(impact, resistance)
    if contrast then best.reason = contrast
    elseif not resistance.unknown and (resistance.multiplier or 1) <= 0.85
        and best.reason ~= "finishes the target" then
        best.reason = "best expected value after "
            .. string.lower(resistance.schoolName or "target") .. " mitigation"
    end
end

local function buildPlan(state, observed, path, counter, started)
    local best, follow, i = path.steps[1], {}, nil
    for i = 2, table.getn(path.steps) do
        table.insert(follow, path.steps[i].action)
    end
    targetObservation(state, best, observed)
    local unknowns = recommendationUnknowns(state, best)
    applyResistanceContrast(state, best)
    local confidence = table.getn(unknowns) > 0 and "partial data"
        or (best.estimated and "estimated" or "client data")
    return { action = best.action, follow = follow, reason = best.reason,
        effectAction = best.effectAction, effectTooltip = best.effectTooltip,
        target = best.target, targetKey = best.targetKey,
        targetGUID = best.targetGUID, targetRelation = best.targetRelation,
        targetSource = best.targetSource, targetRef = best.targetRef,
        castTarget = best.castTarget, castTargetGUID = best.castTargetGUID,
        castTargetRelation = best.castTargetRelation,
        castTargetSource = best.castTargetSource,
        castTargetRef = best.castTargetRef,
        actor = best.action.actor or "player", confidence = confidence,
        unknowns = unknowns, expanded = counter.count,
        budgetLimited = counter.budgetLimited and true or false,
        elapsed = (GetTime() - started) * 1000, value = best.value,
        threat = best.threat, downtime = best.downtime, observed = observed,
        resistance = best.resistance, tooltip = best.tooltip,
        recipientEffects = best.recipientEffects,
        areaRecipientGroups = best.areaRecipientGroups,
        areaUnknowns = best.areaUnknowns,
        areaRecipientsUnknown = best.areaRecipientsUnknown,
        areaDirectResolved = best.areaDirectResolved,
        areaSelectedIncluded = best.areaSelectedIncluded,
        totalExpectedPower = best.totalExpectedPower,
        totalEffectivePower = best.totalEffectivePower,
        collateralExpectedPower = best.collateralExpectedPower,
        power = best.power, rawPower = best.rawPower,
        marginalPower = best.marginalPower,
        displacedWhitePower = best.displacedWhitePower,
        effectDelivery = best.effectDelivery,
        startsPlayerAttack = best.startsPlayerAttack,
        cost = best.cost, costKnown = best.costKnown,
        onNextSwing = best.onNextSwing,
        impactDelay = best.impactDelay, occupancy = best.occupancy,
        wait = best.wait, cast = best.cast, blockers = counter.blockers,
        path = path.steps }
end

function G:Evaluate(mode, preview)
    local counter = { count = 0, blockers = {} }
    local state = self:Snapshot(mode)
    local observed = observedState(state)
    -- Snapshot collection is a live-evidence boundary, not graph expansion.
    -- Start the soft horizon clock afterwards and always finish depth one so
    -- slow client APIs can shorten the runway without suppressing an action.
    local started = GetTime()
    local depth = Policy:Depth()
    local actions = availableActions()
    local path = bestSearchPath(state, started, counter, depth, actions)
    if not path.steps[1] then
        return nil, blockerReason(state, counter.blockers), false
    end
    return buildPlan(state, observed, path, counter, started), nil, false
end
