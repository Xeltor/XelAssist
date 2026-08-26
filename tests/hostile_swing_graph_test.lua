table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, hostileGuid = {}, {}
XelAssist = { Graph = { State = {} } }
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/HostileSwings.lua")
local S = XelAssist.Graph.HostileSwings
local root = { actors = { player = { guid = playerGuid, health = 100,
        healthMax = 100, healthExact = true } },
    hostileSwings = { lanes = { { attackerGuid = hostileGuid,
        attackerKey = hostileGuid, victimGuid = playerGuid,
        victimKind = "player", interval = 2, nextSwingIn = 0.5,
        expectedDamage = 15, generation = 4, phaseKnown = true } } } }
local events = S:Events(root, { downtime = 4.6 })
assert(table.getn(events) == 3 and events[1].offset == 0.5
    and events[1].priority == 15 and events[3].offset == 4.5,
    "a verified hostile lane must emit bounded, pre-action incoming events")
assert(math.abs(root.hostileSwings.lanes[1].nextSwingIn - 1.9) < 0.001,
    "the hostile phase must advance across the chosen action window")
assert(S:Apply(root, events[1])
    and root.actors.player.health == 85
    and root.actors.player.healthExact == false
    and root.incomingProjectionPartial
    and root.lastHostileSwing.attackerGuid == hostileGuid,
    "one learned post-mitigation swing must reduce recipient health exactly once")
assert(S:Apply(root, events[2]) and root.actors.player.health == 70,
    "successive projected rounds must each apply once")

local capped = { actors = root.actors, hostileSwings = { lanes = { {
    attackerGuid = hostileGuid, attackerKey = hostileGuid,
    victimGuid = playerGuid, victimKind = "player", interval = 0.2,
    nextSwingIn = 0.1, expectedDamage = 1, generation = 1,
    phaseKnown = true } } } }
local cappedEvents = S:Events(capped, { downtime = 4 })
assert(table.getn(cappedEvents) == S.MAX_EVENTS
    and capped.incomingProjectionPartial
    and not capped.hostileSwings.lanes[1].phaseKnown,
    "the hostile event cap must make an overlong projection explicitly partial")
print("ok: causal estimated hostile white-swing survival timeline")
