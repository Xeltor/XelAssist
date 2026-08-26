XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function actionRecord(family, base)
    return { spellFamilyName = family, powerType = 0, manaCost = base,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 }
end

local records = {
    [12536] = { spellFamilyName = 3, powerType = 0, procCharges = 1,
        effect = triple(6), effectApplyAuraName = triple(108),
        effectBasePoints = triple(-1001), effectMiscValue = triple(14),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple(),
        effectTriggerSpell = triple() },
    [133] = actionRecord(3, 80),
    [116] = actionRecord(3, 30),
    [9001] = actionRecord(3, 45),
    [2136] = actionRecord(3, 50),
    [589] = actionRecord(6, 25),
}

local playerClass, now, activeAura = "MAGE", 100, nil
local active, modifierCalls, costCalls = false, {}, {}
local baseModifiers = { [133] = -150, [116] = 0, [9001] = -100,
    [2136] = 0 }
local procModifiers = { [133] = -1150, [116] = 0, [9001] = -1200,
    [2136] = -1000 }
local costs = { [133] = 80, [116] = 30, [9001] = 45, [2136] = 50 }
local dbcCalls, durationCalls, auraCalls = 0, 0, 0

local function unsigned(value)
    return value < 0 and value + 4294967296 or value
end

UnitClass = function() return "Localized", playerClass end
GetSpellName = function()
    error("Clearcasting must not inspect localized spell names")
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
GetSpellDuration = function(spellId)
    durationCalls = durationCalls + 1
    assert(spellId == 12536, "only the exact proc aura has a duration")
    return 15000
end
GetSpellModifiers = function(spellId, modifier)
    modifierCalls[spellId] = (modifierCalls[spellId] or 0) + 1
    assert(modifier == 14, "only the COST modifier may be inspected")
    local value = active and procModifiers[spellId] or baseModifiers[spellId]
    assert(value ~= nil, "unexpected modifier query")
    return 0, unsigned(value), value == 0 and 0 or 1
end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls[spellId] = (costCalls[spellId] or 0) + 1
    local cost = costs[spellId]
    if active and procModifiers[spellId] == -1000
        or active and spellId == 133 then return nil end
    return { { type = 0, cost = cost, minCost = cost, costPercent = 0,
        costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    auraCalls = auraCalls + 1
    assert(spellId == 12536, "aura capture must use the numeric identity")
    return activeAura
end }
GetTime = function() return now end

dofile("Game/Player/MageClearcasting.lua")
dofile("Graph/MageClearcasting.lua")
local Evidence = XelAssist.Game.Player.MageClearcasting
local Graph = XelAssist.Graph.MageClearcasting

local state = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 }, actors = { player = { level = 30 } } }
local function action(spellId)
    return { spellId = spellId, actor = "player", executor = "playerSpell",
        facts = { kind = "damage" } }
end
local fireball, frostbolt, ambiguous, unseen = action(133), action(116),
    action(9001), action(2136)

assert(Evidence:Attach(state, "MAGE") and state.mageClearcasting.exact
    and state.mageClearcasting.active == false and auraCalls == 1,
    "an exact absent aura must produce a usable root snapshot")
local plain = { cost = 80, average = 100 }
assert(Evidence:CaptureFacts(fireball, plain, state) == plain,
    "inactive capture should only learn the exact baseline")
Evidence:CaptureFacts(frostbolt, { cost = 30 }, state)
Evidence:CaptureFacts(ambiguous, { cost = 45 }, state)
local fireModifierCalls, fireCostCalls = modifierCalls[133], costCalls[133]
local beforeDBC = dbcCalls
Evidence:CaptureFacts(fireball, plain, state)
assert(modifierCalls[133] == fireModifierCalls
    and costCalls[133] == fireCostCalls and dbcCalls == beforeDBC,
    "inactive roots must reuse the per-level baseline and action profile")

local other = action(589)
local otherFacts, beforeModifier = { cost = 25 }, modifierCalls[589]
assert(Evidence:CaptureFacts(other, otherFacts, state) == otherFacts
    and modifierCalls[589] == beforeModifier,
    "another class family must not enter mutable cost capture")

active, activeAura = true, { spellId = 12536, isHelpful = true,
    applications = 1, duration = 15, expirationTime = 110 }
assert(Evidence:Attach(state, "MAGE") and state.mageClearcasting.active
    and state.mageClearcasting.remaining == 10
    and state.mageClearcasting.expiresAt == 10,
    "active numeric aura evidence must seal graph-relative expiry")
local fireFacts = Evidence:CaptureFacts(fireball, { cost = 0 }, state)
local fireContract = fireFacts.mageClearcastingCost
assert(fireContract and fireContract.claimed and fireContract.exact
    and fireContract.eligible and fireContract.baselineCost == 80
    and fireContract.epoch == 110,
    "an exact -100 percent modifier delta and zero engine cost must be eligible")
local activeModifierCalls, activeCostCalls = modifierCalls[133], costCalls[133]
fireContract.baselineCost = 999
fireFacts = Evidence:CaptureFacts(fireball, { cost = 0 }, state)
fireContract = fireFacts.mageClearcastingCost
assert(fireContract.baselineCost == 80
    and modifierCalls[133] == activeModifierCalls
    and costCalls[133] == activeCostCalls,
    "one proc epoch must cache immutable per-spell contracts")

local frostFacts = Evidence:CaptureFacts(frostbolt, { cost = 30 }, state)
assert(frostFacts.mageClearcastingCost.exact
    and frostFacts.mageClearcastingCost.eligible == false
    and frostFacts.mageClearcastingCost.baselineCost == 30,
    "an exact unchanged cost modifier must preserve an unaffected spell")
local ambiguousFacts = Evidence:CaptureFacts(ambiguous, { cost = 0 }, state)
assert(ambiguousFacts.mageClearcastingCost.exact == false
    and ambiguousFacts.mageClearcastingCost.reason
        == "spell cost modifier regime changed with Clearcasting",
    "an additional simultaneous cost regime must fail closed")
local unseenFacts = Evidence:CaptureFacts(unseen, { cost = 0 }, state)
assert(unseenFacts.mageClearcastingCost.exact == false
    and unseenFacts.mageClearcastingCost.reason
        == "Clearcasting baseline cost unavailable",
    "a spell never observed without the proc must fail closed")

local prepared, reason, handled = Graph:PrepareLegal(
    fireball, state, fireFacts)
assert(handled and reason == nil and prepared.cost == 0
    and prepared ~= fireFacts and prepared.mageClearcastingConsumption
    and fireFacts.mageClearcastingConsumption == nil,
    "an eligible action starting before expiry must receive a copied zero cost")
local child = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 } }
assert(Graph:Copy(state, child) and child.mageClearcasting
    and child.mageClearcasting ~= state.mageClearcasting
    and child.mageClearcasting.profile ~= state.mageClearcasting.profile,
    "branch copies must not share mutable proc snapshots")
child.mageClearcasting.profile.duration = 99
assert(state.mageClearcasting.profile.duration == 15,
    "child profile mutation must not affect its sibling root")
local candidate = { action = fireball, tooltip = prepared,
    actionStart = 0, cost = 0 }
assert(Graph:Consume(child, candidate) and not child.mageClearcasting.active
    and child.mageClearcasting.consumed,
    "successful exact zero-cost action must consume the branch-local proc once")
prepared, reason, handled = Graph:PrepareLegal(fireball, child, fireFacts)
assert(handled and reason == nil and prepared.cost == 80
    and prepared.mageClearcastingConsumption == nil,
    "descendants after consumption must restore the captured baseline cost")
assert(state.mageClearcasting.active,
    "consuming one branch must not mutate its sibling")

prepared, reason, handled = Graph:PrepareLegal(
    frostbolt, state, frostFacts)
assert(handled and reason == nil and prepared.cost == 30
    and prepared.mageClearcastingConsumption == nil,
    "an exactly unaffected spell must keep its ordinary cost and proc")
state.playerGcdReadyAt = 11
prepared, reason, handled = Graph:PrepareLegal(fireball, state, fireFacts)
assert(handled and reason == nil and prepared.cost == 80
    and prepared.mageClearcastingConsumption == nil,
    "a proc expiring before player readiness must not fund the action")
prepared, reason, handled = Graph:PrepareLegal(
    ambiguous, state, ambiguousFacts)
assert(handled and prepared == nil
    and reason == "spell cost modifier regime changed with Clearcasting",
    "unresolved claimed cost evidence must block instead of guessing")
prepared, reason, handled = Graph:PrepareLegal(unseen, state, unseenFacts)
assert(handled and prepared == nil
    and reason == "Clearcasting baseline cost unavailable",
    "missing pre-proc baseline must block instead of treating nil as free")

GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
C_Spell.GetSpellPowerCost = function() error("cost read during graph search") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("aura read during graph search")
end
GetTime = function() error("wall-clock read during graph search") end
state.playerGcdReadyAt = 0
prepared = Graph:PrepareLegal(fireball, state, fireFacts)
local pureChild = { time = 0, playerGcdReadyAt = 0,
    actorReadyAt = { player = 0 } }
assert(prepared and prepared.cost == 0 and Graph:Copy(state, pureChild)
    and Graph:Consume(pureChild, { action = fireball, tooltip = prepared,
        actionStart = 0, cost = 0 }),
    "prepare, copy, and consume must use only immutable root evidence")

print("ok: Mage Clearcasting seals and consumes exact one-use cost evidence")
