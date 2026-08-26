-- Preparation uses numeric build-5875 DBC and VMaNGOS's exact reset predicate.
-- Localized spell labels never participate in classification or graph value.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {
    [14185] = {
        school = 0, category = 0, dispel = 0, mechanic = 0,
        attributes = 262160, attributesEx = 32, attributesEx2 = 0,
        attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
        recoveryTime = 420000, categoryRecoveryTime = 0,
        interruptFlags = 0, auraInterruptFlags = 0,
        channelInterruptFlags = 0, procFlags = 0, procChance = 101,
        procCharges = 0, durationIndex = 0, powerType = 0,
        manaCost = 0, manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 1,
        spellFamilyName = 0, spellFamilyFlags = 0,
        startRecoveryCategory = 133, startRecoveryTime = 1000,
        maxAffectedTargets = 0, effect = triple(3),
        effectBasePoints = triple(), effectDieSides = triple(),
        effectImplicitTargetA = triple(1),
        effectImplicitTargetB = triple(),
        effectApplyAuraName = triple(), effectAmplitude = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
    },
    [2983] = { spellFamilyName = 8,
        recoveryTime = 300000, categoryRecoveryTime = 0 },
    [1856] = { spellFamilyName = 8,
        recoveryTime = 0, categoryRecoveryTime = 300000 },
    [5277] = { spellFamilyName = 8,
        recoveryTime = 300000, categoryRecoveryTime = 0 },
    [1752] = { spellFamilyName = 8,
        recoveryTime = 0, categoryRecoveryTime = 0 },
    [20554] = { spellFamilyName = 0,
        recoveryTime = 120000, categoryRecoveryTime = 0 },
    [9999] = { spellFamilyName = 8, recoveryTime = 120000 },
}

local dbcCalls = 0
function GetSpellRecField(spellId, field, asArray)
    dbcCalls = dbcCalls + 1
    local record = records[spellId]
    if not record then return nil end
    local value = record[field]
    if asArray then return value end
    return value
end

function GetSpellDuration(spellId)
    assert(spellId == 14185, "only Preparation duration is queried")
    return 0
end

function UnitClass(unit)
    assert(unit == "player")
    return "Rogue", "ROGUE"
end

XelAssist = { Game = { Player = {} }, Graph = {} }
dofile("Game/Player/RoguePreparation.lua")
local Runtime = XelAssist.Game.Player.RoguePreparation

local inferred, reason, handled = Runtime:InferKnowledge(14185)
assert(handled and not reason and inferred and inferred.kind == "modifier"
    and inferred.roguePreparation == true
    and inferred.roguePreparationEvidence.family == 8
    and inferred.roguePreparationEvidence.cooldown == 420
    and inferred.roguePreparationEvidence.gcd == 1,
    "Preparation must be claimed only from exact numeric topology")

local foreign, _, foreignHandled = Runtime:InferKnowledge(2983)
assert(foreign == nil and foreignHandled == false,
    "ordinary Rogue spells must remain available to other inference")

local function action(spellId, slot, facts)
    return { name = "localized display " .. tostring(slot), spellId = spellId,
        slot = slot, bookType = "spell", actor = "player",
        executor = "playerSpell", facts = facts or { kind = "damage" } }
end

local preparation = action(14185, 1, inferred)
local sprint = action(2983, 2, { kind = "modifier" })
local vanish = action(1856, 3, { kind = "modifier" })
local evasion = action(5277, 4, { kind = "defensive" })
local strike = action(1752, 5)
local racial = action(20554, 6, { kind = "modifier" })
local malformed = action(9999, 7)

local function capture(found, base)
    return Runtime:CaptureFacts(found, base or {
        cost = 10, cast = 0, gcd = 1, cooldown = 1 })
end

local facts = {
    [preparation] = capture(preparation, { cost = nil, cast = 0,
        gcd = nil, cooldown = 420 }),
    [sprint] = capture(sprint), [vanish] = capture(vanish),
    [evasion] = capture(evasion), [strike] = capture(strike),
    [racial] = capture(racial), [malformed] = capture(malformed),
}

assert(Runtime:CooldownContract(facts[sprint]).eligible == true
    and Runtime:CooldownContract(facts[vanish]).eligible == true,
    "direct and category recovery both contribute to GetRecoveryTime")
assert(Runtime:CooldownContract(facts[strike]).eligible == false
    and Runtime:CooldownContract(facts[racial]).eligible == false,
    "Rogue family and positive effective recovery are both required")
assert(Runtime:CooldownContract(facts[malformed]) == nil
    and facts[malformed].roguePreparationCooldown.complete == false,
    "an incomplete server predicate must be claimed but fail closed")
assert(facts[preparation].cost == 0 and facts[preparation].powerType == 0
    and facts[preparation].cast == 0 and facts[preparation].gcd == 1
    and facts[preparation].cooldown == 420,
    "Preparation's exact cost and timing must be root sealed")

dofile("Graph/CooldownLedger.lua")
local Ledger = XelAssist.Graph.CooldownLedger
local rootActions = {
    preparation, sprint, vanish, evasion, strike, racial,
}
XelAssist.Graph.RootObservation = {}
function XelAssist.Graph.RootObservation:Actions(state)
    return state.rootActions, "known"
end
function XelAssist.Graph.RootObservation:Facts(state, found)
    local sealed = state.rootFacts[found]
    return sealed, sealed and "known" or "unknown"
end

dofile("Graph/RoguePreparation.lua")
local Graph = XelAssist.Graph.RoguePreparation

local state = { time = 2, actorReadyAt = { player = 5 },
    playerGcdReadyAt = 8, readyAt = {}, rootActions = rootActions,
    rootFacts = facts, cooldownLedger = { records = {}, order = {} } }
local function cooldown(found, readyAt)
    local key = Ledger:ActionKey(found)
    state.cooldownLedger.records[key] = { known = true, key = key,
        readyAt = readyAt }
    state.readyAt[key] = readyAt
    return key
end

local preparationKey = cooldown(preparation, 0)
local sprintKey = cooldown(sprint, 20)
local vanishKey = cooldown(vanish, 30)
local evasionKey = cooldown(evasion, 7)
local strikeKey = cooldown(strike, 0)
local racialKey = cooldown(racial, 40)
state.readyAt[evasionKey], state.readyAt[strikeKey] = nil, nil
state.readyAt["group:77"] = 45

local capturedCalls = dbcCalls
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitClass = function() error("class read during graph search") end

local noTime, noTimeReason, noTimeHandled = Graph:Prepare(
    preparation, state, facts[preparation])
assert(noTime == nil and noTimeHandled
    and noTimeReason == "Preparation exact application time unavailable",
    "Preparation must fail closed without Targets' exact action start")

local projection, prepareReason, prepareHandled = Graph:Prepare(
    preparation, state, facts[preparation], 8)
assert(prepareHandled and not prepareReason and projection
    and projection.classMechanic == "roguePreparation",
    "the exact root catalogue must produce a Preparation transition")
local transition = projection.roguePreparationTransition
assert(table.getn(transition.catalogueSpellIds) == 3
    and transition.catalogueSpellIds[1] == 1856
    and transition.catalogueSpellIds[2] == 2983
    and transition.catalogueSpellIds[3] == 5277
    and table.getn(transition.changed) == 2
    and transition.changed[1].spellId == 1856
    and transition.changed[2].spellId == 2983,
    "only Rogue cooldowns still delayed at application may change")
assert(dbcCalls == capturedCalls,
    "graph preparation must consume sealed facts without live DBC reads")

local context = { power = 99, expectedPower = 99, effectivePower = 99,
    value = 999, estimated = true }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.estimated == false,
    "Preparation must have no fixed utility independent of consumers")
local setup = Graph:StrategicSetup(projection)
assert(setup and setup.consumerKey == Graph.CONSUMER_KEY,
    "the exact reset must open one bounded consequence lane")

dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassActionMechanics.lua")
dofile("Graph/ClassMechanics.lua")
local Mechanics = XelAssist.Graph.ClassMechanics
local earlyBlocker, earlyHandled = Mechanics:Blocker(
    preparation, state, { unit = "player", relation = "self" },
    facts[preparation])
assert(earlyBlocker == nil and earlyHandled == false,
    "pre-admission class blocking must defer exact-time Preparation")
local integrated, integratedReason, integratedHandled = Mechanics:Prepare(
    preparation, state, { unit = "player", relation = "self" },
    facts[preparation], 8)
local integratedContext = { action = preparation, state = state,
    tooltip = integrated }
assert(integrated and integratedHandled and integratedReason == nil
    and Mechanics:Score(integratedContext, integrated)
    and integratedContext.value == 0,
    "the production class boundary must preserve reset-only setup value")

dofile("Graph/Candidate.lua")
local setupCandidate = XelAssist.Graph.Candidate:Build({
    action = preparation, state = state, facts = facts[preparation],
    tooltip = integrated, value = 0, descriptor = {
        unit = "player", relation = "self" },
})
assert(setupCandidate.strategicSetup == true
    and setupCandidate.strategicSetupConsumerKey == Graph.CONSUMER_KEY,
    "production candidate serialization must retain the exact reset lane")

state.time = 8
local candidate = { action = preparation, tooltip = projection,
    classMechanicProjection = projection }
assert(Graph:Apply(state, candidate),
    "the exact transition must clear changed action clocks")
assert(state.readyAt[sprintKey] == 8 and state.readyAt[vanishKey] == 8
    and state.readyAt[evasionKey] == nil and state.readyAt[strikeKey] == nil
    and state.readyAt[racialKey] == 40
    and state.readyAt[preparationKey] == 0,
    "only clocks selected by the server predicate may clear")
assert(state.readyAt["group:77"] == 45,
    "unowned shared-category clocks must remain conservative")
assert(Graph:RootCooldownCleared(state, sprint, facts[sprint])
    and Graph:RootCooldownCleared(state, vanish, facts[vanish])
    and not Graph:RootCooldownCleared(state, evasion, facts[evasion])
    and not Graph:RootCooldownCleared(state, racial, facts[racial]),
    "immutable root cooldowns may be bypassed only for changed actions")
assert(Graph:ConsumerKey(state, sprint, facts[sprint]) == Graph.CONSUMER_KEY
    and Graph:ConsumerKey(state, vanish, facts[vanish]) == Graph.CONSUMER_KEY
    and Graph:ConsumerKey(state, evasion, facts[evasion]) == nil,
    "only a spell made ready by Preparation may close the setup lane")
local consumerCandidate = XelAssist.Graph.Candidate:Build({
    action = sprint, state = state, facts = facts[sprint],
    tooltip = facts[sprint], value = 1, descriptor = {
        unit = "player", relation = "self" },
})
assert(consumerCandidate.setupConsumerKey == Graph.CONSUMER_KEY,
    "production candidate serialization must identify the changed consumer")
local path = { state = state, strategicSetupOpen = true,
    strategicSetupConsumerKey = Graph.CONSUMER_KEY }
assert(Graph:PotentialConsumer(path, sprint, facts[sprint])
    and not Graph:PotentialConsumer(path, evasion, facts[evasion]),
    "consumer filtering must be branch-local to the changed set")
dofile("Graph/ResourceInvestment.lua")
assert(XelAssist.Graph.ResourceInvestment:PotentialConsumer(
        path, sprint, facts[sprint])
    and not XelAssist.Graph.ResourceInvestment:PotentialConsumer(
        path, evasion, facts[evasion]),
    "production setup filtering must retain only reset consumers")

function XelAssist.Graph.RootObservation:ActionRecord(observedState, found)
    return { cooldown = { applicable = true, known = true, remaining = 22 },
        facts = observedState.rootFacts[found] }, "known"
end
XelAssist.Game.SpellClassification = {
    NormalGcd = function() return true end,
}
dofile("Graph/ActionAdmission.lua")
state.resource, state.playerResourceReserved = 100, 0
assert(XelAssist.Graph.ActionAdmission:Readiness(
        sprint, state, facts[sprint], 8) == nil,
    "production admission must honor the branch-local reset marker")

local copied = {}
assert(Mechanics:Copy(state, copied)
    and copied.roguePreparationReset ~= state.roguePreparationReset
    and copied.roguePreparationReset.keys ~= state.roguePreparationReset.keys
    and copied.roguePreparationReset.keys[sprintKey],
    "Preparation reset ownership must copy without branch aliasing")

local incomplete = { time = 2, readyAt = {},
    rootActions = { preparation, malformed }, rootFacts = facts,
    cooldownLedger = { records = {}, order = {} } }
local function incompleteCooldown(found, readyAt)
    local key = Ledger:ActionKey(found)
    incomplete.cooldownLedger.records[key] = { known = true,
        key = key, readyAt = readyAt }
    incomplete.readyAt[key] = readyAt
end
incompleteCooldown(preparation, 0); incompleteCooldown(malformed, 20)
local missing, missingReason, missingHandled = Graph:Prepare(
    preparation, incomplete, facts[preparation], 2)
assert(missing == nil and missingHandled
    and missingReason == "root Preparation reset classification unavailable",
    "one incomplete catalogue spell must fail the exact reset closed")

local readyState = { time = 2, readyAt = {}, rootActions = rootActions,
    rootFacts = facts, cooldownLedger = { records = {}, order = {} } }
local _, found
for _, found in pairs(rootActions) do
    local key = Ledger:ActionKey(found)
    readyState.cooldownLedger.records[key] = { known = true,
        key = key, readyAt = 0 }
end
local none, noneReason, noneHandled = Graph:Prepare(
    preparation, readyState, facts[preparation], 2)
assert(none == nil and noneHandled
    and noneReason == "no resettable Rogue cooldown is delayed",
    "already-ready spells must never manufacture Preparation value")

print("ok: Preparation value emerges only through changed Rogue cooldowns")
