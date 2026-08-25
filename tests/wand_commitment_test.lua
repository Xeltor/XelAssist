table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local appliedDamage = 0
XelAssist = {
    Game = { Actors = { Facts = function(_, action) return action.mock end } },
    Combat = { Resistance = nil },
    Graph = {
        State = {}, Effects = {},
        HostileEffects = { ApplySelectedDamage = function(_, state, damage)
            appliedDamage = appliedDamage + damage
            state.targetHealth = math.max(0, state.targetHealth - damage)
            if state.targetHealth <= 0 then state.hostile = false end
            return true, damage
        end },
    },
}
dofile("Graph/WandCommitment.lua")
local W = XelAssist.Graph.WandCommitment
local shoot = { name = "Shoot", actor = "player", facts = {
    kind = "autoRepeat", autoRepeat = true, wandRepeat = true },
    mock = { cost = 0, cast = 0, gcd = 0, minRange = 0, maxRange = 30 } }
local state = { hostile = true, targetGUID = "target-guid",
    targetHealth = 100, targetHealthExact = true,
    targetDistance = 20,
    resource = 10, resourceMax = 100,
    wand = { active = true, activeKnown = true,
        targetGuid = "target-guid", damage = 12, speed = 2,
        nextShotIn = 0.4 } }
W:Prepare(state, { shoot })
local candidate = W:Candidate(state)
assert(candidate and candidate.action.facts.wandContinuation
    and candidate.action.executor == "instruction"
    and candidate.wait == 0.4 and candidate.power == 12
    and candidate.value > 0,
    "an active matching wand must become one non-executable continuation branch")
local starvedValue = candidate.value
state.resource = state.resourceMax
assert(W:Candidate(state).value == starvedValue,
    "each wand impact must earn damage value once, not farm missing-mana value")
state.resource = 10

state.targetHealth = 12
local lethal = W:Candidate(state)
assert(lethal and lethal.value == candidate.value + 700
    and lethal.reason == "finishes the target with the next wand shot",
    "an imminent lethal wand impact must retain its terminal value")
state.targetHealth = 100

local out = { hostile = true, targetHealth = 100,
    wand = { active = true, activeKnown = true, speed = 2,
        nextShotIn = 0 } }
assert(W:Apply(out, candidate) and out.targetHealth == 88
    and appliedDamage == 12 and out.wand.nextShotIn == 2,
    "a continuation must project one resolved swing and the next repeat clock")
W:Advance(out, 0.5)
assert(out.wand.nextShotIn == 1.5,
    "independent graph time must advance the sustained wand clock")

W:AfterAction(out, { action = { actor = "pet", facts = {} } })
assert(out.wand.active, "an independently commanded pet must not clip wanding")
W:AfterAction(out, { action = { actor = "player", facts = {
    kind = "damage" } } })
assert(not out.wand.active and out.wand.activeKnown,
    "another player action must project cancellation of the wand repeat")
state.wand.targetGuid = "other-guid"
assert(W:Candidate(state) == nil,
    "a wand repeat cannot migrate to a different graph target")
state.wand.targetGuid = "target-guid"
state.moving = true
assert(W:Candidate(state) == nil,
    "movement must not project a wand impact from a stale repeat flag")
state.moving, state.targetDistance = false, 31
assert(W:Candidate(state) == nil,
    "an active wand outside its exact range must not project damage")
state.targetDistance = nil
assert(W:Candidate(state) == nil,
    "unknown exact wand range must not become a guaranteed future impact")
print("ok: sustained wand continuation and weighted clipping")
