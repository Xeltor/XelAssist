-- Companion-owned threat consequences shared by chosen and ambient pet
-- actions. Scheduling and recipient identity remain with CompanionEvents.
XelAssist.Graph.CompanionEventThreat = {}
local T = XelAssist.Graph.CompanionEventThreat

function T:DamageMultiplier(ambient, pet)
    local facts = ambient and ambient.facts or {}
    local multiplier = tonumber(facts.threat)
        or tonumber(ambient and ambient.threat) or 1
    local petMultiplier = XelAssist.Game.Pets and XelAssist.Game.Pets.Effects
        and XelAssist.Game.Pets.Effects:ThreatMultiplier(pet) or 1
    return multiplier * 0.9 * petMultiplier
end

function T:AddDamage(record, ambient, amount, pet)
    if not record or amount <= 0 then return end
    local threat = amount * self:DamageMultiplier(ambient, pet)
    record.projectedThreat = record.projectedThreat or {}
    record.projectedThreat.pet = (record.projectedThreat.pet or 0) + threat
    record.threat = record.threat or {}
    record.threat.petDelta = (tonumber(record.threat.petDelta) or 0) + threat
end

function T:ConsumeMelee(target, out, action, targetGuid, delivery, record,
    selected)
    if not (XelAssist.Game.Pets and XelAssist.Game.Pets.Effects) then return end
    local pet = out.actors and out.actors.pet
    local targetPet = target.actors and target.actors.pet
    local priorRoot = pet and pet.threatEstimate
    local priorEstimate
    if record then priorEstimate = record.companionThreatEstimate
    else priorEstimate = targetPet and targetPet.threatEstimate end
    if record and targetPet then
        targetPet.threatEstimate = priorEstimate
        if record.threat and record.threat.projectedPetHasAggro ~= nil then
            targetPet.hasAggro = record.threat.projectedPetHasAggro
        elseif record.threat then targetPet.hasAggro = record.threat.petHasAggro end
    end
    local effect = XelAssist.Game.Pets.Effects:ConsumeMelee(
        target, action, targetGuid, delivery)
    if effect and record and effect.projectedThreat then
        record.projectedThreat = record.projectedThreat or {}
        record.projectedThreat.pet = (record.projectedThreat.pet or 0)
            + effect.projectedThreat
        record.threat = record.threat or {}
        record.threat.petDelta = (tonumber(record.threat.petDelta) or 0)
            + effect.projectedThreat
    end
    local estimate = targetPet and targetPet.threatEstimate
    if record and estimate ~= priorEstimate then
        record.companionThreatEstimate = estimate
        if selected and pet then pet.threatEstimate = estimate end
    end
    if pet and not selected then pet.threatEstimate = priorRoot end
    return effect
end

local function copyTable(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function T:ApplyRelative(target, out, ambient, record, selected, delivery)
    local threat = XelAssist.Graph.CompanionThreat
    if not threat then return false end
    if not record then return threat:Apply(target, ambient, nil, delivery) end
    local actors, pet = copyTable(target.actors),
        copyTable(target.actors and target.actors.pet)
    if not pet then return false end
    local priorActionDelta = record.companionThreatEstimate
        and tonumber(record.companionThreatEstimate.delta) or 0
    local otherDelta = (tonumber(record.threat.petDelta) or 0)
        - priorActionDelta
    if record.threat.projectedPetHasAggro ~= nil then
        pet.hasAggro = record.threat.projectedPetHasAggro
    else pet.hasAggro = record.threat.petHasAggro end
    pet.threatEstimate = record.companionThreatEstimate
    actors.pet, target.actors = pet, actors
    local applied, estimate = threat:Apply(target, ambient, nil, delivery)
    if not applied then return false end
    local actionDelta = tonumber(estimate.stepDelta)
    if actionDelta ~= nil then
        actionDelta = priorActionDelta + actionDelta
        estimate.delta = actionDelta
    else actionDelta = tonumber(estimate.delta) or priorActionDelta end
    record.companionThreatEstimate = estimate
    record.threat.petDelta = otherDelta
        + actionDelta
    record.projectedThreat = record.projectedThreat or {}
    record.projectedThreat.petThreatAction = actionDelta
    if selected and out.actors and out.actors.pet then
        out.actors.pet.threatEstimate = estimate
    end
    return true
end

function T:ApplyTaunt(target, out, ambient, record, selected, delivery)
    local petTank = XelAssistCharDB.petThreat == "tank"
        or (XelAssistCharDB.petThreat ~= "avoid" and out.groupSize == 0)
    if not petTank then return false end
    local pet = out.actors and out.actors.pet
    if record then
        record.threat.tauntDelivery = delivery
        record.threat.projectedSource = ambient.name
        if delivery >= 0.999 then
            record.tauntFocusUntil, record.tauntFocusExpired = nil, nil
            record.projectedTauntedByPlayer = nil
            record.threat.projectedOwnershipUnknown = nil
            record.threat.projectedPlayerHasAggro = false
            record.threat.projectedPetHasAggro = true
            record.threat.projectedVictimGuid = pet and pet.guid or nil
            record.projectedTauntedByPet = true
            if selected and pet then pet.hasAggro = true end
        else record.threat.projectedTauntUncertain = delivery > 0 end
    elseif delivery >= 0.999 then
        target.hasAggro = false
        if pet then pet.hasAggro = true end
    end
    return true
end
