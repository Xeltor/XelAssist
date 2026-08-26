-- One-input execution boundary with exact actor, target, and application revalidation.
local XA = XelAssist
local Guard = XelAssist.Core.TargetGuard
local ExecutionReach = XelAssist.Core.ExecutionReach
local DispatchReadiness = XelAssist.Core.DispatchReadiness
local RecommendationSnapshot = XelAssist.Core.RecommendationSnapshot
local WandExecution = XelAssist.Core.WandExecution
local PlayerNormalQueue = XelAssist.Core.PlayerNormalQueue
local PlayerOnSwing = XelAssist.Game.Player
    and XelAssist.Game.Player.OnSwing
local WarriorTankGuard = XelAssist.Core.WarriorTankGuard
local function applicationGuarded(facts, tooltip)
    if facts and facts.submissionGuarded then return true end
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" then return true end
    if kind == "petHeal" then
        return facts.channel or tooltip
            and (tonumber(tooltip.duration) or 0) > 0 and true or false
    end
    return kind == "resource" and (facts.transientResource or facts.channel
        or tooltip and (tonumber(tooltip.duration) or 0) > 0) and true or false
end
local function auraBarForFacts(facts)
    if facts and (facts.deferredUntilPetMelee
        or facts.petCombatBuff or facts.petCombatEffects) then return "buff" end
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl" then
        return "debuff"
    end
    if kind == "buff" or kind == "hot" or kind == "absorb"
        or kind == "petHeal" then return "buff" end
    if kind == "resource" then return facts.self and "buff" or "debuff" end
    return nil
end
local function friendlyRelation(relation)
    return relation == "ally" or relation == "friendly"
        or relation == "self" or relation == "player" or relation == "pet"
end
local function autoShotEvidence(expectedGuid, action)
    local capabilities = XelAssist.Game.Capabilities
    local hostile = Guard:CurrentGuid("target") ~= nil
        and not (UnitIsDead and UnitIsDead("target"))
        and UnitCanAttack and UnitCanAttack("player", "target") and true or false
    local distance, distanceKind = capabilities:Distance(
        hostile and "target" or nil)
    local geometry = capabilities:Geometry("player", "target")
    local _, _, casting, _, channeling = capabilities:CurrentCast()
    return XelAssist.Combat.AutoShotRange:Evidence({
        hostile = hostile, moving = PlayerIsMoving
            and PlayerIsMoving() or false,
        casting = casting and not channeling and true or false,
        channeling = channeling and true or false, distance = distance,
        distanceKind = distanceKind,
        lineOfSight = geometry and geometry.lineOfSight },
        expectedGuid, action and action.spellId)
end
local function duplicateApplication(owner, action, tooltip, unit, guid, casterGuid)
    if not applicationGuarded(action.facts, tooltip) then return nil end
    local key = owner:PendingAuraKey(action.name, guid, casterGuid)
    if key and owner.pendingAuras and owner.pendingAuras[key] then
        return "application already pending"
    end
    local kind = action.facts and action.facts.kind
    local positive = kind == "buff" or kind == "hot" or kind == "absorb"
    if positive and unit and XelAssist.Game.Capabilities.UnitHasBuff then
        local ok, active = pcall(XelAssist.Game.Capabilities.UnitHasBuff,
            XelAssist.Game.Capabilities, unit, action.name)
        if ok and active then return "effect already active" end
    end
    return nil
end
local function petRefForPlan(plan)
    local actionRef = plan.action.actorRef or plan.actorRef
    local pet = plan.observed and plan.observed.actors and plan.observed.actors.pet
    local observedRef = pet and (pet.actorRef or pet.guid ~= nil
        and { unit = pet.unit or "pet", guid = pet.guid,
            relation = "controlled", source = "snapshot" }) or nil
    if actionRef and observedRef and actionRef.guid ~= observedRef.guid then
        return nil, "companion changed during evaluation"
    end
    local ref = actionRef or observedRef
    if not ref then return nil, "companion identity unavailable" end
    return ref, nil
end
function XA:Fallback(reason)
    self.lastReason = "Conservative hold — " .. reason
    if XelAssist.UI and XelAssist.UI.HUD then
        XelAssist.UI.HUD:RequestRefresh(true)
    end
end
function XA:ExecutePetPlan(plan, selected)
    local action, facts = plan.action, plan.action.facts
    local actorRef, reason = petRefForPlan(plan)
    if not actorRef then self:Fallback(reason); return end
    local _, validationReason = XelAssist.Game.Actors:ValidateActorRef(actorRef)
    if validationReason then self:Fallback(validationReason); return end
    local targetValid
    targetValid, validationReason = Guard:ValidatePetTarget(plan)
    if not targetValid then self:Fallback(validationReason); return end
    local unit = plan.target or "target"
    local exactTarget = Guard:TargetGuid(plan, unit)
    local duplicate = duplicateApplication(self, action, plan.tooltip, unit,
        exactTarget, actorRef.guid)
    if duplicate then self:Fallback(duplicate); return end
    reason = DispatchReadiness:Pet(action)
    if reason then self:Fallback(reason); return end
    local reachable
    reachable, reason = ExecutionReach:Validate(plan, unit)
    if not reachable then self:Fallback(reason); return end
    local executed, executionReason = Guard:DispatchPet(plan, action, actorRef)
    if not executed then self:Fallback(executionReason or "pet action unavailable"); return end
    self:RecordDecision(plan, selected)
    if XelAssist.Combat.Observations then
        XelAssist.Combat.Observations:Submitted(action, plan.target, plan.tooltip)
    end
    if applicationGuarded(facts, plan.tooltip) then
        self:MarkAuraPending(action.name,
            math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2),
            exactTarget, action.spellId, actorRef.guid, auraBarForFacts(facts))
    end
    self.lastReason = action.name .. " — " .. plan.reason
    XelAssist.UI.HUD:RequestRefresh(true)
end
local function validateFriendly(owner, ref)
    if not ref then return nil, nil, "ally identity unavailable" end
    local unit, reason = XelAssist.Game.Capabilities:ValidateFriendlyRef(ref)
    if not unit then return nil, nil, reason or "ally changed" end
    return unit, ref.guid, nil
end
local function dispatchPlayer(action, plan, castName, friendly, selfQueue, capturedGuid, unit)
    local castRef = plan.castTargetRef or plan.targetRef
    local guid, reason, hostile
    if action.facts.effectTarget == "target" then
        guid, reason, hostile = Guard:ValidateHostileEffect(plan)
        hostile = true
    else
        guid, reason, hostile = Guard:ValidateHostile(plan, unit, castRef)
    end
    if hostile and not guid then return false, reason end
    if action.facts.playerAttack then
        local attack = XelAssist.Game.PlayerAttack
        if not (attack and attack.Start) then return false, "player Attack state unavailable" end
        local started, startReason = attack:Start(guid)
        if not started then return false, startReason end
    elseif action.facts.druidFormCancel then return XelAssist.Graph.DruidForms:DispatchCancel(plan)
    elseif action.facts.wandRepeat then
        return WandExecution:Dispatch(castName, guid)
    elseif action.facts.autoRepeat then CastSpellByName(castName)
    elseif action.facts.petLifecycle then CastSpellByName(castName)
    elseif action.facts.ground then CastSpellByName(castName, "CLICK")
    elseif action.facts.immediateDispatch then CastSpellByName(castName)
    elseif selfQueue then QueueSpellByName(castName, capturedGuid or "player")
    elseif friendly then CastSpellByName(castName, capturedGuid)
    elseif hostile and QueueSpellByName then QueueSpellByName(castName, guid)
    elseif unit then CastSpellByName(castName, unit)
    elseif QueueSpellByName then QueueSpellByName(castName, guid)
    else CastSpellByName(castName) end
    return true, nil, guid
end
local function rejectPlayer(owner, reason, directReason)
    if not directReason then owner:Fallback(reason); return false end
    owner.lastReason = directReason
    XelAssist.UI.HUD:RequestRefresh(true)
    return false
end
local function validateAutoShot(plan)
    local guid, reason, evidence =
        Guard:ValidateAutoShotTarget(plan, autoShotEvidence)
    if not guid then return nil, reason end
    local allowed
    allowed, reason = XelAssist.Combat.AutoShot:CanStart(
        XelAssist.Combat.AutoShot:Snapshot(evidence))
    if not allowed then return nil, reason or "Auto Shot state uncertain" end
    return guid, nil
end

local function playerContext(plan)
    local action, facts = plan.action, plan.action.facts
    local castRef = plan.castTargetRef or plan.targetRef
    local relation = castRef and castRef.relation
        or plan.castTargetRelation or plan.targetRelation
    local context = { action = action, facts = facts, castRef = castRef,
        castName = XelAssist.Game.Capabilities:CastName(action),
        friendly = friendlyRelation(relation) and not facts.petLifecycle,
        unit = plan.castTarget or plan.target
            or ((not facts.ground) and "target" or nil) }
    context.normalQueue = not facts.playerAttack and not facts.autoRepeat
        and PlayerNormalQueue:MayOccupy(action, plan.tooltip)
    context.usesHostileQueue = not facts.playerAttack and not facts.autoRepeat
        and not facts.petLifecycle and not facts.ground and not facts.immediateDispatch
        and not context.friendly
        and QueueSpellByName ~= nil
    context.usesSelfQueue = not facts.petLifecycle and not facts.ground
        and (relation == "self" or relation == "player") and context.normalQueue
        and QueueSpellByName ~= nil
    context.onSwing = PlayerOnSwing
        and PlayerOnSwing:Is(action, plan.tooltip) and true or false
    local reason
    context.hostileGuid, reason, context.hostilePlan =
        Guard:HostileAnchor(plan, context.unit, castRef)
    return context
end

local function validatePlayerContext(owner, plan, context)
    local action, facts = context.action, context.facts
    local usesNormalQueue = context.normalQueue and (context.usesSelfQueue
        or context.usesHostileQueue
            and context.hostilePlan and plan.targetSource ~= "engaged")
    if (tonumber(plan.wait) or 0) > 0 and not usesNormalQueue then
        return rejectPlayer(owner, context.friendly and "ally action not ready"
            or "action not ready")
    end
    if context.normalQueue then
        local blocker = PlayerNormalQueue:Blocker(action, plan.tooltip)
        if blocker then return rejectPlayer(owner, blocker) end
    end
    if context.onSwing then
        local blocker = PlayerOnSwing:Blocker(action, plan.tooltip)
        if blocker then return rejectPlayer(owner, blocker) end
    end
    local reason
    context.hostileGuid, reason, context.hostilePlan =
        Guard:PreflightHostile(plan, context.unit, context.castRef)
    if context.hostilePlan and not context.hostileGuid then
        return rejectPlayer(owner, reason)
    end
    if facts.autoRepeat and not facts.wandRepeat and XelAssist.Combat.AutoShot then
        context.capturedGuid, reason = validateAutoShot(plan)
        if not context.capturedGuid then return rejectPlayer(owner, reason) end
    end
    if context.friendly then
        context.unit, context.capturedGuid, reason =
            validateFriendly(owner, context.castRef)
        if not context.unit then return rejectPlayer(owner, reason) end
    end
    context.effectGuid, reason = Guard:ValidateHostileEffect(plan)
    if facts.effectTarget and not context.effectGuid then
        return rejectPlayer(owner, reason)
    end
    if context.friendly
        and not XelAssist.Game.Capabilities:SameUnitRef(context.castRef) then
        return rejectPlayer(owner, "ally changed")
    end
    reason = DispatchReadiness:Player(action, usesNormalQueue)
    if reason then return rejectPlayer(owner, reason) end
    if facts.requiresHunterCritical then
        local usable, usableReason = XelAssist.Game.Capabilities:Usable(action)
        if usable ~= true then
            return rejectPlayer(owner, usableReason or "Hunter critical expired")
        end
    end
    return true
end

local function preparePlayerRecipients(owner, plan, context)
    local facts = context.facts
    context.playerGuid = owner:PlayerGUID()
    context.applicationGuid = context.effectGuid or context.hostileGuid
        or context.friendly and context.capturedGuid
        or Guard:TargetGuid(plan, context.unit, context.castRef)
    if not facts.petLifecycle then
        context.queueTargetGuid = context.friendly and context.capturedGuid
            or context.hostileGuid
            or Guard:TargetGuid(plan, context.unit, context.castRef)
    end
    context.reservationUnit = facts.effectTarget == "target"
        and "target" or context.unit
    context.reservationGuid = context.applicationGuid
    if facts.deferredUntilPetMelee or facts.petCombatBuff
        or facts.petCombatEffects then
        context.reservationGuid, context.reservationUnit =
            context.capturedGuid, context.unit
    end
    local duplicate = duplicateApplication(owner, context.action, plan.tooltip,
        context.reservationUnit, context.reservationGuid, context.playerGuid)
    if duplicate then return rejectPlayer(owner, duplicate) end
    return true
end

local function dispatchPlayerContext(owner, plan, context)
    local action, facts, reason = context.action, context.facts, nil
    if context.friendly
        and not XelAssist.Game.Capabilities:SameUnitRef(context.castRef) then
        return rejectPlayer(owner, "ally changed")
    end
    local finalEffectGuid
    finalEffectGuid, reason = Guard:ValidateHostileEffect(plan)
    if facts.effectTarget and (not finalEffectGuid
        or finalEffectGuid ~= context.effectGuid) then
        return rejectPlayer(owner, reason or "effect target changed")
    end
    if facts.wandRepeat then
        context.applicationGuid, reason = WandExecution:Validate(context.hostileGuid)
        if not context.applicationGuid then return rejectPlayer(owner, reason) end
    elseif facts.autoRepeat and XelAssist.Combat.AutoShot then
        context.applicationGuid, reason = validateAutoShot(plan)
        if not context.applicationGuid then return rejectPlayer(owner, reason) end
    end
    local reachable
    reachable, reason = ExecutionReach:Validate(plan, context.unit)
    if not reachable then return rejectPlayer(owner, reason) end
    local tankSafe, tankReason = WarriorTankGuard:Validate(plan)
    if not tankSafe then return rejectPlayer(owner, tankReason) end
    local queueRecord, swingRecord
    if context.normalQueue and (facts.petLifecycle
        or context.usesHostileQueue or context.queueTargetGuid ~= nil) then
        queueRecord, reason = PlayerNormalQueue:Arm(action, plan.tooltip,
            context.castName, context.queueTargetGuid, plan.wait, plan.cast)
        if not queueRecord then return rejectPlayer(owner, reason) end
    end
    if context.onSwing then
        swingRecord, reason = PlayerOnSwing:Arm(action, plan.tooltip,
            context.queueTargetGuid, plan.rawPower, plan.cost, plan.costKnown)
        if not swingRecord then return rejectPlayer(owner, reason) end
    end
    local dispatched, dispatchReason, dispatchGuid = dispatchPlayer(action, plan,
        context.castName, context.friendly, context.usesSelfQueue,
        context.capturedGuid, context.unit)
    local queueAccepted = true
    if queueRecord then
        queueAccepted, dispatchReason =
            PlayerNormalQueue:Finalize(queueRecord, dispatched)
    end
    local swingAccepted = true
    if swingRecord then
        swingAccepted, dispatchReason =
            PlayerOnSwing:Finalize(swingRecord, dispatched)
    end
    if not dispatched or not queueAccepted or not swingAccepted then
        return rejectPlayer(owner, dispatchReason or "target changed")
    end
    if context.hostilePlan then context.applicationGuid = dispatchGuid end
    if facts.effectTarget == "target" then context.effectGuid = dispatchGuid end
    return true
end

local function recordPlayerSubmission(owner, plan, selected, context)
    local action, facts = context.action, context.facts
    if facts.wandRepeat and XelAssist.Combat.Wand then
        WandExecution:Submitted(context.applicationGuid, action, plan.tooltip)
    elseif facts.autoRepeat and XelAssist.Combat.AutoShot then
        XelAssist.Combat.AutoShot:Submitted(context.applicationGuid, action.spellId)
    end
    local engagement = XelAssist.Game.Player
        and XelAssist.Game.Player.Engagement
    if engagement then
        engagement:Submitted(action, plan.tooltip,
            plan.targetRelation, context.applicationGuid or context.hostileGuid,
            (tonumber(plan.wait) or 0) + (tonumber(plan.cast) or 0))
    end
    if XelAssist.Game.Pets and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:Submitted(action,
            context.reservationGuid, context.effectGuid, context.playerGuid)
    end
    owner:RecordDecision(plan, selected)
    if XelAssist.Combat.Observations and not facts.playerAttack
        and not facts.autoRepeat
        and not context.onSwing then
        local observedAction = facts.effectTarget == "target" and not facts.deferredUntilPetMelee
            and (plan.effectAction or action) or action
        local observedTooltip = facts.effectTarget == "target"
            and not facts.deferredUntilPetMelee
            and (plan.effectTooltip or plan.tooltip) or plan.tooltip
        local observations, engaged = XelAssist.Combat.Observations, plan.targetSource == "engaged"
        local submit = engaged and observations.SubmittedGuid or observations.Submitted
        submit(observations, observedAction, engaged and context.applicationGuid
            or facts.effectTarget == "target" and not facts.deferredUntilPetMelee and "target"
                or context.friendly and context.capturedGuid
                or plan.target, observedTooltip)
    end
    if applicationGuarded(facts, plan.tooltip) then
        owner:MarkAuraPending(action.name,
            math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2),
            context.reservationGuid, action.spellId, context.playerGuid,
            auraBarForFacts(facts))
    end
    owner.lastReason = action.name .. " — " .. plan.reason
    XelAssist.UI.HUD:RequestRefresh(true)
end

function XA:ExecutePlayerPlan(plan, selected)
    local context = playerContext(plan)
    if not validatePlayerContext(self, plan, context) then return end
    if not preparePlayerRecipients(self, plan, context) then return end
    if not dispatchPlayerContext(self, plan, context) then return end
    recordPlayerSubmission(self, plan, selected, context)
end

function XA:ExecuteItemPlan(plan, selected)
    local action = plan.action
    if action.executor == "instruction" then
        self.lastReason = action.name .. " — " .. plan.reason
        -- A hold is a true input no-op. The continuous producer and live
        -- combat events own refreshes; macro taps must never cancel its work.
        return
    end
    if (tonumber(plan.wait) or 0) > 0 then
        self:Fallback("item action not ready"); return
    end
    local queueCandidate = PlayerNormalQueue:MayOccupy(action, plan.tooltip)
    if queueCandidate then
        local queueBlocker = PlayerNormalQueue:Blocker(action, plan.tooltip)
        if queueBlocker then self:Fallback(queueBlocker); return end
    end
    local queueRecord, reason
    if queueCandidate then
        queueRecord, reason = PlayerNormalQueue:Arm(action, plan.tooltip,
            action.name, nil, plan.wait, plan.cast)
        if not queueRecord then self:Fallback(reason); return end
    end
    local executed = XelAssist.Game.Inventory:Execute(action)
    local queueAccepted = true
    if queueRecord then
        queueAccepted, reason = PlayerNormalQueue:Finalize(queueRecord, executed)
    end
    if not executed or not queueAccepted then
        self:Fallback(reason or "item unavailable"); return
    end
    self:RecordDecision(plan, selected)
    self.lastReason = action.name .. " — " .. plan.reason
    XelAssist.UI.HUD:RequestRefresh(true)
end

function XA:Execute(mode)
    if not self.executionEnabled then
        self:CheckDependencies()
        if not self.executionEnabled then return end
    end
    local selected = mode or self.mode
    local plan, err = RecommendationSnapshot:Acquire(selected)
    if not plan then
        self.lastReason = "Conservative hold — "
            .. (err or "recommendation not ready")
        if XelAssist.UI and XelAssist.UI.HUD then
            XelAssist.UI.HUD:EnsureEvaluation(selected)
        end
        return
    end
    if XelAssist.UI and XelAssist.UI.HUD
        and XelAssist.UI.HUD.ClearExecutionMode then
        XelAssist.UI.HUD:ClearExecutionMode()
    end
    local action = plan.action
    if action.executor == "item" or action.executor == "instruction" then
        self:ExecuteItemPlan(plan, selected); return
    end
    if action.actor == "pet" then self:ExecutePetPlan(plan, selected); return end
    self:ExecutePlayerPlan(plan, selected)
end
