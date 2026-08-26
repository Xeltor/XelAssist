-- Righteous Fury is projected only through exact Holy-school threat. The
-- focused test removes every live API after root capture to prove search purity.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local row = {
    school = 1, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327680, attributesEx = 0, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
    auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
    procChance = 101, procCharges = 0, maxLevel = 0, baseLevel = 16,
    spellLevel = 16, durationIndex = 21, powerType = 0, manaCost = 0,
    manaCostPerlevel = 0, manaPerSecond = 0, manaPerSecondPerLevel = 0,
    rangeIndex = 1, speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = -1, equippedItemSubClassMask = -1,
    equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    maxTargetLevel = 0, spellFamilyName = 10, spellFamilyFlags = 1,
    maxAffectedTargets = 0, dmgClass = 0, preventionType = 0,
    effect = triple(6), effectDieSides = triple(1),
    effectBaseDice = triple(1), effectDicePerLevel = triple(),
    effectRealPointsPerLevel = triple(), effectBasePoints = triple(59),
    effectMechanic = triple(), effectImplicitTargetA = triple(1),
    effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
    effectApplyAuraName = triple(10), effectAmplitude = triple(),
    effectMultipleValue = triple(), effectChainTarget = triple(),
    effectItemType = triple(), effectMiscValue = triple(2),
    effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
}

local class, reads = "PALADIN", 0
local modifierFlat, modifierPercent, modifierChanged = 0, 0, 0
function UnitClass()
    reads = reads + 1
    return "localized class deliberately ignored", class
end
function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    if spellId ~= 25780 then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellModifiers(spellId, kind)
    reads = reads + 1
    assert(spellId == 25780 and kind == 8)
    return modifierFlat, modifierPercent, modifierChanged
end

dofile("Game/Player/PaladinAuraState.lua")
dofile("Game/Player/PaladinActions.lua")
dofile("Game/Player/PaladinRighteousFury.lua")
local Actions = XelAssist.Game.Player.PaladinActions
local Runtime = XelAssist.Game.Player.PaladinRighteousFury

local facts, reason, handled = Actions:InferKnowledge(25780)
assert(facts and handled and reason == nil and facts.paladinRighteousFury
    and not facts.paladinEffectRepresented,
    "the family adapter must retain its fail-closed lifecycle baseline")
facts = Runtime:Promote(25780, facts)
assert(facts.paladinEffectRepresented and facts.paladinLifecycleRepresented
    and facts.paladinRepresentation == "exactSchoolThreatAura"
    and facts.paladinRighteousFuryEvidence.valid
    and facts.preferred == nil and facts.order == nil,
    "exact DBC topology must promote mechanics without a typed priority")

local action = { name = "localized action deliberately ignored",
    spellId = 25780, actor = "player", facts = facts }
facts = Runtime:CaptureFacts(action, facts)
action.facts = facts
local effect = Runtime:CapturedEffect(action)
assert(effect and effect.exact and effect.kind == "schoolThreatMultiplier"
    and effect.school == 1 and effect.schoolMask == 2
    and effect.percent == 60 and effect.multiplier == 1.6,
    "unmodified installed evidence must expose the exact Holy multiplier")

modifierFlat, modifierChanged = 30, 1
local modified = Runtime:CaptureFacts(action, Runtime:Promote(25780,
    Actions:InferKnowledge(25780)))
local modifiedEffect = Runtime:CapturedEffect(modified)
assert(modifiedEffect and modifiedEffect.percent == 90
    and modifiedEffect.multiplier == 1.9,
    "root-captured ALL_EFFECTS modifiers must change the aura magnitude")
modifierFlat, modifierChanged = 0, 0

class = "ROGUE"
local foreign = Runtime:Snapshot()
assert(not foreign.valid and not foreign.exact,
    "another class must not acquire the Paladin threat profile")
class = "PALADIN"

local function state(active)
    local record = { unit = "player", guid = "Player-1", relation = "self" }
    local snapshot = { available = true, unit = "player", key = "self-key",
        guid = "Player-1", playerGUID = "Player-1",
        recipientRelation = "self", blessingsByCaster = {} }
    if active then
        snapshot.righteousFury = { spellId = 25780, sourceGUID = "Player-1",
            recipientGUID = "Player-1", recipientRelation = "self", exact = true,
            classification = facts.paladinClassification }
    end
    local out = { friendlies = { byUnit = { player = "self-key" },
        byKey = { ["self-key"] = record } } }
    out.paladinAuraState = { available = true, playerKey = "self-key",
        playerGUID = "Player-1", player = snapshot,
        byKey = { ["self-key"] = snapshot } }
    return out, record
end

dofile("Graph/PaladinRighteousFury.lua")
local Graph = XelAssist.Graph.PaladinRighteousFury
local clean, selfRecord = state(false)
assert(Graph:Attach(clean) and clean.paladinRighteousFury.exact
    and not clean.paladinRighteousFury.active
    and clean.paladinRighteousFury.multiplier == 1,
    "an exact inactive root must attach the neutral branch component")
local live = state(true)
assert(Graph:Attach(live) and live.paladinRighteousFury.active
    and live.paladinRighteousFury.multiplier == 1.6,
    "the exact active self aura must attach its Holy threat multiplier")

local descriptor = { unit = "player", relation = "self", key = "self-key",
    guid = "Player-1" }
local projection, projectionReason, projectionHandled = Graph:Prepare(
    action, clean, descriptor, effect)
assert(projection and projectionHandled and projectionReason == nil
    and projection.kind == "righteousFury"
    and projection.effect.multiplier == 1.6,
    "the inactive exact self branch must prepare the consequence")
assert(Graph:Blocker(action, live, descriptor, effect)
        == "Righteous Fury is already active",
    "a live exact aura must suppress duplicate recommendations")

local saved = { GetSpellRecField, GetSpellModifiers, UnitClass }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
UnitClass = function() error("class read during graph search") end

local context = { action = action, state = clean }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.expectedPower == 0
    and context.kind == "classMechanic"
    and context.reason == "changes projected Holy threat",
    "Righteous Fury must have no fixed or role-typed edge value")
local candidate = { action = action,
    classMechanicProjection = projection }
assert(Graph:Apply(clean, candidate)
    and clean.paladinRighteousFury.active
    and clean.paladinAuraState.player.righteousFury.projected,
    "the branch apply must synchronize lifecycle and consequence")

local multiplier, exact = Graph:Resolve(clean, "player", 1, 1, true)
assert(multiplier == 1.6 and exact,
    "Holy player threat must receive the exact multiplier")
multiplier, exact = Graph:Resolve(clean, "player", 0, 1, true)
assert(multiplier == 1 and exact,
    "physical player threat must remain unchanged")
multiplier, exact = Graph:Resolve(clean, "pet", 1, 1, true)
assert(multiplier == 1 and exact,
    "pet threat must bypass the player-owned aura")
multiplier, exact = Graph:Resolve(clean, "player", nil, 1, true)
assert(multiplier == 1 and not exact,
    "unknown-school player threat must fail closed")

local branch = {}
assert(Graph:Copy(clean, branch) and branch.paladinRighteousFury.active
    and branch.paladinRighteousFury ~= clean.paladinRighteousFury,
    "graph branches must not share mutable Righteous Fury lifecycle")

dofile("Graph/PlayerThreat.lua")
local composed, composedExact = XelAssist.Graph.PlayerThreat:Resolve(
    clean, "player", 1)
assert(composed == 1.6 and composedExact,
    "production player threat must compose exact Holy Righteous Fury")
composed, composedExact = XelAssist.Graph.PlayerThreat:Resolve(
    clean, "player", 0)
assert(composed == 1 and composedExact,
    "production player threat must leave physical packets unchanged")
composed, composedExact = XelAssist.Graph.PlayerThreat:Resolve(
    clean, "player", nil)
assert(composed == 1 and not composedExact,
    "production player threat must fail closed for an unknown school")

GetSpellRecField, GetSpellModifiers, UnitClass = saved[1], saved[2], saved[3]
Runtime:Invalidate()
row.effectMiscValue = triple(127)
local drift = Runtime:Inspect(facts.paladinClassification)
assert(not drift.valid and not drift.exact
    and drift.reason == "Righteous Fury DBC topology is incomplete",
    "an all-school or otherwise drifted row must fail closed")

print("paladin_righteous_fury_test: ok")
