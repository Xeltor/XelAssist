XelAssist = { Game = { Player = {} }, Graph = {} }
if not table.getn then table.getn = function(entries)
    local count = 0
    while entries[count + 1] ~= nil do count = count + 1 end
    return count
end end
local roots = { [15270] = 20, [15335] = 40, [15336] = 60,
    [15337] = 80, [15338] = 100 }
local function triple(a, b, c) return { a, b, c } end
GetSpellRecField = function(id, field, array)
    if id == 15271 then
        local child = { effect = triple(6, 6, 0),
            effectApplyAuraName = triple(137, 134, 0),
            effectBasePoints = triple(99, 49, 0),
            effectMiscValue = triple(4, 0, 0),
            effectImplicitTargetA = triple(1, 1, 0) }
        return child[field]
    end
    if roots[id] then
        local root = { attributes = 464, procFlags = 65538,
            procChance = roots[id], effect = triple(6, 0, 0),
            effectApplyAuraName = triple(42, 0, 0),
            effectTriggerSpell = triple(15271, 0, 0) }
        return root[field]
    end
end
GetSpellDuration = function(id) return id == 15271 and 15000 or nil end
IsPlayerSpell = function(id) return id == 15337 end
GetTime = function() return 100 end
C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
    assert(id == 15271, "the colliding 42003 aura must never be projected")
    return { spellId = 15271, isHelpful = true, duration = 15,
        expirationTime = 110 }
end }
dofile("Game/Player/PriestSpiritTap.lua")
local Runtime = XelAssist.Game.Player.PriestSpiritTap
local observed = Runtime:Snapshot({ time = 0 }, "PRIEST")
assert(observed.available and observed.exact and observed.active
    and observed.rank == 4 and observed.procChance == 0.8
    and observed.remaining == 10 and observed.expiresAt == 10,
    "exact rank and active Spirit Tap aura were not sealed")

XelAssist.Game.SoulShards = { TargetEligibility = function(_, _, _, evidence)
    return evidence and evidence.eligible == true
end }
XelAssist.Graph.State = { HostileByKey = function(_, state, key)
    return state.hostiles and state.hostiles.byKey[key]
end }
XelAssist.Graph.RootObservation = { Target = function(_, _, descriptor)
    return { eligible = descriptor.key ~= "gray" }, "known"
end }
dofile("Graph/PriestSpiritTap.lua")
dofile("Graph/PlayerKillConsequences.lua")
local Tap, Kills = XelAssist.Graph.PriestSpiritTap,
    XelAssist.Graph.PlayerKillConsequences
local state = { time = 2, targetHealthExact = true, targetHealth = 20,
    targetGUID = "enemy", hostiles = { order = { "enemy", "gray" }, byKey = {
        enemy = { guid = "enemy", health = 20, healthExact = true },
        gray = { guid = "gray", health = 20, healthExact = true },
    } }, playerResourceClock = { phaseKnown = true, nextIn = 1 } }
Tap:Attach(state, observed)
state.priestSpiritTap.active, state.priestSpiritTap.expiresAt = false, nil
local action = { actor = "player", facts = { kind = "damage" } }
local candidate = { action = action, targetKey = "enemy", targetGUID = "enemy" }
local event = { owner = "action", kind = "chosenAction", targetKey = "enemy" }
local before = Kills:Capture(state, candidate, event)
assert(Kills:Resolve(state, candidate, event, before) == 0,
    "ordinary or unsealed-critical Mind Blast damage must not invent a proc")
state.hostiles.byKey.enemy.health = 0
assert(Kills:Resolve(state, candidate, event, before) == 1
    and state.priestSpiritTap.active
    and math.abs(state.priestSpiritTap.applicationProbability - 0.8) < 0.0001
    and state.priestSpiritTap.expiresAt == 17
    and not state.playerResourceClock.phaseKnown,
    "exact player lethal did not create its rank-weighted branch")
assert(Kills:Resolve(state, candidate, event, before) == 0,
    "one dead target must not proc Spirit Tap twice")

state.hostiles.byKey.gray.health = 0
state.priestSpiritTap.active = false
local grayBefore = { gray = { key = "gray", guid = "gray", health = 20 } }
assert(Kills:Resolve(state, candidate, event, grayBefore) == 0
    and not state.priestSpiritTap.active,
    "an ineligible target must not generate Spirit Tap")
state.hostiles.byKey.enemy.health = 20
local petEvent = { owner = "ongoing", kind = "petWhiteSwing", targetKey = "enemy" }
assert(Kills:Capture(state, candidate, petEvent) == nil,
    "pet damage must not be mistaken for a player killing blow")
local periodic = { owner = "ongoing", kind = "periodicTick",
    targetKey = "enemy", aura = { periodicThreatActor = "player" } }
assert(Kills:Capture(state, candidate, periodic).enemy,
    "player periodic damage must enter the kill consequence boundary")
periodic.aura.periodicThreatActor = "pet"
assert(Kills:Capture(state, candidate, periodic) == nil,
    "pet periodic damage must not generate Spirit Tap")

dofile("Game/Player/Resources.lua")
local Resources = XelAssist.Game.Player.Resources
local mana = { time = 0, resourceType = 0, resource = 0, resourceMax = 100,
    playerResourceClock = { verified = true, phaseKnown = true,
        externalEnergizeExcluded = true, resourceType = 0,
        amount = 10, interval = 2, nextIn = 1,
        spiritTapEpoch = "live", spiritTapExpiresAt = 2.5 },
    priestSpiritTap = { available = true, exact = true, active = true,
        epoch = "live", expiresAt = 2.5 } }
Resources:Advance(mana, 5)
assert(mana.resource == 10 and not mana.playerResourceClock.phaseKnown
    and mana.playerResourceClock.nextIn == nil,
    "an active-regime mana clock must stop exactly at Spirit Tap expiry")

print("ok: exact Spirit Tap rank, kill ownership and bounded mana lifecycle")
