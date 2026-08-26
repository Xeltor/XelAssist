-- VMaNGOS rolls Feign Death against each in-range hostile creature reference.
-- A single resist preserves the Hunter's threat references, so an unconfirmed
-- graph branch must not claim that aggro was dropped deterministically.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local state = Fixture.State("smart")
state.inCombat, state.hasAggro, state.tank = true, true, false
state.pet, state.actors.pet = true, { hasAggro = true }
state.hostiles = { order = { "selected", "off-target" }, capped = false,
    selectedKey = "selected", byKey = {
        ["selected"] = { key = "selected", guid = state.targetGUID,
            selected = true, dead = false, hasPlayerAggro = true,
            threat = { available = true, victimGuid = "player-guid",
                playerHasAggro = true, petHasAggro = false,
                playerDelta = 0, playerDeltaExact = true, petDelta = 0 } },
        ["off-target"] = { key = "off-target", guid = "other-guid",
            dead = false, hasPlayerAggro = false,
            threat = { available = true, victimGuid = "pet-guid",
                playerHasAggro = false, petHasAggro = true,
                playerDelta = 0, playerDeltaExact = true, petDelta = 0 } },
    } }

local feign = Fixture.Action("Feign Death", 1, "threatDrop", 0, 80, {
    self = true,
    feignDeath = true, threatDropModel = "resistible-all-or-nothing",
})
local context = { action = feign, state = state }
assert(XelAssist.Graph.ThreatDrop:Score(context)
    and context.value == 4200 and context.estimated
    and context.reason == "may drop unwanted aggro",
    "unwanted aggro must make a resistible threat drop valuable but uncertain")

local projected = XelAssist.Graph.State:Copy(state)
assert(XelAssist.Graph.ThreatDrop:Apply(projected, { action = feign }),
    "the resistible all-or-nothing threat model must own Feign projection")
local selected = projected.hostiles.byKey.selected
local offTarget = projected.hostiles.byKey["off-target"]
assert(projected.hasAggro == nil
    and projected.targetPlayerThreatDeltaExact == false
    and projected.playerThreatDrop.outcomeCoupled == true
    and projected.inCombat == true,
    "unconfirmed Feign Death must preserve both success and resist branches")
assert(selected.threat.projectedPlayerOwnershipUnknown
    and offTarget.threat.projectedPlayerOwnershipUnknown
    and selected.threat.playerDeltaExact == false
    and offTarget.threat.playerDeltaExact == false,
    "every bounded hostile reference must retain uncertain player ownership")
assert(selected.threat.playerHasAggro == true
    and selected.threat.victimGuid == "player-guid"
    and offTarget.threat.playerHasAggro == false
    and offTarget.threat.victimGuid == "pet-guid",
    "projection must not overwrite immutable live victim evidence")
assert(projected.actors.pet.hasAggro == true
    and selected.threat.petHasAggro == false
    and offTarget.threat.petHasAggro == true,
    "a player threat drop must not erase exact companion ownership")
assert(state.hasAggro == true
    and not state.hostiles.byKey.selected.threat.projectedPlayerOwnershipUnknown,
    "a threat-drop branch must not mutate its immutable source state")

print("ok: resistible all-or-nothing threat drops preserve every causal branch")
