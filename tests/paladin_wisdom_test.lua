-- Blessing of Wisdom must earn value only through exact future self mana.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local ranks = {
    [19742] = { level = 14, cost = 30, amount = 10 },
    [19850] = { level = 24, cost = 45, amount = 15 },
    [19852] = { level = 34, cost = 65, amount = 20 },
    [19853] = { level = 44, cost = 90, amount = 25 },
    [19854] = { level = 54, cost = 115, amount = 30 },
    [25290] = { level = 60, cost = 125, amount = 33 },
}

local function row(rank)
    return { spellLevel = rank.level, baseLevel = rank.level, maxLevel = 0,
        manaCost = rank.cost, school = 1, dispel = 1, attributes = 327680,
        attributesEx = 1024, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, castingTimeIndex = 1, recoveryTime = 0,
        categoryRecoveryTime = 0, durationIndex = 6, powerType = 0,
        manaCostPercentage = 0, rangeIndex = 4, speed = 0,
        spellFamilyName = 10, spellFamilyFlags = 268500992,
        maxAffectedTargets = 0, dmgClass = 1, preventionType = 1,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        effect = triple(6), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(rank.amount - 1), effectMechanic = triple(),
        effectImplicitTargetA = triple(21), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(), effectApplyAuraName = triple(24),
        effectAmplitude = triple(5000), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectItemType = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
        effectPointsPerComboPoint = triple() }
end

local records = {}
local spellId, rank
for spellId, rank in pairs(ranks) do records[spellId] = row(rank) end
records[25894] = { spellFamilyName = 10,
    spellFamilyFlags = 268500992 }
records[99999] = { spellFamilyName = 5, spellFamilyFlags = 0 }

local reads, now = 0, 1000
local modifiers = { [8] = { 0, 0, 0 }, [19] = { 0, 0, 0 } }
function UnitClass()
    reads = reads + 1
    return "localized class deliberately ignored", "PALADIN"
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
function GetSpellDuration()
    reads = reads + 1
    return 600000
end
function GetTime()
    reads = reads + 1
    return now
end

local function classification(id)
    return { exact = true, spellId = id, family = 10, flags = 268500992,
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

dofile("Game/Player/PaladinWisdom.lua")
local Runtime = XelAssist.Game.Player.PaladinWisdom

for spellId, rank in pairs(ranks) do
    local found, reason, handled = Runtime:Inspect(
        spellId, classification(spellId))
    assert(found and reason == nil and handled and found.valid and found.exact
        and found.level == rank.level and found.baseCost == rank.cost
        and found.baseAmount == rank.amount and found.basePeriod == 5,
        "every installed single-target Wisdom rank must bind exact evidence")
end
local unknown, _, unknownHandled = Runtime:Inspect(
    99999, classification(99999))
assert(unknown == nil and not unknownHandled,
    "an unrelated spell must stay outside the Wisdom portfolio")

local promoted = Runtime:Promote(19742, blessingFacts(19742))
assert(promoted.paladinWisdom and promoted.paladinEffectRepresented
    and promoted.requiresExactPaladinWisdomProfile
    and promoted.paladinDownstreamEffect.zeroThreat
    and promoted.preferred == nil and promoted.order == nil,
    "Wisdom must expose exact periodic mana without action priority")
local greater = Runtime:Promote(25894, blessingFacts(25894))
assert(not greater.paladinEffectRepresented
    and not greater.paladinWisdomEvidence,
    "class-group Greater Wisdom must remain action-unrepresented")

local action = { name = "localized name deliberately ignored",
    spellId = 19742, actor = "player", facts = promoted }
local captured = Runtime:CaptureFacts(action, promoted)
action.facts = captured
local profile = Runtime:Profile(captured)
assert(profile and profile.amount == 10 and profile.period == 5
    and profile.duration == 600 and profile.zeroThreat,
    "root capture must seal exact mana amount, phase and zero threat")

modifiers[8] = { 1, 0, 1 }
local modified = Runtime:CaptureFacts(action, promoted)
assert(Runtime:Profile(modified).amount == 11,
    "the server all-effects modifier must change the sealed tick amount")
modifiers[8] = { 0, 0, 0 }

local playerGUID = "Player-1"
local function stateWith(blessings)
    local record = { unit = "player", guid = playerGUID, relation = "self",
        resource = 0 }
    local player = { available = true, unit = "player", key = "self",
        guid = playerGUID, playerGUID = playerGUID,
        recipientRelation = "self", rootRelation = "self",
        blessingsByCaster = blessings or {} }
    return { time = 0, resource = 0, resourceMax = 100,
        resourceType = 0, playerResourceReserved = 0,
        playerResourceExact = true, actors = { player = { resource = 0 } },
        friendlies = { player = record, byUnit = { player = "self" },
            byKey = { self = record } },
        paladinAuraState = { available = true, player = player,
            playerKey = "self", playerGUID = playerGUID,
            byKey = { self = player } } }, player, record
end

dofile("Graph/PaladinWisdom.lua")
local Graph = XelAssist.Graph.PaladinWisdom
local clean, cleanPlayer, cleanRecord = stateWith()
assert(Graph:Attach(clean) and clean.paladinWisdom.activeSpellId == nil,
    "a complete inactive root must attach without inventing mana")
local projection = { kind = "blessing", classMechanic = "paladin",
    action = action, actionSpellId = 19742, recipientKey = "self",
    recipientGUID = playerGUID, casterGUID = playerGUID,
    effect = captured.paladinDownstreamEffect }
local prepared, reason, handled = Graph:Prepare(clean, projection, captured)
assert(prepared and handled and reason == nil
    and prepared.paladinWisdomTransition.amount == 10
    and prepared.paladinWisdomTransition.zeroThreat,
    "self Wisdom must prepare an exact zero-threat mana transition")

local saved = { GetSpellRecField, GetSpellModifiers, GetSpellDuration,
    UnitClass, GetTime }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitClass = function() error("class read during graph search") end
GetTime = function() error("clock read during graph search") end

local context = { state = clean }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.kind == "classMechanic",
    "Wisdom itself must have no fixed buff score")
cleanPlayer.blessingsByCaster[playerGUID] = { spellId = 19742,
    sourceGUID = playerGUID, exact = true,
    classification = classification(19742) }
assert(Graph:Apply(clean, projection)
    and clean.paladinWisdom.remaining == 600
    and clean.paladinWisdom.nextIn == 5,
    "application must start the exact five-second mana lifecycle")
assert(Graph:Advance(clean, 4.9) == 0 and clean.resource == 0
    and Graph:Advance(clean, 0.1) == 10 and clean.resource == 10
    and clean.actors.player.resource == 10 and cleanRecord.resource == 10,
    "the first energize must occur after five seconds and sync player state")

local value, available = Graph:ResourceAt(clean, 10)
local earliest, exact = Graph:Earliest(clean, 30, 0)
assert(available and value == 30 and exact and math.abs(earliest - 10) < 0.001,
    "future action admission must include exact Wisdom ticks")
clean.playerResourceClock = { verified = true, phaseKnown = true,
    externalEnergizeExcluded = true, resourceType = 0,
    amount = 5, interval = 2, nextIn = 2 }
earliest = Graph:Earliest(clean, 30, 0)
assert(math.abs(earliest - 5) < 0.001,
    "base mana and Wisdom clocks must compose without double counting")
local branch = stateWith({ [playerGUID] = { spellId = 19742,
    sourceGUID = playerGUID, exact = true,
    classification = classification(19742) } })
assert(Graph:Copy(clean, branch)
    and branch.paladinWisdom ~= clean.paladinWisdom,
    "graph branches must isolate the mutable Wisdom lifecycle")

clean.resource, clean.actors.player.resource, cleanRecord.resource = 95, 95, 95
clean.paladinWisdom.remaining, clean.paladinWisdom.nextIn = 5, 5
assert(Graph:Advance(clean, 5) == 5 and clean.resource == 100
    and clean.paladinWisdom.activeSpellId == nil
    and cleanPlayer.blessingsByCaster[playerGUID] == nil
    and clean.playerResourceClock.phaseKnown == false,
    "the final tick must cap mana, expire the aura, and close lost base phase")

GetSpellRecField, GetSpellModifiers, GetSpellDuration, UnitClass, GetTime =
    saved[1], saved[2], saved[3], saved[4], saved[5]

local activeAura = { spellId = 19742, sourceGUID = playerGUID, exact = true,
    classification = classification(19742), duration = 600,
    expirationTime = 1600 }
local active, activePlayer = stateWith({ [playerGUID] = activeAura })
assert(Graph:Attach(active) and active.paladinWisdom.activeSpellId == 19742
    and active.paladinWisdom.nextIn == 5,
    "an active exact self aura must recover its tick phase from expiration")
local replacement = { kind = "blessing", actionSpellId = 19740,
    action = { spellId = 19740, actor = "player" }, recipientKey = "self",
    recipientGUID = playerGUID, casterGUID = playerGUID,
    replacedSpellId = 19742 }
assert(Graph:Prepare(active, replacement, { paladinEffectRepresented = true })
    and replacement.paladinWisdomTransition.mode == "remove",
    "a represented own blessing must carry the lost-Wisdom transition")
activePlayer.blessingsByCaster[playerGUID] = { spellId = 19740,
    sourceGUID = playerGUID, exact = true, classification = classification(19740) }
assert(Graph:Apply(active, replacement)
    and active.paladinWisdom.activeSpellId == nil
    and active.paladinWisdom.ownOtherBlessingSpellId == 19740,
    "replacing Wisdom must remove its future mana")

local other = stateWith({ [playerGUID] = { spellId = 19740,
    sourceGUID = playerGUID, exact = true,
    classification = classification(19740) } })
assert(Graph:Attach(other))
local blocked, blockReason, blockHandled = Graph:Prepare(other,
    { kind = "blessing", actionSpellId = 19742, recipientKey = "self",
        recipientGUID = playerGUID, casterGUID = playerGUID }, captured)
assert(blocked == nil and blockHandled
    and blockReason == "displaced own blessing consequence is unresolved",
    "an unresolved displaced blessing must block invented Wisdom value")

local external = stateWith({ OtherPaladin = { spellId = 19742,
    sourceGUID = "OtherPaladin", exact = true,
    classification = classification(19742), duration = 600,
    expirationTime = 1600 } })
assert(not Graph:Attach(external)
    and external.paladinWisdom.reason == "external Wisdom stacking is unresolved",
    "external Wisdom stacking must fail closed")

Runtime:Invalidate()
records[19742].effectAmplitude = triple(4999)
local drift, driftReason, driftHandled = Runtime:Inspect(
    19742, classification(19742))
assert(drift == nil and driftHandled
    and driftReason == "Wisdom DBC topology is incomplete",
    "a drifted installed rank must fail closed")

assert(reads > 0, "the root evidence test must exercise mutable APIs")
print("paladin_wisdom_test: ok")
