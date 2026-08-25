-- Server-faithful ranged timer projection for the observed Auto Shot state.
local A = XelAssist.Combat.AutoShot
local RESUME_FLOOR = 0.5

local function arrayCount(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function runFree(nextIn, span, speed, remainingAmmo, base, launches,
    includeEnd)
    local count, elapsed = 0, 0
    span = math.max(0, tonumber(span) or 0)
    nextIn = math.max(0.05, tonumber(nextIn) or speed)
    while (span > nextIn or includeEnd and span >= nextIn)
        and (remainingAmmo == nil or count < remainingAmmo) do
        span, elapsed = span - nextIn, elapsed + nextIn
        count = count + 1
        table.insert(launches, base + elapsed)
        nextIn = speed
    end
    if remainingAmmo == nil or count < remainingAmmo then
        nextIn = math.max(0.05, nextIn - span)
    end
    return nextIn, count
end

local function addPoint(points, value, total)
    value = math.max(0, math.min(total, tonumber(value) or 0))
    local i
    for i = 1, arrayCount(points) do
        if math.abs(points[i] - value) < 0.0001 then return end
    end
    table.insert(points, value)
end

local function segmentBlocked(midpoint, source, currentCastEnd,
    actionCastStart, actionCastEnd)
    if source and source.moving then return true end
    if midpoint < currentCastEnd then return true end
    return midpoint >= actionCastStart and midpoint < actionCastEnd
end

local function projectedState(snapshot)
    return { supported = snapshot and snapshot.supported,
        spellId = snapshot and snapshot.spellId,
        active = snapshot and snapshot.active and true or false,
        activeSource = snapshot and snapshot.activeSource,
        confidence = snapshot and snapshot.confidence,
        stateUncertain = snapshot and snapshot.stateUncertain,
        knownInactive = snapshot and snapshot.knownInactive,
        projectable = snapshot and snapshot.projectable,
        targetGuid = snapshot and snapshot.targetGuid,
        currentTargetGuid = snapshot and snapshot.currentTargetGuid,
        eligibilityReason = snapshot and snapshot.eligibilityReason,
        blocked = snapshot and snapshot.blocked,
        nextLaunchIn = snapshot and snapshot.nextLaunchIn,
        rangedSpeed = snapshot and snapshot.rangedSpeed,
        rangedSpeedSource = snapshot and snapshot.rangedSpeedSource,
        projectileSpeed = snapshot and snapshot.projectileSpeed,
        ammoId = snapshot and snapshot.ammoId,
        ammoKnown = snapshot and snapshot.ammoKnown,
        ammoCount = snapshot and snapshot.ammoCount,
        shotDamage = snapshot and snapshot.shotDamage,
        inFlight = snapshot and snapshot.inFlight,
        launches = 0, launchOffsets = {} }
end

-- Blocked time keeps decrementing the server timer; resuming applies the
-- vMaNGOS 500 ms floor instead of freezing the swing phase.
function A:Project(snapshot, candidate, source)
    local out = projectedState(snapshot)
    if not (snapshot and snapshot.active and snapshot.projectable ~= false
        and candidate) then return out end
    local speed = math.max(0.1, tonumber(snapshot.rangedSpeed) or 2.8)
    local remainingAmmo = snapshot.ammoKnown
        and math.max(0, tonumber(snapshot.ammoCount) or 0) or nil
    if remainingAmmo == 0 then out.active = false; return out end
    local wait = math.max(0, tonumber(candidate.wait) or 0)
    local occupancy = math.max(0, tonumber(candidate.occupancy) or 0)
    local actionCast = math.min(occupancy,
        math.max(0, tonumber(candidate.cast) or 0))
    local action = candidate.action
    local facts = action and action.facts or {}
    local actor = action and action.actor or candidate.actor
    local playerCast = actor == "pet" and 0 or actionCast
    local playerGeneric = actor ~= "pet" and not facts.autoRepeat
    local total = wait + occupancy
    local currentCastEnd = source and source.playerCasting
        and math.min(total, math.max(0, tonumber(source.castRemaining) or 0)) or 0
    local points = { 0, total }
    addPoint(points, currentCastEnd, total)
    addPoint(points, wait, total)
    addPoint(points, wait + playerCast, total)
    table.sort(points)
    local nextIn = math.max(0, tonumber(snapshot.nextLaunchIn) or speed)
    local wasBlocked = snapshot.blocked and true or false
    local launches, floorApplied, i = 0, false, nil
    for i = 1, arrayCount(points) - 1 do
        local left, right = points[i], points[i + 1]
        local span = right - left
        if span > 0 then
            if playerGeneric and not floorApplied and left >= wait then
                wasBlocked, floorApplied = true, true
            end
            local blocked = segmentBlocked((left + right) / 2, source,
                currentCastEnd, wait, wait + playerCast)
            if blocked then
                nextIn, wasBlocked = math.max(0, nextIn - span), true
            else
                if wasBlocked then
                    nextIn, wasBlocked = math.max(RESUME_FLOOR, nextIn), false
                end
                local count
                nextIn, count = runFree(nextIn, span, speed,
                    remainingAmmo, left, out.launchOffsets,
                    not (playerGeneric and not floorApplied and right == wait))
                launches = launches + count
                if remainingAmmo then remainingAmmo = remainingAmmo - count end
            end
        end
    end
    if playerGeneric and not floorApplied then
        wasBlocked, floorApplied = true, true
    end
    local currentContinues = source and source.playerCasting
        and (tonumber(source.castRemaining) or 0) > total
    if wasBlocked and not (source and source.moving) and not currentContinues then
        nextIn, wasBlocked = math.max(RESUME_FLOOR, nextIn), false
    end
    out.nextLaunchIn, out.launches, out.blocked = nextIn, launches, wasBlocked
    out.windowEnd, out.impactOffset = total, wait + actionCast
    out.launchesBeforeImpact, out.launchesAfterImpact = 0, 0
    for i = 1, arrayCount(out.launchOffsets) do
        if out.launchOffsets[i] < out.impactOffset then
            out.launchesBeforeImpact = out.launchesBeforeImpact + 1
        else out.launchesAfterImpact = out.launchesAfterImpact + 1 end
    end
    if snapshot.ammoKnown then
        out.ammoCount = math.max(0, (snapshot.ammoCount or 0) - launches)
        if out.ammoCount == 0 then out.active = false end
    end
    return out
end
