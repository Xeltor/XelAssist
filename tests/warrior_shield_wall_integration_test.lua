-- Defensive Stance and Shield Wall must compose once in the production
-- hostile-cast preview used by both scoring and timeline application.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Player = {} }, Graph = {
    State = {}, IncomingAbsorbs = {},
} }

dofile("Game/Player/WarriorStanceEffects.lua")
dofile("Graph/WarriorStances.lua")
dofile("Game/Player/WarriorShieldWall.lua")
dofile("Graph/WarriorShieldWall.lua")
dofile("Graph/IncomingConsequences.lua")

local Incoming = XelAssist.Graph.IncomingConsequences
local ShieldWall = XelAssist.Graph.WarriorShieldWall

local defensive = { exact = true, formID = 18, key = "defensive",
    passiveSpellId = 7376, damageTakenPercent = -10,
    damageTakenMultiplier = 0.9 }
local state = {
    classMechanicClass = "WARRIOR",
    playerForm = { available = true, formID = 18 },
    warriorStanceEffects = { kind = "warriorStanceEffects", available = true,
        byForm = { [18] = defensive } },
    warriorStanceProfile = defensive,
    playerStanceDamageTakenMultiplier = 0.9,
    actors = { player = { guid = "player-guid", health = 500,
        healthMax = 500, healthExact = true } },
    warriorShieldWall = { available = true, exact = true, active = false,
        spellId = 871, schoolMask = 127, damageTakenPercent = -75,
        damageTakenMultiplier = 0.25, duration = 10 },
}
local cast = { remaining = 3, probability = 1, consequence = {
    kind = "damage", amount = 100, school = 2,
    targetGuid = "player-guid", estimated = false } }

local preview, reason = Incoming:Preview(state, cast)
assert(preview and reason == nil and preview.rawAmount == 90
    and preview.amount == 90,
    "Defensive Stance must reduce exact player damage before cooldowns")

state.hostileCasts = { order = { "cast" }, byCaster = { cast = cast } }
local projection = { warriorShieldWallTransition = {
    kind = "warriorShieldWall", evidenceExact = true, spellId = 871,
    schoolMask = 127, damageTakenPercent = -75,
    damageTakenMultiplier = 0.25, duration = 10,
    epoch = "871:test", serverProfileExact = true, runtimeVerified = false,
} }
local score = { state = state, wait = 0, cast = 0 }
assert(ShieldWall:Score(score, projection)
    and score.warriorShieldWallPreventedDamage == 67.5
    and score.value == 67.5,
    "Shield Wall must value only its 75 percent marginal post-stance reduction")

state.warriorShieldWall.active = true
state.warriorShieldWall.remaining = 10
state.warriorShieldWall.epoch = "871:test"
preview, reason = Incoming:Preview(state, cast)
assert(preview and reason == nil and preview.rawAmount == 22.5,
    "Defensive Stance and Shield Wall must compose as 0.9 times 0.25")

state.warriorShieldWall.active = false
state.warriorShieldWall.remaining, state.warriorShieldWall.epoch = nil, nil
state.playerForm.formID = 0
state.warriorStanceProfile = nil
state.playerStanceDamageTakenMultiplier = nil
preview, reason = Incoming:Preview(state, cast)
assert(preview and reason == nil and preview.rawAmount == 100,
    "an exactly observed neutral Warrior form must use multiplier one")

state.playerForm.formID = 18
state.warriorStanceProfile = { exact = true, formID = 17,
    passiveSpellId = 21156, damageTakenMultiplier = 1 }
state.playerStanceDamageTakenMultiplier = 1
preview, reason = Incoming:Preview(state, cast)
assert(preview == nil
    and reason == "exact Warrior stance damage-taken projection unavailable",
    "a stale stance profile must fail hostile damage projection closed")

print("ok: Warrior stance and Shield Wall incoming mitigation compose exactly")
