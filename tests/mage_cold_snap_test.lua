-- Cold Snap uses numeric build-5875 DBC and the exact VMaNGOS reset predicate.
-- No localized spell label participates in classification or graph value.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local common = { spellFamilyName = 3, school = 4,
    recoveryTime = 0, categoryRecoveryTime = 0 }
local records = {
    [12472] = {
        school = 0, category = 0, dispel = 0, mechanic = 0,
        attributes = 327680, attributesEx = 0, attributesEx2 = 0,
        attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
        recoveryTime = 600000, categoryRecoveryTime = 0,
        interruptFlags = 12, auraInterruptFlags = 0,
        channelInterruptFlags = 0, durationIndex = 0, powerType = 0,
        manaCost = 0, manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 1,
        spellFamilyName = 3, spellFamilyFlags = 0,
        startRecoveryCategory = 0, startRecoveryTime = 0,
        maxAffectedTargets = 0, effect = triple(3),
        effectBasePoints = triple(), effectDieSides = triple(),
        effectImplicitTargetA = triple(1),
        effectImplicitTargetB = triple(),
        effectApplyAuraName = triple(), effectAmplitude = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
    },
    [122] = { spellFamilyName = 3, school = 4,
        recoveryTime = 25000, categoryRecoveryTime = 0 },
    [11426] = { spellFamilyName = 3, school = 4,
        recoveryTime = 0, categoryRecoveryTime = 30000 },
    [11958] = { spellFamilyName = 3, school = 4,
        recoveryTime = 300000, categoryRecoveryTime = 0 },
    [116] = common,
    [2136] = { spellFamilyName = 3, school = 2,
        recoveryTime = 8000, categoryRecoveryTime = 0 },
    [20554] = { spellFamilyName = 0, school = 0,
        recoveryTime = 120000, categoryRecoveryTime = 0 },
    [9999] = { spellFamilyName = 3, school = 4,
        recoveryTime = 10000 },
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
    assert(spellId == 12472, "only Cold Snap duration is queried")
    return 0
end

function UnitClass(unit)
    assert(unit == "player")
    return "Mage", "MAGE"
end

XelAssist = { Game = { Player = {} }, Graph = {} }
dofile("Game/Player/MageColdSnap.lua")
local Runtime = XelAssist.Game.Player.MageColdSnap

local inferred, reason, handled = Runtime:InferKnowledge(12472)
assert(handled and not reason and inferred and inferred.kind == "modifier"
    and inferred.mageColdSnap == true
    and inferred.mageColdSnapEvidence.frostSchoolMask == 16
    and inferred.mageColdSnapEvidence.cooldown == 600,
    "Cold Snap must be claimed only from its exact numeric topology")

local foreign, _, foreignHandled = Runtime:InferKnowledge(122)
assert(foreign == nil and foreignHandled == false,
    "ordinary Mage spells must remain available to other inference")

local function action(spellId, slot, facts)
    return { name = "localized display " .. tostring(slot), spellId = spellId,
        slot = slot, bookType = "spell", actor = "player",
        executor = "playerSpell", facts = facts or { kind = "damage" } }
end

local cold = action(12472, 1, inferred)
local nova = action(122, 2)
local barrier = action(11426, 3, { kind = "absorb" })
local block = action(11958, 4, { kind = "defensive" })
local bolt = action(116, 5)
local fire = action(2136, 6)
local racial = action(20554, 7, { kind = "modifier" })
local malformed = action(9999, 8)

local function capture(found, base)
    return Runtime:CaptureFacts(found, base or {
        cost = 10, cast = 0, gcd = 1.5, cooldown = 1 })
end

local facts = {
    [cold] = capture(cold, { cost = nil, cast = 0, gcd = 0,
        cooldown = 600 }),
    [nova] = capture(nova), [barrier] = capture(barrier),
    [block] = capture(block), [bolt] = capture(bolt),
    [fire] = capture(fire), [racial] = capture(racial),
    [malformed] = capture(malformed),
}

assert(Runtime:CooldownContract(facts[nova]).eligible == true
    and Runtime:CooldownContract(facts[barrier]).eligible == true,
    "both direct and category recovery contribute to GetRecoveryTime")
assert(Runtime:CooldownContract(facts[bolt]).eligible == false
    and Runtime:CooldownContract(facts[fire]).eligible == false
    and Runtime:CooldownContract(facts[racial]).eligible == false,
    "family, Frost school mask and positive recovery are all required")
assert(Runtime:CooldownContract(facts[malformed]) == nil
    and facts[malformed].mageColdSnapCooldown.complete == false,
    "an incomplete reset predicate must be claimed but fail closed")
assert(facts[cold].cost == 0 and facts[cold].cast == 0
    and facts[cold].gcd == 0 and facts[cold].cooldown == 600,
    "Cold Snap's exact zero-cost off-GCD timing must be root sealed")

dofile("Graph/CooldownLedger.lua")
local Ledger = XelAssist.Graph.CooldownLedger
local rootActions = { cold, nova, barrier, block, bolt, fire, racial }
XelAssist.Graph.RootObservation = {}
function XelAssist.Graph.RootObservation:Actions(state)
    return state.rootActions, "known"
end
function XelAssist.Graph.RootObservation:Facts(state, found)
    local sealed = state.rootFacts[found]
    return sealed, sealed and "known" or "unknown"
end

dofile("Graph/MageColdSnap.lua")
local Graph = XelAssist.Graph.MageColdSnap

local state = { time = 2, actorReadyAt = { player = 2 },
    playerGcdReadyAt = 8, readyAt = {}, rootActions = rootActions,
    rootFacts = facts, cooldownLedger = { records = {}, order = {} } }
local function cooldown(found, readyAt)
    local key = Ledger:ActionKey(found)
    state.cooldownLedger.records[key] = { known = true, key = key,
        readyAt = readyAt }
    state.readyAt[key] = readyAt
    return key
end

local coldKey = cooldown(cold, 0)
local novaKey = cooldown(nova, 20)
local barrierKey = cooldown(barrier, 30)
local blockKey = cooldown(block, 0)
local boltKey = cooldown(bolt, 0)
local fireKey = cooldown(fire, 15)
local racialKey = cooldown(racial, 40)
state.readyAt["group:471"] = 45
-- Production CooldownLedger leaves ready action keys absent and keeps the
-- exact zero on the record itself.
state.readyAt[blockKey], state.readyAt[boltKey] = nil, nil

local capturedCalls = dbcCalls
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitClass = function() error("class read during graph search") end

local projection, prepareReason, prepareHandled = Graph:Prepare(
    cold, state, facts[cold], 2)
assert(prepareHandled and not prepareReason and projection
    and projection.classMechanic == "mageColdSnap",
    "the exact root catalogue must produce a Cold Snap transition")
local transition = projection.mageColdSnapTransition
assert(table.getn(transition.catalogueSpellIds) == 3
    and transition.catalogueSpellIds[1] == 122
    and transition.catalogueSpellIds[2] == 11426
    and transition.catalogueSpellIds[3] == 11958
    and table.getn(transition.changed) == 2
    and transition.changed[1].spellId == 122
    and transition.changed[2].spellId == 11426,
    "the reset set must include every exact Frost cooldown but change only delayed ones")
assert(dbcCalls == capturedCalls,
    "graph preparation must consume sealed facts without live DBC reads")

local context = { power = 99, expectedPower = 99, effectivePower = 99,
    value = 999, estimated = true }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.estimated == false,
    "Cold Snap must have no fixed utility independent of downstream actions")
local setup = Graph:StrategicSetup(projection)
assert(setup and setup.consumerKey == Graph.CONSUMER_KEY,
    "the exact reset must open one bounded consequence lane")

local candidate = { action = cold, tooltip = projection,
    classMechanicProjection = projection }
assert(Graph:Apply(state, candidate),
    "the exact transition must clear its changed action clocks")
assert(state.readyAt[novaKey] == 2 and state.readyAt[barrierKey] == 2
    and state.readyAt[blockKey] == nil and state.readyAt[boltKey] == nil
    and state.readyAt[fireKey] == 15 and state.readyAt[racialKey] == 40
    and state.readyAt[coldKey] == 0,
    "only action-specific clocks selected by the server predicate may clear")
assert(state.readyAt["group:471"] == 45 and state.playerGcdReadyAt == 8,
    "Cold Snap must not clear category or global-cooldown clocks")
assert(Graph:RootCooldownCleared(state, nova, facts[nova])
    and Graph:RootCooldownCleared(state, barrier, facts[barrier])
    and not Graph:RootCooldownCleared(state, block, facts[block])
    and not Graph:RootCooldownCleared(state, fire, facts[fire]),
    "immutable root cooldowns may be bypassed only for truly changed IDs")
assert(Graph:ConsumerKey(state, nova, facts[nova]) == Graph.CONSUMER_KEY
    and Graph:ConsumerKey(state, barrier, facts[barrier]) == Graph.CONSUMER_KEY
    and Graph:ConsumerKey(state, block, facts[block]) == nil
    and Graph:ConsumerKey(state, fire, facts[fire]) == nil,
    "already-ready Frost and non-Frost actions must not close the setup lane")
local path = { state = state, strategicSetupOpen = true,
    strategicSetupConsumerKey = Graph.CONSUMER_KEY }
assert(Graph:PotentialConsumer(path, nova, facts[nova])
    and not Graph:PotentialConsumer(path, block, facts[block]),
    "consumer filtering must be branch-local to the exact changed set")

function XelAssist.Graph.RootObservation:ActionRecord(_, found)
    local remaining = found == nova and 18 or found == fire and 13 or 0
    return { cooldown = { applicable = true, known = true,
        remaining = remaining }, facts = facts[found] }, "known"
end
state.resource, state.resourceType = 100, 0
XelAssist.Game.Inventory = {}
dofile("Graph/ActionAdmission.lua")
assert(XelAssist.Graph.ActionAdmission:Readiness(
    nova, state, facts[nova], state.time) == nil,
    "action admission must ignore stale root cooldown only for a changed spell")
assert(XelAssist.Graph.ActionAdmission:Readiness(
    fire, state, facts[fire], state.time) ~= nil,
    "the reset marker must not bypass an unrelated immutable root cooldown")

dofile("Graph/Candidate.lua")
local builtSetup = XelAssist.Graph.Candidate:Build({ action = cold,
    state = state, descriptor = { key = "self", relation = "self" },
    facts = cold.facts, tooltip = projection, value = 0 })
local builtConsumer = XelAssist.Graph.Candidate:Build({ action = nova,
    state = state, descriptor = { key = "target", relation = "hostile" },
    facts = nova.facts, tooltip = facts[nova], value = 100 })
assert(builtSetup.strategicSetup == true
    and builtSetup.strategicSetupConsumerKey == Graph.CONSUMER_KEY
    and builtConsumer.setupConsumerKey == Graph.CONSUMER_KEY,
    "candidate serialization must connect the reset edge to its changed consumer")

dofile("Graph/ResourceInvestment.lua")
assert(XelAssist.Graph.ResourceInvestment:PotentialConsumer(
    path, nova, facts[nova])
    and not XelAssist.Graph.ResourceInvestment:PotentialConsumer(
        path, block, facts[block]),
    "strategic search filtering must expose only changed Frost consumers")

local copied = {}
assert(Graph:Copy(state, copied)
    and copied.mageColdSnapReset ~= state.mageColdSnapReset
    and copied.mageColdSnapReset.keys ~= state.mageColdSnapReset.keys
    and copied.mageColdSnapReset.keys[novaKey],
    "Cold Snap reset ownership must survive branch copying without aliasing")

local incomplete = { time = 2, actorReadyAt = { player = 2 },
    readyAt = {}, rootActions = { cold, malformed }, rootFacts = facts,
    cooldownLedger = { records = {}, order = {} } }
local function incompleteCooldown(found, readyAt)
    local key = Ledger:ActionKey(found)
    incomplete.cooldownLedger.records[key] = { known = true,
        key = key, readyAt = readyAt }
    incomplete.readyAt[key] = readyAt
end
incompleteCooldown(cold, 0); incompleteCooldown(malformed, 20)
local missing, missingReason, missingHandled = Graph:Prepare(
    cold, incomplete, facts[cold], 2)
assert(missing == nil and missingHandled
    and missingReason == "root Cold Snap reset classification unavailable",
    "one incomplete catalogue spell must fail the whole exact reset closed")

local readyState = { time = 2, actorReadyAt = { player = 2 },
    readyAt = {}, rootActions = rootActions, rootFacts = facts,
    cooldownLedger = { records = {}, order = {} } }
for _, found in pairs(rootActions) do
    local key = Ledger:ActionKey(found)
    readyState.cooldownLedger.records[key] = { known = true,
        key = key, readyAt = 0 }
    readyState.readyAt[key] = 0
end
local none, noneReason, noneHandled = Graph:Prepare(
    cold, readyState, facts[cold], 2)
assert(none == nil and noneHandled
    and noneReason == "no resettable Frost cooldown is delayed",
    "already-ready Frost spells must never manufacture Cold Snap value")

print("ok: exact Cold Snap reset value emerges only through changed Frost cooldowns")
