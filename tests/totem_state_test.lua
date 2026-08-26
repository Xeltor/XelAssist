XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local now, playerClass, playerId = 100, "SHAMAN", "shaman-guid"
local ownerRace, ownerReads = false, 0
GetTime = function() return now end
UnitClass = function() return "Shaman", playerClass end
UnitExists = function(unit)
    if unit == "player" then
        ownerReads = ownerReads + 1
        if ownerRace and ownerReads > 1 then
            return true, "replacement-shaman-guid"
        end
        return true, playerId
    end
    return false, nil
end

local slots = {
    [1] = { true, "Searing Totem", 90, 30, "fire-icon", 1, 3599 },
    [2] = { true, "", 0, 0, nil, 1, 0 },
    [3] = { true, "Healing Stream Totem", 55, 60,
        "water-icon", 1, 5394 },
    [4] = { false, "", 0, 0, nil, 1, 0 },
}
local failSlot, raceSlot, reads = nil, nil, {}
local function resetReads() reads = {}; ownerReads = 0 end
GetTotemInfo = function(slot)
    if slot == failSlot then error("unavailable") end
    reads[slot] = (reads[slot] or 0) + 1
    if slot == raceSlot and reads[slot] == 2 then
        return true, "Replacement Totem", 99, 5,
            "replacement-icon", 1, 1535
    end
    local row = slots[slot]
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7]
end

local exactTimeLeft = true
GetTotemTimeLeft = function(slot)
    if not exactTimeLeft then error("unavailable") end
    if slot == 1 then return 20 end
    if slot == 3 then return 15 end
    return 0
end

local durations = { [3599] = 30000, [1535] = 5000,
    [5394] = 60000, [8512] = 120000, [999] = 10000,
    [1000] = 10000, [1001] = 10000 }
GetSpellDuration = function(spellId)
    if not durations[spellId] then error("missing duration") end
    return durations[spellId]
end

local definitions = {
    [3599] = { "totemSlot1" }, [1535] = { "totemSlot1" },
    [8071] = { "totemSlot2" }, [5394] = { "totemSlot3" },
    [8512] = { "totemSlot4" },
    [999] = { "totemSlot1", "totemSlot2" },
    [1000] = { "generic" }, [1001] = { "totemSlot1" },
}
XelAssist.Game.SpellSemantics = {}
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    local types = definitions[spellId]
    if not types then return { complete = false, admissible = false,
        reasons = { "spell record unavailable" }, atoms = {} } end
    local atoms, index = {}, nil
    for index = 1, table.getn(types) do
        table.insert(atoms, { kind = "summon", summonType = types[index] })
    end
    return { complete = spellId ~= 1001,
        admissible = spellId ~= 1001,
        reasons = spellId == 1001 and { "trigger unresolved" } or {},
        atoms = atoms }
end

dofile("Game/Player/TotemState.lua")
local Totems = XelAssist.Game.Player.TotemState
local function action(name, spellId)
    return { name = name, spellId = spellId }
end
local downstream = { exact = true, sourceSpellId = 1535,
    element = "fire", source = "focused test exact downstream hook",
    effect = { exact = true, kind = "periodicDamage" },
    range = { exact = true, center = "totem", minimum = 0, maximum = 10 },
    recipients = { exact = true, center = "totem",
        relation = "hostile", shape = "area" } }

resetReads()
local snapshot = Totems:Snapshot()
assert(snapshot.available and snapshot.playerGUID == playerId
    and snapshot.bySlot[1].element == "fire"
    and snapshot.bySlot[1].active and snapshot.bySlot[1].spellId == 3599
    and snapshot.bySlot[1].remaining == 20
    and snapshot.bySlot[2].element == "earth"
    and snapshot.bySlot[2].haveTool and not snapshot.bySlot[2].active
    and snapshot.bySlot[3].element == "water"
    and snapshot.bySlot[3].remaining == 15
    and snapshot.bySlot[4].element == "air"
    and not snapshot.bySlot[4].haveTool,
    "all four exact element slots must retain identity, tool, and lifetime")
assert(snapshot.order == nil and snapshot.priority == nil
    and snapshot.bySlot[1].effect.exact == false
    and snapshot.bySlot[1].range.exact == false
    and snapshot.bySlot[1].recipients.exact == false,
    "live slots must expose downstream uncertainty without typed ordering")

local state = { time = 0, playerGUID = playerId, totems = snapshot }
local projection, reason = Totems:PrepareLifecycle(
    action("Localized Searing", 3599), state)
assert(projection == nil and reason == "same totem already active",
    "an active same-spell totem must not be double deployed")

projection, reason = Totems:PrepareLifecycle(
    action("Localized Fire Nova", 1535), state)
assert(projection and reason == nil and projection.slot == 1
    and projection.element == "fire" and projection.duration == 5
    and projection.replacement and projection.displaced.spellId == 3599
    and projection.displaced.remaining == 20
    and projection.admissible == false
    and projection.effect.exact == false
    and projection.range.exact == false
    and projection.recipients.exact == false
    and projection.score == nil and projection.priority == nil,
    "lifecycle preparation must expose exact replacement but no proxy utility")

projection, reason = Totems:Prepare(
    action("Localized Fire Nova", 1535), state, nil)
assert(projection == nil
    and reason == "totem downstream effect, range, or recipients unavailable",
    "normal recommendation admission must fail without downstream evidence")

local incomplete = { exact = true, sourceSpellId = 1535,
    element = "fire", effect = downstream.effect,
    range = { exact = false }, recipients = downstream.recipients }
projection, reason = Totems:Prepare(
    action("Localized Fire Nova", 1535), state, incomplete)
assert(projection == nil
    and reason == "totem downstream effect, range, or recipients unavailable",
    "unknown range must fail closed")
incomplete.range, incomplete.recipients = downstream.range, { exact = false }
projection, reason = Totems:Prepare(
    action("Localized Fire Nova", 1535), state, incomplete)
assert(projection == nil
    and reason == "totem downstream effect, range, or recipients unavailable",
    "unknown recipients must fail closed")

projection, reason = Totems:Prepare(
    action("Localized Fire Nova", 1535), state, downstream)
assert(projection and reason == nil and projection.admissible
    and projection.effect == downstream.effect
    and projection.range == downstream.range
    and projection.recipients == downstream.recipients,
    "an exact hook may bind effect, range, and recipient topology without valuing it")

local staleState = { time = 0, playerGUID = playerId,
    totems = Totems:Snapshot() }
local staleProjection = Totems:Prepare(
    action("Localized Fire Nova", 1535), staleState, downstream)
staleState.totems.bySlot[1].startTime = 91
assert(not Totems:Apply(staleState, staleProjection),
    "same-element replacement races must reject stale projections")

assert(Totems:Apply(state, projection)
    and state.totems.bySlot[1].spellId == 1535
    and state.totems.bySlot[1].remaining == 5
    and state.totems.bySlot[1].effect == downstream.effect,
    "bound replacement must atomically own one element slot")
assert(Totems:Advance(state, 4) == 0
    and state.totems.bySlot[1].remaining == 1,
    "projected exact lifetime must advance monotonically")
assert(Totems:Advance(state, 1) == 1
    and not state.totems.bySlot[1].active
    and state.totems.bySlot[1].spellId == nil
    and state.totems.bySlot[1].effect.exact == false,
    "duration expiry must despawn exactly one element slot")

projection, reason = Totems:PrepareLifecycle(
    action("Localized Air", 8512), state)
assert(projection == nil and reason == "totem tool unavailable",
    "a missing elemental tool must fail closed")
projection, reason = Totems:PrepareLifecycle(
    action("Unknown Duration", 8071), state)
assert(projection == nil and reason == "totem duration unavailable",
    "placement must require installed-client positive lifetime evidence")
projection, reason = Totems:PrepareLifecycle(
    action("Conflicting", 999), state)
assert(projection == nil and reason == "totem spell has conflicting elements",
    "conflicting installed-client elements must fail closed")
projection, reason = Totems:PrepareLifecycle(
    action("Not Totem", 1000), state)
assert(projection == nil and reason == "spell is not a slotted totem summon",
    "a generic summon must not enter the four element slots")
projection, reason = Totems:PrepareLifecycle(
    action("Incomplete", 1001), state)
assert(projection == nil and reason == "trigger unresolved",
    "incomplete installed-client semantics must fail closed")

exactTimeLeft = false
resetReads()
snapshot = Totems:Snapshot()
assert(snapshot.available and snapshot.bySlot[1].remaining == 20
    and snapshot.bySlot[3].remaining == 15
    and snapshot.bySlot[1].timingSource
        == "GetTotemInfo start and duration",
    "start plus duration must provide the bounded exact-clock fallback")
exactTimeLeft = true

failSlot = 3
resetReads()
snapshot = Totems:Snapshot()
assert(not snapshot.available
    and snapshot.reason == "totem slot observation unavailable",
    "a partial four-slot observation must not publish")
failSlot = nil

raceSlot = 1
resetReads()
snapshot = Totems:Snapshot()
assert(not snapshot.available
    and snapshot.reason == "totem slots changed during observation",
    "slot replacement races across the bounded double-read must fail closed")
raceSlot = nil

ownerRace = true
resetReads()
snapshot = Totems:Snapshot()
assert(not snapshot.available
    and snapshot.reason == "totem owner changed during observation",
    "player identity races across the four-slot observation must fail closed")
ownerRace = false

local oldEarth = slots[2]
slots[2] = { true, "", 0, 0, nil, 1, 8071 }
resetReads()
snapshot = Totems:Snapshot()
assert(not snapshot.available
    and snapshot.reason == "totem empty-slot identity is incoherent",
    "an empty slot with a spell identity must fail closed")
slots[2] = oldEarth

playerClass = "MAGE"
resetReads()
snapshot = Totems:Snapshot()
assert(not snapshot.available
    and snapshot.reason == "player is not an exactly identified Shaman",
    "the Shaman tracker must reject other classes")

print("ok: exact Shaman totem element and fail-closed downstream lifecycle")
