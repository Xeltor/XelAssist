-- Exact Omen/Clearcasting root evidence and search-pure cost consumption.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value) return #value end
dofile("Game/ResourceCost.lua")

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local rows = {
    [16864] = { spellFamilyName = 0, attributes = 66000,
        procChance = 100, procCharges = 0,
        effect = triple(6), effectApplyAuraName = triple(42),
        effectTriggerSpell = triple(16870),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple() },
    [16870] = { spellFamilyName = 7, attributes = 262144,
        durationIndex = 8, procFlags = 87376, procChance = 100,
        procCharges = 1, powerType = 0, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        effect = triple(6), effectApplyAuraName = triple(108),
        effectMiscValue = triple(14), effectBasePoints = triple(-101),
        effectBaseDice = triple(1), effectImplicitTargetA = triple(1),
        effectImplicitTargetB = triple(), effectTriggerSpell = triple() },
    [1001] = { spellFamilyName = 7, powerType = 0, manaCost = 35,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1002] = { spellFamilyName = 7, powerType = 1, manaCost = 100,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1003] = { spellFamilyName = 7, powerType = 3, manaCost = 35,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1004] = { spellFamilyName = 7, powerType = 0, manaCost = 20,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1005] = { spellFamilyName = 7, powerType = 0, manaCost = 45,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1006] = { spellFamilyName = 7, powerType = 3, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [1007] = { spellFamilyName = 7, powerType = 0, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = 20,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
    [2001] = { spellFamilyName = 3, powerType = 0, manaCost = 25,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0 },
}

local dbcCalls, modifierCalls, costCalls, auraCalls = 0, 0, 0, 0
function GetSpellRecField(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = rows[spellId]
    if not row or row[field] == nil then error("missing DBC fixture field") end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

local learned, active, aura, modifierDrift = true, false, nil, 0
UnitClass = function() return "Druid", "DRUID" end
IsPlayerSpell = function(spellId)
    assert(spellId == 16864)
    return learned
end
GetSpellDuration = function(spellId)
    assert(spellId == 16870)
    return 15000
end
GetTime = function() return 100 end
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    auraCalls = auraCalls + 1
    assert(spellId == 16870)
    return aura
end }
GetSpellInfo = function() error("localized names must not select Omen") end
GetSpellName = GetSpellInfo

local eligible = { [1001] = true, [1002] = true, [1003] = true,
    [1005] = true }
local rawCosts = { [1001] = 35, [1002] = 100, [1003] = 35,
    [1004] = 20, [1005] = 45 }
GetSpellModifiers = function(spellId, operation)
    modifierCalls = modifierCalls + 1
    assert(operation == 14)
    return 0, active and eligible[spellId] and -100 + modifierDrift or 0,
        active and 2 or 1
end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls = costCalls + 1
    if active and eligible[spellId] then
        if modifierDrift == 0 then return nil end
        local changed = math.max(1, math.floor(rawCosts[spellId]
            * modifierDrift / 100))
        return { { type = rows[spellId].powerType,
            cost = changed, minCost = changed, costPercent = 0,
            costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
    end
    local row, cost = rows[spellId], rawCosts[spellId]
    if not row or not cost then return nil end
    return { { type = row.powerType, cost = cost, minCost = cost,
        costPercent = 0, costPerSec = 0, requiredAuraID = 0,
        hasRequiredAura = false } }
end }

dofile("Game/Player/DruidClearcasting.lua")
local Runtime = XelAssist.Game.Player.DruidClearcasting

local function state(formID)
    return { time = 0, actorReadyAt = { player = 0 }, playerGcdReadyAt = 0,
        actors = { player = { level = 40 } },
        druidFormState = { available = true, formID = formID } }
end

local function action(spellId)
    return { spellId = spellId, actor = "player", executor = "playerSpell" }
end

local caster, bear, cat = state(0), state(5), state(1)
assert(Runtime:Attach(caster, "DRUID")
    and caster.druidClearcasting.exact
    and caster.druidClearcasting.learned
    and caster.druidClearcasting.active == false,
    "an inactive learned Omen must be exact root evidence")
local profileCalls = dbcCalls
local second = state(0)
assert(Runtime:Attach(second, "DRUID") and dbcCalls == profileCalls,
    "the immutable installed topology must be cached")

Runtime:CaptureFacts(action(1001), { cost = 35 }, caster)
assert(Runtime:Attach(bear, "DRUID"))
Runtime:CaptureFacts(action(1002), { cost = 10 }, bear)
assert(Runtime:Attach(cat, "DRUID"))
Runtime:CaptureFacts(action(1003), { cost = 35 }, cat)
Runtime:CaptureFacts(action(1004), { cost = 20 }, caster)
Runtime:CaptureFacts(action(1006), { cost = 0 }, caster)

active = true
aura = { spellId = 16870, isHelpful = true, applications = 1,
    duration = 15, expirationTime = 110 }
caster, bear, cat = state(0), state(5), state(1)
assert(Runtime:Attach(caster, "DRUID")
    and caster.druidClearcasting.active
    and caster.druidClearcasting.remainingCharges == 1
    and caster.druidClearcasting.expiresAt == 10,
    "numeric aura identity must seal one live charge and graph expiry")
local immutable = state(0)
caster.druidClearcasting.profile.modifierAmount = -1
assert(Runtime:Attach(immutable, "DRUID")
    and immutable.druidClearcasting.profile.modifierAmount == -100,
    "root snapshots must not mutate the cached installed profile")
caster = immutable
assert(Runtime:Attach(bear, "DRUID") and Runtime:Attach(cat, "DRUID"))

local manaFacts = Runtime:CaptureFacts(action(1001), { cost = 35 }, caster)
local rageFacts = Runtime:CaptureFacts(action(1002), { cost = 10 }, bear)
local energyFacts = Runtime:CaptureFacts(action(1003), { cost = 35 }, cat)
local unaffected = Runtime:CaptureFacts(action(1004), { cost = 20 }, caster)
local zeroCost = Runtime:CaptureFacts(action(1006), { cost = 0 }, caster)
local unsupported = Runtime:CaptureFacts(action(1007), { cost = 0 }, caster)
assert(manaFacts.druidClearcastingCost.exact
    and manaFacts.druidClearcastingCost.eligible
    and manaFacts.druidClearcastingCost.baselineCost == 35,
    "an exact mana-cost delta must seal an eligible contract")
assert(rageFacts.druidClearcastingCost.exact
    and rageFacts.druidClearcastingCost.baselineCost == 10,
    "raw engine rage cost must be normalized to display resource units")
assert(energyFacts.druidClearcastingCost.exact
    and energyFacts.druidClearcastingCost.baselineCost == 35,
    "energy must retain its exact engine display cost")
assert(unaffected.druidClearcastingCost.exact
    and unaffected.druidClearcastingCost.eligible == false
    and unaffected.druidClearcastingCost.activeCost == 20,
    "engine-proven unaffected actions must preserve cost without consuming")
assert(zeroCost.druidClearcastingCost.exact
    and zeroCost.druidClearcastingCost.eligible == false
    and zeroCost.druidClearcastingCost.baselineCost == 0,
    "an exact zero-cost unaffected action must remain neutral")
assert(unsupported.druidClearcastingCost.claimed
    and unsupported.druidClearcastingCost.exact == false
    and unsupported.druidClearcastingCost.reason
        == "Druid Clearcasting action cost shape is unsupported",
    "an active unsupported Druid cost shape must be claimed and inexact")

local callsBefore = modifierCalls + costCalls
local cachedFacts = Runtime:CaptureFacts(action(1001), { cost = 35 }, caster)
assert(cachedFacts.druidClearcastingCost.exact
    and modifierCalls + costCalls == callsBefore,
    "one root evaluation must cache immutable per-action contracts")
modifierDrift = 10
local changedRoot = state(0)
assert(Runtime:Attach(changedRoot, "DRUID"))
local drifted = Runtime:CaptureFacts(action(1001), { cost = 35 }, changedRoot)
assert(drifted.druidClearcastingCost.exact == false
    and drifted.druidClearcastingCost.reason
        == "Druid Clearcasting cost regime is ambiguous"
    and modifierCalls + costCalls > callsBefore,
    "the same aura epoch in a new root must revalidate live cost modifiers")
modifierDrift = 0
local unrelated = { cost = 25 }
assert(Runtime:CaptureFacts(action(2001), unrelated, caster) == unrelated,
    "another spell family must remain outside the mechanic")

local noBaseline = state(0)
Runtime:InvalidateCosts()
assert(Runtime:Attach(noBaseline, "DRUID"))
local missing = Runtime:CaptureFacts(action(1005), { cost = 45 }, noBaseline)
assert(missing.druidClearcastingCost
    and missing.druidClearcastingCost.exact == false,
    "active-before-baseline evidence must fail closed")

active, aura, learned = false, nil, false
local beforeAura = auraCalls
local untalented = state(0)
assert(Runtime:Attach(untalented, "DRUID")
    and untalented.druidClearcasting.exact
    and untalented.druidClearcasting.learned == false
    and auraCalls == beforeAura,
    "an exact unlearned talent must bypass mutable aura work")

learned = true
Runtime:Invalidate()
rows[16870].effectBasePoints = triple(-100)
local malformed = state(0)
assert(not Runtime:Attach(malformed, "DRUID")
    and malformed.druidClearcasting.reason
        == "Druid Clearcasting DBC topology is incomplete",
    "recognized topology drift must fail closed")
rows[16870].effectBasePoints = triple(-101)
Runtime:Invalidate()

-- Rebuild exact contracts, then forbid every mutable runtime API in search.
active, aura = false, nil
caster, bear, cat = state(0), state(5), state(1)
assert(Runtime:Attach(caster, "DRUID"))
Runtime:CaptureFacts(action(1001), {}, caster)
Runtime:CaptureFacts(action(1004), {}, caster)
Runtime:CaptureFacts(action(1006), {}, caster)
assert(Runtime:Attach(bear, "DRUID"))
Runtime:CaptureFacts(action(1002), {}, bear)
assert(Runtime:Attach(cat, "DRUID"))
Runtime:CaptureFacts(action(1003), {}, cat)
active = true
aura = { spellId = 16870, isHelpful = true, applications = 1,
    duration = 15, expirationTime = 110 }
caster, bear, cat = state(0), state(5), state(1)
assert(Runtime:Attach(caster, "DRUID") and Runtime:Attach(bear, "DRUID")
    and Runtime:Attach(cat, "DRUID"))
manaFacts = Runtime:CaptureFacts(action(1001), { cost = 35 }, caster)
rageFacts = Runtime:CaptureFacts(action(1002), { cost = 10 }, bear)
energyFacts = Runtime:CaptureFacts(action(1003), { cost = 35 }, cat)
unaffected = Runtime:CaptureFacts(action(1004), { cost = 20 }, caster)
zeroCost = Runtime:CaptureFacts(action(1006), { cost = 0 }, caster)
unsupported = Runtime:CaptureFacts(action(1007), { cost = 0 }, caster)

GetSpellRecField = function() error("graph search reread DBC") end
GetSpellModifiers = function() error("graph search reread modifiers") end
C_Spell.GetSpellPowerCost = function() error("graph search reread cost") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("graph search reread aura")
end
IsPlayerSpell = function() error("graph search reread talent") end
GetTime = function() error("graph search reread clock") end

dofile("Graph/DruidClearcasting.lua")
local Graph = XelAssist.Graph.DruidClearcasting
local prepared, reason, handled = Graph:PrepareLegal(
    action(1001), caster, manaFacts)
assert(handled and not reason and prepared.cost == 0
    and prepared.druidClearcastingConsumption,
    "an active exact contract must make the eligible action free")
local child = state(0)
assert(Graph:Copy(caster, child)
    and child.druidClearcasting ~= caster.druidClearcasting
    and child.druidClearcasting.profile
        ~= caster.druidClearcasting.profile,
    "branch copies must isolate Clearcasting consumption")
local candidate = { action = action(1001), tooltip = prepared,
    cost = prepared.cost, actionStart = 0 }
assert(Graph:Consume(child, candidate)
    and child.druidClearcasting.active == false
    and caster.druidClearcasting.active == true,
    "one chosen eligible action must consume only its branch charge")
local after = Graph:PrepareLegal(action(1001), child, manaFacts)
assert(after and after.cost == 35
    and after.druidClearcastingConsumption == nil,
    "later descendants must pay the sealed baseline after consumption")

local ragePrepared = Graph:PrepareLegal(action(1002), bear, rageFacts)
local energyPrepared = Graph:PrepareLegal(action(1003), cat, energyFacts)
assert(ragePrepared.cost == 0 and energyPrepared.cost == 0,
    "one causal mechanic must cover exact rage and energy actions")
local neutral = Graph:PrepareLegal(action(1004), caster, unaffected)
assert(neutral.cost == 20 and not neutral.druidClearcastingConsumption,
    "an unaffected action must neither discount nor consume the proc")
local zeroNeutral = Graph:PrepareLegal(action(1006), caster, zeroCost)
assert(zeroNeutral.cost == 0
    and not zeroNeutral.druidClearcastingConsumption,
    "an exact zero-cost unaffected action must remain legal and neutral")
local unsafe, unsafeReason, unsafeClaimed = Graph:PrepareLegal(
    action(1007), caster, unsupported)
assert(unsafe == nil and unsafeClaimed and unsafeReason
        == "Druid Clearcasting action cost shape is unsupported",
    "an unsupported potentially affected action must fail closed")
local expired = state(0)
assert(Graph:Copy(caster, expired))
expired.actorReadyAt.player = 10
local late = Graph:PrepareLegal(action(1001), expired, manaFacts)
assert(late.cost == 35 and not late.druidClearcastingConsumption,
    "a proc expiring at action start must not fund the future cast")
local blocked, blockedReason, claimed = Graph:PrepareLegal(
    action(1005), noBaseline, missing)
assert(blocked == nil and claimed and blockedReason
        == "Druid Clearcasting baseline unavailable",
    "an active proc with no learned baseline must block unsafe evaluation")

print("ok: Druid Clearcasting seals exact cross-form costs and one charge")
