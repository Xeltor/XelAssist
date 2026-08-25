-- Arcane Missiles is only the fixture.  Production channel opportunity is
-- derived from exact DBC cadence and graph state, never from a spell rotation.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local records = {
    [5143] = { effectAmplitude = { 1000, 0, 0 } },
    [9999] = { effectAmplitude = { 1000, 500, 0 } },
    [9998] = { effectAmplitude = { 0, 0, 0 } },
}

function GetSpellRecField(spellId, field, asArray)
    local record = records[spellId]
    if asArray and record then return record[field] end
    return nil
end

local now = 100
local activeCast = { spellId = 5143, castType = 3,
    castStartS = 98.2, castRemainingMs = 3200, castDurationMs = 5000 }
function GetTime() return now end
function GetCastInfo() return activeCast end

local dealt = 0
XelAssist = { Game = { Actors = {} }, Graph = {
    ActionPower = {}, State = {}, HostileEffects = {},
    CompanionCommandPolicy = {},
} }
function XelAssist.Game.Actors:Facts(action) return action.mock or {} end
function XelAssist.Graph.ActionPower:Estimate(action)
    return action.mock and action.mock.average or 0, false
end
function XelAssist.Graph.State:FriendlyByKey() return nil end
function XelAssist.Graph.HostileEffects:ApplySelectedDamage(state, amount)
    local applied = math.min(state.targetHealth, amount)
    state.targetHealth, dealt = state.targetHealth - applied, dealt + applied
    return true, applied
end
function XelAssist.Graph.CompanionCommandPolicy:UpdateRecovery() end

dofile("Game/SpellTiming.lua")
dofile("Graph/ChannelCommitment.lua")
local Timing = XelAssist.Game.SpellTiming
local Channel = XelAssist.Graph.ChannelCommitment

local missiles = { name = "Arcane Missiles", spellId = 5143,
    actor = "player", facts = { kind = "damage", channel = true },
    mock = { duration = 5, average = 200 } }
Timing:Apply(missiles, missiles.mock)
assert(missiles.mock.channelInterval == 1
    and missiles.mock.channelIntervalSource == "client DBC effectAmplitude",
    "a channel must expose its exact installed-client effect cadence")

local state = { playerCasting = true, playerChanneling = true,
    playerCastName = "Arcane Missiles", playerCastSpellId = 5143,
    playerCastTargetGUID = "enemy-guid", castRemaining = 3.2,
    targetGUID = "enemy-guid", targetHealth = 500,
    targetHealthExact = true, role = "damage", resource = 100,
    resourceMax = 100, actorReadyAt = { player = 3.2 }, time = 0 }
Channel:Prepare(state, { missiles })
local commitment = state.channelCommitment
local continuation = Channel:Candidate(state)
assert(commitment and commitment.known and commitment.cadence
    and commitment.cadence.totalTicks == 5
    and commitment.cadence.remainingTicks == 4
    and math.abs(commitment.cadence.nextTickIn - 0.2) < 0.0001
    and continuation and continuation.power == 160
    and continuation.channelCadence.remainingTicks == 4,
    "remaining output must include only the four ticks not yet completed")

local routine = { action = { name = "Fire Blast", actor = "player",
        facts = { kind = "damage" } }, state = state, value = 120,
    reason = "routine damage" }
Channel:Adjust(routine)
assert(routine.clipsChannel and routine.value < continuation.value,
    "routine damage must not erase four already scheduled channel ticks")

local interrupt = { action = { name = "Counterspell", actor = "player",
        facts = { kind = "interrupt" } }, state = state, value = 700,
    reason = "prevents a proven hostile cast" }
Channel:Adjust(interrupt)
assert(interrupt.clipsChannel and interrupt.value > continuation.value,
    "proven high-value utility must remain able to clip a damage channel")

local harmless = { action = { name = "Attack state", actor = "player",
        facts = { kind = "command", playerAttack = true } },
    state = state, value = 5, reason = "maintains attack state" }
Channel:Adjust(harmless)
assert(harmless.preservesChannel and harmless.value > continuation.value,
    "a proven preserving action must retain the completed-tick opportunity")

activeCast = { spellId = 5143, castType = 3,
    castStartS = 98.2, castRemainingMs = 2100, castDurationMs = 3900 }
local pushed = { playerCasting = true, playerChanneling = true,
    playerCastName = "Arcane Missiles", playerCastSpellId = 5143,
    playerCastTargetGUID = "enemy-guid", castRemaining = 2.1,
    targetGUID = "enemy-guid", targetHealth = 500,
    targetHealthExact = true, role = "damage", resource = 100,
    resourceMax = 100, actorReadyAt = { player = 2.1 }, time = 0 }
Channel:Prepare(pushed, { missiles })
local pushedContinuation = Channel:Candidate(pushed)
assert(pushedContinuation and pushedContinuation.power == 80
    and pushedContinuation.channelCadence.remainingTicks == 2
    and math.abs(pushedContinuation.channelCadence.nextTickIn - 0.2) < 0.0001,
    "observed start phase must survive channel-shortening pushback")

activeCast = { spellId = 5143, castType = 3,
    castStartS = 98.2, castRemainingMs = 3200, castDurationMs = 5000 }

state.castRemaining = 1.1
continuation = Channel:Candidate(state)
assert(continuation and continuation.power == 80
    and continuation.channelCadence.remainingTicks == 2,
    "future graph time must remove completed ticks discretely, not smoothly")

state.castRemaining, state.targetHealth = 3.2, 70
continuation = Channel:Candidate(state)
assert(continuation and continuation.power == 160
    and continuation.effectivePower == 70,
    "exact target health must cap channel opportunity without changing raw ticks")

local out = { playerCasting = true, playerChanneling = true,
    playerCastName = "Arcane Missiles", playerCastSpellId = 5143,
    playerCastTargetGUID = "enemy-guid", castRemaining = 3.2,
    targetHealth = 500, actorReadyAt = { player = 3.2 }, time = 0 }
assert(Channel:Apply(out, continuation) and out.targetHealth == 340
    and not out.playerChanneling and dealt == 160,
    "finishing the commitment must apply only its exact remaining tick power")

local unknown = { name = "Opaque Channel", spellId = 9998,
    actor = "player", facts = { kind = "damage", channel = true },
    mock = { duration = 5, average = 200 } }
Timing:Apply(unknown, unknown.mock)
activeCast = { spellId = 9998, castType = 3,
    castStartS = 98.2, castRemainingMs = 3200, castDurationMs = 5000 }
state.playerCastName, state.playerCastSpellId = "Opaque Channel", 9998
state.playerCastTargetGUID, state.targetGUID = "enemy-guid", "enemy-guid"
state.targetHealth, state.castRemaining = 500, 3.2
Channel:Prepare(state, { unknown })
continuation = Channel:Candidate(state)
assert(state.channelCommitment and not state.channelCommitment.known
    and state.channelCommitment.cadence == nil
    and continuation and continuation.power == 0
    and continuation.reason == "preserves an unpriced active channel",
    "missing DBC cadence must fail closed without inventing partial output")

local conflict = { name = "Conflicting Channel", spellId = 9999,
    facts = { kind = "damage", channel = true } }
assert(Timing:ChannelInterval(conflict) == nil,
    "conflicting channel amplitudes must not choose an arbitrary cadence")

local incomplete = { name = "Partial Cadence", spellId = 5143,
    facts = { kind = "damage", channel = true } }
local incompleteFacts = { duration = 4.5 }
Timing:Apply(incomplete, incompleteFacts)
assert(incompleteFacts.channelInterval == nil,
    "a cadence that does not exactly cover the channel must fail closed")

print("ok: Mage channel opportunity uses exact completed DBC ticks")
