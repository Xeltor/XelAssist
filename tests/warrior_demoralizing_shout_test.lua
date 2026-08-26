-- Demoralizing Shout is recipient-local flat threat plus an aura lifecycle.
-- Its dynamic AP reduction is sealed as unmodelled and receives no proxy
-- defensive score while the graph lacks hostile melee-swing evidence.
XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
table.getn = table.getn or function(values) return #values end

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local ranks = {
    [1160] = { rank = 1, level = 14, maxLevel = 24,
        basePoints = -36, threat = 11 },
    [6190] = { rank = 2, level = 24, maxLevel = 34,
        basePoints = -56, threat = 19 },
    [11554] = { rank = 3, level = 34, maxLevel = 44,
        basePoints = -71, threat = 27 },
    [11555] = { rank = 4, level = 44, maxLevel = 54,
        basePoints = -106, threat = 35 },
    [11556] = { rank = 5, level = 54, maxLevel = 64,
        basePoints = -141, threat = 43 },
}
local common = {
    school = 0, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 0, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
    auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
    procChance = 101, procCharges = 0, durationIndex = 9, powerType = 1,
    manaCost = 100, manaCostPerlevel = 0, manaPerSecond = 0,
    manaPerSecondPerLevel = 0, rangeIndex = 1, speed = 0,
    modalNextSpell = 0, stackAmount = 0, equippedItemClass = -1,
    equippedItemSubClassMask = 0, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 4,
    spellFamilyFlags = 131072, maxAffectedTargets = 0, dmgClass = 1,
    preventionType = 1, stanceBarOrder = 4294967295,
}
local rows = {}
for id, rank in pairs(ranks) do
    local row, key, value = {}, nil, nil
    for key, value in pairs(common) do row[key] = value end
    row.baseLevel, row.spellLevel, row.maxLevel =
        rank.level, rank.level, rank.maxLevel
    row.effect = triple(6)
    row.effectDieSides, row.effectBaseDice = triple(1), triple(1)
    row.effectDicePerLevel = triple()
    row.effectRealPointsPerLevel = triple(-1)
    row.effectBasePoints = triple(rank.basePoints)
    row.effectMechanic = triple()
    row.effectImplicitTargetA, row.effectImplicitTargetB =
        triple(22), triple(15)
    row.effectRadiusIndex = triple(13)
    row.effectApplyAuraName = triple(99)
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
function GetSpellDuration(_, ignoreModifiers)
    return ignoreModifiers and 30000 or 36000
end
C_Spell = { GetSpellRadius = function() return 10, 12 end }

dofile("Game/Player/WarriorDemoralizingShout.lua")
local Runtime = XelAssist.Game.Player.WarriorDemoralizingShout
local ids = { 1160, 6190, 11554, 11555, 11556 }
local actions, snapshots, index, id = {}, {}, nil, nil
for index = 1, table.getn(ids) do
    id = ids[index]
    local found, reason, handled = Runtime:Classify(id)
    local rank = ranks[id]
    assert(handled and not reason and found.valid and found.exact
        and found.rank == rank.rank and found.level == rank.level
        and found.maxLevel == rank.maxLevel
        and found.attackPowerBasePoints == rank.basePoints
        and found.attackPowerPerLevel == -1
        and not found.attackPowerReductionModeled
        and found.flatThreat == rank.threat
        and found.flatThreatModel
            == "negative-flat-per-successful-recipient"
        and found.serverProfileExact and not found.runtimeVerified,
        "every rank must bind installed DBC and per-recipient threat evidence")
    local facts, inferReason, claimed = Runtime:InferKnowledge(id)
    assert(claimed and not inferReason and facts.kind == "debuff"
        and facts.kindExact and facts.aoe and facts.hostile
        and facts.resourceType == "rage" and facts.deliveryModel == "magic"
        and facts.baseFlatThreatBySpellId[id] == rank.threat
        and facts.attackPowerReductionModeled == false
        and facts.runtimeUnverified,
        "inference must expose consequences without a typed priority")
    local action = { name = "Demoralizing Shout", spellId = id,
        actor = "player", facts = facts }
    local snapshot = Runtime:CaptureFacts(action, {
        kind = facts.kind, aoe = true, warriorDemoralizingShout = true,
        warriorDemoralizingShoutEvidence = facts.warriorDemoralizingShoutEvidence,
        baseFlatThreatBySpellId = facts.baseFlatThreatBySpellId,
        cost = 7, duration = 999,
    })
    local sealed, profile = Runtime:CapturedEvidence(action, snapshot)
    assert(sealed and profile and snapshot.cost == 7
        and snapshot.duration == 36 and profile.baseRadius == 10
        and profile.radius == 12 and profile.baseDuration == 30
        and profile.duration == 36 and not profile.attackPowerReductionModeled
        and snapshot.topology.available and snapshot.topology.area
        and table.getn(snapshot.topology.effects) == 1
        and snapshot.topology.effects[1].aura == 99
        and snapshot.topology.effects[1].center == "caster"
        and snapshot.topology.effects[1].radius == 12
        and snapshot.topology.effects[1].maxTargets == nil,
        "root capture must preserve cost and freeze modified geometry/lifetime")
    actions[id], snapshots[id] = action, snapshot
end

local unknown, unknownReason, unknownHandled = Runtime:Classify(99999)
assert(not unknown and not unknownHandled
    and unknownReason == "not an installed Demoralizing Shout identity",
    "unknown numeric identities must remain unclaimed")

local savedRadiusCapture = C_Spell.GetSpellRadius
C_Spell.GetSpellRadius = function() return 10, nil end
local incomplete = Runtime:CaptureFacts(actions[1160], actions[1160].facts)
assert(incomplete.topology.available == false
    and not Runtime:CapturedEvidence(actions[1160], incomplete),
    "missing modified radius must seal an unusable root snapshot")
C_Spell.GetSpellRadius = savedRadiusCapture

XelAssist.Graph.State = {
    HostileContext = function(_, state, key)
        local record = state.hostiles.byKey[key]
        return { targetGUID = record.guid, targetHealth = record.health,
            targetHealthExact = record.healthExact,
            playerThreat = state.playerThreat, tank = state.tank,
            groupSize = state.groupSize, pet = state.pet }
    end,
    HostileByKey = function(_, state, key)
        return state.hostiles.byKey[key]
    end,
    RefreshHostileRecord = function(_, state, key)
        state.lastRefreshed = key
    end,
    SyncActiveHostile = function(_, state)
        state.synced = true
    end,
}
XelAssist.Graph.Effects = {
    StateAtImpact = function(_, state) return state end,
    Decision = function(_, resistance)
        return resistance.landChance, resistance.landChance
    end,
}
XelAssist.Combat.Resistance = { Estimate = function(_, _, _, _, state)
    return { landChance = state.targetGUID == "guid-b" and 0.5 or 0.8 }
end }
dofile("Graph/WarriorDemoralizingShout.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/AreaRecipients.lua")
local Graph = XelAssist.Graph.WarriorDemoralizingShout

local function hostile(key, guid, distance, selected, engaged)
    return { key = key, guid = guid, unit = selected and "target" or "nameplate1",
        selected = selected, engaged = engaged, dead = false,
        health = 100, healthExact = true, geometry = {
            player = distance and { distance = distance,
                source = "frozen root geometry" } or {} },
        threat = { playerDelta = 0, playerDeltaExact = true },
        projectedThreat = {}, projectedAuras = {} }
end

local first = hostile("a", "guid-a", 6, true, true)
local second = hostile("b", "guid-b", 8, false, true)
local state = { tank = true, groupSize = 2,
    playerThreat = { actor = "player", playerOnly = true,
        exact = true, multiplier = 1.3 },
    hostiles = { order = { "a", "b" }, byKey = {
        a = first, b = second }, selectedKey = "a",
        discoveryComplete = false } }
local descriptor = { unit = "target", relation = "hostile",
    source = "selected", key = "a", guid = "guid-a", record = first }
local action, snapshot = actions[1160], snapshots[1160]

local savedDBC, savedDuration, savedRadius = GetSpellRecField,
    GetSpellDuration, C_Spell.GetSpellRadius
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
C_Spell.GetSpellRadius = function() error("radius read during graph search") end

local blocker, handled = Graph:Blocker(action, state, descriptor, snapshot)
assert(handled and blocker == nil,
    "selected in-range hostile and engaged secondary must be admissible")
local context = { action = action, facts = action.facts, tooltip = snapshot,
    effectAction = action, effectTooltip = snapshot, state = state,
    descriptor = descriptor, effectDelivery = 0.8, wait = 0, cast = 0 }
assert(Graph:Score(context) and context.value == 0
    and context.power == 0 and context.expectedPower == 0
    and context.effectivePower == 0 and context.estimated
    and math.abs(context.warriorDemoralizingShoutPackets
        .byKey.a.scaledThreat - 11.44) < 0.00001
    and math.abs(context.warriorDemoralizingShoutPackets
        .byKey.b.scaledThreat - 7.15) < 0.00001
    and math.abs(context.warriorDemoralizingShoutSecondaryValue
        - 3.575) < 0.00001,
    "score must contain only delivery-weighted flat threat packets")
context.value = 11.44 * 0.5 * 0.88
assert(Graph:Finalize(context)
    and math.abs(context.value - (11.44 + 7.15) * 0.5 * 0.88) < 0.00001,
    "secondary tank threat must use the same generic policy/confidence once")
assert(Graph:Exactness(context, true) == false,
    "unproven runtime server identity must remain explicitly inexact")

first.projectedThreat.player, first.threat.playerDelta = 11.44, 11.44
first.projectedAuras[action.name] = { remaining = 34.5, duration = 36,
    mine = true }
local candidate = { action = action, tooltip = snapshot,
    targetKey = "a", targetGUID = "guid-a", targetRelation = "hostile",
    occupancy = 1.5, cast = 0,
    warriorDemoralizingShoutPackets =
        context.warriorDemoralizingShoutPackets }
local forgedPackets = { order = { "a", "b" }, byKey = {},
    additionalUnknown = true }
for _, key in ipairs(forgedPackets.order) do
    forgedPackets.byKey[key] = {}
    for field, value in pairs(context.warriorDemoralizingShoutPackets.byKey[key]) do
        forgedPackets.byKey[key][field] = value
    end
end
forgedPackets.byKey.b.flatThreat = 12
local forged = { action = action, tooltip = snapshot,
    targetKey = "a", targetGUID = "guid-a", occupancy = 1.5, cast = 0,
    warriorDemoralizingShoutPackets = forgedPackets }
assert(not Graph:Apply(state, forged) and first.threat.playerDelta == 11.44
    and second.threat.playerDelta == 0,
    "packet validation must finish before any recipient is mutated")
assert(Graph:Apply(state, candidate)
    and first.threat.playerDelta == 11.44
    and math.abs(second.threat.playerDelta - 7.15) < 0.00001
    and first.projectedAuras[action.name].applicationProbability == 0.8
    and first.projectedAuras[action.name].remaining == 34.5
    and second.projectedAuras[action.name].applicationProbability == 0.5
    and second.projectedAuras[action.name].remaining == 34.5
    and not second.projectedAuras[action.name].attackPowerReductionModeled
    and second.threat.playerDeltaExact == false
    and second.threat.containsEstimatedBaseThreat,
    "transition must preserve or recover primary delivery and project off-target threat once")

local collateral = hostile("c", "guid-c", 9, false, false)
state.hostiles.order = { "a", "c" }
state.hostiles.byKey = { a = first, c = collateral }
assert(Graph:Blocker(action, state, descriptor, snapshot)
        == "Demoralizing Shout would affect an unengaged hostile",
    "a proven collateral pull must fail closed without proxy penalties")
state.hostiles.order, state.hostiles.byKey = { "a" }, { a = first }
first.geometry.player = {}
assert(Graph:Blocker(action, state, descriptor, snapshot)
        == "selected hostile is not proven inside Shout radius",
    "unknown selected range must fail closed")

GetSpellRecField, GetSpellDuration, C_Spell.GetSpellRadius =
    savedDBC, savedDuration, savedRadius
Runtime:Invalidate()
rows[1160].effectRadiusIndex = triple(14)
local drift, driftReason, driftHandled = Runtime:Classify(1160)
assert(driftHandled and drift and not drift.valid
    and driftReason == "Demoralizing Shout DBC topology is incomplete",
    "installed topology drift must fail closed")
rows[1160].effectRadiusIndex = triple(13)
Runtime:Invalidate()
class = "MAGE"
local foreign, foreignReason, foreignHandled = Runtime:InferKnowledge(1160)
assert(not foreign and not foreignHandled
    and foreignReason == "player is not an exactly identified Warrior",
    "non-Warriors must not receive Warrior mechanics")

print("ok: Demoralizing Shout exact recipient threat without proxy mitigation")
