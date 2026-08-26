-- Exact installed Heroic Strike identity and landed rank-flat threat packet.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local class, dbcCalls = "WARRIOR", 0
function UnitClass() return "Warrior", class end
function GetSpellRangeData(index)
    assert(index == 2)
    return 0, 5
end

local ranks = {
    [78] = { level = 1, bonus = 10, flat = 20, min = 0 },
    [284] = { level = 8, bonus = 20, flat = 39, min = 0 },
    [285] = { level = 16, bonus = 31, flat = 59, min = 0 },
    [1608] = { level = 24, bonus = 43, flat = 78, min = 0 },
    [11564] = { level = 32, bonus = 57, flat = 98, min = 0 },
    [11565] = { level = 40, bonus = 79, flat = 118, min = 0 },
    [11566] = { level = 48, bonus = 110, flat = 137, min = 0 },
    [11567] = { level = 56, bonus = 137, flat = 145, min = 0 },
    [25286] = { level = 60, bonus = 156, flat = 175, min = 5086 },
}

local common = {
    school = 0, category = 0, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327700, attributesEx = 134217728,
    attributesEx2 = 0, attributesEx3 = 1024, attributesEx4 = 0,
    stances = 0, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 0,
    interruptFlags = 0, auraInterruptFlags = 0,
    channelInterruptFlags = 0, procFlags = 0, procChance = 101,
    procCharges = 0, maxLevel = 0, durationIndex = 0,
    powerType = 1, manaCost = 150, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 2,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    equippedItemClass = 2, equippedItemSubClassMask = 173555,
    equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 0,
    startRecoveryTime = 0, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 64,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
    stanceBarOrder = 4294967295,
}

local zero = { 0, 0, 0 }
function GetSpellRecField(spellId, field, array)
    dbcCalls = dbcCalls + 1
    local rank = ranks[spellId]
    if not rank then return nil end
    if not array then
        if field == "baseLevel" or field == "spellLevel" then
            return rank.level
        end
        return common[field]
    end
    local values
    if field == "effect" then values = { 17, 0, 0 }
    elseif field == "effectDieSides" then values = { 1, 0, 0 }
    elseif field == "effectBaseDice" then values = { 1, 0, 0 }
    elseif field == "effectBasePoints" then
        values = { rank.bonus, 0, 0 }
    elseif field == "effectImplicitTargetA" then values = { 6, 0, 0 }
    elseif field == "dmgMultiplier" then values = { 1, 1, 1 }
    else values = zero end
    return { values[1], values[2], values[3] }
end

dofile("Game/Player/WarriorHeroicStrikeThreat.lua")
local Runtime = XelAssist.Game.Player.WarriorHeroicStrikeThreat
local actions, ids = {}, { 78, 284, 285, 1608, 11564, 11565,
    11566, 11567, 25286 }
local index
for index = 1, table.getn(ids) do
    local spellId, rank = ids[index], ranks[ids[index]]
    local found, reason, handled = Runtime:Classify(spellId)
    assert(found and found.valid and found.exact and handled and not reason
        and found.level == rank.level
        and found.damageBonus == rank.bonus + 1
        and found.flatThreat == rank.flat
        and found.damageThreatMultiplier == 1
        and found.onNextSwing and found.cost == 15 and found.gcd == 0
        and found.serverBuildMin == rank.min
        and found.serverBuildMax == 5875
        and found.serverProfileExact and not found.runtimeVerified,
        "every Heroic Strike rank must bind exact DBC and server evidence")
    local facts, inferReason, inferred = Runtime:InferKnowledge(spellId)
    assert(facts and inferred and not inferReason
        and facts.kind == "damage" and facts.kindExact
        and facts.melee and facts.onNextSwing and facts.threat == 1
        and facts.supplementalFlatThreat == rank.flat
        and facts.runtimeUnverified and Runtime:Evidence(facts),
        "inference must expose mechanics without encoding action priority")
    actions[spellId] = { spellId = spellId, actor = "player",
        facts = facts }
end

local calls = dbcCalls
GetSpellRecField = function() error("graph search reread mutable DBC") end
assert(Runtime:Evidence(actions[78]) and Runtime:Evidence(actions[25286])
    and dbcCalls == calls,
    "sealed Heroic Strike evidence must remain search-pure")

dofile("Graph/WarriorHeroicStrikeThreat.lua")
local Graph = XelAssist.Graph.WarriorHeroicStrikeThreat
local blocker, handled = Graph:Blocker(actions[78], {},
    { relation = "hostile" })
assert(blocker == nil and handled,
    "exact Heroic Strike evidence must admit the hostile edge")

local context = { action = actions[78], kind = "damage",
    onNextSwing = true, effectDelivery = 1, estimated = false }
local threat, valueThreat, augmented, reason = Graph:Augment(
    context, 61, 11)
assert(augmented and not reason and threat == 81 and valueThreat == 31
    and context.warriorHeroicStrikeFlatThreat == 20
    and context.warriorHeroicStrikeDamageThreatMultiplier == 1
    and not context.warriorHeroicStrikeThreatProfileExact
    and context.estimated,
    "rank-one Heroic Strike must add 20 threat after displaced-hit value")

context = { action = actions[11567], kind = "damage",
    onNextSwing = true, effectDelivery = 0.5 }
threat, valueThreat = Graph:Augment(context, 50, 10)
assert(threat == 122.5 and valueThreat == 82.5,
    "rank-flat Heroic Strike threat must follow hit probability")
local applied, exact, projected, transitionReason = Graph:AppliedThreat(
    context, { effectDelivery = 0.5 }, 40)
assert(projected and not transitionReason and applied == 112.5
    and exact == false,
    "applied threat must combine capped damage and one landed flat packet")

local ordinary = { actor = "player", facts = { kind = "damage" } }
local left, right, claimed = Graph:Augment(
    { action = ordinary }, 20, 19)
assert(left == 20 and right == 19 and not claimed,
    "the Heroic Strike leaf must not claim ordinary damage")

local corrupt = { spellId = 78, actor = "player", facts = {} }
local key, value
for key, value in pairs(actions[78].facts) do corrupt.facts[key] = value end
corrupt.facts.supplementalFlatThreat = 21
blocker, handled = Graph:Blocker(corrupt, {}, { relation = "hostile" })
assert(blocker == "Heroic Strike threat evidence unavailable" and handled,
    "incoherent sealed threat evidence must fail closed")

XelAssist.Graph.WarriorRevengeThreat = {
    Is = function() return false end,
    Blocker = function() return nil, false end,
    Augment = function(_, _, a, b) return a, b, false, nil end,
    AppliedThreat = function() return nil, nil, false, nil end,
}
dofile("Graph/WarriorThreatPackets.lua")
local Packets = XelAssist.Graph.WarriorThreatPackets
local swingThreat, swingExact, swingHandled = Packets:SwingThreat(
    actions[78], 40, 1)
assert(swingHandled and swingThreat == 60 and swingExact == false,
    "queued swing resolution must reuse the compound Heroic Strike packet")

dofile("Game/ActionInference.lua")
local inferred, inferenceReason, inferenceHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(78)
assert(inferred and inferenceHandled and inferenceReason == nil
    and inferred.warriorHeroicStrikeThreat,
    "the production inference boundary must claim exact Heroic Strike")
dofile("Graph/ClassEvidence.lua")
blocker, handled = XelAssist.Graph.ClassEvidence:Blocker(
    actions[78], {}, { relation = "hostile" }, actions[78].facts, 0)
assert(blocker == nil and handled,
    "the production class blocker must admit sealed Heroic Strike")

XelAssistCharDB = {}
XelAssist.Graph.PlayerThreat = { Scale = function(_, _, actor, amount)
    assert(actor == "player")
    return amount * 1.3, true, 1.3
end }
dofile("Graph/ThreatScoring.lua")
local scored = { action = actions[78], facts = actions[78].facts,
    kind = "damage", onNextSwing = true,
    state = { tank = true, resourceMax = 100, groupSize = 0 },
    cost = 15, value = 13, fullEffectivePower = 61,
    marginalEffectivePower = 11, expectedPower = 61, power = 61,
    effectDelivery = 1, threatSchool = 0 }
XelAssist.Graph.ThreatScoring:Apply(scored)
assert(math.abs(scored.threat - 105.3) < 0.000001
    and scored.playerThreatExact == false
    and scored.warriorHeroicStrikeFlatThreat == 20 and scored.estimated,
    "scoring must compose full damage, rank-flat threat, and stance scaling")

local added
XelAssist.Graph.State = {
    ActiveHostile = function(_, out) return out.active end,
}
XelAssist.Graph.PlayerThreat = {
    Scale = function(_, _, actor, amount)
        assert(actor == "player")
        return amount * 1.3, true, 1.3
    end,
    AddScaled = function(_, record, actor, amount, exactness)
        added = { record = record, actor = actor,
            amount = amount, exact = exactness }
    end,
}
dofile("Graph/PrimaryThreatEffects.lua")
local hostile = { guid = "hostile-1" }
XelAssist.Graph.PrimaryThreatEffects:Apply(
    { active = hostile, actors = {} },
    { targetRelation = "hostile", targetGUID = "hostile-1",
        effectDelivery = 1, playerThreatExact = false },
    { action = actions[78], facts = actions[78].facts,
        appliedHostileDamage = 40, threatSchool = 0 })
assert(added and added.record == hostile and added.actor == "player"
    and math.abs(added.amount - 78) < 0.000001
    and added.exact == false,
    "transition must recompute capped damage plus rank-flat threat")

GetSpellRecField = function(spellId, field, array)
    local rank = ranks[spellId]
    if not rank then return nil end
    if not array then
        if field == "baseLevel" or field == "spellLevel" then
            return rank.level
        end
        if field == "attributesEx3" then return 0 end
        return common[field]
    end
    if field == "effect" then return { 17, 0, 0 } end
    if field == "effectDieSides" or field == "effectBaseDice" then
        return { 1, 0, 0 }
    end
    if field == "effectBasePoints" then return { rank.bonus, 0, 0 } end
    if field == "effectImplicitTargetA" then return { 6, 0, 0 } end
    if field == "dmgMultiplier" then return { 1, 1, 1 } end
    return { 0, 0, 0 }
end
Runtime:Invalidate()
local invalid, invalidReason, recognized = Runtime:Classify(78)
assert(invalid and not invalid.valid and recognized
    and invalidReason == "Heroic Strike DBC topology is incomplete",
    "an installed row mismatch must not fall through to generic knowledge")

Runtime:Invalidate()
class = "MAGE"
local foreign, foreignReason, foreignHandled = Runtime:InferKnowledge(78)
assert(foreign == nil and not foreignHandled
    and foreignReason == "player is not an exactly identified Warrior",
    "another class must not receive Warrior Heroic Strike mechanics")

print("ok: exact Heroic Strike next-swing and rank-flat threat profile")
