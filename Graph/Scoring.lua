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
local Triggered = XelAssist.Combat.TriggeredActions

local function potency(action, tooltip, state)
    local combo = action.facts.combo
        and (tooltip.comboBonus or 0) * state.combo or 0
    local base, estimated = nil, nil
    if Triggered and Triggered.ScriptedPower then
        base, estimated = Triggered:ScriptedPower(action, state)
    end
    if not base and tooltip.average then
        base, estimated = tooltip.average + combo, false
    end
    if not base and tooltip.dbcAverage then
        local weapon = action.facts.melee
            and XelAssist.Game.Capabilities:WeaponDamage() or 0
        if action.facts.ranged and tooltip.school == 0 then
            weapon = XelAssist.Game.Capabilities:RangedDamage() or weapon
        end
        if not base then
            base, estimated = tooltip.dbcAverage + combo + (weapon or 0), true
        end
    end
    if not base then
        base = math.max(10, action.rank * 24 + (tooltip.cost or 0) * 0.8)
        estimated = true
    end
    if action.facts.kind == "petHeal"
        and tonumber(action.facts.channelTicks) then
        base = base * action.facts.channelTicks
    end
    if (action.facts.kind == "damage" or action.facts.kind == "dot")
        and action.actor ~= "pet" then
        local bonus = XelAssist.Game.Capabilities:BonusDamage(tooltip.school)
        if bonus > 0 then
            local coefficient
            if action.facts.kind == "dot" then
                coefficient = math.min(1, (tooltip.duration or 15) / 15)
            else
                coefficient = math.min(1,
                    math.max(1.5, tooltip.cast or 0) / 3.5)
            end
            if action.facts.aoe then coefficient = coefficient * 0.5 end
            base, estimated = base + bonus * coefficient, true
        end
    end
    local damage = action.facts.kind == "damage" or action.facts.kind == "dot"
        or action.facts.kind == "builder"
    local effectActor = action.facts.damageActor
        or action.facts.effectActor or action.actor
    if damage and effectActor == "pet" and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects then
        base = base * XelAssist.Game.Pets.Effects:DamageMultiplier(
            state.actors and state.actors.pet)
    end
    return base, estimated
end

local function legalityAndTiming(action, state, descriptor)
    local allowed, blocker, tooltip, target, actionStart, resolved =
        Targets:Legal(action, state, descriptor)
    if not allowed then return nil, blocker end
    descriptor = resolved or descriptor
    local facts, power, estimated = action.facts, nil, nil
    local effectAction = Triggered and Triggered:ResultAction(action) or action
    local effectTooltip = Triggered and Triggered:EffectFacts(action, tooltip) or tooltip
    power, estimated = potency(effectAction, effectTooltip, state)
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast or (facts.channel and 3 or 0) end
    if facts.channel and cast <= 0 then cast = tooltip.duration or 3 end
    if state.instantNext and cast > 0 then cast = 0 end
    local defaultGCD = action.actor == "pet" and 0.1 or 1.5
    local occupancy = math.max(0.05,
        facts.gcd or tooltip.gcd or defaultGCD, cast)
    local wait = math.max(0, (actionStart or state.time) - state.time)
    local kind = facts.kind
    local damageKind = kind == "damage" or kind == "dot" or kind == "builder"
    return {
        action = action, effectAction = effectAction,
        state = state, descriptor = descriptor,
        facts = facts, kind = kind, tooltip = tooltip, target = target,
        effectTooltip = effectTooltip,
        actionStart = actionStart, cast = cast, occupancy = occupancy,
        wait = wait, downtime = wait + occupancy, cost = tooltip.cost or 0,
        power = power, expectedPower = power, estimated = estimated,
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
    end
end

local function estimateResistance(context)
    if not context.targetEffect then return end
    local action, state = context.effectAction, context.state
    local tooltip = context.effectTooltip
    local resistanceState = state
    if context.wait + context.cast > 0 then
        resistanceState = Effects:StateAtImpact(
            state, context.wait + context.cast)
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
    context.targetRelation = descriptor.relation
    context.targetGUID = descriptor.guid
    local probe = Timeline:BeforeAction(state, context)
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
        local effective = state.targetHealthExact and targetHealth > 0
            and math.min(expected, targetHealth) or expected
        context.value = 250 + effective * 4 / math.max(0.5, context.downtime)
        if state.targetHealthExact and targetHealth > 0
            and expected >= targetHealth then
            context.value, context.reason = context.value + 700, "finishes the target"
        elseif facts.recovery then
            context.value = context.value + ((state.resourceMax > 0
                and (1 - state.resource / state.resourceMax) * 300) or 0)
            context.reason = "preserves resources"
        elseif context.cast > 0 then context.reason = "best value after cast time"
        else context.reason = "best immediate value" end
        if state.role == "damage" then context.value = context.value * 1.15
        elseif state.role == "healer" then context.value = context.value * 0.85 end
    elseif kind == "dot" then
        local effective, fraction = expected, 1
        if state.targetHealthExact and targetHealth > 0 then
            effective = math.min(expected, targetHealth)
            fraction = math.min(1, targetHealth / math.max(1, expected))
        end
        context.value = effective * 4 / math.max(1, context.downtime)
            + effective / math.max(1, context.cost) * 45
        if fraction < 1 then
            context.value = context.value - (expected - effective) * 3
        end
        context.reason = fraction < 0.75
            and "target may die before the effect pays back"
            or "adds efficient lasting damage"
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
        local incoming = context.friendly
            and context.friendly.targetedByCurrentEnemy
            or context.target == "player" and state.hasAggro
        context.value = power * 3 / math.max(0.5, context.downtime)
            + (incoming and 900 or 0)
        context.reason = incoming and "absorbs expected incoming damage"
            or "adds a protective buffer"
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
        context.value = 500 + (context.tooltip.duration or 0) * 4
        context.reason = "adds missing utility"
    elseif kind == "debuff" then
        local tooltip = context.tooltip
        if tooltip.targetArmorReduction
            or tooltip.targetResistanceReduction or tooltip.targetDamageTaken then
            context.value, context.reason = 120, "opens a stronger damage path"
        else
            context.value = 200 + math.min(10, tooltip.duration or 0) * 4
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
    if facts.aoe and not context.friendlySupport then
        context.value = context.value * (state.mode == "aoe" and 1.8 or 0.55)
    end
    if facts.interrupt and state.targetCasting then
        local probability = state.targetCastProbability
        if probability == nil then probability = 1 end
        context.value, context.reason = context.value
            + 4500 * probability * context.effectDelivery, "stops the current cast"
    end
    if facts.execute and state.targetMax > 0
        and state.targetHealth * 100 / state.targetMax <= facts.execute then
        context.value = context.value + 900
    end
    if facts.leech and state.healthMax > 0 then
        local delivered = context.power > 0
            and context.expectedPower / context.power or context.effectDelivery
        context.value = context.value + (1 - state.health / state.healthMax)
            * 500 * math.max(0, delivered)
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
        cost = context.cost, cast = context.cast, downtime = context.downtime,
        threat = context.threat, estimated = context.estimated,
        tooltip = context.tooltip, power = context.expectedPower,
        effectivePower = context.effectivePower, rawPower = context.power,
        supportAoeUnknown = facts.aoe and context.friendlySupport and true or false,
        resistance = context.resistance, effectDelivery = context.effectDelivery,
        dotRawDirectPower = context.dotRawDirectPower,
        dotRawPeriodicPower = context.dotRawPeriodicPower,
        dotPeriodicExpectedPower = context.dotPeriodicExpectedPower,
        wait = context.wait, occupancy = context.occupancy,
        actionStart = context.actionStart,
    }
end

function Scoring:Evaluate(action, state, descriptor)
    local context, blocker = legalityAndTiming(action, state, descriptor)
    if not context then return nil, blocker end
    resolveTargetNeed(context)
    projectDamageAndResistance(context)
    projectAmbientTargetHealth(context)
    if context.ambientDefeatsTarget then
        context.value, context.reason = -100000,
            "ambient attack resolves first"
        return candidate(context)
    end
    scoreKindUtility(context)
    applyActionAdjustments(context)
    ThreatScoring:Apply(context)
    return candidate(context)
end
