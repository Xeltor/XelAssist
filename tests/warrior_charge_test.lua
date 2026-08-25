-- Exact low-level Warrior Charge mechanics over the production graph. Charge
-- contributes only its causal arrival and DBC rank rage; later graph actions
-- must create the actual damage and sustained Attack state.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

GetTime = function() return 100 end
debugprofilestop = function() return 0 end
GetSpellCooldown = function() return 0, 0, 1 end
GetPetActionCooldown = function() return 0, 0, 1 end
GetPetActionsUsable = function() return true end
AttackTarget = function() end

local usable = true
IsSpellUsable = function()
    if usable == nil then return nil end
    return usable and 1 or 0, 0
end

local knowledge = XelAssist.Combat.Knowledge.Charge
assert(knowledge and knowledge.kind == "engage"
    and knowledge.outOfCombat and knowledge.requiresExactUsability
    and knowledge.submissionGuarded
    and knowledge.stanceMask == 65536
    and knowledge.rageGainBySpellId[100] == 9
    and knowledge.rageGainBySpellId[6178] == 12
    and knowledge.rageGainBySpellId[11578] == 15,
    "Charge knowledge must retain the exact installed-client rank mechanics")

local function copyFacts(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

local function charge(spellId, rank)
    local facts = copyFacts(knowledge)
    facts.testMinRange, facts.testMaxRange = 8, 25
    facts.testCategoryCooldown, facts.testGroup = 15, 44
    local action = Fixture.Action("Charge", rank or 1, "engage", 0, 0, facts)
    action.executor, action.spellId = "playerSpell", spellId
    return action
end

local function melee(name, kind, power, cost, extra)
    extra = extra or {}
    extra.melee, extra.testMinRange, extra.testMaxRange = true, 0, 5
    local action = Fixture.Action(name, 1, kind, power, cost, extra)
    action.executor, action.spellId = "playerSpell", 9000 + (cost or 0)
    return action
end

local function source(resource)
    local state = Fixture.State("smart")
    state.inCombat = false
    state.resource, state.resourceMax, state.resourceType = resource or 0, 100, 1
    state.actors.player.resource, state.actors.player.resourceMax =
        state.resource, state.resourceMax
    state.targetDistance, state.distance = 15, 15
    state.targetDistanceKind, state.distanceKind = "hitbox", "hitbox"
    state.playerBehindTarget = false
    state.targetHealth, state.targetMax = 200, 200
    state.playerAttack = { supported = true, active = false, activeKnown = true,
        pending = false, clockKnown = true }
    return state
end

local function descriptor(action, state)
    return XelAssist.Graph.Targets:Targets(action, state)[1]
end

local ids = { 100, 6178, 11578 }
local gains = { 9, 12, 15 }
local index
for index = 1, table.getn(ids) do
    local state = source(50)
    local action = charge(ids[index], index)
    local candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
        action, state, descriptor(action, state))
    assert(candidate and not blocker and candidate.power == 0
        and candidate.rawPower == 0 and candidate.resourceGain == gains[index]
        and candidate.estimated == false,
        "Charge rank must score as exact setup without invented damage")
    local beforeHealth, beforeAggro = state.targetHealth, state.hasAggro
    local out = XelAssist.Graph.Transitions:Advance(state, candidate)
    assert(out.resource == 50 + gains[index]
        and out.playerResourceExact and out.inCombat
        and out.chargeMeleeTargetGUID == state.targetGUID
        and out.readyAt["group:44"] == 15,
        "Charge rank must cap and project its exact rage and combat arrival")
    assert(out.targetHealth == beforeHealth and out.hasAggro == beforeAggro
        and out.playerAttack.active == false
        and out.playerAttack.activeKnown == true
        and out.playerAttack.attackRound == nil,
        "Charge must not invent damage, aggro, Attack state, or a white swing")
end

local capped = source(93)
local highest = charge(11578, 3)
local capCandidate = XelAssist.Graph.Scoring:Evaluate(highest, capped,
    descriptor(highest, capped))
capped = XelAssist.Graph.Transitions:Advance(capped, capCandidate)
assert(capped.resource == 100,
    "Charge rage must respect the exact player resource cap")

local unknown = charge(999999, 1)
assert(XelAssist.Graph.Charge:Blocker(
        unknown, source(), descriptor(unknown, source())) == "unknown Charge rank",
    "an unknown Charge identity must fail closed")

local blocked = source()
blocked.inCombat = true
local rankOne = charge(100, 1)
assert(XelAssist.Graph.Charge:Blocker(
        rankOne, blocked, descriptor(rankOne, blocked)) == "combat state",
    "Charge must remain unavailable throughout an in-combat graph")

blocked = source()
blocked.resourceType = 0
assert(XelAssist.Graph.Charge:Blocker(
        rankOne, blocked, descriptor(rankOne, blocked)) == "resource type",
    "Charge must not project into a non-rage actor")

usable = nil
blocked = source()
assert(XelAssist.Graph.Charge:Blocker(rankOne, blocked,
        descriptor(rankOne, blocked)) == "Charge usability evidence unknown",
    "missing stance/usability evidence must fail closed")
usable = true

blocked = source()
blocked.time = 0.05
assert(XelAssist.Graph.Charge:Blocker(rankOne, blocked,
        descriptor(rankOne, blocked)) == "Charge is only available before combat",
    "Charge must not reappear after an arbitrary future action")
blocked.movementSetupTargetGUID = blocked.targetGUID
assert(XelAssist.Graph.Charge:Blocker(rankOne, blocked,
        descriptor(rankOne, blocked)) == nil,
    "the explicit same-target movement edge may retain root Charge eligibility")

local arrived = source(1)
local candidate = XelAssist.Graph.Scoring:Evaluate(rankOne, arrived,
    descriptor(rankOne, arrived))
arrived = XelAssist.Graph.Transitions:Advance(arrived, candidate)
local rend = melee("Rend", "dot", 45, 10,
    { testDuration = 9, testPeriodicInterval = 3 })
local backstab = melee("Backstab", "builder", 50, 0, { behind = true })
local ranged = Fixture.Action("Throw", 1, "damage", 20, 0,
    { ranged = true, testMinRange = 20, testMaxRange = 30 })
ranged.executor, ranged.spellId = "playerSpell", 9901
local rendCandidate, rendBlocker = XelAssist.Graph.Scoring:Evaluate(
    rend, arrived, descriptor(rend, arrived))
assert(rendCandidate and not rendBlocker and arrived.resource == 10,
    "Charge arrival plus existing rage must expose a newly affordable melee spender")
local _, behindBlocker = XelAssist.Graph.Scoring:Evaluate(
    backstab, arrived, descriptor(backstab, arrived))
assert(behindBlocker == "must be behind target",
    "Charge arrival must not invent a rear arc")
local _, rangedBlocker = XelAssist.Graph.Scoring:Evaluate(
    ranged, arrived, descriptor(ranged, arrived))
assert(rangedBlocker == "minimum range",
    "Charge arrival must not satisfy ranged bands: " .. tostring(rangedBlocker))
assert(not XelAssist.Graph.Charge:CanReach(rend, arrived,
        { relation = "hostile", guid = "another-target" }, 5),
    "Charge arrival must remain pinned to one hostile identity")
local moved = XelAssist.Graph.State:Copy(arrived)
XelAssist.Graph.MovementSetup:Apply(moved, { targetGUID = "another-target",
    action = { facts = { movementSetup = true } } })
assert(moved.chargeMeleeTargetGUID == nil
    and not XelAssist.Graph.Charge:CanReach(rend, moved,
        descriptor(rend, moved), 5),
    "later movement must invalidate stale Charge arrival evidence")

local attack = Fixture.Action("Attack", 1, "command", 0, 0,
    { playerAttack = true, ambient = true, startOnly = true,
        recovery = true, melee = true, whiteAttack = true,
        weaponHand = "main", gcd = 0, effectMaxRange = 5,
        effectRangeHitbox = true })
attack.executor, attack.spellId = "playerSpell", 6603
local zero = source(0)
Fixture:Use(zero, { rankOne, attack, rend })
XelAssistCharDB.graphDepth, XelAssistCharDB.role = 3, "damage"
XelAssistCharDB.petThreat, XelAssistCharDB.allowAoe = "auto", false
local plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
assert(plan and plan.action.name == "Charge" and plan.follow[1]
    and plan.follow[1].name == "Attack", tostring(reason)
        .. ": zero-rage level-four Charge must lead to a real melee start, not fake rage")

local far = source(0)
far.targetDistance, far.distance = 30, 30
Fixture:Use(far, { rankOne, attack, rend })
plan, reason = XelAssist.Graph:Evaluate("smart", true, 100)
assert(plan and plan.action.name == "Move into range", tostring(reason)
        .. ": an out-of-band Charge must retain the explicit movement edge")

print("ok: exact Charge rage, legality and same-target melee arrival")
