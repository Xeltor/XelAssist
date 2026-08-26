-- Seal of Righteousness Judgement must resolve only through the exact hidden
-- result link, with all mutable damage evidence sealed before graph search.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local ranks = {
    [21084] = { result = 20187, max = 7, base = 1, spell = 1,
        points = 14, sides = 1, perLevel = 1.8 },
    [20287] = { result = 20280, max = 16, base = 10, spell = 10,
        points = 24, sides = 3, perLevel = 1.9 },
    [20288] = { result = 20281, max = 24, base = 18, spell = 18,
        points = 38, sides = 5, perLevel = 2.4 },
    [20289] = { result = 20282, max = 32, base = 26, spell = 26,
        points = 56, sides = 7, perLevel = 2.8 },
    [20290] = { result = 20283, max = 40, base = 34, spell = 34,
        points = 77, sides = 9, perLevel = 3.1 },
    [20291] = { result = 20284, max = 48, base = 42, spell = 42,
        points = 101, sides = 11, perLevel = 3.8 },
    [20292] = { result = 20285, max = 56, base = 50, spell = 50,
        points = 130, sides = 13, perLevel = 4.1 },
    [20293] = { result = 20286, max = 64, base = 58, spell = 58,
        points = 161, sides = 17, perLevel = 4.1 },
}

local rows = {
    [20271] = { school = 1, attributes = 327680, attributesEx2 = 1048576,
        attributesEx3 = 512, baseLevel = 4, spellLevel = 4,
        rangeIndex = 7, recoveryTime = 10000, spellFamilyName = 10,
        spellFamilyFlags = 8388608, dmgClass = 0,
        effect = triple(77), effectBasePoints = triple(-1),
        effectImplicitTargetA = triple(6) },
}

local sourceId, rank
for sourceId, rank in pairs(ranks) do
    rows[sourceId] = { school = 1, spellIconID = 25,
        spellFamilyName = 10, spellFamilyFlags = 68853694464,
        dmgClass = 1, effect = triple(6, 0, 6),
        effectBaseDice = triple(1, 0, 1),
        effectBasePoints = triple(0, 0, rank.result - 1),
        effectImplicitTargetA = triple(1, 0, 1),
        effectApplyAuraName = triple(42, 0, 4) }
    rows[rank.result] = { school = 1, attributes = 2097152,
        attributesEx3 = 262656, maxLevel = rank.max,
        baseLevel = rank.base, spellLevel = rank.spell, rangeIndex = 6,
        equippedItemClass = -1, spellIconID = 25, spellFamilyName = 10,
        spellFamilyFlags = 1024, dmgClass = 2,
        effect = triple(2, 0, 3), effectDieSides = triple(rank.sides, 0, 1),
        effectBaseDice = triple(1, 0, 1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(rank.perLevel),
        effectBasePoints = triple(rank.points),
        effectImplicitTargetA = triple(6) }
end

local reads = 0
function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    local value = rows[spellId] and rows[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

local modifiers = { [8] = { 0, 0, 0 }, [0] = { 0, 0, 0 },
    [24] = { 0, 0, 0 } }
function GetSpellModifiers(_, operation)
    reads = reads + 1
    local found = modifiers[operation]
    return found[1], found[2], found[3]
end
function GetSpellPower()
    reads = reads + 1
    return 0, 0, 0, 0, 0, 0, 0
end
function UnitDamage()
    reads = reads + 1
    return 10, 20, 0, 0, 0, 0, 1
end

local classification = { exact = true, spellId = 20271, family = 10,
    flags = 8388608, kind = "judgement", recipientRelation = "hostile" }
local baseFacts = { inferred = true, kind = "judgement", kindExact = true,
    paladinAction = true, paladinJudgement = true,
    paladinEffectRepresented = false,
    requiresExactPaladinDownstreamOutcome = true,
    paladinClassification = classification }

dofile("Game/Player/PaladinRighteousness.lua")
local Runtime = XelAssist.Game.Player.PaladinRighteousness

local installed, reason, handled = Runtime:Inspect(20271)
assert(installed and installed.valid and installed.exact and handled
    and reason == nil and installed.ranks[20287].resultSpellId == 20280,
    "the exact installed Judgement and seal-result map must be retained")
for sourceId, rank in pairs(ranks) do
    local found, rankReason, rankHandled = Runtime:Inspect(sourceId)
    assert(found and rankHandled and rankReason == nil
        and found.resultSpellId == rank.result,
        "every installed normal Righteousness rank must retain its link")
end
local unknown, _, unknownHandled = Runtime:Inspect(20154)
assert(unknown == nil and not unknownHandled,
    "the unlinked player-create seal must stay outside the portfolio")

local promoted = Runtime:Promote(20271, baseFacts)
assert(promoted.paladinRighteousness
    and promoted.requiresExactPaladinRighteousnessOutcome
    and not promoted.paladinEffectRepresented
    and promoted.preferred == nil and promoted.order == nil,
    "Judgement discovery must add mechanics without an action priority")
assert(Runtime:Promote(99999, baseFacts) == baseFacts,
    "unrelated identities must not be claimed")

local playerGUID, targetGUID = "Player-1", "Creature-1"
local function state(activeSpellId, healthExact)
    local player = { available = true, unit = "player", key = "self",
        guid = playerGUID, playerGUID = playerGUID, recipientRelation = "self",
        rootRelation = "self", blessingsByCaster = {},
        activeSeal = activeSpellId and { spellId = activeSpellId,
            sourceGUID = playerGUID, recipientGUID = playerGUID,
            recipientRelation = "self", exact = true } or nil }
    local hostile = { key = "enemy", unit = "target", guid = targetGUID,
        relation = "hostile", health = 100, healthExact = healthExact ~= false,
        threat = {}, projectedThreat = {} }
    return { playerLevel = 16, activeHostileKey = "enemy",
        friendlies = { byKey = { self = { unit = "player",
            guid = playerGUID, relation = "self" } } },
        hostiles = { byKey = { enemy = hostile }, order = { "enemy" } },
        paladinAuraState = { available = true, player = player,
            playerKey = "self", playerGUID = playerGUID,
            byKey = { self = player } } }, player, hostile
end

local root = state(20287)
local action = { name = "localized text deliberately ignored",
    spellId = 20271, actor = "player", facts = promoted }
action.facts = Runtime:CaptureFacts(action, promoted, root)
local profile = Runtime:Profile(action, 20287)
assert(profile and math.abs(profile.meanDamage - 37.4) < 0.00001
    and profile.resultSpellId == 20280
    and action.facts.paladinEffectRepresented,
    "root capture must seal the level-scaled hidden result mean")

modifiers[8], modifiers[0] = { 5, 0, 1 }, { 0, 10, 1 }
local modified = Runtime:CaptureFacts(action, promoted, root)
assert(math.abs(Runtime:Profile(modified, 20287).meanDamage - 46.64) < 0.00001,
    "ALL_EFFECTS then DAMAGE modifiers must follow server order")
modifiers[8], modifiers[0] = { 0, 0, 0 }, { 0, 0, 0 }

local savedPower = GetSpellPower
GetSpellPower = function() return 0, 5, 0, 0, 0, 0, 0 end
local withheld = Runtime:CaptureFacts(action, promoted, root)
assert(not withheld.paladinEffectRepresented
    and withheld.paladinRighteousnessProfiles == nil,
    "unmodeled spell-power contribution must fail closed")
GetSpellPower = savedPower

local savedFlag = rows[20287].spellFamilyFlags
rows[20287].spellFamilyFlags = 134217728
Runtime:Invalidate()
local drifted = Runtime:Inspect(20271)
assert(drifted and not drifted.valid,
    "dropping the exact upper family word must invalidate the rank map")
rows[20287].spellFamilyFlags = savedFlag
Runtime:Invalidate()
assert(Runtime:Inspect(20271).valid, "restored installed evidence must validate")

-- Re-capture after invalidation so all sealed profiles originate at the final
-- root boundary before live APIs become forbidden.
action.facts = Runtime:CaptureFacts(action, promoted, root)

dofile("Game/Player/PaladinAuraState.lua")
dofile("Graph/PaladinAuraProjection.lua")
dofile("Graph/PaladinRighteousness.lua")
local Paladin = XelAssist.Graph.PaladinAuraProjection
local Graph = XelAssist.Graph.PaladinRighteousness
local descriptor = { key = "enemy", unit = "target", guid = targetGUID,
    relation = "hostile", exact = true,
    record = root.hostiles.byKey.enemy }
local outcome, outcomeReason, outcomeHandled = Graph:Outcome(
    action, root, descriptor, action.facts)
assert(outcome and outcomeHandled and outcomeReason == nil
    and outcome.sourceSealSpellId == 20287
    and outcome.effect.resultSpellId == 20280,
    "the active seal and selected hostile must produce an exact outcome")
local projection, projectionReason = Paladin:Prepare(
    action, root, descriptor, outcome)
assert(projection and projectionReason == nil,
    "generic Paladin lifecycle must admit the exact outcome")
projection = assert(Graph:Prepare(root, projection, action.facts))
projection.classMechanic = "paladin"

local saved = { GetSpellRecField, GetSpellModifiers, GetSpellPower, UnitDamage }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetSpellPower = function() error("spell power read during graph search") end
UnitDamage = function() error("damage lane read during graph search") end

local context = { action = action, state = root, descriptor = descriptor,
    tooltip = action.facts }
assert(Graph:Score(context, projection)
    and context.kind == "damage" and context.power == 37.4
    and context.effectAction.spellId == 20280
    and context.effectAction.resistanceMetadata.alwaysHit == true
    and context.effectAction.resistanceMetadata.usesWeaponSkill == false
    and context.classMechanicOwnsKindScore == nil
    and context.value == 0,
    "the hidden result must enter generic resistance/damage scoring purely")

XelAssist.Graph.State = {
    ActiveHostile = function(_, value)
        return value.hostiles.byKey[value.activeHostileKey]
    end,
}
XelAssist.Graph.HostileEffects = {
    ApplySelectedDamage = function(_, value, amount)
        local record = value.hostiles.byKey[value.activeHostileKey]
        if not record.healthExact then return false, nil end
        local before = record.health
        record.health = math.max(0, record.health - amount)
        return true, before - record.health
    end,
}
XelAssist.Graph.PlayerThreat = {
    AddScaled = function(_, record, actor, amount, exact)
        record.projectedThreat[actor] =
            (record.projectedThreat[actor] or 0) + amount
        record.threatExact = exact
    end,
}

assert(Paladin:Apply(root, projection)
    and root.paladinAuraState.player.activeSeal == nil
    and root.paladinAuraState.player.lastJudgement.downstreamPending,
    "generic lifecycle must consume the exact active seal first")
local candidate = { action = action, classMechanicProjection = projection,
    targetGUID = targetGUID, power = 30, threat = 25,
    playerThreatExact = true }
assert(Graph:Apply(root, candidate)
    and root.hostiles.byKey.enemy.health == 70
    and root.hostiles.byKey.enemy.projectedThreat.player == 25
    and root.paladinAuraState.player.lastJudgement.downstreamPending == false,
    "the linked damage and scaled threat must commit exactly once")
assert(not Graph:Apply(root, candidate)
    and root.hostiles.byKey.enemy.health == 70
    and root.hostiles.byKey.enemy.projectedThreat.player == 25,
    "a consumed downstream result must not apply twice")

local uncertain, uncertainPlayer, uncertainHostile = state(20287, false)
local uncertainDescriptor = { key = "enemy", unit = "target",
    guid = targetGUID, relation = "hostile", exact = true,
    record = uncertainHostile }
local uncertainOutcome = assert(Graph:Outcome(
    action, uncertain, uncertainDescriptor, action.facts))
local uncertainProjection = assert(Paladin:Prepare(
    action, uncertain, uncertainDescriptor, uncertainOutcome))
uncertainProjection = assert(Graph:Prepare(
    uncertain, uncertainProjection, action.facts))
uncertainProjection.classMechanic = "paladin"
assert(Paladin:Apply(uncertain, uncertainProjection))
local uncertainCandidate = { action = action,
    classMechanicProjection = uncertainProjection, targetGUID = targetGUID,
    power = 30, threat = 25, playerThreatExact = true }
assert(Graph:Apply(uncertain, uncertainCandidate)
    and uncertainHostile.health == 100
    and uncertainHostile.projectedThreat.player == 25
    and uncertainHostile.projectedThreatTimingUnknown,
    "inexact health must retain one expected threat packet without fake health")

local unsupported = state(20154)
local unsupportedDescriptor = { key = "enemy", unit = "target",
    guid = targetGUID, relation = "hostile", exact = true,
    record = unsupported.hostiles.byKey.enemy }
local noOutcome, noReason, noHandled = Graph:Outcome(
    action, unsupported, unsupportedDescriptor, action.facts)
assert(noOutcome == nil and noHandled and noReason,
    "an unlinked seal must fail closed instead of inventing Judgement damage")

GetSpellRecField, GetSpellModifiers, GetSpellPower, UnitDamage =
    saved[1], saved[2], saved[3], saved[4]

-- Exercise the production discovery, capture, class dispatch, scoring, and
-- application route rather than accepting only direct leaf composition.
UnitClass = function() return "Paladin", "PALADIN" end
dofile("Game/Player/PaladinActions.lua")
dofile("Game/ActionInference.lua")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassMechanics.lua")
local Inference = XelAssist.Game.ActionInference
local Mechanics = XelAssist.Graph.ClassMechanics
local integratedFacts, integrationReason, integrationHandled =
    Inference:ClassKnowledge(20271)
assert(integratedFacts and integrationHandled and integrationReason == nil
    and integratedFacts.paladinRighteousness,
    "production action discovery must promote exact Judgement")
local integratedRoot = state(20287)
local integratedAction = { name = "integrated judgement", spellId = 20271,
    actor = "player", facts = integratedFacts }
integratedAction.facts = Mechanics:CaptureFacts(
    integratedAction, integratedFacts, integratedRoot)
local integratedDescriptor = { key = "enemy", unit = "target",
    guid = targetGUID, relation = "hostile", exact = true,
    record = integratedRoot.hostiles.byKey.enemy }

GetSpellRecField = function() error("DBC read during production graph search") end
GetSpellModifiers = function() error("modifier read during production graph search") end
GetSpellPower = function() error("power read during production graph search") end
UnitDamage = function() error("damage read during production graph search") end
local integratedProjection = assert(Mechanics:Prepare(
    integratedAction, integratedRoot, integratedDescriptor,
    integratedAction.facts, 0))
local integratedContext = { action = integratedAction,
    state = integratedRoot, descriptor = integratedDescriptor,
    tooltip = integratedAction.facts }
assert(Mechanics:Score(integratedContext, integratedProjection)
    and integratedContext.kind == "damage"
    and integratedContext.effectAction.spellId == 20280,
    "production class dispatch must expose the hidden result to scoring")
local integratedCandidate = { action = integratedAction,
    classMechanicProjection = integratedProjection, targetGUID = targetGUID,
    power = 30, threat = 25, playerThreatExact = true }
assert(Mechanics:Apply(integratedRoot, integratedCandidate)
    and integratedRoot.paladinAuraState.player.activeSeal == nil
    and integratedRoot.hostiles.byKey.enemy.health == 70,
    "production class dispatch must consume the seal and apply damage once")

GetSpellRecField, GetSpellModifiers, GetSpellPower, UnitDamage =
    saved[1], saved[2], saved[3], saved[4]
print("paladin righteousness tests: ok")
