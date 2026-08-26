XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value) return #value end

local RAPID, AIMED, STEADY, UNKNOWN = 3045, 19434, 3035, 50000
local aura
local rapid = {
    school = 6, category = 55, dispel = 1, mechanic = 0,
    attributes = 65536, attributesEx3 = 0, castingTimeIndex = 1,
    recoveryTime = 300000, categoryRecoveryTime = 0, durationIndex = 8,
    powerType = 0, manaCost = 100, rangeIndex = 1,
    startRecoveryCategory = 0, startRecoveryTime = 0,
    spellFamilyName = 9, spellFamilyFlags = 32, maxAffectedTargets = 0,
    effect = { 6, 6, 0 }, effectDieSides = { 1, 1, 0 },
    effectBasePoints = { 39, -41, 0 },
    effectImplicitTargetA = { 1, 1, 0 },
    effectImplicitTargetB = { 0, 0, 0 },
    effectApplyAuraName = { 9, 108, 0 },
    effectItemType = { 0, 131072, 0 },
    effectMiscValue = { 0, 10, 0 }, effectTriggerSpell = { 0, 0, 0 },
}
local rows = {
    [RAPID] = rapid,
    [AIMED] = { spellFamilyName = 9, spellFamilyFlags = 131072,
        castingTimeIndex = 5, attributes = 4259858, attributesEx3 = 0 },
    [STEADY] = { spellFamilyName = 9, spellFamilyFlags = 68719476736,
        castingTimeIndex = 4, attributes = 2, attributesEx3 = 0 },
    [UNKNOWN] = { spellFamilyName = 9, spellFamilyFlags = 131072,
        castingTimeIndex = 99, attributes = 2, attributesEx3 = 0 },
}

function GetSpellRecField(spellId, field, array)
    local value = rows[spellId] and rows[spellId][field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function GetSpellDuration(spellId)
    return spellId == RAPID and 15 or nil
end

function UnitClass()
    return "Hunter", "HUNTER"
end

function GetTime() return 100 end

C_Spell = { GetSpellInfo = function(spellId)
    if spellId == AIMED then return { spellID = spellId, castTime = 2000 } end
    if spellId == UNKNOWN then return { spellID = spellId, castTime = 2000 } end
    return { spellID = spellId, castTime = 0 }
end }

function GetUnitField(unit, field)
    assert(unit == "player" and field == "modCastSpeed")
    return 1
end

function GetSpellModifiers(spellId, operation)
    assert(operation == 10)
    return 0, aura and spellId == AIMED and -40 or 0, 1
end

C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    assert(spellId == RAPID)
    return aura
end }

dofile("Game/Player/HunterRapidFire.lua")
dofile("Graph/HunterRapidFire.lua")

local Runtime = XelAssist.Game.Player.HunterRapidFire
local Graph = XelAssist.Graph.HunterRapidFire
local knowledge, reason, handled = Runtime:InferKnowledge(RAPID)
assert(handled and not reason and knowledge.kind == "modifier"
    and knowledge.hunterRapidFireEvidence.runtimeUnverified == true,
    "Rapid Fire must be selected only by its complete numeric topology")

local inactive = Runtime:Snapshot("HUNTER")
assert(inactive.available and inactive.exact and not inactive.active
    and inactive.profile.duration == 15,
    "an absent numeric aura must be an exact inactive root")

local setupAction = { spellId = RAPID, actor = "player",
    executor = "playerSpell", facts = knowledge }
local setupFacts = Runtime:CaptureFacts(setupAction, knowledge,
    { hunterRapidFire = inactive })
assert(setupFacts.hunterRapidFire and setupFacts.gcd == 0,
    "setup facts must preserve exact off-GCD Rapid Fire identity")

local aimedAction = { spellId = AIMED, actor = "player",
    executor = "playerSpell", facts = { kind = "damage" } }
local aimedFacts = Runtime:CaptureFacts(aimedAction, aimedAction.facts,
    { hunterRapidFire = inactive })
local cast = aimedFacts.hunterRapidFireCast
assert(cast.claimed and cast.exact and cast.eligible
    and cast.baselineCast == 2.5 and cast.activeCast == 1.7,
    "the installed Aimed Shot mask must seal both exact cast-time outcomes")

local steadyAction = { spellId = STEADY, actor = "player",
    executor = "playerSpell", facts = { kind = "damage" } }
local steadyFacts = Runtime:CaptureFacts(steadyAction, steadyAction.facts,
    { hunterRapidFire = inactive })
assert(not steadyFacts.hunterRapidFireCast.claimed
    and steadyFacts.hunterRapidFireCast.exact
    and not steadyFacts.hunterRapidFireCast.eligible,
    "the unmasked high-word Steady Shot bit must not be guessed affected")
assert(not Graph:PotentialConsumer(steadyFacts),
    "an executable-mask exclusion must never close the Rapid Fire setup lane")
local unrelatedTip, unrelatedReason, unrelatedHandled = Graph:SettleAdmission(
    steadyAction, { time = 0, hunterRapidFire = { available = false } },
    steadyFacts, 0)
assert(unrelatedTip == steadyFacts and unrelatedReason == nil
    and not unrelatedHandled,
    "missing aura evidence must not block an action outside the exact mask")

local unknownAction = { spellId = UNKNOWN, actor = "player",
    executor = "playerSpell", facts = { kind = "damage" } }
local unknownFacts = Runtime:CaptureFacts(unknownAction, unknownAction.facts,
    { hunterRapidFire = inactive })
assert(unknownFacts.hunterRapidFireCast.claimed
    and not unknownFacts.hunterRapidFireCast.exact,
    "an affected but unrecognized cast shape must fail closed")
local noAimed, noAimedReason, aimedHandled = Graph:SettleAdmission(
    aimedAction, { time = 0, hunterRapidFire = { available = false } },
    aimedFacts, 0)
assert(noAimed == nil and aimedHandled
    and noAimedReason == "exact Rapid Fire aura state unavailable",
    "an exactly affected cast must fail closed without aura state")

aura = { spellId = RAPID, isHelpful = true, duration = 15,
    expirationTime = 110 }
local active = Runtime:Snapshot("HUNTER")
local activeAimed = Runtime:CaptureFacts(aimedAction, aimedAction.facts,
    { hunterRapidFire = active }).hunterRapidFireCast
assert(active.active and active.remaining == 10
    and activeAimed.baselineCast == 2.5 and activeAimed.activeCast == 1.7,
    "an active -40 modifier must be stripped before reconstructing baseline")

local state = { time = 0, actors = { player = { guid = "player-guid" } },
    autoShot = { rangedSpeed = 2, rangedSpeedSource = "live ranged speed",
        nextLaunchIn = 0.3, targetGuid = "target-guid" },
    playerAttack = { attackRound = { speed = 2 / 1.4,
        interval = 2 / 1.4 + 0.05, speedTrusted = true, verified = true,
        projectable = true, targetGuid = "target-guid" } } }
assert(Graph:Attach(state, active), "active Rapid Fire root must attach")
assert(state.autoShot.nextLaunchIn == 0.3,
    "root attachment must never rescale the current ranged timer")
assert(math.abs(Graph:RangedIntervalAfter(state, 2, 99) - 2) < 0.000001
    and Graph:RangedIntervalAfter(state, 11, 99) == 2.8,
    "only ranged resets before exact expiry may use the hasted interval")
assert(math.abs(Graph:MeleeIntervalAfter(state, "main", 2, 99)
        - (2 / 1.4 + 0.05)) < 0.000001
    and Graph:MeleeIntervalAfter(state, "main", 11, 99) == 2.05,
    "melee reset cadence must share aura-9 timing without touching phase")

local activeTip = { cost = 75, cast = 2.5,
    hunterRapidFireCast = activeAimed }
local prepared, blocker, castHandled = Graph:SettleAdmission(
    aimedAction, state, activeTip, 2)
assert(castHandled and not blocker and prepared.cast == 1.7
    and prepared.hunterRapidFireCastApplied,
    "a cast starting inside the aura must use its exact active duration")
prepared, blocker = Graph:SettleAdmission(aimedAction, state, activeTip, 11)
assert(not blocker and prepared.cast == 2.5
    and not prepared.hunterRapidFireCastApplied,
    "a cast starting after expiry must use baseline duration")

local inactiveState = { time = 0,
    actors = { player = { guid = "player-guid" } } }
assert(Graph:Attach(inactiveState, inactive), "inactive exact root must attach")
local setupTip = Runtime:CaptureFacts(setupAction,
    { cost = 100, hunterRapidFire = true,
        hunterRapidFireEvidence = knowledge.hunterRapidFireEvidence },
    inactiveState)
prepared, blocker, handled = Graph:PrepareSetup(setupAction, inactiveState,
    { unit = "player", relation = "self", guid = "player-guid" }, setupTip)
assert(handled and not blocker and prepared.hunterRapidFireTransition,
    "the exact self setup must produce one causal transition")
local context = { tooltip = prepared }
assert(Graph:Score(context, prepared) and context.value == 0
    and Graph:StrategicSetup(prepared).consumerKey == Graph.CONSUMER_KEY
    and Graph:PotentialConsumer(aimedFacts),
    "Rapid Fire must remain zero-value until an exact affected cast consumes it")
assert(Graph:Apply(inactiveState, { tooltip = prepared })
    and inactiveState.hunterRapidFire.remaining == 15,
    "projection must arm the exact 15-second window")
local _, unsafe = Graph:SettleAdmission(unknownAction, inactiveState,
    { hunterRapidFireCast = unknownFacts.hunterRapidFireCast }, 0)
assert(unsafe == "affected Rapid Fire cast record is unrecognized",
    "an active aura must block unsupported affected cast shapes")

local saved = { GetSpellRecField, GetSpellDuration, GetSpellModifiers,
    GetUnitField, GetTime, C_Spell.GetSpellInfo,
    C_UnitAuras.GetPlayerAuraBySpellID }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetUnitField = function() error("unit field read during graph search") end
GetTime = function() error("clock read during graph search") end
C_Spell.GetSpellInfo = function() error("spell info read during graph search") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("aura read during graph search")
end
local copied = {}
assert(Graph:Copy(state, copied)
    and Graph:RangedIntervalAfter(copied, 2, 99) == 2,
    "descendant copying and interval decisions must remain API-pure")
prepared, blocker = Graph:SettleAdmission(aimedAction, copied, activeTip, 2)
assert(not blocker and prepared.cast == 1.7,
    "descendant cast timing must use only sealed root evidence")
GetSpellRecField, GetSpellDuration, GetSpellModifiers, GetUnitField,
    GetTime, C_Spell.GetSpellInfo, C_UnitAuras.GetPlayerAuraBySpellID =
    saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7]

-- Prove the production class-discovery, root-state, evidence, dispatch,
-- candidate, and strategic-investment seams compose the leaf.
aura = nil
Runtime:Invalidate()
dofile("Game/ActionInference.lua")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassActionMechanics.lua")
dofile("Graph/ClassMechanics.lua")
dofile("Graph/Candidate.lua")
dofile("Graph/ResourceInvestment.lua")
local Inference = XelAssist.Game.ActionInference
local Mechanics = XelAssist.Graph.ClassMechanics
local Candidate = XelAssist.Graph.Candidate
local Investment = XelAssist.Graph.ResourceInvestment
local integratedKnowledge, integratedReason, integratedHandled =
    Inference:ClassKnowledge(RAPID)
assert(integratedKnowledge and integratedHandled and integratedReason == nil,
    "production discovery must claim exact Rapid Fire")
integratedKnowledge.cost = 100
local integratedState = { time = 0,
    actors = { player = { guid = "player-guid" } },
    autoShot = { active = true, projectable = true, rangedSpeed = 2.8,
        rangedSpeedSource = "live ranged speed", nextLaunchIn = 0.3,
        targetGuid = "target-guid" },
    playerAttack = { active = true, attackRound = { speed = 2,
        interval = 2.05, nextSwingIn = 0.3, phaseKnown = true,
        speedTrusted = true, verified = true, projectable = true,
        targetGuid = "target-guid" },
        offhandAttackRound = { speed = 2, interval = 2.05,
            nextSwingIn = 0.3, phaseKnown = true, speedTrusted = true,
            verified = true, projectable = true,
            targetGuid = "target-guid" } } }
assert(Mechanics:Attach(integratedState)
    and integratedState.classMechanicClass == "HUNTER",
    "production class state must attach the exact inactive aura")
local integratedAction = { spellId = RAPID, actor = "player",
    executor = "playerSpell", facts = integratedKnowledge }
integratedAction.facts = Mechanics:CaptureFacts(
    integratedAction, integratedKnowledge, integratedState)
local selfTarget = { unit = "player", relation = "self",
    guid = "player-guid" }
local projection = assert(Mechanics:Prepare(integratedAction,
    integratedState, selfTarget, integratedAction.facts, 0))
local integratedContext = { action = integratedAction,
    state = integratedState, descriptor = selfTarget,
    facts = integratedAction.facts, tooltip = projection }
assert(Mechanics:Score(integratedContext, projection),
    "production class scoring must retain the neutral setup")
local setupCandidate = Candidate:Build(integratedContext)
assert(setupCandidate.strategicSetup
    and setupCandidate.strategicSetupConsumerKey == Graph.CONSUMER_KEY,
    "production candidates must expose one bounded Rapid Fire setup lane")
local path = { strategicSetupOpen = true,
    strategicSetupConsumerKey = setupCandidate.strategicSetupConsumerKey }
assert(Investment:PotentialConsumer(path, aimedAction, aimedFacts),
    "an exact Aimed Shot contract must close the production setup lane")
setupCandidate.classMechanicProjection = projection
assert(Mechanics:Apply(integratedState, setupCandidate)
    and integratedState.hunterRapidFire.active,
    "production application must arm the exact Rapid Fire window")
local integratedCopy = {}
assert(Mechanics:Copy(integratedState, integratedCopy)
    and integratedCopy.hunterRapidFire.active,
    "production state copying must isolate the active Rapid Fire window")

-- Auto Shot must use the hasted interval only after a launch reset; its
-- current 0.3-second phase remains untouched.
XelAssist.Combat = { AutoShot = {} }
dofile("Combat/AutoShotProjection.lua")
local projectedAuto = XelAssist.Combat.AutoShot:Project(
    integratedState.autoShot,
    { wait = 0, occupancy = 5, cast = 0,
        action = { actor = "pet", facts = {} } }, integratedState)
assert(math.abs(projectedAuto.launchOffsets[1] - 0.3) < 0.000001
    and math.abs(projectedAuto.launchOffsets[2] - 2.3) < 0.000001
    and math.abs(projectedAuto.launchOffsets[3] - 4.3) < 0.000001,
    "production Auto Shot resets must consume Rapid Fire without rescaling phase")

local hostileRecord = { key = "enemy", guid = "target-guid",
    geometry = { player = { distance = 3, distanceKind = "hitbox" } } }
XelAssist.Graph.CompanionTargets = {
    ForGuid = function(_, _, guid)
        return guid == "target-guid" and "enemy" or nil,
            guid == "target-guid" and hostileRecord or nil
    end,
    ProvenDead = function() return false end,
    Hostiles = function() return true end,
}
dofile("Graph/PlayerSwings.lua")
dofile("Graph/PlayerOffhandSwings.lua")
local swingCandidate = { downtime = 5, wait = 0, cast = 0,
    action = { actor = "pet", facts = {} } }
local mainEvents = XelAssist.Graph.PlayerSwings:Events(
    integratedState, swingCandidate)
local offEvents = XelAssist.Graph.PlayerOffhandSwings:Events(
    integratedState, swingCandidate)
local hastedReset = 0.3 + 2 / 1.4 + 0.05
assert(table.getn(mainEvents) == 4 and table.getn(offEvents) == 4
    and math.abs(mainEvents[2].offset - hastedReset) < 0.000001
    and math.abs(offEvents[2].offset - hastedReset) < 0.000001,
    "production melee reset schedulers must consume Rapid Fire after each hand")

print("ok: Rapid Fire preserves current timers and seals only proven resets/casts")
