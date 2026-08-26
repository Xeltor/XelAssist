-- Candidate-local changes; OngoingEffects owns timing during the action.
XelAssist.Graph.ActionEffects = {}
local A = XelAssist.Graph.ActionEffects
local State, Effects = XelAssist.Graph.State, XelAssist.Graph.Effects
local HostileEffects, Readiness = XelAssist.Graph.HostileEffects, XelAssist.Graph.ReadinessEffects
local CompanionEventThreat, EventAuras = XelAssist.Graph.CompanionEventThreat, XelAssist.Graph.EventAuras
local DotProjection, ResourceExchange = XelAssist.Graph.DotProjection, XelAssist.Graph.ResourceExchange
local HealthTransfer, WandCommitment = XelAssist.Graph.HealthTransfer, XelAssist.Graph.WandCommitment
local PlayerTaunt, StackedModifiers = XelAssist.Graph.PlayerTaunt, XelAssist.Graph.StackedModifiers
local DruidForms, DruidClearcasting = XelAssist.Graph.DruidForms, XelAssist.Graph.DruidClearcasting
local MageClearcasting = XelAssist.Graph.MageClearcasting
local ShamanClearcasting = XelAssist.Graph.ShamanClearcasting
local PriestInnerFocus = XelAssist.Graph.PriestInnerFocus
local MagePresenceOfMind = XelAssist.Graph.MagePresenceOfMind
local WarlockDarkPact = XelAssist.Graph.WarlockDarkPact
local WarlockFelDomination = XelAssist.Graph.WarlockFelDomination
local RogueRuthlessness = XelAssist.Graph.RogueRuthlessness
local WarriorDemoralizingShout = XelAssist.Graph.WarriorDemoralizingShout
local PriestFade = XelAssist.Graph.PriestFade
local HunterStingingNettle = XelAssist.Graph.HunterStingingNettle
local MageProcWindows = XelAssist.Graph.MageProcWindows
local WarriorDevastate, PaladinHolyShock = XelAssist.Graph.WarriorDevastate, XelAssist.Graph.PaladinHolyShockModifiers
local ThreatDrop, ClassMechanics = XelAssist.Graph.ThreatDrop, XelAssist.Graph.ClassMechanics
local FriendlyActionEffects = XelAssist.Graph.FriendlyActionEffects
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
    local hostileExclusiveFamily = candidate.targetRelation == "hostile"
        and facts.exclusiveFamily or nil
    local applicationState = (hasModifier or hostileExclusiveFamily)
        and Effects:StateAtImpact(source, offset) or nil
    local context = { action = action, facts = facts,
        targetFacts = targetFacts,
        projectedDelivery = delivery,
        applicationElapsed = elapsed,
        applicationOffset = offset,
        hasTargetModifier = hasModifier,
        hostileExclusiveFamily = hostileExclusiveFamily,
        targetModifierDuration = duration,
        targetModifierRemaining = remaining,
        targetGUID = candidate.targetGUID,
        applicationState = applicationState,
    }
    function context:ChangesHostileTarget()
        return self.hasTargetModifier or self.hostileExclusiveFamily
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
        if self.hostileExclusiveFamily then
            Effects:ApplyExclusiveFamily(state, self.action,
                self.projectedDelivery)
        end
        if self.hasTargetModifier and self.targetModifierDuration
            and self.targetModifierDuration > elapsedAfterApplication then
            local prior, fallback = self:ModifierPrior(elapsedAfterApplication)
            Effects:ApplyTargetModifier(state, self.action, self.targetFacts,
                source, self.projectedDelivery, prior, fallback, self.targetGUID)
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
    if context.hostileExclusiveFamily then
        Effects:ApplyExclusiveFamily(out, context.action,
            context.projectedDelivery)
    end
    if context.hasTargetModifier and context.targetModifierRemaining
        and context.targetModifierRemaining > 0 then
        local prior, fallback = context:ModifierPrior(
            context.applicationElapsed)
        Effects:ApplyTargetModifier(out, context.action, context.targetFacts,
            source, context.projectedDelivery, prior, fallback, context.targetGUID)
    end
end
local function applyDamageOrSupport(out, source, candidate, context,
    targetLocal, dotDirect, dotPeriodic, dotDuration, dotElapsed)
    if context.classMechanicHandled then return true end
    local facts = context.facts
    if WandCommitment and WandCommitment:Apply(out, candidate) then
        return true
    elseif facts.kind == "autoRepeat" then
        return false
    elseif XelAssist.Graph.CasterPersistentDamage
        and XelAssist.Graph.CasterPersistentDamage:Apply(
            out, candidate, context) then return true
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
        if not (ClassMechanics
            and ClassMechanics:ApplyExactAbsorb(out, nil, candidate)) then
            out.absorbs[context.action.name] = candidate.power
            if ClassMechanics then ClassMechanics:AfterAbsorb(out, candidate) end
        end
        return true
    elseif facts.kind == "hot" and not targetLocal then
        local fraction = math.min(1,
            candidate.downtime / (candidate.tooltip.duration or 12))
        out.healHealth = math.min(out.healMax,
            out.healHealth + candidate.power * fraction)
        return true
    elseif facts.kind == "threatDrop" then
        if XelAssist.Graph.RogueFeint
            and XelAssist.Graph.RogueFeint:Apply(out, candidate) then
            return true
        end
        if PriestFade and PriestFade:Is(context.action, candidate.tooltip) then
            return PriestFade:Apply(out, candidate)
        end
        local applied = ThreatDrop and ThreatDrop:Apply(out, candidate) or false
        if applied and XelAssist.Graph.HunterFeignDeath then
            XelAssist.Graph.HunterFeignDeath:Apply(out, candidate)
        end
        return applied
    elseif facts.healthFundedChannel and HealthTransfer
        and HealthTransfer:Finish(out, candidate) then
        return true
    elseif facts.kind == "petHeal" and out.actors and out.actors.pet then
        out.actors.pet.health = math.min(out.actors.pet.healthMax,
            out.actors.pet.health + candidate.power)
        XelAssist.Graph.CompanionCommandPolicy:UpdateRecovery(out.actors.pet)
        return true
    elseif PlayerTaunt and PlayerTaunt:Apply(out, candidate) then
        return true
    elseif facts.kind == "taunt" and context.action.actor == "pet"
        and out.actors and out.actors.pet then
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
    elseif facts.wandRepeat then
        local wand = out.wand or {}
        wand.supported, wand.active, wand.activeKnown = true, true, true
        wand.source, wand.targetGuid = "graph start",
            candidate.targetGUID or out.targetGUID
        wand.speed = tonumber(wand.speed) or 2
        wand.damage = tonumber(wand.damage) or tonumber(candidate.power) or 0
        wand.nextShotIn = math.max(0.5, tonumber(wand.speed) or 2)
        wand.pending = false
        out.wand = wand
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
        XelAssist.Graph.CompanionCommandPolicy:Apply(out.actors.pet,
            action, candidate.targetGUID or out.targetGUID)
    elseif XelAssist.Graph.WarriorRage
        and XelAssist.Graph.WarriorRage:Apply(out, candidate) then return
    elseif WarlockDarkPact and WarlockDarkPact:Apply(out, candidate) then
        return
    elseif ResourceExchange and ResourceExchange:Apply(out, candidate) then
        return
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
    local handled = RogueRuthlessness
        and RogueRuthlessness:Apply(out, candidate) or false
    if not handled then
        XelAssist.Graph.ComboEffects:Apply(out, candidate, facts)
    end
    end
local function applyAura(out, source, candidate, context,
    targetLocal, dotPeriodic, dotDuration, dotElapsed)
    if context.classMechanicHandled then return end
    local facts, action = context.facts, context.action
    if facts.paladinConsecration then return end
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
            and not facts.transientResource
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
                and DotProjection:RawPeriodicRate(candidate, dotDuration) or nil,
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
        if facts.stackable and StackedModifiers then
            StackedModifiers:SyncAura(out.auras[action.name],
                out.targetModifierEffects and out.targetModifierEffects[action.name])
        end
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
    if XelAssist.Graph.ShamanStormstrike then XelAssist.Graph.ShamanStormstrike:Consume(out, candidate) end
    if XelAssist.Graph.HunterFeignDeath then XelAssist.Graph.HunterFeignDeath:Consume(out, candidate) end
    if WarlockFelDomination then WarlockFelDomination:Consume(out, candidate) end
    if DruidClearcasting then DruidClearcasting:Consume(out, candidate) end
    if MageClearcasting then MageClearcasting:Consume(out, candidate) end
    if ShamanClearcasting then ShamanClearcasting:Consume(out, candidate) end
    if PriestInnerFocus then PriestInnerFocus:Consume(out, candidate) end
    if MagePresenceOfMind then MagePresenceOfMind:Consume(out, candidate) end
    if MageProcWindows then MageProcWindows:Consume(out, candidate) end
    if PaladinHolyShock then PaladinHolyShock:Consume(out, candidate) end
    if candidate.classMechanicProjection then
        context.classMechanicHandled = true
        context.classMechanicApplied = ClassMechanics and ClassMechanics:Apply(out, candidate) or false
    end
    if DruidForms then DruidForms:Apply(out, candidate, context) end
    if XelAssist.Graph.WarriorStances then XelAssist.Graph.WarriorStances:Apply(out, candidate) end
    if XelAssist.Graph.PriestShadowform then
        XelAssist.Graph.PriestShadowform:Apply(out, candidate)
    end
    if ClassMechanics and ClassMechanics:ApplyExactAura(out, candidate) then context.classMechanicHandled = true end
    applyModifierProjection(out, source, context)
    Readiness:Apply(out, candidate, context)
    local dotDirect, dotPeriodic, dotDuration, dotElapsed =
        DotProjection:Candidate(candidate)
    local targetLocal, friendlyRejected = FriendlyActionEffects:Apply(
        out, candidate, context)
    local primaryHandled = friendlyRejected or applyDamageOrSupport(
        out, source, candidate, context, targetLocal,
        dotDirect, dotPeriodic, dotDuration, dotElapsed)
    if not primaryHandled then
        applyActorOrInventory(out, candidate, context)
    end
    if CompanionEventThreat then
        local record = candidate.targetRelation == "hostile"
            and State.ActiveHostile and State:ActiveHostile(out)
            or candidate.targetRelation == "hostile"
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
    if XelAssist.Graph.ShamanFlameShockRefresh then XelAssist.Graph.ShamanFlameShockRefresh:Apply(out, candidate) end
    if XelAssist.Graph.ShamanStormstrike then XelAssist.Graph.ShamanStormstrike:Apply(out, candidate) end
    applyCombatState(out, candidate, context)
    if XelAssist.Graph.SoulShardReserve then
        XelAssist.Graph.SoulShardReserve:Apply(out, candidate)
    end
    if XelAssist.Graph.PlayerEngagement then XelAssist.Graph.PlayerEngagement:Apply(out, candidate) end
    if XelAssist.Graph.SpatialEffects then
        XelAssist.Graph.SpatialEffects:Apply(out, candidate)
    end
    applyAura(out, source, candidate, context, targetLocal,
        dotPeriodic, dotDuration, dotElapsed)
    if XelAssist.Graph.DruidBloodFrenzy then XelAssist.Graph.DruidBloodFrenzy:ApplyImmediate(out, candidate) end
    if HunterStingingNettle then HunterStingingNettle:Apply(out, candidate) end
    if WarriorDemoralizingShout then
        WarriorDemoralizingShout:Apply(out, candidate)
    end
    if WarriorDevastate then WarriorDevastate:Apply(out, candidate) end
    if XelAssist.Graph.CrowdControl then XelAssist.Graph.CrowdControl:Apply(out, candidate, context) end
    if XelAssist.Graph.ShamanWindfuryTotem then
        XelAssist.Graph.ShamanWindfuryTotem:AfterCandidate(out, candidate)
    end
    if XelAssist.Graph.ShamanManaSpring then
        XelAssist.Graph.ShamanManaSpring:AfterCandidate(out, candidate)
    end
    if WandCommitment then WandCommitment:AfterAction(out, candidate) end
    syncFriendlyCompatibility(out)
    if State.CommitActiveHostile then State:CommitActiveHostile(out) end
end
