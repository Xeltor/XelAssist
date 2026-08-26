-- Engine-effective Arcane Missiles cadence under installed Accelerated Arcana.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local passive = { attributes = 464, spellFamilyName = 3,
    effect = { 6, 6, 6 }, effectApplyAuraName = { 108, 108, 108 },
    effectBasePoints = { -6, -6, -6 }, effectMiscValue = { 1, 19, 1 } }
local missiles = { school = 6, spellFamilyName = 3,
    spellFamilyFlags = 264192, durationIndex = 27,
    effect = { 6, 6, 0 }, effectApplyAuraName = { 23, 4, 0 },
    effectImplicitTargetA = { 1, 6, 0 }, effectAmplitude = { 1000, 0, 0 } }
local rows = { [51981] = passive, [5143] = missiles }
local learned, speed, reads = true, 1, 0

function GetSpellRecField(id, field, copied)
    reads = reads + 1
    local value = rows[id] and rows[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(id) return id == 5143 and 5000 or nil end
function IsPlayerSpell(id) return id == 51981 and learned end
function GetSpellModifiers(id, operation)
    assert(id == 5143 and operation == 1)
    return 0, -5, 1
end
function GetUnitField(unit, field)
    assert(unit == "player" and field == "modCastSpeed")
    return speed
end

XelAssist = { Game = { Player = {} } }
dofile("Game/Player/MageAcceleratedArcana.lua")
local Runtime = XelAssist.Game.Player.MageAcceleratedArcana
local action = { spellId = 5143, facts = { kind = "damage", channel = true } }
local base = { duration = 5, channelInterval = 1,
    channelIntervalSource = "client DBC effectAmplitude", cast = 0 }

local captured = Runtime:CaptureFacts(action, base)
assert(captured ~= base and captured.mageAcceleratedArcana.exact
    and captured.duration == 4.75 and captured.channelInterval == 0.95
    and captured.channelIntervalSource
        == "engine-effective Accelerated Arcana cadence",
    "the passive must shorten all five Arcane Missiles tick intervals")
assert(base.duration == 5 and base.channelInterval == 1,
    "root timing capture must not mutate cached tooltip facts")

speed = 0.8
captured = Runtime:CaptureFacts(action, base)
assert(math.abs(captured.duration - 3.8) < 0.000001
    and math.abs(captured.channelInterval - 0.76) < 0.000001
    and captured.mageAcceleratedArcana.modifiers.castSpeedMultiplier == 0.8,
    "other exact casting-speed effects must accelerate the same five ticks")

learned = false
captured = Runtime:CaptureFacts(action, base)
assert(captured.duration == 5 and captured.channelInterval == 1
    and captured.mageAcceleratedArcana == nil,
    "an unlearned passive must preserve ordinary DBC channel timing")

learned = true
local accelerated = Runtime:CaptureFacts(action, base)
local readsAtRoot = reads
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetUnitField = function() error("cast-speed read during graph search") end
assert(accelerated.channelInterval == 0.76 and reads == readsAtRoot,
    "descendants must consume only sealed timing evidence")

local now = 10
function GetTime() return now end
function GetCastInfo() return { spellId = 5143, castType = 3,
    castStartS = 9.24, castRemainingMs = 3040, castDurationMs = 3800 } end
XelAssist.Game.Actors = { Facts = function() return accelerated end }
XelAssist.Graph = { RootObservation = {
    Facts = function() return accelerated, "known" end },
    ActionPower = { Estimate = function() return 500, false end },
    State = { FriendlyByKey = function() return nil end },
}
dofile("Game/SpellTiming.lua")
dofile("Graph/ChannelCadence.lua")
dofile("Graph/ChannelCommitment.lua")
local state = { playerChanneling = true, playerCastSpellId = 5143,
    playerCastName = "Arcane Missiles", playerCastTargetGUID = "enemy",
    targetGUID = "enemy", castRemaining = 3.04, targetHealth = 1000,
    targetHealthExact = true, role = "damage", resource = 100,
    resourceMax = 100 }
XelAssist.Graph.ChannelCommitment:Prepare(state, { action })
assert(state.channelCommitment and state.channelCommitment.known
    and state.channelCommitment.cadence
    and state.channelCommitment.cadence.totalTicks == 5
    and state.channelCommitment.cadence.remainingTicks == 4
    and state.channelCommitment.cadence.source
        == "engine-effective Accelerated Arcana cadence",
    "active-channel protection must accept the sealed accelerated cadence")

Runtime:Invalidate()
GetSpellRecField = function(id, field, copied)
    local value = rows[id] and rows[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellDuration = function(id) return id == 5143 and 5000 or nil end
GetSpellModifiers = function() return 0, -5, 1 end
GetUnitField = function() return 1 end
passive.effectMiscValue = { 1, 18, 1 }
local shifted = Runtime:CaptureFacts(action, base)
assert(shifted.mageAcceleratedArcana.exact == false
    and shifted.unmodeledUnsafe
        == "Accelerated Arcana timing unavailable",
    "a shifted learned passive must fail closed")

print("ok: Mage Accelerated Arcana seals five engine-effective channel ticks")
