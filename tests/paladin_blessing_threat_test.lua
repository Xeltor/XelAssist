-- Installed-topology and search-purity coverage for the Paladin all-threat
-- blessing leaf. Localized spell names are intentionally unavailable.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local arrayFields = { "effect", "effectDieSides", "effectBaseDice",
    "effectDicePerLevel", "effectRealPointsPerLevel", "effectBasePoints",
    "effectMechanic", "effectImplicitTargetA", "effectImplicitTargetB",
    "effectRadiusIndex", "effectApplyAuraName", "effectAmplitude",
    "effectMultipleValue", "effectChainTarget", "effectItemType",
    "effectMiscValue", "effectTriggerSpell",
    "effectPointsPerComboPoint" }

local function blank(flags)
    local out = { spellFamilyName = 10, spellFamilyFlags = flags }
    local index
    for index = 1, table.getn(arrayFields) do
        out[arrayFields[index]] = triple()
    end
    return out
end

local function threat(flags, target, radius)
    local out = blank(flags)
    out.effect = triple(6)
    out.effectDieSides = triple(1)
    out.effectBaseDice = triple(1)
    out.effectBasePoints = triple(-26)
    out.effectImplicitTargetA = triple(target)
    out.effectRadiusIndex = triple(radius)
    out.effectApplyAuraName = triple(10)
    out.effectMiscValue = triple(127)
    return out
end

local function ordinary(flags)
    local out = blank(flags)
    out.effect = triple(6)
    out.effectDieSides = triple(1)
    out.effectBaseDice = triple(1)
    out.effectBasePoints = triple(19)
    out.effectImplicitTargetA = triple(21)
    out.effectApplyAuraName = triple(99)
    return out
end

local records = {
    [1038] = threat(268435712, 57, 0),
    [25895] = threat(268435712, 61, 12),
    [19740] = ordinary(268435458),
    [5001] = threat(268435712, 57, 0),
    [5002] = ordinary(268435458),
}
records[5001].effectRealPointsPerLevel[1] = 1
records[5002].effectTriggerSpell[1] = 9000

local dbcCalls = 0
UnitClass = function() return "Localized class", "PALADIN" end
GetSpellName = function()
    error("all-threat blessing discovery must not inspect localized names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/PaladinAuraState.lua")
dofile("Game/Player/PaladinActions.lua")
dofile("Game/Player/PaladinBlessingThreat.lua")
local Auras = XelAssist.Game.Player.PaladinAuraState
local Actions = XelAssist.Game.Player.PaladinActions
local Evidence = XelAssist.Game.Player.PaladinBlessingThreat

local action = { spellId = 1038, actor = "player" }
local base = Actions:InferKnowledge(action.spellId)
assert(base and base.paladinBlessing
    and base.paladinEffectRepresented == false,
    "the generic blessing adapter must begin lifecycle-only")
local promoted = Evidence:Promote(action.spellId, base)
local effect = Evidence:Effect(promoted)
assert(promoted ~= base and promoted.paladinEffectRepresented == true
    and promoted.paladinBlessingThreatEvidence.valid
    and effect and effect.exact and effect.kind == "playerThreatMultiplier"
    and effect.schoolMask == 127 and effect.percent == -25
    and effect.multiplier == 0.75 and effect.recipientShape == "single",
    "single-recipient exact topology must promote a copied downstream fact")

local groupAction = { spellId = 25895, actor = "player" }
local groupBase = Actions:InferKnowledge(groupAction.spellId)
local groupFacts = Evidence:Promote(groupAction.spellId, groupBase)
local group = Evidence:Inspect(25895, groupBase.paladinClassification)
assert(groupFacts == groupBase and group.valid and group.exact
    and group.recipientShape == "classGroup"
    and group.actionRepresented == false,
    "class-group fanout must remain action-unrepresented")

local ordinaryAction = { spellId = 19740, actor = "player" }
local ordinaryBase = Actions:InferKnowledge(ordinaryAction.spellId)
local ordinaryFacts = Evidence:Promote(ordinaryAction.spellId, ordinaryBase)
local ordinaryEvidence = Evidence:Inspect(
    ordinaryAction.spellId, ordinaryBase.paladinClassification)
assert(ordinaryFacts == ordinaryBase and ordinaryEvidence.available
    and ordinaryEvidence.exact and not ordinaryEvidence.recognized,
    "another exact blessing must remain lifecycle-only without invented threat")

local malformedAction = { spellId = 5001, actor = "player" }
local malformedBase = Actions:InferKnowledge(malformedAction.spellId)
local malformed = Evidence:Inspect(
    malformedAction.spellId, malformedBase.paladinClassification)
assert(malformed.recognized and not malformed.available
    and Evidence:Promote(malformedAction.spellId, malformedBase) == malformedBase,
    "a scaled or changed threat topology must fail closed")
local triggeredBase = Actions:InferKnowledge(5002)
local triggered = Evidence:Inspect(5002, triggeredBase.paladinClassification)
assert(not triggered.available
    and string.find(triggered.reason or "", "triggered") ~= nil,
    "an indirect blessing consequence must not prove threat absence")

local beforeCache = dbcCalls
Evidence:Inspect(1038, base.paladinClassification)
assert(dbcCalls == beforeCache,
    "immutable installed topology must be cached by spell identity")

dofile("Graph/PaladinBlessingThreat.lua")
local Graph = XelAssist.Graph.PaladinBlessingThreat
local playerGUID, otherGUID, thirdGUID, playerKey = {}, {}, {}, {}
local function aura(spellId, classification, caster)
    return { spellId = spellId, classification = classification,
        sourceGUID = caster, recipientGUID = playerGUID,
        recipientRelation = "self", exact = true }
end
local function state(blessings)
    local player = { available = true, guid = playerGUID,
        playerGUID = playerGUID, recipientRelation = "self",
        blessingsByCaster = blessings or {} }
    return { paladinAuraState = { available = true,
        player = player, playerKey = playerKey, playerGUID = playerGUID } }
end

local root = state({ [playerGUID] = aura(19740,
    ordinaryBase.paladinClassification, playerGUID) })
assert(Graph:Attach(root) and root.paladinBlessingThreat.exact
    and root.paladinBlessingThreat.multiplier == 1,
    "an exact ordinary active blessing must seal a neutral threat component")
local projection = { kind = "blessing", effect = effect,
    recipientKey = playerKey, recipientGUID = playerGUID }
local prepared, reason, handled = Graph:Prepare(root, projection)
assert(prepared == projection and reason == nil and handled
    and projection.paladinBlessingThreat.multiplier == 0.75,
    "self projection must transport only sealed numeric evidence")
local context = { state = root }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and not context.estimated
    and context.kind == "classMechanic"
    and context.reason == "changes all player threat",
    "the lifecycle edge must be neutral while descendants price threat")

local branch = {}
assert(Graph:Copy(root, branch)
    and branch.paladinBlessingThreat ~= root.paladinBlessingThreat
    and branch.paladinBlessingThreat.byCaster
        ~= root.paladinBlessingThreat.byCaster,
    "branch copies must isolate the mutable threat component")
branch.paladinAuraState = state({}).paladinAuraState
branch.paladinAuraState.player.blessingsByCaster[playerGUID] = aura(
    1038, base.paladinClassification, playerGUID)
local callsBeforeSearch = dbcCalls
GetSpellRecField = function()
    error("graph search must not reread DBC")
end
assert(Graph:Apply(branch, projection)
    and branch.paladinBlessingThreat.multiplier == 0.75
    and root.paladinBlessingThreat.multiplier == 1,
    "accepted lifecycle application must replace the branch-local component")
local multiplier, exact = Graph:Resolve(branch, "player", 1.3, true)
assert(math.abs(multiplier - 0.975) < 0.000001 and exact
    and Graph:Resolve(branch, "pet", 1.3, true) == 1.3
    and dbcCalls == callsBeforeSearch,
    "player threat must compose exactly while pet threat bypasses the blessing")

GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local value = records[spellId] and records[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
local external = state({
    [playerGUID] = aura(19740, ordinaryBase.paladinClassification, playerGUID),
    [otherGUID] = aura(25895, groupBase.paladinClassification, otherGUID),
})
assert(Graph:Attach(external)
    and external.paladinBlessingThreat.multiplier == 0.75,
    "an already-observed class-group aura may affect the exact player root")
prepared, reason, handled = Graph:Prepare(external, {
    kind = "blessing", effect = effect,
    recipientKey = playerKey, recipientGUID = playerGUID })
assert(prepared == nil and handled
    and reason == "all-threat blessing stacking is unresolved",
    "a second caster must block when stacking semantics are not proven")

local ambiguous = state({
    [otherGUID] = aura(1038, base.paladinClassification, otherGUID),
    [thirdGUID] = aura(25895, groupBase.paladinClassification, thirdGUID),
})
assert(not Graph:Attach(ambiguous)
    and not ambiguous.paladinBlessingThreat.exact
    and ambiguous.paladinBlessingThreat.activeCount == 2,
    "multiple observed modifiers must make the root component unavailable")

local allyProjection = { kind = "blessing", effect = effect,
    recipientKey = {}, recipientGUID = {} }
prepared, reason, handled = Graph:Prepare(root, allyProjection)
assert(prepared == nil and handled
    and reason == "all-threat blessing graph consequence requires self",
    "ally threat output must remain outside the player-action graph")

-- Shared production hooks must promote, score, apply, and compose the leaf;
-- testing only its direct methods would not protect TOC-level integration.
dofile("Game/ActionInference.lua")
local inferred, inferReason, inferHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(1038)
assert(inferred and inferHandled and inferReason == nil
    and inferred.paladinBlessingThreatEvidence
    and inferred.paladinDownstreamEffect.multiplier == 0.75,
    "class inference must promote the exact downstream consequence")

XelAssist.Graph.PaladinAuraProjection = {
    Attach = function(_, value)
        return value and value.paladinAuraState ~= nil
    end,
    Copy = function() return true end,
    Prepare = function(_, actionValue, value, descriptor)
        return { kind = "blessing", action = actionValue,
            recipientKey = descriptor.key, recipientGUID = descriptor.guid,
            casterGUID = value.paladinAuraState.playerGUID,
            effect = actionValue.facts.paladinDownstreamEffect }, nil, true
    end,
    Apply = function(_, value, projected)
        local player = value.paladinAuraState.player
        player.blessingsByCaster[playerGUID] = {
            spellId = projected.action.spellId, sourceGUID = playerGUID }
        return true
    end,
    Invalidate = function() end,
}
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassMechanics.lua")
local integration = state({ [playerGUID] = aura(19740,
    ordinaryBase.paladinClassification, playerGUID) })
assert(XelAssist.Graph.ClassMechanics:Attach(integration)
    and integration.paladinBlessingThreat.multiplier == 1,
    "root class attachment must include the blessing threat component")
local integratedAction = { spellId = 1038, actor = "player",
    facts = inferred }
local integratedDescriptor = { key = playerKey, guid = playerGUID,
    unit = "player", relation = "self" }
local integratedProjection, integratedReason, integratedHandled =
    XelAssist.Graph.ClassMechanics:Prepare(
        integratedAction, integration, integratedDescriptor)
assert(integratedProjection and integratedHandled
    and integratedReason == nil
    and integratedProjection.paladinBlessingThreat.multiplier == 0.75,
    "class preparation must retain the exact threat consequence")
local integratedContext = { state = integration }
assert(XelAssist.Graph.ClassMechanics:Score(
        integratedContext, integratedProjection)
    and integratedContext.value == 0,
    "class scoring must leave the setup neutral for descendant payoff")
local integrationApplied = XelAssist.Graph.ClassMechanics:Apply(
    integration, { classMechanicProjection = integratedProjection })
assert(integrationApplied
    and integration.paladinBlessingThreat.multiplier == 0.75,
    "class application must update lifecycle and threat atomically")
dofile("Graph/PlayerThreat.lua")
local integratedMultiplier, integratedExact =
    XelAssist.Graph.PlayerThreat:Resolve(integration, "player")
assert(integratedMultiplier == 0.75 and integratedExact,
    "player threat must compose the branch-local blessing multiplier")

print("ok: exact Paladin all-threat blessing consequence is search-pure")
