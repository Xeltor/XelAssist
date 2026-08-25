table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Pets = {} } }
dofile("Game/Pets/Actions.lua")
local A = XelAssist.Game.Pets.Actions

local call = { facts = { petLifecycle = "call" } }
local revive = { facts = { petLifecycle = "revive" } }
local dismiss = { facts = { petLifecycle = "dismiss", pet = true } }
local feed = { facts = { itemTarget = true, pet = true, fixedTarget = "pet" } }

local function state(status)
    return { petLifecycle = { lifecycle = status, healthMax = 1000,
        focus = 35, focusMax = 100, lastKnown = { guid = {}, family = "Cat" } } }
end

assert(A:Blocker(call, state("dismissed")) == nil)
assert(A:Blocker(call, state("dead")) == "companion must be revived")
assert(A:Blocker(call, state("unknown")) == "companion lifecycle unknown")
assert(A:Blocker(revive, state("dead")) == nil)
assert(A:Blocker(revive, state("dismissed")) == "companion is dismissed")
assert(A:Blocker(dismiss, state("alive")) == "manual companion dismissal")
assert(A:Blocker(feed, state("alive")) == "compatible pet food not configured")

local unit, relation = A:FixedTarget({ facts = { fixedTarget = "pet" } })
assert(unit == "pet" and relation == "pet")
assert(A:ImplicitTarget(revive) and A:ImplicitTarget(feed))
assert(A:UsabilityBlocker({ facts = { requiresHunterCritical = true } }, nil)
    == "Hunter critical required")

local live = A:MergeLive({ resource = 0, resourceMax = 0 }, {
    lifecycle = "alive", focus = 62, focusMax = 100,
    happiness = 3, damagePercentage = 125, loyaltyText = "Beste vriend",
})
assert(live.resource == 62 and live.resourceMax == 100
    and live.damageMultiplier == 1.25 and live.loyaltyText == "Beste vriend")

local dead = state("dead")
dead.actors, dead.actorReadyAt, dead.time, dead.pet = {}, { player = 10 }, 10, false
local applied = A:ApplyLifecycle(dead, { action = revive })
assert(applied and dead.pet and dead.actors.pet.lifecycle == "alive")
assert(dead.actors.pet.health == 150 and dead.actors.pet.projectedLifecycle == "revive")
assert(dead.actors.pet.guid == dead.petLifecycle.lastKnown.guid,
    "opaque last-known identity must pass through without conversion")

print("ok: conservative Hunter pet lifecycle policy and projected maintenance")
