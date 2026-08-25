-- Target-local consequences of a real Auto Shot launch whose impact clock was
-- unavailable. The graph must not optimize against health/threat it cannot know.
XelAssist.Graph.AutoShotUncertainty = {}
local U = XelAssist.Graph.AutoShotUncertainty

local MAX_HOSTILES = 5

local function markers(observed)
    return observed and observed.unknownInFlight or {}
end

function U:Has(observed)
    return table.getn(markers(observed)) > 0
        or observed and observed.flightOverflowGlobal == true
end

local function hostileForGuid(state, guid)
    local hostiles = state and state.hostiles
    if not (hostiles and hostiles.byKey and hostiles.order) then return nil, nil end
    local direct = guid ~= nil and hostiles.byKey[guid] or nil
    if direct and (direct.guid == nil or direct.guid == guid) then return guid, direct end
    local count = math.min(table.getn(hostiles.order), MAX_HOSTILES)
    local i
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if record and record.guid == guid then return key, record end
    end
    return nil, nil
end

local function markRecord(record)
    record.healthExact = false
    record.autoShotImpactTimingUnknown = true
    record.threat = record.threat or {}
    record.threat.playerDeltaExact = false
    record.threat.autoShotImpactTimingUnknown = true
end

function U:Apply(out, observed)
    local changed, i, marker = {}, nil, nil
    if observed and observed.flightOverflowGlobal then
        if out.hostiles and out.hostiles.order and out.hostiles.byKey then
            local count = math.min(table.getn(out.hostiles.order), MAX_HOSTILES)
            for i = 1, count do
                local key = out.hostiles.order[i]
                local record = out.hostiles.byKey[key]
                if record and record.dead ~= true then
                    markRecord(record)
                    changed[key] = true
                end
            end
        else
            out.targetHealthExact = false
            out.autoShotImpactTimingUnknown = true
            out.targetPlayerThreatDeltaExact = false
        end
    end
    for i = 1, table.getn(markers(observed)) do
        marker = markers(observed)[i]
        local key, record = hostileForGuid(out, marker.targetGuid)
        if record and record.dead ~= true then
            markRecord(record)
            changed[key] = true
        elseif not out.hostiles and marker.targetGuid == out.targetGUID then
            out.targetHealthExact = false
            out.autoShotImpactTimingUnknown = true
            out.targetPlayerThreatDeltaExact = false
        end
    end
    local key
    for key in pairs(changed) do
        if XelAssist.Graph.State.RefreshHostileRecord then
            XelAssist.Graph.State:RefreshHostileRecord(out, key)
        end
    end
end

function U:Current(state, observed)
    if observed and observed.flightOverflowGlobal then return true end
    local i, marker
    for i = 1, table.getn(markers(observed)) do
        marker = markers(observed)[i]
        if marker.targetGuid ~= nil and marker.targetGuid == state.targetGUID then
            return true
        end
    end
    return false
end

function U:Carry(out, observed, elapsed)
    out.autoShot.unknownInFlight = {}
    local i, marker
    for i = 1, table.getn(markers(observed)) do
        marker = markers(observed)[i]
        table.insert(out.autoShot.unknownInFlight, {
            targetGuid = marker.targetGuid, spellId = marker.spellId,
            power = marker.power, delivery = marker.delivery,
            rawPower = marker.rawPower, timingUnknown = true,
            overflow = marker.overflow, unbounded = marker.unbounded })
    end
    out.autoShot.flightOverflowGlobal = observed
        and observed.flightOverflowGlobal and true or nil
    out.autoShot.launchTimingUnknown =
        (table.getn(out.autoShot.unknownInFlight) > 0
            or out.autoShot.flightOverflowGlobal) and true or nil
end
