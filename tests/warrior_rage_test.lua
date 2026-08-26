-- Exact Bloodrage discovery, delayed resource causality, and graph application.
XelAssist = { Game = { Player = {}, Capabilities = {} }, Graph = { State = {} } }

local class = "WARRIOR"
function UnitClass()
    return class == "WARRIOR" and "Warrior" or "Mage", class
end

local function three(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {
    [2687] = {
        spellFamilyName = 4, spellFamilyFlags = 256, school = 0,
        powerType = 0, manaCost = 0, manaCostPercentage = 0,
        recoveryTime = 60000,
        categoryRecoveryTime = 0, startRecoveryTime = 0,
        effect = three(30, 64, 2), effectApplyAuraName = three(),
        effectImplicitTargetA = three(1, 1, 1),
        effectImplicitTargetB = three(), effectMiscValue = three(1),
        effectTriggerSpell = three(0, 29131, 0),
        effectBasePoints = three(99, 0, 9),
        effectBaseDice = three(1, 0, 1),
        effectDieSides = three(1, 0, 1),
        effectDicePerLevel = three(),
        effectRealPointsPerLevel = three(),
        effectPointsPerComboPoint = three(),
        description = "at the cost of $*2;s3% of your base health",
    },
    [29131] = {
        spellFamilyName = 4,
        effect = three(6, 6, 0),
        effectApplyAuraName = three(24, 94, 0),
        effectImplicitTargetA = three(1, 1, 0),
        effectImplicitTargetB = three(), effectMiscValue = three(1),
        effectAmplitude = three(1000, 0, 0),
        effectBasePoints = three(9, 0, 0),
        effectBaseDice = three(1, 0, 0),
        effectDieSides = three(1, 0, 0),
        effectDicePerLevel = three(),
        effectRealPointsPerLevel = three(),
        effectPointsPerComboPoint = three(),
    },
}

function GetSpellRecField(spellId, field, copied)
    local row = records[spellId]
    local value = row and row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function GetSpellDuration(spellId)
    return spellId == 29131 and 10000 or 0
end

function XelAssist.Graph.State:FriendlyByUnit(state, unit)
    local key = state.friendlies and state.friendlies.byUnit[unit]
    return key and state.friendlies.byKey[key] or nil
end

dofile("Game/Player/WarriorRage.lua")
dofile("Graph/WarriorRage.lua")
local Runtime = XelAssist.Game.Player.WarriorRage
local Graph = XelAssist.Graph.WarriorRage

local found, reason, recognized = Runtime:Classify(2687)
assert(found and found.valid == true and found.exact == true
    and found.immediateGain == 10 and found.periodicGain == 1
    and found.ticks == 10 and found.totalGain == 20
    and found.baseHealthPercent == 10
    and found.healthCriticalMultiplier == 2
    and found.healthCostPercent == 20 and found.cooldown == 60
    and found.gcd == 0 and found.powerType == 1
    and found.startsCombat == true and reason == nil and recognized == true,
    "installed Bloodrage must expose its exact direct and triggered effects")
assert(Runtime:Classify(99999) == nil,
    "an unrelated identity must not enter the Bloodrage portfolio")

local inferred, inferReason, inferRecognized = Runtime:InferKnowledge(2687)
assert(inferred and inferred.kind == "resource" and inferred.kindExact == true
    and inferred.self == true and inferred.fixedTarget == "player"
    and inferred.transientResource == true
    and inferred.healthConversion == true
    and inferred.resourceType == "rage" and inferred.warriorRage == true
    and inferred.routineResourceCooldown == true
    and inferred.requiresExactUsability and inferred.submissionGuarded
    and inferred.preferred == nil and inferred.order == nil
    and inferReason == nil and inferRecognized == true,
    "discovery must describe a resource consequence without a typed rotation")
class = "MAGE"
assert(Runtime:InferKnowledge(2687) == nil,
    "another class must not discover the Warrior action")
class = "WARRIOR"

Runtime:Invalidate()
records[29131].effectApplyAuraName[1] = 85
local invalid, invalidReason, invalidRecognized = Runtime:Classify(2687)
assert(invalid and invalid.valid == false and invalidRecognized == true
    and invalidReason == "Bloodrage DBC topology is incomplete",
    "a changed periodic aura must fail closed despite the known spell ID")
records[29131].effectApplyAuraName[1] = 24
Runtime:Invalidate()
records[2687].manaCostPercentage = 20
local percentCost = Runtime:Classify(2687)
assert(percentCost and percentCost.valid == false,
    "an unmodeled percentage health cost must fail closed")
records[2687].manaCostPercentage = 0
Runtime:Invalidate()
found = Runtime:Classify(2687)
inferred = Runtime:InferKnowledge(2687)

local action = { name = "localized text irrelevant", spellId = 2687,
    actor = "player", executor = "playerSpell", facts = inferred }
local savedDBC, savedDuration = GetSpellRecField, GetSpellDuration
GetSpellRecField = function() error("DBC read during sealed capture") end
GetSpellDuration = function() error("duration read during sealed capture") end
local tooltip = Runtime:CaptureFacts(action, { source = "root tooltip" })
GetSpellRecField, GetSpellDuration = savedDBC, savedDuration
assert(tooltip.healthCostPercent == 20 and tooltip.healthCost == nil
    and tooltip.resourceGain == 20
    and tooltip.resourceImmediate == 10 and tooltip.resourcePeriodic == 10
    and tooltip.resourceType == "rage" and tooltip.powerType == 1
    and tooltip.cost == 0 and tooltip.cast == 0 and tooltip.gcd == 0
    and tooltip.cooldown == 60 and tooltip.duration == 10,
    "root capture must seal every magnitude and timing needed by the graph")

local usability = { known = true, usable = true }
XelAssist.Graph.RootObservation = {
    Usability = function() return usability, "known" end,
}
XelAssist.Game.Capabilities.Usable = function()
    error("sealed graph search called live usability")
end

local function state(rage, health, baseHealth)
    local player = { unit = "player", relation = "self", health = health,
        healthMax = 1000, resource = rage, resourceMax = 100 }
    return { time = 0, resourceType = 1, resource = rage,
        resourceMax = 100, playerResourceExact = true,
        playerResourceReserved = 0, health = health, healthMax = 1000,
        playerBaseHealth = baseHealth or 300, playerBaseHealthExact = true,
        inCombat = false, actors = { player = player },
        friendlies = { byUnit = { player = "player-key" },
            byKey = { ["player-key"] = player } } }
end

local target = { unit = "player", relation = "self", key = "player-key" }
local source = state(0, 100)
local blocker, handled = Graph:Blocker(action, source, target, tooltip)
assert(blocker == nil and handled == true,
    "exact safe Bloodrage must be a legal self resource edge")
local lethal = state(0, 60)
assert(Graph:Blocker(action, lethal, target, tooltip)
    == "Bloodrage would be lethal",
    "the exact self-damage must fail closed at lethal health")
local unknownRage = state(0, 100)
unknownRage.playerResourceExact = false
assert(Graph:Blocker(action, unknownRage, target, tooltip)
    == "Warrior rage state unavailable",
    "an inexact rage root must not accept exact-looking projections")
local unknownBase = state(0, 100)
unknownBase.playerBaseHealth, unknownBase.playerBaseHealthExact = nil, false
assert(Graph:Blocker(action, unknownBase, target, tooltip)
    == "base health evidence unavailable",
    "unsealed base health must block percentage self-damage")
assert(Graph:Blocker({ facts = {} }, source, target, tooltip) == nil,
    "ordinary resource actions must remain outside this portfolio")

local context = { action = action, state = source, tooltip = tooltip }
assert(Graph:Score(context) and context.power == 20
    and context.expectedPower == 20 and context.effectivePower == 20
    and context.resourceGain == 20 and context.estimated == false
    and context.value == -60 and context.healthCost == 60,
    "Bloodrage must expose total rage but score only its exact standalone cost")

local out = state(0, 100)
assert(Graph:Apply(out, { action = action, tooltip = tooltip }),
    "the exact action must apply")
assert(out.health == 40 and out.resource == 10 and out.inCombat == true
    and out.warriorRageCombatUntil == 10
    and out.playerResourceClock.ticksRemaining == 10
    and out.playerResourceClock.nextIn == 1
    and out.actors.player.health == 40 and out.actors.player.resource == 10
    and out.friendlies.byKey["player-key"].health == 40,
    "application must synchronize health, immediate rage, combat, and clock")
assert(source.health == 100 and source.resource == 0 and not source.inCombat,
    "applying a descendant must leave its source observation untouched")
assert(Graph:Blocker(action, out, target, tooltip)
    == "Bloodrage already active",
    "the projected clock must prevent a duplicate cast")

assert(Runtime:Advance(out, 0.5) == 0 and out.resource == 10
    and out.playerResourceClock.nextIn == 0.5,
    "a partial interval must not fabricate rage")
assert(Runtime:Advance(out, 0.5) == 1 and out.resource == 11,
    "the first exact second must yield one rage")
assert(Runtime:Advance(out, 2.2) == 2 and out.resource == 13
    and math.abs(out.playerResourceClock.nextIn - 0.8) < 0.000001,
    "multi-second downtime must advance the finite clock causally")

local runway = state(0, 100)
assert(Graph:Apply(runway, { action = action, tooltip = tooltip }))
assert(Runtime:ResourceAt(runway, 5) == 15
    and Runtime:Earliest(runway, 15, 0) == 5
    and Runtime:Earliest(runway, 20, 0) == 10
    and Runtime:Earliest(runway, 21, 0) == nil,
    "future admission must see only rage supported by elapsed exact ticks")
assert(runway.resource == 10 and runway.playerResourceClock.ticksRemaining == 10,
    "resource probes must not consume the searched branch clock")

local capped = state(95, 100)
assert(Graph:Apply(capped, { action = action, tooltip = tooltip })
    and capped.resource == 100)
assert(Runtime:Advance(capped, 1) == 0
    and capped.playerResourceClock.ticksRemaining == 9,
    "a capped tick is consumed but must not overfill rage")
capped.resource, capped.actors.player.resource = 80, 80
assert(Runtime:Advance(capped, 1) == 1 and capped.resource == 81,
    "a capped earlier tick must not erase later finite ticks")

local buffRemaining = 7.8
GetUnitField = function(unit, field)
    assert(unit == "player" and field == "baseHealth")
    return 300
end
GetPlayerBuff = function(index)
    return index == 0 and 7 or -1
end
GetPlayerBuffID = function(slot)
    return slot == 7 and 29131 or nil
end
GetPlayerBuffTimeLeft = function(slot)
    return slot == 7 and buffRemaining or nil
end
local active = Runtime:Snapshot()
assert(active and active.active and active.lowerBound
    and active.exact == false and active.phaseKnown == false
    and active.nextIn == 1 and active.ticksRemaining == 7,
    "an active root aura must carry a conservative phase-safe continuation")
local continued = state(30, 100)
continued.playerBaseHealth, continued.playerBaseHealthExact = nil, false
assert(Runtime:Attach(continued))
assert(continued.playerBaseHealth == 300
    and continued.playerBaseHealthExact == true,
    "root attachment must seal exact base health for percentage self-damage")
GetUnitField = function() error("base health read during graph search") end
GetPlayerBuff = function() error("buff read during graph search") end
GetPlayerBuffID = function() error("buff ID read during graph search") end
GetPlayerBuffTimeLeft = function() error("buff time read during graph search") end
assert(Runtime:Advance(continued, 1) == 1 and continued.resource == 31)
continued.time = 1
assert(Runtime:Earliest(continued, 37, 1) == 7,
    "active-root continuation must need no live API after attachment")

usability = { known = true, usable = false, reason = "state" }
assert(Graph:Blocker(action, state(0, 100), target, tooltip) == "state",
    "self-targeted Bloodrage must still require exact root usability")
usability = { known = false }
assert(Graph:Blocker(action, state(0, 100), target, tooltip)
    == "Bloodrage usability evidence unknown",
    "unknown root usability must fail closed")

print("ok: exact Bloodrage health, combat, and finite rage consequences")
