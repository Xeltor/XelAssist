-- Player threat components must use one conservative resolver in scoring and
-- transition attribution, while pet threat remains entirely independent.
XelAssist = { Game = { Pets = { Effects = {
    ThreatMultiplier = function() return 1 end,
} } }, Graph = {} }
XelAssistCharDB = { petThreat = "avoid" }

dofile("Graph/PlayerThreat.lua")
local PlayerThreat = XelAssist.Graph.PlayerThreat

local function close(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        message .. ": " .. tostring(actual))
end

local exactDefensive = { actor = "player", playerOnly = true,
    exact = true, multiplier = 1.495, minimum = 1.495, maximum = 1.495 }
local boundedDefensive = { actor = "player", playerOnly = true,
    exact = false, minimum = 1.3, maximum = 1.495 }

local multiplier, exact = PlayerThreat:Resolve(
    { tank = true, playerThreat = boundedDefensive }, "player")
close(multiplier, 1.3, "tank lower bound")
assert(exact == false,
    "bounded tank threat must remain explicitly inexact")
multiplier, exact = PlayerThreat:Resolve(
    { tank = false, playerThreat = boundedDefensive }, "player")
close(multiplier, 1.495, "non-tank upper bound")
assert(exact == false,
    "bounded non-tank threat must remain explicitly inexact")
multiplier, exact = PlayerThreat:Resolve(
    { tank = true, playerThreat = exactDefensive }, "player")
close(multiplier, 1.495, "exact Defensive multiplier")
assert(exact == true, "exact live evidence must remain exact")
multiplier, exact = PlayerThreat:Resolve(
    { tank = true, playerThreat = boundedDefensive }, "pet")
close(multiplier, 1, "pet bypass")
assert(exact == true, "player stance evidence must never taint pet threat")

local record = { threat = { playerDeltaExact = true } }
local amount, amountExact = PlayerThreat:Add(record,
    { tank = true, playerThreat = boundedDefensive }, "player", 100)
close(amount, 130, "bounded attributed player threat")
close(record.projectedThreat.player, 130, "projected player threat")
close(record.threat.playerDelta, 130, "player threat delta")
assert(amountExact == false and record.threat.playerDeltaExact == false
    and record.threat.containsBoundedPlayerThreat,
    "a chosen evidence bound must never become exact transition state")
PlayerThreat:Add(record,
    { tank = true, playerThreat = exactDefensive }, "pet", 100)
close(record.projectedThreat.pet, 100, "unscaled pet threat")
close(record.threat.petDelta, 100, "unscaled pet delta")

dofile("Graph/EventAuras.lua")
local periodicRecord = { threat = { playerDeltaExact = true } }
XelAssist.Graph.EventAuras:ApplyPeriodicThreat(periodicRecord,
    { periodicThreatActor = "player", periodicThreatMultiplier = 1 }, 10,
    { tank = false, playerThreat = { actor = "player", playerOnly = true,
        exact = true, multiplier = 0.8, minimum = 0.8, maximum = 0.8 } })
close(periodicRecord.projectedThreat.player, 8,
    "periodic player threat component")
close(periodicRecord.threat.playerDelta, 8,
    "periodic player threat delta")

dofile("Graph/ThreatScoring.lua")
local ThreatScoring = XelAssist.Graph.ThreatScoring
local function score(profile, tank)
    local state = { tank = tank, playerThreat = profile, groupSize = 1,
        pet = false, hasAggro = false, targetPlayerThreatDeltaExact = true,
        resourceMax = 100, actors = {} }
    local context = { state = state,
        action = { name = "Test strike", actor = "player" },
        facts = { kind = "damage" }, kind = "damage",
        power = 100, expectedPower = 100, effectivePower = 100,
        fullEffectivePower = 100, cost = 0, value = 0,
        effectDelivery = 1, estimated = false }
    ThreatScoring:Apply(context)
    return context
end

local defensiveScore = score(exactDefensive, true)
close(defensiveScore.threat, 149.5, "exact scored Defensive threat")
close(defensiveScore.playerThreatMultiplier, 1.495,
    "scored Defensive component")
assert(defensiveScore.playerThreatExact == true
    and defensiveScore.reason == "builds threat",
    "exact Defensive threat must become tank utility")

local boundedTank = score(boundedDefensive, true)
close(boundedTank.threat, 130, "conservative bounded tank score")
assert(boundedTank.estimated and boundedTank.playerThreatExact == false,
    "bounded tank score must retain uncertainty")
local boundedRisk = score(boundedDefensive, false)
close(boundedRisk.threat, 149.5, "conservative bounded threat risk")
assert(boundedRisk.estimated and boundedRisk.playerThreatExact == false,
    "bounded non-tank score must retain uncertainty")

print("ok: conservative player threat scaling and attribution")
