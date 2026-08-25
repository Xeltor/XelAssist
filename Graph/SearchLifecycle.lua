-- Observation ownership for a frame-sliced graph search. Publication tickets
-- remain a UI concern; this module only binds search work to the combat
-- topology and records softer state drift without cancelling useful work.
XelAssist.Graph.SearchLifecycle = {}
local L = XelAssist.Graph.SearchLifecycle

local function revision()
    return XelAssist.Core and XelAssist.Core.CombatRevision
end

local function now()
    if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
    end
    return 0
end

function L:Observe(session)
    if type(session) ~= "table" then return nil end
    session.requestedAt = session.requestedAt or session.observedAt
    session.snapshotAt = now()
    session.observedAt = session.snapshotAt
    local owner = revision()
    session.combatRevisionToken = owner and owner.Snapshot
        and owner:Snapshot() or nil
    session.changedDomains, session.softChanged = nil, nil
    return session.snapshotAt
end

function L:HardChanged(session)
    local owner = revision()
    if not (owner and owner.HardChanged and session
        and session.combatRevisionToken) then return false end
    return owner:HardChanged(session.combatRevisionToken)
end

function L:AbortHardChange(session)
    if type(session) ~= "table" or session.status ~= "pending" then
        return false
    end
    session.status, session.phase, session.stale =
        "stale", "stale", true
    session.reason = "combat topology changed during evaluation"
    return true
end

function L:RecordSoftChanges(session)
    local owner = revision()
    local changed = owner and owner.ChangedDomains
        and session and session.combatRevisionToken
        and owner:ChangedDomains(session.combatRevisionToken) or {}
    session.changedDomains = changed
    session.softChanged = table.getn(changed) > 0 and true or false
    return session.softChanged, changed
end
