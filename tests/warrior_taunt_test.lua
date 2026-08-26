-- Exact root-only player Taunt semantics. This is threat ownership, not a
-- Warrior priority list: the edge exists only to rescue a proven current ally.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

GetTime = function() return 100 end
GetSpellCooldown = function() return 0, 0, 1 end
GetPetActionCooldown = function() return 0, 0, 1 end
GetPetActionsUsable = function() return true end
local usable = true
IsSpellUsable = function()
    if usable == nil then return nil end
    return usable and 1 or 0, 0
end

local knowledge = XelAssist.Combat.Knowledge.Taunt
assert(knowledge and knowledge.playerTaunt and knowledge.tankOnly
    and knowledge.immediateDispatch and knowledge.requiresExactUsability
    and knowledge.submissionGuarded and knowledge.stanceMask == 131072
    and knowledge.tauntFocusDuration == 3 and knowledge.spellIds[1] == 355
    and knowledge.gcd == 0,
    "player Taunt must retain its exact installed-client control semantics")

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function taunt(spellId)
    local facts = copy(knowledge)
    facts.testMinRange, facts.testMaxRange = 0, 5
    facts.testCategoryCooldown, facts.testGroup = 10, 82
    local action = Fixture.Action("Taunt", 1, "taunt", 0, 0, facts)
    action.executor, action.spellId = "playerSpell", spellId or 355
    return action
end

local function victim(kind)
    if kind == "player" then return { available = true, guid = "player-guid",
        targetsPlayer = true, targetsPet = false, targetsGroup = false } end
    if kind == "pet" then return { available = true, guid = "pet-guid",
        targetsPlayer = false, targetsPet = true, targetsGroup = false } end
    if kind == "outsider" then return { available = true, guid = "outsider-guid",
        targetsPlayer = false, targetsPet = false, targetsGroup = false } end
    if kind == "unknown" then return { available = false, guid = nil,
        targetsPlayer = nil, targetsPet = nil, targetsGroup = nil } end
    return { available = true, guid = "ally-guid", groupUnit = "party1",
        targetsPlayer = false, targetsPet = false, targetsGroup = true }
end

local function source(victimKind, withPet)
    local state = Fixture.State("smart")
    state.inCombat, state.tank, state.role = true, true, "tank"
    state.groupSize, state.resourceType = 1, 1
    state.actors.player.guid = "player-guid"
    if withPet or victimKind == "pet" then
        state.actors.pet = { guid = "pet-guid", health = 600,
            healthMax = 1000, hasAggro = victimKind == "pet" }
        state.pet = true
    else state.actors.pet, state.pet = nil, false end
    local observedVictim = victim(victimKind)
    local record = { key = "target-guid", guid = "target-guid",
        unit = "target", selected = true, dead = false, priority = 1,
        health = 1000, healthMax = 1000, healthExact = true,
        targetAuras = {}, projectedAuras = {}, victim = observedVictim,
        hasPlayerAggro = observedVictim.targetsPlayer,
        hasPetAggro = observedVictim.targetsPet,
        threat = { available = observedVictim.available,
            victimGuid = observedVictim.guid,
            playerHasAggro = observedVictim.targetsPlayer,
            petHasAggro = observedVictim.targetsPet,
            playerDelta = 0, playerDeltaExact = true, petDelta = 0 },
        targetRef = { unit = "target", guid = "target-guid",
            relation = "hostile", source = "selected" } }
    state.hostiles = { order = { record.key }, selectedKey = record.key,
        byKey = { [record.key] = record }, byUnit = { target = record.key },
        total = 1, capped = false, discoveryComplete = true }
    XelAssist.Graph.State:SyncSelectedHostile(state)
    state.inCombat, state.tank, state.role = true, true, "tank"
    state.groupSize, state.resourceType = 1, 1
    return state
end

local function descriptor(action, state)
    return XelAssist.Graph.Targets:Targets(action, state)[1]
end

local action = taunt()
action.mock.average, action.mock.dbcAverage = nil, 1
local state = source("ally", true)
local candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
    action, state, descriptor(action, state))
assert(candidate and not blocker and candidate.power == 0
    and candidate.rawPower == 0 and candidate.threat == 0
    and candidate.value == 4800 and candidate.estimated == false
    and candidate.reason == "takes the target from an ally",
    "Taunt must ignore generic DBC magnitude and remain exact threat rescue")
local out = XelAssist.Graph.Transitions:Advance(state, candidate)
local projected = XelAssist.Graph.State:SelectedHostile(out)
assert(out.hasAggro == true and out.targetHealth == 1000
    and projected.victim.guid == "ally-guid"
    and projected.threat.victimGuid == "ally-guid"
    and projected.threat.projectedVictimGuid == "player-guid"
    and projected.threat.projectedPlayerHasAggro == true
    and projected.threat.projectedPetHasAggro == false
    and projected.threat.playerDelta == 0
    and projected.threat.playerDeltaExact == false
    and projected.projectedTauntedByPlayer == true
    and projected.projectedTauntedByPet ~= true
    and projected.tauntFocusUntil > out.time,
    "successful Taunt must project only player ownership and bounded focus")
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, out,
        descriptor(action, out)) == "target already projected on player",
    "a projected Taunt must not repeat inside the same graph")

local longAction = Fixture.Action("Long Tank Action", 1, "damage", 10, 0,
    { cast = 4 })
longAction.executor, longAction.spellId = "playerSpell", 99002
local longCandidate, longBlocker = XelAssist.Graph.Scoring:Evaluate(
    longAction, out, descriptor(longAction, out))
assert(longCandidate and not longBlocker, tostring(longBlocker))
local expired = XelAssist.Graph.Transitions:Advance(out, longCandidate)
local expiredRecord = XelAssist.Graph.State:SelectedHostile(expired)
assert(expired.time >= 3 and expired.hasAggro == nil
    and expired.targetPlayerThreatDeltaExact == false
    and expired.actors.pet.hasAggro == nil
    and expiredRecord.victim.guid == "ally-guid"
    and expiredRecord.threat.victimGuid == "ally-guid"
    and expiredRecord.threat.projectedVictimGuid == nil
    and expiredRecord.threat.projectedPlayerHasAggro == nil
    and expiredRecord.threat.projectedPetHasAggro == nil
    and expiredRecord.threat.projectedOwnershipUnknown == true
    and expiredRecord.tauntFocusUntil == nil
    and expiredRecord.tauntFocusExpired == true,
    "expired Taunt focus must make ownership unknown without rewriting observation")

XelAssist.Combat.Resistance = { Estimate = function()
    return { landChance = 0.5, unknown = false, source = "test delivery" }
end }
state = source("ally")
candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
    action, state, descriptor(action, state))
assert(candidate and candidate.effectDelivery == 0.5,
    "the fixture must retain a partial Taunt delivery branch: "
        .. tostring(blocker) .. "/"
        .. tostring(candidate and candidate.effectDelivery))
out = XelAssist.Graph.Transitions:Advance(state, candidate)
projected = XelAssist.Graph.State:SelectedHostile(out)
assert(out.hasAggro == false
    and projected.threat.projectedPlayerHasAggro ~= true
    and projected.threat.projectedVictimGuid == nil
    and projected.threat.projectedTauntUncertain == true
    and projected.threat.playerDelta == 0
    and projected.threat.playerDeltaExact == false,
    "partial Taunt delivery must preserve ownership and expose uncertainty")
XelAssist.Combat.Resistance = nil

local cases = {
    { "player", "target already attacks player" },
    { "unknown", "hostile victim unknown" },
    { "outsider", "target is not attacking an ally" },
}
local i
for i = 1, table.getn(cases) do
    state = source(cases[i][1])
    assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
            descriptor(action, state)) == cases[i][2],
        "Taunt victim gate drifted for " .. cases[i][1])
end

state = source("pet")
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
        descriptor(action, state)) == nil,
    "a tank may rescue its own exactly identified companion")
local petCandidate = XelAssist.Graph.Scoring:Evaluate(
    action, state, descriptor(action, state))
assert(petCandidate
    and petCandidate.reason == "takes the target from your companion",
    "a companion rescue must explain its actual threat recipient")
state = source("ally"); state.actors.player.guid = nil
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
        descriptor(action, state)) == "player identity unavailable",
    "Taunt must not enter the graph without a projectable player identity")
state = source("ally"); state.tank = false
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
        descriptor(action, state)) == "tank role required",
    "player Taunt must obey the character tank role")
state = source("ally"); state.inCombat = false
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
        descriptor(action, state)) == nil,
    "Taunt must rescue a proven ally pull before the player combat flag arrives")
usable = nil; state = source("ally")
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state,
        descriptor(action, state)) == "Taunt usability evidence unknown",
    "unknown stance/proc usability must fail closed")
usable = true
dofile("Game/Player/DruidGrowl.lua")
local growl = taunt(6795)
growl.name = "Growl"
growl.facts.warriorTaunt = nil
growl.facts.druidGrowl = true
growl.facts.druidGrowlEvidence = { valid = true, exact = true,
    spellId = 6795, formMask = 144, rangeIndex = 2, cooldown = 10,
    gcd = 0, cost = 0, powerType = 1, tauntFocusDuration = 3,
    noOpWhenTargetingCaster = true }
local growlBlocker = XelAssist.Graph.PlayerTaunt:Blocker(growl, state,
    descriptor(growl, state))
assert(growlBlocker == nil,
    "exact Druid Growl must reuse victim-sensitive player-taunt semantics: "
        .. tostring(growlBlocker))
local unknown = taunt(999999)
assert(XelAssist.Graph.PlayerTaunt:Blocker(unknown, state,
        descriptor(unknown, state)) == "unknown player Taunt rank",
    "an unknown Taunt identity must fail closed")

state = source("ally")
local strike = Fixture.Action("Tank Strike", 1, "damage", 100, 0,
    { melee = true, testMinRange = 0, testMaxRange = 5 })
strike.executor, strike.spellId = "playerSpell", 99001
Fixture:Use(state, { action, strike })
XelAssistCharDB.graphDepth, XelAssistCharDB.role = 2, "tank"
XelAssistCharDB.petThreat, XelAssistCharDB.allowAoe = "auto", false
local plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
assert(plan and plan.action.name == "Taunt" and plan.follow[1]
    and plan.follow[1].name == "Tank Strike", tostring(reason)
        .. ": exact ally threat loss must retain a Taunt-to-threat runway")

print("ok: exact root-only player Taunt threat rescue")
