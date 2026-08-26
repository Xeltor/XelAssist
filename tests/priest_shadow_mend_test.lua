XelAssist = { Graph = {} }
table.getn = table.getn or function(value) return #value end
XelAssist.Graph.State = {}
function XelAssist.Graph.State:FriendlyByUnit(state, unit)
    return state.friendlies and state.friendlies[unit] or nil
end
XelAssist.Graph.HostileCastEvents = {}
function XelAssist.Graph.HostileCastEvents:IncomingDamage(state)
    return state.incoming or 0, state.incomingExact ~= false
end

dofile("Graph/PriestShadowMend.lua")
local Mend = XelAssist.Graph.PriestShadowMend

local function state(health, incoming)
    local player = { guid = "player-guid", unit = "player",
        health = health, healthMax = 1000, healthExact = true }
    return { health = health, healthMax = 1000, incoming = incoming or 0,
        incomingExact = true, friendlies = { player = player },
        actors = { player = { guid = "player-guid", health = health } } }, player
end

local function context(current, recipient)
    return { state = current, descriptor = recipient,
        facts = { shadowMend = true, shadowMendSelfDamageRatio = 0.5 },
        tooltip = { low = 800, high = 900 }, power = 850,
        wait = 0, cast = 2.5, value = 2000, effectivePower = 700 }
end

local allyState, player = state(1000, 50)
local ally = { guid = "ally-guid", unit = "party1", health = 100,
    healthMax = 1000, healthExact = true }
local allyContext = context(allyState,
    { key = "ally-guid", guid = "ally-guid", unit = "party1", record = ally })
local prepared, reason = Mend:Prepare(allyContext)
assert(prepared and not reason and allyContext.shadowMend.expectedSelfDamage == 425
    and allyContext.shadowMend.maximumSelfDamage == 450
    and not allyContext.shadowMend.selfTarget,
    "ally Shadow Mend must seal mean projection and maximum-roll safety")
Mend:Score(allyContext)
assert(allyContext.value < 2000
    and allyContext.reason == "heals an ally with a safe self-damage cost",
    "ally healing must pay caster-health opportunity and survival risk")
Mend:Apply(allyState, { shadowMend = allyContext.shadowMend })
assert(player.health == 575 and allyState.health == 575
    and allyState.actors.player.health == 575,
    "ally healing must debit the player across canonical graph aliases")

local selfState, selfRecord = state(1000)
local selfContext = context(selfState,
    { key = "player-guid", guid = "player-guid", unit = "player",
        record = selfRecord })
assert(Mend:Prepare(selfContext))
Mend:Score(selfContext)
assert(selfContext.shadowMend.selfTarget and selfContext.effectivePower == 275,
    "self Shadow Mend must value only healing net of self-damage")
selfRecord.health = math.min(selfRecord.healthMax, selfRecord.health + 850)
Mend:Apply(selfState, { shadowMend = selfContext.shadowMend })
assert(selfRecord.health == 575,
    "self healing transition must heal first and then apply its health cost")

local emergencyState, emergencyRecord = state(200)
local emergency = context(emergencyState,
    { key = "player-guid", guid = "player-guid", unit = "player",
        record = emergencyRecord })
prepared, reason = Mend:Prepare(emergency)
assert(prepared and not reason and emergency.shadowMend.minimumPostHealth == 550,
    "heal-before-cost ordering must admit a provably safe emergency self-cast")

local lethal = state(500, 60)
prepared, reason = Mend:Prepare(context(lethal,
    { guid = "ally-guid", unit = "party1" }))
assert(not prepared and reason == "Shadow Mend could defeat the caster",
    "maximum heal roll plus known incoming damage must guard lethality")

local missing = context(state(1000), { guid = "ally-guid", unit = "party1" })
missing.tooltip.high = nil
prepared, reason = Mend:Prepare(missing)
assert(not prepared and reason == "Shadow Mend live heal range unavailable",
    "missing live maximum heal evidence must fail closed")

local uncertainState = state(1000)
uncertainState.incomingExact = false
prepared, reason = Mend:Prepare(context(uncertainState,
    { guid = "ally-guid", unit = "party1" }))
assert(not prepared
    and reason == "Shadow Mend incoming caster damage unavailable",
    "uncertain landing damage must fail closed")

print("ok: exact Shadow Mend safety, score and graph health transfer")
