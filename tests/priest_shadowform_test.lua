table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Player = {} }, Graph = {} }

local classToken, dbcCalls, costCalls = "PRIEST", 0, 0
local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local row = {
    school = 5, category = 39,
    attributes = 33882112, attributesEx = 131072,
    attributesEx2 = 2, attributesEx3 = 0, attributesEx4 = 0,
    stances = 0, stancesNot = 0, targets = 0,
    casterAuraState = 0, targetAuraState = 0,
    castingTimeIndex = 1, recoveryTime = 0,
    categoryRecoveryTime = 1500, durationIndex = 21,
    powerType = 0, manaCost = 0, manaCostPerlevel = 0,
    manaCostPercentage = 40, rangeIndex = 1,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    spellFamilyName = 6, spellFamilyFlags = 2147483648,
    effect = triple(6, 6, 6),
    effectApplyAuraName = triple(36, 79, 87),
    effectBasePoints = triple(0, 14, -16),
    effectBaseDice = triple(0, 1, 1),
    effectDieSides = triple(0, 1, 1),
    effectImplicitTargetA = triple(1, 1, 1),
    effectImplicitTargetB = triple(0, 0, 0),
    effectMiscValue = triple(28, 32, 1),
    effectTriggerSpell = triple(0, 0, 0),
}

function UnitClass()
    return classToken == "PRIEST" and "Priest" or "Mage", classToken
end

function GetSpellRecField(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    if spellId ~= 15473 then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls = costCalls + 1
    assert(spellId == 15473)
    return { { type = 0, cost = 40, minCost = 40, costPercent = 40,
        costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
end }

dofile("Game/Player/PriestShadowform.lua")
dofile("Graph/PriestShadowform.lua")
local Runtime = XelAssist.Game.Player.PriestShadowform
local Shadowform = XelAssist.Graph.PriestShadowform

local beforeOrdinary = dbcCalls
local ordinary, _, ordinaryHandled = Runtime:InferKnowledge(585)
assert(ordinary == nil and not ordinaryHandled and dbcCalls == beforeOrdinary,
    "ordinary Priest spells must not pay for Shadowform DBC discovery")

local facts, reason, handled = Runtime:InferKnowledge(15473)
assert(handled and facts and reason == nil and facts.kind == "form"
    and facts.kindExact and facts.self and facts.fixedTarget == "player"
    and facts.resourceType == "mana" and facts.priestShadowform
    and facts.requiresPriestShadowformEvidence
    and facts.priestShadowformEvidence.formID == 28
    and facts.priestShadowformEvidence.formMask == 134217728
    and facts.priestShadowformEvidence.shadowDamagePercent == 15
    and facts.priestShadowformEvidence.physicalDamageTakenPercent == -15
    and facts.priestShadowformEvidence.threatMultiplier == nil,
    "installed identity must infer only the exact numeric Shadowform shape")
local discoveryCalls = dbcCalls
assert(Runtime:InferKnowledge(15473) and dbcCalls == discoveryCalls,
    "validated installed topology must be cached across action discovery")

local action = { name = "localized text is irrelevant", spellId = 15473,
    actor = "player", facts = facts }
local captured = Runtime:CaptureFacts(action, facts)
assert(captured ~= facts and captured.priestShadowformEvidence ~=
    facts.priestShadowformEvidence and costCalls == 1
    and captured.priestShadowformCostExact
    and captured.priestShadowformEvidence.costExact
    and captured.priestShadowformEvidence.effectiveCost == 40
    and captured.cost == 40 and captured.powerType == 0
    and facts.priestShadowformEvidence.effectiveCost == nil,
    "root capture must copy one exact live percentage-mana cost")

local fixedCostAPI = C_Spell.GetSpellPowerCost
C_Spell.GetSpellPowerCost = function()
    return {
        { type = 0, cost = 40, minCost = 40, costPercent = 40,
            costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false },
        { type = 0, cost = 1, minCost = 1, costPercent = 0,
            costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false },
    }
end
local uncertainCost = Runtime:CaptureFacts(action, facts)
assert(not uncertainCost.priestShadowformCostExact
    and uncertainCost.cost == nil
    and uncertainCost.priestShadowformEvidence.costExact == false,
    "an ambiguous live cost response must fail the percentage cost closed")
C_Spell.GetSpellPowerCost = fixedCostAPI

local state = { playerForm = { available = true, formID = 0 },
    resourceType = 0, resource = 100, resourceMax = 200,
    playerResourceExact = true }
assert(Shadowform:Attach(state)
    and state.playerShadowformProfileExact
    and state.playerShadowformFormID == 0
    and state.playerShadowDamageMultiplier == 1
    and state.playerPhysicalDamageTakenMultiplier == 1,
    "root form zero must attach an exact inactive profile")

local rejected, rejectedReason = Shadowform:Prepare(
    action, state, uncertainCost)
assert(rejected == nil
    and string.find(rejectedReason or "", "cost") ~= nil,
    "graph preparation must not fall back to the DBC zero base cost")

local prepared
prepared, reason, handled = Shadowform:Prepare(action, state, captured)
assert(handled and prepared and reason == nil and prepared.cost == 40
    and prepared.powerType == 0
    and prepared.priestShadowformTransition.kind == "priestShadowform"
    and prepared.priestShadowformTransition.sourceForm == 0
    and prepared.priestShadowformTransition.targetForm == 28
    and prepared.priestShadowformTransition.targetMask == 134217728
    and prepared.priestShadowformTransition.shadowDamageMultiplier == 1.15
    and prepared.priestShadowformTransition
        .physicalDamageTakenMultiplier == 0.85,
    "sealed preparation must expose the exact consequence-bearing transition")
assert(costCalls == 1 and dbcCalls == discoveryCalls,
    "preparation must not reread mutable cost or DBC APIs")

local lowMana = { playerForm = { available = true, formID = 0 },
    resourceType = 0, resource = 39, playerResourceExact = true }
Shadowform:Attach(lowMana)
rejected, rejectedReason = Shadowform:Prepare(action, lowMana, captured)
assert(rejected == nil and rejectedReason == "resource",
    "an exact percentage-cost transition must not overdraw mana")

local spirit = { playerForm = { available = true, formID = 32 },
    resourceType = 0, resource = 100, playerResourceExact = true }
Shadowform:Attach(spirit)
rejected, rejectedReason = Shadowform:Prepare(action, spirit, captured)
assert(rejected == nil and rejectedReason == "another Priest form is active",
    "the leaf must not invent a transition out of another Priest form")

local context = { tooltip = prepared, power = 99, expectedPower = 88,
    effectivePower = 77, value = 55, estimated = true }
assert(Shadowform:Score(context) and context.power == 0
    and context.expectedPower == 0 and context.effectivePower == 0
    and context.value == 0 and not context.estimated,
    "Shadowform itself must remain a zero-value strategic setup edge")

local activeRoot = { playerForm = { available = true, formID = 28 },
    resourceType = 0, resource = 60, playerResourceExact = true }
assert(Shadowform:Attach(activeRoot)
    and activeRoot.playerShadowDamageMultiplier == 1.15
    and activeRoot.playerPhysicalDamageTakenMultiplier == 0.85,
    "an observed active form must attach both exact aura consequences")

local fixedDBC, fixedCost, fixedClass = GetSpellRecField,
    C_Spell.GetSpellPowerCost, UnitClass
GetSpellRecField = function() error("graph search reread DBC") end
C_Spell.GetSpellPowerCost = function() error("graph search reread live cost") end
UnitClass = function() error("graph search reread class") end

local candidate = { action = action, cost = 40, tooltip = prepared,
    priestShadowformTransition = prepared.priestShadowformTransition }
local resourceBefore = state.resource
assert(Shadowform:Apply(state, candidate)
    and state.playerForm.formID == 28 and state.playerForm.projected
    and state.playerShadowformProfileExact
    and state.playerShadowformFormID == 28
    and state.playerShadowDamageMultiplier == 1.15
    and state.playerPhysicalDamageTakenMultiplier == 0.85
    and state.resource == resourceBefore,
    "projection must change only form consequences; shared consumption pays cost")

local damage = { state = state, kind = "damage",
    action = { actor = "player" }, effectTooltip = { school = 5 },
    power = 100, expectedPower = 80 }
assert(Shadowform:AdjustDamage(damage)
    and math.abs(damage.power - 115) < 0.000001
    and math.abs(damage.expectedPower - 92) < 0.000001
    and damage.shadowformDamageMultiplier == 1.15,
    "exact player Shadow damage must receive the installed 15 percent factor")

local physical = { state = state, kind = "damage",
    action = { actor = "player" }, effectTooltip = { school = 0 },
    power = 100, expectedPower = 100 }
assert(not Shadowform:AdjustDamage(physical) and physical.power == 100,
    "physical outgoing damage must not receive the Shadow-only factor")
local petShadow = { state = state, kind = "damage",
    action = { actor = "pet" }, effectTooltip = { school = 5 },
    power = 100, expectedPower = 100 }
assert(not Shadowform:AdjustDamage(petShadow) and petShadow.power == 100,
    "a Priest aura must not be applied to pet-owned Shadow damage")

local amount, incomingReason, incomingHandled = Shadowform:AdjustIncoming(
    state, { kind = "player" }, 100, 0)
assert(incomingHandled and incomingReason == nil
    and math.abs(amount - 85) < 0.000001,
    "exact physical incoming damage must receive the installed reduction")
amount, incomingReason, incomingHandled = Shadowform:AdjustIncoming(
    state, { kind = "player" }, 100, 2)
assert(incomingHandled and incomingReason == nil and amount == 100,
    "nonphysical incoming damage must remain unchanged")
amount, incomingReason, incomingHandled = Shadowform:AdjustIncoming(
    state, { kind = "pet" }, 100, 0)
assert(not incomingHandled and incomingReason == nil and amount == 100,
    "Shadowform mitigation must remain local to the player")
amount, incomingReason, incomingHandled = Shadowform:AdjustIncoming(
    state, { kind = "player" }, 100, nil)
assert(incomingHandled and amount == nil
    and incomingReason == "incoming damage school unavailable",
    "unknown school evidence must not fabricate physical mitigation")

rejected, rejectedReason = Shadowform:Prepare(action, state, captured)
assert(rejected == nil and rejectedReason == "Shadowform already active",
    "projected active form must suppress duplicate setup without an aura scan")

GetSpellRecField, C_Spell.GetSpellPowerCost, UnitClass =
    fixedDBC, fixedCost, fixedClass
Runtime:Invalidate()
row.effectMiscValue[2] = 127
local broken, brokenReason, brokenHandled = Runtime:InferKnowledge(15473)
assert(broken == nil and brokenHandled
    and string.find(brokenReason or "", "topology") ~= nil,
    "a mismatched school mask must fail the recognized action closed")
row.effectMiscValue[2] = 32

Runtime:Invalidate()
classToken = "MAGE"
local beforeForeign = dbcCalls
local foreign, _, foreignHandled = Runtime:InferKnowledge(15473)
assert(foreign == nil and not foreignHandled and dbcCalls == beforeForeign,
    "another class must not pay for or receive Shadowform evidence")

print("ok: exact Shadowform transition, Shadow damage and physical mitigation")
