XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end

local records = {
    [18220] = { spellFamilyName = 5, powerType = 0,
        manaCost = 0, manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0,
        effect = triple(8), effectImplicitTargetA = triple(5),
        effectImplicitTargetB = triple(), effectMiscValue = triple(),
        effectMultipleValue = triple(1), effectApplyAuraName = triple(),
        effectMechanic = triple(), effectRadiusIndex = triple(),
        effectAmplitude = triple(), effectChainTarget = triple(),
        effectItemType = triple(), effectTriggerSpell = triple(),
        effectBasePoints = triple(39), effectBaseDice = triple(1),
        effectDieSides = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectPointsPerComboPoint = triple() },
    [9001] = { spellFamilyName = 5, powerType = 0,
        manaCost = 0, manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0,
        effect = triple(8, 2), effectImplicitTargetA = triple(5, 6),
        effectImplicitTargetB = triple(), effectMiscValue = triple(),
        effectMultipleValue = triple(1), effectApplyAuraName = triple(),
        effectMechanic = triple(), effectRadiusIndex = triple(),
        effectAmplitude = triple(), effectChainTarget = triple(),
        effectItemType = triple(), effectTriggerSpell = triple(),
        effectBasePoints = triple(39, 5), effectBaseDice = triple(1, 1),
        effectDieSides = triple(1, 1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectPointsPerComboPoint = triple() },
    [133] = { spellFamilyName = 3, effect = triple(2),
        effectImplicitTargetA = triple(6), effectMiscValue = triple() },
}

local dbcReads, playerClass = 0, "WARLOCK"
GetSpellName = function() error("Dark Pact must not read localized names") end
GetSpellRecField = function(spellId, field, copied)
    dbcReads = dbcReads + 1
    local row, value = records[spellId], records[spellId] and records[spellId][field]
    if value == nil then error("missing DBC field") end
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
UnitClass = function() return "Localized", playerClass end

local at, playerMana, playerMax, petMana, petMax = 10, 100, 300, 200, 300
GetTime = function() return at end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
    if unit == "pet" then return true, "pet-guid" end
    return false, nil
end
UnitMana = function(unit) return unit == "player" and playerMana or petMana end
UnitManaMax = function(unit) return unit == "player" and playerMax or petMax end
UnitPowerType = function() return 0 end
GetNampowerVersion = function() return 4, 7, 0 end

local registered, handler = {}, nil
CreateFrame = function()
    return {
        RegisterEvent = function(_, name) registered[name] = true; return true end,
        SetScript = function(_, _, callback) handler = callback end,
    }
end

dofile("Game/Player/WarlockDarkPact.lua")
local Runtime = XelAssist.Game.Player.WarlockDarkPact

assert(Runtime.runtimeSupported and Runtime.powerEventMode == "guid"
    and registered.SPELL_GO_SELF and registered.SPELL_GO_OTHER
    and type(handler) == "function",
    "exact GO and GUID power events must gate runtime learning")

local facts, reason, handled = Runtime:InferKnowledge(18220)
assert(facts and not reason and handled and facts.kind == "resource"
    and facts.kindExact and facts.self and facts.fixedTarget == "player"
    and facts.warlockDarkPact and facts.petManaConversion
    and facts.requiresWarlockDarkPactEvidence
    and facts.warlockDarkPactEvidence.baseAmount == 40,
    "fixed installed pet-mana drain topology must identify Dark Pact")
assert(facts.priority == nil and facts.score == nil and facts.rotation == nil,
    "mechanics identity must not encode a Warlock action order")

local before = dbcReads
local secondFacts = Runtime:InferKnowledge(18220)
assert(secondFacts and dbcReads == before and secondFacts ~= facts,
    "complete DBC identity must be cached and returned by copy")
secondFacts.warlockDarkPactEvidence.baseAmount = 999
assert(Runtime:InferKnowledge(18220).warlockDarkPactEvidence.baseAmount == 40,
    "caller mutation must not poison cached topology")

local unknown
unknown, reason, handled = Runtime:InferKnowledge(133)
assert(not unknown and not handled and reason == "spell is not a pet-mana drain",
    "unrelated spells must remain available to generic inference")
unknown, reason, handled = Runtime:InferKnowledge(9001)
assert(not unknown and handled
    and reason == "pet-mana drain DBC topology is incomplete",
    "recognized mixed effects must fail closed")

local action = { spellId = 18220, facts = facts }
local captured = Runtime:CaptureFacts(action, { cost = 0 })
assert(not captured.warlockDarkPactTransferExact
    and captured.warlockDarkPactCaptureReason,
    "an unseen live transfer must remain unavailable")

local function sample(playerBefore, petBefore, amount)
    playerMana, petMana = playerBefore, petBefore
    assert(Runtime:OnEvent("SPELL_GO_SELF", 0, 18220,
        "player-guid", "pet-guid", 0, 0, 0), "exact GO must open sample")
    at = at + 0.1
    playerMana, petMana = playerBefore + amount, petBefore - amount
    return Runtime:OnEvent("UNIT_MANA_GUID", "pet-guid", 1)
end

assert(not sample(100, 200, 40) and not Runtime:Snapshot(18220),
    "one sample must not publish a live transfer")
at = at + 1
assert(sample(100, 200, 40), "second identical sample must verify transfer")
local learned = Runtime:Snapshot(18220)
assert(learned and learned.amount == 40 and learned.samples == 2
    and learned.playerGuid == nil and learned.petGuid == nil,
    "published evidence must be exact and must not expose opaque identities")

captured = Runtime:CaptureFacts(action, { cost = 9, average = 999 })
assert(captured.warlockDarkPactTransferExact
    and captured.warlockDarkPactTransfer == 40 and captured.cost == 0
    and captured.powerType == 0 and captured.resourceType == "mana",
    "root capture must seal only the learned live transfer")

-- A pet clamp and a player cap are valid casts but cannot teach the full rank.
at = at + 1; playerMana, petMana = 100, 30
Runtime:OnEvent("SPELL_GO_SELF", 0, 18220,
    "player-guid", "pet-guid", 0, 1, 0)
at = at + 0.1; playerMana, petMana = 130, 0
assert(not Runtime:OnEvent("UNIT_MANA_GUID", "pet-guid", 1)
    and Runtime:Snapshot(18220).amount == 40,
    "a pet-mana-clipped sample must not replace verified rank evidence")

at = at + 1; playerMana, petMana = 290, 200
Runtime:OnEvent("SPELL_GO_SELF", 0, 18220,
    "player-guid", "pet-guid", 0, 1, 0)
at = at + 0.1; playerMana, petMana = 300, 160
assert(not Runtime:OnEvent("UNIT_MANA_GUID", "player-guid", 1)
    and Runtime:Snapshot(18220).amount == 40,
    "a player-cap-clipped sample must not poison verified evidence")

-- A concurrent pet cast and a stale delta must never train attribution.
at = at + 1; playerMana, petMana = 100, 200
Runtime:OnEvent("SPELL_GO_SELF", 0, 18220,
    "player-guid", "pet-guid", 0, 1, 0)
Runtime:OnEvent("SPELL_GO_OTHER", 0, 3110,
    "pet-guid", "enemy-guid", 0, 1, 0)
at = at + 0.1; playerMana, petMana = 140, 150
assert(not Runtime:OnEvent("UNIT_MANA_GUID", "pet-guid", 1)
    and Runtime:Snapshot(18220).amount == 40,
    "a concurrent demon spell must close event attribution")

at = at + 1; playerMana, petMana = 100, 200
Runtime:OnEvent("SPELL_GO_SELF", 0, 18220,
    "player-guid", "pet-guid", 0, 1, 0)
at = at + 0.6; playerMana, petMana = 140, 160
assert(not Runtime:OnEvent("UNIT_MANA_GUID", "pet-guid", 1),
    "a late resource delta must exceed the association safety window")

Runtime:OnEvent("UNIT_AURA", "pet")
assert(not Runtime:Snapshot(18220)
    and not Runtime:CaptureFacts(action, {}).warlockDarkPactTransferExact,
    "pet aura changes must invalidate learned server-side magnitude")

playerClass, before = "MAGE", dbcReads
unknown, reason, handled = Runtime:InferKnowledge(18220)
assert(not unknown and not handled and dbcReads == before,
    "another exact class must be rejected before DBC access")
playerClass = "WARLOCK"

-- Restore exact evidence for graph projection.
at = at + 1
sample(100, 200, 40); at = at + 1; sample(100, 200, 40)
captured = Runtime:CaptureFacts(action, {})

XelAssist.Graph.State = {
    FriendlyByUnit = function(_, state, unit)
        return unit == "player" and state.friendlies and state.friendlies.player
    end,
}
dofile("Graph/WarlockDarkPact.lua")
local Graph = XelAssist.Graph.WarlockDarkPact

local function state(player, pet)
    return { resourceType = 0, resource = player, resourceMax = 300,
        playerResourceExact = true,
        playerResourceClock = { verified = true, phaseKnown = true, nextIn = 1 },
        actors = { player = { resource = player }, pet = {
            ownerClass = "WARLOCK", health = 100, healthMax = 100,
            resource = pet, resourceMax = 300, resourceExact = true } },
        friendlies = { player = { resource = player } } }
end
local descriptor = { unit = "player", relation = "self" }
local graphState = state(100, 60)
local blocker, claimed, projection = Graph:Blocker(
    action, graphState, descriptor, captured)
assert(not blocker and claimed and projection.drained == 40
    and projection.gained == 40 and projection.wasted == 0,
    "exact player and demon mana must admit the transfer")

dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassMechanics.lua")
local integratedFacts = XelAssist.Graph.ClassMechanics:CaptureFacts(
    action, facts, graphState)
local integratedAction = { spellId = action.spellId, facts = integratedFacts }
blocker, claimed = XelAssist.Graph.ClassMechanics:EvidenceBlocker(
    integratedAction, graphState, descriptor, integratedFacts)
assert(not blocker and claimed and integratedFacts.warlockDarkPactTransferExact,
    "the production class evidence boundary must seal and admit Dark Pact")
dofile("Graph/ResourceInvestment.lua")
assert(XelAssist.Graph.ResourceInvestment:Is({ action = integratedAction }),
    "a neutral pet-mana transfer must retain a lane until player mana is spent")

local context = { action = action, state = graphState, tooltip = captured }
assert(Graph:Score(context) and context.value == 0
    and context.resourceGain == 40 and context.petResourceSpent == 40
    and context.priority == nil,
    "equal transfer must be recommendation-neutral until descendants use it")
local candidate = { action = action, tooltip = captured }
assert(Graph:Apply(graphState, candidate)
    and graphState.resource == 140 and graphState.actors.player.resource == 140
    and graphState.friendlies.player.resource == 140
    and graphState.actors.pet.resource == 20
    and graphState.playerResourceClock.phaseKnown,
    "graph transition must move exact mana without resetting passive phase")

local capState = state(290, 60)
context = { action = action, state = capState, tooltip = captured }
assert(Graph:Score(context) and context.value == -30
    and context.effectivePower == 10,
    "player-cap waste must be the only immediate transfer penalty")
assert(Graph:Apply(capState, candidate) and capState.resource == 300
    and capState.actors.pet.resource == 20
    and not capState.playerResourceClock.phaseKnown
    and capState.playerResourceClock.nextIn == nil,
    "server drains full pet amount while cap erases passive mana phase")

local lowPet = state(100, 25)
assert(Graph:Apply(lowPet, candidate) and lowPet.resource == 125
    and lowPet.actors.pet.resource == 0,
    "server clamp must transfer all remaining demon mana exactly")

local full = state(300, 60)
blocker, claimed = Graph:Blocker(action, full, descriptor, captured)
assert(claimed and blocker == "player mana already full",
    "a full player pool must block waste-only Dark Pact")
local unknownPet = state(100, 60)
unknownPet.actors.pet.resourceExact = false
blocker = Graph:Blocker(action, unknownPet, descriptor, captured)
assert(blocker == "controlled demon mana evidence unavailable",
    "unknown demon mana must fail closed")
local unknownPlayer = state(100, 60)
unknownPlayer.playerResourceExact = false
assert(not Graph:Projection(action, unknownPlayer, captured)
    and not Graph:Score({ action = action, state = unknownPlayer,
        tooltip = captured }),
    "projection helpers must independently fail closed on unknown player mana")

local savedDBC, savedTime, savedMana = GetSpellRecField, GetTime, UnitMana
GetSpellRecField = function() error("DBC read during graph search") end
GetTime = function() error("clock read during graph search") end
UnitMana = function() error("unit power read during graph search") end
graphState = state(100, 60)
assert(Graph:Score({ action = action, state = graphState, tooltip = captured })
    and Graph:Apply(graphState, candidate),
    "sealed graph helpers must perform no mutable API reads")
GetSpellRecField, GetTime, UnitMana = savedDBC, savedTime, savedMana

print("ok: Warlock Dark Pact learns and projects exact pet-mana transfers")
