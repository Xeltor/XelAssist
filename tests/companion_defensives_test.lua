XelAssist = { Game = { Pets = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Game/Pets/DefensiveActions.lua")
dofile("Game/Pets/Effects.lua")
dofile("Graph/CompanionDefensives.lua")
local D = XelAssist.Graph.CompanionDefensives
local E = XelAssist.Game.Pets.Effects

local facts = { kind = "petDefensive",
    petDefensiveProfile = { exact = true, kind = "shellShield",
        spellId = 26064, duration = 12, incomingDamageMultiplier = 0.5,
        meleeAttackTimeMultiplier = 1.35, offensiveTimingExact = false },
    petCombatEffects = { { key = "shellShield", duration = 12,
        incomingDamageMultiplier = 0.5, meleeAttackTimeMultiplier = 1.35,
        offensiveTimingExact = false, sourceSpellId = 26064 } } }
local petGuid = {}
local state = { actors = { pet = { guid = petGuid, combatEffects = {},
    attackRound = { phaseExact = true, projectable = true } } } }
local ambient = { name = "Shell Shield", spellId = 26064,
    facts = facts, tooltip = { duration = 12 } }
assert(D:Apply(state, ambient, {})
    and E:IncomingDamageMultiplier(state.actors.pet) == 0.5
    and state.actors.pet.defensiveOffenseTimingUnknown
    and state.actors.pet.attackRound.projectable == false
    and state.actors.pet.attackRound.reason == "companion defensive attack timing"
    and state.companionDefensiveTimingUnknown,
    "Shell Shield must install exact mitigation and retain its offense unknown")
assert(D:AdjustIncoming(state,
        { victimKind = "pet", victimGuid = petGuid }, 40) == 20
    and D:AdjustIncoming(state,
        { victimKind = "player", victimGuid = {} }, 40) == 40
    and D:AdjustIncoming(state,
        { victimKind = "pet", victimGuid = {} }, 40) == 40,
    "Shell Shield mitigation must remain on the exact companion recipient")
E:Advance(state, 6)
assert(E:IncomingDamageMultiplier(state.actors.pet) == 0.5,
    "Shell Shield must remain active inside its exact duration")
E:Advance(state, 6)
assert(E:IncomingDamageMultiplier(state.actors.pet) == 1,
    "Shell Shield must expire on the shared companion effect clock")

print("ok: exact target-local companion defensive mitigation")
