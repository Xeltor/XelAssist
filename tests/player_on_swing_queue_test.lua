table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Player = {} } }
local clock, fallbackPending = 0, 0
local nativePresent, native = false, {}
local zeroGuid = "0x0000000000000000"

GetTime = function() return clock end
GetCurrentCastingInfo = function()
    return 0, 0, 0, 0, 0, fallbackPending, 0
end
GetOnSwingInfo = function()
    if nativePresent then return native end
    return nil
end

local function setNative(armed, spellId, targetGuid, attemptId,
        buffered, bufferedSpellId, bufferedTargetGuid, bufferedAttemptId)
    nativePresent = armed or buffered and true or false
    native.pending, native.armed = armed and 1 or 0, armed and 1 or 0
    native.spellId = armed and spellId or 0
    native.targetGuid = armed and (targetGuid or zeroGuid) or zeroGuid
    native.attemptId = armed and tostring(attemptId or "0") or "0"
    native.buffered = buffered and 1 or 0
    native.bufferedSpellId = buffered and bufferedSpellId or 0
    native.bufferedTargetGuid = buffered
        and (bufferedTargetGuid or zeroGuid) or zeroGuid
    native.bufferedAttemptId = buffered
        and tostring(bufferedAttemptId or "0") or "0"
end

local function clearNative()
    nativePresent = false
end

dofile("Game/Player/OnSwing.lua")
local O = XelAssist.Game.Player.OnSwing
local targetA, targetB = "target-a", "target-b"
local raptor = { name = "Raptor Strike", spellId = 2973,
    facts = { kind = "damage", onNextSwing = true } }
local heroic = { name = "Heroic Strike", spellId = 78,
    facts = { kind = "damage", onNextSwing = true } }
local tooltip = { onNextSwing = true, normalGcd = false, school = 0 }

local empty = O:Snapshot()
assert(empty.supported and empty.exact and not empty.occupied,
    "the exact native API must prove an empty lane")
assert(O:Is(raptor, tooltip) and not O:Is({ facts = {} }, {}),
    "on-next-swing classification must remain data-derived")

local submitted = assert(O:Arm(raptor, tooltip, targetA, 125, 15))
assert(submitted.phase == "submitting" and submitted.owner == "xelassist"
    and O:Snapshot().occupied,
    "Arm must close the lane before entering the synchronous native call")
assert(not O:Arm(heroic, tooltip, targetA, 130, 15),
    "a nested or repeated submission must not replace a provisional arm")

setNative(true, 2973, targetA, "101", false)
local birth = O:StateEvent(0, 2973, targetA, "101")
assert(birth and birth.owner == "external",
    "a same-spell state event alone must not claim XelAssist ownership")
local owned = O:CastEvent(1, 2973, 2, targetA, "101")
assert(owned == submitted and owned.owner == "xelassist"
    and owned.action == raptor and owned.tooltip == tooltip
    and owned.rawPower == 125 and owned.cost == 15,
    "the exact cast attempt must bind the pre-dispatch record and metadata")
local finalized, reason = O:Finalize(submitted, true)
assert(finalized and reason == nil,
    "Finalize must accept the exact generation bound during dispatch")
assert(not O:Arm(heroic, tooltip, targetA, 130, 15),
    "an owned armed generation must block replacement")

local snapshot = O:Snapshot()
native.attemptId, native.targetGuid = "mutated", targetB
assert(snapshot.attemptId == "101" and snapshot.targetGuid == targetA,
    "Snapshot must copy Nampower's reusable GetOnSwingInfo table")
native.attemptId, native.targetGuid = "101", targetA

assert(O:ServerResult(1, 2973, targetA, 0, "101") == owned
    and owned.phase == "server-armed",
    "server acceptance must retain rather than release the armed generation")
assert(not O:Failed(2973, "0") and O:Snapshot().attemptId == "101",
    "an ambiguous legacy failure must not clear exact occupancy")
assert(not O:StateEvent(6, 2973, targetA, "0")
    and O:Snapshot().attemptId == "101",
    "an ambiguous native failure must not clear an occupied lane")
assert(not O:StateEvent(6, 2973, targetA, "wrong")
    and O:Snapshot().attemptId == "101",
    "a mismatched generation must not clear the current lane")

clearNative()
local consumed = O:StateEvent(5, 2973, targetA, "101")
assert(consumed == owned and consumed.phase == "consumed"
    and consumed.action == raptor and consumed.cost == 15,
    "CONSUMED must return the exact retired owned record with graph metadata")
local delivered = O:Resolved(2973, "player-guid", "player-guid", targetB)
assert(delivered == consumed and delivered.resolvedTargetGuid == targetB,
    "same-packet delivery must recover the consumed generation and actual target")
assert(not O:Resolved(2973, "player-guid", "player-guid", targetB),
    "a consumed generation must be returned to delivery only once")
assert(not O:Snapshot().occupied,
    "exact native absence after consumption must reopen the lane")

clock = 1
local rejected = assert(O:Arm(raptor, tooltip, targetA, 120, 15))
setNative(true, 2973, targetA, "151", false)
O:StateEvent(0, 2973, targetA, "151")
assert(O:CastEvent(1, 2973, 2, targetA, "151") == rejected)
clearNative()
assert(O:StateEvent(6, 2973, targetA, "151") == rejected)
local rejectionAccepted = O:Finalize(rejected, true)
assert(not rejectionAccepted and not O:Snapshot().occupied,
    "a synchronous exact failure must reject Finalize and reopen the lane")
local undispatched = assert(O:Arm(raptor, tooltip, targetA, 120, 15))
assert(not O:Finalize(undispatched, false) and not O:Snapshot().occupied,
    "an undispatched provisional arm must be released")

-- Replacement events describe the old identity. The post-mutation native slot
-- remains occupied by the new generation and must never inherit old ownership.
clock = 2
local old = assert(O:Arm(raptor, tooltip, targetA, 100, 15))
setNative(true, 2973, targetA, "201", false)
O:StateEvent(0, 2973, targetA, "201")
assert(O:CastEvent(1, 2973, 2, targetA, "201") == old)
assert(O:Finalize(old, true))
setNative(true, 78, targetA, "202", false)
local replaced = O:StateEvent(2, 2973, targetA, "201")
local replacement = O:Snapshot()
assert(replaced == old and replaced.phase == "armed-replaced"
    and replacement.occupied and replacement.spellId == 78
    and replacement.attemptId == "202" and replacement.owner == "external",
    "ARMED_REPLACED must retire only the old identity and adopt the new slot")
assert(not O:StateEvent(6, 2973, targetA, "201")
        or O:Snapshot().attemptId == "202",
    "a late terminal event for the old generation must not clear its successor")
setNative(false, nil, nil, nil, false)
assert(O:StateEvent(7, 78, targetA, "202")
    and not O:Snapshot().occupied,
    "CANCELLED must release the exact current generation")

-- A race may arm an external generation and buffer XelAssist behind it. The
-- replay receives a new attempt ID; metadata follows only its exact cast event.
clock = 4
local bufferedSubmission = assert(O:Arm(raptor, tooltip, targetA, 140, 20))
setNative(true, 78, targetA, "301", true, 2973, targetA, "302")
O:StateEvent(1, 2973, targetA, "302")
local bufferedOwned = O:CastEvent(0, 2973, 2, targetA, "302")
assert(bufferedOwned == bufferedSubmission and bufferedOwned.owner == "xelassist")
assert(O:Finalize(bufferedSubmission, true))
local raced = O:Snapshot()
assert(raced.attemptId == "301" and raced.owner == "external"
    and raced.bufferedAttemptId == "302"
    and raced.bufferedOwner == "xelassist",
    "armed and buffered generations must retain independent ownership")

setNative(false, nil, nil, nil, false)
assert(O:StateEvent(5, 78, targetA, "301").attemptId == "301",
    "consuming the armed generation must preserve the buffered generation")
local popped = O:StateEvent(4, 2973, targetA, "302")
assert(popped and popped.attemptId == "302" and popped.phase == "buffer-popped",
    "BUFFER_POPPED must retain the detached buffer metadata until replay")
setNative(true, 2973, targetA, "303", false)
O:StateEvent(0, 2973, targetA, "303")
local replayed = O:CastEvent(1, 2973, 2, targetA, "303")
assert(replayed and replayed.owner == "xelassist" and replayed.action == raptor
    and replayed.attemptId == "303" and replayed.replayedFromAttemptId == "302",
    "a replay's new exact cast ID must inherit the old owned buffer metadata")
assert(O:Snapshot().attemptId == "303",
    "replaying the old buffer must not leave its detached generation active")
O:StateEvent(6, 2973, targetA, "302")
assert(O:Snapshot().attemptId == "303",
    "a late failure for the old buffer must not clear the replay")
clearNative()
assert(O:StateEvent(5, 2973, targetA, "303") == replayed,
    "the replayed generation must remain exactly consumable")

-- If code-4 callbacks create another native generation, code 8 cancels only
-- the detached old buffer; it must not disturb the newer exact owner.
O:Reset("buffer callback replacement")
clock = 6
local detached = assert(O:Arm(raptor, tooltip, targetA, 145, 21))
setNative(true, 78, targetA, "601", true, 2973, targetA, "602")
O:StateEvent(1, 2973, targetA, "602")
assert(O:CastEvent(0, 2973, 2, targetA, "602") == detached)
assert(O:Finalize(detached, true))
clearNative()
O:StateEvent(5, 78, targetA, "601")
assert(O:StateEvent(4, 2973, targetA, "602") == detached)
local callbackArm = assert(O:Arm(heroic, tooltip, targetA, 150, 12))
setNative(true, 78, targetA, "603", false)
O:StateEvent(0, 78, targetA, "603")
assert(O:CastEvent(1, 78, 2, targetA, "603") == callbackArm)
assert(O:Finalize(callbackArm, true))
assert(O:StateEvent(8, 2973, targetA, "602") == detached
    and detached.phase == "buffer-cancelled"
    and O:Snapshot().attemptId == "603",
    "BUFFER_CANCELLED must clear only the detached buffer replay source")
clearNative()
O:StateEvent(7, 78, targetA, "603")

-- A callback-created same-spell arm can resemble the pending replay until
-- Nampower closes the outer pop with code 8. That cancellation must remove
-- inherited XelAssist metadata from the external generation.
O:Reset("same-spell callback replacement")
local sameDetached = assert(O:Arm(raptor, tooltip, targetA, 146, 22))
setNative(true, 78, targetA, "611", true, 2973, targetA, "612")
O:StateEvent(1, 2973, targetA, "612")
assert(O:CastEvent(0, 2973, 2, targetA, "612") == sameDetached)
assert(O:Finalize(sameDetached, true))
clearNative()
O:StateEvent(5, 78, targetA, "611")
assert(O:StateEvent(4, 2973, targetA, "612") == sameDetached)
setNative(true, 2973, targetA, "613", false)
O:StateEvent(0, 2973, targetA, "613")
local provisionalReplay = O:CastEvent(1, 2973, 2, targetA, "613")
assert(provisionalReplay and provisionalReplay.owner == "xelassist",
    "same-spell callback state is provisional until the outer pop settles")
assert(O:StateEvent(8, 2973, targetA, "612") == sameDetached)
local externalSameSpell = O:Snapshot()
assert(externalSameSpell.attemptId == "613"
    and externalSameSpell.owner == "external"
    and externalSameSpell.action == nil
    and externalSameSpell.tooltip == nil
    and externalSameSpell.rawPower == nil
    and externalSameSpell.cost == nil
    and externalSameSpell.costKnown == nil
    and externalSameSpell.replayedFromAttemptId == nil,
    "BUFFER_CANCELLED must disown a callback-created same-spell generation")
clearNative()
O:StateEvent(7, 2973, targetA, "613")

-- Buffer replacement also names the old generation and leaves the native
-- replacement independently occupied.
O:Reset("buffer replacement")
clock = 8
local oldBuffer = assert(O:Arm(raptor, tooltip, targetA, 100, 15))
setNative(true, 78, targetA, "701", true, 2973, targetA, "702")
O:StateEvent(1, 2973, targetA, "702")
assert(O:CastEvent(0, 2973, 2, targetA, "702") == oldBuffer)
assert(O:Finalize(oldBuffer, true))
setNative(true, 78, targetA, "701", true, 78, targetA, "703")
assert(O:StateEvent(3, 2973, targetA, "702") == oldBuffer)
local bufferReplacement = O:Snapshot()
assert(bufferReplacement.bufferedAttemptId == "703"
    and bufferReplacement.bufferedOwner == "external",
    "BUFFER_REPLACED must retire only the old buffered attempt")

-- Nampower 4.7 fallback: one provisional owner plus the live pending bit and
-- legacy buffer events. Ambiguous failures never reopen a live lane.
GetOnSwingInfo = nil
O:Reset("fallback test")
clock, fallbackPending = 10, 0
local fallbackRecord = assert(O:Arm(raptor, tooltip, targetA, 90, 10))
assert(O:CastEvent(1, 2973, 2, targetA, "401"))
assert(O:Finalize(fallbackRecord, true))
fallbackPending = 1
local fallback = O:Snapshot()
assert(fallback.supported and not fallback.exact and fallback.occupied
    and fallback.owner == "xelassist",
    "the 4.7 pending flag must retain the single locally owned generation")
assert(not O:Failed(2973, "0") and O:Snapshot().occupied,
    "an ambiguous 4.7 failure must not clear a live pending generation")
assert(not O:QueueEvent(2, 2973) and not O:QueueEvent(3, 2973)
    and not O:QueueEvent(4, 2973) and not O:QueueEvent(5, 2973),
    "normal and non-GCD queue codes must not mutate the on-swing lane")
assert(O:Resolved(2973, "player-guid", "player-guid", targetB) == fallbackRecord,
    "exact GO evidence must return the owned 4.7 generation")
fallbackPending = 0
assert(not O:Snapshot().occupied,
    "the cleared 4.7 live bit must reopen the lane after GO returns")

O:Reset("fallback buffer")
clock, fallbackPending = 20, 0
local queued = assert(O:Arm(raptor, tooltip, targetA, 95, 11))
assert(O:CastEvent(0, 2973, 2, targetA, "501") == queued)
assert(O:QueueEvent(0, 2973) == queued and O:Finalize(queued, true),
    "legacy code 0 must preserve the failed attempt as an owned buffer")
assert(O:QueueEvent(1, 2973) == queued and O:Snapshot().occupied,
    "legacy code 1 alone must remain provisional and must not reopen the lane")
clock = 21
assert(not O:Snapshot().occupied,
    "a settled legacy pop plus known false pending state may release the fallback")

O:Reset("unknown cost metadata")
clock, fallbackPending = 22, 0
local unknownCost = assert(O:Arm(raptor, tooltip, targetA, 95, nil, false))
local unknownCostSnapshot = O:Snapshot()
assert(unknownCost.costKnown == false
    and unknownCostSnapshot.costKnown == false
    and unknownCostSnapshot.cost == nil,
    "unknown next-swing cost must survive the runtime ownership snapshot")
O:Reset("unknown cost metadata complete")

print("ok: exact-generation player on-swing ownership and conservative 4.7 fallback")
