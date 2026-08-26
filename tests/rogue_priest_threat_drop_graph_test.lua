-- Production-named threat actions share mechanics without sharing a rotation:
-- Vanish clears only references proven eligible, while Fade applies an exact
-- temporary offset without claiming that any hostile changed victims.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function threat(player, pet, victim)
    return { available = true, victimGuid = victim,
        playerHasAggro = player, petHasAggro = pet,
        playerDelta = 0, playerDeltaExact = true, petDelta = 0 }
end

local function portfolioState()
    local state = Fixture.State("smart")
    state.inCombat, state.hasAggro, state.tank = true, true, false
    state.pet, state.actors.pet = true, { hasAggro = true }
    state.hostiles = { order = { "selected", "guard", "unknown" },
        selectedKey = "selected", capped = false, byKey = {
            selected = { key = "selected", guid = state.targetGUID,
                selected = true, dead = false, hasPlayerAggro = true,
                threat = threat(true, false, "player-guid"),
                threatDropEvidence = { ["reference-clear"] = {
                    known = true, eligible = true,
                    source = "exact non-exempt hostile" } } },
            guard = { key = "guard", guid = "guard-guid", dead = false,
                hasPlayerAggro = false, threat = threat(false, true, "pet-guid"),
                threatDropEvidence = { ["reference-clear"] = {
                    known = true, eligible = false,
                    source = "exact exempt hostile" } } },
            unknown = { key = "unknown", guid = "unknown-guid", dead = false,
                hasPlayerAggro = false, threat = threat(false, false, nil) },
        } }
    return state
end

local vanish = Fixture.Action("Vanish", 2, "threatDrop", 0, 80, {
    self = true, reagent = true, reagentName = "Flash Powder",
    threatDropModel = "reference-clear",
})
vanish.spellId = 1857
local source = portfolioState()
source.hostiles.byKey.selected.threat.playerDelta = 50
source.hostiles.byKey.selected.projectedThreat = { player = 50, pet = 30 }
local context = { action = vanish, state = source }
assert(XelAssist.Graph.ThreatDrop:Score(context)
    and context.value == 4400 and context.estimated
    and context.reason == "clears unwanted hostile references",
    "Vanish must value exact reference clearing without assuming every enemy")

local vanished = XelAssist.Graph.State:Copy(source)
assert(XelAssist.Graph.ThreatDrop:Apply(vanished, { action = vanish }),
    "Vanish must use the generic reference-clear model")
local selected = vanished.hostiles.byKey.selected
local guard = vanished.hostiles.byKey.guard
local unknown = vanished.hostiles.byKey.unknown
assert(selected.threat.projectedPlayerReferenceKnown
    and selected.threat.projectedPlayerReference == false
    and selected.threat.projectedPlayerHasAggro == false,
    "an exactly eligible hostile reference must clear in the projected branch")
assert(selected.threat.playerDelta == 0
    and selected.threat.playerDeltaExact == true
    and not (selected.projectedThreat
        and selected.projectedThreat.player),
    "an exact reference clear must begin a fresh player-threat epoch")
assert(not guard.threat.projectedPlayerOwnershipUnknown
    and guard.threat.projectedReferenceClearEligible == false
    and guard.threat.playerHasAggro == false
    and guard.threat.petHasAggro == true,
    "an exactly exempt hostile must retain its live player and pet ownership")
assert(unknown.threat.projectedPlayerOwnershipUnknown
    and unknown.threat.playerDeltaExact == false,
    "an unclassified hostile must retain both Vanish outcome branches")
assert(vanished.hasAggro == false
    and vanished.targetPlayerThreatDeltaExact == true
    and vanished.inCombat == true and vanished.actors.pet.hasAggro == true,
    "selected clearance must not invent global combat or companion clearance")
assert(selected.guid == source.hostiles.byKey.selected.guid
    and guard.guid == source.hostiles.byKey.guard.guid
    and unknown.guid == source.hostiles.byKey.unknown.guid
    and not source.hostiles.byKey.selected.threat.projectedPlayerReferenceKnown,
    "reference projection must preserve exact identities and source purity")

local reengaged = XelAssist.Graph.State:Copy(vanished)
local reengagedSelected = reengaged.hostiles.byKey.selected
XelAssist.Graph.PlayerThreat:Add(reengagedSelected,
    reengaged, "player", 25)
assert(reengagedSelected.threat.projectedPlayerReferenceKnown
    and reengagedSelected.threat.projectedPlayerReference == true
    and reengagedSelected.threat.projectedPlayerOwnershipUnknown
    and reengagedSelected.threat.playerDelta == 25
    and reengagedSelected.projectedThreat.player == 25
    and reengagedSelected.projectedThreat.pet == 30,
    "new player threat after Vanish must start a fresh player-only epoch")

local fade = Fixture.Action("Fade", 1, "threatDrop", 0, 80, {
    self = true, threatDropModel = "temporary-flat",
})
fade.spellId = 586
local fadeSource = portfolioState()
fadeSource.hostiles.byKey.guard.threat.projectedPlayerReferenceKnown = true
fadeSource.hostiles.byKey.guard.threat.projectedPlayerReference = false
fadeSource.hostiles.byKey.unknown.threat.projectedPlayerReferenceKnown = true
fadeSource.hostiles.byKey.unknown.threat.projectedPlayerReference = true
local fadeContext = { action = fade, state = fadeSource,
    tooltip = { threatDropAmount = 55, duration = 10 } }
assert(XelAssist.Graph.ThreatDrop:Score(fadeContext)
    and fadeContext.value > 1350 and fadeContext.estimated
    and fadeContext.reason == "temporarily lowers unwanted threat",
    "Fade must value its exact temporary amount without claiming a threat wipe")
local faded = XelAssist.Graph.State:Copy(fadeSource)
assert(XelAssist.Graph.ThreatDrop:Apply(faded,
    { action = fade, tooltip = fadeContext.tooltip }),
    "Fade must use the generic temporary-flat model")
local key, record
for _, key in ipairs({ "selected", "unknown" }) do
    record = faded.hostiles.byKey[key]
    assert(record.threat.playerThreatOffset
        and record.threat.playerThreatOffset.amount == -55
        and record.threat.playerThreatOffset.remaining == 10
        and record.threat.playerThreatOffset.sourceSpellId == 586
        and record.threat.projectedPlayerOwnershipUnknown,
        "Fade must attach one exact temporary offset to every bounded hostile")
end
assert(faded.hostiles.byKey.guard.threat.playerThreatOffset == nil
    and faded.hostiles.byKey.guard.threat.projectedPlayerReference == false,
    "Fade must not create threat on a provably absent player reference")
XelAssist.Graph.ThreatDrop:Advance(faded, 4)
assert(faded.hostiles.byKey.selected.threat.playerThreatOffset.remaining == 6,
    "the temporary threat offset must age on the causal graph clock")
XelAssist.Graph.ThreatDrop:Advance(faded, 6)
assert(faded.hostiles.byKey.selected.threat.playerThreatOffset == nil
    and faded.hostiles.byKey.unknown.threat.playerThreatOffset == nil,
    "the temporary offset must expire without rewriting live victims")
assert(fadeSource.hostiles.byKey.selected.threat.playerThreatOffset == nil,
    "aging a projected Fade must not mutate the source state")

local unknownDrop = Fixture.Action("Future Threat Tool", 1,
    "threatDrop", 0, 0, { self = true })
local unknownOut = XelAssist.Graph.State:Copy(fadeSource)
assert(XelAssist.Graph.ThreatDrop:Blocker(unknownDrop, unknownOut, {})
        == "threat drop mechanics unknown"
    and not XelAssist.Graph.ThreatDrop:Apply(unknownOut,
        { action = unknownDrop })
    and not unknownOut.hostiles.byKey.selected.threat
        .projectedPlayerOwnershipUnknown,
    "an unclassified threat drop must fail closed without mutating the branch")

local idle = portfolioState()
idle.inCombat = false
local idleContext = { action = vanish, state = idle }
assert(XelAssist.Graph.ThreatDrop:Score(idleContext)
    and idleContext.value == -500,
    "a known idle state must not turn unknown hostile references into threat risk")

print("ok: Vanish and Fade use bounded generic player threat-drop mechanics")
