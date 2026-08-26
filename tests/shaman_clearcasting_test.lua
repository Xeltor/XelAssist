XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function auraRecord(amount, charges, chance, stack)
    return { spellFamilyName = 11, school = 6, attributes = 327680,
        attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, procFlags = 87376, procChance = chance,
        procCharges = charges, durationIndex = 8, powerType = 0,
        manaCost = 0, manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0,
        effect = triple(6), effectApplyAuraName = triple(108),
        effectMiscValue = triple(14), effectBasePoints = triple(amount - 1),
        effectBaseDice = triple(1), effectDieSides = triple(1),
        effectDicePerLevel = triple(), effectRealPointsPerLevel = triple(),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple(),
        effectMechanic = triple(), effectRadiusIndex = triple(),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectItemType = triple(),
        effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
        stackAmount = stack or 0 }
end

local function actionRecord(family, cost)
    return { spellFamilyName = family, powerType = 0, manaCost = cost,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 }
end

local records = {
    [45541] = { spellFamilyName = 11, school = 0, attributes = 464,
        attributesEx = 0, attributesEx2 = 0, attributesEx3 = 67108864,
        attributesEx4 = 0, procFlags = 87380, procChance = 100,
        procCharges = 0, durationIndex = 21,
        effect = triple(6), effectApplyAuraName = triple(42),
        effectImplicitTargetA = triple(1), effectTriggerSpell = triple(45542) },
    [45542] = auraRecord(-60, 2, 0, 1),
    [16246] = auraRecord(-100, 1, 100, 0),
    [49999] = auraRecord(-60, 2, 0, 1),
    [49998] = auraRecord(-60, 2, 0, 2),
    [403] = actionRecord(11, 30),
    [331] = actionRecord(11, 40),
    [8042] = actionRecord(11, 45),
    [8050] = actionRecord(11, 50),
    [589] = actionRecord(6, 25),
    [90000] = { spellFamilyName = 3 },
}
records[49999].procFlags = 0

local playerClass, playerGUID = "SHAMAN", "Player-1"
local now, auras, procActive = 100, { { spellId = 90000 } }, false
local dbcCalls, auraCalls, modifierCalls, costCalls = 0, 0, {}, {}
local baseModifiers = { [403] = -10, [331] = 0, [8042] = -5,
    [8050] = 0 }
local procModifiers = { [403] = -70, [331] = 0, [8042] = -80,
    [8050] = -60 }
local baseCosts = { [403] = 30, [331] = 40, [8042] = 45,
    [8050] = 50 }
local procCosts = { [403] = 12, [331] = 40, [8042] = 10,
    [8050] = 20 }

local function unsigned(value)
    return value < 0 and value + 4294967296 or value
end

UnitClass = function() return "Localized", playerClass end
IsPlayerSpell = function(id) return id == 45541 end
UnitExists = function(unit)
    return unit == "player" and true or false,
        unit == "player" and playerGUID or nil
end
GetTime = function() return now end
GetSpellName = function()
    error("Shaman Clearcasting must not inspect localized spell names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row, value = records[spellId], records[spellId]
        and records[spellId][field]
    if value == nil then error("missing DBC field") end
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellModifiers = function(spellId, kind)
    modifierCalls[spellId] = (modifierCalls[spellId] or 0) + 1
    assert(kind == 14, "only exact engine cost modifiers may be read")
    local value = (procActive and procModifiers or baseModifiers)[spellId]
    assert(value ~= nil, "unexpected Shaman modifier query")
    return 0, unsigned(value), value == 0 and 0 or 1
end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls[spellId] = (costCalls[spellId] or 0) + 1
    local value = (procActive and procCosts or baseCosts)[spellId]
    if value == 0 then return nil end
    return { { type = 0, cost = value, minCost = value,
        costPercent = 0, costPerSec = 0, requiredAuraID = 0,
        hasRequiredAura = false } }
end }
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    auraCalls = auraCalls + 1
    assert(unit == "player" and filter == "HELPFUL")
    return auras
end }

dofile("Game/Player/ShamanClearcasting.lua")
dofile("Graph/ShamanClearcasting.lua")
local Runtime = XelAssist.Game.Player.ShamanClearcasting
local Graph = XelAssist.Graph.ShamanClearcasting

local state = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 }, actors = { player = { level = 30 } } }
local function action(spellId)
    return { spellId = spellId, actor = "player", executor = "playerSpell",
        facts = { kind = "damage" } }
end
local bolt, heal, ambiguous, unseen = action(403), action(331),
    action(8042), action(8050)

assert(Runtime:Attach(state, "SHAMAN") and state.shamanClearcasting.exact
    and state.shamanClearcasting.active == false and auraCalls == 1,
    "a complete numeric aura scan must prove the inactive root")
local plain = { cost = 30, average = 55 }
assert(Runtime:CaptureFacts(bolt, plain, state) == plain,
    "inactive capture must learn without mutating action facts")
Runtime:CaptureFacts(heal, { cost = 40 }, state)
Runtime:CaptureFacts(ambiguous, { cost = 45 }, state)
local modifierBefore, costBefore = modifierCalls[403], costCalls[403]
Runtime:CaptureFacts(bolt, plain, state)
assert(modifierCalls[403] == modifierBefore and costCalls[403] == costBefore,
    "inactive per-level baselines must be reused")

local foreign = action(589)
local foreignFacts = { cost = 25 }
assert(Runtime:CaptureFacts(foreign, foreignFacts, state) == foreignFacts
    and modifierCalls[589] == nil,
    "another class family must not enter Shaman cost capture")

procActive = true
auras = { { spellId = 90000 }, { spellId = 45542, isHelpful = true,
    applications = 2, duration = 15, expirationTime = 110 } }
assert(Runtime:Attach(state, "SHAMAN") and state.shamanClearcasting.active
    and state.shamanClearcasting.remainingCharges == 2
    and state.shamanClearcasting.remaining == 10
    and state.shamanClearcasting.profile.modifierAmount == -60,
    "active numeric topology must seal its exact reduction and two charges")
local activeDBC = dbcCalls
local boltFacts = Runtime:CaptureFacts(bolt, { cost = 12 }, state)
local contract = boltFacts.shamanClearcastingCost
assert(contract and contract.claimed and contract.exact and contract.eligible
    and contract.baselineCost == 30 and contract.activeCost == 12
    and contract.auraSpellId == 45542,
    "engine delta must seal the exact reduced Shaman cost")
local activeModifier, activeCost = modifierCalls[403], costCalls[403]
contract.activeCost = 999
boltFacts = Runtime:CaptureFacts(bolt, { cost = 12 }, state)
contract = boltFacts.shamanClearcastingCost
assert(contract.activeCost == 12 and modifierCalls[403] == activeModifier
    and costCalls[403] == activeCost and dbcCalls == activeDBC,
    "one aura epoch must cache immutable action contracts and DBC identity")

local healFacts = Runtime:CaptureFacts(heal, { cost = 40 }, state)
assert(healFacts.shamanClearcastingCost.exact
    and healFacts.shamanClearcastingCost.eligible == false
    and healFacts.shamanClearcastingCost.activeCost == 40,
    "an engine-proven unaffected heal must preserve both cost and proc")
local ambiguousFacts = Runtime:CaptureFacts(ambiguous, { cost = 10 }, state)
assert(ambiguousFacts.shamanClearcastingCost.exact == false
    and ambiguousFacts.shamanClearcastingCost.reason
        == "Shaman Clearcasting cost regime is ambiguous",
    "simultaneous unproven cost changes must fail closed")
local unseenFacts = Runtime:CaptureFacts(unseen, { cost = 20 }, state)
assert(unseenFacts.shamanClearcastingCost.exact == false
    and unseenFacts.shamanClearcastingCost.reason
        == "Shaman Clearcasting baseline cost unavailable",
    "a spell first observed during the proc must fail closed")

local prepared, reason, handled = Graph:PrepareLegal(bolt, state, boltFacts)
assert(handled and reason == nil and prepared.cost == 12
    and prepared.shamanClearcastingConsumption
    and boltFacts.shamanClearcastingConsumption == nil,
    "an eligible action must receive a copied exact reduced cost")
local child = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 } }
assert(Graph:Copy(state, child) and child.shamanClearcasting
    and child.shamanClearcasting ~= state.shamanClearcasting
    and child.shamanClearcasting.profile ~= state.shamanClearcasting.profile,
    "graph branches must not share the mutable charge snapshot")
local candidate = { action = bolt, tooltip = prepared,
    actionStart = 0, cost = 12 }
assert(Graph:Consume(child, candidate) and child.shamanClearcasting.active
    and child.shamanClearcasting.remainingCharges == 1,
    "the first exact cast must consume only one of two charges")
prepared = Graph:PrepareLegal(bolt, child, boltFacts)
candidate = { action = bolt, tooltip = prepared, actionStart = 0, cost = 12 }
assert(prepared.cost == 12 and Graph:Consume(child, candidate)
    and not child.shamanClearcasting.active
    and child.shamanClearcasting.remainingCharges == 0,
    "the second exact cast must exhaust the branch-local proc")
prepared = Graph:PrepareLegal(bolt, child, boltFacts)
assert(prepared.cost == 30 and not prepared.shamanClearcastingConsumption,
    "descendants after exhaustion must restore the learned baseline")
assert(state.shamanClearcasting.active
    and state.shamanClearcasting.remainingCharges == 2,
    "consuming one branch must not mutate its sibling")

prepared = Graph:PrepareLegal(heal, state, healFacts)
assert(prepared.cost == 40 and not prepared.shamanClearcastingConsumption,
    "an unaffected heal must not consume Clearcasting")
state.playerGcdReadyAt = 11
prepared = Graph:PrepareLegal(bolt, state, boltFacts)
assert(prepared.cost == 30 and not prepared.shamanClearcastingConsumption,
    "a proc expiring before player readiness must not fund the action")
prepared, reason, handled = Graph:PrepareLegal(
    ambiguous, state, ambiguousFacts)
assert(handled and not prepared
    and reason == "Shaman Clearcasting cost regime is ambiguous",
    "an unresolved claimed cost must block instead of guessing")

-- Charge count and recognized topology drift are hard evidence boundaries.
state.playerGcdReadyAt = 0
auras = { { spellId = 45542, isHelpful = true,
    applications = 3, duration = 15, expirationTime = 110 } }
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason
        == "active Shaman Clearcasting aura is incomplete",
    "live stacks above the DBC charge ceiling must fail closed")
auras = { { spellId = 49999, isHelpful = true,
    applications = 2, duration = 15, expirationTime = 110 } }
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason
        == "non-Octo Shaman Clearcasting topology is unsupported",
    "a recognized but drifted cost proc must not fall through")
Runtime:Invalidate()
auras = { { spellId = 49998, isHelpful = true,
    applications = 2, duration = 15, expirationTime = 110 } }
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason
        == "non-Octo Shaman Clearcasting topology is unsupported",
    "a stackable lookalike must not be mistaken for remaining proc charges")

-- A legacy one-charge lookalike must not replace Octo Elemental Focus.
Runtime:Invalidate()
procActive = false; auras = {}; state.shamanClearcasting = nil
assert(Runtime:Attach(state, "SHAMAN"))
Runtime:CaptureFacts(bolt, plain, state)
procActive = true; procModifiers[403], procCosts[403] = -110, 0
auras = { { spellId = 16246, isHelpful = true,
    applications = 1, duration = 15, expirationTime = 111 } }
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason
        == "non-Octo Shaman Clearcasting topology is unsupported",
    "legacy one-charge Clearcasting must fail closed on Octo")

local learned = IsPlayerSpell
IsPlayerSpell = function() return nil end
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason == "Elemental Focus ownership unavailable",
    "unknown passive ownership must fail closed")
IsPlayerSpell = learned
Runtime:Invalidate(); records[45541].effectTriggerSpell[1] = 45543
assert(not Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.reason
        == "Elemental Focus trigger topology is incomplete",
    "recognized passive trigger drift must fail closed")
records[45541].effectTriggerSpell[1] = 45542; Runtime:Invalidate()

procModifiers[403], procCosts[403] = -70, 12
procActive = false; auras = {}
assert(Runtime:Attach(state, "SHAMAN"))
Runtime:CaptureFacts(bolt, plain, state)
procActive = true
auras = { { spellId = 45542, isHelpful = true,
    applications = 2, duration = 15, expirationTime = 111 } }
assert(Runtime:Attach(state, "SHAMAN")
    and state.shamanClearcasting.learned
    and state.shamanClearcasting.triggerEligible
    and state.shamanClearcasting.triggerSpellCritical
    and state.shamanClearcasting.triggerMeleeCritical
    and state.shamanClearcasting.triggerProjection == "observed-aura-only"
    and state.shamanClearcasting.remainingCharges == 2,
    "owned Octo proc must preserve both charges")
local ownedFacts = Runtime:CaptureFacts(bolt, { cost = 12 }, state)
prepared = Graph:PrepareLegal(bolt, state, ownedFacts)

local saved = { GetSpellRecField, GetSpellModifiers, GetTime,
    C_Spell.GetSpellPowerCost, C_UnitAuras.GetUnitAuras, UnitClass, UnitExists,
    IsPlayerSpell }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetTime = function() error("wall-clock read during graph search") end
C_Spell.GetSpellPowerCost = function() error("cost read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end
UnitClass = function() error("class read during graph search") end
UnitExists = function() error("identity read during graph search") end
IsPlayerSpell = function() error("ownership read during graph search") end
local pureChild = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 } }
assert(Graph:Copy(state, pureChild)
    and Graph:Consume(pureChild, { action = bolt, tooltip = prepared,
        actionStart = 0, cost = 12 }),
    "graph copy and consumption must use only sealed root evidence")
GetSpellRecField, GetSpellModifiers, GetTime, C_Spell.GetSpellPowerCost,
    C_UnitAuras.GetUnitAuras, UnitClass, UnitExists, IsPlayerSpell = saved[1],
    saved[2], saved[3], saved[4], saved[5], saved[6], saved[7], saved[8]

local priorAuraCalls = auraCalls
playerClass = "MAGE"
assert(not Runtime:Attach(state, nil) and auraCalls == priorAuraCalls,
    "another exact class must be rejected before aura interpretation")

print("ok: Shaman Clearcasting seals exact engine costs and charge consumption")
