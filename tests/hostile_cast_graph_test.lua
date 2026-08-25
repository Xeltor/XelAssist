table.getn = table.getn or function(value) return #value end

XelAssist = { Game = {}, Graph = {} }
local observed = {
    { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 100,
        generation = 1, remaining = 2, active = true, source = "test" },
}
XelAssist.Game.HostileCasts = {
    Snapshot = function() return observed end,
}
XelAssist.Game.HostileSpellFacts = {
    ForCast = function(_, cast, level)
        assert(level == 10, "retained hostile level must seed DBC facts")
        if cast.spellId == 100 then
            return { kind = "damage", targetMode = "target", amount = 40,
                estimated = true, targetGuid = cast.targetGuid }
        end
        return { kind = "heal", targetMode = "target", amount = 40,
            estimated = true, targetGuid = cast.targetGuid }
    end,
}
XelAssist.Graph.State = {
    RefreshHostileRecord = function(_, state, key)
        local selected = state.hostiles and state.hostiles.selectedKey
        local record = state.hostiles and state.hostiles.byKey[key]
        if record and selected == key then
            state.targetCasting = record.casting
            state.targetCastRemaining = record.castRemaining
            state.targetCastProbability = record.castProbability
            state.targetHealth = record.health
        end
    end,
    SyncActiveHostile = function(self, state)
        return self:RefreshHostileRecord(state, state.hostiles.selectedKey)
    end,
}

dofile("Graph/HostileCastState.lua")
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/HostileCastEvents.lua")

local CastState = XelAssist.Graph.HostileCastState
local Incoming = XelAssist.Graph.IncomingConsequences
local Events = XelAssist.Graph.HostileCastEvents

local function friendly(key, guid, health, maximum)
    return { key = key, guid = guid, health = health, healthMax = maximum,
        exact = true, absorbs = { available = false }, auras = {} }
end

local function state()
    local player = friendly("player-key", "player-a", 100, 100)
    local pet = friendly("pet-key", "pet-a", 80, 100)
    local ally = friendly("ally-key", "ally-a", 60, 100)
    local caster = { key = "enemy-a", guid = "enemy-a", health = 100,
        healthMax = 100, healthExact = true, encounter = { level = 10 } }
    local healer = { key = "enemy-b", guid = "enemy-b", health = 100,
        healthMax = 100, healthExact = true, encounter = { level = 10 } }
    return { time = 0, health = 100, healthMax = 100, absorbs = {},
        actors = { player = { guid = "player-a", health = 100,
                healthMax = 100 },
            pet = { guid = "pet-a", health = 80, healthMax = 100 } },
        friendlies = { order = { "player-key", "pet-key", "ally-key" },
            primaryKey = "player-key", byKey = { ["player-key"] = player,
                ["pet-key"] = pet, ["ally-key"] = ally } },
        hostiles = { order = { "enemy-a", "enemy-b" },
            selectedKey = "enemy-a", byKey = { ["enemy-a"] = caster,
                ["enemy-b"] = healer } },
        targetGUID = "enemy-a", targetHealth = 100,
        targetCasting = false, targetCastRemaining = 0 }
end

local attached = state()
CastState:Attach(attached, 0)
local cast = CastState:Find(attached, "enemy-a")
assert(cast and cast.consequence.amount == 40
    and attached.hostiles.byKey["enemy-a"].casting
    and attached.targetCastRemaining == 2,
    "ledger casts must become exact target-local graph state")

local copied = CastState:Copy(attached.hostileCasts)
copied.byCaster["enemy-a"].remaining = 1
copied.byCaster["enemy-a"].consequence.amount = 99
assert(cast.remaining == 2 and cast.consequence.amount == 40,
    "graph branch copies must isolate cast clocks and consequences")

assert(table.getn(Events:Events(attached, { downtime = 1 })) == 0
    and Events:Events(attached, { downtime = 2 })[1].priority == 15,
    "hostile completion must enter only a reaching window before the action")
CastState:Advance(attached, 1)
assert(cast.remaining == 1 and attached.targetCastRemaining == 1,
    "hostile clocks must advance causally with graph time")

attached.friendlies.byKey["player-key"].absorbs.Shield = {
    amount = 10, applicationProbability = 1 }
local result = assert(Events:Apply(attached, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 1 }))
assert(result.effective == 30 and result.absorbed == 10 and result.partial
    and attached.health == 70
    and attached.actors.player.health == 70
    and attached.actors.player.healthExact == false
    and attached.friendlies.byKey["player-key"].health == 70
    and attached.friendlies.byKey["player-key"].exact == false
    and not CastState:Find(attached, "enemy-a")
    and not attached.targetCasting,
    "estimated incoming damage must consume known shields, mark recipient views partial, and retire")

local probabilistic = state()
local probabilisticPlayer = probabilistic.friendlies.byKey["player-key"]
probabilisticPlayer.absorbs = { available = true, Shield = {
    amount = 50, applicationProbability = 1 } }
probabilistic.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 20, remaining = 0, probability = 0.5,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 100, estimated = false } } } }
result = assert(Events:Apply(probabilistic, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 20 }))
assert(result.amount == 50 and result.absorbed == 25
    and result.effective == 25 and result.partial
    and probabilistic.health == 75
    and probabilisticPlayer.absorbs.Shield.amount == 50
    and probabilisticPlayer.absorbs.Shield.applicationProbability == 0.5
    and probabilisticPlayer.exact == false,
    "a probabilistic impact must retain the no-hit shield branch and correlated expected damage")
probabilistic.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 27, remaining = 0, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 40, estimated = false } } } }
result = assert(Events:Apply(probabilistic, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 27 }))
assert(result.effective == 20 and result.absorbed == 20
    and probabilistic.health == 55
    and probabilisticPlayer.absorbs.Shield.amount == 10
    and probabilisticPlayer.absorbs.Shield.applicationProbability == 0.5,
    "later damage must consume the correlated shield branch instead of a certain half shield")

local estimatedLethal = state()
local estimatedPlayer = estimatedLethal.friendlies.byKey["player-key"]
estimatedPlayer.health, estimatedLethal.actors.player.health = 40, 40
estimatedPlayer.absorbs = { available = true }
estimatedLethal.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 21, remaining = 0, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 80, estimated = true } } } }
local estimatedCast = CastState:Find(estimatedLethal, "enemy-a")
local estimatedValue, estimatedReason = Incoming:PreventedValue(
    estimatedLethal, estimatedCast)
assert(estimatedValue > 0 and estimatedReason == "prevents incoming damage",
    "an estimated magnitude must never receive the exact-lethal interrupt bonus")
result = assert(Events:Apply(estimatedLethal, {
    kind = "hostileCastImpact", casterGuid = "enemy-a", generation = 21 }))
assert(result.partial and estimatedLethal.health == 0
    and estimatedPlayer.exact == false and estimatedPlayer.dead == nil
    and estimatedLethal.actors.player.dead == nil,
    "an estimated lethal mean must make health partial without asserting death")

local cappedPlayer = state()
cappedPlayer.friendlies = { order = {}, byKey = {} }
cappedPlayer.actors.player.healthExact = true
cappedPlayer.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 22, remaining = 0, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 20, estimated = false } } } }
result = assert(Events:Apply(cappedPlayer, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 22 }))
assert(result.partial and cappedPlayer.health == 80
    and cappedPlayer.actors.player.healthExact == false,
    "actor-only player resolution must keep capped live-absorb state unknown")

local stale = state()
stale.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 2, remaining = 1, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 20 } } } }
assert(Events:Apply(stale, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 1 }) == nil
    and CastState:Find(stale, "enemy-a", 2),
    "a stale completion must never clear or deliver a replacement cast")

local healing = state()
healing.hostiles.byKey["enemy-a"].health = 50
healing.hostileCasts = { order = { "enemy-b" }, byCaster = {
    ["enemy-b"] = { casterGuid = "enemy-b", targetGuid = "enemy-a",
        generation = 3, remaining = 0, probability = 1,
        consequence = { kind = "heal", targetMode = "target",
            targetGuid = "enemy-a", amount = 40, estimated = true } } } }
result = assert(Events:Apply(healing, { kind = "hostileCastImpact",
    casterGuid = "enemy-b", generation = 3 }))
assert(result.effective == 40 and result.partial
    and healing.hostiles.byKey["enemy-a"].health == 90
    and healing.hostiles.byKey["enemy-a"].healthExact == false
    and healing.targetHealth == 90,
    "estimated hostile healing must remain local while making health partial")

local death = state()
death.hostiles.byKey["enemy-a"].health = 20
death.hostileCasts = { order = { "enemy-b" }, byCaster = {
    ["enemy-b"] = { casterGuid = "enemy-b", targetGuid = "enemy-a",
        generation = 23, remaining = 0, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "enemy-a", amount = 20, estimated = false } } } }
assert(Events:Apply(death, { kind = "hostileCastImpact",
    casterGuid = "enemy-b", generation = 23 }))
local deathTarget = death.hostiles.byKey["enemy-a"]
assert(deathTarget.dead and deathTarget.projectedDefeated
    and deathTarget.healthExact,
    "an exact hostile consequence must set coherent death state")
death.hostileCasts = { order = { "enemy-b" }, byCaster = {
    ["enemy-b"] = { casterGuid = "enemy-b", targetGuid = "enemy-a",
        generation = 24, remaining = 0, probability = 1,
        consequence = { kind = "heal", targetMode = "target",
            targetGuid = "enemy-a", amount = 10, estimated = false } } } }
assert(Events:Apply(death, { kind = "hostileCastImpact",
    casterGuid = "enemy-b", generation = 24 }))
assert(deathTarget.health == 10 and deathTarget.dead == false
    and deathTarget.projectedDefeated == nil and deathTarget.healthExact,
    "an exact heal above zero must clear stale hostile death state")

local friendlyDeath = state()
local friendlyTarget = friendlyDeath.friendlies.byKey["player-key"]
friendlyTarget.health, friendlyDeath.actors.player.health = 20, 20
friendlyTarget.absorbs = { available = true }
friendlyDeath.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 25, remaining = 0, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-a", amount = 20, estimated = false } } } }
assert(Events:Apply(friendlyDeath, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 25 }))
assert(friendlyTarget.dead and friendlyTarget.projectedDefeated
    and friendlyDeath.actors.player.dead,
    "exact friendly death must be synchronized to its actor view")
friendlyDeath.hostileCasts = { order = { "enemy-a" }, byCaster = {
    ["enemy-a"] = { casterGuid = "enemy-a", targetGuid = "player-a",
        generation = 26, remaining = 0, probability = 1,
        consequence = { kind = "heal", targetMode = "target",
            targetGuid = "player-a", amount = 10, estimated = false } } } }
assert(Events:Apply(friendlyDeath, { kind = "hostileCastImpact",
    casterGuid = "enemy-a", generation = 26 }))
assert(friendlyTarget.health == 10 and friendlyTarget.dead == false
    and friendlyTarget.projectedDefeated == nil
    and friendlyDeath.actors.player.dead == false,
    "exact friendly healing must clear death state on both synchronized views")

local interrupt = state()
CastState:Attach(interrupt, 0)
local context = { state = interrupt, descriptor = { guid = "enemy-a" },
    wait = 0, cast = 0, effectDelivery = 1 }
local value, reason, handled = Events:InterruptValue(context)
assert(handled and value > 0 and reason == "prevents incoming damage",
    "interrupt value must derive from the prevented exact consequence")
context.wait = 2
value, reason = Events:InterruptValue(context)
assert(value == -1200 and reason == "cast resolves before the interrupt",
    "an exact-deadline interrupt must lose to the incoming consequence")
context.wait = 0
assert(Events:Interrupt(interrupt, { targetGUID = "enemy-a",
        effectDelivery = 1 }, { kind = "interrupt" })
    and not CastState:Find(interrupt, "enemy-a"),
    "a fully delivered interrupt must retire its exact generation")

local partial = state()
CastState:Attach(partial, 0)
Events:Interrupt(partial, { targetGUID = "enemy-a", effectDelivery = 0.5 },
    { interrupt = true })
assert(math.abs(CastState:Find(partial, "enemy-a").probability - 0.5) < 0.001
    and Events:IncomingDamage(partial, "player-a", 2) == 20,
    "partial interrupt delivery must preserve a proportional consequence branch")

print("ok: target-local hostile cast graph consequences")
