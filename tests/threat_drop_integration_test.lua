XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function hostile(state)
    return { key = "selected", unit = "target", guid = state.targetGUID,
        selected = true, dead = false, hasPlayerAggro = true,
        health = state.targetHealth, healthMax = state.targetMax,
        healthExact = true, targetAuras = {}, projectedAuras = {},
        threat = { available = true, playerHasAggro = true,
            petHasAggro = false, playerDelta = 0,
            playerDeltaExact = true, petDelta = 0 } }
end

local state = Fixture.State("smart")
state.inCombat, state.hasAggro, state.tank = true, true, false
state.hostiles = { order = { "selected" }, selectedKey = "selected",
    capped = false, byKey = { selected = hostile(state) } }
local feign = Fixture.Action("Localized threat tool", 1,
    "threatDrop", 0, 0, { self = true })
feign.mock.threatDropModel = "resistible-all-or-nothing"
Fixture:Use(state, { feign })
local descriptor = XelAssist.Graph.Targets:Targets(feign, state)[1]
local candidate, reason = XelAssist.Graph.Scoring:Evaluate(
    feign, state, descriptor)
assert(candidate and reason == nil
    and math.abs(candidate.value - 3696) < 0.0001
    and candidate.reason == "may drop unwanted aggro",
    "production scoring must consume the DBC-selected threat-drop model")

local projected = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(projected.hasAggro == nil
    and projected.hostiles.byKey.selected.threat
        .projectedPlayerOwnershipUnknown,
    "production transitions must preserve resisted and successful branches")

local unknown = Fixture.Action("Unclassified threat tool", 1,
    "threatDrop", 0, 0, { self = true })
Fixture:Use(state, { unknown })
descriptor = XelAssist.Graph.Targets:Targets(unknown, state)[1]
candidate, reason = XelAssist.Graph.Scoring:Evaluate(
    unknown, state, descriptor)
assert(candidate == nil and reason == "threat drop mechanics unknown",
    "production legality must reject an unclassified threat-drop action")

local feintEvidence = { valid = true, exact = true,
    model = "target-local-flat", spellId = 1966,
    playerLevel = 20, effectiveLevel = 20,
    baseLevel = 16, spellLevel = 16, maxLevel = 26,
    signedBaseThreat = -150, signedThreatPerLevel = -1, amount = 154,
    powerType = 3, cost = 20, minRange = 0, maxRange = 5,
    category = 82, categoryCooldown = 10, gcd = 1, cast = 0,
    school = 0, dmgClass = 2, deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
    refundsPowerOnFailure = true, resourceRefundAmountExact = false,
    recipient = "selected-hostile", effectOpcode = 63 }
local feint = Fixture.Action("Localized Feint", 1, "threatDrop", 0, 20, {
    rogueFeint = true, targetLocalThreatDrop = true,
    threatDropModel = "target-local-flat",
    rogueFeintEvidence = feintEvidence, submissionGuarded = true,
    melee = true, school = 0, deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
    testMinRange = 0, testMaxRange = 5, testSchool = 0 })
state = Fixture.State("smart")
state.inCombat, state.hasAggro, state.tank = true, true, false
state.hostiles = { order = { "selected", "other" },
    selectedKey = "selected", capped = false, byKey = {
        selected = hostile(state),
        other = { key = "other", unit = "nameplate1", guid = "other-guid",
            selected = false, dead = false, hasPlayerAggro = false,
            threat = { available = true, playerHasAggro = false,
                petHasAggro = true, playerDelta = 0,
                playerDeltaExact = true, petDelta = 0 } } } }
local priorResistance = XelAssist.Combat.Observations.ResistanceMultiplier
XelAssist.Combat.Observations.ResistanceMultiplier = function()
    return 1, "exact Feint delivery fixture",
        { multiplier = 1, landChance = 0.75, source = "fixture",
            unknown = false }
end
Fixture:Use(state, { feint })
local recipients = XelAssist.Graph.Targets:Targets(feint, state)
assert(table.getn(recipients) == 1
    and recipients[1].guid == state.targetGUID
    and recipients[1].source == "selected",
    "production target selection must keep Feint on only the selected hostile")
candidate, reason = XelAssist.Graph.Scoring:Evaluate(
    feint, state, recipients[1])
assert(candidate and reason == nil
    and candidate.effectDelivery == 0.75
    and candidate.rogueFeintExpectedThreatReduction == 115.5
    and math.abs(candidate.value - 97.416) < 0.0001,
    "production scoring must apply Feint delivery once before resource and confidence reserves")
projected = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(projected.hostiles.byKey.selected.threat.playerDelta == -115.5
    and projected.hostiles.byKey.other.threat.playerDelta == 0,
    "production transitions must keep Feint target-local")
XelAssist.Combat.Observations.ResistanceMultiplier = priorResistance

print("ok: threat-drop semantics cross production legality and transitions")
