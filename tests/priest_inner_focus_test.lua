XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function innerFocusRecord()
    return { school = 0, category = 0, castUI = 0, dispel = 1, mechanic = 0,
        attributes = 33882112,
        attributesEx = 0, attributesEx2 = 524288, attributesEx3 = 0,
        attributesEx4 = 0, stances = 134217728, stancesNot = 0,
        targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
        casterAuraState = 0, targetAuraState = 0,
        castingTimeIndex = 1, recoveryTime = 180000,
        categoryRecoveryTime = 0, interruptFlags = 0,
        auraInterruptFlags = 0, channelInterruptFlags = 0,
        procFlags = 87376, procChance = 100, procCharges = 1,
        maxLevel = 0, baseLevel = 0, spellLevel = 0, durationIndex = 21,
        powerType = 0, manaCost = 0, manaCostPerlevel = 0,
        manaCostPercentage = 0, rangeIndex = 1, speed = 0,
        modalNextSpell = 0, stackAmount = 0, equippedItemClass = -1,
        equippedItemSubClassMask = 0, equippedItemInventoryTypeMask = 0,
        startRecoveryCategory = 0, startRecoveryTime = 0,
        maxTargetLevel = 0,
        spellFamilyName = 6, spellFamilyFlags = 0,
        maxAffectedTargets = 0, dmgClass = 1, preventionType = 1,
        effect = triple(6, 6), effectDieSides = triple(1, 1),
        effectBaseDice = triple(1, 1),
        effectDicePerLevel = triple(), effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(-101, 24), effectMechanic = triple(),
        effectImplicitTargetA = triple(1, 1),
        effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(),
        effectApplyAuraName = triple(108, 107),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(),
        effectItemType = triple(3606577115, 3646176912),
        effectMiscValue = triple(14, 7), effectTriggerSpell = triple(),
        effectPointsPerComboPoint = triple() }
end

local function actionRecord(flags, attributesEx3)
    return { spellFamilyName = 6, spellFamilyFlags = flags,
        powerType = 0, attributesEx3 = attributesEx3 or 0 }
end

local records = {
    [14751] = innerFocusRecord(),
    [2054] = actionRecord(1024),
    [9000] = actionRecord(4),
    [9001] = actionRecord(1024),
    [9002] = actionRecord(16777216),
    [9003] = actionRecord(1),
    [9004] = actionRecord(1024, 536870912),
    [9005] = actionRecord(1),
    [133] = { spellFamilyName = 3, spellFamilyFlags = 1,
        powerType = 0, attributesEx3 = 0 },
}

local playerClass, aura, procActive = "PRIEST", nil, false
local dbcCalls, auraCalls, modifierCalls, costCalls = 0, 0, {}, {}
local modifierBase = { [2054] = { 0, 0 }, [9000] = { 0, 0 },
    [9001] = { 5, 0 }, [9002] = { 0, 0 }, [9003] = { 0, 0 },
    [9004] = { 0, 0 }, [9005] = { 0, 0 } }

local function unsigned(value)
    return value < 0 and value + 4294967296 or value
end

UnitClass = function() return "Localized", playerClass end
GetSpellName = function()
    error("Inner Focus mechanics must not inspect localized spell names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row or row[field] == nil then error("missing DBC field") end
    if copied and type(row[field]) == "table" then
        return { row[field][1], row[field][2], row[field][3] }
    end
    return row[field]
end
GetSpellModifiers = function(spellId, operation)
    modifierCalls[spellId] = (modifierCalls[spellId] or 0) + 1
    assert(operation == 14, "only the exact COST modifier may be queried")
    local pair = modifierBase[spellId]
    assert(pair, "unexpected modifier query")
    local flat, percent = pair[1], pair[2]
    if procActive and spellId ~= 9001 then percent = percent - 100 end
    local changed = flat ~= 0 or percent ~= 0
    return unsigned(flat), unsigned(percent), changed and 1 or 0
end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls[spellId] = (costCalls[spellId] or 0) + 1
    local costs = { [2054] = 155, [9001] = 90, [9003] = 0, [9005] = 60 }
    local cost = costs[spellId]
    assert(cost ~= nil, "unexpected effective-cost query")
    if procActive then return nil end
    return { { type = 0, cost = cost, minCost = cost, costPercent = 0,
        costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    auraCalls = auraCalls + 1
    assert(spellId == 14751, "aura capture must use the numeric identity")
    return aura
end }

dofile("Game/Player/PriestInnerFocus.lua")
dofile("Graph/PriestInnerFocus.lua")
local Evidence = XelAssist.Game.Player.PriestInnerFocus
local Graph = XelAssist.Graph.PriestInnerFocus

local inferred, reason, handled = Evidence:InferKnowledge(14751)
assert(inferred and reason == nil and handled
    and inferred.kind == "modifier" and inferred.kindExact
    and inferred.self and inferred.priestInnerFocus
    and inferred.priestInnerFocusEvidence.costMask == 3606577115
    and inferred.priestInnerFocusEvidence.critMask == 3646176912
    and inferred.priestInnerFocusEvidence.costPercent == -100
    and inferred.priestInnerFocusEvidence.critFlat == 25,
    "installed identity and both exact modifier shapes must be sealed")
assert(inferred.priority == nil and inferred.score == nil
    and inferred.rotation == nil and inferred.nextSpell == nil,
    "Inner Focus discovery must not encode a spell order")

local unknown
unknown, reason, handled = Evidence:InferKnowledge(2054)
assert(unknown == nil and not handled and reason == "spell is not Inner Focus",
    "ordinary Priest spells must fall through to generic knowledge")
playerClass = "MAGE"
local beforeDBC = dbcCalls
unknown, reason, handled = Evidence:InferKnowledge(14751)
assert(unknown == nil and not handled and dbcCalls == beforeDBC,
    "another exact class must be rejected before DBC access")
playerClass = "PRIEST"

Evidence:Invalidate()
records[14751].effectItemType[1] = 1
unknown, reason, handled = Evidence:InferKnowledge(14751)
assert(unknown == nil and handled
    and reason == "Inner Focus DBC topology is incomplete",
    "a recognized identity with changed family mask must fail closed")
records[14751].effectItemType[1] = 3606577115
Evidence:Invalidate()
inferred = Evidence:InferKnowledge(14751)

local state = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 }, resourceType = 0, resource = 500,
    actors = { player = { level = 20 } } }
assert(Evidence:Attach(state, "PRIEST")
    and state.priestInnerFocus.active == false
    and state.priestInnerFocus.profile.costPercent == -100
    and auraCalls == 1,
    "an exact absent numeric aura must seal an inactive root state")

local function action(spellId, facts)
    return { spellId = spellId, actor = "player", executor = "playerSpell",
        facts = facts or { kind = "heal" } }
end
local focusAction = action(14751, inferred)
local heal, unaffected, conflict, critOnly, zeroCost, ignored, unseen =
    action(2054), action(9000), action(9001), action(9002), action(9003),
    action(9004), action(9005)

local healFacts = Evidence:CaptureFacts(heal, { cost = 999, average = 320 }, state)
assert(healFacts.priestInnerFocusCost.exact
    and healFacts.priestInnerFocusCost.costAffected
    and healFacts.priestInnerFocusCost.baselineCost == 155
    and healFacts.priestInnerFocusCost.critFlatUnvalued == 25
    and healFacts.cost == 155,
    "engine cost and matching DBC mask must override an inexact tooltip cost")
assert(Graph:PotentialConsumer(healFacts),
    "exact future cost savings must expose a mechanics-only setup consumer")

local unaffectedFacts = Evidence:CaptureFacts(
    unaffected, { cost = 40 }, state)
assert(unaffectedFacts.priestInnerFocusCost.exact
    and not unaffectedFacts.priestInnerFocusCost.costAffected,
    "a spell outside both installed masks must remain exactly unaffected")
local conflictFacts = Evidence:CaptureFacts(conflict, { cost = 90 }, state)
assert(not conflictFacts.priestInnerFocusCost.exact
    and conflictFacts.priestInnerFocusCost.reason
        == "another Priest COST modifier is active",
    "a simultaneous COST regime must fail closed")
local critFacts = Evidence:CaptureFacts(critOnly, { cost = 50 }, state)
assert(not critFacts.priestInnerFocusCost.exact
    and critFacts.priestInnerFocusCost.reason
        == "Inner Focus critical-only consequence is unmodeled",
    "a critical-only family match must not fabricate expected power")
local zeroFacts = Evidence:CaptureFacts(zeroCost, { cost = 0 }, state)
assert(not zeroFacts.priestInnerFocusCost.exact
    and zeroFacts.priestInnerFocusCost.reason
        == "positive Priest mana cost unavailable",
    "a zero-cost family match must stay unresolved until consumption is proven")
local ignoredFacts = Evidence:CaptureFacts(ignored, { cost = 50 }, state)
assert(ignoredFacts.priestInnerFocusCost.exact
    and not ignoredFacts.priestInnerFocusCost.costAffected,
    "IGNORE_CASTER_MODIFIERS must override the family-mask intersection")

local setupTooltip = {}
for key, value in pairs(inferred) do setupTooltip[key] = value end
setupTooltip.cost = 0
local prepared, setupReason, setupHandled = Graph:PrepareLegal(
    focusAction, state, setupTooltip)
assert(setupHandled and setupReason == nil and prepared
    and prepared ~= setupTooltip and prepared.cost == 0
    and prepared.priestInnerFocusTransition.evidenceExact
    and prepared.priestInnerFocusTransition.critFlatUnvalued == 25,
    "the exact zero-cost action must create a copied one-charge transition")
local scoreContext = { tooltip = prepared, power = 999,
    expectedPower = 999, effectivePower = 999, value = 999 }
assert(Graph:Score(scoreContext)
    and scoreContext.value == 0 and scoreContext.power == 0
    and scoreContext.estimated == false,
    "setup must carry no fixed utility or typed ordering")

dofile("Game/ActionInference.lua")
local catalogFacts, catalogReason, catalogHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(14751)
assert(catalogFacts and catalogHandled and catalogReason == nil
    and catalogFacts.priestInnerFocus,
    "the production action-inference boundary must discover Inner Focus")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassMechanics.lua")
local mechanics = XelAssist.Graph.ClassMechanics
local integratedFacts = mechanics:CaptureFacts(
    heal, { cost = 999, average = 320 }, state)
assert(integratedFacts.priestInnerFocusCost
    and integratedFacts.priestInnerFocusCost.exact,
    "the production class-evidence boundary must seal affected costs")
local integrated, integratedReason, integratedHandled = mechanics:Prepare(
    focusAction, state, { unit = "player", relation = "self" }, prepared)
local integratedContext = { action = focusAction, state = state,
    tooltip = prepared }
assert(integrated and integratedHandled and integratedReason == nil
    and integrated.classMechanic == "priestInnerFocus"
    and mechanics:Score(integratedContext, integrated)
    and integratedContext.value == 0,
    "the class-mechanic boundary must retain consequence-only setup scoring")
local integratedChild = { time = 0 }
assert(mechanics:Copy(state, integratedChild)
    and mechanics:Apply(integratedChild, { action = focusAction,
        classMechanicProjection = integrated })
    and integratedChild.priestInnerFocus.active,
    "the production copy/apply boundary must arm only the selected branch")

local child = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 } }
assert(Graph:Copy(state, child)
    and child.priestInnerFocus ~= state.priestInnerFocus
    and child.priestInnerFocus.profile ~= state.priestInnerFocus.profile,
    "graph branches must own independent modifier snapshots")
assert(Graph:Apply(child, { action = focusAction, tooltip = prepared })
    and child.priestInnerFocus.active and child.priestInnerFocus.projected,
    "the chosen exact setup must arm one branch")
assert(not state.priestInnerFocus.active,
    "projecting one branch must not mutate its sibling root")

local free, freeReason, freeHandled = Graph:PrepareLegal(
    heal, child, healFacts)
assert(freeHandled and freeReason == nil and free.cost == 0
    and free.priestInnerFocusConsumption
    and healFacts.priestInnerFocusConsumption == nil,
    "an affected future heal must use the captured zero cost")
local unchanged = Graph:PrepareLegal(unaffected, child, unaffectedFacts)
assert(unchanged == unaffectedFacts and unchanged.cost == 40,
    "an unaffected spell must not consume or gain the charge")
local blocked, blockedReason, blockedHandled = Graph:PrepareLegal(
    critOnly, child, critFacts)
assert(blocked == nil and blockedHandled
    and blockedReason == "Inner Focus critical-only consequence is unmodeled",
    "an active charge must block a consumer whose benefit is incomplete")
assert(Graph:Consume(child, { action = heal, tooltip = free, cost = 0 })
    and not child.priestInnerFocus.active
    and child.priestInnerFocus.consumed
    and child.priestInnerFocus.savedMana == 155,
    "a successful affected action must consume the charge exactly once")
prepared, setupReason, setupHandled = Graph:PrepareLegal(
    heal, child, healFacts)
assert(setupHandled and setupReason == nil and prepared.cost == 155,
    "after consumption the ordinary captured cost must be restored")

procActive = true
aura = { spellId = 14751, isHelpful = true, applications = 1,
    duration = 0, expirationTime = 0 }
local activeRoot = { time = 0, actors = { player = { level = 20 } } }
assert(Evidence:Attach(activeRoot, "PRIEST")
    and activeRoot.priestInnerFocus.active,
    "a permanent active aura needs exact identity, not fabricated expiry")
local activeFacts = Evidence:CaptureFacts(heal, { cost = 0 }, activeRoot)
assert(activeFacts.priestInnerFocusCost.exact
    and activeFacts.priestInnerFocusCost.costAffected
    and activeFacts.priestInnerFocusCost.baselineCost == 155,
    "a prior clean baseline plus exact -100 delta must support active roots")
local unseenFacts = Evidence:CaptureFacts(unseen, { cost = 0 }, activeRoot)
assert(not unseenFacts.priestInnerFocusCost.exact
    and unseenFacts.priestInnerFocusCost.reason
        == "Inner Focus baseline or active cost delta unavailable",
    "an active root without a learned baseline must fail closed")

aura = { spellId = nil, isHelpful = true, applications = 1 }
assert(not Evidence:Attach(activeRoot, "PRIEST")
    and activeRoot.priestInnerFocus.reason
        == "active Inner Focus aura identity is incomplete",
    "malformed active aura evidence must invalidate the root")

-- Seal a fresh branch before making every mutable API fatal.
aura, procActive = nil, false
assert(Evidence:Attach(state, "PRIEST"))
healFacts = Evidence:CaptureFacts(heal, { cost = 155 }, state)
prepared = Graph:PrepareLegal(focusAction, state, setupTooltip)
local pureChild = { time = 0 }
local savedDBC, savedMods, savedCosts, savedAuras = GetSpellRecField,
    GetSpellModifiers, C_Spell.GetSpellPowerCost,
    C_UnitAuras.GetPlayerAuraBySpellID
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
C_Spell.GetSpellPowerCost = function() error("cost read during graph search") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("aura read during graph search")
end
assert(Graph:Copy(state, pureChild)
    and Graph:Apply(pureChild, { action = focusAction, tooltip = prepared }))
free = Graph:PrepareLegal(heal, pureChild, healFacts)
assert(free and free.cost == 0
    and Graph:Consume(pureChild, { action = heal, tooltip = free, cost = 0 }),
    "copy, activation, cost adjustment and consumption must be search-pure")
GetSpellRecField, GetSpellModifiers, C_Spell.GetSpellPowerCost,
    C_UnitAuras.GetPlayerAuraBySpellID =
    savedDBC, savedMods, savedCosts, savedAuras

print("ok: Priest Inner Focus projects exact one-charge mana consequences")
