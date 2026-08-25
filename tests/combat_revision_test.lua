XelAssist = { Core = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Core/CombatRevision.lua")
local Revision = XelAssist.Core.CombatRevision

local function joined(values)
    return table.concat(values, ",")
end

Revision:Reset()
local initial = Revision:Snapshot()
assert(initial.hardEpoch == 0
    and initial.softCounters.health == 0
    and initial.softCounters.inventory == 0,
    "reset must create a complete zero-valued revision token")
assert(not Revision:HardChanged(initial)
    and not Revision:AnyChanged(initial)
    and table.getn(Revision:ChangedDomains(initial)) == 0,
    "a fresh token must match the current combat revision")

local healthCount, touchError = Revision:Touch("health", "target damaged")
assert(healthCount == 1 and touchError == nil,
    "a supported soft domain must advance independently")
assert(not Revision:HardChanged(initial),
    "a soft touch must never imply hard cancellation")
assert(Revision:AnyChanged(initial)
    and joined(Revision:ChangedDomains(initial)) == "health",
    "soft comparison must identify only the touched domain")
assert(Revision.lastSoftReasons.health == "target damaged",
    "soft diagnostics must retain the latest bounded-domain reason")

local afterHealth = Revision:Snapshot()
Revision:Touch("cast", "player cast started")
Revision:Touch("resource", "energy tick")
assert(joined(Revision:ChangedDomains(afterHealth)) == "resource,cast",
    "changed domains must use stable canonical ordering")
assert(not Revision:HardChanged(afterHealth),
    "multiple soft domains must still leave the hard epoch untouched")

local beforeUnknown = Revision:Snapshot()
local unknownCount, unknownError = Revision:Touch(
    "arbitrary-domain", "must not allocate")
assert(unknownCount == nil and unknownError == "unknown combat revision domain"
    and not Revision:AnyChanged(beforeUnknown),
    "unknown domains must fail without growing or mutating revision state")

local beforeHard = Revision:Snapshot()
local hardEpoch = Revision:Hard("selected target changed")
assert(hardEpoch == 1 and Revision:HardChanged(beforeHard)
    and Revision:AnyChanged(beforeHard),
    "a hard boundary must invalidate an older token")
assert(table.getn(Revision:ChangedDomains(beforeHard)) == 0,
    "hard and soft change reporting must remain independent")
assert(Revision.lastHardReason == "selected target changed",
    "hard diagnostics must retain the latest reason")

local isolated = Revision:Snapshot()
isolated.softCounters.health = isolated.softCounters.health + 100
assert(Revision:Snapshot().softCounters.health ~= isolated.softCounters.health,
    "snapshot tokens must not expose mutable owner counters")

Revision:Reset()
Revision.hardEpoch = Revision.MAX_COUNTER
local beforeHardWrap = Revision:Snapshot()
assert(Revision:Hard("counter wrap") == 0
    and Revision:HardChanged(beforeHardWrap),
    "the hard counter must wrap within its fixed numeric bound")

Revision.softCounters.aura = Revision.MAX_COUNTER
local beforeSoftWrap = Revision:Snapshot()
local wrapped = Revision:Touch("aura", "counter wrap")
assert(wrapped == 0 and Revision:AnyChanged(beforeSoftWrap)
    and joined(Revision:ChangedDomains(beforeSoftWrap)) == "aura",
    "soft counters must wrap without losing immediate change detection")

assert(Revision:HardChanged(nil) and Revision:AnyChanged(nil)
    and table.getn(Revision:ChangedDomains(nil))
        == table.getn(Revision.DOMAINS),
    "missing or malformed tokens must compare fail closed")
local malformed = Revision:Snapshot()
malformed.softCounters.pet = nil
assert(not Revision:HardChanged(malformed) and Revision:AnyChanged(malformed)
    and table.getn(Revision:ChangedDomains(malformed))
        == table.getn(Revision.DOMAINS),
    "incomplete soft counters must fail closed without inventing a hard change")

print("combat revision tests passed")
