-- Patch-5 Barkskin must carry its mitigation and opportunity costs together.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end
XelAssist = { Game = { Player = {} }, Graph = {} }

local rows = {
    [22812] = {
        school = 3, attributes = 65536, recoveryTime = 60000,
        durationIndex = 8, powerType = 0, manaCost = 0,
        spellFamilyName = 7, effect = { 6, 6, 6 },
        effectBasePoints = { 99, 0, 999 },
        effectImplicitTargetA = { 1, 0, 1 },
        effectApplyAuraName = { 149, 192, 107 },
        effectTriggerSpell = { 0, 22839, 0 },
    },
    [22839] = {
        school = 3, attributes = 65920, durationIndex = 8,
        effect = { 6, 6, 0 }, effectBasePoints = { -26, -21, 0 },
        effectImplicitTargetA = { 1, 1, 0 },
        effectApplyAuraName = { 138, 87, 0 },
        effectMiscValue = { 0, 1, 0 },
    },
}

function UnitClass()
    return "Druid", "DRUID"
end

function GetSpellRecField(spellId, field, array)
    local value = rows[spellId] and rows[spellId][field]
    if array then return { value[1], value[2], value[3] } end
    return value
end

function GetSpellDuration()
    return 10000
end

local now, aura = 100, nil
function GetTime()
    return now
end
C_UnitAuras = {
    GetPlayerAuraBySpellID = function()
        return aura
    end,
}

dofile("Game/Player/DruidBarkskin.lua")
local Runtime = XelAssist.Game.Player.DruidBarkskin
local facts, reason, handled = Runtime:InferKnowledge(22812)
assert(handled and facts and not reason and facts.kind == "defensive"
    and facts.druidBarkskinEvidence.physicalDamageMultiplier == 0.8
    and facts.druidBarkskinEvidence.nonInstantCastTimeAdded == 1
    and facts.druidBarkskinEvidence.meleeAttackRateMultiplier == 0.75,
    "Barkskin must seal mitigation and both costs")
assert(Runtime:InferKnowledge(22839) == nil,
    "linked aura is not a cast action")

dofile("Graph/DruidBarkskin.lua")
dofile("Graph/HostileWhiteMitigation.lua")
local Graph = XelAssist.Graph.DruidBarkskin
local state = { time = 100, actors = {
    player = { guid = "player-guid" },
} }
assert(Graph:Attach(state, "DRUID"),
    "inactive exact aura root must attach")
local projection = assert(Graph:Prepare({ facts = facts }, state, {
    unit = "player", relation = "self", guid = "player-guid",
}, facts))
local context = { state = state, wait = 0, cast = 0 }
assert(Graph:Score(context, projection) and context.value == 0
    and context.kind == "classMechanic",
    "no invented incoming damage may give flat defensive value")
state.hostileSwings = { lanes = { { victimKind = "player",
    expectedDamage = 20, interval = 2, nextSwingIn = 1 } } }
context = { state = state, wait = 0, cast = 0 }
assert(Graph:Score(context, projection)
    and math.abs(context.value - 20) < 0.000001
    and context.druidBarkskinWhiteRounds == 5 and context.estimated,
    "Barkskin must earn only its exact phase-known white-round prevention")
assert(Graph:Apply(state, { classMechanicProjection = projection }),
    "transition must activate")

local cast, changed = Graph:CastTime(state, 2.5)
assert(changed and cast == 3.5,
    "non-instant casts pay exact one-second cost")
cast, changed = Graph:CastTime(state, 0)
assert(not changed and cast == 0, "instant spells stay instant")
local interval = Graph:MeleeInterval(state, 1.5)
assert(math.abs(interval - 2) < 0.00001,
    "25% melee-rate slow must lengthen rounds")

local amount, why, owned = Graph:AdjustIncoming(
    state, { kind = "player" }, 100, 0)
assert(owned and not why and amount == 80,
    "physical incoming damage is reduced 20%")
amount, why, owned = Graph:AdjustIncoming(
    state, { kind = "player" }, 100, 5)
assert(owned and not why and amount == 100,
    "magic damage is not reduced")
assert(Graph:Advance(state, 10) and state.druidBarkskin.active == false,
    "all consequences expire together")

Runtime:Invalidate()
rows[22839].effectBasePoints = { -26, -11, 0 }
facts, reason, handled = Runtime:InferKnowledge(22812)
assert(handled and not facts
    and reason == "Barkskin patch-5 topology is incomplete",
    "changed installed arithmetic must fail closed")

print("ok: exact patch-5 Barkskin mitigation and opportunity costs")
