-- Passage-of-time projections that happen while a candidate occupies the
-- player: friendly periodic healing, pet autocasts, hostile periodic effects,
-- and expiration of observed or projected target state.
XelAssist.Graph.OngoingEffects = {}
local O = XelAssist.Graph.OngoingEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Companion = XelAssist.Graph.CompanionEvents
local PlayerSwings = XelAssist.Graph.PlayerSwings
local EventAuras = XelAssist.Graph.EventAuras
local MAX_HOSTILES = 5

local function hostilesOf(state)
    local hostiles = state and state.hostiles
    if type(hostiles) ~= "table" or type(hostiles.order) ~= "table"
        or type(hostiles.byKey) ~= "table" then return nil end
    return hostiles
end

local function localRecord(state, key, guid)
    local hostiles = hostilesOf(state)
    local record = hostiles and key ~= nil and hostiles.byKey[key]
    if not record or guid ~= nil and (record.guid or key) ~= guid then
        return nil
    end
    return record
end

local function isSelected(state, key, record)
    local hostiles = hostilesOf(state)
    if not hostiles then return false end
    if hostiles.selectedKey ~= nil then return hostiles.selectedKey == key end
    return record and record.selected == true
end

local function syncLocal(state, key, record, changed)
    if not changed or not isSelected(state, key, record) then return end
    if State.SyncSelectedHostile then State:SyncSelectedHostile(state) end
    local threat = record and record.threat
    if threat and threat.projectedPlayerHasAggro ~= nil then
        state.hasAggro = threat.projectedPlayerHasAggro
    end
    if threat and threat.projectedPetHasAggro ~= nil
        and state.actors and state.actors.pet then
        state.actors.pet.hasAggro = threat.projectedPetHasAggro
    end
    if record.dead == true and state.autoShot then state.autoShot.active = false end
end

local function candidateTargets(candidate, key, guid)
    if key == nil then return true end
    local descriptor = candidate and candidate.descriptor or {}
    local candidateKey = candidate and candidate.targetKey or descriptor.key
    if candidateKey ~= nil then return candidateKey == key end
    local candidateGuid = candidate and candidate.targetGUID or descriptor.guid
    return candidateGuid ~= nil and candidateGuid == guid
end

local function eventSource(source, entry)
    if entry.targetKey == nil then
        return hostilesOf(source) and nil or source
    end
    if not localRecord(source, entry.targetKey, entry.targetGuid) then return nil end
    return State.HostileContext and State:HostileContext(
        source, entry.targetKey) or nil
end

local function advanceFriendlies(state, elapsed)
    if not state.friendlies or elapsed <= 0 then return end
    local i, name, aura
    for i = 1, table.getn(state.friendlies.order or {}) do
        local record = State:FriendlyByKey(
            state, state.friendlies.order[i])
        if record then
            for name, aura in pairs(record.auras or {}) do
                if type(aura) == "table" then
                    local active = aura.remaining
                        and math.min(elapsed, aura.remaining) or elapsed
                    if aura.periodicHealRate and active > 0 then
                        record.health = math.min(record.healthMax,
                            record.health + aura.periodicHealRate * active)
                    end
                    if aura.remaining then
                        aura.remaining = math.max(0, aura.remaining - elapsed)
                        if aura.remaining <= 0 then record.auras[name] = nil end
                    end
                end
            end
            for name, aura in pairs(record.absorbs or {}) do
                if type(aura) == "table" and aura.remaining then
                    aura.remaining = math.max(0, aura.remaining - elapsed)
                    if aura.remaining <= 0 then record.absorbs[name] = nil end
                end
            end
        end
    end
end

local function advancePlayerCast(state, elapsed)
    if not state.playerCasting then return end
    local remaining = tonumber(state.castRemaining)
    if not remaining then return end
    state.castRemaining = math.max(0, remaining - elapsed)
    if state.castRemaining <= 0 then
        state.playerCasting, state.playerChanneling = false, false
        state.playerCastName = nil
    end
end

local function projectedEventState(source, candidate, context, entry, offset)
    local base = eventSource(source, entry)
    if not base then return nil end
    local state = Effects:StateAtImpact(base, offset)
    if state and candidateTargets(candidate, entry.targetKey, entry.targetGuid)
        and offset >= context.applicationOffset
        and context:ChangesHostileTarget() then
        state = State:Copy(state)
        context:ProjectCurrentApplication(state,
            offset - context.applicationOffset)
    end
    return state
end

local function markTargetDeath(out)
    if not (out.targetHealthExact and out.targetHealth <= 0) then return end
    out.hostile = false
    if out.autoShot then out.autoShot.active = false end
end

local function periodicSegment(aura, state, span)
    return EventAuras:Damage(aura, state, span)
end

local function periodicDamage(source, candidate, context, entry, elapsed,
    baseState)
    local aura = entry.aura
    local fallback = math.max(0, aura.periodicRate or 0) * elapsed
    if not (aura.periodicRawRate and aura.periodicAction
        and XelAssist.Combat.Resistance and elapsed > 0) then
        return fallback
    end
    if candidateTargets(candidate, entry.targetKey, entry.targetGuid)
        and context:ChangesHostileTarget()
        and context.applicationOffset < elapsed then
        local before = math.max(0, context.applicationOffset)
        local afterState = State:Copy(
            Effects:StateAtImpact(source, context.applicationOffset))
        context:ProjectCurrentApplication(afterState, 0)
        context:AddProjectedModifierAura(afterState)
        return periodicSegment(aura, baseState, before)
            + periodicSegment(aura, afterState, elapsed - before)
    end
    return periodicSegment(aura, baseState, elapsed)
end

local function addPeriodicEvent(events, kind, name, aura, offset,
    priority, left, right, span, key, guid, scheduleToken)
    table.insert(events, { owner = "ongoing", kind = kind, auraName = name,
        aura = aura, offset = offset, priority = priority,
        left = left, right = right, tickSpan = span,
        targetKey = key, targetGuid = guid, scheduleToken = scheduleToken })
end

local function appendClock(events, out, name, aura, outAura, key, guid,
    candidate, context)
    if not (type(aura) == "table" and aura.remaining
        and aura.periodicRate and aura.target == "target") then return end
    local token = EventAuras:ScheduledToken(out, key, guid, name, outAura)
    local active = math.min(aura.remaining, candidate.downtime)
    local interval = tonumber(aura.periodicInterval)
    local nextTick = tonumber(aura.periodicNextIn)
    if interval and interval > 0 and nextTick then
        nextTick = math.max(0, nextTick)
        while nextTick <= active do
            local priority = nextTick < context.applicationOffset and 10 or 60
            addPeriodicEvent(events, "periodicTick", name, aura,
                nextTick, priority, nil, nil, interval, key, guid, token)
            nextTick = nextTick + interval
        end
    elseif active > 0 then
        local cut = candidateTargets(candidate, key, guid)
            and context.applicationOffset or nil
        if cut and cut > 0 and cut < active then
            addPeriodicEvent(events, "periodicSegment", name, aura,
                cut, 10, 0, cut, nil, key, guid, token)
            addPeriodicEvent(events, "periodicSegment", name, aura,
                active, 60, cut, active, nil, key, guid, token)
        else
            local priority = cut and active <= cut and 10 or 60
            addPeriodicEvent(events, "periodicSegment", name, aura,
                active, priority, 0, active, nil, key, guid, token)
        end
    end
end

local function appendPeriodic(events, out, auras, outAuras, key, guid,
    candidate, context)
    local name, aura, i
    for name, aura in pairs(auras or {}) do
        local outAura = outAuras and outAuras[name]
        appendClock(events, out, name, aura, outAura, key, guid,
            candidate, context)
        local branches = type(aura) == "table" and aura.periodicBranches
        for i = 1, table.getn(branches or {}) do
            appendClock(events, out, name, branches[i],
                outAura and outAura.periodicBranches
                    and outAura.periodicBranches[i], key, guid,
                candidate, context)
        end
    end
end

local function periodicEvents(out, source, candidate, context)
    local events, hostiles = {}, hostilesOf(source)
    if not hostiles then
        appendPeriodic(events, out, source.auras, out.auras,
            nil, source.targetGUID, candidate, context)
        return events
    end
    local i, count = nil, math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        local outRecord = localRecord(out, key, record and record.guid or key)
        if record then appendPeriodic(events, out, record.projectedAuras,
            outRecord and outRecord.projectedAuras, key, record.guid or key,
            candidate, context) end
    end
    return events
end

local function hasFallback(view)
    local _, effect
    for _, effect in pairs(view.targetModifierEffects or {}) do
        if effect.fallbackRemaining then return true end
    end
    return false
end

local function ageAuraSet(out, candidate, key, record)
    local view = key ~= nil and State.HostileContext
        and State:HostileContext(out, key) or out
    if not view then return false end
    local auras
    if record then auras = record.projectedAuras or {}
    else auras = out.auras or {} end
    local changed, name, aura = false, nil, nil
    for name, aura in pairs(auras) do
        if type(aura) == "table" and aura.remaining then
            local elapsed = math.min(aura.remaining, candidate.downtime)
            local interval = tonumber(aura.periodicInterval)
            local nextTick = tonumber(aura.periodicNextIn)
            if interval and interval > 0 and nextTick then
                while nextTick <= elapsed do
                    nextTick = nextTick + interval
                end
                aura.periodicNextIn = math.max(0, nextTick - elapsed)
            end
            EventAuras:AgeBranches(aura, candidate.downtime)
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 and not EventAuras:PromoteBranch(aura) then
                if aura.targetModifier then
                    Effects:RemoveTargetModifier(view, name)
                end
                auras[name] = nil
            end
            changed = elapsed > 0 or changed
        end
    end
    local fallback = hasFallback(view)
    Effects:AdvanceModifierFallbacks(view, candidate.downtime)
    return changed or fallback
end

local function advanceAuraDurations(out, candidate)
    local hostiles = hostilesOf(out)
    if not hostiles then ageAuraSet(out, candidate) return end
    local i, count = nil, math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key, record = hostiles.order[i]
        record = hostiles.byKey[key]
        if record then
            syncLocal(out, key, record,
                ageAuraSet(out, candidate, key, record))
        end
    end
end

local function periodicEventDamage(source, candidate, context, entry)
    local base = eventSource(source, entry)
    if not base then return 0 end
    if entry.kind == "periodicTick" then
        local eventState = projectedEventState(
            source, candidate, context, entry, entry.offset)
        if not eventState then return 0 end
        return periodicSegment(entry.aura, eventState, entry.tickSpan)
    end
    local baseState = State:Copy(base)
    local right = periodicDamage(
        base, candidate, context, entry, entry.right, baseState)
    local left = periodicDamage(
        base, candidate, context, entry, entry.left, baseState)
    return math.max(0, right - left)
end

local function applyPeriodic(out, source, candidate, context, entry)
    if entry.scheduleToken and not EventAuras:ScheduledCurrent(out,
        entry.targetKey, entry.targetGuid, entry.auraName,
        entry.scheduleToken) then return end
    local damage = periodicEventDamage(source, candidate, context, entry)
        * EventAuras:ScheduledScale(entry.scheduleToken)
    if entry.targetKey ~= nil then
        local record = localRecord(out, entry.targetKey, entry.targetGuid)
        if not record or not record.healthExact or (tonumber(record.health) or 0) <= 0 then
            return
        end
        local beforeHealth = tonumber(record.health)
        record.health = math.max(0, beforeHealth - damage)
        if EventAuras and EventAuras.ApplyPeriodicThreat then
            EventAuras:ApplyPeriodicThreat(
                record, entry.aura, beforeHealth - record.health)
        end
        if record.health <= 0 then
            record.dead, record.projectedDefeated = true, true
        end
        syncLocal(out, entry.targetKey, record, damage > 0)
        return
    end
    if hostilesOf(out) or not out.targetHealthExact or out.targetHealth <= 0 then
        return
    end
    out.targetHealth = math.max(0, out.targetHealth - damage)
    markTargetDeath(out)
end

local function advanceObservedTargetAuras(state, elapsed)
    local function age(auras)
        local changed, name, aura = false, nil, nil
        for name, aura in pairs(auras or {}) do
            if type(aura) == "table" and aura.remaining then
                aura.remaining = math.max(0, aura.remaining - elapsed)
                if aura.remaining <= 0 then auras[name] = nil end
                changed = elapsed > 0 or changed
            end
        end
        return changed
    end
    local hostiles = hostilesOf(state)
    if not hostiles then age(state.targetAuras) return end
    local i, count = nil, math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if record then
            syncLocal(state, key, record, age(record.targetAuras))
        end
    end
end

function O:Events(out, source, candidate, context)
    EventAuras:BeginScheduled(out)
    local events = Companion and Companion:Events(out, candidate) or {}
    local playerEvents = PlayerSwings and PlayerSwings:Events(out, candidate) or {}
    local periodic = periodicEvents(out, source, candidate, context)
    local i
    for i = 1, table.getn(playerEvents) do
        table.insert(events, playerEvents[i])
    end
    for i = 1, table.getn(periodic) do table.insert(events, periodic[i]) end
    return events
end

function O:Prepare(out, source, candidate, context)
    local events = self:Events(out, source, candidate, context)
    out.time = out.time + candidate.downtime
    advancePlayerCast(out, candidate.downtime)
    advanceFriendlies(out, candidate.downtime)
    advanceAuraDurations(out, candidate)
    advanceObservedTargetAuras(out, candidate.downtime)
    return events
end

function O:ApplyEvent(out, source, candidate, context, entry)
    if entry.kind == "petAutocast" or entry.kind == "petAutocastUnknown"
        or entry.kind == "petAutocastStart" or entry.kind == "petWhiteSwing"
        or entry.kind == "petSwingTimelineCap" then
        if Companion then
            Companion:Apply(out, source, candidate, context, entry)
        end
    elseif entry.kind == "playerMainSwing"
        or entry.kind == "playerSwingTimelineCap" then
        if PlayerSwings then PlayerSwings:Apply(out, entry) end
    elseif entry.kind == "periodicTick"
        or entry.kind == "periodicSegment" then
        applyPeriodic(out, source, candidate, context, entry)
    end
end

-- Root auras present at Prepare time have already been aged across the full
-- candidate window. Keep a separate clock only for auras created or replaced
-- by later ambient events, so those records can advance causally without
-- aging the pre-existing records twice.
function O:AuraSnapshot(state)
    return EventAuras:Snapshot(state)
end

function O:TrackEventAuras(state, before, tracked)
    EventAuras:Track(state, before, tracked)
end

function O:AdvanceEventAuras(state, tracked, elapsed)
    EventAuras:Advance(state, tracked, elapsed)
end

function O:Advance(out, source, candidate, context)
    local events = self:Prepare(out, source, candidate, context)
    table.sort(events, function(left, right)
        if left.offset ~= right.offset then return left.offset < right.offset end
        return left.priority < right.priority
    end)
    local i
    for i = 1, table.getn(events) do
        self:ApplyEvent(out, source, candidate, context, events[i])
    end
end
