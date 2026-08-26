XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function presenceRecord()
    return { school = 0, category = 1151, dispel = 1,
        attributes = 33882112, castingTimeIndex = 1,
        categoryRecoveryTime = 180000, interruptFlags = 12,
        procFlags = 87376, procChance = 100, procCharges = 1,
        durationIndex = 21, powerType = 0, manaCost = 0, rangeIndex = 1,
        spellFamilyName = 3, spellFamilyFlags = 17179869184,
        maxAffectedTargets = 0,
        effect = triple(6, 6), effectBasePoints = triple(-101, -1),
        effectImplicitTargetA = triple(1, 1),
        effectImplicitTargetB = triple(),
        effectApplyAuraName = triple(108, 108),
        effectItemType = triple(1073741824, 1073741824),
        effectMiscValue = triple(10), effectTriggerSpell = triple() }
end

local function castRecord(family, flags, castIndex, attributesEx3)
    return { spellFamilyName = family, spellFamilyFlags = flags,
        castingTimeIndex = castIndex, attributes = 65536,
        attributesEx3 = attributesEx3 or 0 }
end

local records = {
    [12043] = presenceRecord(),
    [133] = castRecord(3, 1073741825, 16),
    [11366] = castRecord(3, 1077936128, 171),
    [51949] = castRecord(3, 9663676416, 19),
    [9001] = castRecord(3, 4096, 1),
    [9002] = castRecord(3, 1073741824, 16, 536870912),
    [9003] = castRecord(3, 1073741824, 999),
    [9004] = castRecord(3, 1073741824, 16),
    [9005] = castRecord(3, 1073741824, 16),
    [9006] = castRecord(3, 1073741824, 1),
    [589] = castRecord(6, 1073741824, 16),
}

local castTimes = { [133] = 1500, [11366] = 6000, [51949] = 2500,
    [9001] = 0, [9002] = 1500, [9003] = 12000, [9004] = 1500,
    [9005] = 1500,
    [9006] = 0,
    [589] = 1500 }
local baseModifiers = { [133] = { -100, -10 }, [11366] = { 0, 0 },
    [51949] = { 0, 0 }, [9004] = { 0, 0 }, [9005] = { 0, 0 } }
local playerClass, aura, procActive, conflict = "MAGE", nil, false, false
local dbcCalls, durationCalls, auraCalls, modifierCalls = 0, 0, 0, {}
local spellInfoCalls, castSpeedCalls = {}, 0

local function unsigned(value)
    return value < 0 and value + 4294967296 or value
end

UnitClass = function() return "Localized Mage", playerClass end
GetSpellName = function()
    error("Presence of Mind mechanics must not inspect localized names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row or row[field] == nil then error("missing DBC field") end
    if copied and type(row[field]) == "table" then
        return { row[field][1], row[field][2], row[field][3] }
    end
    return row[field]
end
GetSpellDuration = function(spellId, ignoreModifiers)
    durationCalls = durationCalls + 1
    assert(spellId == 12043 and ignoreModifiers == 1,
        "only exact base Presence of Mind duration may be read")
    return 0
end
GetSpellModifiers = function(spellId, operation)
    modifierCalls[spellId] = (modifierCalls[spellId] or 0) + 1
    assert(operation == 10, "only CASTING_TIME modifiers may be read")
    local pair = baseModifiers[spellId]
    assert(pair, "unexpected modifier query")
    local flat, percent = pair[1], pair[2]
    if procActive then
        percent = percent - 100
        if conflict then percent = percent - 120 end
    end
    local changed = flat ~= 0 or percent ~= 0
    return unsigned(flat), unsigned(percent), changed and 1 or 0
end
C_Spell = { GetSpellInfo = function(spellId)
    spellInfoCalls[spellId] = (spellInfoCalls[spellId] or 0) + 1
    local cast = castTimes[spellId]
    assert(cast ~= nil, "unexpected spell info query")
    return { spellID = spellId, castTime = cast,
        name = "localized text must remain mechanically irrelevant" }
end }
GetUnitField = function(unit, field)
    castSpeedCalls = castSpeedCalls + 1
    assert(unit == "player" and field == "modCastSpeed")
    return 0.8
end
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    auraCalls = auraCalls + 1
    assert(spellId == 12043, "aura capture must use numeric identity")
    return aura
end }

dofile("Game/Player/MagePresenceOfMind.lua")
dofile("Graph/MagePresenceOfMind.lua")
local Runtime = XelAssist.Game.Player.MagePresenceOfMind
local Graph = XelAssist.Graph.MagePresenceOfMind

local inferred, reason, handled = Runtime:InferKnowledge(12043)
assert(inferred and reason == nil and handled and inferred.kind == "modifier"
    and inferred.kindExact and inferred.magePresenceOfMind
    and inferred.magePresenceOfMindEvidence.affectMask == 1073741824
    and inferred.magePresenceOfMindEvidence.modifier == 10
    and inferred.magePresenceOfMindEvidence.modifierPercent == -100,
    "numeric setup identity must seal the exact one-charge cast modifier")
assert(inferred.priority == nil and inferred.rotation == nil
    and inferred.nextSpell == nil and inferred.nextInstant == nil,
    "exact inference must contain no typed spell order or generic instant flag")

local unknown
unknown, reason, handled = Runtime:InferKnowledge(133)
assert(unknown == nil and not handled and reason == "spell is not Presence of Mind",
    "ordinary Mage actions must fall through to ordinary action inference")
playerClass = "PRIEST"
local beforeDBC = dbcCalls
unknown, reason, handled = Runtime:InferKnowledge(12043)
assert(unknown == nil and not handled and dbcCalls == beforeDBC,
    "another class must be rejected before reading setup DBC")
playerClass = "MAGE"

Runtime:Invalidate()
records[12043].effectItemType[1] = 1
unknown, reason, handled = Runtime:InferKnowledge(12043)
assert(unknown == nil and handled
    and reason == "Presence of Mind DBC topology is incomplete",
    "a recognized but changed setup topology must fail closed")
records[12043].effectItemType[1] = 1073741824
Runtime:Invalidate()
inferred = assert(Runtime:InferKnowledge(12043))

local state = { time = 0, actors = { player = { level = 40 } },
    actorReadyAt = { player = 0 }, playerGcdReadyAt = 0 }
assert(Runtime:Attach(state, "MAGE") and state.magePresenceOfMind.exact
    and state.magePresenceOfMind.active == false and auraCalls == 1,
    "an absent exact numeric aura must seal inactive root state")

local function action(spellId, facts)
    return { spellId = spellId, actor = "player", executor = "playerSpell",
        facts = facts or { kind = "damage", ranged = true } }
end
local setup = action(12043, inferred)
local fireball, pyroblast, highFlags, instant, ignored, unknownCast, conflictCast,
    affectedInstant =
    action(133), action(11366), action(51949), action(9001), action(9002),
    action(9003), action(9004), action(9006)

local fireFacts = Runtime:CaptureFacts(fireball, { cast = 99 }, state)
local fireContract = fireFacts.magePresenceOfMindCast
assert(fireContract and fireContract.claimed and fireContract.exact
    and fireContract.eligible and fireContract.baselineCast == 1.008,
    "flat, percent and haste evidence must reproduce the server baseline cast")
assert(Graph:PotentialConsumer(fireFacts),
    "an exact positive later cast must expose a mechanics-only setup consumer")
local highFacts = Runtime:CaptureFacts(highFlags, { cast = 99 }, state)
assert(highFacts.magePresenceOfMindCast.exact
    and highFacts.magePresenceOfMindCast.eligible
    and highFacts.magePresenceOfMindCast.baselineCast == 2,
    "the low affect bit must remain exact when high family-flag words exist")
local pyroFacts = Runtime:CaptureFacts(pyroblast, { cast = 99 }, state)
assert(pyroFacts.magePresenceOfMindCast.baselineCast == 4.8,
    "installed six-second casts must retain exact haste-adjusted baselines")
local instantFacts = Runtime:CaptureFacts(instant, { cast = 0 }, state)
assert(instantFacts.magePresenceOfMindCast.exact
    and instantFacts.magePresenceOfMindCast.eligible == false,
    "an action outside the exact affect mask must not consume the charge")
local ignoredFacts = Runtime:CaptureFacts(ignored, { cast = 1.5 }, state)
assert(ignoredFacts.magePresenceOfMindCast.exact
    and ignoredFacts.magePresenceOfMindCast.eligible == false
    and modifierCalls[9002] == nil,
    "IGNORE_CASTER_MODIFIERS must prevent both mutation and live modifier reads")
local unknownFacts = Runtime:CaptureFacts(unknownCast, { cast = 12 }, state)
assert(unknownFacts.magePresenceOfMindCast.exact == false
    and unknownFacts.magePresenceOfMindCast.reason
        == "installed cast-time record is unrecognized",
    "an unrecognized affected cast record must fail closed")
local affectedInstantFacts = Runtime:CaptureFacts(
    affectedInstant, { cast = 0 }, state)
assert(affectedInstantFacts.magePresenceOfMindCast.exact == false
    and affectedInstantFacts.magePresenceOfMindCast.reason
        == "affected cast lifecycle is not a positive PoM cast",
    "a masked zero-cast action must not be mislabeled unaffected")

local setupTooltip = {}
for key, value in pairs(inferred) do setupTooltip[key] = value end
local prepared, setupReason, setupHandled = Graph:PrepareLegal(
    setup, state, setupTooltip)
assert(setupHandled and setupReason == nil and prepared
    and prepared.cost == 0 and prepared.powerType == 0
    and prepared.classMechanic == "magePresenceOfMind"
    and prepared.magePresenceOfMindTransition.evidenceExact,
    "the exact setup must create a copied zero-cost transition")
local setupLane = Graph:StrategicSetup(prepared)
assert(setupLane and setupLane.key == "magePresenceOfMind:12043"
    and setupLane.consumerKey == "magePresenceOfMind:affectedCast"
    and Graph:ConsumerKey(fireFacts) == setupLane.consumerKey
    and Graph:ConsumerKey(instantFacts) == nil,
    "only an exact positive affected cast may close the bounded setup lane")
local score = { tooltip = prepared, power = 999, expectedPower = 999,
    effectivePower = 999, value = 999 }
assert(Graph:Score(score) and score.value == 0 and score.power == 0
    and score.estimated == false,
    "setup must have no flat utility independent of its later consequence")

local child = { time = 0, actorReadyAt = { player = 0 },
    playerGcdReadyAt = 0 }
assert(Graph:Copy(state, child)
    and child.magePresenceOfMind ~= state.magePresenceOfMind
    and child.magePresenceOfMind.profile
        ~= state.magePresenceOfMind.profile,
    "graph branches must own independent aura and profile tables")
assert(Graph:Apply(child, { action = setup, tooltip = prepared })
    and child.magePresenceOfMind.active
    and state.magePresenceOfMind.active == false,
    "setup must activate only its chosen graph branch")
local instantFire, legalReason, legalHandled = Graph:PrepareLegal(
    fireball, child, fireFacts)
assert(legalHandled and legalReason == nil and instantFire.cast == 0
    and instantFire.magePresenceOfMindConsumption
    and fireFacts.magePresenceOfMindConsumption == nil,
    "an exact affected later cast must become instant on a copy")
assert(Graph:Consume(child, { action = fireball, tooltip = instantFire,
        cast = 0 }) and not child.magePresenceOfMind.active
    and child.magePresenceOfMind.savedCastTime == 1.008,
    "a successful affected cast must consume exactly one branch-local charge")
local restored = assert(Graph:PrepareLegal(fireball, child, fireFacts))
assert(restored.cast == 1.008
    and restored.magePresenceOfMindConsumption == nil,
    "descendants after consumption must restore the sealed baseline cast")

assert(Graph:Apply(child, { action = setup, tooltip = prepared }))
local unaffected = assert(Graph:PrepareLegal(instant, child, instantFacts))
assert(unaffected.cast == 0 and not unaffected.magePresenceOfMindConsumption
    and not Graph:Consume(child, { action = instant, tooltip = unaffected,
        cast = 0 }) and child.magePresenceOfMind.active,
    "an exactly unaffected instant action must preserve the charge")
local blocked, blockedReason, blockedHandled = Graph:PrepareLegal(
    unknownCast, child, unknownFacts)
assert(blocked == nil and blockedHandled
    and blockedReason == "installed cast-time record is unrecognized",
    "an active aura must block an affected action with incomplete evidence")
blocked, blockedReason, blockedHandled = Graph:PrepareLegal(
    affectedInstant, child, affectedInstantFacts)
assert(blocked == nil and blockedHandled
    and blockedReason == "affected cast lifecycle is not a positive PoM cast",
    "an active aura must fail closed on an unmodeled masked instant lifecycle")

procActive, aura = true, { spellId = 12043, isHelpful = true,
    applications = 1, duration = 0, expirationTime = 0 }
assert(Runtime:Attach(state, "MAGE") and state.magePresenceOfMind.active,
    "an exact indefinite numeric aura must seal active root state")
fireFacts = Runtime:CaptureFacts(fireball, { cast = 0 }, state)
assert(fireFacts.magePresenceOfMindCast.exact
    and fireFacts.magePresenceOfMindCast.eligible
    and fireFacts.magePresenceOfMindCast.baselineCast == 1.008,
    "active root capture must verify exactly the additional -100 percent delta")
local reloadFacts = Runtime:CaptureFacts(action(9005), { cast = 0 }, state)
assert(reloadFacts.magePresenceOfMindCast.exact
    and reloadFacts.magePresenceOfMindCast.baselineCast == 1.2,
    "an active reload must reconstruct the exact baseline without prior capture")
conflict = true
local conflictFacts = Runtime:CaptureFacts(conflictCast, { cast = 0 }, state)
assert(conflictFacts.magePresenceOfMindCast.exact == false
    and conflictFacts.magePresenceOfMindCast.reason
        == "Presence of Mind baseline or active cast delta unavailable",
    "a changed simultaneous casting-time regime must fail closed")
conflict = false

local saved = { GetSpellRecField, GetSpellDuration, GetSpellModifiers,
    C_Spell.GetSpellInfo, GetUnitField,
    C_UnitAuras.GetPlayerAuraBySpellID }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
C_Spell.GetSpellInfo = function() error("spell info read during graph search") end
GetUnitField = function() error("cast speed read during graph search") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("aura read during graph search")
end
local pure = { time = 0, actorReadyAt = { player = 0 },
    playerGcdReadyAt = 0 }
assert(Graph:Copy(state, pure))
local pureCast = assert(Graph:PrepareLegal(fireball, pure, fireFacts))
assert(pureCast.cast == 0 and Graph:Consume(pure,
    { action = fireball, tooltip = pureCast, cast = 0 }),
    "copy, timing preparation and consumption must use sealed root facts only")

GetSpellRecField, GetSpellDuration, GetSpellModifiers =
    saved[1], saved[2], saved[3]
C_Spell.GetSpellInfo, GetUnitField,
    C_UnitAuras.GetPlayerAuraBySpellID = saved[4], saved[5], saved[6]

print("ok: Mage Presence of Mind projects one exact later cast-time consequence")
