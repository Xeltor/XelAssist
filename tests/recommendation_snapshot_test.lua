XelAssist = { Core = {} }

local now = 10
GetTime = function() return now end
dofile("Core/RecommendationSnapshot.lua")
local Snapshot = XelAssist.Core.RecommendationSnapshot

local first = { action = { name = "Sinister Strike" } }
Snapshot:Publish(first, "smart")
local acquired, reason = Snapshot:Acquire("smart")
assert(acquired == first and reason == nil,
    "a fresh complete graph publication must be executable")

acquired, reason = Snapshot:Acquire("smart")
assert(acquired == nil and reason == "waiting for the next graph decision",
    "one publication must never be replayed by macro spam")

local second = { action = { name = "Eviscerate" } }
now = now + 0.2
Snapshot:Publish(second, "smart")
acquired = Snapshot:Acquire("smart")
assert(acquired == second,
    "the next independently published decision must become executable")

now = now + 0.2
Snapshot:Publish(first, "single")
acquired, reason = Snapshot:Acquire("smart")
assert(acquired == nil and reason == "recommendation mode changed",
    "a plan evaluated for another mode must never execute")

now = now + 0.2
Snapshot:Publish(first, "smart")
now = now + Snapshot.MAX_AGE + 0.01
acquired, reason = Snapshot:Acquire("smart")
assert(acquired == nil and reason == "recommendation expired",
    "a stale publication must fail closed")

now = now + 1
local delayed = { action = { name = "Shadow Bolt" },
    observedAt = now - Snapshot.MAX_AGE - 0.01 }
Snapshot:Publish(delayed, "smart")
acquired, reason = Snapshot:Acquire("smart")
assert(acquired == nil and reason == "recommendation expired",
    "search time must age from live observation rather than publication")

now = now + 0.2
Snapshot:Publish(first, "smart")
Snapshot:Invalidate("target changed")
acquired, reason = Snapshot:Acquire("smart")
assert(acquired == nil and reason == "target changed",
    "target invalidation must retire the published action immediately")

print("ok: fresh graph publications are atomic, one-shot and fail closed")
