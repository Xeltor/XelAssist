-- Installed-client Hunter control is identity/topology driven and only a
-- deferred stun with a proven companion melee may claim a cast consequence.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Pets = {} }, Graph = {}, Combat = {} }

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local records = {
    [36533] = { effect = triple(6), aura = triple(26),
        targetA = triple(6), targetB = triple(), mechanic = 7,
        trigger = triple(36534), rangeIndex = 3, family = 9,
        maximum = 0, interrupt = 0 },
    [36534] = { effect = triple(6), aura = triple(33),
        targetA = triple(6), targetB = triple(),
        effectMechanic = triple(11), basePoints = triple(-61),
        baseDice = triple(1), interrupt = 0 },
    [7371] = { effect = triple(96, 6, 64), aura = triple(0, 99),
        targetA = triple(6, 1, 6), targetB = triple(),
        trigger = triple(0, 0, 25999), rangeIndex = 95,
        interrupt = 0 },
    [25999] = { effect = triple(6), aura = triple(26),
        targetA = triple(6), targetB = triple(), mechanic = 7,
        rangeIndex = 95, interrupt = 0 },
    [19577] = { effect = triple(6, 64), aura = triple(42),
        targetA = triple(5, 5), targetB = triple(),
        trigger = triple(24394, 51556), procFlags = 20,
        procChance = 100, procCharges = 1, interrupt = 0 },
    [24394] = { effect = triple(63, 6), aura = triple(0, 12),
        targetA = triple(6, 6), targetB = triple(), mechanic = 12,
        rangeIndex = 2, interrupt = 0 },
    [51556] = { effect = triple(6), aura = triple(10),
        targetA = triple(5), targetB = triple(),
        basePoints = triple(49), baseDice = triple(1),
        misc = triple(127), interrupt = 0 },
}
local durations = { [36533] = 2000, [36534] = 2000,
    [7371] = 4000, [25999] = 1000,
    [19577] = 15000, [24394] = 3000, [51556] = 8000 }
local ranges = { [2] = { 0, 5 }, [3] = { 0, 20 }, [95] = { 8, 25 } }
local reads = 0

function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    local row = records[spellId]
    if not row then return nil end
    local arrays = { effect = row.effect,
        effectBasePoints = row.basePoints, effectBaseDice = row.baseDice,
        effectMechanic = row.effectMechanic,
        effectApplyAuraName = row.aura,
        effectImplicitTargetA = row.targetA,
        effectImplicitTargetB = row.targetB,
        effectMiscValue = row.misc,
        effectTriggerSpell = row.trigger }
    if arrays[field] then
        local value = arrays[field]
        return { value[1], value[2], value[3] }
    end
    local fields = { mechanic = row.mechanic, rangeIndex = row.rangeIndex,
        spellFamilyName = row.family, maxAffectedTargets = row.maximum,
        auraInterruptFlags = row.interrupt, procFlags = row.procFlags,
        procChance = row.procChance, procCharges = row.procCharges }
    return fields[field]
end
function GetSpellDuration(spellId)
    reads = reads + 1
    return durations[spellId]
end
function GetSpellRangeData(index)
    reads = reads + 1
    local found = ranges[index]
    return found and found[1], found and found[2]
end

dofile("Game/Pets/HunterControl.lua")
local GameControl = XelAssist.Game.Pets.HunterControl
local webAction = { name = "Renamed web", spellId = 36533, actor = "pet",
    facts = { kind = "crowdControl", hunterPet = true } }
local chargeAction = { name = "Renamed charge", spellId = 7371,
    actor = "pet", facts = { kind = "crowdControl", hunterPet = true } }
local intimidationAction = { name = "Renamed intimidation", spellId = 19577,
    actor = "player", facts = { kind = "crowdControl",
        fixedTarget = "pet", effectTarget = "target" } }

local web = assert(GameControl:Classify(webAction))
assert(web.valid and web.applicationMode == "immediate"
    and web.controlType == "root" and web.duration == 2
    and web.minRange == 0 and web.maxRange == 20
    and web.interruptsCasting == false and web.linkedSpellId == 36534
    and web.movementSpeedPercent == -60 and web.damageBreakSpecified,
    "Web must retain its exact immediate root lifecycle")
local charge = assert(GameControl:Classify(chargeAction))
assert(charge.valid and charge.applicationMode == "chargeImpact"
    and charge.controlSpellId == 25999 and charge.duration == 1
    and charge.minRange == 8 and charge.maxRange == 25
    and charge.movesSourceToTarget and not charge.interruptsCasting,
    "Charge must retain its exact movement-triggered root lifecycle")
local intimidation = assert(GameControl:Classify(intimidationAction))
assert(intimidation.valid and intimidation.applicationMode == "nextPetMelee"
    and intimidation.controlSpellId == 24394
    and intimidation.triggerWindow == 15 and intimidation.duration == 3
    and intimidation.minRange == 0 and intimidation.maxRange == 5
    and intimidation.threatSpellId == 51556
    and intimidation.threatRecipient == "pet"
    and intimidation.threatMultiplier == 1.5
    and intimidation.interruptsCasting,
    "Intimidation must retain both its deferred stun and threat trigger")

local baseFacts = { duration = 15 }
local captured = GameControl:CaptureFacts(intimidationAction, baseFacts)
assert(captured.hunterControlEvidence.valid
    and captured.crowdControlEvidence.controlSpellId == 24394
    and baseFacts.crowdControlEvidence == nil,
    "root capture must seal evidence without mutating tooltip facts")
dofile("Game/CrowdControl.lua")
local centralCaptured = XelAssist.Game.CrowdControl:CaptureFacts(
    intimidationAction, baseFacts)
assert(centralCaptured.hunterControlEvidence
    and centralCaptured.hunterControlEvidence.portfolio == "hunterControl"
    and centralCaptured.crowdControlEvidence.controlSpellId == 24394,
    "central crowd-control capture must delegate Hunter control first")
local wrongActor = GameControl:Classify({ spellId = 36533, actor = "player",
    facts = { kind = "crowdControl", hunterPet = true } })
assert(wrongActor and not wrongActor.valid,
    "a Hunter pet identity must not become a player control")
local outside, _, handled = GameControl:Classify({ spellId = 99999,
    actor = "pet", facts = { kind = "crowdControl", hunterPet = true } })
assert(outside == nil and not handled,
    "unrelated identities must not enter this narrow portfolio")

GameControl:Invalidate()
local saved = records[36533].targetA
records[36533].targetA = triple(22)
local beforeBroken = reads
local broken, reason, brokenHandled = GameControl:Classify(webAction)
assert(broken and not broken.valid and brokenHandled
    and string.find(reason, "topology"),
    "a recognized Web identity with changed topology must fail closed")
local afterBroken = reads
local brokenAgain, reasonAgain, handledAgain = GameControl:Classify(webAction)
assert(brokenAgain and not brokenAgain.valid and handledAgain
    and reasonAgain == reason and reads == afterBroken and afterBroken > beforeBroken,
    "a cached invalid identity must remain handled without changing semantics")
records[36533].targetA = saved
GameControl:Invalidate()
records[25999].interrupt = 2
local changedBreak, changedBreakReason, changedBreakHandled =
    GameControl:Classify(chargeAction)
assert(changedBreak and not changedBreak.valid and changedBreakHandled
    and string.find(changedBreakReason, "break"),
    "a changed damage-break lifecycle must fail closed")
records[25999].interrupt = 0
GameControl:Invalidate()
web = assert(GameControl:Classify(webAction))
charge = assert(GameControl:Classify(chargeAction))
intimidation = assert(GameControl:Classify(intimidationAction))
local cachedReads = reads
GetSpellRecField = function() error("live DBC read during graph search") end
GetSpellDuration = function() error("live duration read during graph search") end
GetSpellRangeData = function() error("live range read during graph search") end
assert(GameControl:Classify(webAction).valid and reads == cachedReads,
    "recognized Hunter control must remain cached after root capture")

dofile("Game/Range.lua")
local refreshed = 0
XelAssist.Graph.State = {
    HostileByKey = function(_, state, key)
        return state.hostiles and state.hostiles.byKey[key]
    end,
    ActiveHostile = function(_, state)
        return state.hostiles and state.hostiles.byKey[state.targetContextKey]
    end,
    RefreshHostileRecord = function() refreshed = refreshed + 1 end,
}
local function castFor(state, guid)
    return state.hostileCasts and state.hostileCasts.byCaster[guid]
end
XelAssist.Graph.HostileCastState = {
    Find = function(_, state, guid) return castFor(state, guid) end,
    Retire = function(_, state, guid)
        local cast = castFor(state, guid)
        state.hostileCasts.byCaster[guid] = nil
        return cast
    end,
    SetProbability = function(_, state, guid, _, probability)
        local cast = castFor(state, guid)
        if cast then cast.probability = probability end
        return cast
    end,
}
XelAssist.Graph.IncomingConsequences = {
    PreventedValue = function(_, _, cast)
        return cast and cast.consequence and cast.consequence.value or nil,
            cast and "prevents exact incoming damage" or "unavailable"
    end,
}
XelAssist.Combat.Resistance = {
    Estimate = function(_, action, target, _, state)
        assert(action.actor == "pet" and action.facts.whiteAttack
            and target == "target" and state.sealed,
            "deferred delivery must consume only frozen pet-melee state")
        return { landChance = 0.75 }
    end,
}
XelAssist.Graph.Effects = {
    Decision = function(_, estimate) return estimate.landChance,
        estimate.landChance end,
}
dofile("Graph/HunterControl.lua")
local GraphControl = XelAssist.Graph.HunterControl
dofile("Graph/CrowdControl.lua")
local ControlFacade = XelAssist.Graph.CrowdControl

local function fixture(distance)
    local guid, key = "hostile-guid", "hostile-key"
    local record = { guid = guid, key = key, projectedAuras = {},
        targetAuras = {}, geometry = { pet = {
            distance = distance or 3, distanceKind = "hitbox" } } }
    local state = { sealed = true, time = 0, targetGUID = guid,
        targetContextKey = key, auras = record.projectedAuras,
        targetAuras = record.targetAuras,
        hostiles = { byKey = { [key] = record } },
        hostileCasts = { byCaster = { [guid] = { remaining = 2,
            probability = 1, generation = 1,
            consequence = { value = 1000 } } } },
        actors = { pet = { targetExists = true, targetGuid = guid,
            companionTimelineExact = true,
            attackRound = { projectable = true, phaseKnown = true,
                verified = true, attackActive = true, targetGuid = guid,
                nextSwingIn = 1, interval = 2 } } } }
    local descriptor = { relation = "hostile", guid = guid, key = key,
        record = record }
    return state, descriptor, record
end
local function tooltip(found)
    return { cast = 0, hunterControlEvidence = found,
        crowdControlEvidence = found }
end

local state, descriptor, record = fixture(3)
local blocker, exact = ControlFacade:Blocker(webAction, state, descriptor,
    tooltip(web), 0)
assert(exact and blocker == "root has no modeled hostile consequence",
    "Web must not be mislabeled as a cast interrupt")
local webCandidate = { action = webAction, tooltip = tooltip(web),
    target = "target", targetGUID = descriptor.guid, targetKey = descriptor.key,
    targetRelation = "hostile", effectDelivery = 0.8 }
assert(ControlFacade:Apply(state, webCandidate, { applicationElapsed = 0 }))
local webAura = state.auras["hunterControl:36533"]
assert(webAura and webAura.remaining == 2 and webAura.crowdControl
    and webAura.applicationProbability == 0.8
    and state.hostileCasts.byCaster[descriptor.guid],
    "Web must project its root without suppressing an active cast")
webAura.applicationProbability = 0.6
blocker = ControlFacade:Blocker(webAction, state, descriptor,
    tooltip(web), 0)
assert(blocker == "root has no modeled hostile consequence",
    "a low-probability root branch must not suppress a legal retry")
webAura.applicationProbability = 0.75
blocker = ControlFacade:Blocker(webAction, state, descriptor,
    tooltip(web), 0)
assert(blocker == "target already controlled",
    "the shared application threshold must block a likely active root")

state, descriptor = fixture(5)
blocker = ControlFacade:Blocker(chargeAction, state, descriptor,
    tooltip(charge), 0)
assert(blocker == "minimum range",
    "Charge must retain its exact eight-yard minimum")
state, descriptor = fixture(10)
blocker = ControlFacade:Blocker(chargeAction, state, descriptor,
    tooltip(charge), 0)
assert(blocker == "root has no modeled hostile consequence",
    "Charge root must not invent a cast consequence")

state, descriptor = fixture(3)
blocker, exact = ControlFacade:Blocker(intimidationAction, state, descriptor,
    tooltip(intimidation), 0)
assert(exact and blocker == nil,
    "an exact next pet melee before the cast must admit Intimidation")
local score = { action = intimidationAction, state = state,
    descriptor = descriptor, tooltip = tooltip(intimidation),
    actionStart = 0, effectDelivery = 0.8 }
assert(ControlFacade:Score(score) and math.abs(score.value - 600) < 0.0001
    and score.hunterControlArrival == 1,
    "Intimidation value must be consequence times melee and result delivery")
local intimidationCandidate = { action = intimidationAction,
    tooltip = tooltip(intimidation), target = "target",
    targetGUID = descriptor.guid, targetKey = descriptor.key,
    targetRelation = "hostile", effectDelivery = 0.8 }
assert(ControlFacade:Apply(state, intimidationCandidate,
    { applicationElapsed = 0 }))
local pending = state.actors.pet.pendingMeleeEffects[intimidationAction.name]
assert(pending and pending.remaining == 15 and pending.stunDuration == 3
    and pending.resultDelivery == 0.8 and not next(state.auras)
    and state.hostileCasts.byCaster[descriptor.guid],
    "Intimidation must arm without applying or pricing its stun early")

dofile("Game/Pets/Effects.lua")
dofile("Graph/CompanionEventThreat.lua")
local melee = { actor = "pet", facts = { kind = "damage", melee = true } }
local consumed = XelAssist.Graph.CompanionEventThreat:ConsumeMelee(
    state, state, melee, descriptor.guid, 0.75, nil, true)
assert(consumed and state.auras[intimidationAction.name]
    and state.auras[intimidationAction.name].hunterControlResolved,
    "the matching successful melee branch must resolve deferred control")
local stun = state.auras[intimidationAction.name]
assert(stun and stun.crowdControl and stun.controlSpellId == 24394
    and math.abs(stun.applicationProbability - 0.6) < 0.0001
    and math.abs(state.hostileCasts.byCaster[
        descriptor.guid].probability - 0.4) < 0.0001,
    "the actual melee event must apply and value the stun probability")

state, descriptor = fixture(3)
local lowResultCandidate = { action = intimidationAction,
    tooltip = tooltip(intimidation), target = "target",
    targetGUID = descriptor.guid, targetKey = descriptor.key,
    targetRelation = "hostile", effectDelivery = 0.1 }
assert(ControlFacade:Apply(state, lowResultCandidate,
    { applicationElapsed = 0 }))
XelAssist.Graph.CompanionEventThreat:ConsumeMelee(
    state, state, melee, descriptor.guid, 0.8, nil, true)
local strongest = state.auras[intimidationAction.name]
assert(strongest and math.abs(strongest.rawApplicationProbability - 0.8) < 0.0001
    and math.abs(strongest.applicationProbability - 0.08) < 0.0001,
    "deferred control must retain raw trigger and result delivery separately")
strongest.remaining = 1
XelAssist.Graph.CompanionEventThreat:ConsumeMelee(
    state, state, melee, descriptor.guid, 1, nil, true)
strongest = state.auras[intimidationAction.name]
assert(math.abs(strongest.rawApplicationProbability - 0.8) < 0.0001
    and math.abs(strongest.applicationProbability - 0.08) < 0.0001
    and strongest.alternateProcTimingWithheld,
    "a weaker later raw trigger must not replace a stronger scaled stun branch")

state, descriptor = fixture(3)
state.hostileCasts.byCaster[descriptor.guid].remaining = 0.8
blocker = ControlFacade:Blocker(intimidationAction, state, descriptor,
    tooltip(intimidation), 0)
assert(blocker == "companion stun arrives after modeled consequence",
    "a late deferred stun must fail closed")
state, descriptor = fixture(3)
state.actors.pet.attackRound.projectable = false
blocker = ControlFacade:Blocker(intimidationAction, state, descriptor,
    tooltip(intimidation), 0)
assert(blocker == "exact companion swing timing unavailable",
    "missing companion phase must not invent a proc time")
state, descriptor = fixture(6)
blocker = ControlFacade:Blocker(intimidationAction, state, descriptor,
    tooltip(intimidation), 0)
assert(blocker == "range",
    "the deferred stun must retain its exact melee effect band")
assert(reads == cachedReads,
    "no Hunter graph operation may revisit live DBC, duration, or range APIs")

print("ok: exact Hunter roots and deferred Intimidation consequences")
