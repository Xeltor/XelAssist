-- Exact installed Revenge identity and compound server threat consequence.
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
    [6572] = { level = 14, base = 11, die = 3, flat = 63, min = 0 },
    [6574] = { level = 24, base = 17, die = 5, flat = 108, min = 0 },
    [7379] = { level = 34, base = 24, die = 7, flat = 153, min = 0 },
    [11600] = { level = 44, base = 42, die = 11, flat = 198, min = 0 },
    [11601] = { level = 54, base = 63, die = 15, flat = 243, min = 0 },
    [25288] = { level = 60, base = 80, die = 19, flat = 270, min = 5086 },
}

local common = {
    school = 0, category = 65, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 134218240,
    attributesEx2 = 0, attributesEx3 = 1024, attributesEx4 = 512,
    stances = 131072, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 1, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 6000,
    interruptFlags = 0, auraInterruptFlags = 0,
    channelInterruptFlags = 0, procFlags = 0, procChance = 101,
    procCharges = 0, maxLevel = 0, durationIndex = 0,
    powerType = 1, manaCost = 50, manaCostPerlevel = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 2,
    speed = 0, modalNextSpell = 0, stackAmount = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 1024,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
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
    if field == "effect" then values = { 2, 0, 0 }
    elseif field == "effectDieSides" then values = { rank.die, 0, 0 }
    elseif field == "effectBaseDice" then values = { 1, 0, 0 }
    elseif field == "effectBasePoints" then values = { rank.base, 0, 0 }
    elseif field == "effectImplicitTargetA" then values = { 6, 0, 0 }
    else values = zero end
    return { values[1], values[2], values[3] }
end

dofile("Game/Player/WarriorRevengeThreat.lua")
local Runtime = XelAssist.Game.Player.WarriorRevengeThreat

local actions = {}
local ids = { 6572, 6574, 7379, 11600, 11601, 25288 }
local i
for i = 1, table.getn(ids) do
    local spellId, rank = ids[i], ranks[ids[i]]
    local found, reason, handled = Runtime:Classify(spellId)
    assert(found and found.valid and found.exact and handled and not reason
        and found.level == rank.level
        and found.damageMinimum == rank.base + 1
        and found.damageMaximum == rank.base + rank.die
        and found.flatThreat == rank.flat
        and found.damageThreatMultiplier == 2.25
        and found.serverBuildMin == rank.min and found.serverBuildMax == 5875
        and found.serverProfileExact and not found.runtimeVerified,
        "every Revenge rank must bind exact DBC and server-profile evidence")
    local facts, inferReason, inferred = Runtime:InferKnowledge(spellId)
    assert(facts and inferred and not inferReason
        and facts.kind == "damage" and facts.kindExact
        and facts.melee and facts.reactive and facts.threat == 2.25
        and facts.supplementalFlatThreat == rank.flat
        and facts.runtimeUnverified and Runtime:Evidence(facts),
        "Revenge inference must expose compound threat without a priority")
    actions[spellId] = { spellId = spellId, actor = "player", facts = facts }
end

local calls = dbcCalls
GetSpellRecField = function() error("graph search reread mutable DBC") end
assert(Runtime:Evidence(actions[6572])
    and Runtime:Evidence(actions[25288]) and dbcCalls == calls,
    "sealed Revenge evidence must be search-pure")

dofile("Graph/WarriorRevengeThreat.lua")
local Graph = XelAssist.Graph.WarriorRevengeThreat
XelAssist.Graph.WarriorHeroicStrikeThreat = {
    Is = function() return false end,
    Blocker = function() return nil, false end,
    Augment = function(_, _, left, right)
        return left, right, false, nil
    end,
    AppliedThreat = function() return nil, nil, false, nil end,
}
dofile("Graph/WarriorThreatPackets.lua")
local blocker, handled = Graph:Blocker(actions[6572], {},
    { relation = "hostile" })
assert(blocker == nil and handled,
    "exact Revenge evidence must admit the hostile edge")

local context = { action = actions[6572], kind = "damage",
    effectDelivery = 1, estimated = false }
local threat, valueThreat, augmented, reason = Graph:Augment(
    context, 13 * 2.25, 13 * 2.25)
assert(augmented and not reason and threat == 92.25 and valueThreat == 92.25
    and context.warriorRevengeFlatThreat == 63
    and context.warriorRevengeDamageThreatMultiplier == 2.25
    and context.warriorRevengeThreatProfileExact == false
    and context.estimated,
    "rank-one Revenge must add 63 landed flat threat to 2.25x damage")

context = { action = actions[11601], kind = "damage",
    effectDelivery = 0.5 }
threat, valueThreat = Graph:Augment(context, 50, 40)
assert(threat == 171.5 and valueThreat == 161.5
    and context.warriorRevengeFlatThreat == 121.5,
    "flat Revenge threat must follow hit probability, not armor mitigation")

local applied, exact, projected, transitionReason = Graph:AppliedThreat(
    context, { effectDelivery = 0.5 }, 10)
assert(projected and not transitionReason and applied == 144
    and exact == false,
    "transition threat must combine capped damage and the landed flat packet")

context = { action = actions[25288], kind = "damage", effectDelivery = 1 }
threat = Graph:Augment(context, 0, 0)
assert(threat == 270,
    "rank-six Revenge must preserve its distinct server flat-threat row")

local ordinary = { actor = "player", facts = { kind = "damage" } }
local left, right, claimed = Graph:Augment(
    { action = ordinary }, 20, 19)
assert(left == 20 and right == 19 and not claimed,
    "the Revenge leaf must not claim ordinary damage actions")

local corrupt = { spellId = 6572, actor = "player", facts = {} }
for key, value in pairs(actions[6572].facts) do corrupt.facts[key] = value end
corrupt.facts.supplementalFlatThreat = 64
blocker, handled = Graph:Blocker(corrupt, {}, { relation = "hostile" })
assert(blocker == "Revenge threat evidence unavailable" and handled,
    "incoherent sealed threat evidence must fail closed")

dofile("Game/ActionInference.lua")
local inferred, inferenceReason, inferenceHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(6572)
assert(inferred and inferenceHandled and inferenceReason == nil
    and inferred.warriorRevengeThreat,
    "the production action-inference boundary must claim exact Revenge")
dofile("Graph/ClassEvidence.lua")
blocker, handled = XelAssist.Graph.ClassEvidence:Blocker(
    actions[6572], {}, { relation = "hostile" }, actions[6572].facts, 0)
assert(blocker == nil and handled,
    "the production class-evidence blocker must admit sealed Revenge")

XelAssistCharDB = {}
XelAssist.Graph.PlayerThreat = { Scale = function(_, _, actor, amount)
    assert(actor == "player")
    return amount * 1.3, true, 1.3
end }
dofile("Graph/ThreatScoring.lua")
local scored = { action = actions[6572], facts = actions[6572].facts,
    kind = "damage", state = { tank = true, resourceMax = 100, groupSize = 0 },
    cost = 5, value = 13, fullEffectivePower = 13, effectivePower = 13,
    expectedPower = 13, power = 13, effectDelivery = 1, threatSchool = 0 }
XelAssist.Graph.ThreatScoring:Apply(scored)
assert(math.abs(scored.threat - 119.925) < 0.000001
    and scored.playerThreatExact == false
    and scored.warriorRevengeFlatThreat == 63 and scored.estimated,
    "production scoring must compose compound Revenge threat with stance scaling")

local added
XelAssist.Graph.State = {
    ActiveHostile = function(_, out) return out.active end,
    SyncActiveHostile = function() return true end,
}
XelAssist.Graph.Effects, XelAssist.Graph.AreaRecipients = {}, {}
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
dofile("Graph/HostileEffects.lua")
local hostile = { guid = "hostile-1" }
XelAssist.Graph.HostileEffects:ApplyPrimaryThreat(
    { active = hostile, actors = {} },
    { targetRelation = "hostile", targetGUID = "hostile-1",
        effectDelivery = 1, playerThreatExact = false },
    { action = actions[6572], facts = actions[6572].facts,
        appliedHostileDamage = 10, threatSchool = 0 })
assert(added and added.record == hostile and added.actor == "player"
    and math.abs(added.amount - 111.15) < 0.000001
    and added.exact == false,
    "production transition must recompute capped Revenge damage plus flat threat")

GetSpellRecField = function(spellId, field, array)
    local rank = ranks[spellId]
    if not rank then return nil end
    if not array then
        if field == "baseLevel" or field == "spellLevel" then return rank.level end
        if field == "attributesEx3" then return 0 end
        return common[field]
    end
    if field == "effect" then return { 2, 0, 0 } end
    if field == "effectDieSides" then return { rank.die, 0, 0 } end
    if field == "effectBaseDice" then return { 1, 0, 0 } end
    if field == "effectBasePoints" then return { rank.base, 0, 0 } end
    if field == "effectImplicitTargetA" then return { 6, 0, 0 } end
    return { 0, 0, 0 }
end
Runtime:Invalidate()
local invalid, invalidReason, recognized = Runtime:Classify(6572)
assert(invalid and not invalid.valid and recognized
    and invalidReason == "Revenge DBC topology is incomplete",
    "an installed row mismatch must not fall through to generic name knowledge")

Runtime:Invalidate()
class = "MAGE"
local foreign, foreignReason, foreignHandled = Runtime:InferKnowledge(6572)
assert(foreign == nil and not foreignHandled
    and foreignReason == "player is not an exactly identified Warrior",
    "another class must not receive Warrior Revenge mechanics")

print("ok: exact Warrior Revenge compound threat profile")
