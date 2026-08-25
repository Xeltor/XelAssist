-- Causal Auto Shot projection. Ammunition and hit outcome are fixed at launch;
-- damage resolves after projectile travel, on either side of the chosen action.
XelAssist.Graph.AutoShotEffects = {}
local A = XelAssist.Graph.AutoShotEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects

local function hasInFlight(observed)
    return observed and observed.inFlight
        and table.getn(observed.inFlight) > 0
end

local function hasCurrentInFlight(state, observed)
    local i, shot = nil, nil
    for i = 1, table.getn(observed and observed.inFlight or {}) do
        shot = observed.inFlight[i]
        if shot.targetGuid ~= nil and shot.targetGuid == state.targetGUID then
            return true
        end
    end
    return false
end

local function sameLiveTarget(state, observed)
    if not (state and observed) then return false end
    if state.targetHealthExact and (tonumber(state.targetHealth) or 0) <= 0 then
        return false
    end
    if observed.targetGuid == nil or state.targetGUID == nil
        or observed.targetGuid ~= state.targetGUID then return false end
    return true
end

local function launchEligible(state, observed)
    if not (sameLiveTarget(state, observed) and observed.active
        and state.hostile) then return false end
    if observed.active and observed.projectable == false then return false end
    if state.targetLineOfSight == false then return false end
    local distance = tonumber(state.targetDistance)
    if distance and (distance < 8 or distance > 35) then return false end
    return true
end

local function eligible(state, observed)
    return launchEligible(state, observed)
        or state and observed and hasInFlight(observed)
            and (not state.targetHealthExact or state.targetHealth > 0)
            and hasCurrentInFlight(state, observed)
end

local function actionFor(observed)
    return { name = "Auto Shot", spellId = observed.spellId or 75,
        rank = 1, actor = "player", facts = { kind = "damage",
            ranged = true, weaponRanged = true, ammunition = true } }
end

local function shotPower(observed, resistanceState)
    local power = math.max(0, tonumber(observed.shotDamage) or 0)
    local delivery = 1
    if power > 0 and XelAssist.Combat.Resistance then
        local estimate = XelAssist.Combat.Resistance:Estimate(
            actionFor(observed), "target", { school = 0 }, resistanceState)
        local decision
        decision, delivery = Effects:Decision(estimate, resistanceState, true)
        power = power * decision
    end
    return power, delivery
end

-- Resolve live launch outcome once, before later target modifiers or learned
-- resistance updates can rewrite an arrow that is already in the air.
function A:CaptureLaunch(targetGuid, spellId, rawPower)
    if tonumber(rawPower) == nil then return nil, nil end
    local at = GetTime and GetTime() or 0
    local state = self.liveState
    local age = at - (self.liveStateAt or at)
    if not state or state.targetGUID ~= targetGuid
        or age < 0 or age > 2 then
        return tonumber(rawPower), nil
    end
    return shotPower({ spellId = spellId, shotDamage = rawPower }, state)
end

function A:ObserveLiveState(state)
    if not state or (tonumber(state.time) or 0) ~= 0 then return end
    self.liveState, self.liveStateAt = state, GetTime and GetTime() or 0
end

local function flightTime(state, observed)
    local distance = math.max(5, tonumber(state.targetDistance) or 5)
    local speed = math.max(1, tonumber(observed.projectileSpeed) or 40)
    return distance / speed
end

local function syncAmmo(out)
    local auto = out.autoShot
    if out.inventory and out.inventory.ammo and auto and auto.ammoKnown then
        out.inventory.ammo.count = auto.ammoCount
    end
end

local function applyLaunch(out, launchState, observed, shot)
    local auto = out.autoShot
    if not auto or not auto.active then return false end
    if auto.ammoKnown and (tonumber(auto.ammoCount) or 0) <= 0 then
        auto.active = false
        return false
    end
    if out.targetHealthExact and (tonumber(out.targetHealth) or 0) <= 0 then
        auto.active = false
        return false
    end
    if auto.ammoKnown then auto.ammoCount = math.max(0, auto.ammoCount - 1) end
    shot.launched, shot.power, shot.delivery =
        true, shotPower(observed, launchState)
    auto.launches = (auto.launches or 0) + 1
    table.insert(auto.launchOffsets, shot.launchOffset)
    if auto.ammoKnown and auto.ammoCount <= 0 then auto.active = false end
    syncAmmo(out)
    return true
end

local function applyImpact(out, shot)
    if not shot.launched or shot.impacted then return false end
    shot.impacted = true
    if shot.targetGuid ~= out.targetGUID then return true end
    if not out.targetHealthExact or (tonumber(out.targetHealth) or 0) <= 0 then
        return true
    end
    out.targetHealth = math.max(0,
        out.targetHealth - math.max(0, tonumber(shot.power) or 0))
    out.autoShot.impacts = (out.autoShot.impacts or 0) + 1
    table.insert(out.autoShot.impactOffsets, shot.impactOffset)
    if out.targetHealth <= 0 then
        out.hostile, out.autoShot.active = false, false
    end
    return true
end

local function eventState(source, context, offset)
    local state = Effects:StateAtImpact(source, offset)
    if context and context.applicationOffset
        and context.ChangesHostileTarget and context.ProjectCurrentApplication
        and offset >= context.applicationOffset
        and context:ChangesHostileTarget() then
        state = State:Copy(state)
        context:ProjectCurrentApplication(state,
            offset - context.applicationOffset)
    end
    return state
end

local function buildEvents(source, projected)
    local events, shots, observed = {}, {}, source.autoShot
    local i, carried = nil, nil
    for i = 1, table.getn(observed.inFlight or {}) do
        carried = observed.inFlight[i]
        local shot = { launched = true, power = carried.power,
            delivery = carried.delivery, rawPower = carried.rawPower,
            spellId = carried.spellId or observed.spellId,
            targetGuid = carried.targetGuid,
            impactOffset = math.max(0, tonumber(carried.remaining) or 0) }
        table.insert(shots, shot)
        table.insert(events, { kind = "impact", offset = shot.impactOffset,
            shot = shot })
    end
    local flight = flightTime(source, observed)
    for i = 1, table.getn(projected.plannedLaunchOffsets or {}) do
        local launch = projected.plannedLaunchOffsets[i]
        local shot = { launchOffset = launch, impactOffset = launch + flight,
            spellId = observed.spellId, targetGuid = observed.targetGuid }
        table.insert(shots, shot)
        table.insert(events, { kind = "launch", offset = launch, shot = shot })
        table.insert(events, { kind = "impact", offset = shot.impactOffset,
            shot = shot })
    end
    table.sort(events, function(left, right)
        if left.offset ~= right.offset then return left.offset < right.offset end
        return left.kind == "launch" and right.kind ~= "launch"
    end)
    return events, shots
end

local function processEvent(out, source, context, observed, entry)
    if entry.kind == "launch" then
        return applyLaunch(out, eventState(source, context, entry.offset),
            observed, entry.shot)
    end
    return applyImpact(out, entry.shot)
end

local function storeInFlight(out, shots, windowEnd)
    out.autoShot.inFlight = {}
    if out.targetHealthExact and out.targetHealth <= 0 then return end
    local i, shot
    for i = 1, table.getn(shots or {}) do
        shot = shots[i]
        if shot.launched and not shot.impacted and shot.targetGuid == out.targetGUID then
            table.insert(out.autoShot.inFlight, { power = shot.power,
                delivery = shot.delivery, rawPower = shot.rawPower,
                spellId = shot.spellId, targetGuid = shot.targetGuid,
                remaining = math.max(0, shot.impactOffset - windowEnd) })
        end
    end
end

local function inactiveProjection(observed, candidate)
    local wait = math.max(0, tonumber(candidate.wait) or 0)
    local occupancy = math.max(0, tonumber(candidate.occupancy) or 0)
    local cast = math.min(occupancy, math.max(0, tonumber(candidate.cast) or 0))
    local out, key, value = {}, nil, nil
    for key, value in pairs(observed) do out[key] = value end
    out.launches, out.launchOffsets = 0, {}
    out.impactOffset, out.windowEnd = wait + cast, wait + occupancy
    return out
end

function A:Eligible(state, observed)
    return eligible(state, observed)
end

function A:Project(state, candidate)
    self:ObserveLiveState(state)
    local observed = state and state.autoShot
    if not eligible(state, observed) then return nil end
    if launchEligible(state, observed) and XelAssist.Combat.AutoShot then
        return XelAssist.Combat.AutoShot:Project(observed, candidate, state)
    end
    return inactiveProjection(observed, candidate)
end

local function prepareProjection(state, candidate)
    local projected = A:Project(state, candidate)
    if not projected then return nil end
    projected.windowEnd = projected.windowEnd or candidate.downtime
        or (tonumber(candidate.wait) or 0) + (tonumber(candidate.occupancy) or 0)
    projected.plannedLaunches = projected.launches
    projected.plannedLaunchOffsets = projected.launchOffsets
    projected.launches, projected.launchOffsets = 0, {}
    projected.impacts, projected.impactOffsets = 0, {}
    projected.active = state.autoShot.active and true or false
    projected.ammoCount = state.autoShot.ammoCount
    projected.inFlight = {}
    return projected
end

-- Expose individual projectile events to the graph timeline without exposing
-- the mechanics that fix ammunition and damage at launch.
function A:CreateTimeline(out, source, candidate, context)
    local projected = prepareProjection(source, candidate)
    if not projected then return nil end
    out.autoShot = projected
    syncAmmo(out)
    local events, shots = buildEvents(source, projected)
    local i
    for i = 1, table.getn(events) do events[i].owner = "autoShot" end
    return { events = events, shots = shots, observed = source.autoShot,
        source = source, context = context, windowEnd = projected.windowEnd,
        actionOffset = projected.impactOffset }
end

function A:ApplyTimelineEvent(out, timeline, entry)
    if not (timeline and entry) then return false end
    return processEvent(out, timeline.source, timeline.context,
        timeline.observed, entry)
end

function A:FinishTimeline(out, timeline)
    if not timeline then return end
    storeInFlight(out, timeline.shots, timeline.windowEnd)
end

function A:HealthBeforeImpact(state, candidate)
    if not state.targetHealthExact then return nil, 0, 0 end
    local projected = prepareProjection(state, candidate)
    if not projected then return state.targetHealth, 0, 0 end
    local probe = State:Copy(state)
    probe.autoShot = projected
    local events = buildEvents(state, projected)
    local i, entry = 1, nil
    while events[i] and events[i].offset < projected.impactOffset do
        entry = events[i]
        processEvent(probe, state, candidate, state.autoShot, entry)
        i = i + 1
    end
    return probe.targetHealth, projected.impacts, projected.launches
end

function A:Begin(out, source, candidate, context)
    local timeline = A:CreateTimeline(out, source, candidate, context)
    if not timeline then return end
    local pending, i, entry = {}, 1, nil
    while timeline.events[i] do
        entry = timeline.events[i]
        if entry.offset < timeline.actionOffset then
            A:ApplyTimelineEvent(out, timeline, entry)
        else table.insert(pending, entry) end
        i = i + 1
    end
    if out.targetHealthExact and out.targetHealth <= 0
        and candidate.targetRelation == "hostile" then
        out.autoShotActionPrevented = true
    end
    timeline.events = pending
    out.autoShotPending = timeline
end

function A:Complete(out)
    local pending = out.autoShotPending
    out.autoShotPending = nil
    if not pending then return end
    if not out.autoShotActionPrevented then
        local i, entry = 1, nil
        while pending.events[i] do
            entry = pending.events[i]
            if entry.offset <= pending.windowEnd then
                A:ApplyTimelineEvent(out, pending, entry)
            end
            i = i + 1
        end
    end
    A:FinishTimeline(out, pending)
end
