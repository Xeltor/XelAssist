-- Candidate-local state changes. Timing that occurs during the action lives in
-- OngoingEffects; this module consumes resources and applies the chosen action.
XelAssist.Graph.ActionEffects = {}
local A = XelAssist.Graph.ActionEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local HostileEffects = XelAssist.Graph.HostileEffects
local Readiness = XelAssist.Graph.ReadinessEffects
local CompanionEventThreat = XelAssist.Graph.CompanionEventThreat
local EventAuras = XelAssist.Graph.EventAuras
local function dotPowerSplit(candidate)
    local resistance = candidate.resistance
    if not (resistance and resistance.mode == "hybrid"
        and type(resistance.components) == "table") then
        return 0, candidate.power
    end
    local direct, periodic, unassigned, total = 0, 0, 0, 0
    local i
    for i = 1, table.getn(resistance.components) do
        local component = resistance.components[i]
        local share = tonumber(component.decisionShare) or 0
        total = total + share
        if component.componentPhase == "direct" then direct = direct + share
        elseif component.componentPhase == "periodic" then periodic = periodic + share
        else unassigned = unassigned + share end
    end
    if total <= 0 then return 0, candidate.power end
    periodic = periodic + unassigned
    return candidate.power * direct / total,
        candidate.power * periodic / total
end

function A:Context(source, candidate)
    local action, facts = candidate.action, candidate.action.facts
    local targetFacts = candidate.tooltip or {}
    local delivery = candidate.effectDelivery or (candidate.resistance
        and (candidate.resistance.landChance or 1)
            * (candidate.resistance.uncertaintyMultiplier or 1) or 1)
    local elapsed = math.max(0, (candidate.occupancy or 0)
        - math.max(0, candidate.cast or 0))
    local offset = math.max(0, candidate.wait or 0)
        + math.max(0, candidate.cast or 0)
    local hasModifier = candidate.targetRelation == "hostile"
        and (targetFacts.targetArmorReduction
            or targetFacts.targetResistanceReduction
            or targetFacts.targetDamageTaken)
    local duration = tonumber(candidate.tooltip.duration)
    local remaining = duration and math.max(0, duration - elapsed) or nil
    local applicationState = (hasModifier or facts.exclusiveFamily)
        and Effects:StateAtImpact(source, offset) or nil
    local context = { action = action, facts = facts,
        targetFacts = targetFacts,
        projectedDelivery = delivery,
        applicationElapsed = elapsed,
        applicationOffset = offset,
        hasTargetModifier = hasModifier,
        targetModifierDuration = duration,
        targetModifierRemaining = remaining,
        applicationState = applicationState,
    }
    function context:ChangesHostileTarget()
        return self.hasTargetModifier or self.facts.exclusiveFamily
    end
    function context:ModifierPrior(elapsedAfterApplication)
        if not self.applicationState then return nil, nil end
        local prior = self.applicationState.targetModifierEffects
            and self.applicationState.targetModifierEffects[self.action.name]
        local priorAura = self.applicationState.auras
            and self.applicationState.auras[self.action.name]
        local priorRemaining = type(priorAura) == "table"
            and priorAura.remaining or nil
        if priorRemaining and priorRemaining <= elapsedAfterApplication then
            return nil, nil
        end
        return prior, priorRemaining
            and priorRemaining - elapsedAfterApplication or nil
    end
    function context:ProjectCurrentApplication(state, elapsedAfterApplication)
        Effects:ApplyExclusiveFamily(state, self.action,
            self.projectedDelivery)
        if self.hasTargetModifier and self.targetModifierDuration
            and self.targetModifierDuration > elapsedAfterApplication then
            local prior, fallback = self:ModifierPrior(elapsedAfterApplication)
            Effects:ApplyTargetModifier(state, self.action, self.targetFacts,
                source, self.projectedDelivery, prior, fallback)
        end
    end

    function context:AddProjectedModifierAura(state)
        if self.hasTargetModifier and self.targetModifierDuration
            and self.targetModifierDuration > 0 then
            state.auras[self.action.name] = {
                remaining = self.targetModifierDuration,
                duration = self.targetModifierDuration,
                mine = true,
                target = "target",
                targetModifier = true,
                applicationProbability = self.projectedDelivery,
                exclusiveFamily = self.facts.exclusiveFamily,
            }
        end
    end
    return context
end

function A:Consume(out, candidate, context)
    return XelAssist.Graph.ActionConsumption:Consume(
        out, candidate, context)
end

local function applyModifierProjection(out, source, context)
    if context.facts.exclusiveFamily then
        Effects:ApplyExclusiveFamily(out, context.action,
            context.projectedDelivery)
    end
    if context.hasTargetModifier and context.targetModifierRemaining
        and context.targetModifierRemaining > 0 then
        local prior, fallback = context:ModifierPrior(
            context.applicationElapsed)
        Effects:ApplyTargetModifier(out, context.action,
            context.targetFacts, source, context.projectedDelivery,
            prior, fallback)
    end
end

local function dotProjection(candidate)
    local direct, periodic, duration, elapsed = 0, 0, nil, 0
    if candidate.action.facts.kind ~= "dot" then
        return direct, periodic, duration, elapsed
    end
    if candidate.dotRawPeriodicPower ~= nil then
        periodic = candidate.dotPeriodicExpectedPower or 0
        direct = math.max(0, candidate.power - periodic)
    else
        direct, periodic = dotPowerSplit(candidate)
    end
    duration = math.max(1, tonumber(candidate.tooltip.duration) or 12)
    elapsed = math.min(duration,
        math.max(0, (candidate.occupancy or 0)
            - math.max(0, candidate.cast or 0)))
    return direct, periodic, duration, elapsed
end

local function applyFriendlyTarget(out, candidate, context)
    if candidate.targetRelation == "hostile" then return nil end
    local target = State:FriendlyByKey(out, candidate.targetKey)
    local kind = context.facts.kind
    if not (target and (kind == "heal" or kind == "hot"
        or kind == "absorb" or kind == "buff")) then return nil end
    if kind == "heal" then
        target.health = math.min(target.healthMax,
            target.health + candidate.power)
    elseif kind == "hot" then
        local duration = math.max(1,
            tonumber(candidate.tooltip.duration) or 12)
        local active = math.min(duration, context.applicationElapsed)
        local rate = candidate.power / duration
        target.health = math.min(target.healthMax,
            target.health + rate * active)
        target.auras = target.auras or {}
        target.auras[context.action.name] = {
            duration = duration,
            remaining = math.max(0, duration - active),
            mine = true,
            periodicHealRate = rate,
            applicationProbability = 1,
        }
    elseif kind == "absorb" then
        local duration = tonumber(candidate.tooltip.duration)
        target.absorbs = target.absorbs or {}
        target.absorbs[context.action.name] = {
            amount = candidate.power,
            duration = duration,
            remaining = duration,
            applicationProbability = 1,
        }
    elseif kind == "buff" then
        local duration = tonumber(candidate.tooltip.duration)
        target.auras = target.auras or {}
        target.auras[context.action.name] = {
            duration = duration,
            remaining = duration,
            mine = true,
            applicationProbability = 1,
        }
    end
    return true
end
local function applyDamageOrSupport(out, source, candidate, context,
    targetLocal, dotDirect, dotPeriodic, dotDuration, dotElapsed)
    local facts = context.facts
    if facts.kind == "autoRepeat" then
        return false
    elseif facts.kind == "damage" or facts.kind == "builder" then
        if candidate.areaDirectResolved
            and not candidate.areaSelectedIncluded then return true end
        local applied, dealt = HostileEffects:ApplySelectedDamage(
            out, candidate.power)
        context.appliedHostileDamage = dealt
        return applied
    elseif facts.kind == "dot" then
        local immediate = XelAssist.Game.SpellTiming:AppliedPower(
            dotPeriodic, dotDuration, dotElapsed, candidate.tooltip.periodicInterval)
        if candidate.dotRawPeriodicPower and XelAssist.Combat.Resistance
            and dotElapsed > 0 then
            local conditional = Effects:OverWindow(context.action,
                candidate.target, candidate.tooltip, source,
                context.applicationOffset, dotElapsed, "periodic", true)
            if conditional then
                immediate = XelAssist.Game.SpellTiming:AppliedPower(
                    candidate.dotRawPeriodicPower * context.projectedDelivery
                        * conditional, dotDuration, dotElapsed,
                    candidate.tooltip.periodicInterval)
            end
        end
        local applied, dealt = HostileEffects:ApplySelectedDamage(
            out, dotDirect + immediate)
        context.appliedHostileDamage = dealt
        return applied
    elseif facts.kind == "heal" and not targetLocal then
        if candidate.target == "player" then
            out.health = math.min(out.healthMax, out.health + candidate.power)
        else
            out.healHealth = math.min(out.healMax,
                out.healHealth + candidate.power)
        end
        return true
    elseif facts.kind == "absorb" and not facts.petSacrifice
        and not targetLocal then
        out.absorbs[context.action.name] = candidate.power
        return true
    elseif facts.kind == "hot" and not targetLocal then
        local fraction = math.min(1,
            candidate.downtime / (candidate.tooltip.duration or 12))
        out.healHealth = math.min(out.healMax,
            out.healHealth + candidate.power * fraction)
        return true
    elseif facts.kind == "threatDrop" then
        out.hasAggro = false
        return true
    elseif facts.kind == "petHeal" and out.actors and out.actors.pet then
        out.actors.pet.health = math.min(out.actors.pet.healthMax,
            out.actors.pet.health + candidate.power)
        return true
    elseif facts.kind == "taunt" and out.actors and out.actors.pet then
        local delivery = math.max(0, math.min(1,
            tonumber(candidate.effectDelivery) or 1))
        if delivery >= 0.999 then
            out.hasAggro = false
            out.actors.pet.hasAggro = true
        end
        if HostileEffects and HostileEffects.ProjectPetTaunt then
            HostileEffects:ProjectPetTaunt(out, candidate, context.action)
        end
        return true
    end
    return false
end
local function applyActorOrInventory(out, candidate, context)
    local facts, action = context.facts, context.action
    if XelAssist.Graph.CompanionThreat
        and XelAssist.Graph.CompanionThreat:Apply(
            out, candidate, nil, candidate.effectDelivery) then
        return
    elseif XelAssist.Game.Pets and XelAssist.Game.Pets.Effects
        and XelAssist.Game.Pets.Effects:Apply(out, candidate,
            context.petEventContext or context) then
        return
    elseif facts.playerAttack then
        out.playerAttack = XelAssist.Game.PlayerAttack:Projected(
            candidate.targetGUID or out.targetGUID)
    elseif facts.kind == "autoRepeat" then
        local auto = out.autoShot or {}
        auto.supported, auto.active = true, true
        auto.activeSource, auto.confidence = "graph start", "projected"
        auto.targetGuid = candidate.targetGUID or out.targetGUID
        auto.spellId = XelAssist.Combat.AutoShot
            and XelAssist.Combat.AutoShot:CanonicalSpellId(action.spellId)
            or action.spellId or auto.spellId
        auto.rangedSpeed = tonumber(auto.rangedSpeed) or 2.8
        auto.nextLaunchIn, auto.projectable = 0.5, XelAssist.Combat.AutoShotRange
            :Projectable(auto, auto.targetGuid, auto.spellId)
        auto.blocked = out.moving and true or false
        out.autoShot = auto
    elseif facts.kind == "command" and out.actors and out.actors.pet then
        if action.command == "passive" then
            out.actors.pet.stance = "passive"
            out.actors.pet.attackActive = false
            out.actors.pet.attackActiveKnown = true
            if out.actors.pet.attackRound then
                out.actors.pet.attackRound.projectable = false
                out.actors.pet.attackRound.phaseKnown = false
            end
        else
            out.actors.pet.targetExists = action.command == "attack"
            out.actors.pet.targetsCurrent = action.command == "attack"
            if action.command == "attack" then
                out.actors.pet.targetGuid = candidate.targetGUID or out.targetGUID
                out.actors.pet.attackActive = true
                out.actors.pet.attackActiveKnown = true
                if out.actors.pet.attackRound then
                    out.actors.pet.attackRound.projectable = false
                    out.actors.pet.attackRound.phaseKnown = false
                    out.actors.pet.attackRound.reason =
                        "attack command submitted; awaiting resolved swing"
                end
            else
                out.actors.pet.attackActive = false
                out.actors.pet.attackActiveKnown = true
            end
        end
    elseif facts.kind == "resource" and facts.consumable then
        out.resource = math.min(out.resourceMax,
            out.resource + candidate.power)
    elseif facts.kind == "dispel" then
        out.dispelled = true
    elseif facts.petLifecycle and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Actions
        and XelAssist.Game.Pets.Actions:ApplyLifecycle(out, candidate) then
        return
    elseif facts.kind == "summon" then
        out.pet = true
        out.actors.pet = {
            id = "pet", unit = "pet", actorType = "controlled",
            family = facts.summonFamily, health = 1, healthMax = 1,
            resource = 0, resourceMax = 0, targetExists = false,
            targetsCurrent = false, hasAggro = false,
        }
    elseif facts.petSacrifice then
        out.pet = false
        out.actors.pet = nil
    end
end
local function applyCombatState(out, candidate, context)
    local facts = context.facts
    HostileEffects:FinalizeSelected(out, candidate, facts)
    XelAssist.Graph.ComboEffects:Apply(out, candidate, facts)
end

local function applyAura(out, source, candidate, context,
    targetLocal, dotPeriodic, dotDuration, dotElapsed)
    local facts, action = context.facts, context.action
    local threatActor = facts.damageActor or facts.effectActor
        or action.actor or "player"
    local periodicThreatMultiplier = facts.threat or 1
    if threatActor == "pet" and CompanionEventThreat then
        periodicThreatMultiplier = CompanionEventThreat:DamageMultiplier(
            action, out.actors and out.actors.pet)
    end
    if facts.petCombatBuff or facts.deferredUntilPetMelee then return end
    if not ((facts.kind == "dot" or facts.kind == "debuff"
        or facts.kind == "buff" or facts.kind == "hot"
        or facts.kind == "absorb" or facts.kind == "resource"
        or context.hasTargetModifier) and not targetLocal) then return end
    local priorAura = out.auras[action.name]
    local branches = facts.kind == "dot" and EventAuras:ReplaceStateAura(
        out, action.name, context.projectedDelivery, priorAura) or nil
    local stacks = EventAuras:PriorStacks(
        priorAura, source, action.name, context.applicationOffset)
    local duration = facts.kind == "dot"
        and dotDuration or candidate.tooltip.duration
    local remaining = duration
    if facts.kind == "dot" then
        remaining = math.max(0, dotDuration - dotElapsed)
    elseif duration then
        remaining = math.max(0, duration - context.applicationElapsed)
    end
    if (remaining == nil or remaining > 0)
        and (not context.hasTargetModifier
            or context.targetModifierRemaining
                and context.targetModifierRemaining > 0) then
        out.auras[action.name] = {
            remaining = remaining,
            duration = duration,
            mine = true,
            target = candidate.target,
            periodicRate = facts.kind == "dot"
                and dotPeriodic / dotDuration or nil,
            periodicRawRate = facts.kind == "dot"
                and candidate.dotRawPeriodicPower
                and candidate.dotRawPeriodicPower / dotDuration or nil,
            periodicAction = facts.kind == "dot" and action or nil,
            periodicTooltip = facts.kind == "dot"
                and { school = candidate.tooltip.school } or nil,
            periodicInterval = facts.kind == "dot" and candidate.tooltip.periodicInterval or nil,
            periodicNextIn = facts.kind == "dot" and XelAssist.Game.SpellTiming:Next(
                candidate.tooltip.periodicInterval, dotElapsed) or nil,
            periodicThreatActor = facts.kind == "dot" and threatActor or nil,
            periodicThreatMultiplier = facts.kind == "dot"
                and periodicThreatMultiplier or nil,
            periodicBranches = branches,
            applicationProbability = context.projectedDelivery,
            targetModifier = context.hasTargetModifier
                and context.targetModifierRemaining
                and context.targetModifierRemaining > 0 and true or false,
            exclusiveFamily = facts.exclusiveFamily,
            stacks = facts.stackable and math.min(facts.stackable,
                stacks + 1) or nil,
            expectedStacks = facts.stackable and math.min(facts.stackable,
                stacks + context.projectedDelivery) or nil,
        }
    end
end
local function syncFriendlyCompatibility(state)
    local record = State:PrimaryFriendly(state)
    if not record then return end
    state.healUnit, state.healHealth, state.healMax = record.unit,
        record.health, record.healthMax
    state.healDistance, state.healDistanceKind = record.distance,
        record.distanceKind
    local player = State:FriendlyByUnit(state, "player")
    if player then
        state.health, state.healthMax = player.health, player.healthMax
    end
end

function A:Apply(out, source, candidate, context)
    applyModifierProjection(out, source, context)
    Readiness:Apply(out, candidate, context)
    local dotDirect, dotPeriodic, dotDuration, dotElapsed =
        dotProjection(candidate)
    local targetLocal = applyFriendlyTarget(out, candidate, context)
    local primaryHandled = applyDamageOrSupport(
        out, source, candidate, context, targetLocal,
        dotDirect, dotPeriodic, dotDuration, dotElapsed)
    if not primaryHandled then
        applyActorOrInventory(out, candidate, context)
    end
    if CompanionEventThreat then
        local record = candidate.targetRelation == "hostile"
            and State.SelectedHostile and State:SelectedHostile(out) or nil
        CompanionEventThreat:ConsumeMelee(out, out, context.action,
            candidate.targetGUID, candidate.effectDelivery, record, true)
    elseif XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        XelAssist.Game.Pets.Effects:ConsumeMelee(out, context.action,
            candidate.targetGUID, candidate.effectDelivery)
    end
    if HostileEffects then HostileEffects:Apply(out, candidate) end
    if HostileEffects and HostileEffects.ApplyPrimaryThreat then
        HostileEffects:ApplyPrimaryThreat(out, candidate, context)
    end
    applyCombatState(out, candidate, context)
    if XelAssist.Graph.PlayerEngagement then XelAssist.Graph.PlayerEngagement:Apply(out, candidate) end
    applyAura(out, source, candidate, context, targetLocal,
        dotPeriodic, dotDuration, dotElapsed)
    syncFriendlyCompatibility(out)
    if State.CommitActiveHostile then State:CommitActiveHostile(out) end
end
