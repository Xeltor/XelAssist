-- Passive companion combat events. Scheduling captures the pet's exact target;
-- resolution mutates that hostile record rather than whichever target happens
-- to occupy the selected compatibility mirror later in the graph path.
XelAssist.Graph.CompanionEvents = {}
local C = XelAssist.Graph.CompanionEvents
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Threat = XelAssist.Graph.CompanionEventThreat
local Scheduler = XelAssist.Graph.CompanionScheduler
local CastEvents = XelAssist.Graph.CompanionCastEvents
local CastRuntime = XelAssist.Graph.CompanionCastRuntime
local MAX_HOSTILES = 5

local function hostilesOf(state)
    local hostiles = state and state.hostiles
    if type(hostiles) ~= "table" or type(hostiles.order) ~= "table"
        or type(hostiles.byKey) ~= "table" then return nil end
    return hostiles
end

local function hostileForGuid(state, guid)
    local hostiles = hostilesOf(state)
    if not hostiles or guid == nil then return nil, nil end
    local direct = hostiles.byKey[guid]
    if direct and (direct.guid == nil or direct.guid == guid) then
        return guid, direct
    end
    local count = math.min(table.getn(hostiles.order), MAX_HOSTILES)
    local i
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if record and record.guid == guid then return key, record end
    end
    return nil, nil
end
local function selectedIdentity(state)
    local hostiles = hostilesOf(state)
    if not hostiles then return state and state.targetGUID, nil, nil end
    local count = math.min(table.getn(hostiles.order), MAX_HOSTILES)
    local fallbackKey, fallback
    local i
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if record then
            if key == hostiles.selectedKey then
                return record.guid or key, key, record
            end
            if not fallback and record.selected == true then
                fallbackKey, fallback = key, record
            end
        end
    end
    if fallback then return fallback.guid or fallbackKey, fallbackKey, fallback end
    return nil, nil, nil
end

local function selectedKey(state, key, record)
    local hostiles = hostilesOf(state)
    if not hostiles then return false end
    if hostiles.selectedKey ~= nil then return key == hostiles.selectedKey end
    return record and record.selected == true
end

local function provenDead(record)
    if not record then return true end
    if record.dead == true or record.projectedDefeated == true then return true end
    return record.healthExact == true and tonumber(record.health) ~= nil
        and tonumber(record.health) <= 0
end

local function captureTarget(state, pet)
    if not (pet and pet.targetExists) then return nil, nil, nil end
    local hostiles = hostilesOf(state)
    if hostiles then
        local petGuid, aliasGuid = pet.targetGuid, nil
        if type(hostiles.byUnit) == "table" then
            local aliasKey = hostiles.byUnit.pettarget
            local alias = aliasKey and hostiles.byKey[aliasKey]
            if alias then aliasGuid = alias.guid or aliasKey end
        end
        if petGuid ~= nil and aliasGuid ~= nil and petGuid ~= aliasGuid then
            return nil, nil, nil
        end
        local guid = petGuid or aliasGuid
        if guid == nil and pet.targetsCurrent == true then
            guid = selectedIdentity(state)
        end
        local key, record = hostileForGuid(state, guid)
        if not key or provenDead(record) then return nil, nil, nil end
        return guid, key, true
    end
    if pet.targetsCurrent ~= true then return nil, nil, nil end
    local guid = pet.targetGuid or state.targetGUID
    if guid == nil or pet.targetGuid ~= nil and state.targetGUID ~= nil
        and pet.targetGuid ~= state.targetGUID then return nil, nil, nil end
    return guid, nil, false
end

function C:Events(out, candidate)
    local pet = out.actors and out.actors.pet
    local targetGuid, targetKey, targetLocal = captureTarget(out, pet)
    if not (pet and pet.autocasts) then return {} end
    local record
    if targetLocal then _, record = hostileForGuid(out, targetGuid) end
    local identity
    if targetGuid then identity = {
        guid = targetGuid, key = targetKey, localTarget = targetLocal } end
    local events = Scheduler:Events(pet, record, candidate, identity)
    local i
    for i = 1, table.getn(events) do
        events[i].windowStart = tonumber(out.time) or 0
    end
    if pet.actionReadyIn and pet.actionReadyIn > 0 then
        out.actorReadyAt = out.actorReadyAt or {}
        out.actorReadyAt.pet = math.max(tonumber(out.actorReadyAt.pet) or 0,
            (tonumber(out.time) or 0) + (tonumber(candidate.downtime) or 0)
                + pet.actionReadyIn)
    end
    return events
end
function C:SyncChosenCooldown(out, candidate, context)
    local action = candidate and candidate.action
    local pet = out and out.actors and out.actors.pet
    if not (action and pet and action.actor == "pet"
        and action.executor == "petAbility") then return end
    local i, ambient
    for i = 1, table.getn(pet.autocasts or {}) do
        ambient = pet.autocasts[i]
        if Scheduler:MatchesAction(action, ambient) then
            local cooldown = math.max(0.1, tonumber(
                    candidate.tooltip and candidate.tooltip.cooldown)
                or tonumber(ambient.cooldown) or 1.5)
            local after = math.max(0, (tonumber(candidate.downtime) or 0) -
                (tonumber(context and context.applicationOffset) or 0))
            ambient.readyIn = math.max(0.1, cooldown - after)
        end
    end
end

local function eventTarget(out, entry)
    if entry.targetLocal then
        if not hostilesOf(out) then return nil end
        local key, record = hostileForGuid(out, entry.targetGuid)
        if not key or key ~= entry.targetKey or provenDead(record) then return nil end
        record.projectedAuras = record.projectedAuras or {}
        record.threat = record.threat or { playerHasAggro = record.hasPlayerAggro,
            petHasAggro = record.hasPetAggro, playerDelta = 0, petDelta = 0 }
        local view = State.HostileContext and State:HostileContext(out, key)
        if not view then return nil end
        return view, key, record, selectedKey(out, key, record)
    end
    if hostilesOf(out) or entry.targetGuid ~= out.targetGUID then return nil end
    if out.targetHealthExact and (tonumber(out.targetHealth) or 0) <= 0 then
        return nil
    end
    return out, nil, nil, true
end

local function candidateTargetsEntry(candidate, entry)
    if not candidate then return false end
    if entry.targetKey ~= nil and candidate.targetKey ~= nil then
        return entry.targetKey == candidate.targetKey
    end
    return entry.targetGuid ~= nil and candidate.targetGUID ~= nil
        and entry.targetGuid == candidate.targetGUID
end

local function eventState(source, candidate, context, entry)
    local base = source
    if entry.targetLocal then
        base = State.HostileContext
            and State:HostileContext(source, entry.targetKey) or nil
        if not base then return nil end
    end
    local state = Effects:StateAtImpact(base, entry.offset)
    if state and context and context.applicationOffset
        and entry.offset >= context.applicationOffset
        and candidateTargetsEntry(candidate, entry)
        and context.ChangesHostileTarget and context.ProjectCurrentApplication
        and context:ChangesHostileTarget() then
        state = State:Copy(state)
        context:ProjectCurrentApplication(state,
            entry.offset - context.applicationOffset)
    end
    return state
end

local function petPower(pet, ambient)
    local power = math.max(0, tonumber(ambient.power) or 0)
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        power = power * XelAssist.Game.Pets.Effects:DamageMultiplier(pet)
    end
    return power
end

local function attributableLivePetAura(target, pet, ambient)
    local aura = target.targetAuras and target.targetAuras[ambient.name]
    if type(aura) ~= "table" then return nil end
    if aura.spellId ~= nil and ambient.spellId ~= nil
        and tonumber(aura.spellId) ~= tonumber(ambient.spellId) then return nil end
    if aura.sourceGUID ~= nil then
        if pet.guid ~= nil and aura.sourceGUID == pet.guid then return aura end
        return nil
    end
    if aura.sourceUnit ~= nil then
        if aura.sourceUnit == "pet" then return aura end
        return nil
    end
    if aura.playerOrPet == true and aura.mine ~= true then return aura end
    return nil
end

local function deliveryFor(source, candidate, context, entry, ambient, power)
    local state = eventState(source, candidate, context, entry)
    local delivery, decision, conditional = 1, 1, 1
    if XelAssist.Combat.Resistance then
        if not state then return nil, nil, nil, nil end
        local tooltip = ambient.tooltip or {}
        local estimate = XelAssist.Combat.Resistance:Estimate(
            ambient, "target", tooltip, state)
        decision, delivery = Effects:Decision(estimate, state, true)
        if ambient.kind == "dot" then
            local duration = tonumber(tooltip.duration)
                or tonumber(ambient.facts and ambient.facts.duration)
            conditional = Effects:OverWindow(ambient, "target", tooltip,
                state, 0, duration, "periodic", true) or 1
        end
    end
    return power * (decision or 1), delivery or 1, conditional, state
end

local function activeAt(aura, offset)
    if type(aura) ~= "table" then return false end
    local remaining = tonumber(aura.remaining)
    return remaining == nil or remaining > offset
end

local function stackPriorAtEvent(target, eventTarget, pet, ambient, offset)
    local prior = target.auras and target.auras[ambient.name]
    if type(prior) == "table" then return prior end
    local projected = eventTarget and eventTarget.auras
        and eventTarget.auras[ambient.name]
    if activeAt(projected, offset) then return projected end
    local live = attributableLivePetAura(eventTarget or {}, pet, ambient)
    if activeAt(live, offset) then return live end
    return nil
end

local function applyDot(target, out, source, candidate, context, entry,
    ambient, pet, record, selected)
    local tooltip, facts = ambient.tooltip or {}, ambient.facts or {}
    local duration = tonumber(tooltip.duration) or tonumber(facts.duration)
    if not duration or duration <= 0 then return false end
    local power = petPower(pet, ambient)
    local expected, delivery, conditional, eventTarget = deliveryFor(
        source, candidate, context, entry, ambient, power)
    if expected == nil then return false end
    local stackPrior = stackPriorAtEvent(
        target, eventTarget, pet, ambient, entry.offset)
    local stacks = stackPrior and (stackPrior.expectedStacks
        or stackPrior.stacks or 0) or 0
    local maximum = tonumber(facts.stackable)
    local expectedStacks = maximum
        and math.min(maximum, stacks + delivery) or nil
    local scale = maximum and math.min(maximum, stacks + 1) or 1
    local branches = XelAssist.Graph.EventAuras:ReplaceScheduledAura(out,
        entry.targetKey, entry.targetGuid, ambient.name, delivery,
        target.auras and target.auras[ambient.name])
    target.auras = target.auras or {}
    target.auras[ambient.name] = { remaining = duration, duration = duration,
        mine = true, target = "target", targetKey = entry.targetKey,
        targetGuid = entry.targetGuid, sourceActor = "pet",
        periodicRate = power * scale * delivery * conditional / duration,
        periodicRawRate = not maximum and power / duration or nil,
        periodicAction = ambient,
        periodicTooltip = { school = tooltip.school },
        periodicInterval = tooltip.periodicInterval,
        periodicNextIn = XelAssist.Game.SpellTiming:Next(
            tooltip.periodicInterval, 0),
        periodicThreatActor = "pet",
        periodicThreatMultiplier = Threat:DamageMultiplier(ambient, pet),
        periodicBranches = branches,
        applicationProbability = delivery,
        stacks = maximum and math.min(maximum,
            (stackPrior and stackPrior.stacks or 0) + 1) or nil,
        expectedStacks = expectedStacks }
    Threat:ConsumeMelee(target, out, ambient, entry.targetGuid, delivery,
        record, selected)
    return true
end

local function applyDamage(target, out, source, candidate, context, entry,
    ambient, pet, record, selected)
    local power = petPower(pet, ambient)
    local expected, delivery = deliveryFor(
        source, candidate, context, entry, ambient, power)
    if expected == nil then return false end
    if record then
        local dealt = expected
        if record.healthExact and tonumber(record.health) then
            local beforeHealth = tonumber(record.health)
            record.health = math.max(0, beforeHealth - expected)
            dealt = beforeHealth - record.health
            if record.health <= 0 then
                record.dead, record.projectedDefeated = true, true
            end
        end
        Threat:AddDamage(record, ambient, dealt, pet)
    elseif target.targetHealthExact then
        target.targetHealth = math.max(0, target.targetHealth - expected)
    end
    Threat:ConsumeMelee(target, out, ambient, entry.targetGuid, delivery,
        record, selected)
    return true
end

local function applyThreat(target, out, source, candidate, context, entry,
    ambient, record, selected)
    local _, delivery = deliveryFor(
        source, candidate, context, entry, ambient, 1)
    if delivery == nil then return false end
    return Threat:ApplyRelative(target, out, ambient, record, selected, delivery)
end

local function applyTaunt(target, out, source, candidate, context, entry,
    ambient, record, selected)
    local _, delivery = deliveryFor(
        source, candidate, context, entry, ambient, 1)
    if delivery == nil then return false end
    return Threat:ApplyTaunt(
        target, out, ambient, record, selected, delivery)
end

local function syncSelected(out, record, selected)
    if not (record and selected) then return end
    if State.SyncSelectedHostile then State:SyncSelectedHostile(out) end
    if record.threat then
        if record.threat.projectedPlayerHasAggro ~= nil then
            out.hasAggro = record.threat.projectedPlayerHasAggro
        end
        if out.actors and out.actors.pet
            and record.threat.projectedPetHasAggro ~= nil then
            out.actors.pet.hasAggro = record.threat.projectedPetHasAggro
        end
    end
    if record.dead == true and out.autoShot then out.autoShot.active = false end
end
local function tiedHostileValid(out, pet, entry)
    if not entry.pendingCompletion then
        if not pet.targetExists then return false end
        local currentGuid, currentKey = captureTarget(out, pet)
        if currentGuid ~= entry.targetGuid or currentKey ~= entry.targetKey then
            return false
        end
    end
    return eventTarget(out, entry) ~= nil
end

local function startTargetValid(out, pet, entry)
    if entry.targetIndependent then return true end
    if not pet.targetExists then return false end
    local guid, key = captureTarget(out, pet)
    return guid == entry.targetGuid and key == entry.targetKey
        and eventTarget(out, entry) ~= nil
end

function C:Apply(out, source, candidate, context, entry)
    local pet = out.actors and out.actors.pet
    if not pet then return false end
    if entry.kind == "petAutocastTimelineCap" then
        pet.resourceExact, pet.actionReadyExact = false, false
        pet.resourceUnknownReason = "companion autocast timeline cap"
        return true
    end
    if entry.kind == "petAutocastStart" then
        return CastRuntime:Begin(
            out, pet, entry, startTargetValid(out, pet, entry))
    end
    if not CastEvents:Started(entry) then return false end
    if entry.tiedReservation then
        return entry.kind == "petAutocastUnknown"
            and CastRuntime:ReserveTied(
                out, pet, entry, tiedHostileValid(out, pet, entry)) or false
    end
    local _, ambient = Scheduler:FindAmbient(pet, entry)
    if not ambient then return false end
    if entry.targetIndependent then
        return entry.kind == "petAutocastUnknown"
            and CastRuntime:Reserve(out, pet, ambient, entry) or false
    end
    if not entry.pendingCompletion then
        if not pet.targetExists then return false end
        local currentGuid, currentKey = captureTarget(out, pet)
        if currentGuid ~= entry.targetGuid or currentKey ~= entry.targetKey then
            return false
        end
    end
    local target, _, record, selected = eventTarget(out, entry)
    if not target then
        if entry.pendingCompletion then
            return CastRuntime:Reserve(out, pet, ambient, entry)
        end
        return false
    end
    if not CastRuntime:Reserve(out, pet, ambient, entry) then return false end
    if entry.kind == "petAutocastUnknown" then return true end
    local changed
    if ambient.kind == "dot" then
        changed = applyDot(target, out, source, candidate, context, entry,
            ambient, pet, record, selected)
    elseif ambient.kind == "damage" then
        changed = applyDamage(target, out, source, candidate, context, entry,
            ambient, pet, record, selected)
    elseif ambient.kind == "petThreat" then
        changed = applyThreat(target, out, source, candidate, context, entry,
            ambient, record, selected)
    elseif ambient.kind == "taunt" then
        changed = applyTaunt(target, out, source, candidate, context, entry,
            ambient, record, selected)
    end
    syncSelected(out, record, selected and changed)
    if not record and out.targetHealthExact and out.targetHealth <= 0 then
        out.hostile = false
        if out.autoShot then out.autoShot.active = false end
    end
    return changed and true or false
end
