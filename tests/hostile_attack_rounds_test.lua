table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, petGuid, partyGuid, hostileGuid, unknownGuid = {}, {}, {}, {}, {}
local units = { player = playerGuid, pet = petGuid, party1 = partyGuid,
    target = hostileGuid }
local armor = { player = 100, pet = 50, party1 = 80 }
UnitExists = function(unit)
    local guid = units[unit]
    return guid ~= nil, guid
end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 1 end
UnitArmor = function(unit)
    local value = armor[unit]
    return value, value, value, 0, 0
end
UnitDefense = function() return 20, 0 end
UnitLevel = function() return 10 end
GetShapeshiftForm = function() return 0 end
GetBlockChance = function() return 5 end
XelAssist = { Game = { Geometry = {
    Observe = function() return { behind = false, source = "UnitXP" } end,
}, Hostiles = {
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
local hostiles = { order = { hostileGuid }, selectedKey = hostileGuid, byKey = {
    [hostileGuid] = { key = hostileGuid, guid = hostileGuid, dead = false },
} }
local actors = { player = { guid = playerGuid }, pet = { guid = petGuid } }
local snapshot = H:Snapshot(hostiles, nil, actors, 8.5)
assert(table.getn(snapshot.lanes) == 1
    and snapshot.lanes[1].attackerGuid == hostileGuid
    and snapshot.lanes[1].victimGuid == playerGuid
    and math.abs(snapshot.lanes[1].interval - 2.05) < 0.001
    and snapshot.lanes[1].expectedDamage == 10
    and snapshot.lanes[1].damageProbability == 0.75
    and snapshot.lanes[1].blockLowerBound == 3
    and snapshot.lanes[1].blockSamples == 1
    and snapshot.playerDefense.exact
    and snapshot.playerDefense.blockChance == 5
    and snapshot.playerDefense.selectedBehindPlayer == false,
    "three clean intervals must expose one opaque, estimated post-mitigation lane")

armor.player = 120
assert(table.getn(H:Snapshot(hostiles, nil, actors, 8.5).lanes) == 0,
    "an armor-regime change must retire stale post-mitigation damage")
armor.player = 100
assert(table.getn(H:Snapshot(hostiles, nil, actors, 8.5).lanes) == 1,
    "the original exact mitigation regime must retain its learned lane")

H:Observe(hostileGuid, playerGuid, 10, 0, 0, 0, 0, 0, 0, 20)
assert(table.getn(H:Snapshot(hostiles, nil, actors, 20.1).lanes) == 0,
    "a dirty cadence gap must withhold the hostile phase")
H:Reset("test")
assert(table.getn(H.lanes) == 0, "world reset must retire every session lane")

local tick
for tick = 1, 4 do
    local at = tick * 2
    assert(H:Observe(hostileGuid, petGuid, 8, 0, 0, 0, 0, 0, 0, at))
    assert(H:Observe(hostileGuid, partyGuid, 12, 0, 0, 0, 0, 0, 0, at))
end
local party = { key = "party", unit = "party1", guid = partyGuid,
    relation = "ally" }
local friendlies = { order = { "party" }, byKey = { party = party } }
local multi = H:Snapshot(hostiles, friendlies, actors, 8.5)
assert(table.getn(multi.lanes) == 2,
    "pet and ally mitigation regimes must retain independent incoming lanes")
armor.pet = 60
multi = H:Snapshot(hostiles, friendlies, actors, 8.5)
assert(table.getn(multi.lanes) == 1 and multi.lanes[1].victimKind == "ally",
    "a pet armor change must not preserve its stale damage or erase an ally lane")
armor.party1 = 90
assert(table.getn(H:Snapshot(hostiles, friendlies, actors, 8.5).lanes) == 0,
    "healer evidence must not project stale ally damage after armor changes")
print("ok: bounded exact-recipient hostile white-round evidence")
