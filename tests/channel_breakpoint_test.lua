-- Exact channel breakpoints are graph mechanics, independent of spell names.
-- All API globals are traps: graph search must consume only frozen evidence.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

function GetTime() error("live time read during graph search") end
function GetCastInfo() error("live cast read during graph search") end
function UnitHealth() error("live health read during graph search") end
function UnitGUID() error("live identity read during graph search") end

XelAssist = { Graph = { State = {} } }
function XelAssist.Graph.State:FriendlyByKey(state, key)
    return state.friendlies and state.friendlies.byKey
        and state.friendlies.byKey[key] or nil
end

dofile("Graph/ChannelCadence.lua")
dofile("Graph/ChannelBreakpoint.lua")
local Breakpoint = XelAssist.Graph.ChannelBreakpoint
local SOURCE = Breakpoint.EXACT_CADENCE_SOURCE

local function cadence(power)
    return { source = SOURCE, interval = 1, total = 5, totalTicks = 5,
        rootRemaining = 3.2, rootNextTickIn = 0.2,
        remainingTicks = 4, tickPower = power or 40 }
end

local function hostileState(health)
    return { time = 0, playerChanneling = true, playerCastSpellId = 1001,
        playerCastTargetGUID = "enemy-a", castRemaining = 3.2,
        targetGUID = "enemy-a", targetHealth = health or 500,
        targetHealthExact = true, health = 400, healthMax = 500 }
end

local function hostileCommitment(kind)
    return { known = true, spellId = 1001, targetGUID = "enemy-a",
        targetMatches = true, selfChannel = false, kind = kind or "damage",
        cadence = cadence(40), estimated = false }
end

local state, commitment = hostileState(500), hostileCommitment()
local plan = assert(Breakpoint:Plan(state, commitment))
assert(math.abs(plan.duration - 0.2) < 0.0001
    and math.abs(plan.landsAt - 0.2) < 0.0001
    and plan.ticks == 1 and plan.rawPower == 40 and plan.damage == 40
    and plan.remainingTicksBefore == 4 and plan.remainingTicksAfter == 3
    and plan.remainingAfter == 3 and not plan.completesChannel
    and plan.frozen and not plan.estimated,
    "the root choice must preserve exactly the next completed tick")

state.castRemaining, state.time = 3, 0.2
plan = assert(Breakpoint:Plan(state, commitment))
assert(math.abs(plan.duration - 1) < 0.0001
    and math.abs(plan.landsAt - 1.2) < 0.0001
    and plan.remainingTicksBefore == 3 and plan.remainingTicksAfter == 2,
    "a future branch must not replay the tick it just completed")

state.castRemaining, state.time = 1, 2.2
plan = assert(Breakpoint:Plan(state, commitment))
assert(math.abs(plan.duration - 1) < 0.0001 and plan.remainingAfter == 0
    and plan.remainingTicksBefore == 1 and plan.remainingTicksAfter == 0
    and plan.completesChannel,
    "only the final tick may mark the active channel complete")

local near = hostileCommitment()
near.cadence.rootRemaining, near.cadence.rootNextTickIn = 4.0001, 0.0001
state = hostileState(500)
state.castRemaining = 4.0001
plan = assert(Breakpoint:Plan(state, near))
assert(math.abs(plan.duration - 0.0001) < 0.000001,
    "a valid tick frozen at the API minimum must not be skipped")
state.castRemaining, state.time = 4, 0.0001
plan = assert(Breakpoint:Plan(state, near))
assert(math.abs(plan.duration - 1) < 0.0001
    and plan.remainingTicksBefore == 4,
    "advancing through the minimum boundary must consume it exactly once")

state, commitment = hostileState(15), hostileCommitment()
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.rawPower == 40 and plan.damage == 15
    and plan.effectivePower == 15 and plan.value == 60,
    "exact hostile health must cap marginal tick value")
state.targetHealth, state.targetHealthExact = nil, false
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.damage == 40 and plan.estimated,
    "unknown hostile health may retain expected output but not claim an exact cap")

state = hostileState(500)
state.playerCastTargetGUID = "enemy-b"
assert(Breakpoint:Plan(state, hostileCommitment()) == nil,
    "a cast-recipient identity race must fail closed")
state = hostileState(500)
state.targetGUID = "enemy-b"
assert(Breakpoint:Plan(state, hostileCommitment()) == nil,
    "an active-hostile identity race must fail closed")
state = hostileState(500)
state.playerCastSpellId = 1002
assert(Breakpoint:Plan(state, hostileCommitment()) == nil,
    "a replacement channel spell must not inherit the frozen cadence")

state, commitment = hostileState(500), hostileCommitment()
commitment.cadence.source = "tooltip guess"
assert(Breakpoint:Plan(state, commitment) == nil,
    "non-DBC cadence must not create a breakpoint")
commitment = hostileCommitment()
commitment.cadence.total = 4.5
assert(Breakpoint:Plan(state, commitment) == nil,
    "a cadence that does not cover its duration exactly must fail closed")
commitment = hostileCommitment()
commitment.cadence.totalTicks = Breakpoint.MAX_TICKS + 1
commitment.cadence.total = commitment.cadence.totalTicks
assert(Breakpoint:Plan(state, commitment) == nil,
    "an unbounded or corrupted cadence must fail closed")

state = { time = 5, playerChanneling = true, playerCastSpellId = 2001,
    playerCastTargetGUID = "ally-a", castRemaining = 3.2,
    friendlies = { byKey = { allyKey = { guid = "ally-a", health = 90,
        healthMax = 100, healthExact = true } } } }
commitment = { known = true, spellId = 2001, targetGUID = "ally-a",
    targetMatches = false, selfChannel = false, friendlyKey = "allyKey",
    kind = "heal", cadence = cadence(40) }
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.healing == 10 and plan.effectivePower == 10
    and plan.friendlyKey == "allyKey" and plan.friendlyGUID == "ally-a",
    "a friendly tick must cap against the exact retained recipient")
state.friendlies.byKey.allyKey.guid = "ally-b"
assert(Breakpoint:Plan(state, commitment) == nil,
    "a replacement friendly must not receive the old channel tick")
state.friendlies.byKey.allyKey.guid = "ally-a"
state.friendlies.byKey.allyKey.healthExact = false
assert(Breakpoint:Plan(state, commitment) == nil,
    "unknown friendly health must not fabricate healing value")

state = { time = 0, playerChanneling = true, playerCastSpellId = 3001,
    castRemaining = 3.2, resource = 85, resourceMax = 100,
    playerResourceExact = true }
commitment = { known = true, spellId = 3001, selfChannel = true,
    kind = "resource", cadence = cadence(40) }
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.resourceGain == 15 and plan.effectivePower == 15,
    "an exact resource channel must value only capacity left this tick")
state.playerResourceExact = false
assert(Breakpoint:Plan(state, commitment) == nil,
    "unknown resource state must fail closed")

state, commitment = hostileState(30), hostileCommitment()
commitment.cadence.tickPower = 50
commitment.leechEvidence = { damageFactor = 1, ratio = 1,
    applicationDelivery = 1, threatActor = "player", threatFactor = 1.5 }
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.damage == 30 and plan.healing == 30
    and plan.effectivePower == 30 and plan.threatFactor == 1.5,
    "leech healing must be capped by damage this exact tick actually deals")
state, commitment = hostileState(500), hostileCommitment()
commitment.cadence.tickPower = 50
commitment.leechEvidence = { damageFactor = 0, ratio = 1,
    applicationDelivery = 0, threatActor = "player", threatFactor = 1.5 }
plan = assert(Breakpoint:Plan(state, commitment))
assert(plan.damage == 0 and plan.healing == 0 and plan.value == 0,
    "a fully resisted tick must not fabricate damage or paired healing")

state, commitment = hostileState(500), hostileCommitment()
commitment.healthTransferData = { exact = true }
assert(Breakpoint:Plan(state, commitment) == nil,
    "a health-funded channel must remain with its dedicated causal owner")

print("ok: exact channel breakpoints preserve one frozen causal tick")
