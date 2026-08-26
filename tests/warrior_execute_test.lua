XelAssist = { Game = { Player = {} }, Graph = {} }

local ranks = { [5308] = { 124, 0.3 }, [20658] = { 199, 0.6 },
    [20660] = { 324, 0.9 }, [20661] = { 449, 1.2 },
    [20662] = { 599, 1.5 } }
local malformed = false
UnitClass = function() return "Warrior", "WARRIOR" end
GetSpellRecField = function(spellId, field, copy)
    local rank = ranks[spellId]
    if not rank then return nil end
    local triples = {
        effect = { 3, 64, 0 }, effectTriggerSpell = { 0, 26651, 0 },
        effectDieSides = { 1, 0, 0 }, effectBaseDice = { 1, 0, 0 },
        effectBasePoints = { malformed and rank[1] + 1 or rank[1], 0, 0 },
        dmgMultiplier = { rank[2], 1, 1 },
    }
    if copy then return triples[field] end
    local scalars = { school = 0, spellFamilyName = 4,
        spellFamilyFlags = 536870912, powerType = 1, manaCost = 150,
        targetAuraState = 2 }
    return scalars[field]
end

dofile("Game/Player/WarriorExecute.lua")
dofile("Graph/WarriorExecute.lua")
local Runtime, Graph = XelAssist.Game.Player.WarriorExecute,
    XelAssist.Graph.WarriorExecute

local actions = {}
for spellId, expected in pairs(Runtime.RANKS) do
    local facts, reason, handled = Runtime:InferKnowledge(spellId)
    assert(handled and facts and not reason and facts.warriorExecute
        and facts.warriorExecuteEvidence.baseDamage == expected[1]
        and facts.warriorExecuteEvidence.damagePerRage == expected[2] * 10,
        "installed Execute rank was not classified exactly: " .. spellId)
    actions[spellId] = { spellId = spellId, actor = "player",
        executor = "playerSpell", facts = facts }
end

local action = actions[5308]
local captured = Runtime:CaptureFacts(action, action.facts)
action.facts = captured
local context = { action = action, facts = captured, cost = 15,
    state = { resourceType = 1, resource = 45, playerResourceExact = true } }
local prepared, reason = Graph:Prepare(context)
assert(prepared and not reason and context.power == 215
    and context.warriorExecuteExtraRage == 30 and context.estimated,
    "rank-one Execute must add three damage for each extra displayed rage")

local improved = { action = action, facts = captured, cost = 10,
    state = { resourceType = 1, resource = 45, playerResourceExact = true } }
assert(Graph:Prepare(improved) and improved.power == 230
    and improved.warriorExecuteExtraRage == 35,
    "actual reduced base cost must leave more rage for Execute conversion")

local function candidate(delivery)
    return { action = action, effectDelivery = delivery,
        warriorExecuteExtraRage = 30 }
end
local landed = { resource = 30, playerResourceExact = true }
Graph:Consume(landed, candidate(1))
assert(landed.resource == 0 and landed.playerResourceExact,
    "delivered Execute must consume all remaining rage")
local missed = { resource = 30, playerResourceExact = true }
Graph:Consume(missed, candidate(0))
assert(missed.resource == 30 and missed.playerResourceExact,
    "proven missed Execute must retain rage beyond the paid base cost")
local uncertain = { resource = 30, playerResourceExact = true }
Graph:Consume(uncertain, candidate(0.8))
assert(uncertain.resource == 0 and not uncertain.playerResourceExact
    and uncertain.warriorExecuteResourceRange.minimum == 0
    and uncertain.warriorExecuteResourceRange.maximum == 30,
    "uncertain delivery must carry safe rage bounds rather than fake precision")

context.state.playerResourceExact = false
prepared, reason = Graph:Prepare(context)
assert(not prepared and reason == "exact rage unavailable for Execute",
    "Execute must fail closed when current variable rage is unknown")

malformed = true
Runtime:Invalidate()
local facts, invalidReason, handled = Runtime:InferKnowledge(5308)
assert(handled and not facts
    and invalidReason == "Octo Execute DBC topology is incomplete",
    "a changed Octo rank must not fall through to generic damage")
print("ok: installed Octo Execute damage and hit-side rage bounds")
