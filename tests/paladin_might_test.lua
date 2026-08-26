-- Blessing of Might must earn value only through later exact melee damage.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local ranks = {
    [19740] = { rank = 1, level = 4, cost = 20, base = 19,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19834] = { rank = 2, level = 12, cost = 30, base = 34,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19835] = { rank = 3, level = 22, cost = 45, base = 54,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19836] = { rank = 4, level = 32, cost = 60, base = 84,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19837] = { rank = 5, level = 42, cost = 85, base = 114,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [19838] = { rank = 6, level = 52, cost = 110, base = 154,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [25291] = { rank = 7, level = 60, maxLevel = 60, cost = 130, base = 184,
        durationIndex = 6, range = 4, target = 21, radius = 0, single = true },
    [25782] = { rank = 1, level = 52, cost = 220, base = 154,
        durationIndex = 30, range = 5, target = 61, radius = 12, greater = true },
    [25916] = { rank = 2, level = 60, maxLevel = 60, cost = 260, base = 184,
        durationIndex = 30, range = 5, target = 61, radius = 12, greater = true },
}

local function row(rank)
    return { school = 1, dispel = 1, attributes = 327680,
        castingTimeIndex = 1, maxLevel = rank.maxLevel or 0,
        baseLevel = rank.level, spellLevel = rank.level,
        durationIndex = rank.durationIndex, powerType = 0,
        manaCost = rank.cost, rangeIndex = rank.range,
        spellFamilyName = 10, spellFamilyFlags = 268435458,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        dmgClass = 1, preventionType = 1,
        effect = triple(6), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(rank.base), effectMechanic = triple(),
        effectImplicitTargetA = triple(rank.target),
        effectImplicitTargetB = triple(), effectRadiusIndex = triple(rank.radius),
        effectApplyAuraName = triple(99), effectAmplitude = triple(),
        effectMultipleValue = triple(), effectChainTarget = triple(),
        effectItemType = triple(), effectMiscValue = triple(),
        effectTriggerSpell = triple(), effectPointsPerComboPoint = triple() }
end

local records = {}
local spellId, rank
for spellId, rank in pairs(ranks) do records[spellId] = row(rank) end
records[50000] = { dmgClass = 2, attributesEx3 = 0,
    effect = triple(121) }

local reads, class, now = 0, "PALADIN", 1000
local modifiers = { [8] = { 0, 0, 0 }, [3] = { 0, 0, 0 } }
function UnitClass()
    reads = reads + 1
    return "localized class deliberately ignored", class
end
function GetSpellRecField(id, field, copied)
    reads = reads + 1
    local value = records[id] and records[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellModifiers(_, kind)
    reads = reads + 1
    local found = modifiers[kind]
    return found[1], found[2], found[3]
end
function GetSpellDuration(id)
    reads = reads + 1
    return ranks[id] and (ranks[id].greater and 900000 or 300000) or nil
end
function UnitAttackSpeed()
    reads = reads + 1
    return 2.5
end
function UnitDamage()
    reads = reads + 1
    return 40, 60, 0, 0, 0, 0, 1.1
end
function GetTime()
    reads = reads + 1
    return now
end

local function classification(id)
    return { exact = true, spellId = id, family = 10, flags = 268435458,
        kind = "blessing", exclusiveFamily = "paladinBlessingByCaster",
        recipientRelation = "friendly" }
end

local function blessingFacts(id)
    return { inferred = true, kind = "buff", kindExact = true,
        paladinAction = true, paladinAura = true, paladinBlessing = true,
        paladinEffectRepresented = false, paladinLifecycleRepresented = true,
        paladinClassification = classification(id),
        exclusiveFamily = "paladinBlessingByCaster" }
end

dofile("Game/Player/PaladinMight.lua")
local Runtime = XelAssist.Game.Player.PaladinMight

for spellId, rank in pairs(ranks) do
    local found, reason, handled = Runtime:Inspect(spellId, classification(spellId))
    assert(found and reason == nil and handled and found.valid and found.exact
        and found.baseAttackPower == rank.base + 1
        and found.actionRepresented == (rank.single and true or false),
        "every installed Might aura rank must retain its exact consequence")
end
local unknown, _, unknownHandled = Runtime:Inspect(99999, classification(99999))
assert(unknown == nil and not unknownHandled,
    "an unrelated numeric identity must stay outside the Might portfolio")

local promoted = Runtime:Promote(19740, blessingFacts(19740))
assert(promoted.paladinEffectRepresented
    and promoted.requiresExactPaladinMightProfile
    and promoted.paladinMightEvidence
    and promoted.preferred == nil and promoted.order == nil,
    "normal Might must expose consequence evidence without an action priority")
local greater = Runtime:Promote(25782, blessingFacts(25782))
assert(not greater.paladinEffectRepresented and not greater.paladinMightEvidence,
    "class-group Greater Might must remain action-unrepresented")

local action = { name = "localized name deliberately ignored", spellId = 19740,
    actor = "player", facts = promoted }
local captured = Runtime:CaptureFacts(action, promoted)
action.facts = captured
local profile = Runtime:Profile(captured)
assert(profile and profile.attackPower == 20 and profile.duration == 300
    and captured.paladinDownstreamEffect.attackPower == 20,
    "root capture must seal exact attack power and duration")

modifiers[8], modifiers[3] = { 5, 0, 1 }, { 0, 20, 1 }
local modified = Runtime:CaptureFacts(action, promoted)
assert(Runtime:Profile(modified).attackPower == 30,
    "ALL_EFFECTS then ATTACK_POWER modifiers must follow engine order")
modifiers[8], modifiers[3] = { 0, 0, 0 }, { 0, 0, 0 }

local weaponFacts = { kind = "damage", weaponCoefficient = 1.5,
    weaponNormalized = true,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" }
local weaponAction = { spellId = 50000, actor = "player", facts = weaponFacts }
weaponFacts = Runtime:CaptureFacts(weaponAction, weaponFacts)
assert(weaponFacts.paladinMainHandWeaponEvidence
    and weaponFacts.paladinMainHandWeaponEvidence.normalized,
    "exact Paladin main-hand weapon actions must be sealed at root")

local playerGUID = "Player-1"
local function stateWith(blessings)
    local player = { available = true, unit = "player", key = "self",
        guid = playerGUID, playerGUID = playerGUID, recipientRelation = "self",
        rootRelation = "self", blessingsByCaster = blessings or {} }
    local record = { unit = "player", guid = playerGUID, relation = "self" }
    return { friendlies = { byUnit = { player = "self" },
            byKey = { self = record } },
        paladinAuraState = { available = true, player = player,
            playerKey = "self", playerGUID = playerGUID,
            byKey = { self = player } } }, player
end

dofile("Graph/PaladinMight.lua")
local Graph = XelAssist.Graph.PaladinMight
local clean, cleanPlayer = stateWith()
assert(Graph:Attach(clean) and clean.paladinMight.deltaAttackPower == 0,
    "a complete inactive root must attach without inventing AP")
local projection = { kind = "blessing", classMechanic = "paladin",
    action = action, actionSpellId = 19740, recipientKey = "self",
    recipientGUID = playerGUID, casterGUID = playerGUID,
    effect = captured.paladinDownstreamEffect }
local prepared, reason, handled = Graph:Prepare(clean, projection, captured)
assert(prepared and handled and reason == nil
    and prepared.paladinMightTransition.toAttackPower == 20
    and prepared.paladinMightTransition.projectedDelta == 20,
    "Might must prepare an exact root-relative AP transition")

local saved = { GetSpellRecField, GetSpellModifiers, GetSpellDuration,
    UnitClass, UnitAttackSpeed, UnitDamage, GetTime }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitClass = function() error("class read during graph search") end
UnitAttackSpeed = function() error("speed read during graph search") end
UnitDamage = function() error("damage read during graph search") end
GetTime = function() error("clock read during graph search") end

local context = { state = clean }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.kind == "classMechanic",
    "the Might edge must have no fixed buff utility")
cleanPlayer.blessingsByCaster[playerGUID] = { spellId = 19740,
    sourceGUID = playerGUID, exact = true, classification = classification(19740) }
assert(Graph:Apply(clean, projection)
    and clean.paladinMight.deltaAttackPower == 20,
    "generic blessing application must commit the exact AP transition")
local white = Graph:MainHandWhiteBonus(clean)
assert(math.abs(white - 20 / 14 * 2.5 * 1.1) < 0.00001,
    "future white swings must receive current-speed Might damage")
local special = Graph:WeaponActionBonus(weaponAction, weaponFacts, clean,
    { exact = true, normalized = true, normalizedSpeed = 2.4,
        damagePercent = 1.2 })
assert(math.abs(special - 20 / 14 * 2.4 * 1.2 * 1.5) < 0.00001,
    "normalized weapon actions must receive exact Might damage")
local branch = {}
assert(Graph:Copy(clean, branch) and branch.paladinMight ~= clean.paladinMight,
    "graph branches must not share mutable Might lifecycle")

GetSpellRecField, GetSpellModifiers, GetSpellDuration, UnitClass,
    UnitAttackSpeed, UnitDamage, GetTime = saved[1], saved[2], saved[3],
    saved[4], saved[5], saved[6], saved[7]

local activeAura = { spellId = 19740, sourceGUID = playerGUID, exact = true,
    classification = classification(19740), duration = 300, expirationTime = 1300 }
local active, activePlayer = stateWith({ [playerGUID] = activeAura })
assert(Graph:Attach(active)
    and active.paladinMight.baselineAttackPower == 20
    and active.paladinMight.deltaAttackPower == 0,
    "live Might already included in UnitDamage must be neutral at root")
local rankTwoFacts = Runtime:Promote(19834, blessingFacts(19834))
local rankTwoAction = { spellId = 19834, actor = "player", facts = rankTwoFacts }
rankTwoFacts = Runtime:CaptureFacts(rankTwoAction, rankTwoFacts)
rankTwoAction.facts = rankTwoFacts
local rankTwoProjection = { kind = "blessing", classMechanic = "paladin",
    action = rankTwoAction, actionSpellId = 19834, recipientKey = "self",
    recipientGUID = playerGUID, casterGUID = playerGUID,
    effect = rankTwoFacts.paladinDownstreamEffect }
assert(Graph:Prepare(active, rankTwoProjection, rankTwoFacts)
    and rankTwoProjection.paladinMightTransition.projectedDelta == 15,
    "rank replacement must contribute only the delta over live Might")
activePlayer.blessingsByCaster[playerGUID] = { spellId = 19834,
    sourceGUID = playerGUID, exact = true, classification = classification(19834) }
assert(Graph:Apply(active, rankTwoProjection)
    and active.paladinMight.deltaAttackPower == 15,
    "higher-rank application must retain the root-relative delta")
assert(Graph:Advance(active, 300) == 0
    and active.paladinMight.deltaAttackPower == -20
    and activePlayer.blessingsByCaster[playerGUID] == nil,
    "expiry must remove both projected Might and its frozen-root AP")

local external = stateWith({ OtherPaladin = { spellId = 19740,
    sourceGUID = "OtherPaladin", exact = true,
    classification = classification(19740), duration = 300,
    expirationTime = 1300 } })
assert(not Graph:Attach(external)
    and external.paladinMightRoot.reason == "external Might stacking is unresolved",
    "external Might must fail closed instead of guessing stacking")

local other, otherPlayer = stateWith({ [playerGUID] = { spellId = 999,
    sourceGUID = playerGUID, exact = true, classification = classification(999) } })
assert(Graph:Attach(other))
local blocked, blockReason, blockHandled = Graph:Prepare(other,
    { kind = "blessing", actionSpellId = 19740, recipientKey = "self",
        recipientGUID = playerGUID, casterGUID = playerGUID }, captured)
assert(blocked == nil and blockHandled
    and blockReason == "displaced own blessing consequence is unresolved",
    "an unknown displaced blessing must prevent false Might value")

local removal, removalPlayer = stateWith({ [playerGUID] = activeAura })
assert(Graph:Attach(removal))
local salvationFacts = { paladinEffectRepresented = true }
local salvation = { kind = "blessing", actionSpellId = 1038,
    action = { spellId = 1038, actor = "player" },
    recipientKey = "self", recipientGUID = playerGUID, casterGUID = playerGUID,
    effect = { exact = true, kind = "playerThreatMultiplier" } }
assert(Graph:Prepare(removal, salvation, salvationFacts)
    and salvation.paladinMightTransition.mode == "remove",
    "another represented blessing must carry the lost-Might transition")
removalPlayer.blessingsByCaster[playerGUID] = { spellId = 1038,
    sourceGUID = playerGUID, exact = true, classification = classification(1038) }
assert(Graph:Apply(removal, salvation)
    and removal.paladinMight.currentAttackPower == 0
    and removal.paladinMight.deltaAttackPower == -20,
    "represented blessing replacement must remove Might damage")

Runtime:Invalidate()
records[19740].effectApplyAuraName = triple(0)
local drift, driftReason, driftHandled = Runtime:Inspect(
    19740, classification(19740))
assert(drift and not drift.valid and driftHandled
    and driftReason == "Might DBC topology is incomplete",
    "a drifted installed rank must fail closed")

print("paladin_might_test: ok")
