XelAssist = { Graph = {}, Game = {}, Combat = {} }
table.getn = table.getn or function(value) return #value end
XelAssistCharDB = { allowAoe = true, petThreat = "tank",
    toggles = { petActions = true, consumables = true, reagents = true,
        cooldowns = true, petControl = true } }
BOOKTYPE_SPELL = "spell"

local calls = { facts = 0, usable = 0, cooldown = 0, range = 0,
    settled = 0, aura = 0, pending = 0, observed = 0, power = 0,
    tapped = 0, tapOwner = 0 }
GetTime = function() return 100 end
GetSpellCooldown = function()
    calls.cooldown = calls.cooldown + 1
    return 0, 0
end
GetPetActionsUsable = function() return true end
UnitIsTapped = function()
    calls.tapped = calls.tapped + 1
    return true
end
UnitIsTappedByPlayer = function()
    calls.tapOwner = calls.tapOwner + 1
    return true
end

XelAssist.Game.Actors = {
    Facts = function()
        calls.facts = calls.facts + 1
        return { average = 100, cost = 10, cast = 0, gcd = 1.5,
            duration = 12, minRange = 0, maxRange = 30, school = 5 }
    end,
    HasReagent = function() return true end,
}
XelAssist.Game.Capabilities = {
    Usable = function()
        calls.usable = calls.usable + 1
        return true
    end,
    CastName = function(_, action) return action.name end,
    BonusDamage = function()
        calls.power = calls.power + 1
        return 20
    end,
    WeaponDamage = function() return 50 end,
    RangedDamage = function() return 40 end,
    TargetHasDebuff = function()
        calls.aura = calls.aura + 1
        return false
    end,
    UnitHasBuff = function() error("unexpected friendly aura query") end,
}
XelAssist.Game.Inventory = {
    Cooldown = function() error("unexpected item cooldown query") end,
    Blocker = function() return nil end,
}
XelAssist.Game.Range = {
    SpellVerdict = function()
        calls.range = calls.range + 1
        return true
    end,
    TooltipVerdict = function(_, tooltip, distance)
        if distance == nil then return nil, "range unknown" end
        if tooltip.maxRange and distance > tooltip.maxRange then return false, "range" end
        return true
    end,
    EffectBand = function() return nil, nil, false, false end,
    BandVerdict = function() return nil, "range unknown" end,
}
XelAssist.Game.SpatialEvidence = {
    Range = function(_, _, _, verdict)
        calls.settled = calls.settled + 1
        return verdict
    end,
}
XelAssist.Game.SpellClassification = {
    NormalGcd = function() return false end,
}
XelAssist.Combat.Observations = {
    Blocker = function()
        calls.observed = calls.observed + 1
        return nil
    end,
}
XelAssist.IsAuraPending = function()
    calls.pending = calls.pending + 1
    return false
end
XelAssist.SweepPendingAuras = function() end

local opaqueTarget = {}
local descriptor = { unit = "target", relation = "hostile",
    source = "selected", key = opaqueTarget, guid = opaqueTarget }
XelAssist.Graph.TargetSelection = {
    VariableFriendlyAction = function() return false end,
    Targets = function() return { descriptor } end,
}
XelAssist.Graph.State = {
    FriendlyByKey = function() return nil end,
}
XelAssist.Graph.CompanionResources = nil
XelAssist.Graph.CompanionThreat = nil
XelAssist.Graph.PlayerSwings = nil
XelAssist.Graph.ResourceExchange = { Blocker = function() return nil end }

dofile("Graph/ActionAdmission.lua")
dofile("Graph/SpatialRequirements.lua")
dofile("Graph/Targets.lua")
dofile("Graph/ActionPower.lua")
dofile("Graph/RootObservation.lua")
dofile("Game/SoulShards.lua")
dofile("Graph/SoulShardReserve.lua")

local source = { name = "Corruption", rank = 1, rankText = "Rank 1",
    spellId = 172, slot = 1, bookType = BOOKTYPE_SPELL,
    actor = "player", executor = "playerSpell",
    facts = { kind = "dot", reagentName = "Test Reagent" } }
local state = { mode = "auto", hostile = true, inCombat = true,
    health = 100, healthMax = 100, resource = 100, resourceMax = 100,
    resourceType = 0, targetHealth = 500, targetMax = 500,
    targetHealthExact = true, targetDistance = 20, targetDistanceKind = "hitbox",
    distance = 20, distanceKind = "hitbox", targetAuras = {}, auras = {},
    moving = false, playerCasting = false, playerChanneling = false,
    playerStealthed = false, playerStealthKnown = true, groupSize = 0,
    actors = { player = { guid = "player-guid" } }, inventory = {
        reagentCounts = { ["Soul Shard"] = 2 } }, playerLevel = 10,
    hostiles = { order = { opaqueTarget }, byKey = { [opaqueTarget] = {
        unit = "target", key = opaqueTarget, guid = opaqueTarget,
        selected = true, encounter = { level = 10 } } } },
    readyAt = {}, actorReadyAt = { player = 0 }, time = 0 }

local incomplete = XelAssist.Graph.RootObservation:Begin(state, { source }, 100)
local sealed, reason = XelAssist.Graph.RootObservation:Seal(incomplete)
assert(sealed == nil and reason == "root observation incomplete",
    "an incomplete sliced capture must not seal")
local steps = 0
while not XelAssist.Graph.RootObservation:Step(incomplete) do
    steps = steps + 1
    assert(steps < 10, "root observation capture got stuck")
end
assert(steps >= 3, "capture should expose sliced setup/action/recipient work")
assert(XelAssist.Graph.RootObservation:Seal(incomplete),
    "a completed root observation should seal")

local actions, actionStatus = XelAssist.Graph.RootObservation:Actions(state)
assert(actionStatus == "known" and table.getn(actions) == 1,
    "sealed action catalog should be evaluation-owned")
local action = actions[1]
local facts, factsStatus = XelAssist.Graph.RootObservation:Facts(state, action)
assert(factsStatus == "known" and facts.average == 100,
    "exact action facts should be frozen")
local evidence, evidenceStatus = XelAssist.Graph.RootObservation:Recipient(
    state, action, descriptor)
assert(evidenceStatus == "known" and evidence.key == opaqueTarget,
    "opaque recipient identity must survive without coercion")
assert(calls.facts == 1 and calls.usable == 1 and calls.cooldown == 1
    and calls.range == 1 and calls.settled == 1 and calls.aura == 1
    and calls.pending == 1 and calls.observed == 1 and calls.power == 1,
    "each mutable root query should be captured once")
assert(calls.tapped == 1 and calls.tapOwner == 1,
    "generic hostile tap evidence should be captured once per target")

source.facts.kind = "buff"
XelAssistCharDB.toggles.cooldowns = false
local frozenConfig = XelAssist.Graph.RootObservation:Config(state)
assert(action.facts.kind == "dot" and frozenConfig.toggles.cooldowns == true,
    "source action and config mutations must not change a sealed observation")

local function forbidden() error("live API called after root observation seal") end
XelAssist.Game.Actors.Facts = forbidden
XelAssist.Game.Actors.HasReagent = forbidden
XelAssist.Game.Capabilities.Usable = forbidden
XelAssist.Game.Capabilities.BonusDamage = forbidden
XelAssist.Game.Capabilities.TargetHasDebuff = forbidden
XelAssist.Game.Range.SpellVerdict = forbidden
XelAssist.Game.SpatialEvidence.Range = forbidden
XelAssist.Game.Inventory.Cooldown = forbidden
XelAssist.Combat.Observations.Blocker = forbidden
XelAssist.IsAuraPending = forbidden
GetSpellCooldown = forbidden
UnitIsTapped = forbidden
UnitIsTappedByPlayer = forbidden

local power = XelAssist.Graph.ActionPower:Estimate(
    action, facts, state, opaqueTarget)
assert(math.abs(power - 116) < 0.001,
    "power should use captured spell power instead of a resumed live query")
assert(XelAssist.Graph.ActionAdmission:Readiness(action, state, facts, 0) == nil,
    "readiness should use the captured exact-rank cooldown")
local shardLedger = XelAssist.Graph.SoulShardReserve:Prepare(state)
assert(shardLedger.targets[opaqueTarget].eligible,
    "Soul Shard preparation should reuse frozen generic tap evidence")
assert(XelAssist.Graph.SpatialRequirements:Blocker(
    action, state, descriptor, "target", facts) == nil,
    "spatial legality should use the captured settled range result")
local legal, blocker = XelAssist.Graph.Targets:Legal(action, state, descriptor)
assert(legal and blocker == nil,
    "target legality should consume only sealed evidence")

local unknown = { name = "Unknown", rank = 1, spellId = 999,
    actor = "player", executor = "playerSpell",
    facts = { kind = "damage" } }
legal, blocker = XelAssist.Graph.Targets:Legal(unknown, state, descriptor)
assert(not legal and blocker == "action evidence unknown",
    "missing sealed action evidence must fail explicitly without a live fallback")
local unknownPower, _, unknownEvidence = XelAssist.Graph.ActionPower:Estimate(
    unknown, facts, state, opaqueTarget)
assert(unknownPower == 0 and unknownEvidence.unknown,
    "missing sealed power evidence must be explicit")
assert(XelAssist.Graph.ActionAdmission:Readiness(
    unknown, state, facts, 0) == "cooldown evidence unknown",
    "missing sealed cooldown evidence must fail closed")
assert(XelAssist.Graph.SpatialRequirements:Blocker(
    unknown, state, descriptor, "target", facts) == "range evidence unknown",
    "missing sealed range evidence must fail closed")

print("ok: sliced root observation freezes action, recipient and reader evidence")
