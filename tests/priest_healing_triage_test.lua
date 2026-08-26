XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Graph/HealingTriage.lua")
local Triage = XelAssist.Graph.HealingTriage

-- Priest names make this scenario readable. Choices still derive only from
-- generic graph evidence about health, delivery time, potency, cost and threat.
local function heal(key, name, power, cost, cast)
    return { actionKey = key, name = name, kind = "heal",
        delivery = "direct", actor = "player", power = power, cost = cost,
        cast = cast, wait = 0, gcd = 1.5, powerKnown = true,
        guaranteedPower = power, guaranteedPowerKnown = true,
        costKnown = true, timingKnown = true }
end

local function hit(id, guid, at, damage)
    return { id = id, kind = "damage", recipientGUID = guid,
        at = at, damage = damage, exact = true, frozen = true,
        probability = 1 }
end

local function recipient(key, health, maximum, incoming)
    return { key = key, guid = key .. "-guid", health = health,
        healthMax = maximum, healthAt = 0, healthExact = true,
        incomingKnown = true, incomingFrozen = true,
        incoming = incoming or {} }
end

local actions = {
    heal(1, "Flash Heal (efficient rank)", 300, 100, 1.5),
    heal(2, "Flash Heal (large rank)", 600, 230, 1.5),
    heal(3, "Greater Heal", 900, 260, 2.5),
}
local state = { time = 0, resource = 300, resourceMax = 1000,
    playerResourceExact = true }
local tank = recipient("tank", 500, 1000)
tank.incoming = { hit("swing-2", tank.guid, 2, 300),
    hit("swing-1", tank.guid, 1, 350) }
local damage = recipient("damage", 200, 1000)

local best, reason = Triage:Best(actions, { tank, damage }, state)
assert(best and reason == nil and best.recipient == "tank"
    and best.actionKey == 1 and best.actionIndex == 1
    and best.recipientIndex == 1 and best.effectiveHealing == 300
    and best.savesRecipient and best.stabilizingHealing == 151
    and best.resourceAfter == 200 and best.incomingEvents == 2,
    "triage must choose the timely efficient rank that prevents proven death")
assert(best.healingThreat == 150 and best.threatFactor == 0.5,
    "healing threat must use effective healing rather than tooltip power")

local late, lateReason = Triage:Score(actions[3], tank, state)
assert(late == nil and lateReason == "recipient dies before heal lands",
    "a larger heal arriving after lethal damage must not win")

local safe = recipient("safe", 950, 1000)
local small = Triage:Score(actions[1], safe, state)
local large = Triage:Score(actions[2], safe, state)
assert(small and large and small.value > large.value
    and small.overheal < large.overheal
    and small.effectiveHealing == large.effectiveHealing,
    "rank choice must penalize overheal and mana without a typed rank order")

local affordable = Triage:Best(actions, { damage },
    { time = 0, resource = 150, resourceMax = 1000,
        playerResourceExact = true })
assert(affordable and affordable.actionKey == 1
    and affordable.resourceAfter == 50,
    "an unaffordable rank must not displace an exact affordable heal")
local starved, starvedReason = Triage:Best(actions, { damage },
    { time = 0, resource = 50, resourceMax = 1000,
        playerResourceExact = true })
assert(starved == nil and starvedReason == "insufficient healing resource",
    "future mana must never be borrowed to fabricate a heal")

local full, fullReason = Triage:Best(actions, {
    recipient("tank-full", 1000, 1000),
    recipient("damage-full", 1000, 1000),
}, state)
assert(full == nil and fullReason == "no effective healing",
    "without effective healing the support lane must remain open for damage")

local inexact = recipient("inexact", 400, 1000)
inexact.healthExact = false
local invalid, invalidReason = Triage:Score(actions[1], inexact, state)
assert(invalid == nil and invalidReason == "recipient evidence unavailable",
    "unknown recipient health must fail closed")

local overflow, index = recipient("overflow", 400, 1000), nil
for index = 1, Triage.MAX_EVENTS + 1 do
    table.insert(overflow.incoming,
        hit("event-" .. index, overflow.guid, 4 + index, 1))
end
invalid, invalidReason = Triage:Score(actions[1], overflow, state)
assert(invalid == nil
    and invalidReason == "incoming event budget or shape invalid",
    "unbounded future evidence must not hide early damage")

local duplicate = recipient("duplicate", 400, 1000, {})
duplicate.incoming = {
    hit("same-generation", duplicate.guid, 1, 50),
    hit("same-generation", duplicate.guid, 2, 50),
}
invalid, invalidReason = Triage:Score(actions[1], duplicate, state)
assert(invalid == nil
    and invalidReason == "incoming event evidence unavailable",
    "duplicate event identity must not double-count incoming damage")

local incomplete = heal(4, "Unknown heal", 300, 100, 1.5)
incomplete.powerKnown = false
invalid, invalidReason = Triage:Score(incomplete, damage, state)
assert(invalid == nil and invalidReason == "heal evidence unavailable",
    "unknown rank potency must not participate in triage")

print("ok: Priest triage chooses exact recipient and mana-efficient heal")
