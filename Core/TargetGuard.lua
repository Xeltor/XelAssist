-- Last-dispatch identity boundary for selected, explicitly engaged, and
-- companion hostile actions. Every mutation remains pinned to the opaque GUID
-- and live evidence captured by the graph; this module never changes targets.
XelAssist.Core = XelAssist.Core or {}
XelAssist.Core.TargetGuard = {}
local G = XelAssist.Core.TargetGuard
local HostilePolicy = XelAssist.Graph.HostileTargetPolicy
local HostileEngagement = XelAssist.Game.HostileEngagement

local HOSTILE_KINDS = { damage = true, dot = true, debuff = true,
    crowdControl = true, interrupt = true, builder = true, taunt = true,
    petThreat = true, autoRepeat = true }

local function friendlyRelation(relation)
    return relation == "ally" or relation == "friendly" or relation == "self"
        or relation == "player" or relation == "pet"
end

local function petTargetsSelected()
    if not (UnitExists and UnitExists("pettarget")) then
        return false, "companion has no target"
    end
    if not (UnitIsUnit and UnitIsUnit("pettarget", "target")) then
        return false, "companion target changed"
    end
    return true, nil
end

function G:CurrentGuid(unit)
    if not unit or not UnitExists then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 then return nil end
    if not guid or guid == "" or guid == "0x000000000"
        or guid == "0x0000000000000000" then return nil end
    return guid
end

-- This half is deliberately pure so malformed graph plans fail before any
-- mutable client query. Live identity and hostility are checked below.
function G:SelectedHostileAnchor(plan, unit, castRef)
    local action, ref = plan.action or {}, plan.targetRef
    local facts = action.facts or {}
    local hostileKind = not facts.self and not facts.petLifecycle
        and HOSTILE_KINDS[facts.kind] == true
    local hostile = plan.targetRelation == "hostile"
        or plan.castTargetRelation == "hostile"
        or ref and ref.relation == "hostile"
        or castRef and castRef.relation == "hostile"
        or facts.effectTarget == "target" or facts.autoRepeat
        or hostileKind or action.command == "attack"
    if not hostile then return nil, nil, false end
    if plan.target ~= "target" then
        return nil, "hostile target must remain selected", true
    end
    if not ref or ref.guid == nil then
        return nil, "selected hostile identity unavailable", true
    end
    if ref.unit ~= "target" or ref.relation ~= "hostile"
        or plan.targetRelation and plan.targetRelation ~= "hostile" then
        return nil, "hostile target reference is not selected", true
    end
    if plan.targetGUID ~= nil and plan.targetGUID ~= ref.guid then
        return nil, "hostile target identity conflict", true
    end
    local indirect = facts.effectTarget == "target" and unit ~= "target"
    if indirect then
        if not facts.fixedTarget or unit ~= facts.fixedTarget or not castRef
            or castRef.guid == nil or castRef.unit ~= unit
            or not friendlyRelation(castRef.relation)
            or plan.castTargetGUID ~= nil and plan.castTargetGUID ~= castRef.guid
            or plan.castTargetRelation ~= nil
                and plan.castTargetRelation ~= castRef.relation then
            return nil, "hostile action cast recipient changed", true
        end
    elseif unit ~= "target" or not castRef or castRef.unit ~= "target"
        or castRef.relation ~= "hostile" or castRef.guid ~= ref.guid
        or plan.castTargetGUID ~= nil and plan.castTargetGUID ~= ref.guid
        or plan.castTargetRelation ~= nil
            and plan.castTargetRelation ~= "hostile" then
        return nil, "hostile cast target must remain selected", true
    end
    return ref.guid, nil, true
end

function G:ValidateSelectedHostile(plan, unit, castRef)
    local captured, reason, hostile =
        self:SelectedHostileAnchor(plan, unit, castRef)
    if not hostile or not captured then return captured, reason, hostile end
    local attackOk, attackable = pcall(UnitCanAttack, "player", "target")
    if not attackOk or not attackable or attackable == 0 then
        return nil, "selected target is not hostile", true
    end
    if UnitIsDead then
        local deadOk, dead = pcall(UnitIsDead, "target")
        if not deadOk then return nil, "selected target state unavailable", true end
        if dead and dead ~= 0 then return nil, "selected target defeated", true end
    end
    local guid = self:CurrentGuid("target")
    if guid == nil or guid ~= captured then
        return nil, "selected hostile changed", true
    end
    return guid, nil, true
end

-- Pure graph-publication boundary for the narrow GUID-directed hostile lane.
-- Selected-only mechanics never reach this path.
function G:GuidHostileAnchor(plan, unit, castRef)
    local action, ref = plan.action or {}, plan.targetRef
    if not (HostilePolicy and HostilePolicy:Enabled()
        and not HostilePolicy:SelectedOnly(action)) then
        return nil, "hostile target must remain selected", true
    end
    if plan.targetSource ~= "engaged" or plan.targetRelation ~= "hostile"
        or plan.target == nil or not ref or ref.guid == nil
        or ref.unit ~= plan.target or ref.relation ~= "hostile"
        or ref.source ~= "engaged" then
        return nil, "engaged hostile reference unavailable", true
    end
    if plan.targetGUID ~= nil and plan.targetGUID ~= ref.guid then
        return nil, "engaged hostile identity conflict", true
    end
    if unit ~= ref.unit or not castRef or castRef.unit ~= ref.unit
        or castRef.guid ~= ref.guid or castRef.relation ~= "hostile"
        or plan.castTargetGUID ~= nil and plan.castTargetGUID ~= ref.guid
        or plan.castTargetRelation ~= nil
            and plan.castTargetRelation ~= "hostile" then
        return nil, "engaged hostile cast recipient changed", true
    end
    return ref.guid, nil, true
end

function G:HostileAnchor(plan, unit, castRef)
    local guid, reason, hostile = self:SelectedHostileAnchor(plan, unit, castRef)
    if not hostile or guid then return guid, reason, hostile end
    return self:GuidHostileAnchor(plan, unit, castRef)
end

function G:ValidateHostile(plan, unit, castRef)
    local guid, reason, hostile = self:SelectedHostileAnchor(plan, unit, castRef)
    if not hostile then return guid, reason, hostile end
    if guid then return self:ValidateSelectedHostile(plan, unit, castRef) end
    guid, reason, hostile = self:GuidHostileAnchor(plan, unit, castRef)
    if not guid then return nil, reason, true end
    if not HostileEngagement then
        return nil, "engaged hostile validation unavailable", true
    end
    local liveGuid
    liveGuid, reason = HostileEngagement:Validate(castRef)
    if not liveGuid or liveGuid ~= guid then
        return nil, reason or "engaged enemy changed", true
    end
    return guid, nil, true
end

function G:PreflightHostile(plan, unit, castRef)
    if plan.targetSource == "engaged" then
        return self:HostileAnchor(plan, unit, castRef)
    end
    return self:ValidateHostile(plan, unit, castRef)
end

function G:ValidateHostileEffect(plan)
    local facts = plan.action and plan.action.facts
    if not (facts and facts.effectTarget == "target") then return nil, nil end
    local castRef = plan.castTargetRef or plan.targetRef
    local unit = plan.castTarget or plan.target or "target"
    local guid, reason = self:ValidateSelectedHostile(plan, unit, castRef)
    if not guid then return nil, reason end
    if facts.effectActor == "pet" then
        local matches
        matches, reason = petTargetsSelected()
        if not matches then return nil, reason end
        if facts.requiresPetMelee then
            local distance = XelAssist.Game.Actors:Distance("pet", "target")
            if distance == nil then return nil, "companion melee range unknown" end
            if facts.effectMinRange and distance < facts.effectMinRange then
                return nil, "companion too close"
            end
            if facts.effectMaxRange and distance > facts.effectMaxRange then
                return nil, "companion out of melee range"
            end
        end
        if facts.commandMaxRange then
            local distance = XelAssist.Game.Capabilities:Distance("target")
            if distance == nil then return nil, "command range unknown" end
            if distance > facts.commandMaxRange then
                return nil, "target outside command range"
            end
        end
        matches, reason = petTargetsSelected()
        if not matches then return nil, reason end
    end
    local finalGuid
    finalGuid, reason = self:ValidateSelectedHostile(plan, unit, castRef)
    if not finalGuid or finalGuid ~= guid then
        return nil, reason or "effect target changed"
    end
    return finalGuid, nil
end

function G:ValidateAutoShotTarget(plan, evidenceFactory)
    local ref = plan.targetRef
    local guid, reason = self:ValidateSelectedHostile(plan, "target", ref)
    if not guid then return nil, reason end
    local evidence = evidenceFactory(guid, plan.action)
    if not evidence.hostile then return nil, "hostile target required" end
    local finalGuid
    finalGuid, reason = self:ValidateSelectedHostile(plan, "target", ref)
    if not finalGuid or finalGuid ~= guid then
        return nil, reason or "target changed"
    end
    return finalGuid, nil, evidence
end

function G:TargetGuid(plan, unit, ref)
    ref = ref or plan.targetRef
    if ref and ref.guid ~= nil then return ref.guid end
    if plan.targetGUID ~= nil then return plan.targetGUID end
    return self:CurrentGuid(unit)
end

function G:ValidatePetTarget(plan)
    local ref, unit = plan.targetRef, plan.target or "target"
    local guid, reason, hostile = self:ValidateSelectedHostile(plan, unit, ref)
    if hostile then
        if not guid then return false, reason end
        if plan.action and plan.action.executor == "petAbility" then
            local matches
            matches, reason = petTargetsSelected()
            if not matches then return false, reason end
        end
        local finalGuid
        finalGuid, reason = self:ValidateSelectedHostile(plan, unit, ref)
        if not finalGuid or finalGuid ~= guid then
            return false, reason or "selected hostile changed"
        end
        if plan.action and plan.action.executor == "petAbility" then
            local matches
            matches, reason = petTargetsSelected()
            if not matches then return false, reason end
        end
        return true, nil
    end
    if plan.target ~= "target" then return true, nil end
    if not plan.targetRef or plan.targetRef.guid == nil then
        return false, "target identity unavailable"
    end
    local friendlyUnit
    friendlyUnit, reason = XelAssist.Game.Capabilities:ValidateFriendlyRef(
        plan.targetRef)
    if not friendlyUnit then return false, reason or "target changed" end
    return true, nil
end

function G:DispatchPet(plan, action, actorRef)
    local _, reason = XelAssist.Game.Actors:ValidateActorRef(actorRef)
    if reason then return false, reason end
    local valid
    valid, reason = self:ValidatePetTarget(plan)
    if not valid then return false, reason end
    if action.executor == "petAbility" and action.actionSlot and CastPetAction then
        CastPetAction(action.actionSlot); return true
    end
    if action.executor == "petCommand" and action.command == "attack" and PetAttack then
        PetAttack(); return true
    end
    if action.executor == "petCommand" and action.command == "follow" and PetFollow then
        PetFollow(); return true
    end
    if action.executor == "petCommand" and action.command == "passive" and PetPassiveMode then
        PetPassiveMode(); return true
    end
    return false, "pet action unavailable"
end
