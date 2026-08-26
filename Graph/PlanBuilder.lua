-- Converts one completed search path into the immutable UI/execution plan.
-- Search coordination stays in Engine; evidence wording and plan provenance
-- stay here so neither concern turns the engine into a monolith.
XelAssist.Graph.PlanBuilder = {}
local B = XelAssist.Graph.PlanBuilder
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Diagnostics = XelAssist.Graph.PlanDiagnostics
local Policy = XelAssist.Graph.SearchPolicy

function B:ObservedState(state)
    return { health = state.health, healthMax = state.healthMax,
        targetHealth = state.targetHealth, targetMax = state.targetMax,
        targetHealthExact = state.targetHealthExact,
        resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, hasAggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind,
        talentPoints = state.talentPoints }
end

local function targetObservation(state, best, observed)
    observed.targetHealth, observed.targetMax = state.targetHealth,
        state.targetMax
    observed.targetHealthExact = state.targetHealthExact
    observed.hasAggro = state.hasAggro
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

local function stateForBest(state, best)
    if best and best.targetRelation == "hostile"
        and best.targetSource == "engaged" and best.targetKey ~= nil
        and state.hostiles and State.HostileContext then
        return State:HostileContext(state, best.targetKey) or state
    end
    return state
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

local function insertUnique(out, values)
    local i, j
    for i = 1, table.getn(values or {}) do
        local reason, found = values[i], false
        for j = 1, table.getn(out) do
            if out[j] == reason then found = true; break end
        end
        if not found then table.insert(out, reason) end
    end
end

local function recommendationUnknowns(state, best)
    local out, kind = {}, best.action.facts.kind
    local distance = state.targetDistance
    if best.action.actor == "pet" and state.actors and state.actors.pet then
        distance = state.actors.pet.distance
    end
    if best.targetRelation == "hostile" and distance == nil then
        table.insert(out, "range")
    end
    if best.targetRelation ~= "hostile" and best.target ~= "player" then
        local friendly = State:FriendlyByKey(state, best.targetKey)
        if not friendly or friendly.distance == nil then
            table.insert(out, "ally range")
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
    insertUnique(out, best.areaUnknowns)
    insertUnique(out, best.companionUnknowns)
    insertUnique(out, best.playerSwingUnknowns)
    if (kind == "damage" or kind == "dot" or kind == "builder")
        and not state.targetHealthExact then
        table.insert(out, "exact target health")
    end
    addResistanceUnknowns(best, out)
    if best.powerEvidence and best.powerEvidence.exact == false then
        table.insert(out, best.powerEvidence.gap or "weapon damage")
    end
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

function B:Build(state, observed, path, counter, started, observedAt)
    local best, follow, i = path.steps[1], {}, nil
    local probes = state.xelTimelineProbeCache or {}
    for i = 2, table.getn(path.steps) do
        table.insert(follow, path.steps[i].action)
    end
    local targetState = stateForBest(state, best)
    targetObservation(targetState, best, observed)
    local unknowns = recommendationUnknowns(targetState, best)
    applyResistanceContrast(targetState, best)
    local confidence = table.getn(unknowns) > 0 and "partial data"
        or (best.estimated and "estimated" or "client data")
    local terminal = Diagnostics:Terminal(path.state, path.terminalBlockers)
    return { action = best.action, follow = follow, reason = best.reason,
        liveSnapshot = true, observedAt = observedAt,
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
        completedDepth = counter.completedDepth or 0,
        decisionHorizon = Policy:Depth(), timeHorizon = Policy.MAX_SECONDS,
        elapsed = Policy:ElapsedMilliseconds(started), value = best.value,
        timelineProbeHits = probes.hits or 0,
        timelineProbeMisses = probes.misses or 0,
        timelineProbeBypasses = probes.bypasses or 0,
        threat = best.threat, downtime = best.downtime, observed = observed,
        druidFormTransition = best.druidFormTransition,
        warriorStanceTransition = best.warriorStanceTransition,
        priestShadowformTransition = best.priestShadowformTransition,
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
        powerEvidence = best.powerEvidence,
        survival = best.survival,
        comboAvailability = best.comboAvailability,
        marginalPower = best.marginalPower,
        displacedWhitePower = best.displacedWhitePower,
        clipsChannel = best.clipsChannel,
        effectDelivery = best.effectDelivery,
        startsPlayerAttack = best.startsPlayerAttack,
        cost = best.cost, costKnown = best.costKnown,
        onNextSwing = best.onNextSwing,
        impactDelay = best.impactDelay, occupancy = best.occupancy,
        wait = best.wait, cast = best.cast, blockers = counter.blockers,
        rootBlockers = counter.rootBlockers, terminal = terminal,
        horizonLimited = path.horizonLimited and true or false,
        path = path.steps }
end
