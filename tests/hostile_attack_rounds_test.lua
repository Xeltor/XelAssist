table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, petGuid, hostileGuid, unknownGuid = {}, {}, {}, {}
local units = { player = playerGuid, pet = petGuid, target = hostileGuid }
UnitExists = function(unit)
    local guid = units[unit]
    return guid ~= nil, guid
end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
XelAssist = { Game = { Hostiles = {
    ProvesGuid = function(_, guid) return guid == hostileGuid end,
} } }
dofile("Game/HostileAttackRounds.lua")
local H = XelAssist.Game.HostileAttackRounds

assert(not H:Observe(playerGuid, playerGuid, 10, 0, 0, 0, 0, 0, 0, 1),
    "owned player rounds must remain in the player ledger")
assert(not H:Observe(unknownGuid, playerGuid, 10, 0, 0, 0, 0, 0, 0, 1),
    "an unproven hostile identity must fail closed")
assert(not H:Observe(hostileGuid, unknownGuid, 10, 0, 0, 0, 0, 0, 0, 1),
    "an unknown victim identity must fail closed")
assert(not H:Observe(hostileGuid, playerGuid, 10, 65536, 0, 0, 0, 0, 0, 1),
    "NOACTION melee-spell packets must not train ordinary white cadence")

assert(H:Observe(hostileGuid, playerGuid, 12, 0, 0, 0, 0, 0, 0, 2))
assert(H:Observe(hostileGuid, playerGuid, 0, 0, 1, 0, 0, 0, 0, 4))
assert(H:Observe(hostileGuid, playerGuid, 18, 0, 0, 0, 3, 0, 0, 6))
assert(H:Observe(hostileGuid, playerGuid, 10, 0, 0, 0, 0, 0, 0, 8))
local hostiles = { order = { hostileGuid }, byKey = {
    [hostileGuid] = { key = hostileGuid, guid = hostileGuid, dead = false },
} }
local actors = { player = { guid = playerGuid }, pet = { guid = petGuid } }
local snapshot = H:Snapshot(hostiles, nil, actors, 8.5)
assert(table.getn(snapshot.lanes) == 1
    and snapshot.lanes[1].attackerGuid == hostileGuid
    and snapshot.lanes[1].victimGuid == playerGuid
    and math.abs(snapshot.lanes[1].interval - 2.05) < 0.001
    and snapshot.lanes[1].expectedDamage == 10,
    "three clean intervals must expose one opaque, estimated post-mitigation lane")

H:Observe(hostileGuid, playerGuid, 10, 0, 0, 0, 0, 0, 0, 20)
assert(table.getn(H:Snapshot(hostiles, nil, actors, 20.1).lanes) == 0,
    "a dirty cadence gap must withhold the hostile phase")
H:Reset("test")
assert(table.getn(H.lanes) == 0, "world reset must retire every session lane")
print("ok: bounded exact-recipient hostile white-round evidence")
