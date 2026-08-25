-- Bounded live projectile ledger. Exact launches keep their measured clocks;
-- launches whose center-distance clock is missing remain explicit uncertainty.
XelAssist.Combat.AutoShotFlights = {}
local F = XelAssist.Combat.AutoShotFlights

local MAX_IN_FLIGHT = 8

local function count(values)
    local total = 0
    while values and values[total + 1] ~= nil do total = total + 1 end
    return total
end

local function recordOverflow(owner, targetGuid)
    if owner.flightOverflowGlobal then return end
    owner.flightOverflowTargets = owner.flightOverflowTargets or {}
    local i
    for i = 1, count(owner.flightOverflowTargets) do
        if owner.flightOverflowTargets[i] == targetGuid then return end
    end
    if count(owner.flightOverflowTargets) >= MAX_IN_FLIGHT then
        owner.flightOverflowTargets, owner.flightOverflowGlobal = {}, true
        return
    end
    table.insert(owner.flightOverflowTargets, targetGuid)
end

local function boundedInsert(owner, values, value)
    while count(values) >= MAX_IN_FLIGHT do
        local evicted = table.remove(values, 1)
        recordOverflow(owner, evicted and evicted.targetGuid)
    end
    table.insert(values, value)
end

function F:Prune(owner, at)
    at = tonumber(at) or 0
    local known, unknown, i, shot = {}, {}, nil, nil
    for i = 1, count(owner.launchLedger) do
        shot = owner.launchLedger[i]
        if tonumber(shot.launchedAt) and tonumber(shot.impactAt)
            and shot.launchedAt <= at and shot.impactAt > at then
            table.insert(known, shot)
        end
    end
    for i = 1, count(owner.unknownLaunchLedger) do
        table.insert(unknown, owner.unknownLaunchLedger[i])
    end
    owner.launchLedger, owner.unknownLaunchLedger = known, unknown
    owner.launchTimingUnknown = (count(unknown) > 0
        or count(owner.flightOverflowTargets) > 0
        or owner.flightOverflowGlobal) and true or nil
    return known, unknown
end

local function duplicate(values, targetGuid, spellId, launchedAt)
    local prior = values[count(values)]
    if prior and prior.launchedAt == launchedAt
        and prior.targetGuid == targetGuid and prior.spellId == spellId then
        return prior
    end
    return nil
end

function F:Record(owner, targetGuid, spellId, launchedAt, flight, outcome)
    local known, unknown = self:Prune(owner, launchedAt)
    local prior = duplicate(known, targetGuid, spellId, launchedAt)
        or duplicate(unknown, targetGuid, spellId, launchedAt)
    if prior then return prior end
    local shot = { targetGuid = targetGuid, spellId = spellId,
        launchedAt = launchedAt, power = outcome.power,
        delivery = outcome.delivery, rawPower = outcome.rawPower }
    if tonumber(flight) then
        shot.impactAt = launchedAt + flight
        boundedInsert(owner, known, shot)
    else
        shot.timingUnknown = true
        boundedInsert(owner, unknown, shot)
        owner.launchTimingUnknown = true
    end
    return shot
end

function F:Known(owner, at)
    at = tonumber(at) or 0
    local known = self:Prune(owner, at)
    local out, i, shot = {}, nil, nil
    for i = 1, count(known) do
        shot = known[i]
        table.insert(out, { targetGuid = shot.targetGuid,
            spellId = shot.spellId, power = shot.power,
            delivery = shot.delivery, rawPower = shot.rawPower,
            remaining = math.max(0, shot.impactAt - at) })
    end
    return out
end

function F:Unknown(owner, at)
    at = tonumber(at) or 0
    local _, unknown = self:Prune(owner, at)
    local out, i, shot = {}, nil, nil
    for i = 1, count(unknown) do
        shot = unknown[i]
        table.insert(out, { targetGuid = shot.targetGuid,
            spellId = shot.spellId, power = shot.power,
            delivery = shot.delivery, rawPower = shot.rawPower,
            timingUnknown = true })
    end
    for i = 1, count(owner.flightOverflowTargets) do
        table.insert(out, { targetGuid = owner.flightOverflowTargets[i],
            timingUnknown = true, overflow = true, unbounded = true })
    end
    return out
end

function F:Reset(owner, preserve)
    if not preserve then
        owner.launchLedger, owner.unknownLaunchLedger = {}, {}
        owner.flightOverflowTargets, owner.flightOverflowGlobal = {}, nil
        owner.launchTimingUnknown = nil
    else self:Prune(owner, GetTime and GetTime() or 0) end
end
