table.getn = table.getn or function(value) return #value end
XelAssist = { Game = {}, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {
    -- Exact rows from the installed Octowow patch-5.mpq Spell.dbc.  The test
    -- action names below are intentionally unrelated to these spell identities.
    [118] = { spellFamilyName = 3, mechanic = 17,
        attributesEx = 0,
        auraInterruptFlags = 524290, targetCreatureType = 193,
        maxAffectedTargets = 0, effect = triple(6, 6, 108),
        effectApplyAuraName = triple(5, 56),
        effectImplicitTargetA = triple(6, 6, 6),
        effectImplicitTargetB = triple() },
    [5782] = { spellFamilyName = 5, mechanic = 5,
        attributesEx = 0,
        auraInterruptFlags = 0, targetCreatureType = 0,
        maxAffectedTargets = 0, effect = triple(6, 6),
        effectApplyAuraName = triple(7, 31),
        effectImplicitTargetA = triple(6, 6),
        effectImplicitTargetB = triple() },
    [9484] = { spellFamilyName = 6, mechanic = 20,
        attributesEx = 0,
        auraInterruptFlags = 2, targetCreatureType = 32,
        maxAffectedTargets = 0, effect = triple(6),
        effectApplyAuraName = triple(12),
        effectImplicitTargetA = triple(6), effectImplicitTargetB = triple() },
    [8122] = { spellFamilyName = 6, mechanic = 5,
        attributesEx = 0,
        auraInterruptFlags = 0, targetCreatureType = 0,
        maxAffectedTargets = 5, effect = triple(6, 6),
        effectApplyAuraName = triple(7, 31),
        effectImplicitTargetA = triple(22, 22),
        effectImplicitTargetB = triple(15, 15) },
    [122] = { spellFamilyName = 3, mechanic = 7,
        attributesEx = 0,
        auraInterruptFlags = 0, targetCreatureType = 0,
        maxAffectedTargets = 0, effect = triple(2, 6),
        effectApplyAuraName = triple(0, 26),
        effectImplicitTargetA = triple(22, 22),
        effectImplicitTargetB = triple(15, 15) },
    [710] = { spellFamilyName = 5, mechanic = 18,
        attributesEx = 0,
        auraInterruptFlags = 0, targetCreatureType = 12,
        maxAffectedTargets = 0, effect = triple(6, 6),
        effectApplyAuraName = triple(12, 39),
        effectImplicitTargetA = triple(6, 6),
        effectImplicitTargetB = triple() },
    [60007] = { spellFamilyName = 5, mechanic = 5,
        attributesEx = 0,
        auraInterruptFlags = 0, targetCreatureType = 0,
        maxAffectedTargets = 0, effect = triple(6),
        effectApplyAuraName = triple(7),
        effectImplicitTargetA = triple(25), effectImplicitTargetB = triple() },
    [2637] = { spellFamilyName = 7, mechanic = 10,
        attributesEx = 0,
        auraInterruptFlags = 2, targetCreatureType = 1,
        maxAffectedTargets = 0, effect = triple(6),
        effectApplyAuraName = triple(12),
        effectImplicitTargetA = triple(6), effectImplicitTargetB = triple() },
    [6358] = { spellFamilyName = 5, mechanic = 1,
        attributesEx = 4,
        auraInterruptFlags = 2, targetCreatureType = 64,
        maxAffectedTargets = 0, effect = triple(6),
        effectApplyAuraName = triple(12),
        effectImplicitTargetA = triple(6), effectImplicitTargetB = triple() },
}

local reads = 0
function GetSpellRecField(spellId, field, asArray)
    reads = reads + 1
    local record = records[spellId]
    if not record then return nil end
    local value = record[field]
    if asArray and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/CrowdControl.lua")
local GameControl = XelAssist.Game.CrowdControl

local polymorph = assert(GameControl:Classify(118))
assert(polymorph.valid and polymorph.family == 3
    and polymorph.controlType == "polymorph"
    and polymorph.targetCreatureMask == 193
    and polymorph.breaksOnAnyDamage
    and not polymorph.breaksOnDirectDamage,
    "Polymorph should be identified from exact DBC fields")

local fear = assert(GameControl:Classify(5782))
assert(fear.valid and fear.controlType == "fear"
    and not fear.damageBreakSpecified,
    "Fear's paired movement aura should not require a localized name")

local shackle = assert(GameControl:Classify(9484))
assert(shackle.valid and shackle.targetCreatureMask == 32
    and shackle.breaksOnAnyDamage,
    "Shackle should retain its Undead mask and damage-cancel flag")

local rejected
rejected = GameControl:Classify(8122)
assert(rejected and not rejected.valid
    and string.find(rejected.reason, "area crowd control"),
    "area control must wait for recipient-set projection")
local hybridHandled
rejected, _, hybridHandled = GameControl:Classify(122)
assert(rejected and not rejected.valid and hybridHandled,
    "damage/control hybrids must not be flattened into pure control")
rejected = GameControl:Classify(710)
assert(rejected and not rejected.valid,
    "Banish immunity must not be discarded as an auxiliary aura")
rejected = GameControl:Classify(60007)
assert(rejected and not rejected.valid,
    "unresolved recipient topology must fail closed")
local outside, _, handled = GameControl:Classify(2637)
assert(outside and not outside.valid and not handled,
    "this caster portfolio must not claim another class family")

local inferred = assert(GameControl:InferKnowledge(118))
assert(inferred.kind == "crowdControl" and inferred.kindExact
    and inferred.submissionGuarded and inferred.requiresExactUsability
    and inferred.crowdControlEvidence.valid,
    "inference should expose mechanics without defining a rotation")

local explicit = { name = "Localized pet control", spellId = 6358,
    actor = "pet", facts = { kind = "crowdControl", channel = true } }
local captured = GameControl:CaptureFacts(explicit, { duration = 15 })
assert(not captured.crowdControlEvidence,
    "channeled control must not acquire a post-channel lifecycle")
local rejectedChannel, channelReason, channelHandled =
    GameControl:Classify(6358)
assert(rejectedChannel and not rejectedChannel.valid and channelHandled
    and string.find(channelReason, "channeled control"),
    "installed channel flags must reject maintained control before inference")

local cachedReads = reads
GetSpellRecField = function() error("DBC read during graph search") end
assert(GameControl:Classify(118).valid and reads == cachedReads,
    "cached classification must not revisit mutable client APIs")
local sealed = GameControl:CaptureFacts(
    { name = "Renamed", spellId = 118, facts = inferred },
    { duration = 20 })
assert(sealed.crowdControlEvidence.valid and reads == cachedReads,
    "inferred action evidence must remain sealed at root capture")

local refreshed = 0
local function hostile(state, key)
    return state.hostiles and state.hostiles.byKey[key]
end
XelAssist.Graph.State = {
    HostileByKey = function(_, state, key) return hostile(state, key) end,
    ActiveHostile = function(_, state)
        return hostile(state, state.targetContextKey
            or state.hostiles and state.hostiles.selectedKey)
    end,
    RefreshHostileRecord = function() refreshed = refreshed + 1 end,
}
XelAssist.Graph.HostileCastState = {
    Find = function(_, state, guid)
        return state.hostileCasts and state.hostileCasts.byCaster[guid]
    end,
    Retire = function(_, state, guid)
        local cast = state.hostileCasts.byCaster[guid]
        state.hostileCasts.byCaster[guid] = nil
        return cast
    end,
    SetProbability = function(_, state, guid, _, probability)
        local cast = state.hostileCasts.byCaster[guid]
        if cast then cast.probability = probability end
        return cast
    end,
}
XelAssist.Graph.IncomingConsequences = {
    PreventedValue = function(_, _, cast)
        return cast and cast.consequence and 900 or nil,
            cast and "prevents modeled incoming damage"
                or "consequence unavailable"
    end,
}
dofile("Graph/CrowdControl.lua")
local GraphControl = XelAssist.Graph.CrowdControl

local keyA, keyB = "enemy-a", "enemy-b"
local recordA = { key = keyA, guid = "guid-a", health = 100,
    healthExact = true, encounter = { creatureTypeId = 7 },
    projectedAuras = {} }
local recordB = { key = keyB, guid = "guid-b", health = 100,
    healthExact = true, encounter = { creatureTypeId = 7 },
    projectedAuras = {} }
local state = { time = 4, targetGUID = "guid-a", targetContextKey = keyA,
    hostiles = { selectedKey = keyA, order = { keyA, keyB },
        byKey = { [keyA] = recordA, [keyB] = recordB } },
    hostileCasts = { byCaster = {
        ["guid-a"] = { remaining = 10, probability = 1, generation = 1,
            consequence = { kind = "damage" } },
        ["guid-b"] = { remaining = 10, probability = 1, generation = 1,
            consequence = { kind = "damage" } },
    } },
    auras = recordA.projectedAuras }
local action = { name = "Untranslated control", spellId = 118,
    actor = "player", facts = inferred }
local tooltip = { duration = 20, cast = 1.5,
    crowdControlEvidence = polymorph }
local candidate = { action = action, tooltip = tooltip,
    target = "target", targetKey = keyA, targetGUID = "guid-a",
    targetRelation = "hostile", effectDelivery = 1 }

local applied, reason = GraphControl:Apply(
    state, candidate, { applicationElapsed = 0.5 })
assert(applied and not reason
    and recordA.projectedAuras[action.name].remaining == 19.5
    and not recordB.projectedAuras[action.name]
    and reads == cachedReads,
    "control projection should be duration-aware and hostile-local")

local descriptorA = { key = keyA, guid = "guid-a", record = recordA,
    relation = "hostile" }
local blocker, exact = GraphControl:Blocker(
    action, state, descriptorA, tooltip, 4)
assert(exact and blocker == "target already controlled",
    "active projected control should block a duplicate cast")
state.hostileCasts.byCaster["guid-a"] = { remaining = 30,
    probability = 1, generation = 2, consequence = { kind = "damage" } }
blocker = GraphControl:Blocker(action, state, descriptorA, tooltip, 24)
assert(blocker == nil,
    "a recast may begin when its application lands after expiration")

local descriptorB = { key = keyB, guid = "guid-b", record = recordB,
    relation = "hostile" }
blocker = GraphControl:Blocker(action, state, descriptorB, tooltip, 4)
assert(blocker == nil,
    "control on one hostile must not block another hostile")

local scoreContext = { state = state, descriptor = descriptorB,
    effectDelivery = 0.5 }
assert(GraphControl:Score(scoreContext) and scoreContext.value == 450
    and scoreContext.reason == "prevents modeled incoming damage",
    "control utility must be derived from a represented downstream consequence")

local unknownTip = { crowdControlEvidence = polymorph }
blocker = GraphControl:Blocker(action, state, descriptorB, unknownTip, 4)
assert(blocker == "crowd-control duration unknown",
    "duration-unknown controls must fail before candidate publication")
state.hostileCasts.byCaster["guid-b"] = nil
blocker = GraphControl:Blocker(action, state, descriptorB, tooltip, 4)
assert(blocker == "control consequence unavailable",
    "controls without a represented downstream effect must fail closed")
state.hostileCasts.byCaster["guid-b"] = { remaining = 10,
    probability = 1, generation = 2, consequence = { kind = "damage" } }

local shackleAction = { name = "Type restricted", spellId = 9484,
    facts = assert(GameControl:InferKnowledge(9484)) }
local shackleTip = { duration = 50, crowdControlEvidence = shackle }
blocker = GraphControl:Blocker(
    shackleAction, state, descriptorA, shackleTip, 4)
assert(blocker == "incompatible creature type",
    "numeric creature masks should reject incompatible targets")
recordA.encounter.creatureTypeId = nil
blocker = GraphControl:Blocker(
    shackleAction, state, descriptorA, shackleTip, 4)
assert(blocker == "creature type evidence unknown",
    "missing numeric creature evidence must fail closed")
recordA.encounter.creatureTypeId = 7

local snapshot = assert(GraphControl:DamageSnapshot(state))
recordA.health = 90
local resolved = GraphControl:ResolveDamage(state, snapshot,
    { direct = false, guaranteed = true, source = "periodic test" })
assert(resolved.removed == 1 and not recordA.projectedAuras[action.name]
    and not recordB.projectedAuras[action.name],
    "a guaranteed damage event should clear any-damage control locally")

GraphControl:Apply(state, candidate, { applicationElapsed = 0 })
snapshot = GraphControl:DamageSnapshot(state)
recordA.health = 85
resolved = GraphControl:ResolveDamage(state, snapshot,
    { direct = true, guaranteed = false, source = "expected spell damage" })
local uncertainAura = recordA.projectedAuras[action.name]
assert(resolved.uncertain == 1 and uncertainAura
    and uncertainAura.controlBreakOutcomeUnknown,
    "probabilistic damage must not invent a guaranteed control break")
blocker = GraphControl:Blocker(action, state, descriptorA, tooltip, 4)
assert(blocker == "control persistence unknown",
    "an unresolved damage branch should fail closed on duplicate control")

recordA.projectedAuras = {}
state.auras = recordA.projectedAuras
local directEvidence = {
    valid = true, controlType = "stun", targetCreatureMask = 0,
    breaksOnAnyDamage = false, breaksOnDirectDamage = true,
    damageBreakSpecified = true, source = "test direct flag" }
local directAction = { name = "Direct-break control",
    facts = { kind = "crowdControl" } }
local directCandidate = { action = directAction,
    tooltip = { duration = 10, crowdControlEvidence = directEvidence },
    target = "target", targetKey = keyA, targetGUID = "guid-a",
    targetRelation = "hostile", effectDelivery = 1 }
assert(GraphControl:Apply(state, directCandidate, { applicationElapsed = 0 }))
resolved = GraphControl:ApplyDamage(state, { targetKey = keyA,
    targetGuid = "guid-a", amount = 5, direct = false, guaranteed = true })
assert(resolved.affected == 0 and recordA.projectedAuras[directAction.name],
    "periodic damage must not clear direct-damage-only control")
resolved = GraphControl:ApplyDamage(state, { targetKey = keyA,
    targetGuid = "guid-a", amount = 5, direct = true, guaranteed = true })
assert(resolved.removed == 1 and not recordA.projectedAuras[directAction.name],
    "guaranteed direct damage should clear direct-damage control")

local fearAction = { name = "Unscripted break", facts = {
    kind = "crowdControl", crowdControlEvidence = fear } }
local fearCandidate = { action = fearAction,
    tooltip = { duration = 20, crowdControlEvidence = fear },
    target = "target", targetKey = keyA, targetGUID = "guid-a",
    targetRelation = "hostile", effectDelivery = 1 }
assert(GraphControl:Apply(state, fearCandidate, { applicationElapsed = 0 }))
resolved = GraphControl:ApplyDamage(state, { targetKey = keyA,
    targetGuid = "guid-a", amount = 1, direct = true, guaranteed = true })
assert(resolved.uncertain == 1
    and recordA.projectedAuras[fearAction.name].controlBreakOutcomeUnknown,
    "unflagged server-side break behavior must remain explicitly unknown")

local channelTip = { duration = 15, channel = true,
    crowdControlEvidence = { valid = true, controlType = "charm",
        targetCreatureMask = 64, breaksOnAnyDamage = true,
        damageBreakSpecified = true, source = "defensive fixture" } }
local channelCandidate = { action = explicit, tooltip = channelTip,
    target = "target", targetKey = keyA, targetGUID = "guid-a",
    targetRelation = "hostile", effectDelivery = 1 }
applied, reason = GraphControl:Apply(
    state, channelCandidate, { applicationElapsed = 0 })
assert(not applied and string.find(reason, "channeled control"),
    "maintained channel control must not become a post-channel aura")
blocker = GraphControl:Blocker(
    explicit, state, descriptorA, channelTip, 4)
assert(blocker == "channeled control projection unavailable",
    "maintained channel control must not become a legal graph candidate")

assert(reads == cachedReads,
    "no graph projection method may read live DBC state")
assert(refreshed > 0, "hostile compatibility views should be refreshed")
print("crowd control graph tests passed")
