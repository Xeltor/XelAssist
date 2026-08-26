table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, hostileGuid = {}, {}
UnitArmor = function() return 100, 100, 100, 0, 0 end
UnitDefense = function() return 20, 0 end
UnitLevel = function() return 10 end
GetShapeshiftForm = function() return 0 end
XelAssist = { Game = { Pets = {} }, Graph = { State = {} } }
dofile("Game/Pets/DefensiveActions.lua")
dofile("Game/Pets/Effects.lua")
dofile("Graph/PlayerRage.lua")
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/WarriorShieldBlock.lua")
dofile("Graph/CompanionDefensives.lua")
dofile("Graph/HostileSwings.lua")
local S = XelAssist.Graph.HostileSwings
local root = { actors = { player = { guid = playerGuid, health = 100,
        healthMax = 100, healthExact = true } },
    resource = 0, resourceMax = 100, resourceType = 1,
    playerLevel = 10, playerResourceExact = true,
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
    and root.resource == 1 and root.lastHostileSwing
    and root.lastHostileSwing.effective == 15
    and root.lastIncomingConsequence.rageGained == 1
    and root.lastHostileSwing.attackerGuid == hostileGuid,
    "one learned post-mitigation swing must reduce recipient health exactly once")
assert(S:Apply(root, events[2]) and root.actors.player.health == 70
    and root.resource == 2,
    "successive projected rounds must each apply once")

local shielded = { actors = { player = { guid = playerGuid, health = 100,
        healthMax = 100, healthExact = true } }, resource = 0,
    resourceMax = 100, resourceType = 1, playerLevel = 10,
    playerResourceExact = true, warriorShieldBlock = { active = true,
        projected = true, attackerKey = hostileGuid,
        baseBlockChance = 0.05, addedBlockChance = 0.75, blockLowerBound = 10,
        expectedCharges = 2, chargeDistribution = { [2] = 1 } } }
assert(S:Apply(shielded, events[1])
    and math.abs(shielded.actors.player.health - 92.5) < 0.000001
    and math.abs(shielded.warriorShieldBlock.expectedCharges - 1.2) < 0.000001
    and shielded.resource == 0,
    "a matching selected-attacker swing must consume expected block charges "
        .. "and apply only bounded residual damage")
local otherSwing = {}
for key, value in pairs(events[1]) do otherSwing[key] = value end
otherSwing.attackerKey = "other"
assert(S:Apply(shielded, otherSwing)
    and math.abs(shielded.actors.player.health - 77.5) < 0.000001
    and math.abs(shielded.warriorShieldBlock.expectedCharges - 1.2) < 0.000001,
    "off-target attackers must receive no invented facing or block prevention")

local petGuid = {}
local petShielded = { actors = { pet = { guid = petGuid, health = 80,
    healthMax = 100, healthExact = true, combatEffects = {
        shellShield = { remaining = 12, incomingDamageMultiplier = 0.5,
            meleeAttackTimeMultiplier = 1.35 } } } } }
local petSwing = { kind = "hostileWhiteSwing", attackerGuid = hostileGuid,
    attackerKey = hostileGuid, victimGuid = petGuid, victimKind = "pet",
    amount = 20, generation = 1 }
assert(S:Apply(petShielded, petSwing)
    and petShielded.actors.pet.health == 70
    and petShielded.lastHostileSwing.effective == 10,
    "an active Shell Shield must halve only the companion's projected swing")

local manaUser = { actors = { player = { guid = playerGuid, health = 100,
        healthMax = 100, healthExact = true } }, resource = 0,
    resourceMax = 100, resourceType = 0, playerLevel = 10,
    playerResourceExact = true }
assert(XelAssist.Graph.IncomingConsequences:ApplyResolvedDamage(
        manaUser, playerGuid, 30, true, "test")
    and manaUser.resource == 0,
    "incoming damage must never manufacture rage for a non-rage user")

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
