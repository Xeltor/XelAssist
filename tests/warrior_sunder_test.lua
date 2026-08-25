-- Rank-specific Sunder Armor base threat and stack-cap projection. Server
-- values remain explicitly estimated; this is combat math, never a rotation.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil
GetSpellCooldown = function() return 0, 0, 1 end

local knowledge = XelAssist.Combat.Knowledge["Sunder Armor"]
local ids = { 7386, 7405, 8380, 11596, 11597 }
local threat = { 45, 99, 153, 207, 261 }
local armor = { 90, 180, 270, 360, 450 }
assert(knowledge and knowledge.stackable == 5
    and knowledge.refreshAtStackCap and knowledge.runtimeUnverified
    and knowledge.threat == nil
    and knowledge.baseFlatThreatSource == "VMaNGOS build-5875 server profile",
    "Sunder must expose estimated rank-specific base threat without a multiplier")

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function action(index, forcedRank)
    local facts = copy(knowledge)
    facts.testMinRange, facts.testMaxRange = 0, 5
    facts.testArmorReduction, facts.testDuration = armor[index], 30
    local value = Fixture.Action("Sunder Armor", forcedRank or index,
        "debuff", 9999, 10, facts)
    value.executor, value.spellId = "playerSpell", ids[index]
    return value
end

local function aura(stacks, remaining)
    return { remaining = remaining or 12, duration = 30, mine = true,
        target = "target", targetModifier = true,
        applicationProbability = 1, stacks = stacks,
        expectedStacks = stacks }
end

local function modifier(stacks, perStack, remaining)
    local total = stacks * perStack
    return { name = "Sunder Armor", group = "majorArmor", mine = true,
        activeRoot = true, remaining = remaining or 12,
        stackCap = 5, stackMass = { [stacks] = 1 },
        stacks = stacks, expectedStacks = stacks,
        resistanceReduction = { [0] = total }, damageTaken = {},
        successResistanceReduction = { [0] = total },
        successDamageTaken = {}, failureResistanceReduction = { [0] = total },
        failureDamageTaken = {}, deliveryProbability = 1 }
end

local function record(guid, selected, stacks, perStack, remaining)
    local projected, observed, effects = {}, {}, {}
    if stacks then
        projected["Sunder Armor"] = aura(stacks, remaining)
        observed["Sunder Armor"] = aura(stacks, remaining)
        effects["Sunder Armor"] = modifier(stacks, perStack, remaining)
    end
    return { key = guid, guid = guid, unit = selected and "target" or "mouseover",
        source = selected and "selected" or "mouseover", selected = selected,
        executable = selected, dead = false, health = selected and 1000 or 700,
        healthMax = selected and 1000 or 700, healthExact = true,
        targetAuras = observed, projectedAuras = projected,
        modifierEffects = effects, damageTaken = {}, baseDamageTaken = {},
        victim = { available = true, guid = "ally-guid",
            targetsPlayer = false, targetsPet = false, targetsGroup = true },
        threat = { available = true, victimGuid = "ally-guid",
            playerHasAggro = false, petHasAggro = false,
            playerDelta = 0, playerDeltaExact = true, petDelta = 0 },
        targetRef = { unit = selected and "target" or "mouseover", guid = guid,
            relation = "hostile", source = selected and "selected" or "mouseover" } }
end

local function state(stacks, perStack, remaining, withOther)
    local value = Fixture.State("smart")
    value.tank, value.role, value.resourceType = true, "tank", 1
    value.resource, value.resourceMax, value.groupSize = 100, 100, 4
    local primary = record("target-guid", true, stacks, perStack, remaining)
    local other = withOther and record("other-guid", false, 3, 90, 9) or nil
    local order = other and { primary.key, other.key } or { primary.key }
    local byKey = { [primary.key] = primary }
    local byUnit = { target = primary.key }
    if other then byKey[other.key], byUnit.mouseover = other, other.key end
    value.hostiles = { order = order, byKey = byKey, byUnit = byUnit,
        selectedKey = primary.key, total = table.getn(order), capped = false,
        discoveryComplete = true }
    XelAssist.Graph.State:SyncSelectedHostile(value)
    value.tank, value.role, value.resourceType = true, "tank", 1
    value.resource, value.resourceMax, value.groupSize = 100, 100, 4
    return value
end

local function descriptor(value, source)
    return XelAssist.Graph.Targets:Targets(value, source)[1]
end

local function candidate(value, source)
    local scored, blocker = XelAssist.Graph.Scoring:Evaluate(
        value, source, descriptor(value, source))
    assert(scored, tostring(blocker))
    return scored
end

local i
for i = 1, table.getn(ids) do
    assert(knowledge.spellIds[i] == ids[i]
        and knowledge.baseFlatThreatBySpellId[ids[i]] == threat[i],
        "Sunder rank evidence drifted at index " .. i)
    local scored = candidate(action(i, 99), state())
    assert(scored.threat == threat[i] and scored.power == 0
        and scored.rawPower == 0 and scored.estimated == true,
        "Sunder must use spell identity, not rank text or DBC armor magnitude")
end

local unknown = action(1)
unknown.spellId = 999999
local unknownCandidate = candidate(unknown, state())
assert(unknownCandidate.threat == 0 and unknownCandidate.estimated == true,
    "an unknown Sunder identity must not inherit fabricated fixed threat")

local source = state(4, 90, 12, true)
local first = candidate(action(1), source)
local firstOut = XelAssist.Graph.Transitions:Advance(source, first)
local firstRecord = XelAssist.Graph.State:SelectedHostile(firstOut)
local firstEffect = firstRecord.modifierEffects["Sunder Armor"]
assert(first.threat == 45 and firstRecord.health == 1000
    and firstEffect.expectedStacks == 5
    and firstEffect.resistanceReduction[0] == 450
    and firstRecord.projectedAuras["Sunder Armor"].stacks == 5
    and firstRecord.threat.playerDelta == 45
    and firstRecord.threat.playerDeltaExact == false
    and firstRecord.threat.containsEstimatedBaseThreat == true
    and firstRecord.threat.projectedSource == knowledge.baseFlatThreatSource,
    "four-stack Sunder must add one armor stack and estimated base threat")
assert(source.hostiles.byKey["target-guid"].threat.playerDelta == 0
    and source.hostiles.byKey["target-guid"].modifierEffects["Sunder Armor"]
        .resistanceReduction[0] == 360
    and firstOut.hostiles.byKey["other-guid"].health == 700
    and firstOut.hostiles.byKey["other-guid"].threat.playerDelta == 0
    and firstOut.hostiles.byKey["other-guid"].modifierEffects["Sunder Armor"]
        .resistanceReduction[0] == 270,
    "Sunder must remain immutable and selected-hostile local")
assert(firstRecord.threat.victimGuid == "ally-guid"
    and firstRecord.threat.playerHasAggro == false
    and firstRecord.threat.projectedVictimGuid == nil
    and firstOut.hasAggro == false,
    "estimated fixed threat must not invent an aggro ownership switch")

source = state(5, 90, 3)
local capped = candidate(action(1), source)
local cappedOut = XelAssist.Graph.Transitions:Advance(source, capped)
local cappedRecord = XelAssist.Graph.State:SelectedHostile(cappedOut)
assert(cappedRecord.modifierEffects["Sunder Armor"].resistanceReduction[0] == 450
    and cappedRecord.modifierEffects["Sunder Armor"].expectedStacks == 5
    and cappedRecord.projectedAuras["Sunder Armor"].remaining > 29
    and cappedRecord.threat.playerDelta == 45,
    "a five-stack Sunder must refresh without projecting a sixth armor stack")
local twice = XelAssist.Graph.Transitions:Advance(
    cappedOut, candidate(action(1), cappedOut))
local twiceRecord = XelAssist.Graph.State:SelectedHostile(twice)
assert(twiceRecord.modifierEffects["Sunder Armor"].resistanceReduction[0] == 450
    and twiceRecord.threat.playerDelta == 90,
    "repeated capped Sunders must add threat while armor remains capped")

XelAssist.Combat.Resistance = { Estimate = function()
    return { landChance = 0.5, unknown = false, source = "test delivery" }
end }
source = state(4, 90, 12)
local partial = candidate(action(1), source)
local partialOut = XelAssist.Graph.Transitions:Advance(source, partial)
local partialRecord = XelAssist.Graph.State:SelectedHostile(partialOut)
assert(partial.threat == 22.5
    and partialRecord.modifierEffects["Sunder Armor"].expectedStacks == 4.5
    and partialRecord.modifierEffects["Sunder Armor"].resistanceReduction[0] == 405
    and partialRecord.threat.playerDelta == 22.5,
    "partial delivery must blend one stack and base threat exactly once")

source = state(5, 90, 2)
partial = candidate(action(1), source)
partialOut = XelAssist.Graph.Transitions:Advance(source, partial)
partialRecord = XelAssist.Graph.State:SelectedHostile(partialOut)
assert(partialRecord.modifierEffects["Sunder Armor"].expectedStacks == 5
    and partialRecord.modifierEffects["Sunder Armor"].resistanceReduction[0] == 450,
    "a partial capped refresh must preserve the still-live failure branch")
local afterFallback = XelAssist.Graph.Effects:StateAtImpact(partialOut, 3)
local fallbackEffect = XelAssist.Graph.State:SelectedHostile(afterFallback)
    .modifierEffects["Sunder Armor"]
assert(fallbackEffect.expectedStacks == 2.5
    and fallbackEffect.stackMass[0] == 0.5
    and fallbackEffect.stackMass[5] == 0.5
    and fallbackEffect.resistanceReduction[0] == 225,
    "expired prior aura must leave only the delivered refresh branch")
local secondPartial = candidate(action(1), afterFallback)
local secondPartialOut = XelAssist.Graph.Transitions:Advance(
    afterFallback, secondPartial)
local secondEffect = XelAssist.Graph.State:SelectedHostile(secondPartialOut)
    .modifierEffects["Sunder Armor"]
assert(secondEffect.expectedStacks == 2.75
    and secondEffect.stackMass[0] == 0.25
    and secondEffect.stackMass[1] == 0.25
    and secondEffect.stackMass[5] == 0.5
    and secondEffect.resistanceReduction[0] == 247.5,
    "a second partial cast must convolve capped stack probability, not an average")
XelAssist.Combat.Resistance = nil

source = state(5, 261, 5)
local lowerOut = XelAssist.Graph.Transitions:Advance(
    source, candidate(action(1), source))
assert(XelAssist.Graph.State:SelectedHostile(lowerOut)
        .modifierEffects["Sunder Armor"].resistanceReduction[0] == 1305,
    "a lower-rank capped refresh must never downgrade stronger observed armor")

source = state(5, 90, 8)
local rankOne, rankFive = action(1, 1), action(5, 5)
local rankOneCandidate = candidate(rankOne, source)
local rankFiveCandidate = candidate(rankFive, source)
assert(rankFiveCandidate.value > rankOneCandidate.value
    and rankFiveCandidate.threat == 261 and rankOneCandidate.threat == 45,
    "rank-specific base threat must affect tank candidate value")
Fixture:Use(source, { rankOne, rankFive })
XelAssistCharDB.graphDepth, XelAssistCharDB.role = 1, "tank"
XelAssistCharDB.allowAoe, XelAssistCharDB.petThreat = false, "auto"
local plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
assert(plan and plan.action.spellId == 11597, tostring(reason)
        .. ": tank rank choice must use estimated base threat at stack cap")

print("ok: Warrior Sunder rank threat and capped armor projection")
