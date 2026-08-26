-- Fade must be inferred from exact numeric DBC topology, freeze its scaled
-- amount and duration at the root, and project VMaNGOS temporary-threat
-- recipient/application/expiration semantics without a typed action order.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(values) return #values end

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local ranks = {
    [586] = { rank = 1, baseLevel = 8, spellLevel = 8,
        maxLevel = 18, manaCost = 40, base = -56 },
    [9578] = { rank = 2, baseLevel = 20, spellLevel = 20,
        maxLevel = 30, manaCost = 75, base = -156 },
    [9579] = { rank = 3, baseLevel = 30, spellLevel = 30,
        maxLevel = 40, manaCost = 125, base = -286 },
    [9592] = { rank = 4, baseLevel = 40, spellLevel = 40,
        maxLevel = 50, manaCost = 175, base = -441 },
    [10941] = { rank = 5, baseLevel = 50, spellLevel = 50,
        maxLevel = 60, manaCost = 225, base = -621 },
    [10942] = { rank = 6, baseLevel = 60, spellLevel = 60,
        maxLevel = 70, manaCost = 275, base = -821 },
}

local common = {
    school = 5, category = 82, dispel = 1, mechanic = 0,
    attributes = 327680, attributesEx = 1024, attributesEx2 = 524288,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    targets = 0, casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 30000,
    interruptFlags = 8, auraInterruptFlags = 0, channelInterruptFlags = 0,
    durationIndex = 1, powerType = 0, manaCostPerlevel = 0,
    manaCostPercentage = 0, rangeIndex = 1, spellFamilyName = 6,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    spellFamilyFlags = 16384, maxAffectedTargets = 0, dmgClass = 1,
    preventionType = 1,
}

local rows = {}
for id, rank in pairs(ranks) do
    local row, key, value = {}, nil, nil
    for key, value in pairs(common) do row[key] = value end
    row.baseLevel, row.spellLevel, row.maxLevel = rank.baseLevel,
        rank.spellLevel, rank.maxLevel
    row.manaCost = rank.manaCost
    row.effect, row.effectDieSides = triple(6, 6), triple(1, 1)
    row.effectBaseDice, row.effectDicePerLevel = triple(1, 1), triple()
    row.effectRealPointsPerLevel = triple(0, -3)
    row.effectBasePoints = triple(-16, rank.base)
    row.effectMechanic = triple()
    row.effectImplicitTargetA, row.effectImplicitTargetB =
        triple(1, 1), triple()
    row.effectRadiusIndex, row.effectApplyAuraName = triple(), triple(4, 4)
    row.effectAmplitude, row.effectMultipleValue = triple(), triple()
    row.effectChainTarget, row.effectItemType = triple(), triple()
    row.effectMiscValue, row.effectTriggerSpell = triple(), triple()
    row.effectPointsPerComboPoint = triple()
    rows[id] = row
end

local class, level, dbcReads = "PRIEST", 8, 0
local liveDuration, modifierFlat, modifierPercent, modifierChanged =
    10000, 0, 0, 0
function UnitClass() return "Priest", class end
function UnitLevel() return level end
function GetSpellRecField(spellId, field, copied)
    dbcReads = dbcReads + 1
    local value = rows[spellId] and rows[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(_, ignoreModifiers)
    return ignoreModifiers and 10000 or liveDuration
end
function GetSpellModifiers()
    return modifierFlat, modifierPercent, modifierChanged
end

dofile("Game/Player/PriestFade.lua")
local Runtime = XelAssist.Game.Player.PriestFade

local ids = { 586, 9578, 9579, 9592, 10941, 10942 }
local actions, captures, index, id = {}, {}, nil, nil
for index = 1, table.getn(ids) do
    id = ids[index]
    local rank = ranks[id]
    local found, reason, handled = Runtime:Classify(id)
    assert(handled and not reason and found.valid and found.exact
        and found.rank == rank.rank and found.baseLevel == rank.baseLevel
        and found.spellLevel == rank.spellLevel
        and found.maxLevel == rank.maxLevel
        and found.baseManaCost == rank.manaCost
        and found.signedBaseThreat == rank.base + 1
        and found.signedThreatPerLevel == -3
        and found.recipient == "caster-hostile-references"
        and found.appliesOnlyExistingReferences
        and found.requiresZeroTemporaryModifier,
        "every installed rank must bind the exact self-dummy topology")
    local facts, inferReason, claimed = Runtime:InferKnowledge(id)
    assert(claimed and not inferReason and facts.kind == "threatDrop"
        and facts.kindExact and facts.self and facts.priestFade
        and facts.threatDropModel == "temporary-flat"
        and facts.resourceType == "mana" and facts.submissionGuarded
        and facts.runtimeUnverified,
        "exact inference must describe mechanics without an action priority")
    level = rank.maxLevel
    local action = { name = "localized-irrelevant-" .. tostring(id),
        spellId = id, actor = "player", facts = facts }
    local captured = Runtime:CaptureFacts(action, facts)
    local contract = Runtime:CapturedEvidence(captured)
    local expected = -(rank.base + 1
        + (rank.maxLevel - rank.spellLevel) * -3)
    assert(contract and contract.amount == expected
        and contract.duration == 10 and contract.playerLevel == rank.maxLevel
        and contract.effectiveLevel == rank.maxLevel
        and contract.appliesOnlyExistingReferences
        and contract.requiresZeroTemporaryModifier
        and contract.removalVisitsCurrentReferences
        and contract.runtimeVerified == false
        and captured.threatDropAmount == expected
        and captured.threatDropDuration == 10,
        "root capture must freeze exact level scaling and lifetime")
    actions[id], captures[id] = action, captured
end

level = 255
local capped = Runtime:CaptureFacts(actions[10942], actions[10942].facts)
assert(Runtime:CapturedEvidence(capped).amount == 850,
    "the final rank must cap effect scaling at its DBC max level")

local unknown, unknownReason, unknownHandled = Runtime:Classify(99999)
assert(not unknown and not unknownHandled
    and unknownReason == "not an installed Fade identity",
    "unrelated numeric identities must remain unclaimed")
local reads = dbcReads
class = "MAGE"
local wrongClass, wrongReason, wrongHandled = Runtime:InferKnowledge(586)
assert(not wrongClass and not wrongHandled
    and wrongReason == "player is not an exactly identified Priest"
    and dbcReads == reads,
    "wrong-class inference must not read or claim Priest mechanics")
class = "PRIEST"

Runtime:Invalidate()
rows[9578].effectApplyAuraName = triple(4, 103)
local invalid, invalidReason, invalidHandled = Runtime:Classify(9578)
assert(invalidHandled and invalid and not invalid.valid
    and invalidReason == "Fade DBC topology is incomplete",
    "a recognized conflicting topology must fail closed")
rows[9578].effectApplyAuraName = triple(4, 4)
local cachedInvalid, cachedReason, cachedHandled = Runtime:Classify(9578)
assert(cachedHandled and cachedInvalid and not cachedInvalid.valid
    and cachedReason == invalidReason,
    "cached invalid rows must remain recognized on repeated calls")
Runtime:Invalidate()
assert(Runtime:Classify(9578).valid,
    "explicit invalidation must permit a fresh exact root capture")

level, modifierFlat, modifierChanged = 8, 1, 1
local unsupported = Runtime:CaptureFacts(actions[586], actions[586].facts)
assert(not Runtime:CapturedEvidence(unsupported)
    and unsupported.priestFadeContract.recognized
    and unsupported.priestFadeContract.reason
        == "Fade has unsupported duration or effect modifiers"
    and unsupported.threatDropAmount == nil,
    "unsupported effect modifiers must seal an unusable contract")
modifierFlat, modifierChanged = 0, 0
local fadeFacts = Runtime:CaptureFacts(actions[586], actions[586].facts)
assert(Runtime:CapturedEvidence(fadeFacts).amount == 55,
    "rank one must preserve its exact level-eight magnitude")

XelAssist.Graph.State = {
    RefreshHostileRecord = function(_, state, key)
        state.refreshed = state.refreshed or {}
        table.insert(state.refreshed, key)
    end,
    SyncActiveHostile = function(_, state)
        state.synced = true
        state.hasAggro = nil
        state.targetPlayerThreatDeltaExact = false
    end,
}
dofile("Graph/PriestFade.lua")
local Graph = XelAssist.Graph.PriestFade

local function threat(aggro, reference)
    return { available = true, playerHasAggro = aggro,
        playerReferenceKnown = reference ~= nil,
        playerReference = reference, playerDelta = 0,
        playerDeltaExact = true }
end

local function hostile(key, guid, aggro, reference)
    return { key = key, guid = guid, dead = false,
        selected = key == "selected", hasPlayerAggro = aggro,
        threat = threat(aggro, reference) }
end

local function state()
    local selected = hostile("selected", "guid-selected", true, true)
    local healer = hostile("healer", "guid-healer", false, true)
    local absent = hostile("absent", "guid-absent", false, false)
    local unknownRef = hostile("unknown", "guid-unknown", false, nil)
    local competing = hostile("competing", "guid-competing", true, true)
    competing.threat.playerThreatOffset = { amount = -10, remaining = 20,
        exact = true, model = "temporary-flat", sourceSpellId = 26400 }
    return { inCombat = true, tank = false, time = 12,
        hasAggro = true, targetPlayerThreatDeltaExact = true,
        hostiles = { order = { "selected", "healer", "absent",
            "unknown", "competing" }, selectedKey = "selected",
            capped = false, discoveryComplete = false, byKey = {
                selected = selected, healer = healer, absent = absent,
                unknown = unknownRef, competing = competing } } }
end

local action = actions[586]
local tooltip = fadeFacts
local descriptor = { unit = "player", relation = "self", source = "self" }

local saved = { UnitClass, UnitLevel, GetSpellRecField,
    GetSpellDuration, GetSpellModifiers }
UnitClass = function() error("class read during graph search") end
UnitLevel = function() error("level read during graph search") end
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end

local source = state()
local context = { action = action, state = source, descriptor = descriptor,
    tooltip = tooltip, effectDelivery = 1 }
assert(Graph:Score(context) and context.value == 55
    and context.priestFadeThreatReduction == 55
    and context.priestFadeRecipients == 3
    and context.priestFadeApplicable == 2 and context.estimated
    and context.reason == "temporarily lowers threat on current attackers",
    "Fade value must arise from exact current unwanted-aggro consequences")

local tank = state()
tank.tank = true
local tankContext = { action = action, state = tank, descriptor = descriptor,
    tooltip = tooltip, effectDelivery = 1 }
assert(Graph:Score(tankContext) and tankContext.value == -110
    and tankContext.reason == "preserves current tank threat",
    "the same exact threat loss must be harmful to a tank")

local projected = state()
assert(Graph:Apply(projected, { action = action, tooltip = tooltip,
    target = "player", targetRelation = "self", targetSource = "self",
    effectDelivery = 1 }),
    "a proven self application must create the exact temporary lifecycle")
assert(projected.priestFade and projected.priestFade.remaining == 10
    and table.getn(projected.priestFade.recipients) == 2
    and projected.hostiles.byKey.selected.threat.playerThreatOffset.amount == -55
    and projected.hostiles.byKey.healer.threat.playerThreatOffset.amount == -55
    and projected.hostiles.byKey.absent.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.unknown.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.competing.threat.playerThreatOffset.amount == -10,
    "application must snapshot only proven zero-modifier player references")
local activeBlock, activeHandled = Graph:Blocker(
    action, projected, descriptor, tooltip)
assert(activeHandled and activeBlock == "Fade is already active",
    "an active projected Fade must prevent a second lifecycle")

projected.hostiles.byKey.later = hostile("later", "guid-later", true, true)
table.insert(projected.hostiles.order, "later")
assert(Graph:Advance(projected, 4)
    and projected.priestFade.remaining == 6
    and projected.hostiles.byKey.selected.threat.playerThreatOffset.remaining == 6
    and projected.hostiles.byKey.later.threat.playerThreatOffset == nil,
    "hostiles acquired after application must not inherit Fade")
projected.hostiles.byKey.later.threat.playerThreatOffset = {
    amount = -25, remaining = 8, exact = true,
    model = "temporary-flat", sourceSpellId = 28862 }
assert(Graph:Advance(projected, 6) and projected.priestFade == nil
    and projected.hostiles.byKey.selected.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.healer.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.competing.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.later.threat.playerThreatOffset == nil
    and projected.hostiles.byKey.later.threat
        .projectedTemporaryThreatResetByFade,
    "expiration must reset every then-current temporary modifier like VMaNGOS")

local copiedSource = state()
assert(Graph:Apply(copiedSource, { action = action, tooltip = tooltip,
    target = "player", targetRelation = "self", targetSource = "self",
    effectDelivery = 1 }))
local copied = {}
Graph:Copy(copiedSource, copied)
copied.priestFade.recipients[1].key = "changed"
assert(copiedSource.priestFade.recipients[1].key ~= "changed",
    "Fade lifecycle copy must not alias recipient identities")

local unavailable = state()
local badTooltip = {}
for key, value in pairs(tooltip) do badTooltip[key] = value end
badTooltip.priestFadeContract = { recognized = true, valid = false,
    exact = false, spellId = 586, model = "temporary-flat" }
local badBlock, badHandled = Graph:Blocker(
    action, unavailable, descriptor, badTooltip)
assert(badHandled and badBlock == "Fade root evidence unavailable",
    "recognized incomplete root evidence must fail closed")
local badContext = { action = action, state = unavailable,
    descriptor = descriptor, tooltip = badTooltip, effectDelivery = 1 }
assert(Graph:Score(badContext) and badContext.value == -100000,
    "incomplete evidence must not receive generic utility")

UnitClass, UnitLevel, GetSpellRecField, GetSpellDuration,
    GetSpellModifiers = saved[1], saved[2], saved[3], saved[4], saved[5]

print("ok: Priest Fade uses exact rank, recipient, and temporary-threat lifecycle evidence")
