XelAssist = { Graph = {} }
table.getn = table.getn or function(value) return #value end
dofile("Graph/PushbackProjection.lua")
local P = XelAssist.Graph.PushbackProjection

local classes = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST",
    "SHAMAN", "WARLOCK" }
local function context(class, cast)
    return { action = { actor = "player" }, facts = { kind = "damage" },
        cast = cast or 2.5, wait = 0, occupancy = cast or 2.5,
        downtime = cast or 2.5, advanceDowntime = cast or 2.5,
        state = { class = class, time = 0, inCombat = true,
            hostileSwings = { playerPushback = { available = true,
                meanDelay = 0.5, maximumDelay = 0.75, samples = 4 },
                lanes = { { phaseKnown = true,
                victimKind = "player", interval = 2, nextSwingIn = 1,
                expectedDamage = 10, damageProbability = 0.5 } } } } }
end

for i = 1, table.getn(classes) do
    local cast = context(classes[i])
    assert(P:Adjust(cast) and cast.cast == 2.75
        and cast.pushbackProjection.events == 1
        and cast.pushbackProjection.extension == 0.25,
        classes[i] .. " casts must share evidence-driven pushback timing")
end

local iterative = context("MAGE", 4.2)
iterative.state.hostileSwings.lanes[1].damageProbability = 1
assert(P:Adjust(iterative) and iterative.cast == 5.7
    and iterative.pushbackProjection.events == 3,
    "each projected delay must admit a later phase-known hostile round")

local channel = context("PRIEST")
channel.facts.channel = true
assert(not P:Adjust(channel) and channel.cast == 2.5,
    "channels use their exact shortening lane and must not be extended")
local immune = context("DRUID")
immune.state.druidBarkskin = { available = true, exact = true, active = true,
    remaining = 8, pushbackImmune = true }
assert(not P:Adjust(immune), "exact Barkskin immunity must suppress pushback")
local outOfCombat = context("MAGE")
outOfCombat.state.inCombat = false
assert(not P:Adjust(outOfCombat), "future hostile rounds require combat")
local pet = context("WARLOCK")
pet.action.actor = "pet"
assert(not P:Adjust(pet), "player evidence must not alter pet casts")
local unknown = context("SHAMAN")
unknown.state.hostileSwings.lanes[1].damageProbability = nil
assert(not P:Adjust(unknown),
    "unknown damaging-hit probability must not manufacture cast delay")

print("ok: hostile rounds extend ordinary caster actions without channels")
