-- Candidate potency and utility scoring. Legality, state projection, and
-- combat effects belong to their respective graph modules.
XelAssist.Graph.Scoring = {}
local Scoring = XelAssist.Graph.Scoring
local State = XelAssist.Graph.State
local Targets = XelAssist.Graph.Targets
local Effects = XelAssist.Graph.Effects
local ActorScoring = XelAssist.Graph.ActorScoring
local ThreatScoring = XelAssist.Graph.ThreatScoring
local Timeline = XelAssist.Graph.Timeline
local HostileEffects = XelAssist.Graph.HostileEffects
local PlayerSwings = XelAssist.Graph.PlayerSwings
local PlayerSwingScoring = XelAssist.Graph.PlayerSwingScoring
local Triggered = XelAssist.Combat.TriggeredActions
local ComboScoring = XelAssist.Graph.ComboScoring
local Admission = XelAssist.Graph.ActionAdmission
local SurvivalPressure = XelAssist.Graph.SurvivalPressure
local IncomingScoring = XelAssist.Graph.IncomingScoring
local PeriodicScoring = XelAssist.Graph.PeriodicScoring
local function legalityAndTiming(action, state, descriptor)
    local allowed, blocker, tooltip, target, actionStart, resolved, targetState =
        Targets:Legal(action, state, descriptor)
    if not allowed then return nil, blocker end
    state = targetState or state
    descriptor = resolved or descriptor
    if XelAssist.Graph.ComboState then
        tooltip = XelAssist.Graph.ComboState:TooltipFor(
            state, descriptor and descriptor.guid, tooltip)
    end
    local facts, power, estimated, powerEvidence = action.facts, nil, nil, nil
    local effectAction = Triggered and Triggered:ResultAction(action) or action
    local effectTooltip = Triggered and Triggered:EffectFacts(action, tooltip) or tooltip
    power, estimated, powerEvidence = XelAssist.Graph.ActionPower:Estimate(
        effectAction, effectTooltip, state, descriptor and descriptor.guid)
    local comboAvailability = 1
    if facts.combo or tooltip.comboSpendAll then
        comboAvailability = XelAssist.Graph.ComboState
            and XelAssist.Graph.ComboState:Availability(
                state, descriptor and descriptor.guid) or 1
        power = power * comboAvailability
        if comboAvailability < 1 then estimated = true end
    end
    local cast, nextSwing, gcd, normalGcd, cycle, occupancy =
        Admission:Timing(action, state, tooltip)
    local wait = math.max(0, (actionStart or state.time) - state.time)
    local impactDelay = nextSwing and PlayerSwings:ImpactDelay(state) or nil
    local kind = facts.kind
    local damageKind = kind == "damage" or kind == "dot" or kind == "builder"
    return {
        action = action, effectAction = effectAction,
        state = state, descriptor = descriptor,
        facts = facts, kind = kind, tooltip = tooltip, target = target,
        effectTooltip = effectTooltip,
        actionStart = actionStart, cast = cast, occupancy = occupancy,
        wait = wait, downtime = cycle,
        advanceDowntime = wait + occupancy, cost = tooltip.cost or 0,
        gcd = gcd, normalGcd = normalGcd and true or false,
        onNextSwing = nextSwing and true or false,
        impactDelay = impactDelay,
        costKnown = tooltip.cost ~= nil,
        power = power, expectedPower = power, estimated = estimated,
        powerEvidence = powerEvidence,
        comboAvailability = comboAvailability,
        value = 0, reason = kind, damageKind = damageKind,
        targetEffect = damageKind or kind == "debuff"
            or kind == "crowdControl" or kind == "interrupt" or kind == "taunt"
            or kind == "petThreat" and not facts.petThreatDrop,
        effectDelivery = 1,
    }
end
local function resolveTargetNeed(context)
    local descriptor, state = context.descriptor, context.state
    context.friendly = descriptor and descriptor.relation ~= "hostile"
        and (descriptor.record
            or State:FriendlyByKey(state, descriptor.key)) or nil
    if context.kind == "heal" or context.kind == "hot" then
        context.targetMissing = context.friendly
            and State:Missing(context.friendly)
            or context.target == "player"
                and math.max(0, state.healthMax - state.health) or 0
        if IncomingScoring then IncomingScoring:AdjustTargetNeed(context) end
    end
end

local function estimateResistance(context)
    if not context.targetEffect then return end
    local action, state = context.effectAction, context.state
    local tooltip = context.effectTooltip
    local resistanceState = state
    local impactDelay = context.impactDelay
        or context.wait + context.cast
    if impactDelay > 0 then
        resistanceState = Effects:StateAtImpact(
            state, impactDelay)
    end
    local resistance
    if XelAssist.Combat.Resistance then
        resistance = XelAssist.Combat.Resistance:Estimate(
            action, context.target, tooltip, resistanceState)
    elseif XelAssist.Combat.Observations then
        local multiplier, source, estimate =
            XelAssist.Combat.Observations:ResistanceMultiplier(
                action, context.target, tooltip, state)
        resistance = estimate or { multiplier = multiplier or 1,
            source = source or "unknown", unknown = multiplier == nil }
    end
    context.resistance = resistance
    if resistance then
        local decision
        decision, context.effectDelivery = Effects:Decision(
            resistance, resistanceState, context.damageKind)
        if context.damageKind then
            context.expectedPower = context.power * decision
        end
    end
end

local function projectPeriodicDamage(context)
    local resistance = context.resistance
    if not (XelAssist.Combat.Resistance and resistance) then return end
    local action, state, tooltip = context.action, context.state, context.tooltip
    if context.kind == "dot" then
        local directWeight = tonumber(tooltip.directDamage) or 0
        local periodicWeight = tonumber(tooltip.periodicDamage) or 0
        if directWeight > 0 and periodicWeight > 0 then
            local total = directWeight + periodicWeight
            context.dotRawDirectPower = context.power * directWeight / total
            context.dotRawPeriodicPower = context.power * periodicWeight / total
        else
            context.dotRawDirectPower, context.dotRawPeriodicPower = 0, context.power
        end
        local duration = math.max(1, tonumber(tooltip.duration) or 12)
        local conditional = Effects:OverWindow(action, context.target, tooltip,
            state, context.wait + context.cast, duration, "periodic", true)
        if conditional then
            local direct = context.dotRawDirectPower
                * Effects:PhaseFactor(resistance, "direct", false)
            context.dotPeriodicExpectedPower = context.dotRawPeriodicPower
                * context.effectDelivery * conditional
            context.expectedPower = direct + context.dotPeriodicExpectedPower
            resistance.decisionMultiplier = context.power > 0
                and context.expectedPower / context.power or 0
        end
    elseif context.facts.channel and context.cast > 0 then
        local conditional, delivery = Effects:OverWindow(action, context.target,
            tooltip, state, context.wait, context.cast, "periodic", true)
        if conditional then
            context.effectDelivery = delivery
            context.expectedPower = context.power * delivery * conditional
            resistance.decisionMultiplier = context.power > 0
                and context.expectedPower / context.power or 0
        end
    end
end

local function projectDamageAndResistance(context)
    estimateResistance(context)
    projectPeriodicDamage(context)
end

local function projectAmbientTargetHealth(context)
    local state = context.state
    if not (Timeline and state.targetHealthExact) then return end
    local descriptor = context.descriptor or {}
    if descriptor.relation ~= "hostile" then return end
    context.targetRelation = descriptor.relation
    context.targetGUID = descriptor.guid
    local probe = context.onNextSwing
        and Timeline:BeforePlayerSwing(state, context, context.impactDelay)
        or Timeline:BeforeScoredAction(state, context)
    context.targetHealthAtImpact = probe.targetHealth
    context.autoShotLaunchesBeforeImpact = probe.autoLaunches
    context.autoShotImpactsBeforeImpact = probe.autoImpacts
    if context.descriptor and context.descriptor.relation == "hostile"
        and probe.damageEvents > 0 and probe.defeated then
        context.ambientDefeatsTarget = true
    end
end

local function scoreDamageAndHealing(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local power, expected = context.power, context.expectedPower
    local targetHealth = context.targetHealthAtImpact or state.targetHealth
    if kind == "damage" or kind == "builder" then
        if HostileEffects and HostileEffects:Score(context) then return true end
        local effective = PlayerSwingScoring:Effective(
            context, targetHealth, state.targetHealthExact)
        context.effectivePower = effective
        context.value = PlayerSwingScoring:DamageValue(context, effective)
        if PlayerSwingScoring:Finishes(
            context, targetHealth, state.targetHealthExact) then
            context.value, context.reason = context.value + 700, "finishes the target"
        elseif context.onNextSwing then
            context.reason = "upgrades the next melee swing"
        elseif facts.recovery then
            context.value = context.value + ((state.resourceMax > 0
                and (1 - state.resource / state.resourceMax) * 300) or 0)
            context.reason = "preserves resources"
        elseif context.cast > 0 then context.reason = "best value after cast time"
        else context.reason = "best immediate value" end
        if state.role == "damage" then context.value = context.value * 1.15
        elseif state.role == "healer" then context.value = context.value * 0.85 end
    elseif kind == "dot" then
        PeriodicScoring:Score(context, targetHealth)
    elseif kind == "heal" or kind == "hot" then
        local missing = context.targetMissing
        local effective = math.min(power, missing)
        context.effectivePower = effective
        if facts.consumable then
            context.value = effective * 5 / math.max(0.5, context.downtime)
                - 1200 / math.max(1, context.action.count or 1)
        else
            context.value = effective * 5 / math.max(0.5, context.downtime)
                + effective / math.max(1, context.cost) * 80
        end
        if power > missing * 1.35 then
            context.value = context.value - (power - missing) * 2
        end
        if missing <= 0 then context.value = context.value - 1000 end
        context.reason = power > missing * 1.35 and "avoids excess healing"
            or "best healing per resource"
        if context.friendly and context.friendly.targetedByCurrentEnemy then
            context.value = context.value + 300
            if power <= missing * 1.35 then
                context.reason = "stabilizes the enemy's current victim"
            end
        end
        if state.role == "healer" then context.value = context.value * 1.25
        elseif state.role == "damage" then context.value = context.value * 0.85 end
    elseif kind == "absorb" then
        if IncomingScoring then
            context.value, context.reason = IncomingScoring:AbsorbValue(context)
        else
            context.value = power * 3 / math.max(0.5, context.downtime)
            context.reason = "adds a protective buffer"
        end
    else return false end
    return true
end

local function scoreStateUtility(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if kind == "defensive" then
        local hp = state.healthMax > 0 and state.health / state.healthMax or 1
        context.value = (1 - hp) * 1800 + (state.hasAggro and 500 or 0)
        context.reason = "reduces immediate danger"
    elseif kind == "threatDrop" then
        context.value = state.hasAggro and not state.tank and 4200 or -500
        context.reason = "drops unwanted aggro"
    elseif kind == "resource" then
        if XelAssist.Graph.ResourceExchange
            and XelAssist.Graph.ResourceExchange:Score(context) then return end
        local missing = math.max(0, state.resourceMax - state.resource)
        if facts.consumable then
            local effective = math.min(context.power, missing)
            context.value = effective * 4 / math.max(0.5, context.downtime)
                - 1200 / math.max(1, context.action.count or 1)
            if context.power > missing * 1.35 then
                context.value = context.value - (context.power - missing) * 2
            end
            if missing <= 0 then context.value = -1000 end
            context.reason = context.power > missing * 1.35
                and "avoids wasting a resource consumable"
                or "restores needed combat resources"
        else
            context.value = state.resourceMax > 0
                and (1 - state.resource / state.resourceMax) * 1200 or 0
            context.reason = "recovers combat resources"
        end
    elseif kind == "buff" then
        if facts.stealthPreparation and XelAssist.Graph.StealthSetup then
            XelAssist.Graph.StealthSetup:Score(context)
        else
            context.value = 500 + (context.tooltip.duration or 0) * 4
            context.reason = "adds missing utility"
        end
    elseif kind == "debuff" then
        local tooltip = context.tooltip
        local survivalFactor = context.survival
            and context.survival.utilityFactor or 1
        if tooltip.targetArmorReduction
            or tooltip.targetResistanceReduction or tooltip.targetDamageTaken then
            context.value, context.reason = 120 * survivalFactor,
                "opens a stronger damage path"
        else
            context.value = (200
                + math.min(10, tooltip.duration or 0) * 4) * survivalFactor
            context.reason = "adds missing utility"
        end
    elseif kind == "modifier" then
        local urgent = State:PrimaryFriendly(state)
        local missing = State:Missing(urgent)
        local maximum = urgent and (tonumber(urgent.healthMax) or 0) or 0
        context.value = facts.nextInstant
            and (state.moving or missing > maximum * 0.45) and 1500 or 250
        context.reason = facts.nextInstant and "makes the next cast instant"
            or "improves the next action"
    end
end

local function scoreKindUtility(context)
    if scoreDamageAndHealing(context) then return end
    if ActorScoring:Score(context) then return end
    scoreStateUtility(context)
end

local function applyActionAdjustments(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if context.resistance and context.targetEffect and not context.damageKind then
        context.value = context.value * context.effectDelivery
    end
    context.friendlySupport = context.descriptor
        and context.descriptor.relation ~= "hostile"
        and (kind == "heal" or kind == "hot"
            or kind == "absorb" or kind == "buff")
    if facts.interrupt and kind ~= "interrupt" then
        local events = XelAssist.Graph.HostileCastEvents
        local value, reason
        if events then value, reason = events:InterruptValue(context) end
        if value then
            context.value = context.value + value
            if value > 0 then context.reason = reason end
        end
    end
    if facts.execute and (not context.areaDirectResolved
        or context.areaSelectedIncluded) and state.targetMax > 0
        and (context.targetHealthAtImpact or state.targetHealth) * 100
            / state.targetMax <= facts.execute then
        context.value = context.value + 900
    end
    if facts.leech and state.healthMax > 0 then
        local delivered = context.power > 0
            and context.expectedPower / context.power or context.effectDelivery
        context.value = context.value + (1 - state.health / state.healthMax)
            * 500 * math.max(0, delivered)
    end
    if XelAssist.Graph.PlayerEngagement then
        XelAssist.Graph.PlayerEngagement:Score(context)
    end
end

local function candidate(context)
    local descriptor, facts = context.descriptor, context.facts
    return {
        action = context.action, value = context.value, reason = context.reason,
        effectAction = context.effectAction, effectTooltip = context.effectTooltip,
        target = context.target, targetKey = descriptor and descriptor.key,
        targetGUID = descriptor and descriptor.guid,
        targetRelation = descriptor and descriptor.relation,
        targetSource = descriptor and descriptor.source,
        targetRef = descriptor and descriptor.targetRef,
        castTarget = descriptor and descriptor.castUnit,
        castTargetGUID = descriptor and descriptor.castGuid,
        castTargetRelation = descriptor and descriptor.castRelation,
        castTargetSource = descriptor and descriptor.castSource,
        castTargetRef = descriptor and descriptor.castTargetRef,
        targetPriority = descriptor and descriptor.record
            and descriptor.record.priority,
        cost = context.cost, costKnown = context.costKnown,
        cast = context.cast, downtime = context.advanceDowntime,
        valueDowntime = context.downtime,
        threat = context.threat, estimated = context.estimated,
        tooltip = context.tooltip, power = context.expectedPower,
        powerEvidence = context.powerEvidence,
        survival = context.survival,
        comboAvailability = context.comboAvailability,
        effectivePower = context.effectivePower, rawPower = context.power,
        supportAoeUnknown = facts.aoe and context.friendlySupport and true or false,
        resistance = context.resistance, effectDelivery = context.effectDelivery,
        dotRawDirectPower = context.dotRawDirectPower,
        dotRawPeriodicPower = context.dotRawPeriodicPower,
        dotPeriodicExpectedPower = context.dotPeriodicExpectedPower,
        wait = context.wait, occupancy = context.occupancy,
        gcd = context.gcd, normalGcd = context.normalGcd,
        actionStart = context.actionStart,
        clipsChannel = XelAssist.Graph.ChannelCommitment
            and context.clipsChannel and true or false,
        preservesChannel = context.preservesChannel and true or false,
        channelCommitment = (context.clipsChannel or context.preservesChannel)
            and context.state.channelCommitment or nil,
        channelOpportunityValue = context.channelOpportunityValue,
        recipientEffects = context.recipientEffects,
        areaRecipientGroups = context.areaRecipientGroups,
        areaUnknowns = context.areaUnknowns,
        areaRecipientsUnknown = context.areaRecipientsUnknown,
        areaDirectResolved = context.areaDirectResolved,
        areaSelectedIncluded = context.areaSelectedIncluded,
        totalExpectedPower = context.totalExpectedPower,
        totalEffectivePower = context.totalEffectivePower,
        collateralExpectedPower = context.collateralExpectedPower,
        companionUnknowns = context.companionUnknowns,
        onNextSwing = context.onNextSwing,
        impactDelay = context.impactDelay,
        displacedWhitePower = context.displacedWhitePower,
        marginalPower = context.marginalPower,
        marginalEffectivePower = context.marginalEffectivePower,
        playerSwingUnknowns = context.playerSwingUnknowns,
        startsPlayerAttack = context.startsPlayerAttack,
        soulShardOpportunity = context.soulShardOpportunity,
        soulShardStockValue = context.soulShardStockValue,
        soulShardStockCost = context.soulShardStockCost,
        soulShardOvercapPenalty = context.soulShardOvercapPenalty,
        confidence = descriptor and descriptor.projectionOpen and "partial data" or nil,
        spatialConditions = descriptor and descriptor.spatialConditions, spatialConditionFingerprint = descriptor and descriptor.spatialConditionFingerprint, spatialConditionalOnly = descriptor and descriptor.spatialConditionalOnly,
    }
end
function Scoring:Evaluate(action, state, descriptor)
    local context, blocker = legalityAndTiming(action, state, descriptor)
    if not context then return nil, blocker end
    local targetState = context.state
    resolveTargetNeed(context)
    projectDamageAndResistance(context)
    PlayerSwingScoring:Project(context)
    projectAmbientTargetHealth(context)
    if SurvivalPressure then SurvivalPressure:Adjust(context) end
    if action.facts.execute and targetState.targetMax > 0
        and (context.targetHealthAtImpact or targetState.targetHealth) * 100
            / targetState.targetMax > action.facts.execute then
        return nil, "execute range"
    end
    if context.ambientDefeatsTarget then
        context.value, context.reason = -100000,
            "ambient attack resolves first"
        return candidate(context)
    end
    scoreKindUtility(context)
    if XelAssist.Graph.SoulShardReserve then
        XelAssist.Graph.SoulShardReserve:Score(context)
    end
    if SurvivalPressure then SurvivalPressure:Explain(context) end
    ComboScoring:Apply(context)
    applyActionAdjustments(context)
    ThreatScoring:Apply(context)
    if XelAssist.Graph.ChannelCommitment then
        XelAssist.Graph.ChannelCommitment:Adjust(context)
    end
    return candidate(context)
end
