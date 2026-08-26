XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Graph/HealingTriage.lua")
local Triage = XelAssist.Graph.HealingTriage

local function heal(key, power, cost, cast, gcd)
    return { actionKey = key, kind = "heal", delivery = "direct",
        actor = "player", power = power, cost = cost, cast = cast,
        wait = 0, gcd = gcd or 1.5, powerKnown = true,
        guaranteedPower = power, guaranteedPowerKnown = true,
        costKnown = true, timingKnown = true }
end

local function hit(id, guid, at, damage)
    return { id = id, kind = "damage", recipientGUID = guid,
        at = at, damage = damage, exact = true, frozen = true,
        probability = 1 }
end

local function recipient(key, health, maximum, healthAt, incoming)
    return { key = key, guid = key .. "-guid", health = health,
        healthMax = maximum, healthAt = healthAt, healthExact = true,
        incomingKnown = true, incomingFrozen = true,
        incoming = incoming or {} }
end

local state = { time = 4, resource = 300, resourceMax = 1000,
    playerResourceExact = true }
local action = heal("direct-1", 300, 100, 1.5, 2)
action.wait = 0.5
local target = recipient("party1", 600, 1000, 4, {})
target.incoming = {
    hit("later", target.guid, 7, 600),
    hit("before-land", target.guid, 5, 250),
}

local plan, reason = Triage:Score(action, target, state)
assert(plan and reason == nil and plan.startsAt == 4.5
    and plan.landsAt == 6 and plan.readyAt == 6.5
    and plan.occupancy == 2.5 and plan.landingHealth == 350,
    "wait, cast completion and GCD completion need distinct graph times")
assert(plan.effectiveHealing == 300 and plan.overheal == 0
    and plan.projectedHealth == 50 and plan.savesRecipient
    and plan.stabilizingHealing == 251,
    "only frozen damage delivered before each boundary may affect survival")
assert(plan.healingThreat == 150 and plan.healingThreatActor == "player",
    "only effective healing may cause base healing threat")

local ranged = heal("random-heal", 300, 100, 0, 1.5)
ranged.guaranteedPower = 100
local rangeTarget = recipient("range-target", 100, 1000, 4, {})
rangeTarget.incoming = { hit("range-hit", rangeTarget.guid, 5, 250) }
local rangedPlan = Triage:Score(ranged, rangeTarget, state)
assert(rangedPlan and rangedPlan.effectiveHealing == 300
    and rangedPlan.guaranteedHealing == 100
    and rangedPlan.projectedHealth == 150
    and rangedPlan.guaranteedProjectedHealth == 0
    and not rangedPlan.savesRecipient and rangedPlan.deathSaveUnproven,
    "expected healing may be valued but a low roll cannot prove a death save")
local unknownMinimum = heal("unknown-minimum", 300, 100, 0, 1.5)
unknownMinimum.guaranteedPower, unknownMinimum.guaranteedPowerKnown = nil, false
local unknownPlan = Triage:Score(unknownMinimum, rangeTarget, state)
assert(unknownPlan and unknownPlan.guaranteedHealing == nil
    and not unknownPlan.savesRecipient and unknownPlan.deathSaveUnproven,
    "unknown minimum healing must withhold only the proven-save claim")

action.power, action.healingThreatFactor = 9999, 9
target.health, target.incoming[1].damage = 1, 9999
assert(plan.rawHealing == 300 and plan.healingThreat == 150
    and plan.projectedHealth == 50,
    "a candidate plan must not retain mutable capture tables")

local sameTime = recipient("same-time", 300, 1000, 4, {})
sameTime.incoming = { hit("landing-hit", sameTime.guid, 5.5, 300) }
local instant = heal("instant", 300, 50, 0, 1.5)
instant.wait = 1.5
local rejected, rejectedReason = Triage:Score(instant, sameTime, state)
assert(rejected == nil and rejectedReason == "recipient dies before heal lands",
    "unresolved damage at the landing timestamp must resolve before the heal")

local wrong = recipient("wrong", 400, 1000, 4, {})
wrong.incoming = { hit("replacement", "new-guid", 5, 100) }
rejected, rejectedReason = Triage:Score(instant, wrong, state)
assert(rejected == nil
    and rejectedReason == "incoming event evidence unavailable",
    "incoming events must stay pinned to the captured recipient identity")

local uncertain = recipient("uncertain", 400, 1000, 4, {})
uncertain.incoming = { hit("uncertain", uncertain.guid, 5, 100) }
uncertain.incoming[1].probability = 0.5
rejected, rejectedReason = Triage:Score(instant, uncertain, state)
assert(rejected == nil
    and rejectedReason == "incoming event evidence unavailable",
    "probabilistic future damage cannot fabricate a certain death save")

local stale = recipient("stale", 400, 1000, 4, {})
stale.incoming = { hit("already-reflected", stale.guid, 3, 100) }
rejected, rejectedReason = Triage:Score(instant, stale, state)
assert(rejected == nil
    and rejectedReason == "incoming event evidence unavailable",
    "events before the health snapshot must not be replayed")

local unfrozen = recipient("unfrozen", 400, 1000, 4)
unfrozen.incomingFrozen = false
rejected, rejectedReason = Triage:Score(instant, unfrozen, state)
assert(rejected == nil and rejectedReason == "recipient evidence unavailable",
    "graph search must reject recipient evidence that was not frozen")

local badThreat = heal("bad-threat", 300, 50, 0, 1.5)
badThreat.healingThreatFactor = -1
rejected, rejectedReason = Triage:Score(badThreat,
    recipient("safe", 400, 1000, 4), state)
assert(rejected == nil
    and rejectedReason == "healing threat evidence unavailable",
    "invalid threat facts must fail closed rather than use a default")

print("ok: healing triage freezes direct-heal timing, survival and threat")
