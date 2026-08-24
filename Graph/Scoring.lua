-- Candidate potency and utility scoring. Legality, state projection, and
-- combat effects belong to their respective graph modules.
XelAssist.Graph.Scoring = {}
local Scoring = XelAssist.Graph.Scoring
local State = XelAssist.Graph.State
local Targets = XelAssist.Graph.Targets
local Effects = XelAssist.Graph.Effects

local function potency(action, tooltip, state)
    local combo = action.facts.combo
        and (tooltip.comboBonus or 0) * state.combo or 0
    local base, estimated = nil, nil
    if tooltip.average then base, estimated = tooltip.average + combo, false end
    if tooltip.dbcAverage then
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
    return base, estimated
end

local function legalityAndTiming(action, state, descriptor)
    local allowed, blocker, tooltip, target, actionStart, resolved =
        Targets:Legal(action, state, descriptor)
    if not allowed then return nil, blocker end
    descriptor = resolved or descriptor
    local facts, power, estimated = action.facts, nil, nil
    power, estimated = potency(action, tooltip, state)
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
        action = action, state = state, descriptor = descriptor,
        facts = facts, kind = kind, tooltip = tooltip, target = target,
        actionStart = actionStart, cast = cast, occupancy = occupancy,
        wait = wait, downtime = wait + occupancy, cost = tooltip.cost or 0,
        power = power, expectedPower = power, estimated = estimated,
        value = 0, reason = kind, damageKind = damageKind,
        targetEffect = damageKind or kind == "debuff"
            or kind == "crowdControl" or kind == "interrupt" or kind == "taunt",
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
    local action, state, tooltip = context.action, context.state, context.tooltip
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

local function scoreDamageAndHealing(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local power, expected = context.power, context.expectedPower
    if kind == "damage" or kind == "builder" then
        local effective = state.targetHealthExact and state.targetHealth > 0
            and math.min(expected, state.targetHealth) or expected
        context.value = 250 + effective * 4 / math.max(0.5, context.downtime)
        if state.targetHealthExact and state.targetHealth > 0
            and expected >= state.targetHealth then
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
        if state.targetHealthExact and state.targetHealth > 0 then
            effective = math.min(expected, state.targetHealth)
            fraction = math.min(1, state.targetHealth / math.max(1, expected))
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

local function scoreCompanionAndControl(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if kind == "interrupt" then
        local probability = state.targetCastProbability
        if probability == nil then probability = state.targetCasting and 1 or 0 end
        context.value = state.targetCasting and 5000 * probability or -1000
        context.reason = context.action.actor == "pet"
            and "companion stops the current cast" or "stops the current cast"
    elseif kind == "taunt" then
        context.value, context.reason = state.hasAggro and not state.tank
            and 3800 or 900, "companion takes unwanted aggro"
    elseif kind == "petHeal" then
        local pet = state.actors and state.actors.pet
        local missing = pet and math.max(0, pet.healthMax - pet.health) or 0
        local effective = math.min(context.power, missing)
        context.value, context.reason = effective * 4
            / math.max(0.5, context.downtime), "restores the companion"
        if missing <= 0 then context.value = -1000 end
    elseif kind == "crowdControl" then
        context.value, context.reason = state.hasAggro and not state.tank
            and 2200 or 650, "controls a dangerous target"
    elseif kind == "dispel" then
        context.value, context.reason = 700, "removes a harmful combat effect"
    elseif kind == "summon" then
        context.value, context.reason = 850, "restores a missing companion"
        if facts.summonRole == "tank" and state.groupSize == 0 then
            context.value, context.reason = 1250,
                "brings a companion that can hold solo threat"
        elseif facts.summonRole == "interrupt" and state.targetCasting then
            context.value, context.reason = 1800,
                "brings a companion with an interrupt"
        elseif facts.summonRole == "control"
            and XelAssistCharDB.toggles.petControl then
            context.value, context.reason = 1050,
                "brings a companion with crowd control"
        elseif facts.summonRole == "support" and state.groupSize > 0 then
            context.value, context.reason = 1100, "brings group support"
        end
    elseif kind == "command" then
        local pet = state.actors and state.actors.pet
        if context.action.command == "attack" then
            context.value, context.reason = 850,
                "sends the companion to the current target"
        elseif context.action.command == "passive" then
            context.value, context.reason = 2900,
                "stops the endangered companion from re-engaging"
        else
            local low = pet and pet.healthMax > 0
                and pet.health / pet.healthMax < 0.25
            context.value = low and 2600 or 1000
            context.reason = low and "retreats the endangered companion"
                or "recalls the companion from another target"
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
    if scoreCompanionAndControl(context) then return end
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

local function applyThreatResourceAndConfidence(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local threatPower = (kind == "damage" or kind == "dot" or kind == "builder")
        and context.expectedPower or ((kind == "heal" or kind == "hot")
            and (context.effectivePower or 0) or context.power)
    local threat = threatPower * (facts.threat
        or ((kind == "heal" or kind == "hot") and 0.5 or 1))
    local damageActor = facts.damageActor or context.action.actor
    if damageActor == "pet" then threat = threat * 0.9 end
    if damageActor == "pet" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and state.groupSize == 0)
        if petTank then context.value = context.value + threat * 0.4
        elseif state.groupSize > 0 then
            context.value = context.value - threat * 0.25
        end
    elseif state.tank and threat > threatPower then
        context.value = context.value + (threat - threatPower) * 0.5
        context.reason = "builds threat"
    elseif (state.groupSize > 0 or state.pet) and not state.tank then
        context.value = context.value - threat * (state.hasAggro and 3 or 0.25)
        if state.hasAggro then context.reason = "limits additional threat"
        elseif threat > threatPower * 1.2 then
            context.reason = "lower threat for the group"
        end
    end
    context.threat = threat
    if context.cost > 0 and state.resourceMax > 0 then
        context.value = context.value - context.cost / state.resourceMax * 240
    end
    if facts.inferred then context.estimated = true end
    if context.estimated then context.value = context.value * 0.88 end
end

local function candidate(context)
    local descriptor, facts = context.descriptor, context.facts
    return {
        action = context.action, value = context.value, reason = context.reason,
        target = context.target, targetKey = descriptor and descriptor.key,
        targetGUID = descriptor and descriptor.guid,
        targetRelation = descriptor and descriptor.relation,
        targetSource = descriptor and descriptor.source,
        targetRef = descriptor and descriptor.targetRef,
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
    scoreKindUtility(context)
    applyActionAdjustments(context)
    applyThreatResourceAndConfidence(context)
    return candidate(context)
end
