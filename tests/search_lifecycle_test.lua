XelAssist = { Core = {}, Graph = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local clock = 12.5
function GetTime() return clock end

dofile("Core/CombatRevision.lua")
dofile("Graph/SearchLifecycle.lua")
local Revision = XelAssist.Core.CombatRevision
local Lifecycle = XelAssist.Graph.SearchLifecycle

Revision:Reset()
local session = { status = "pending", phase = "snapshot", observedAt = 10 }
assert(Lifecycle:Observe(session) == 12.5
    and session.requestedAt == 10 and session.snapshotAt == 12.5
    and session.observedAt == 12.5,
    "the graph freshness clock must begin at its actual state observation")
assert(not Lifecycle:HardChanged(session),
    "an unchanged topology must retain an active search")

Revision:Touch("health", "ordinary damage")
Revision:Touch("resource", "mana changed")
assert(not Lifecycle:HardChanged(session),
    "soft combat traffic must never cancel sliced work")
local soft, domains = Lifecycle:RecordSoftChanges(session)
assert(soft and table.concat(domains, ",") == "health,resource",
    "completed work must retain deterministic soft-drift provenance")

Revision:Hard("target identity changed")
assert(Lifecycle:HardChanged(session)
    and Lifecycle:AbortHardChange(session)
    and session.status == "stale" and session.phase == "stale"
    and session.stale and session.reason,
    "a hard topology change must end the old search without a plan")
assert(not Lifecycle:AbortHardChange(session),
    "a terminal stale search must not be aborted twice")

clock = 15
local nextSession = { status = "pending", observedAt = 14 }
Lifecycle:Observe(nextSession)
assert(not Lifecycle:HardChanged(nextSession)
    and not Lifecycle:RecordSoftChanges(nextSession),
    "a replacement observation must own the current combat revision")

print("search lifecycle tests passed")
