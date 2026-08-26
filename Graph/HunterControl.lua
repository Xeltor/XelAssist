-- Consequence-driven Hunter control over sealed DBC evidence.  Roots are
-- projected faithfully but are never called cast interrupts.  Intimidation is
-- valued only when an exact, target-pinned companion swing can land before a
-- modeled hostile consequence; its stun is applied at that later melee event.
XelAssist.Graph.HunterControl = {}
local H = XelAssist.Graph.HunterControl
local State = XelAssist.Graph.State

local EPSILON, READY_DELAY, APPLICATION_BLOCK_THRESHOLD = 0.0001, 0.05, 0.75

local function clamp(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function evidence(action, tooltip)
    if not (action and action.facts
        and action.facts.kind == "crowdControl") then return nil end
    local found = tooltip and (tooltip.hunterControlEvidence
        or tooltip.crowdControlEvidence)
    if type(found) ~= "table" or found.valid ~= true
        or found.portfolio ~= "hunterControl" then return nil end
    return found
end

local function recordFor(state, descriptor)
    local record = descriptor and descriptor.record
    if record then return record end
    if State and State.HostileByKey and descriptor and descriptor.key then
        record = State:HostileByKey(state, descriptor.key)
    end
    if not record and State and State.ActiveHostile then
        record = State:ActiveHostile(state)
    end
    return record
end

local function controlKey(found)
    return "hunterControl:" .. tostring(found.controlSpellId)
end

local function auraSets(state, descriptor)
    local record = recordFor(state, descriptor)
    if record then
        return record.projectedAuras or {}, record.targetAuras or {}, record
    end
    return state.auras or {}, state.targetAuras or {}, nil
end

local function active(aura, lead)
    if type(aura) ~= "table" then return false end
    if clamp(aura.applicationProbability or 1)
        < APPLICATION_BLOCK_THRESHOLD then return false end
    local remaining = tonumber(aura.remaining)
    return remaining == nil or remaining > math.max(0, lead or 0) + EPSILON
end

local function sameControlAura(aura, found)
    return type(aura) == "table" and (tonumber(aura.controlSpellId)
        == tonumber(found.controlSpellId) or tonumber(aura.spellId)
        == tonumber(found.controlSpellId))
end

local function activeControl(state, descriptor, found, lead)
    local projected, observed = auraSets(state, descriptor)
    local aura = projected[controlKey(found)]
    if active(aura, lead) then return aura end
    local _, candidate
    for _, candidate in pairs(projected) do
        if sameControlAura(candidate, found) and active(candidate, lead) then
            return candidate
        end
    end
    for _, candidate in pairs(observed) do
        if sameControlAura(candidate, found) and active(candidate, lead) then
            return candidate
        end
    end
    return nil
end

local function geometry(state, descriptor)
    local record = recordFor(state, descriptor)
    local observed = record and record.geometry and record.geometry.pet
    local pet = state and state.actors and state.actors.pet
    if observed then return observed.distance, observed.distanceKind end
    return pet and pet.distance, pet and pet.distanceKind
end

local function rangeBlocker(state, descriptor, found)
    local distance, kind = geometry(state, descriptor)
    local ranges = XelAssist.Game and XelAssist.Game.Range
    local verdict, reason
    if ranges and ranges.BandVerdict then
        verdict, reason = ranges:BandVerdict(found.minRange, found.maxRange,
            distance, kind, found.effectRangeHitbox == true)
    else
        if type(distance) ~= "number"
            or kind ~= "hitbox" and kind ~= "combat reach" then
            return "companion control range unknown"
        end
        if distance < (tonumber(found.minRange) or 0) then
            return "minimum companion control range"
        end
        if tonumber(found.maxRange) and distance > found.maxRange then
            return "companion control range"
        end
        verdict = true
    end
    if verdict == true then return nil end
    if verdict == false then return reason or "companion control range" end
    return reason or "companion control range unknown"
end

local function targetGuid(state, descriptor)
    return descriptor and (descriptor.guid or descriptor.castGuid)
        or state and state.targetGUID
end

local function modeledCast(state, descriptor)
    local guid = targetGuid(state, descriptor)
    local casts = XelAssist.Graph.HostileCastState
    return casts and casts:Find(state, guid), guid
end

local function armDelay(action, state, tooltip, actionStart)
    local start = math.max(tonumber(state and state.time) or 0,
        tonumber(actionStart) or tonumber(state and state.time) or 0)
    local cast = math.max(0, tonumber(action and action.facts
        and action.facts.cast) or tonumber(tooltip and tooltip.cast) or 0)
    return start - (tonumber(state and state.time) or 0) + cast
end

local function petTargets(pet, guid)
    if not (pet and pet.targetExists == true and guid ~= nil) then return false end
    if pet.targetGuid ~= nil then return pet.targetGuid == guid end
    return pet.targetsCurrent == true
end

local function nextPetMelee(action, state, descriptor, tooltip, actionStart,
    found)
    local pet = state and state.actors and state.actors.pet
    local round = pet and pet.attackRound
    local guid = targetGuid(state, descriptor)
    if not (round and round.projectable == true and round.phaseKnown == true
        and round.verified == true and round.attackActive == true) then
        return nil, "exact companion swing timing unavailable"
    end
    if pet.companionTimelineExact == false then
        return nil, "companion event order is uncertain"
    end
    if not petTargets(pet, guid)
        or round.targetGuid ~= nil and round.targetGuid ~= guid then
        return nil, "companion is not attacking this target"
    end
    local rangeReason = rangeBlocker(state, descriptor, found)
    if rangeReason then return nil, rangeReason end
    local interval = tonumber(round.interval)
    local due = round.readyHeld and READY_DELAY
        or tonumber(round.nextSwingIn)
    if not interval or interval <= 0 or not due or due < 0 then
        return nil, "exact companion swing cadence unavailable"
    end
    due = math.max(READY_DELAY, due)
    local armedAt = armDelay(action, state, tooltip, actionStart)
    if due <= armedAt + EPSILON then
        local cycles = math.floor((armedAt - due) / interval) + 1
        due = due + cycles * interval
    end
    if due - armedAt > (tonumber(found.triggerWindow) or 0) + EPSILON then
        return nil, "companion melee occurs after control proc expires"
    end
    return due, nil
end

local function meleeDelivery(state)
    local resistance, effects = XelAssist.Combat and XelAssist.Combat.Resistance,
        XelAssist.Graph.Effects
    if not (resistance and effects) then return nil end
    local action = { name = "Hunter control trigger melee", actor = "pet",
        facts = { kind = "damage", school = 0, melee = true,
            whiteAttack = true, weaponHand = "main",
            deliveryModel = "physical", deliverySubtype = "melee",
            usesWeaponSkill = true } }
    local estimate = resistance:Estimate(action, "target", { school = 0 }, state)
    if not estimate then return nil end
    local _, delivery = effects:Decision(estimate, state, true)
    return tonumber(delivery) and clamp(delivery) or nil
end

local function pendingControl(pet, found)
    local _, pending
    for _, pending in pairs(pet and pet.pendingMeleeEffects or {}) do
        local sealed = pending.hunterControlEvidence
        if type(sealed) == "table" and tonumber(sealed.controlSpellId)
            == tonumber(found.controlSpellId)
            and (tonumber(pending.remaining) or 1) > 0 then return pending end
    end
    return nil
end

function H:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

function H:Analysis(action, state, descriptor, tooltip, actionStart)
    local found = evidence(action, tooltip)
    if not found then return nil, "exact Hunter control evidence unavailable" end
    if not descriptor or descriptor.relation ~= "hostile" then
        return nil, "Hunter control requires a hostile effect recipient"
    end
    local lead = armDelay(action, state, tooltip, actionStart)
    if activeControl(state, descriptor, found, lead) then
        return nil, "target already controlled"
    end
    local pet = state and state.actors and state.actors.pet
    if found.applicationMode == "nextPetMelee"
        and pendingControl(pet, found) then
        return nil, "companion control proc already armed"
    end
    local rangeReason = rangeBlocker(state, descriptor, found)
    if rangeReason then return nil, rangeReason end
    if found.interruptsCasting ~= true then
        return nil, "root has no modeled hostile consequence"
    end
    local arrival, reason = nextPetMelee(
        action, state, descriptor, tooltip, actionStart, found)
    if not arrival then return nil, reason end
    local swingDelivery = meleeDelivery(state)
    if swingDelivery == nil then
        return nil, "companion melee delivery is unknown"
    end
    local cast, guid = modeledCast(state, descriptor)
    if not cast then return nil, "control consequence unavailable" end
    if arrival + EPSILON >= math.max(0, tonumber(cast.remaining) or 0) then
        return nil, "companion stun arrives after modeled consequence"
    end
    local incoming = XelAssist.Graph.IncomingConsequences
    local value, valueReason
    if incoming then value, valueReason = incoming:PreventedValue(state, cast) end
    if value == nil or value <= 0 then
        return nil, valueReason or "control consequence unavailable"
    end
    return { evidence = found, arrival = arrival, swingDelivery = swingDelivery,
        cast = cast, targetGuid = guid, value = value, reason = valueReason }
end

function H:Blocker(action, state, descriptor, tooltip, actionStart)
    local found = evidence(action, tooltip)
    if not found then return nil, false end
    local analysis, reason = self:Analysis(
        action, state, descriptor, tooltip, actionStart)
    return analysis and nil or reason, true
end

function H:Score(context)
    local found = evidence(context and context.action,
        context and context.tooltip)
    if not found then return false end
    local analysis, reason = self:Analysis(context.action, context.state,
        context.descriptor, context.tooltip, context.actionStart)
    if not analysis then
        context.value, context.reason = -100000,
            reason or "exact Hunter control consequence unavailable"
        return true
    end
    local resultDelivery = clamp(context.effectDelivery)
    context.hunterControlArrival = analysis.arrival
    context.hunterControlSwingDelivery = analysis.swingDelivery
    context.value = analysis.value * analysis.swingDelivery * resultDelivery
    context.reason = analysis.reason
    return true
end

local function suppressCast(state, guid, probability)
    local casts = XelAssist.Graph.HostileCastState
    local cast = casts and casts:Find(state, guid)
    if not cast or (tonumber(cast.remaining) or 0) <= 0 then return false end
    local remaining = (tonumber(cast.probability) or 1)
        * (1 - clamp(probability))
    if remaining <= 0.05 then casts:Retire(state, guid, cast.generation)
    else casts:SetProbability(state, guid, cast.generation, remaining) end
    return true
end

local function annotateAura(aura, found, candidate, probability)
    aura.crowdControl, aura.controlType = true, found.controlType
    aura.controlSpellId, aura.spellId = found.controlSpellId,
        found.controlSpellId
    aura.sourceActor = found.sourceActor
    aura.targetGuid = aura.targetGuid or candidate and candidate.targetGUID
    aura.targetKey = aura.targetKey or candidate and candidate.targetKey
    if aura.rawApplicationProbability == nil then
        aura.rawApplicationProbability = clamp(probability)
    end
    aura.applicationProbability = clamp(probability)
    aura.breaksOnAnyDamage = found.breaksOnAnyDamage == true
    aura.breaksOnDirectDamage = found.breaksOnDirectDamage == true
    aura.damageBreakSpecified = found.damageBreakSpecified == true
    aura.crowdControlEvidenceSource = found.source
    return aura
end

local function elapsedAtApplication(context)
    if context and context.petEventContext then
        return math.max(0, tonumber(
            context.petEventContext.applicationElapsed) or 0)
    end
    return math.max(0, tonumber(context and context.applicationElapsed) or 0)
end

function H:Apply(state, candidate, context)
    local found = evidence(candidate and candidate.action,
        candidate and candidate.tooltip)
    if not found or candidate.targetRelation ~= "hostile" then return false end
    local delivery = tonumber(candidate.effectDelivery)
    if delivery == nil or clamp(delivery) <= 0 then return false end
    delivery = clamp(delivery)
    local elapsed = elapsedAtApplication(context)
    if found.applicationMode == "nextPetMelee" then
        local pet = state.actors and state.actors.pet
        if not pet then return false end
        pet.pendingMeleeEffects = pet.pendingMeleeEffects or {}
        local key = candidate.action.name
        local pending = pet.pendingMeleeEffects[key] or {}
        pending.remaining = math.max(0,
            (tonumber(found.triggerWindow) or 0) - elapsed)
        if pending.remaining <= 0 then return false end
        pending.duration = tonumber(found.triggerWindow)
        pending.targetGuid, pending.targetKey = candidate.targetGUID,
            candidate.targetKey
        pending.stunDuration = tonumber(found.duration)
        pending.resultSpellId = found.resultSpellId
        pending.auraKey = key
        pending.resultDelivery = delivery
        pending.hunterControlEvidence = copy(found)
        pet.pendingMeleeEffects[key] = pending
        return true
    end
    local duration = tonumber(found.duration)
    local remaining = duration and duration - elapsed or nil
    if not remaining or remaining <= 0 then return false end
    local projected, _, record = auraSets(state, candidate.descriptor)
    local probability = delivery
    projected[controlKey(found)] = annotateAura({ remaining = remaining,
        duration = duration, mine = true, target = candidate.target },
        found, candidate, probability)
    if found.interruptsCasting == true then
        suppressCast(state, candidate.targetGUID, probability)
    end
    if record and State and State.RefreshHostileRecord then
        State:RefreshHostileRecord(state, record.key)
    end
    return true
end

-- Called only after Game.Pets.Effects has consumed a matching successful
-- melee branch.  The existing aura carries that melee's conditional delivery;
-- the separately captured result-spell delivery is multiplied exactly once.
function H:ResolveDeferred(state, effect, targetGuid)
    local found = effect and effect.hunterControlEvidence
    if type(found) ~= "table" or found.valid ~= true
        or found.applicationMode ~= "nextPetMelee"
        or effect.targetGuid ~= targetGuid then return false end
    local aura = state.auras and state.auras[effect.auraKey]
    if type(aura) ~= "table" then return false end
    if aura.hunterControlResolved then return true end
    local trigger, result = tonumber(aura.applicationProbability),
        tonumber(effect.resultDelivery)
    if trigger == nil or result == nil then return false end
    local probability = clamp(trigger) * clamp(result)
    annotateAura(aura, found, { targetGUID = targetGuid,
        targetKey = effect.targetKey }, probability)
    aura.hunterControlResolved = true
    if found.interruptsCasting == true then
        suppressCast(state, targetGuid, probability)
    end
    return true
end
