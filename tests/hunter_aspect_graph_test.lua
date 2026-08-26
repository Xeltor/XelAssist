-- Hunter aspects are one server-exclusive self-buff family. Replacing an
-- aspect must update the exact friendly recipient, not only hostile aura
-- compatibility tables.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local state = Fixture.State("smart")
state.inCombat = true
state.playerResourceExact = true
local rootPlayer = XelAssist.Graph.State:FriendlyByUnit(state, "player")
rootPlayer.auras.available = true
local hawk = Fixture.Action("Aspect of the Hawk", 1, "buff", 0, 0, {
    self = true, hunterAspect = true, exclusiveFamily = "hunterAspect",
    aspectRole = "rangedOffense",
})
local monkey = Fixture.Action("Aspect of the Monkey", 1, "buff", 0, 0, {
    self = true, hunterAspect = true, exclusiveFamily = "hunterAspect",
    aspectRole = "avoidance",
})
local viper = Fixture.Action("Aspect of the Viper", 1, "resource", 0, 10, {
    self = true, hunterAspect = true, exclusiveFamily = "hunterAspect",
    aspectRole = "manaRecovery",
})

local function project(source, action)
    local out = XelAssist.Graph.State:Copy(source)
    local target = XelAssist.Graph.State:FriendlyByUnit(out, "player")
    assert(XelAssist.Graph.HunterAspects:Apply(target, {
        action = action, targetRelation = "self", tooltip = {},
    }, {}), "the preparatory aspect adapter must own player-aura replacement")
    return out
end

local afterHawk = project(state, hawk)
local player = XelAssist.Graph.State:FriendlyByUnit(afterHawk, "player")
assert(player and player.auras and player.auras[hawk.name]
    and player.auras[hawk.name].exclusiveFamily == "hunterAspect"
    and player.hunterAspectExact and player.hunterAspectName == hawk.name
    and not afterHawk.auras[hawk.name],
    "the first aspect must retain its exclusive family on the player aura")

local afterMonkey = project(afterHawk, monkey)
player = XelAssist.Graph.State:FriendlyByUnit(afterMonkey, "player")
assert(player and player.auras and player.auras[monkey.name]
    and not player.auras[hawk.name] and not afterMonkey.auras[monkey.name],
    "a new aspect must replace the prior player aspect in projected state")

local live = Fixture.State("smart")
local livePlayer = XelAssist.Graph.State:FriendlyByUnit(live, "player")
livePlayer.auras = { available = true,
    [hawk.name] = { name = hawk.name, spellId = 13165,
        source = "unit aura", applicationProbability = 1 } }
local current, exact = XelAssist.Graph.HunterAspects:Current(live)
assert(current == hawk.name and exact,
    "the graph must discover the current aspect from exact live player auras")

local missing = Fixture.State("smart")
missing.playerResourceExact = true
XelAssist.Graph.State:FriendlyByUnit(missing, "player").auras.available = true
Fixture:Use(missing, { hawk, viper })
local hawkCandidate, hawkBlocker = XelAssist.Graph.Scoring:Evaluate(hawk, missing,
    XelAssist.Graph.Targets:Targets(hawk, missing)[1])
local viperCandidate, viperBlocker = XelAssist.Graph.Scoring:Evaluate(viper, missing,
    XelAssist.Graph.Targets:Targets(viper, missing)[1])
assert(not hawkCandidate and not viperCandidate
    and hawkBlocker == "Hunter aspect effects are not represented"
    and viperBlocker == "Hunter aspect effects are not represented",
    "aspects must stay out of recommendations until downstream effects are causal")

local unknown = Fixture.State("smart")
unknown.playerResourceExact = true
local unknownPlayer = XelAssist.Graph.State:FriendlyByUnit(unknown, "player")
unknownPlayer.auras.available = false
local unknownCurrent, unknownExact, unknownReason =
    XelAssist.Graph.HunterAspects:Current(unknown)
assert(not unknownCurrent and not unknownExact
    and unknownReason == "player aura evidence incomplete",
    "unknown aura absence must remain explicit in the preparatory adapter")

print("ok: Hunter aspect replacement is exact and recommendations fail closed")
