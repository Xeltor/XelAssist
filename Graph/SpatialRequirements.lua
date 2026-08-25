-- Spatial legality for current actions and explicit conditions for projected
-- rows. Future search never calls live geometry APIs or turns a failed edge
-- positive merely because modeled time advanced.
XelAssist.Graph.SpatialRequirements = {}
local S = XelAssist.Graph.SpatialRequirements
local Range = XelAssist.Game.Range
local StealthSetup = XelAssist.Graph.StealthSetup
local MovementSetup = XelAssist.Graph.MovementSetup

local function isFuture(state)
    return (tonumber(state and state.time) or 0) > 0
end

local function actorUnit(action, effect)
    local facts = action.facts or {}
    if action.actor == "pet" or effect
        and (facts.effectActor == "pet" or facts.damageActor == "pet") then
        return "pet"
    end
    return "player"
end

local function friendlyRecord(state, unit)
    local graphState = XelAssist.Graph.State
    return graphState and graphState.FriendlyByUnit
        and graphState:FriendlyByUnit(state, unit) or nil
end

local function distanceFor(state, descriptor, actor, unit)
    if actor == unit then return 0, "self" end
    if unit == "target" then
        if actor == "pet" then
            local pet = state.actors and state.actors.pet
            return pet and pet.distance, pet and pet.distanceKind
        end
        if descriptor.relation == "hostile" then
            return state.targetDistance ~= nil and state.targetDistance
                    or state.distance,
                state.targetDistance ~= nil and state.targetDistanceKind
                    or state.distanceKind
        end
    end
    local record = descriptor.unit == unit and descriptor.record
        or friendlyRecord(state, unit)
    if actor == "player" then
        return record and record.distance, record and record.distanceKind
    end
    return nil, nil
end

local function valueText(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value == math.floor(value) then return tostring(math.floor(value)) end
    return string.format("%.1f", value)
end

local function bandText(minimum, maximum)
    local minText, maxText = valueText(minimum), valueText(maximum)
    if minText and tonumber(minimum) > 0 and maxText
        and tonumber(maximum) > 0 then
        return minText .. "-" .. maxText .. " yd"
    end
    if maxText and tonumber(maximum) > 0 then return "within " .. maxText .. " yd" end
    if minText and tonumber(minimum) > 0 then return "beyond " .. minText .. " yd" end
    return "client range"
end

local function addCondition(descriptor, record)
    if not descriptor.projectionOpen then return end
    descriptor.spatialConditions = descriptor.spatialConditions or {}
    record.assumption = record.assumption or "remain"
    record.fingerprint = table.concat({ record.kind or "spatial",
        record.stage or "effect", record.actor or "player",
        tostring(record.target or ""), record.assumption,
        tostring(record.minimum or ""), tostring(record.maximum or "") }, ":")
    table.insert(descriptor.spatialConditions, record)
    descriptor.spatialConditionFingerprint = descriptor.spatialConditionFingerprint
        and descriptor.spatialConditionFingerprint .. "|" .. record.fingerprint
        or record.fingerprint
    if record.conditionalOnly then descriptor.spatialConditionalOnly = true end
end

local function projectedVerdict(descriptor, verdict, reason, record)
    if verdict == false then return reason or "range" end
    if verdict == nil then
        record.assumption, record.conditionalOnly = "prove", true
    end
    addCondition(descriptor, record)
    return nil
end

local function projectedRangeVerdict(action, state, descriptor, verdict,
    reason, record)
    if MovementSetup
        and MovementSetup:CanApproach(action, state, descriptor) then
        record.assumption, record.conditionalOnly = "move", true
        record.movementSetup = true
        record.detail = "move into " .. bandText(record.minimum,
            record.maximum) .. " before using this action"
        addCondition(descriptor, record)
        return nil
    end
    if verdict == false and StealthSetup
        and StealthSetup:CanApproach(action, state, descriptor) then
        record.assumption, record.conditionalOnly = "approach", true
        record.stealthApproach = true
        record.detail = "approach into " .. bandText(record.minimum,
            record.maximum) .. " while remaining undetected"
        addCondition(descriptor, record)
        return nil
    end
    return projectedVerdict(descriptor, verdict, reason, record)
end

local function rootVerdict(action, descriptor, verdict, reason)
    local settled = verdict
    if XelAssist.Game.SpatialEvidence then
        settled = XelAssist.Game.SpatialEvidence:Range(action,
            descriptor.guid, verdict)
    end
    if settled == false then return reason or "range" end
    if settled ~= true then return reason or "range unknown" end
    return nil
end

local function commandRelevant(action, state, descriptor, unit, tooltip)
    local facts = action.facts or {}
    if action.executor == "item" or facts.petLifecycle or facts.playerAttack
        or facts.self or action.executor == "petCommand" then return false end
    if unit == actorUnit(action, false) then return false end
    if isFuture(state) and not (facts.melee or facts.ranged
        or tooltip.minRange ~= nil or tooltip.maxRange ~= nil) then return false end
    return facts.melee or facts.ranged or tooltip.minRange ~= nil
        or tooltip.maxRange ~= nil or descriptor.relation ~= "self"
end

local function commandVerdict(action, state, descriptor, target, tooltip)
    local castUnit = descriptor.castUnit or target
    if not commandRelevant(action, state, descriptor, castUnit, tooltip) then
        return nil, nil, false, castUnit
    end
    local verdict, reason
    if not isFuture(state) and action.actor ~= "pet" then
        verdict = Range:SpellVerdict(action.spellId,
            XelAssist.Game.Capabilities:CastName(action), castUnit)
    end
    local distance, kind = distanceFor(state, descriptor,
        actorUnit(action, false), castUnit)
    local bandVerdict, bandReason = Range:TooltipVerdict(
        tooltip, distance, kind)
    if verdict == false or bandVerdict == false then
        return false, bandVerdict == false and bandReason or "range",
            true, castUnit
    end
    if verdict ~= true then verdict, reason = bandVerdict, bandReason end
    if verdict == nil then reason = reason or "range unknown"
    elseif verdict == false then reason = reason or "range" end
    return verdict, reason, true, castUnit
end

local function effectVerdict(action, state, descriptor, target)
    local minimum, maximum, requiresHitbox, explicit = Range:EffectBand(action)
    if not explicit then return nil, nil, false end
    local effectUnit = action.facts.effectTarget == "target"
        and "target" or target
    local actor = actorUnit(action, true)
    local distance, kind = distanceFor(state, descriptor, actor, effectUnit)
    local verdict, reason = Range:BandVerdict(minimum, maximum,
        distance, kind, requiresHitbox)
    if verdict == nil then reason = reason or "effect range unknown" end
    return verdict, reason, true, effectUnit, actor, minimum, maximum
end

local function commandMaximumVerdict(action, state, descriptor)
    local maximum = tonumber(action.facts.commandMaxRange)
    if not maximum then return nil, nil, false end
    local verdict, reason = Range:BandVerdict(0, maximum,
        state.targetDistance, state.targetDistanceKind, false)
    if verdict == nil then reason = "command range unknown" end
    if verdict == false then reason = "command range" end
    return verdict, reason, true, maximum
end

local function autoShotBlocker(action, state, descriptor)
    local auto, expected = state.autoShot, descriptor.guid or state.targetGUID
    local valid = auto and auto.rangeChecked == true
        and auto.rangeIdentityVerified == true and expected ~= nil
        and auto.rangeTargetGuid == expected and auto.rangeSpellId
            == XelAssist.Combat.AutoShotRange:CanonicalSpellId(action.spellId)
    local verdict = valid and auto.rangeVerdict or nil
    if not isFuture(state) then
        if not valid then return "Auto Shot target evidence changed" end
        if verdict == false then return "range" end
        if verdict ~= true then return "Auto Shot range unknown" end
        return nil
    end
    return projectedVerdict(descriptor, verdict,
        verdict == false and "range" or "Auto Shot range unknown", {
            kind = "range", stage = "launch", actor = "player",
            target = expected, detail = "must remain inside Auto Shot's exact range" })
end

local function rangeBlocker(action, state, descriptor, target, tooltip)
    if action.facts.autoRepeat and not action.facts.wandRepeat then
        return autoShotBlocker(action, state, descriptor)
    end
    local future = isFuture(state)
    local verdict, reason, relevant, unit =
        commandVerdict(action, state, descriptor, target, tooltip)
    if relevant then
        if future then
            local blocker = projectedRangeVerdict(action, state,
                descriptor, verdict, reason, {
                kind = "range", stage = "command",
                actor = actorUnit(action, false), target = descriptor.castGuid
                    or descriptor.guid or unit,
                minimum = tooltip.minRange, maximum = tooltip.maxRange,
                detail = "must remain in " .. bandText(
                    tooltip.minRange, tooltip.maxRange) })
            if blocker then return blocker end
        else
            local blocker = rootVerdict(action, descriptor, verdict, reason)
            if blocker then return blocker end
        end
    end
    local actor, minimum, maximum
    verdict, reason, relevant, unit, actor, minimum, maximum =
        effectVerdict(action, state, descriptor, target)
    if relevant then
        if future then
            local blocker = projectedRangeVerdict(action, state,
                descriptor, verdict, reason, {
                kind = "range", stage = "effect", actor = actor,
                target = descriptor.guid or unit, minimum = minimum,
                maximum = maximum,
                detail = "effect must remain " .. bandText(minimum, maximum) })
            if blocker then return blocker end
        else
            local blocker = rootVerdict(action, descriptor, verdict, reason)
            if blocker then return blocker end
        end
    end
    local commandMaximum
    verdict, reason, relevant, commandMaximum =
        commandMaximumVerdict(action, state, descriptor)
    if relevant then
        if future then
            return projectedRangeVerdict(action, state,
                descriptor, verdict, reason, {
                kind = "range", stage = "command", actor = "player",
                target = descriptor.guid, minimum = 0, maximum = commandMaximum,
                detail = "command target must remain within "
                    .. valueText(commandMaximum) .. " yd" })
        end
        return rootVerdict(action, descriptor, verdict, reason)
    end
    return nil
end

local function positionBlocker(action, state, descriptor, tooltip)
    local facts = action.facts or {}
    if isFuture(state) and action.actor ~= "pet" then
        local cast = XelAssist.Graph.ActionAdmission:Timing(
            action, state, tooltip)
        if cast > 0 then
            if state.moving then return "moving" end
            addCondition(descriptor, { kind = "stationary", stage = "cast",
                actor = "player", target = descriptor.guid,
                detail = "player must remain stationary through the cast" })
        end
    end
    if action.executor == "petCommand" then return nil end
    if descriptor.relation ~= "hostile" then return nil end
    local actor = actorUnit(action, true)
    if not facts.behind then return nil end
    local behind = actor == "pet" and state.actors and state.actors.pet
        and state.actors.pet.behind or state.playerBehindTarget
    if behind == false then
        if isFuture(state) and StealthSetup
            and StealthSetup:CanApproach(action, state, descriptor) then
            addCondition(descriptor, { kind = "behind", stage = "effect",
                actor = actor, target = descriptor.guid,
                assumption = "position", conditionalOnly = true,
                stealthApproach = true,
                detail = "reach and retain the target's rear arc before opening" })
            return nil
        end
        return "must be behind target"
    end
    if isFuture(state) then
        addCondition(descriptor, { kind = "behind", stage = "effect",
            actor = actor, target = descriptor.guid,
            assumption = behind == true and "remain" or "prove",
            detail = "actor must remain behind the target" })
    end
    return nil
end

function S:CaptureRoot(action, state, descriptor, target, tooltip)
    if isFuture(state) then return "root range evidence unknown" end
    return rangeBlocker(action, state, descriptor, target, tooltip)
end

function S:Blocker(action, state, descriptor, target, tooltip)
    if action.facts and action.facts.movementSetup then return nil end
    local blocker = positionBlocker(action, state, descriptor, tooltip)
    if blocker then return blocker end
    if not isFuture(state) and XelAssist.Graph.RootObservation then
        local evidence, status = XelAssist.Graph.RootObservation:Recipient(
            state, action, descriptor)
        if status ~= "absent" then
            if status ~= "known" or not evidence.rangeKnown then
                return "range evidence unknown"
            end
            return evidence.rangeBlocker
        end
    end
    return rangeBlocker(action, state, descriptor, target, tooltip)
end
