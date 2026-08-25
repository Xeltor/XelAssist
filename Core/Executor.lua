-- The one-input execution boundary. Every dispatch is revalidated against the
-- exact actor/target identities and live application state used by the plan.
local XA = XelAssist
local Guard = XelAssist.Core.TargetGuard

local function applicationGuarded(facts, tooltip)
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" then return true end
    if kind == "petHeal" then
        return facts.channel or tooltip
            and (tonumber(tooltip.duration) or 0) > 0 and true or false
    end
    return kind == "resource" and (facts.channel
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

local function autoShotEvidence()
    local capabilities = XelAssist.Game.Capabilities
    local hostile = Guard:CurrentGuid("target") ~= nil
        and not (UnitIsDead and UnitIsDead("target"))
        and UnitCanAttack and UnitCanAttack("player", "target") and true or false
    local distance = capabilities:Distance(hostile and "target" or nil)
    local geometry = capabilities:Geometry("player", "target")
    local _, _, casting, _, channeling = capabilities:CurrentCast()
    return { hostile = hostile, moving = PlayerIsMoving
            and PlayerIsMoving() or false,
        casting = casting and not channeling and true or false,
        channeling = channeling and true or false, distance = distance,
        lineOfSight = geometry and geometry.lineOfSight }
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
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. self.lastReason .. ".",
        1, 0.65, 0.2)
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
    XelAssist.UI.HUD:Refresh(true)
end

local function validateFriendly(owner, ref)
    if not ref then return nil, nil, "ally identity unavailable" end
    local unit, reason = XelAssist.Game.Capabilities:ValidateFriendlyRef(ref)
    if not unit then return nil, nil, reason or "ally changed" end
    return unit, ref.guid, nil
end

local function dispatchPlayer(action, plan, castName, friendly, capturedGuid, unit)
    local castRef = plan.castTargetRef or plan.targetRef
    local guid, reason, hostile
    if action.facts.effectTarget == "target" then
        guid, reason, hostile = Guard:ValidateHostileEffect(plan)
        hostile = true
    else
        guid, reason, hostile = Guard:ValidateSelectedHostile(plan, unit, castRef)
    end
    if hostile and not guid then return false, reason end
    if action.facts.playerAttack then
        local attack = XelAssist.Game.PlayerAttack
        if not (attack and attack.Start) then
            return false, "player Attack state unavailable"
        end
        local started, startReason = attack:Start(guid)
        if not started then return false, startReason end
    elseif action.facts.autoRepeat then CastSpellByName(castName)
    elseif action.facts.petLifecycle then CastSpellByName(castName)
    elseif action.facts.ground then CastSpellByName(castName, "CLICK")
    elseif friendly then CastSpellByName(castName, capturedGuid)
    elseif unit == "target" and QueueSpellByName then QueueSpellByName(castName)
    elseif unit then CastSpellByName(castName, unit)
    elseif QueueSpellByName then QueueSpellByName(castName)
    else CastSpellByName(castName) end
    return true, nil, guid
end

function XA:ExecutePlayerPlan(plan, selected)
    local action, facts = plan.action, plan.action.facts
    local castName = XelAssist.Game.Capabilities:CastName(action)
    local castRef = plan.castTargetRef or plan.targetRef
    local relation = castRef and castRef.relation
        or plan.castTargetRelation or plan.targetRelation
    local friendly = friendlyRelation(relation) and not facts.petLifecycle
    local unit = plan.castTarget or plan.target
        or ((not facts.ground) and "target" or nil)
    local queueCandidate = not facts.playerAttack and not facts.autoRepeat
        and not facts.petLifecycle
        and not facts.ground and not friendly
        and (not plan.target or plan.target == "target") and QueueSpellByName
    local capturedGuid, effectGuid, reason, hostileGuid, hostilePlan
    hostileGuid, reason, hostilePlan =
        Guard:SelectedHostileAnchor(plan, unit, castRef)
    local forceQueue = queueCandidate and hostilePlan
    if (tonumber(plan.wait) or 0) > 0 and not forceQueue then
        self:Fallback(friendly and "ally action not ready" or "action not ready")
        XelAssist.UI.HUD:Refresh(true); return
    end
    hostileGuid, reason, hostilePlan =
        Guard:ValidateSelectedHostile(plan, unit, castRef)
    if hostilePlan and not hostileGuid then
        self:Fallback(reason); XelAssist.UI.HUD:Refresh(true); return
    end
    if facts.autoRepeat and XelAssist.Combat.AutoShot then
        local evidence, allowed
        capturedGuid, reason, evidence =
            Guard:ValidateAutoShotTarget(plan, autoShotEvidence)
        if not capturedGuid then
            self:Fallback(reason); XelAssist.UI.HUD:Refresh(true); return
        end
        allowed, reason = XelAssist.Combat.AutoShot:CanStart(
            XelAssist.Combat.AutoShot:Snapshot(evidence))
        if not allowed then
            self:Fallback(reason or "Auto Shot state uncertain")
            XelAssist.UI.HUD:Refresh(true); return
        end
    end
    if friendly then
        unit, capturedGuid, reason = validateFriendly(self, castRef)
        if not unit then self:Fallback(reason); XelAssist.UI.HUD:Refresh(true); return end
    end
    effectGuid, reason = Guard:ValidateHostileEffect(plan)
    if facts.effectTarget and not effectGuid then
        self:Fallback(reason); XelAssist.UI.HUD:Refresh(true); return
    end
    if not facts.petLifecycle
        and XelAssist.Game.Capabilities:InRange(castName, unit) == false then
        self.lastReason = "Move into range — " .. action.name
        XelAssist.UI.HUD:Refresh(true); return
    end
    if friendly and not XelAssist.Game.Capabilities:SameUnitRef(castRef) then
        self:Fallback("ally changed"); XelAssist.UI.HUD:Refresh(true); return
    end
    if facts.requiresHunterCritical then
        local usable, usableReason = XelAssist.Game.Capabilities:Usable(action)
        if usable ~= true then
            self:Fallback(usableReason or "Hunter critical expired")
            XelAssist.UI.HUD:Refresh(true); return
        end
    end
    local playerGuid = self:PlayerGUID()
    local applicationGuid = effectGuid or hostileGuid or friendly and capturedGuid
        or Guard:TargetGuid(plan, unit, castRef)
    local applicationUnit = facts.effectTarget == "target" and "target" or unit
    local reservationGuid, reservationUnit = applicationGuid, applicationUnit
    if facts.deferredUntilPetMelee or facts.petCombatBuff
        or facts.petCombatEffects then
        reservationGuid, reservationUnit = capturedGuid, unit
    end
    local duplicate = duplicateApplication(self, action, plan.tooltip, reservationUnit,
        reservationGuid, playerGuid)
    if duplicate then self:Fallback(duplicate); return end
    -- Aura inspection reads a mutable token, so identity is checked again at
    -- the exact dispatch boundary.
    if friendly and not XelAssist.Game.Capabilities:SameUnitRef(castRef) then
        self:Fallback("ally changed"); XelAssist.UI.HUD:Refresh(true); return
    end
    local finalEffectGuid
    finalEffectGuid, reason = Guard:ValidateHostileEffect(plan)
    if facts.effectTarget and (not finalEffectGuid or finalEffectGuid ~= effectGuid) then
        self:Fallback(reason or "effect target changed")
        XelAssist.UI.HUD:Refresh(true); return
    end
    if facts.autoRepeat and XelAssist.Combat.AutoShot then
        local evidence, allowed
        applicationGuid, reason, evidence =
            Guard:ValidateAutoShotTarget(plan, autoShotEvidence)
        if not applicationGuid then
            self:Fallback(reason); XelAssist.UI.HUD:Refresh(true); return
        end
        allowed, reason = XelAssist.Combat.AutoShot:CanStart(
            XelAssist.Combat.AutoShot:Snapshot(evidence))
        if not allowed then
            self:Fallback(reason or "Auto Shot state uncertain")
            XelAssist.UI.HUD:Refresh(true); return
        end
    end
    local dispatched, dispatchReason, dispatchGuid = dispatchPlayer(
        action, plan, castName, friendly, capturedGuid, unit)
    if not dispatched then
        self:Fallback(dispatchReason or "target changed")
        XelAssist.UI.HUD:Refresh(true); return
    end
    if hostilePlan then applicationGuid = dispatchGuid end
    if facts.effectTarget == "target" then effectGuid = dispatchGuid end
    if facts.autoRepeat and XelAssist.Combat.AutoShot then
        XelAssist.Combat.AutoShot:Submitted(applicationGuid, action.spellId)
    end
    if XelAssist.Game.Pets and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:Submitted(action,
            reservationGuid, effectGuid, playerGuid)
    end
    self:RecordDecision(plan, selected)
    if XelAssist.Combat.Observations and not facts.playerAttack then
        local observedAction = facts.effectTarget == "target"
            and not facts.deferredUntilPetMelee
            and (plan.effectAction or action) or action
        local observedTooltip = facts.effectTarget == "target"
            and not facts.deferredUntilPetMelee
            and (plan.effectTooltip or plan.tooltip) or plan.tooltip
        XelAssist.Combat.Observations:Submitted(observedAction,
            facts.effectTarget == "target" and not facts.deferredUntilPetMelee
                and "target"
                or friendly and capturedGuid or plan.target, observedTooltip)
    end
    if applicationGuarded(facts, plan.tooltip) then
        self:MarkAuraPending(action.name,
            math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2),
            reservationGuid, action.spellId, playerGuid, auraBarForFacts(facts))
    end
    self.lastReason = action.name .. " — " .. plan.reason
    XelAssist.UI.HUD:Refresh(true)
end

function XA:Execute(mode)
    if not self.executionEnabled then
        self:CheckDependencies()
        if not self.executionEnabled then return end
    end
    local selected = mode or self.mode
    local ok, plan, err, fallback = pcall(function()
        local value, failure, held = XelAssist.Graph:Evaluate(selected, false)
        return value, failure, held
    end)
    if not ok then self:RecordError(plan); self:Fallback("evaluation error"); return end
    if fallback then self:Fallback(err or "incomplete data"); return end
    if not plan then
        DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. (err or "no legal action"),
            0.35, 0.85, 1)
        return
    end
    local action = plan.action
    if action.executor == "item" then
        if (tonumber(plan.wait) or 0) > 0 then
            self:Fallback("item action not ready"); return
        end
        if not XelAssist.Game.Inventory:Execute(action) then
            self:Fallback("item unavailable"); return
        end
        self:RecordDecision(plan, selected)
        self.lastReason = action.name .. " — " .. plan.reason
        XelAssist.UI.HUD:Refresh(true); return
    end
    if action.actor == "pet" then self:ExecutePetPlan(plan, selected); return end
    self:ExecutePlayerPlan(plan, selected)
end
