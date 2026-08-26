XelAssist = { Game = { Capabilities = {} }, Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out, key, child = {}, nil, nil
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
end

XelAssist.Graph.State = {
    Copy = function(_, state) return copy(state) end,
}
XelAssist.Graph.Effects = {
    StateAtImpact = function(_, state) return state end,
    Decision = function() return 1, 1 end,
    AdvanceModifierFallbacks = function() end,
    RemoveTargetModifier = function() end,
}
XelAssist.Graph.EventAuras = {
    BeginScheduled = function() end,
    Snapshot = function() return {} end,
    Track = function() end,
    Advance = function() end,
    AgeBranches = function() end,
    PromoteBranch = function() return false end,
}
XelAssist.Game.Pets = { Effects = { Advance = function() end } }
XelAssist.Game.Capabilities.IsReady = function() return true end
XelAssist.Game.Capabilities.Usable = function() return true end
XelAssist.Combat.Resistance = {
    Estimate = function() return { multiplier = 1 } end,
}
XelAssist.Combat.AutoShotRange = {
    Projectable = function() return true end,
}
XelAssist.Graph.AutoShotUncertainty = {
    Has = function() return false end,
    Current = function() return false end,
    Apply = function() end,
    Carry = function() end,
}
local battleShoutWhiteCalls = 0
XelAssist.Graph.WarriorBattleShout = {
    MainHandWhiteBonus = function()
        battleShoutWhiteCalls = battleShoutWhiteCalls + 1
        return 10, false, nil
    end,
}

dofile("Graph/CompanionTargets.lua")
dofile("Graph/PlayerRage.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/PlayerSwings.lua")
dofile("Graph/PlayerSwingScoring.lua")
dofile("Game/SpellClassification.lua")
dofile("Graph/ActionAdmission.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/OngoingEffects.lua")
dofile("Graph/AutoShotEffects.lua")

XelAssist.Graph.ActionEffects = {
    Context = function(_, _, candidate)
        return { action = candidate.action, facts = candidate.action.facts,
            applicationOffset = math.max(0, tonumber(candidate.wait) or 0)
                + math.max(0, tonumber(candidate.cast) or 0),
            ChangesHostileTarget = function() return false end }
    end,
    Consume = function(_, out, candidate, context)
        return XelAssist.Graph.ActionConsumption:Consume(out, candidate, context)
    end,
    Apply = function(_, out) out.normalActionApplied = true end,
}

dofile("Graph/Timeline.lua")
dofile("Graph/Transitions.lua")

local targetGuid = "target-guid"
local raptor = { name = "Raptor Strike", spellId = 2973, rank = 1,
    actor = "player",
    facts = { kind = "damage", melee = true, onNextSwing = true,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true } }
local tooltip = { onNextSwing = true, school = 0, cost = 10, average = 80,
    cooldown = 6, gcd = 1.5 }
local state = { time = 0, resource = 30, resourceMax = 100,
    playerResourceReserved = 0, playerResourceExact = true,
    hostile = true, targetGUID = targetGuid,
    targetHealth = 200, targetHealthExact = true,
    targetDistance = 3, targetDistanceKind = "hitbox",
    targetLineOfSight = true, auras = {}, readyAt = {},
    actorReadyAt = { player = 4 },
    playerAttack = { active = true, activeKnown = true,
        onSwing = { occupied = false, pending = false, exact = true },
        attackRound = { projectable = true, phaseKnown = true,
            verified = true, targetGuid = targetGuid, nextSwingIn = 1,
            interval = 2, power = 50, normalDamageKnown = true,
            phaseSource = "test exact round" } } }

local descriptor = { guid = targetGuid }
assert(not XelAssist.Graph.PlayerSwings:Blocker(
    raptor, state, descriptor, tooltip),
    "an exact future main-hand round must admit a DBC next-swing action")

local candidate = { action = raptor, tooltip = tooltip,
    rawPower = 80, power = 80, cost = 10, costKnown = true,
    target = "target", targetGUID = targetGuid,
    targetRelation = "hostile", cast = 0, wait = 0,
    occupancy = 0.05, downtime = 0.05, actionStart = 0 }
local armed = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(armed.resource == 30 and armed.playerResourceReserved == 10,
    "arming must reserve rather than spend the resource")
assert(armed.targetHealth == 200 and not armed.readyAt["player:Raptor Strike"],
    "arming must cause no damage or cooldown")
assert(armed.playerAttack.onSwing.occupied
    and armed.playerAttack.onSwing.phase == "graph-armed",
    "the graph must own exactly one pending replacement slot")

local unavailable = XelAssist.Graph.ActionAdmission:Readiness(
    { name = "Expensive", actor = "player", facts = {} }, armed,
    { cost = 25 }, armed.time)
assert(unavailable == "resource",
    "reserved next-swing cost must block a later double-spend")
assert(XelAssist.Graph.PlayerSwings:Blocker(
    raptor, armed, descriptor, tooltip) == "next-swing action already armed",
    "the occupied graph slot must reject a repeated or replacement input")

local unknownCost = copy(candidate)
unknownCost.cost, unknownCost.costKnown = 0, false
local uncertain = XelAssist.Graph.Transitions:Advance(state, unknownCost)
assert(uncertain.playerResourceReserved == state.resource
    and XelAssist.Graph.ActionAdmission:Readiness(
        { name = "Any Cost", actor = "player", facts = {} }, uncertain,
        { cost = 1 }, uncertain.time) == "resource",
    "an unknown next-swing cost must reserve all available resource")

local normal = { action = { name = "Wait", actor = "player",
        facts = { kind = "command" } }, tooltip = { cost = 0 },
    rawPower = 0, power = 0, cost = 0, costKnown = true,
    target = "target", targetGUID = targetGuid,
    targetRelation = "hostile", cast = 0, wait = 0,
    occupancy = 1.5, downtime = 1.5, actionStart = armed.time }
local shoutedState = copy(state)
shoutedState.warriorBattleShout = { available = true }
local shoutedWhite = XelAssist.Graph.Transitions:Advance(shoutedState, normal)
assert(shoutedWhite.targetHealth == 140 and battleShoutWhiteCalls == 1,
    "an exact Battle Shout AP delta must augment an ordinary main-hand round")
local shoutedArmed = XelAssist.Graph.Transitions:Advance(shoutedState, candidate)
local shoutedSpecial = XelAssist.Graph.Transitions:Advance(shoutedArmed, normal)
assert(shoutedSpecial.targetHealth == 120 and battleShoutWhiteCalls == 1,
    "a next-swing replacement must not receive the ordinary white AP delta twice")
local resolved = XelAssist.Graph.Transitions:Advance(armed, normal)
assert(resolved.resource == 20 and resolved.playerResourceReserved == 0,
    "the exact swing must pay the reserved cost once")
assert(resolved.targetHealth == 120,
    "the yellow replacement must apply once without adding the white hit")
assert(resolved.readyAt["player:Raptor Strike"] == 7,
    "the replacement cooldown must begin at the exact one-second swing")
assert(not resolved.playerAttack.onSwing.occupied,
    "the exact replacement swing must release the graph slot")

local futureCast = copy(normal)
futureCast.action = { name = "Future Cast", actor = "player",
    facts = { kind = "command" } }
futureCast.tooltip = { cost = 0 }
futureCast.wait, futureCast.cast = 1, 2
futureCast.occupancy, futureCast.downtime = 2, 3
futureCast.actionStart = armed.time + futureCast.wait
local beforeCast = XelAssist.Graph.Transitions:Advance(armed, futureCast)
assert(beforeCast.resource == 20 and beforeCast.targetHealth == 120
    and not beforeCast.playerAttack.onSwing.occupied,
    "an armed round due before a future cast must resolve before that cast starts")
assert(math.abs(beforeCast.playerAttack.attackRound.nextSwingIn - 0.05) < 0.0001,
    "a later round due during the cast must remain held until the cast ends")
local afterCast = XelAssist.Graph.Transitions:Advance(beforeCast,
    { action = normal.action, tooltip = normal.tooltip, rawPower = 0,
        power = 0, cost = 0, costKnown = true, target = "target",
        targetGUID = targetGuid, targetRelation = "hostile", cast = 0,
        wait = 0, occupancy = 0.1, downtime = 0.1,
        actionStart = beforeCast.time })
assert(afterCast.resource == 20 and afterCast.targetHealth == 70,
    "the cast-held later round must resume once without replaying the special")

local later = XelAssist.Graph.Transitions:Advance(resolved,
    { action = normal.action, tooltip = normal.tooltip, rawPower = 0,
        power = 0, cost = 0, costKnown = true, target = "target",
        targetGUID = targetGuid, targetRelation = "hostile", cast = 0,
        wait = 0, occupancy = 2, downtime = 2,
        actionStart = resolved.time })
assert(later.resource == 20 and later.targetHealth == 70,
    "the following ordinary round must not pay or replay the special")

local due = copy(state)
due.playerAttack.attackRound.nextSwingIn = 0.05
assert(XelAssist.Graph.PlayerSwings:Blocker(
    raptor, due, descriptor, tooltip) == "player swing already resolving",
    "a button press must not retroactively catch an already-due round")
local cleave = copy(raptor)
cleave.facts.aoe = true
assert(XelAssist.Graph.PlayerSwings:Blocker(
    cleave, state, descriptor, tooltip)
        == "next-swing area recipients unresolved",
    "unproven Cleave topology must be withheld rather than duplicated")

local score = { onNextSwing = true, state = state, target = "target",
    expectedPower = 80, impactDelay = 1 }
XelAssist.Graph.PlayerSwingScoring:Project(score)
local effective = XelAssist.Graph.PlayerSwingScoring:Effective(
    score, 200, true)
assert(score.displacedWhitePower == 50 and score.marginalPower == 30
    and effective == 30,
    "next-swing utility must be the yellow upgrade over displaced white damage")
assert(XelAssist.Graph.PlayerSwingScoring:DamageValue(score, 1) == 4,
    "a paid next-swing action must not receive base value for a trivial upgrade")
local dying = { onNextSwing = true, state = state, target = "target",
    expectedPower = 80, impactDelay = 1 }
XelAssist.Graph.PlayerSwingScoring:Project(dying)
local dyingEffective = XelAssist.Graph.PlayerSwingScoring:Effective(
    dying, 40, true)
assert(dyingEffective == 0
    and XelAssist.Graph.PlayerSwingScoring:DamageValue(dying, dyingEffective) == 0,
    "a free white kill must leave no base utility for a paid replacement")

XelAssist.Graph.Targets = {
    Legal = function(_, _, source, resolved)
        return true, nil, tooltip, "target", source.time, resolved
    end,
}
XelAssist.Graph.HostileEffects = { Score = function() return false end }
XelAssist.Graph.ActorScoring = { Score = function() return false end }
XelAssist.Graph.ThreatScoring = { Apply = function() end }
XelAssist.Game.Capabilities.BonusDamage = function() return 0 end
dofile("Graph/ActionPower.lua")
dofile("Graph/PeriodicScoring.lua")
dofile("Graph/Candidate.lua")
dofile("Graph/StateUtilityScoring.lua")
dofile("Graph/Scoring.lua")
dofile("Graph/PlayerAttackCommitment.lua")

local rageState = copy(state)
rageState.resource, rageState.resourceMax, rageState.resourceType = 0, 100, 1
rageState.playerLevel, rageState.targetHealth = 1, 500
rageState.playerAttack.rageCosts = { 15 }
rageState.playerAttack.attackRound.power = 10
local commitment = XelAssist.Graph.PlayerAttackCommitment:Candidate(rageState)
assert(commitment and commitment.action.name == "Continue Attack"
    and commitment.action.executor == "instruction"
    and math.abs(commitment.wait - 3) < 0.0001
    and commitment.projectedRage == 18,
    "zero-rage melee must publish a harmless wait through the next affordable threshold")
local rageBuilt = XelAssist.Graph.Transitions:Advance(rageState, commitment)
assert(rageBuilt.resource == 18 and rageBuilt.targetHealth == 480,
    "two ordinary white rounds must add projected rage and damage exactly once")

local rageArmed = copy(state)
rageArmed.resourceType, rageArmed.playerLevel = 1, 1
rageArmed.playerAttack.rageCosts = { 15 }
rageArmed = XelAssist.Graph.Transitions:Advance(rageArmed, candidate)
local armedWait = XelAssist.Graph.PlayerAttackCommitment:Candidate(rageArmed)
local rageResolved = XelAssist.Graph.Transitions:Advance(rageArmed, armedWait)
assert(rageResolved.resource == 20 and rageResolved.targetHealth == 120,
    "a next-swing replacement must spend rage without also earning white-hit rage")

local autoKill = copy(state)
autoKill.targetHealth, autoKill.targetMax = 60, 60
autoKill.autoShot = { active = true, targetGuid = targetGuid,
    inFlight = { { power = 60, spellId = 75, targetGuid = targetGuid,
        remaining = 0.5 } }, unknownInFlight = {}, ammoKnown = false }
local avoided = XelAssist.Graph.Scoring:Evaluate(
    raptor, autoKill, { guid = targetGuid, relation = "hostile" })
assert(avoided and avoided.value == -100000
    and avoided.reason == "ambient attack resolves first",
    "an in-flight Auto Shot kill before the one-second swing must suppress Raptor Strike")
local castLocked = copy(autoKill)
castLocked.playerCasting, castLocked.castRemaining = true, 2
castLocked.actorReadyAt.player = 2
castLocked.autoShot.inFlight[1].remaining = 1.5
local castLockedDelay = XelAssist.Graph.PlayerSwings:ImpactDelay(castLocked)
assert(math.abs(castLockedDelay - 2.05) < 0.0001,
    "an existing player cast must extend the projected melee impact clock")
local castLockedAvoided = XelAssist.Graph.Scoring:Evaluate(
    raptor, castLocked, { guid = targetGuid, relation = "hostile" })
assert(castLockedAvoided and castLockedAvoided.value == -100000
    and castLockedAvoided.reason == "ambient attack resolves first",
    "ambient damage during a cast-delayed melee round must suppress Raptor Strike")
local whiteOnly = XelAssist.Graph.Timeline:BeforePlayerSwing(
    state, candidate, 1)
assert(whiteOnly.targetHealth == state.targetHealth,
    "the impact-health probe must exclude only the displaced white swing")
local tiedAuto = copy(autoKill)
tiedAuto.autoShot.inFlight[1].remaining = 1
local tiedProbe = XelAssist.Graph.Timeline:BeforePlayerSwing(
    tiedAuto, candidate, 1)
assert(tiedProbe.targetHealth == 0 and tiedProbe.damageEvents == 1,
    "same-offset ambient damage must remain visible beside the displaced white swing")
assert(raptor.facts.whiteAttack ~= true,
    "the yellow replacement must not inherit the dual-wield white miss penalty")

print("ok: causal player next-swing reservation, replacement and marginal value")
