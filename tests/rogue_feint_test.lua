-- Build-5875 Feint rows prove a selected-hostile flat threat consequence,
-- including level scaling and melee delivery, without localized spell names.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function row(baseLevel, spellLevel, maxLevel, basePoints, dice)
    return {
        school = 0, category = 82, mechanic = 0, attributes = 327696,
        attributesEx = 134217728, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, stances = 0, stancesNot = 0, targets = 0,
        casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
        recoveryTime = 0, categoryRecoveryTime = 10000,
        interruptFlags = 0, auraInterruptFlags = 0,
        channelInterruptFlags = 0, baseLevel = baseLevel,
        spellLevel = spellLevel, maxLevel = maxLevel, durationIndex = 0,
        powerType = 3, manaCost = 20, manaCostPerlevel = 0,
        manaCostPercentage = 0, rangeIndex = 2,
        startRecoveryCategory = 133, startRecoveryTime = 1000,
        spellFamilyName = 8, spellFamilyFlags = 134217728,
        maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
        effect = triple(63), effectDieSides = dice,
        effectBaseDice = triple(dice[1], dice[2], dice[3]),
        effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(-1),
        effectBasePoints = basePoints, effectMechanic = triple(),
        effectImplicitTargetA = triple(6), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(), effectApplyAuraName = triple(),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectMiscValue = triple(),
        effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
    }
end

local records = {
    [1966] = row(16, 16, 26, triple(-151, -1), triple(1, 1)),
    [6768] = row(28, 28, 38, triple(-241), triple(1)),
    [8637] = row(40, 40, 50, triple(-391), triple(1)),
    [11303] = row(52, 52, 62, triple(-601), triple(1)),
    [25302] = row(60, 60, 70, triple(-801), triple(1)),
}
local reads, class, level = 0, "ROGUE", 20

function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    local value = records[spellId] and records[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function GetSpellRangeData(index)
    reads = reads + 1
    assert(index == 2)
    return 0, 5
end

function UnitClass()
    return "localized class irrelevant", class
end

function UnitLevel(unit)
    assert(unit == "player")
    return level
end

dofile("Game/Player/RogueFeint.lua")
local Runtime = XelAssist.Game.Player.RogueFeint
local ids = { 1966, 6768, 8637, 11303, 25302 }
local baseLevels = { 16, 28, 40, 52, 60 }
local baseAmounts = { 150, 240, 390, 600, 800 }
local index
for index = 1, table.getn(ids) do
    local found, reason, handled = Runtime:Classify(ids[index], baseLevels[index])
    assert(found and found.valid and found.exact and handled and reason == nil
        and found.amount == baseAmounts[index]
        and found.effectOpcode == 63 and found.recipient == "selected-hostile"
        and found.powerType == 3 and found.cost == 20
        and found.minRange == 0 and found.maxRange == 5
        and found.categoryCooldown == 10 and found.gcd == 1
        and found.deliveryModel == "physical"
        and found.deliverySubtype == "melee" and found.usesWeaponSkill
        and found.refundsPowerOnFailure
        and found.resourceRefundAmountExact == false,
        "every installed Feint rank must expose its exact target-local shape")
    local capped = Runtime:Classify(ids[index], baseLevels[index] + 40)
    assert(capped.amount == baseAmounts[index] + 10,
        "Feint level scaling must stop at the installed rank maximum")
end
assert(Runtime:Classify(99999) == nil,
    "an unrelated identity must remain outside the Feint portfolio")

local inferred, reason, handled = Runtime:InferKnowledge(1966)
assert(inferred and handled and reason == nil and inferred.inferred
    and inferred.kind == "threatDrop" and inferred.kindExact
    and inferred.rogueFeint and inferred.targetLocalThreatDrop
    and inferred.threatDropModel == "target-local-flat"
    and inferred.melee and inferred.school == 0
    and inferred.deliveryModel == "physical"
    and inferred.deliverySubtype == "melee" and inferred.usesWeaponSkill
    and inferred.requiresExactUsability and inferred.submissionGuarded
    and inferred.preferred == nil and inferred.order == nil
    and inferred.rogueFeintEvidence.amount == 154,
    "Rogue inference must describe consequences without a typed rotation")
class = "HUNTER"
local foreign, _, foreignHandled = Runtime:InferKnowledge(1966)
assert(foreign == nil and foreignHandled == false,
    "another class must not claim Rogue action inference")
class = "ROGUE"

local action = { name = "localized text deliberately ignored", spellId = 1966,
    actor = "player", executor = "playerSpell", facts = inferred }
local savedDBC, savedRange, savedLevel = GetSpellRecField,
    GetSpellRangeData, UnitLevel
GetSpellRecField = function() error("DBC read after action discovery") end
GetSpellRangeData = function() error("range read after action discovery") end
UnitLevel = function() error("level read after action discovery") end
local captured = Runtime:CaptureFacts(action, { source = "root tooltip" })
assert(captured.rogueFeint and captured.targetLocalThreatDrop
    and captured.threatDropModel == "target-local-flat"
    and captured.threatDropAmount == 154 and captured.cost == 20
    and captured.powerType == 3 and captured.minRange == 0
    and captured.maxRange == 5 and captured.categoryCooldown == 10
    and captured.cooldownGroup == 82 and captured.gcd == 1
    and captured.cast == 0 and captured.deliveryModel == "physical"
    and captured.deliverySubtype == "melee" and captured.usesWeaponSkill,
    "root capture must consume only sealed Feint discovery evidence")

XelAssist.Graph.State = {
    RefreshHostileRecord = function(_, state, key)
        state.refreshed = (state.refreshed or 0) + 1
        local record = state.hostiles.byKey[key]
        if record.threat.projectedPlayerOwnershipUnknown then
            state.hasAggro = nil
        else
            state.hasAggro = record.threat.projectedPlayerHasAggro
            if state.hasAggro == nil then
                state.hasAggro = record.threat.playerHasAggro
            end
        end
        state.targetPlayerThreatDeltaExact =
            record.threat.playerDeltaExact ~= false
    end,
}
dofile("Graph/RogueFeint.lua")
local Graph = XelAssist.Graph.RogueFeint

local function hostile(key, guid, selected, playerAggro)
    return { key = key, guid = guid, selected = selected, dead = false,
        hasPlayerAggro = playerAggro,
        threat = { available = true, playerHasAggro = playerAggro,
            petHasAggro = not playerAggro, playerDelta = 0,
            playerDeltaExact = true, petDelta = 0 } }
end

local function state(playerAggro)
    local selected = hostile("selected-key", "selected-guid", true,
        playerAggro)
    local other = hostile("other-key", "other-guid", false, false)
    return { inCombat = true, tank = false, hasAggro = playerAggro,
        targetGUID = selected.guid, targetPlayerThreatDeltaExact = true,
        hostiles = { selectedKey = selected.key,
            order = { selected.key, other.key },
            byKey = { [selected.key] = selected, [other.key] = other } } }
end

local descriptor = { unit = "target", relation = "hostile",
    source = "selected", key = "selected-key", guid = "selected-guid" }
local source = state(true)
local blocker, graphHandled = Graph:Blocker(
    action, source, descriptor, captured)
assert(blocker == nil and graphHandled,
    "exact selected-target Feint must enter its target-local graph lane")
local offTarget = { unit = "mouseover", relation = "hostile",
    source = "engaged", key = "other-key", guid = "other-guid" }
assert(Graph:Blocker(action, source, offTarget, captured)
        == "Feint requires the selected hostile",
    "Feint must never become an off-target or global threat drop")
local idle = state(true)
idle.inCombat = false
assert(Graph:Blocker(action, idle, descriptor, captured)
        == "no combat threat to reduce",
    "Feint must not consume graph horizon without a combat threat list")
local uncertain = state(true)
uncertain.hostiles.byKey["selected-key"].threat
    .projectedPlayerOwnershipUnknown = true
assert(Graph:Blocker(action, uncertain, descriptor, captured)
        == "selected hostile threat ownership unavailable",
    "unknown projected ownership must fail closed")

local context = { action = action, state = source, descriptor = descriptor,
    tooltip = captured, resistance = { unknown = false },
    effectDelivery = 0.75, value = 0 }
assert(Graph:Score(context)
    and context.rogueFeintExpectedThreatReduction == 115.5
    and context.value == 115.5 and context.power == 0
    and context.expectedPower == 0 and context.effectivePower == 0
    and context.threat == 0
    and context.reason == "lowers threat on the selected attacker",
    "Feint value must be only exact flat threat times melee delivery")
local tankContext = { action = action, state = state(true),
    descriptor = descriptor, tooltip = captured,
    resistance = { unknown = false }, effectDelivery = 0.75 }
tankContext.state.tank = true
assert(Graph:Score(tankContext) and tankContext.value == -115.5,
    "a tank must see the same exact reduction as a negative consequence")
local safeContext = { action = action, state = state(false),
    descriptor = descriptor, tooltip = captured,
    resistance = { unknown = false }, effectDelivery = 0.75 }
assert(Graph:Score(safeContext) and safeContext.value == 0,
    "no observed player aggro must not create proxy Feint utility")
local noDelivery = { action = action, state = state(true),
    descriptor = descriptor, tooltip = captured, effectDelivery = 1 }
assert(Graph:Score(noDelivery) and noDelivery.value == -100000
    and noDelivery.reason == "Feint melee delivery evidence unavailable",
    "missing weapon-delivery evidence must fail closed")

local candidate = { action = action, tooltip = captured,
    targetRelation = "hostile", targetSource = "selected",
    targetKey = "selected-key", targetGUID = "selected-guid",
    effectDelivery = 0.75 }
local out = state(true)
assert(Graph:Apply(out, candidate), "a valid Feint edge must apply")
local projected = out.hostiles.byKey["selected-key"]
assert(projected.threat.playerDelta == -115.5
    and projected.threat.playerDeltaExact == false
    and projected.threat.projectedPlayerThreatReduction == 115.5
    and projected.threat.projectedPlayerThreatReductionExact == false
    and projected.threat.projectedPlayerThreatReductionProbability == 0.75
    and projected.threat.projectedThreatDropModel == "target-local-flat"
    and projected.projectedThreat.playerReduction == 115.5
    and projected.projectedFeint.rawReduction == 154
    and projected.projectedFeint.applicationProbability == 0.75
    and projected.threat.projectedPlayerOwnershipUnknown
    and out.hasAggro == nil and out.targetPlayerThreatDeltaExact == false
    and out.refreshed == 1,
    "Feint must store one expected target-local reduction without inventing a victim")
assert(out.hostiles.byKey["other-key"].threat.playerDelta == 0
    and out.hostiles.byKey["other-key"].projectedThreat == nil
    and source.hostiles.byKey["selected-key"].threat.playerDelta == 0
    and source.hasAggro == true,
    "Feint must preserve off-target and source-state purity")
local notAggro = state(false)
assert(Graph:Apply(notAggro, candidate)
    and notAggro.hasAggro == false
    and not notAggro.hostiles.byKey["selected-key"].threat
        .projectedPlayerOwnershipUnknown,
    "reducing player threat cannot make a different victim switch to player")

GetSpellRecField, GetSpellRangeData, UnitLevel = savedDBC, savedRange, savedLevel
Runtime:Invalidate()
records[1966].effectImplicitTargetA = triple(1)
local beforeInvalid = reads
local invalid, invalidReason, invalidHandled = Runtime:Classify(1966, 20)
assert(invalid and not invalid.valid and invalidHandled
    and invalidReason == "Feint DBC topology is incomplete" and reads > beforeInvalid,
    "a recognized Feint identity with changed recipient must fail closed")
local afterInvalid = reads
local cachedInvalid, cachedReason, cachedHandled = Runtime:Classify(1966, 20)
assert(cachedInvalid and not cachedInvalid.valid and cachedHandled
    and cachedReason == invalidReason and reads == afterInvalid,
    "cached invalid Feint evidence must remain handled without rereading DBC")

print("ok: build-5875 Feint is an exact selected-target flat threat edge")
