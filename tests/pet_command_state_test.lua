table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local clock, health, maximum = 10, 100, 1000
local touches = 0
XelAssist = { Core = { CombatRevision = {
    Touch = function(_, domain)
        assert(domain == "pet")
        touches = touches + 1
    end,
} }, Game = { Pets = {} }, Combat = { PetKnowledge = {
    Facts = function(_, spellId)
        if spellId == 17767 then return { kind = "petHeal", channel = true } end
        return nil
    end,
} } }
GetTime = function() return clock end
UnitHealth = function(unit) assert(unit == "pet"); return health end
UnitHealthMax = function(unit) assert(unit == "pet"); return maximum end

dofile("Game/Pets/CommandState.lua")
local C = XelAssist.Game.Pets.CommandState
local guid = {}

local pet = { guid = guid, health = health, healthMax = maximum,
    targetExists = true, targetsCurrent = true, stance = "defensive",
    attackRound = { attackActive = true, attackActiveKnown = true } }
C:Attach(pet)
assert(pet.recovering and not pet.retreatFollowIssued
    and not pet.retreatPassiveIssued,
    "critical health must enter a fresh recovery episode")

local attack = { executor = "petCommand", command = "attack" }
local follow = { executor = "petCommand", command = "follow" }
local passive = { executor = "petCommand", command = "passive" }
assert(C:LiveBlocker(attack, guid) == "companion is recovering",
    "the final dispatch boundary must reject stale attack plans during recovery")
assert(C:LiveBlocker(follow, guid) == nil)
C:Submitted(guid, "follow")
assert(touches == 1 and C:Pending(guid, "follow"),
    "a protected command must create a short acknowledgement reservation")
assert(C:LiveBlocker(follow, guid) == "companion command awaiting acknowledgement",
    "macro tapping must not replay the same retreat command")

pet.targetExists = true
pet.attackRound.attackActive = false
pet.following, pet.followingKnown = true, true
C:Attach(pet)
assert(pet.retreatFollowIssued and not pet.commandPending.follow,
    "the active Follow token must acknowledge retreat even if pettarget lingers")

C:Submitted(guid, "passive")
pet.stance = "passive"
C:Attach(pet)
assert(pet.retreatPassiveIssued and not pet.commandPending.passive,
    "the active passive stance must acknowledge the protected stance command")

health, pet.health = 349, 349
C:Attach(pet)
assert(pet.recovering,
    "recovery must remain latched above the emergency entry threshold")
health, pet.health = 350, 350
C:Attach(pet)
assert(not pet.recovering and not pet.retreatFollowIssued
    and not pet.retreatPassiveIssued and C:LiveBlocker(attack, guid) == nil,
    "recovery must release only at the safe hysteresis threshold")

health, pet.health = 100, 100
C:Attach(pet)
assert(pet.recovering)
XelAssist.petCastGuid, XelAssist.petCastSpellId = guid, 17767
XelAssist.petCastChannel, XelAssist.petCastUntil = true, clock + 3
assert(C:LiveBlocker(follow, guid) == "companion recovery channel active",
    "a stale retreat plan must not interrupt a newly active recovery channel")
assert(C:LiveBlocker(attack, guid) == "companion recovery channel active",
    "a stale attack plan must not interrupt a newly active recovery channel")
XelAssist.petCastGuid, XelAssist.petCastSpellId = nil, nil
XelAssist.petCastChannel, XelAssist.petCastUntil = nil, nil
C:Submitted(guid, "follow")
clock = clock + 2
assert(not C:Pending(guid, "follow") and C:LiveBlocker(follow, guid) == nil,
    "an unacknowledged retreat must become retryable after bounded backoff")

local nextGuid = {}
local replacement = { guid = nextGuid, health = 1000, healthMax = 1000,
    targetExists = false, targetsCurrent = false, stance = "defensive" }
C:Attach(replacement)
assert(not replacement.recovering,
    "a replacement companion must not inherit the prior pet's recovery latch")

print("ok: companion recovery hysteresis and pet-command acknowledgement")
