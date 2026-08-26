-- Thunder Clap is direct max-four area damage with one server-backed 2.5x
-- threat packet per delivered recipient. Its slow never becomes proxy value.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(values) return #values end

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local ranks = {
    [6343] = { rank = 1, level = 6, base = 9, duration = 1 },
    [8198] = { rank = 2, level = 18, base = 22, duration = 305 },
    [8204] = { rank = 3, level = 28, base = 36, duration = 85 },
    [8205] = { rank = 4, level = 38, base = 54, duration = 467 },
    [11580] = { rank = 5, level = 48, base = 81, duration = 468 },
    [11581] = { rank = 6, level = 58, base = 102, duration = 9 },
}

local common = {
    school = 0, category = 49, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 136, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 196608,
    stancesNot = 0, targets = 0, targetCreatureType = 0,
    requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 4000,
    interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
    procFlags = 0, procChance = 0, procCharges = 0, maxLevel = 0,
    powerType = 1, manaCost = 200, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 1,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = -1, equippedItemSubClassMask = 0,
    equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    maxTargetLevel = 0, spellFamilyName = 4, spellFamilyFlags = 128,
    maxAffectedTargets = 4, dmgClass = 1, preventionType = 1,
    stanceBarOrder = 4294967295,
}

local rows = {}
for id, rank in pairs(ranks) do
    local row, key, value = {}, nil, nil
    for key, value in pairs(common) do row[key] = value end
    row.baseLevel, row.spellLevel, row.durationIndex =
        rank.level, rank.level, rank.duration
    row.effect = triple(2, 6)
    row.effectDieSides, row.effectBaseDice = triple(1, 1), triple(1, 1)
    row.effectDicePerLevel = triple()
    row.effectRealPointsPerLevel = triple()
    row.effectBasePoints = triple(rank.base, -11)
    row.effectMechanic = triple()
    row.effectImplicitTargetA = triple(22, 22)
    row.effectImplicitTargetB = triple(15, 15)
    row.effectRadiusIndex = triple(14, 14)
    row.effectApplyAuraName = triple(0, 138)
    row.effectAmplitude, row.effectMultipleValue = triple(), triple()
    row.effectChainTarget, row.effectItemType = triple(), triple()
    row.effectMiscValue, row.effectTriggerSpell = triple(), triple()
    row.effectPointsPerComboPoint = triple()
    rows[id] = row
end

local class = "WARRIOR"
function UnitClass() return "Warrior", class end
function GetSpellRecField(spellId, field, array)
    local value = rows[spellId] and rows[spellId][field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(spellId)
    assert(rows[spellId], "duration requested for an unknown Thunder Clap")
    return 10000
end

dofile("Game/Player/WarriorThunderClap.lua")
local Runtime = XelAssist.Game.Player.WarriorThunderClap
local ids = { 6343, 8198, 8204, 8205, 11580, 11581 }
local actions, snapshots = {}, {}
local index, id
for index = 1, table.getn(ids) do
    id = ids[index]
    local found, reason, handled = Runtime:Classify(id)
    assert(handled and not reason and found.valid and found.exact
        and found.rank == ranks[id].rank and found.level == ranks[id].level
        and found.damageMinimum == ranks[id].base + 1
        and found.damageMaximum == ranks[id].base + 1
        and found.stances == 196608 and found.radius == 8
        and found.maxAffectedTargets == 4
        and found.attackTimeIncreasePercent == 10
        and found.damageThreatMultiplier == 2.5
        and found.flatThreat == 0 and found.inverseEffectMask == 0
        and found.serverProfileExact and not found.runtimeVerified,
        "every player rank must bind installed DBC and server threat evidence")
    local facts, inferReason, claimed = Runtime:InferKnowledge(id)
    assert(claimed and not inferReason and facts.kind == "damage"
        and facts.kindExact and facts.aoe and not facts.melee
        and facts.threat == 2.5 and facts.stanceMask == 196608
        and facts.deliveryModel == "magic" and facts.school == 0
        and facts.runtimeUnverified,
        "inference must expose causal area damage and threat, not an order")
    local action = { name = "Thunder Clap", spellId = id,
        actor = "player", facts = facts }
    local snapshot = Runtime:CaptureFacts(action, {
        kind = facts.kind, aoe = facts.aoe, threat = facts.threat,
        warriorThunderClap = true,
        warriorThunderClapEvidence = facts.warriorThunderClapEvidence,
        cost = 16, average = ranks[id].base + 1, school = 0,
        topology = { available = true, effects = { {}, {} } },
    })
    actions[id], snapshots[id] = action, snapshot
    local captured = Runtime:CapturedEvidence(action, snapshot)
    local topology = snapshot.topology
    assert(captured and snapshot.cost == 16
        and snapshot.average == ranks[id].base + 1
        and table.getn(topology.effects) == 1
        and topology.effects[1].effect == 2
        and topology.effects[1].center == "caster"
        and topology.effects[1].radius == 8
        and topology.effects[1].maxTargets == 4,
        "root capture must retain dynamic cost/power and seal direct topology")
    local slow = Runtime:SlowEvidence(action, snapshot)
    assert(slow and slow.duration == 10 and slow.baseDuration == 10
        and slow.attackTimeIncreasePercent == 10
        and slow.intervalMultiplier == 1.1
        and slow.phaseAdjustment == "future-reset-only",
        "root capture must seal the installed duration and server phase rule")
end

local unknown, unknownReason, unknownHandled = Runtime:Classify(99999)
assert(not unknown and not unknownHandled
    and unknownReason == "not an installed Thunder Clap identity",
    "unknown identities must remain unclaimed")

dofile("Graph/WarriorThunderClap.lua")
local Graph = XelAssist.Graph.WarriorThunderClap
local action, snapshot = actions[6343], snapshots[6343]
local savedDBC = GetSpellRecField
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end

local blocker, handled = Graph:Blocker(
    action, {}, { relation = "hostile" }, snapshot)
assert(handled and blocker == nil,
    "sealed Thunder Clap must admit a hostile edge")

local context = { action = action, facts = action.facts,
    tooltip = snapshot, kind = "damage", effectivePower = 23 }
local threat, valueThreat, augmented, reason = Graph:Augment(
    context, 57.5, 143.75)
assert(augmented and not reason and threat == 57.5 and valueThreat == 57.5
    and context.warriorThunderClapDamageThreatMultiplier == 2.5
    and context.warriorThunderClapThreatProfileExact == false
    and context.estimated,
    "delivered damage must receive exactly one 2.5x threat multiplier")

local badThreat, _, badHandled, badReason = Graph:Augment(
    context, 23, 23)
assert(badHandled and badThreat == nil
    and badReason == "Thunder Clap delivered threat is incoherent",
    "an unmultiplied or otherwise incoherent threat lane must fail closed")

local applied, exact, appliedHandled, appliedReason = Graph:AppliedThreat(
    context, { effectDelivery = 0.5, tooltip = snapshot }, 20)
assert(appliedHandled and not appliedReason and applied == 50 and not exact,
    "transition must multiply already delivered damage exactly once")
assert(Graph:Exactness(context, true) == false,
    "unverified Octowow runtime profile must remain explicitly inexact")

local enemyA, enemyB, playerGuid = {}, {}, {}
local transition = { time = 2, hostiles = { order = { enemyA, enemyB },
    byKey = {
        [enemyA] = { guid = enemyA, health = 100, healthExact = true,
            harmfulAuras = { available = true, byName = {} } },
        [enemyB] = { guid = enemyB, health = 100, healthExact = true,
            harmfulAuras = { available = true, byName = {} } },
    } } }
local slowCandidate = { action = action, tooltip = snapshot,
    areaDirectResolved = true, recipientEffects = {
        order = { enemyA, enemyB }, byKey = {
            [enemyA] = { guid = enemyA, delivery = 1 },
            [enemyB] = { guid = enemyB, delivery = 0.5 },
        } } }
assert(Graph:ApplySlow(transition, slowCandidate)
    and transition.lastWarriorThunderClapSlowRecipients == 1
    and transition.hostiles.byKey[enemyA].meleeAttackTimeEffects
        .thunderClap.expiresAt == 12
    and transition.hostiles.byKey[enemyB].meleeAttackTimeUnknown
    and transition.incomingProjectionPartial,
    "only a guaranteed, aura-observable recipient may receive the exact slow")

XelAssist.Graph.IncomingConsequences = {}
dofile("Graph/HostileSwings.lua")
local lane = { attackerGuid = enemyA, attackerKey = enemyA,
    victimGuid = playerGuid, hand = "main", interval = 2,
    nextSwingIn = 0.5, expectedDamage = 10, generation = 1 }
transition.hostileSwings = { lanes = { lane } }
local slowedEvents = XelAssist.Graph.HostileSwings:Events(
    transition, { downtime = 5 })
assert(table.getn(slowedEvents) == 3
    and math.abs(slowedEvents[1].offset - 0.5) < 0.0001
    and math.abs(slowedEvents[2].offset - 2.7) < 0.0001
    and math.abs(slowedEvents[3].offset - 4.9) < 0.0001,
    "Thunder Clap must leave the current timer unchanged and slow later resets")
transition.time = 6
assert(Graph:ApplySlow(transition, slowCandidate)
    and transition.hostiles.byKey[enemyA].meleeAttackTimeEffects
        .thunderClap.observedMultiplier == 1
    and transition.hostiles.byKey[enemyA].meleeAttackTimeEffects
        .thunderClap.baseIntervals.main == 2,
    "a projected refresh must extend the same slow without rebasing its cadence")

local active = transition.hostiles.byKey[enemyA]
active.meleeAttackTimeEffects = nil
active.harmfulAuras.byName[action.name] = {
    spellId = action.spellId, remaining = 5 }
lane.interval, lane.nextSwingIn = 2.2, 0.5
transition.time = 0
transition.incomingProjectionPartial = nil
slowCandidate.recipientEffects.order = { enemyA }
slowCandidate.recipientEffects.byKey[enemyA].delivery = 1
assert(Graph:ApplySlow(transition, slowCandidate)
    and active.meleeAttackTimeEffects.thunderClap.observedMultiplier == 1.1,
    "refreshing an observed Thunder Clap must not multiply its learned cadence twice")
slowedEvents = XelAssist.Graph.HostileSwings:Events(
    transition, { downtime = 3 })
assert(table.getn(slowedEvents) == 2
    and math.abs(slowedEvents[2].offset - 2.7) < 0.0001,
    "an already slowed observed interval must remain 2.2 seconds after refresh")

active.harmfulAuras = { available = false, byName = {} }
active.meleeAttackTimeEffects = nil
assert(not Graph:ApplySlow(transition, slowCandidate)
    and active.meleeAttackTimeUnknown,
    "missing root aura ownership must withhold cadence instead of double slowing")

local resolution = { groups = { { effectIndex = 1,
    topology = { maxTargets = 4 }, byKey = { a = {}, b = {} } } },
    collateral = { { effectIndex = 1, key = "c" } },
    withheld = { { effectIndex = 1, key = "d" } } }
local areaReason, areaHandled = Graph:AreaBlocker(context, resolution)
assert(areaHandled and not areaReason,
    "four proven or collateral recipients must retain normal area policy")
table.insert(resolution.withheld, { effectIndex = 1, key = "e" })
areaReason, areaHandled = Graph:AreaBlocker(context, resolution)
assert(areaHandled
    and areaReason == "Thunder Clap four-target recipient subset is unknown",
    "a fifth candidate must fail closed instead of guessing server selection")

local corrupt = {}
for key, value in pairs(snapshot) do corrupt[key] = value end
corrupt.threat = 5
assert(Graph:Blocker(action, {}, { relation = "hostile" }, corrupt)
    == "Thunder Clap threat evidence unavailable",
    "forged effective threat must not cross the graph boundary")

local mismatched = {}
for key, value in pairs(snapshot) do mismatched[key] = value end
mismatched.warriorThunderClapEvidence = {}
for key, value in pairs(snapshot.warriorThunderClapEvidence) do
    mismatched.warriorThunderClapEvidence[key] = value
end
mismatched.warriorThunderClapEvidence.spellId = 8198
mismatched.warriorThunderClapEvidence.rank = 2
mismatched.warriorThunderClapEvidence.level = 18
mismatched.warriorThunderClapEvidence.damageMinimum = 23
mismatched.warriorThunderClapEvidence.damageMaximum = 23
assert(Graph:Blocker(action, {}, { relation = "hostile" }, mismatched)
    == "Thunder Clap threat evidence unavailable",
    "a stale root snapshot from another rank must fail closed")

GetSpellRecField = savedDBC
Runtime:Invalidate()
rows[6343].maxAffectedTargets = 5
local drift, driftReason, driftHandled = Runtime:Classify(6343)
assert(driftHandled and drift and not drift.valid
    and driftReason == "Thunder Clap DBC topology is incomplete",
    "installed target-cap drift must fail closed")
rows[6343].maxAffectedTargets = 4
Runtime:Invalidate()
class = "MAGE"
local foreign, foreignReason, foreignHandled = Runtime:InferKnowledge(6343)
assert(not foreign and not foreignHandled
    and foreignReason == "player is not an exactly identified Warrior",
    "another class must not receive Warrior mechanics")

print("ok: exact Thunder Clap max-four area damage and 2.5x threat")
