-- Drain Life is only the fixture. Production behavior is driven by generic
-- leech facts, installed-client channel cadence and causal timeline events.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local deliveryFactor, applicationDelivery = 1, 1
local activeCast = { spellId = 778, castType = 3,
    castStartS = 98.2, castRemainingMs = 3200, castDurationMs = 5000 }
function GetTime() return 100 end
function GetCastInfo() return activeCast end
function GetSpellRecField(spellId, field, asArray)
    if spellId == 778 and field == "effectAmplitude" and asArray then
        return { 1000, 0, 0 }
    end
end

XelAssist = { Combat = { Resistance = {} }, Game = { Actors = {} }, Graph = {
    ActionPower = {}, State = {}, Effects = {}, HostileEffects = {},
    CompanionCommandPolicy = {}, EventAuras = {},
} }
function XelAssist.Game.Actors:Facts(action) return action.mock end
function XelAssist.Graph.ActionPower:Estimate(action)
    return action.mock.average, false
end
function XelAssist.Graph.Effects:OverWindow()
    return deliveryFactor, applicationDelivery, { source = "test resistance" }
end
function XelAssist.Graph.State:FriendlyByKey() return nil end
function XelAssist.Graph.State:FriendlyByUnit(state, unit)
    return unit == "player" and state.playerFriendly or nil
end
function XelAssist.Graph.State:ActiveHostile(state)
    return state.activeHostile
end
function XelAssist.Graph.HostileEffects:ApplySelectedDamage(state, amount)
    if not state.targetHealthExact then return false, nil end
    local dealt = math.min(state.targetHealth, math.max(0, amount))
    state.targetHealth = state.targetHealth - dealt
    return true, dealt
end
function XelAssist.Graph.CompanionCommandPolicy:UpdateRecovery() end
function XelAssist.Graph.EventAuras:BeginScheduled() end

dofile("Game/SpellTiming.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/LeechChannel.lua")
dofile("Graph/ChannelCadence.lua")
dofile("Graph/ChannelCommitment.lua")
dofile("Graph/OngoingEffects.lua")
local Channel = XelAssist.Graph.ChannelCommitment
local Ongoing = XelAssist.Graph.OngoingEffects

local drain = { name = "Drain Life", spellId = 778, actor = "player",
    facts = { kind = "damage", channel = true, leech = true, threat = 1.5 },
    mock = { duration = 5, average = 500 } }
XelAssist.Game.SpellTiming:Apply(drain, drain.mock)

local function state(targetHealth)
    return { playerCasting = true, playerChanneling = true,
        playerCastName = drain.name, playerCastSpellId = drain.spellId,
        playerCastTargetGUID = "enemy-guid", castRemaining = 3.2,
        targetGUID = "enemy-guid", targetHealth = targetHealth,
        targetHealthExact = true, health = 400, healthMax = 1000,
        playerFriendly = { key = "player-key", unit = "player",
            health = 400, healthMax = 1000 },
        friendlies = { primaryKey = "player-key" },
        actors = { player = { health = 400 } },
        activeHostile = { guid = "enemy-guid",
            threat = { playerDeltaExact = true } },
        playerThreat = { actor = "player", playerOnly = true, exact = true,
            multiplier = 0.8, minimum = 0.8, maximum = 0.8 },
        role = "damage", resource = 100, resourceMax = 100,
        actorReadyAt = { player = 3.2 }, time = 0, auras = {} }
end

local root = state(500)
Channel:Prepare(root, { drain })
local continuation = assert(Channel:Candidate(root))
assert(continuation.leechChannel and continuation.leechChannel.ticks == 4
    and continuation.power == 400 and continuation.rawPower == 400
    and continuation.leechChannel.effectiveHealing == 400,
    "an exact active leech channel must retain four future tick pairs")
local events = Ongoing:Events(root, root, continuation, {})
assert(table.getn(events) == 5
    and math.abs(events[1].offset - 0.2) < 0.0001
    and math.abs(events[4].offset - 3.2) < 0.0001
    and events[5].kind == "leechChannelFinish",
    "only exact completed tick boundaries may schedule leech delivery")

local out = state(500)
assert(Channel:Apply(out, continuation)
    and out.targetHealth == 500 and out.health == 400
    and out.activeHostile.threat.playerDelta == nil,
    "the continuation action must not front-load aggregate damage or healing")
local i
for i = 1, table.getn(events) do
    Ongoing:ApplyEvent(out, root, continuation, {}, events[i])
end
assert(out.targetHealth == 100 and out.health == 800
    and out.actors.player.health == 800
    and out.playerFriendly.health == 800 and not out.playerChanneling
    and out.activeHostile.threat.playerDelta == 480
    and out.activeHostile.projectedThreat.player == 480,
    "each delivered tick must damage, heal and add scaled threat exactly once")

root = state(50)
Channel:Prepare(root, { drain })
continuation = assert(Channel:Candidate(root))
events = Ongoing:Events(root, root, continuation, {})
assert(continuation.leechChannel.ticks == 1
    and continuation.effectivePower == 50
    and continuation.leechChannel.effectiveHealing == 50
    and table.getn(events) == 2,
    "exact hostile health must cap both useful ticks and paired healing")
out = state(50)
Ongoing:ApplyEvent(out, root, continuation, {}, events[1])
assert(out.targetHealth == 0 and out.health == 450,
    "the lethal tick may heal only for damage actually dealt")
assert(out.activeHostile.threat.playerDelta == 60,
    "lethal leech threat must use actual capped damage and its threat factor")

out = state(500)
out.activeHostile.guid = "replacement-guid"
out.targetGUID = "replacement-guid"
Ongoing:ApplyEvent(out, root, continuation, {}, events[1])
assert(out.targetHealth == 500 and out.health == 400
    and out.activeHostile.threat.playerDelta == nil,
    "a target identity race must not damage, heal, or attribute threat")

root = state(500)
Channel:Prepare(root, { drain })
local movement = { action = { facts = { movementSetup = true } },
    downtime = 0.5 }
assert(table.getn(Ongoing:Events(root, root, movement, {})) == 0,
    "movement clipping before a tick must schedule no leech")
out = state(500)
Channel:Apply(out, movement)
assert(out.targetHealth == 500 and out.health == 400
    and not out.playerChanneling,
    "movement clipping must not fabricate damage or healing")

local clipContext = { action = { actor = "player", facts = { kind = "damage" } },
    state = root, value = 100, reason = "new action" }
Channel:Adjust(clipContext)
local clipped = { action = clipContext.action, clipsChannel = true,
    channelCommitment = root.channelCommitment, wait = 0, downtime = 1.5 }
assert(table.getn(Ongoing:Events(root, root, clipped, {})) == 0,
    "an action clip must not inherit future channel ticks")
out = state(500)
Channel:Apply(out, clipped)
assert(out.targetHealth == 500 and out.health == 400,
    "an action clip must clear without phantom sustain")

deliveryFactor, applicationDelivery = 0, 0
root = state(500)
Channel:Prepare(root, { drain })
continuation = assert(Channel:Candidate(root))
events = Ongoing:Events(root, root, continuation, {})
assert(continuation.power == 0 and continuation.effectivePower == 0
    and continuation.leechChannel.effectiveHealing == 0
    and math.abs(continuation.occupancy - 3.2) < 0.0001
    and table.getn(events) == 1
    and events[1].kind == "leechChannelFinish"
    and math.abs(events[1].offset - 3.2) < 0.0001,
    "a fully resisted delivery must expose no damaging or healing ticks but retain channel occupancy")
out = state(500)
Channel:Apply(out, continuation)
Ongoing:ApplyEvent(out, root, continuation, {}, events[1])
assert(out.targetHealth == 500 and out.health == 400,
    "full resistance must not fabricate healing")

print("ok: Warlock leech channels resolve delivered tick pairs causally")
