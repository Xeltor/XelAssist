-- Final live reach boundary. Planning evidence can explain a recommendation,
-- but only fresh actor/recipient identity plus raw client geometry may permit
-- the actual mutation.
XelAssist.Core.ExecutionReach = {}
local E = XelAssist.Core.ExecutionReach
local Guard = XelAssist.Core.TargetGuard
local Range = XelAssist.Game.Range

local function effectActor(action)
    local facts = action.facts or {}
    if action.actor == "pet" or facts.effectActor == "pet"
        or facts.damageActor == "pet" then return "pet" end
    return "player"
end

local function distance(actor, unit)
    if actor == unit then return 0, "self" end
    if actor == "pet" then return XelAssist.Game.Actors:Distance(actor, unit) end
    return XelAssist.Game.Capabilities:Distance(unit)
end

local function capture(unit)
    if not unit or unit == "CLICK" then return nil end
    return Guard:CurrentGuid(unit)
end

local function changed(unit, guid)
    if not unit or unit == "CLICK" then return false end
    return guid == nil or Guard:CurrentGuid(unit) ~= guid
end

local function friendlyRelation(relation)
    return relation == "ally" or relation == "friendly"
        or relation == "self" or relation == "player" or relation == "pet"
end

local function targeted(action, plan, unit, tooltip)
    local facts = action.facts or {}
    if action.executor == "item" or facts.petLifecycle or facts.playerAttack
        or facts.self or action.executor == "petCommand" then return false end
    if unit == (action.actor == "pet" and "pet" or "player") then return false end
    return facts.melee or facts.ranged or tooltip.minRange ~= nil
        or tooltip.maxRange ~= nil or plan.targetRelation ~= "self"
end

local function commandVerdict(action, plan, unit, tooltip)
    if not targeted(action, plan, unit, tooltip) then return true, nil end
    local verdict, reason
    if action.actor ~= "pet" then
        verdict = Range:SpellVerdict(action.spellId,
            XelAssist.Game.Capabilities:CastName(action), unit)
    end
    if verdict == nil then
        local measured, kind = distance(
            action.actor == "pet" and "pet" or "player", unit)
        verdict, reason = Range:TooltipVerdict(tooltip, measured, kind)
    end
    if verdict == false then return false, reason or "range" end
    if verdict ~= true then return false, reason or "range unknown" end
    return true, nil
end

local function effectVerdict(action, plan, castUnit)
    local minimum, maximum, requiresHitbox, explicit = Range:EffectBand(action)
    if not explicit then return true, nil, nil end
    local unit = action.facts.effectTarget == "target"
        and "target" or plan.target or castUnit
    local actor = effectActor(action)
    local measured, kind = distance(actor, unit)
    local verdict, reason = Range:BandVerdict(minimum, maximum,
        measured, kind, requiresHitbox)
    if verdict == false then return false, reason or "range", unit end
    if verdict ~= true then return false, reason or "effect range unknown", unit end
    return true, nil, unit
end

local function commandMaximum(action)
    local maximum = tonumber(action.facts.commandMaxRange)
    if not maximum then return true, nil end
    local measured, kind = distance("player", "target")
    local verdict = Range:BandVerdict(0, maximum, measured, kind, false)
    if verdict == false then return false, "command range" end
    if verdict ~= true then return false, "command range unknown" end
    return true, nil
end

local function petRecipient(action, plan)
    if action.actor ~= "pet" or plan.targetRelation == "hostile" then return true end
    local facts, target = action.facts or {}, plan.target
    if facts.self or facts.petSacrifice or target == "pet"
        or action.command == "follow" or action.command == "passive" then return true end
    local ref = plan.targetRef
    if target == "target" and ref and ref.unit == "target"
        and ref.guid ~= nil then return true end
    return false, "companion recipient cannot be pinned"
end

function E:Validate(plan, castUnit)
    local action, tooltip = plan.action, plan.tooltip or {}
    castUnit = castUnit or plan.castTarget or plan.target
    local actor = action.actor == "pet" and "pet" or "player"
    local geometryActor = effectActor(action)
    local lifecycle = action.facts.petLifecycle ~= nil
    local identityCastUnit, effectUnit = castUnit, nil
    if lifecycle then identityCastUnit = nil
    else
        effectUnit = action.facts.effectTarget == "target"
            and "target" or plan.target or castUnit
    end
    local actorGuid, geometryActorGuid, castGuid, effectGuid = capture(actor),
        capture(geometryActor), capture(identityCastUnit), capture(effectUnit)
    if actorGuid == nil then return false, "actor identity unavailable" end
    if geometryActorGuid == nil then
        return false, geometryActor == "pet"
            and "companion identity unavailable" or "actor identity unavailable"
    end
    local allowed, reason = petRecipient(action, plan)
    if not allowed then return false, reason end
    allowed, reason = commandVerdict(action, plan, castUnit, tooltip)
    if not allowed then return false, reason end
    local checkedEffectUnit
    allowed, reason, checkedEffectUnit = effectVerdict(action, plan, castUnit)
    if not allowed then return false, reason end
    allowed, reason = commandMaximum(action)
    if not allowed then return false, reason end
    local geometryUnit
    if action.executor ~= "petCommand" then
        geometryUnit = checkedEffectUnit or effectUnit
    end
    if geometryUnit and geometryUnit ~= geometryActor then
        local geometry = XelAssist.Game.Capabilities:Geometry(
            geometryActor, geometryUnit)
        if geometry and geometry.lineOfSight == false then
            return false, geometryActor == "pet" and "companion line of sight"
                or "line of sight"
        end
        if action.facts.behind and not (geometry and geometry.behind == true) then
            return false, "must be behind target"
        end
    end
    if action.actor ~= "pet" and (tonumber(plan.cast) or 0) > 0
        and PlayerIsMoving and PlayerIsMoving() then return false, "moving" end
    if changed(actor, actorGuid) then
        return false, actor == "pet" and "companion changed" or "actor changed"
    end
    if geometryActor ~= actor and changed(geometryActor, geometryActorGuid) then
        return false, geometryActor == "pet"
            and "companion changed" or "effect actor changed"
    end
    if changed(identityCastUnit, castGuid) or changed(effectUnit, effectGuid) then
        local relation = plan.castTargetRelation or plan.targetRelation
        return false, friendlyRelation(relation) and "ally changed" or "target changed"
    end
    return true, nil
end
