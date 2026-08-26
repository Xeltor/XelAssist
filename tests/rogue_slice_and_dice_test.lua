-- Build-5875 Slice and Dice must earn graph value only from exact aura-138
-- attack cadence, verified white damage and bounded target survival.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function row(level, basePoints)
    return { school = 0, category = 0, mechanic = 0,
        attributes = 537198608, attributesEx = 4195328,
        attributesEx2 = 4, attributesEx3 = 1342439424,
        attributesEx4 = 16, stances = 0, stancesNot = 0, targets = 0,
        castingTimeIndex = 1, recoveryTime = 0,
        categoryRecoveryTime = 0, interruptFlags = 0,
        auraInterruptFlags = 0, channelInterruptFlags = 0,
        maxLevel = 0, baseLevel = level, spellLevel = level,
        durationIndex = 185, powerType = 3, manaCost = 20,
        manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 6,
        startRecoveryCategory = 133, startRecoveryTime = 1000,
        spellFamilyName = 8, spellFamilyFlags = 262144,
        maxAffectedTargets = 0, dmgClass = 0, preventionType = 2,
        effect = triple(3, 6), effectDieSides = triple(0, 1),
        effectBaseDice = triple(0, 1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(0, basePoints),
        effectMechanic = triple(), effectImplicitTargetA = triple(6, 1),
        effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
        effectApplyAuraName = triple(0, 138), effectAmplitude = triple(),
        effectMultipleValue = triple(), effectChainTarget = triple(),
        effectItemType = triple(), effectMiscValue = triple(),
        effectTriggerSpell = triple(), effectPointsPerComboPoint = triple() }
end

local records = { [5171] = row(10, 19), [6774] = row(42, 29) }
local class, now, auraList, durationScale = "ROGUE", 100, {}, 1
local reads = 0

function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    local value = records[spellId] and records[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function UnitClass()
    return "localized class ignored", class
end

function GetTime()
    return now
end

C_Spell = { GetSpellDurationRange = function(spellId)
    reads = reads + 1
    assert(records[spellId])
    return 6 * durationScale, 21 * durationScale, true
end }
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    reads = reads + 1
    assert(unit == "player" and filter == "HELPFUL")
    return auraList
end }

dofile("Game/Player/RogueSliceAndDice.lua")
local Runtime = XelAssist.Game.Player.RogueSliceAndDice

local first, reason, handled = Runtime:Classify(5171)
assert(first and first.valid and first.exact and handled and reason == nil
    and first.rank == 1 and first.hastePercent == 20
    and first.hasteMultiplier == 1.2 and first.aura == 138
    and first.durationBase == 6 and first.durationMax == 21
    and first.durationComboScaled and first.cost == 20
    and first.recipient == "player",
    "rank one must expose the exact self melee-haste consequence")
local second = Runtime:Classify(6774)
assert(second and second.valid and second.rank == 2
    and second.hastePercent == 30 and second.hasteMultiplier == 1.3,
    "rank two must retain its installed 30 percent magnitude")
assert(Runtime:Classify(99999) == nil,
    "an unrelated numeric identity must remain outside this portfolio")

local inferred, inferReason, inferHandled = Runtime:InferKnowledge(6774)
assert(inferred and inferHandled and inferReason == nil and inferred.inferred
    and inferred.kind == "buff" and inferred.kindExact and inferred.self
    and inferred.combo and inferred.comboSpendAll
    and inferred.rogueSliceAndDice and inferred.playerMeleeHaste
    and inferred.preferred == nil and inferred.order == nil,
    "inference must describe mechanics without creating a Rogue rotation")
local action = { name = "localized text deliberately ignored", spellId = 6774,
    actor = "player", executor = "playerSpell", facts = inferred }
local captured = Runtime:CaptureFacts(action, { source = "root capture" })
action.facts = captured
assert(captured.rogueSliceAndDice and captured.meleeHastePercent == 30
    and captured.durationBase == 6 and captured.durationMax == 21
    and captured.durationComboScaled and captured.cost == 20
    and captured.gcd == 1 and captured.cast == 0,
    "root facts must consume only sealed exact rank evidence")

durationScale = 1.45
Runtime:Invalidate()
local talented = Runtime:Classify(6774)
assert(talented and talented.valid
    and math.abs(talented.durationBase - 8.7) < 0.0001
    and math.abs(talented.durationMax - 30.45) < 0.0001
    and talented.durationSpellModFactor == 1.45,
    "exact player duration SpellMods must scale both combo endpoints")
durationScale = 1
Runtime:Invalidate()
Runtime:Classify(5171)
Runtime:Classify(6774)

class = "DRUID"
local foreign, _, foreignHandled = Runtime:InferKnowledge(6774)
assert(foreign == nil and foreignHandled == false,
    "another class must not claim Rogue inference")
class = "ROGUE"

Runtime:Invalidate()
records[5171].effectApplyAuraName[2] = 137
local corrupt, corruptReason, corruptHandled = Runtime:Classify(5171)
assert(corrupt and corruptHandled and not corrupt.valid
    and corruptReason == "Slice and Dice DBC topology is incomplete",
    "a changed aura type must fail closed")
records[5171].effectApplyAuraName[2] = 138
Runtime:Invalidate()
first, reason = Runtime:Classify(5171)
second = Runtime:Classify(6774)
assert(first.valid and second.valid and reason == nil,
    "restored installed rows must validate after cache invalidation")
inferred = Runtime:InferKnowledge(6774)
action.facts = Runtime:CaptureFacts({ spellId = 6774, facts = inferred }, {})

XelAssist.Graph.Effects = { Decision = function(_, estimate)
    return estimate and estimate.decision or nil
end }
XelAssist.Combat.Resistance = { Estimate = function(_, white)
    assert(white.facts.whiteAttack and white.facts.usesWeaponSkill)
    return { decision = 1 }
end }
dofile("Graph/RogueSliceAndDice.lua")
local Graph = XelAssist.Graph.RogueSliceAndDice

local function friendlyPlayer()
    local record = { key = "player-key", unit = "player", guid = "player-guid",
        auras = { available = true } }
    return { order = { record.key }, byKey = { [record.key] = record },
        byUnit = { player = record.key } }
end

local function round(hand, speed, power)
    return { hand = hand, speed = speed, interval = speed + 0.05,
        speedTrusted = true, verified = true, projectable = true,
        phaseKnown = true, normalDamageKnown = true, power = power,
        targetGuid = "target-guid" }
end

local function state(mainSpeed, offSpeed)
    return { hostile = true, targetGUID = "target-guid",
        targetHealth = 1000, targetHealthExact = true, time = 0,
        targetSurvival = { available = true, incomingDps = 100,
            lowerTimeToDie = 8, upperTimeToDie = 12, timeToDie = 10 },
        actors = { player = { guid = "player-guid" } },
        friendlies = friendlyPlayer(),
        playerAttack = { active = true,
            attackRound = round("main", mainSpeed or 2, 50),
            offhandAttackRound = round("off", offSpeed or 1.5, 25) } }
end

local root = state()
auraList = {}
local attached = Graph:Attach(root)
assert(attached and attached.exact and not attached.active
    and attached.lanes.main.baseSpeed == 2
    and attached.lanes.off.baseSpeed == 1.5,
    "an exact absent aura must retain both unmodified melee lanes")
local descriptor = { unit = "player", relation = "self", source = "self",
    key = "player-key", guid = "player-guid" }
assert(Graph:Blocker(action, root, descriptor, action.facts) == nil,
    "verified self haste with a hostile and white lane must be legal")

local tooltip = {}
for key, value in pairs(action.facts) do tooltip[key] = value end
tooltip.duration, tooltip.durationComboPoints = 15, 3
local context = { action = action, tooltip = tooltip, state = root,
    descriptor = descriptor, wait = 0, cast = 0, downtime = 1 }
assert(Graph:Score(context)
    and math.abs(context.rogueMeleeHasteBonusDps - 12.15578285) < 0.0001
    and math.abs(context.rogueMeleeHasteUsefulSeconds - 10) < 0.0001
    and math.abs(context.rogueMeleeHasteExpectedDamage - 121.5578285) < 0.001
    and math.abs(context.value - 486.2313139) < 0.01
    and context.reason == "adds white damage before the target dies"
    and context.power == 0 and context.expectedPower == 0,
    "rank two must earn only target-survival-bounded extra white damage")

local noSurvival = state()
auraList = {}
Graph:Attach(noSurvival)
noSurvival.targetSurvival = nil
local unknownContext = { action = action, tooltip = tooltip,
    state = noSurvival, descriptor = descriptor, downtime = 1 }
assert(Graph:Score(unknownContext) and unknownContext.value == 0
    and unknownContext.reason == "target survival evidence unavailable",
    "missing survival evidence must withhold melee-haste value")

local candidate = { action = action, tooltip = tooltip, target = "player",
    targetRelation = "self", targetSource = "self",
    targetKey = "player-key", targetGUID = "player-guid" }
assert(Graph:Apply(root, candidate), "the exact self haste edge must apply")
local projectedAura = root.friendlies.byKey["player-key"].auras[action.name]
assert(root.rogueSliceAndDice.active
    and root.rogueSliceAndDice.remaining == 15
    and root.rogueSliceAndDice.percent == 30
    and projectedAura and projectedAura.spellId == 6774
    and projectedAura.meleeHastePercent == 30,
    "application must project both the state mechanic and numeric self aura")
assert(math.abs(Graph:IntervalAfter(root, "main", 1, 99)
        - (2 / 1.3 + 0.05)) < 0.0001,
    "a reset while aura 138 is active must use the hasted main cadence")
assert(Graph:Blocker(action, root, descriptor, tooltip)
        == "player melee haste is already active",
    "an active exact haste aura must not be double-applied")
Graph:Advance(root, 14.5)
assert(root.rogueSliceAndDice.active
    and root.rogueSliceAndDice.remaining == 0.5,
    "the projected haste lifetime must age causally")
assert(math.abs(Graph:IntervalAfter(root, "main", 0.25, 99)
        - (2 / 1.3 + 0.05)) < 0.0001
    and Graph:IntervalAfter(root, "main", 0.75, 99) == 2.05,
    "only resets occurring before expiration may keep the haste multiplier")
Graph:Advance(root, 0.5)
assert(not root.rogueSliceAndDice.active
    and Graph:IntervalAfter(root, "off", 0, 99) == 1.55,
    "expired haste must restore the exact off-hand base cadence")

auraList = { { spellId = 5171, expirationTime = 108, duration = 21 } }
local activeRoot = state(2 / 1.2, 1.5 / 1.2)
local activeModel = Graph:Attach(activeRoot)
assert(activeModel and activeModel.active and activeModel.spellId == 5171
    and activeModel.percent == 20 and activeModel.remaining == 8
    and math.abs(activeModel.lanes.main.baseSpeed - 2) < 0.0001
    and math.abs(activeModel.lanes.off.baseSpeed - 1.5) < 0.0001,
    "a live rank-one aura must recover the unmodified melee speeds")
assert(math.abs(Graph:IntervalAfter(activeRoot, "main", 1, 99)
        - (2 / 1.2 + 0.05)) < 0.0001
    and Graph:IntervalAfter(activeRoot, "main", 9, 99) == 2.05,
    "the current live aura expiry must bound future reset haste")

auraList = { { name = "identity unavailable" } }
local incomplete = state()
assert(Graph:Attach(incomplete) == nil
    and incomplete.rogueSliceAndDice.exact == false,
    "an unidentifiable helpful aura must fail closed")

-- All mutable client evidence is now forbidden. Descendant scoring,
-- application, copying and cadence selection must remain search-pure.
auraList = {}
local pure = state()
Graph:Attach(pure)
GetSpellRecField = function() error("DBC read inside graph search") end
C_Spell.GetSpellDurationRange = function()
    error("duration read inside graph search")
end
C_UnitAuras.GetUnitAuras = function()
    error("aura read inside graph search")
end
GetTime = function() error("clock read inside graph search") end
local pureContext = { action = action, tooltip = tooltip, state = pure,
    descriptor = descriptor, wait = 0, cast = 0, downtime = 1 }
assert(Graph:Score(pureContext) and Graph:Apply(pure, candidate),
    "sealed descendants must not reread mutable game evidence")
local copied = {}
assert(Graph:Copy(pure, copied) and copied.rogueSliceAndDice.active
    and copied.rogueSliceAndDice ~= pure.rogueSliceAndDice
    and Graph:IntervalAfter(copied, "main", 1, 99) < 2.05,
    "copied graph branches must keep independent exact haste state")

print("ok: exact Rogue melee haste earns only projected white-swing value")
