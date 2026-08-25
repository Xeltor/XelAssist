XelAssist = { Core = {} }

local clock = 10
GetTime = function() return clock end

dofile("Core/PlayerNormalQueue.lua")
local Q = XelAssist.Core.PlayerNormalQueue
local targetGuid, otherGuid = {}, {}
local normal = { name = "Serpent Sting", spellId = 1978,
    facts = { kind = "dot" } }

local record, reason = Q:Arm(normal, { gcd = 1.5 }, normal.name,
    targetGuid, 4, 0)
assert(record and not reason and record.phase == "arming"
    and record.targetGuid == targetGuid,
    "arming must preserve the exact action and opaque target before dispatch")
assert(Q:CastEvent(1, 1978, 0, targetGuid) == record
    and record.phase == "attempted" and Q:Current() == record,
    "client cast success must remain latched until server evidence")
Q:Finalize(record, true)
assert(not Q:ServerAccepted(9999, targetGuid)
    and not Q:ServerAccepted(1978, otherGuid) and Q:Current() == record,
    "mismatched spell or target must not release an attempted owner")
assert(Q:ServerAccepted(1978, targetGuid) and not Q:Current(),
    "matching server acceptance must release an attempted owner")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:CastEvent(1, 1978, 0, targetGuid, "101"); Q:Finalize(record, true)
assert(not Q:ServerAccepted(1978, targetGuid) and Q:Current() == record,
    "ID-bound attempts must ignore identityless compatibility terminals")
assert(not Q:ServerResult(1, 1978, targetGuid, 0, "0")
    and Q:Current() == record,
    "an ambiguous Nampower server result must retain the bounded latch")
assert(not Q:ServerResult(1, 1978, targetGuid, 0, "100")
    and Q:Current() == record,
    "a stale server result must not resolve a newer same-spell attempt")
assert(Q:ServerResult(1, 1978, targetGuid, 0, "101")
    and not Q:Current(),
    "the exact Nampower attempt result must release its owner")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:CastEvent(1, 1978, 0, targetGuid, "111"); Q:Finalize(record, true)
assert(not Q:ServerFailure(1978, nil, "0")
    and record.phase == "attempted",
    "an ambiguous failure must not claim an exact current attempt")
assert(Q:ServerResult(0, 1978, targetGuid, 77, "111") == record
    and Q:ServerFailure(1978, nil, "111") == record,
    "the legacy failure after an exact failed result must remain attributable")
Q:Reset()

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:CastEvent(1, 1978, 0, targetGuid, "201"); Q:Finalize(record, true)
assert(Q:ServerResult(0, 1978, targetGuid, 77, "201") == record
    and record.phase == "failure-pending",
    "an ID-bound failed result must stay provisional for synchronous retry")
Q:QueueEvent(2, 1978)
assert(record.phase == "queued" and record.attemptId == nil,
    "retry queuing must retire the failed attempt generation")
Q:CastEvent(1, 1978, 0, targetGuid, "202"); Q:QueueEvent(3, 1978)
assert(not Q:ServerResult(1, 1978, targetGuid, 0, "201")
    and Q:Current() == record,
    "a delayed prior-generation success must not release the retried cast")
assert(Q:ServerResult(1, 1978, targetGuid, 0, "202")
    and not Q:Current(),
    "the retry's exact result must release only that generation")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 4, 0)
assert(Q:QueueEvent(2, 1978) == record and record.phase == "queued",
    "a synchronous normal-queued event must promote the provisional owner")
Q:Finalize(record, true)
assert(Q:Current() == record
    and Q:Blocker(normal, { gcd = 1.5 }) == "normal player spell already queued",
    "finalization must retain a proven occupied normal queue")
Q:QueueEvent(0, 1978)
Q:QueueEvent(1, 1978)
Q:QueueEvent(4, 1978)
Q:QueueEvent(5, 1978)
assert(Q:Current() == record,
    "on-swing and non-GCD queue events must not mutate normal ownership")
assert(not Q:QueueEvent(3, 9999) and Q:Current() == record,
    "a different normal spell pop must not mutate the owner")
assert(not Q:ServerAccepted(1978, targetGuid) and record.phase == "queued",
    "same-spell server evidence from an active cast must not unlock a queued follow-up")
assert(Q:CastEvent(1, 1978, 0, targetGuid) == record
    and record.phase == "attempted", "the queued client attempt must be observed")
assert(Q:QueueEvent(3, 1978) and record.phase == "popped"
    and Q:Current() == record,
    "an exact queue pop must retain ownership until the server responds")
assert(Q:ServerAccepted(1978, targetGuid) and not Q:Current(),
    "matching server acceptance after a pop must reopen the normal slot")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:QueueEvent(2, 1978); Q:Finalize(record, true)
assert(Q:QueueEvent(3, 1978) == record and record.phase == "dropped"
    and not Q:Current(),
    "a queued pop without a preceding client attempt must be a terminal drop")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
assert(Q:QueueEvent(3, 1978) and record.phase == "pre-dispatch-pop",
    "a same-spell pop during dispatch must remain provisional")
Q:Finalize(record, true)
assert(Q:Current() == record and record.phase == "unknown",
    "a reentrant old pop plus lost new events must retain bounded ownership")
Q:Reset()

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
assert(Q:QueueEvent(3, 1978) and record.phase == "pre-dispatch-pop",
    "a same-spell pop during dispatch must remain provisional")
assert(Q:CastEvent(1, 1978, 0, targetGuid) == record
    and record.phase == "attempted",
    "a later same-dispatch attempt must supersede the provisional pop")
Q:Finalize(record, true)
assert(Q:ServerAccepted(1978, targetGuid) and not Q:Current(),
    "the superseding attempt must still wait for matching server evidence")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:CastEvent(1, 1978, 0, targetGuid); Q:Finalize(record, true)
assert(Q:ServerFailure(1978, nil) == record
    and record.phase == "failure-pending",
    "an exact server failure must remain provisional during Nampower's callback")
local failedSerial = record.failedSerial
assert(Q:QueueEvent(2, 1978) == record and record.phase == "queued"
    and record.retrySerial > failedSerial,
    "a later synchronous retry event must revive the same owned record")
Q:CastEvent(1, 1978, 0, targetGuid); Q:QueueEvent(3, 1978)
assert(Q:ServerFailure(1978, targetGuid) == record and Q:Current() == record,
    "a failed retry must remain owned until its callback can finish")
assert(not Q:Blocker(normal, { gcd = 1.5 }) and not Q:Current(),
    "the next submission must resolve a failure that received no retry event")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
assert(Q:CastEvent(0, 1978, 0, targetGuid) == record
    and record.phase == "client-failed", "client failure must be provisional")
local accepted, failureReason = Q:Finalize(record, true)
assert(not accepted and failureReason == "client cast failed",
    "client failure finalization must reject downstream submission effects")
assert(not Q:Current(), "client failure must release after dispatch returns")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
assert(Q:ServerFailure(1978, nil, "211") == record
    and record.phase == "pre-cast-failure",
    "an exact failure raised inside the cast call must be retained")
local earlyFailedSerial = record.failedSerial
assert(Q:QueueEvent(2, 1978) == record and record.phase == "queued"
    and record.retrySerial > earlyFailedSerial,
    "a synchronous code-2 retry must supersede the early failed generation")
assert(Q:CastEvent(0, 1978, 0, targetGuid, "211") == record
    and record.phase == "queued" and record.attemptId == nil,
    "the outer failed cast event must not discard its already queued retry")
accepted = Q:Finalize(record, true)
assert(accepted and Q:Current() == record,
    "a locally retried cast must remain accepted and guarded after dispatch")
Q:Reset()

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:ServerFailure(1978, nil, "212")
Q:CastEvent(0, 1978, 0, targetGuid, "212")
accepted, failureReason = Q:Finalize(record, true)
assert(not accepted and failureReason == "client cast failed" and not Q:Current(),
    "an early local failure without a code-2 retry must remain terminal")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:QueueEvent(2, 1978); Q:Finalize(record, true)
local deferredRecord, deferred = Q:ServerFailure(
    1978, nil, "prior-attempt")
assert(not deferredRecord and deferred == "deferred"
    and record.phase == "queued" and Q:Current() == record,
    "a targetless prior-generation failure must not claim a queued follow-up")
Q:CastEvent(1, 1978, 0, targetGuid, "current-attempt")
assert(record.phase == "attempted" and record.failureCandidateId == nil,
    "the current generation's exact cast must retire an older failure candidate")
Q:Reset()

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:QueueEvent(2, 1978); Q:Finalize(record, true)
deferredRecord, deferred = Q:ServerFailure(1978, nil, "queued-attempt")
assert(not deferredRecord and deferred == "deferred"
    and record.phase == "queued",
    "an owned queued cast failure must wait for target-bearing cast evidence")
Q:QueueEvent(2, 1978)
local preserved, preserveReason = Q:CastEvent(
    0, 1978, 0, targetGuid, "queued-attempt")
assert(preserved == record and preserveReason == "retry-preserved"
    and record.phase == "queued" and record.ignoreNextPop,
    "matching CAST0 must confirm the queued generation and its later retry")
local priorPop, popReason = Q:QueueEvent(3, 1978)
assert(priorPop == record and popReason == "prior-generation-pop"
    and record.phase == "queued" and Q:Current() == record,
    "the failed generation's pop must not discard its confirmed retry")
Q:Reset()

record = Q:Arm(normal, {}, normal.name, targetGuid, 0, 0)
assert(Q:CastEvent(1, 1978, 2, targetGuid) == record
    and record.phase == "non-normal", "cast type must correct uncertain metadata")
accepted = Q:Finalize(record, true)
assert(accepted, "a corrected independent queue class is still a valid dispatch")
assert(not Q:Current(), "an observed on-swing cast must not occupy the normal slot")

record = Q:Arm(normal, {}, normal.name, targetGuid, 0, 0)
assert(Q:QueueEvent(4, 1978) == record and record.phase == "non-normal",
    "queue class must correct uncertain metadata")
Q:Finalize(record, true)
assert(not Q:Current(), "an observed non-GCD queue must not occupy the normal slot")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:Finalize(record, true)
assert(Q:Current() == record and record.phase == "unknown",
    "missing synchronous evidence must stay conservatively latched")
assert(Q:QueueEvent(2, 1978) == record and record.phase == "queued",
    "late exact queue evidence must refine an unknown owner")
Q:CastEvent(0, 1978, 0, targetGuid)
assert(not Q:Blocker(normal, { gcd = 1.5 }) and not Q:Current(),
    "a client failure with a lost pop must release on the next submission")

record = Q:Arm(normal, { gcd = 1.5 }, normal.name, targetGuid, 0, 0)
Q:Finalize(record, true)
clock = 16
assert(not Q:Current(), "unknown event loss must release at its bounded timeout")

clock = 20
local revive = { name = "Revive Pet", spellId = 982,
    facts = { kind = "summon", petLifecycle = "revive" } }
record = Q:Arm(revive, { gcd = 1.5 }, revive.name, nil, 0, 10)
Q:CastEvent(1, 982, 0, "0x0000000000000000", "301")
Q:QueueEvent(3, 982); Q:Finalize(record, true)
clock = 26
assert(Q:Current() == record,
    "attempt and pop evidence must not shorten a long cast's arm deadline")
clock = 35
assert(not Q:Current(),
    "a long cast with uncorrelated server evidence must eventually time out")

clock = 50
record = Q:Arm(revive, { gcd = 1.5 }, revive.name, nil, 0, 10)
Q:CastEvent(1, 982, 0, "0x0000000000000000", "401")
clock = 51
Q:ServerResult(0, 982, "0x0000000000000000", 65, "401")
Q:QueueEvent(2, 982)
Q:CastEvent(1, 982, 0, "0x0000000000000000", "402")
Q:ServerResult(1, 982, "0x0000000000000000", 0, "0")
clock = 57
assert(Q:Current() == record,
    "a long-cast retry with ambiguous result identity must retain a full hold")
clock = 66
assert(not Q:Current(),
    "a long-cast retry must release after its renewed bounded hold")

clock = 70
local external = Q:QueueEvent(2, 3044)
assert(external and external.owner == "external"
    and Q:Blocker(normal, { gcd = 1.5 }) == "normal player spell queue occupied",
    "an externally occupied normal slot must also be protected from overwrite")
clock = 191
assert(not Q:Current(), "a missing external event must not create a session latch")

local nonGcd = { name = "Kill Command", spellId = 34026,
    facts = { kind = "damage", gcd = 0 } }
local onSwing = { name = "Raptor Strike", spellId = 2973,
    facts = { kind = "damage", onNextSwing = true } }
local dbcOnSwing = { name = "Raptor Strike", spellId = 2973,
    facts = { kind = "damage", melee = true } }
assert(not Q:MayOccupy(nonGcd, {}) and not Q:MayOccupy(onSwing, {})
    and not Q:MayOccupy(dbcOnSwing,
        { gcd = 1.5, onNextSwing = true, normalGcd = false }),
    "known non-GCD and on-next-swing actions must remain independent")

print("ok: server-evidenced normal queue ownership and independent queue classes")
