XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(a, b, c)
    return { a or 0, b or 0, c or 0 }
end

local ACTION_FLAG = 4504149383184384
local ranks = {
    [5675] = { aura = 5677, creature = 3573, level = 26,
        cost = 40, amount = 4 },
    [10495] = { aura = 10491, creature = 7414, level = 36,
        cost = 60, amount = 6 },
    [10496] = { aura = 10493, creature = 7415, level = 46,
        cost = 80, amount = 8 },
    [10497] = { aura = 10494, creature = 7416, level = 56,
        cost = 100, amount = 10 },
}
local records = {}
local zeroFields = { "effectDicePerLevel", "effectRealPointsPerLevel",
    "effectMechanic", "effectMultipleValue", "effectChainTarget",
    "effectItemType", "effectPointsPerComboPoint" }

local function addZeros(row)
    local index
    for index = 1, table.getn(zeroFields) do
        row[zeroFields[index]] = triple()
    end
    return row
end

local function common(school, level, duration, cost, flags)
    return { school = school, attributes = school == 4 and 65536 or 0,
        attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, castingTimeIndex = 1, recoveryTime = 0,
        categoryRecoveryTime = 0, baseLevel = level, spellLevel = level,
        durationIndex = duration, powerType = 0, manaCost = cost,
        rangeIndex = 1, speed = 0, spellFamilyName = 11,
        spellFamilyFlags = flags, maxAffectedTargets = 0,
        dmgClass = 1, preventionType = 1 }
end

local function build()
    local spellId, rank
    for spellId, rank in pairs(ranks) do
        local action = addZeros(common(
            4, rank.level, 3, rank.cost, ACTION_FLAG))
        action.startRecoveryCategory, action.startRecoveryTime = 107, 1500
        action.effect = triple(89)
        action.effectDieSides, action.effectBaseDice = triple(1), triple(1)
        action.effectBasePoints = triple(4)
        action.effectImplicitTargetA = triple(42)
        action.effectImplicitTargetB, action.effectRadiusIndex = triple(), triple()
        action.effectApplyAuraName, action.effectAmplitude = triple(), triple()
        action.effectMiscValue = triple(rank.creature)
        action.effectTriggerSpell = triple()
        records[spellId] = action

        local aura = addZeros(common(3, rank.level, 21, 0, 16384))
        aura.startRecoveryCategory, aura.startRecoveryTime = 0, 0
        aura.effect = triple(35, 35, 35)
        aura.effectDieSides, aura.effectBaseDice = triple(1, 1, 1), triple(1, 1, 1)
        aura.effectBasePoints = triple(rank.amount - 1, -1, -1)
        aura.effectImplicitTargetA = triple(1, 1, 1)
        aura.effectImplicitTargetB = triple()
        aura.effectRadiusIndex = triple(10, 10, 10)
        aura.effectApplyAuraName = triple(24, 24, 24)
        aura.effectAmplitude = triple(2000, 2000, 2000)
        aura.effectMiscValue = triple(0, 1, 3)
        aura.effectTriggerSpell = triple()
        records[rank.aura] = aura
    end
end
build()

local reads = 0
GetSpellRecField = function(spellId, field, array)
    reads = reads + 1
    local row = records[spellId]
    local value = row and row[field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

local modifiers = {}
GetSpellModifiers = function(spellId, kind)
    local row = modifiers[spellId] and modifiers[spellId][kind]
    if row then return row[1], row[2], row[3] end
    return 0, 0, 0
end
UnitClass = function() return "Shaman", "SHAMAN" end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end

dofile("Game/Player/ShamanManaSpring.lua")
local Runtime = XelAssist.Game.Player.ShamanManaSpring

local lifecycle = { shamanTotem = true, shamanLifecycleRepresented = true,
    shamanRepresentationExact = true, totemElementExact = true,
    totemReplacementExact = true, totemLifetimeExact = true,
    totemSlot = 3, totemReplacementSlot = 3, totemElement = "water",
    totemReplacementFamily = "shamanTotemSlot3",
    totemReplacementFamilyExact = true, totemLifetime = 60 }

local capturedByRank = {}
local spellId, rank
for spellId, rank in pairs(ranks) do
    local promoted = Runtime:Promote(spellId, lifecycle)
    assert(promoted ~= lifecycle and promoted.shamanManaSpring == true
        and promoted.shamanRepresentation == "manaSpringTotemSolo"
        and promoted.shamanEffectRepresented
        and promoted.shamanRangeRepresented
        and promoted.shamanRecipientsRepresented
        and promoted.shamanManaSpringEvidence.auraSpellId == rank.aura
        and promoted.shamanTotemDownstream.effect.baseAmount == rank.amount
        and promoted.shamanTotemDownstream.effect.period == 2
        and promoted.shamanTotemDownstream.effect.zeroThreat == true,
        "every installed rank must promote its exact periodic mana chain")
    local action = { spellId = spellId, actor = "player", facts = promoted }
    local captured = Runtime:CaptureFacts(action, promoted)
    assert(captured.shamanManaSpringContract.exact == true
        and captured.shamanManaSpringContract.deterministic == true
        and captured.shamanManaSpringContract.amount == rank.amount
        and captured.shamanManaSpringContract.period == 2,
        "root capture must seal each rank's deterministic amount and cadence")
    action.facts, capturedByRank[spellId] = captured, captured
end

local unrelated = Runtime:Inspect(9999)
assert(unrelated.recognized == false,
    "unrelated Shaman spells must fall through without being claimed")

records[5677].effectAmplitude[1] = 1999
Runtime:Invalidate()
local invalid = Runtime:Promote(5675, lifecycle)
assert(invalid == lifecycle and invalid.shamanEffectRepresented == nil,
    "a changed installed aura topology must remain lifecycle-only")
records[5677].effectAmplitude[1] = 2000
Runtime:Invalidate()

local promoted = Runtime:Promote(5675, lifecycle)
modifiers[5677] = { [8] = { 0, 5, 1 }, [19] = { 0, 0, 0 } }
local stochastic = Runtime:CaptureFacts(
    { spellId = 5675, facts = promoted }, promoted)
assert(stochastic.shamanManaSpringContract.exact == false
    and stochastic.shamanManaSpringContract.reason
        == "Mana Spring tick is stochastic or invalid",
    "fractional rand-dithered mana must fail closed without resource branches")
modifiers[5677] = { [8] = { 0, 0, 0 }, [19] = { 1000, 0, 1 } }
local slowed = Runtime:CaptureFacts(
    { spellId = 5675, facts = promoted }, promoted)
assert(slowed.shamanManaSpringContract.exact
    and slowed.shamanManaSpringContract.period == 3,
    "root capture must apply exact activation-time modifiers")
modifiers[5677] = nil

local observed = Runtime:ObserveRoot()
assert(observed.available and observed.exact and observed.solo
    and not observed.grouped,
    "solo group membership must be captured exactly")
GetNumPartyMembers = function() return 1 end
local grouped = Runtime:ObserveRoot()
assert(grouped.available and grouped.exact and grouped.grouped
    and grouped.reason == "Mana Spring party fanout is unresolved",
    "grouped roots must preserve identity while refusing invented fanout")
GetNumPartyMembers = function() return 0 end

dofile("Graph/ShamanManaSpring.lua")
local Graph = XelAssist.Graph.ShamanManaSpring

local function state()
    return { time = 0, resource = 100, resourceMax = 200,
        resourceType = 0, playerResourceExact = true,
        actors = { player = { resource = 100 } },
        friendlies = { player = { resource = 100 },
            byUnit = { player = "player-guid" },
            byKey = { ["player-guid"] = { resource = 100 } } },
        totems = { available = true, playerGUID = "player-guid", bySlot = {
            [3] = { slot = 3, element = "water", haveTool = true,
                active = false, remaining = 0, exact = true },
        } },
        playerResourceClock = { phaseKnown = true, nextIn = 1,
            pendingSpendSpellId = 123 } }
end

local action = { spellId = 5675, actor = "player",
    facts = capturedByRank[5675] }
local downstream = action.facts.shamanTotemDownstream
local function projection(actionValue)
    return { kind = "totemPlacement", action = actionValue,
        playerGUID = "player-guid", slot = 3, element = "water",
        duration = 60, lifetime = { exact = true },
        downstreamSpellId = actionValue.spellId,
        downstreamElement = "water", effect = downstream.effect,
        range = downstream.range, recipients = downstream.recipients,
        admissible = true, classMechanic = "shaman" }
end

local root = state()
assert(Graph:Attach(root), "solo root evidence must attach before search")
local prepared, reason, handled = Graph:Prepare(root, projection(action))
assert(handled and prepared and not reason and prepared.shamanManaSpring,
    "fresh solo placement must prepare from sealed evidence")
local context = { state = root, action = action }
assert(Graph:Score(context, prepared) and context.value == 0
    and context.power == 0 and context.priority == nil,
    "Mana Spring must have no invented immediate utility or priority")

local row = root.totems.bySlot[3]
row.active, row.projected, row.spellId = true, true, action.spellId
row.remaining, row.duration = 60, 60
row.effect, row.range, row.recipients = downstream.effect,
    downstream.range, downstream.recipients
assert(Graph:Apply(root, prepared),
    "applied TotemState placement must arm an exact fresh tick phase")
assert(Graph:Advance(root, 1) == 0 and row.manaSpring.nextIn == 1,
    "partial elapsed time must preserve the exact next tick")
assert(Graph:Advance(root, 1) == 4 and root.resource == 104
    and root.actors.player.resource == 104
    and root.friendlies.player.resource == 104
    and root.friendlies.byKey["player-guid"].resource == 104,
    "the first two-second tick must add exact player mana everywhere")
assert(Graph:Advance(root, 4) == 8 and root.resource == 112,
    "aggregated elapsed time must apply every exact deterministic tick")

row.remaining, row.manaSpring.nextIn = 2, 2
assert(Graph:Advance(root, 2) == 4,
    "the server's final pre-unsummon update must retain the expiry tick")

root.resource, root.resourceMax = 198, 200
root.actors.player.resource = 198
root.friendlies.player.resource = 198
root.friendlies.byKey["player-guid"].resource = 198
row.remaining, row.manaSpring.nextIn = 10, 2
assert(Graph:Advance(root, 2) == 2 and root.resource == 200
    and root.playerResourceClock.phaseKnown == false
    and root.playerResourceClock.nextIn == nil,
    "mana-cap waste must not overfill and must retire the passive phase")

assert(Graph:AfterCandidate(root, { action = {
    actor = "player", facts = { movementSetup = true } } })
    and root.shamanManaSpring.rangeExact == false
    and row.manaSpring.rangeExact == false
    and Graph:Advance(root, 2) == 0,
    "player movement must stop projected ticks instead of inventing totem range")

local groupState = state()
GetNumPartyMembers = function() return 1 end
assert(Graph:Attach(groupState), "known grouped evidence still attaches")
prepared, reason, handled = Graph:Prepare(groupState, projection(action))
assert(handled and not prepared
    and reason == "Mana Spring party fanout is unresolved",
    "group fanout must fail closed before scoring")
GetNumPartyMembers = function() return 0 end

assert(Graph:ConsumerKey({ powerType = 0, cost = 20 }) == Graph.CONSUMER_KEY
    and Graph:ConsumerKey({ powerType = 1, cost = 20 }) == nil
    and Graph:StrategicSetup(capturedByRank[5675]).consumerKey
        == Graph.CONSUMER_KEY,
    "the setup lane must close only on a later mana-funded action")

local corruptedFacts = {}
for key, value in pairs(action.facts) do corruptedFacts[key] = value end
corruptedFacts.shamanManaSpringContract = {}
for key, value in pairs(action.facts.shamanManaSpringContract) do
    corruptedFacts.shamanManaSpringContract[key] = value
end
corruptedFacts.shamanManaSpringContract.amount = 999
local corrupted = { spellId = action.spellId, actor = "player",
    facts = corruptedFacts }
prepared, reason, handled = Graph:Prepare(root, projection(corrupted))
assert(handled and not prepared,
    "a branch-corrupted root contract must fail closed")

local pure = state()
assert(Graph:Attach(pure), "purity fixture must capture its root first")
local pureProjection = projection(action)
local savedDBC, savedMods, savedClass = GetSpellRecField,
    GetSpellModifiers, UnitClass
local savedRaid, savedParty = GetNumRaidMembers, GetNumPartyMembers
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
UnitClass = function() error("class read during graph search") end
GetNumRaidMembers = function() error("raid read during graph search") end
GetNumPartyMembers = function() error("party read during graph search") end
prepared = Graph:Prepare(pure, pureProjection)
assert(prepared and Graph:Score({ state = pure, action = action }, prepared),
    "graph descendants must use only root-sealed Mana Spring evidence")
local pureRow = pure.totems.bySlot[3]
pureRow.active, pureRow.projected, pureRow.spellId = true, true, action.spellId
pureRow.remaining, pureRow.duration = 60, 60
pureRow.effect, pureRow.range, pureRow.recipients = downstream.effect,
    downstream.range, downstream.recipients
assert(Graph:Apply(pure, prepared) and Graph:Advance(pure, 2) == 4,
    "apply and timeline projection must remain free of live API reads")
GetSpellRecField, GetSpellModifiers, UnitClass = savedDBC, savedMods, savedClass
GetNumRaidMembers, GetNumPartyMembers = savedRaid, savedParty

print("ok: exact Shaman Mana Spring fresh-phase mana consequences")
