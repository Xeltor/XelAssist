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
local Candidate = XelAssist.Graph.Candidate
local ActionConsumption = XelAssist.Graph.ActionConsumption
local ThreatDrop = XelAssist.Graph.ThreatDrop
local RogueFeint = XelAssist.Graph.RogueFeint
local HealingTriageEvidence = XelAssist.Graph.HealingTriageEvidence
local PersistentDamage = XelAssist.Graph.CasterPersistentDamage
local ClassMechanics = XelAssist.Graph.ClassMechanics
local HunterMark = XelAssist.Graph.HunterMark
local HunterDistractingShot = XelAssist.Graph.HunterDistractingShot
local PriestShadowform = XelAssist.Graph.PriestShadowform
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local StateUtilityScoring = XelAssist.Graph.StateUtilityScoring
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local WarlockDarkPact = XelAssist.Graph.WarlockDarkPact
local PriestPowerInfusion = XelAssist.Graph.PriestPowerInfusion
local function legalityAndTiming(action, state, descriptor)
    local allowed, blocker, tooltip, target, actionStart, resolved, targetState =
        Targets:Legal(action, state, descriptor)
    if not allowed then return nil, blocker end
    state = targetState or state
    descriptor = resolved or descriptor
    local facts = action.facts
    local comboTargetGUID, comboAllOwners = nil, false
    if XelAssist.Graph.ComboState then
        comboTargetGUID, comboAllOwners =
            XelAssist.Graph.ComboState:ActionOwner(
                state, facts, tooltip, descriptor)
        tooltip = XelAssist.Graph.ComboState:TooltipFor(
            state, comboTargetGUID, tooltip, comboAllOwners)
    end
    local power, estimated, powerEvidence = nil, nil, nil
    local effectAction = Triggered and Triggered:ResultAction(action) or action
    local effectTooltip = Triggered and Triggered:EffectFacts(action, tooltip) or tooltip
    power, estimated, powerEvidence = XelAssist.Graph.ActionPower:Estimate(
        effectAction, effectTooltip, state, comboTargetGUID, comboAllOwners,
        descriptor and descriptor.guid)
    local comboAvailability = 1
    if facts.combo or tooltip.comboSpendAll then
        comboAvailability = XelAssist.Graph.ComboState
            and XelAssist.Graph.ComboState:Availability(
                state, comboTargetGUID, comboAllOwners) or 1
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
        threatSchool = effectTooltip and effectTooltip.school or tooltip.school,
        actionStart = actionStart, cast = cast, occupancy = occupancy,
        wait = wait, downtime = cycle,
        advanceDowntime = wait + occupancy, cost = tooltip.cost or 0,
        gcd = gcd, normalGcd = normalGcd and true or false,
        onNextSwing = nextSwing and true or false,
        impactDelay = impactDelay,
        costKnown = tooltip.cost ~= nil,
        power = power, expectedPower = power,
        estimated = estimated or state.playerResourceProjected == true,
        powerEvidence = powerEvidence,
        comboAvailability = comboAvailability,
        comboTargetGUID = comboTargetGUID,
        comboAllOwners = comboAllOwners,
        value = 0, reason = kind, damageKind = damageKind,
        targetEffect = damageKind or kind == "debuff"
            or kind == "crowdControl" or kind == "interrupt" or kind == "taunt"
            or facts.targetLocalThreatDrop
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
    if PersistentDamage and PersistentDamage:Prepare(context) then return end
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
    local ammunitionAction = ActionConsumption
        and ActionConsumption:SpendsAmmunition(context.action)
    if not Timeline or not state.targetHealthExact
        and not ammunitionAction then return end
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
    context.ammunitionAtApplication = probe.ammunition
    context.ammunitionAtApplicationKnown = probe.ammunitionKnown
    if context.descriptor and context.descriptor.relation == "hostile"
        and probe.damageEvents > 0 and probe.defeated then
        context.ambientDefeatsTarget = true
    end
end

local function scoreDamageAndHealing(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local power, expected = context.power, context.expectedPower
    local targetHealth = context.targetHealthAtImpact or state.targetHealth
    if kind == "heal" and HealingTriageEvidence then
        local plan = HealingTriageEvidence:Score(context)
        if plan then
            context.healingTriage = plan
            context.effectivePower = plan.effectiveHealing
            context.value, context.reason = plan.value, plan.reason
            if state.role == "healer" then
                context.value = context.value * 1.25
            elseif state.role == "damage" then
                context.value = context.value * 0.85
            end
            return true
        end
    end
    if PersistentDamage and PersistentDamage:Score(
        context, targetHealth) then return true end
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
        local absorbPower = ClassMechanics
            and ClassMechanics:AbsorbCapacity(context) or power
        context.absorbEffectivePower = absorbPower
        if IncomingScoring then
            context.value, context.reason = IncomingScoring:AbsorbValue(context)
        else
            context.value = absorbPower * 3 / math.max(0.5, context.downtime)
            context.reason = "adds a protective buffer"
        end
    else return false end
    return true
end

local function scoreKindUtility(context)
    if XelAssist.Graph.Charge and XelAssist.Graph.Charge:Score(context) then return end
    if XelAssist.Graph.PlayerTaunt and XelAssist.Graph.PlayerTaunt:Score(context) then return end
    if XelAssist.Graph.WarriorStances and XelAssist.Graph.WarriorStances:Score(context) then return end
    if RogueFeint and RogueFeint:Score(context) then return end
    if HunterMark and HunterMark:Score(context) then return end
    if PriestShadowform and PriestShadowform:Score(context) then return end
    if ThreatDrop and ThreatDrop:Score(context) then return end
    if scoreDamageAndHealing(context) then return end
    if ActorScoring:Score(context) then return end
    if RogueSlice and RogueSlice:Score(context) then return end
    if WarlockDarkPact and WarlockDarkPact:Score(context) then return end
    StateUtilityScoring:Score(context)
end

local function applyActionAdjustments(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if context.resistance and context.targetEffect and not context.damageKind
        and not facts.targetLocalThreatDrop then
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

function Scoring:Evaluate(action, state, descriptor)
    local context, blocker = legalityAndTiming(action, state, descriptor)
    if not context then return nil, blocker end
    if ClassMechanics then
        local projection, reason, handled = ClassMechanics:Prepare(
            context.action, context.state, context.descriptor,
            context.tooltip)
        if handled then
            if not projection then return nil, reason end
            local scored
            scored, reason = ClassMechanics:Score(context, projection)
            if not scored then return nil, reason end
            context.classMechanicProjection = projection
        end
    end
    local targetState = context.state
    resolveTargetNeed(context)
    if HunterDistractingShot then
        local prepared, reason, handled = HunterDistractingShot:Prepare(context)
        if handled and not prepared then return nil, reason end
    end
    if action.facts.healthFundedChannel then
        local prepared, reason
        if XelAssist.Graph.HealthTransfer then
            prepared, reason = XelAssist.Graph.HealthTransfer:Prepare(context)
        end
        if not prepared then
            return nil, reason or "health transfer evidence unknown"
        end
    end
    if PriestShadowform then PriestShadowform:AdjustDamage(context) end
    if PriestPowerInfusion then
        local adjusted, reason, handled = PriestPowerInfusion:Adjust(context)
        if handled and not adjusted and reason then return nil, reason end
    end
    projectDamageAndResistance(context)
    if Windfury then Windfury:Adjust(context) end
    PlayerSwingScoring:Project(context)
    projectAmbientTargetHealth(context)
    if context.ammunitionAtApplicationKnown
        and (tonumber(context.ammunitionAtApplication) or 0) <= 0 then
        return nil, "ammunition before application"
    end
    if not (PersistentDamage and PersistentDamage:AdjustSurvival(context))
        and SurvivalPressure then SurvivalPressure:Adjust(context) end
    if action.facts.execute and targetState.targetMax > 0
        and (context.targetHealthAtImpact or targetState.targetHealth) * 100
            / targetState.targetMax > action.facts.execute then
        return nil, "execute range"
    end
    if context.ambientDefeatsTarget then
        context.value, context.reason = -100000,
            "ambient attack resolves first"
        return Candidate:Build(context)
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
    return Candidate:Build(context)
end
