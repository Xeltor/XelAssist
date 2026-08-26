table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function row(mana, base, sides, level, maximum)
    return { spellFamilyName = 5, school = 2, category = 631,
        castingTimeIndex = 171, categoryRecoveryTime = 30000,
        rangeIndex = 4, powerType = 0, manaCost = mana,
        manaCostPerlevel = 0, manaCostPercentage = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0,
        spellLevel = level, maxLevel = maximum,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        effect = { 2, 0, 0 }, effectImplicitTargetA = { 6, 0, 0 },
        effectTriggerSpell = { 0, 0, 0 },
        effectBasePoints = { base - 1, 0, 0 },
        effectBaseDice = { 1, 0, 0 }, effectDieSides = { sides, 0, 0 },
        reagent = { 6265, 0, 0, 0, 0, 0, 0, 0 },
        reagentCount = { 1, 0, 0, 0, 0, 0, 0, 0 } }
end
local rows = { [51683] = row(305, 623, 161, 46, 52),
    [51684] = row(335, 703, 179, 54, 60) }
function UnitClass() return "Warlock", "WARLOCK" end
function GetSpellRecField(spellId, field, arrays)
    local value = rows[spellId] and rows[spellId][field]
    if arrays and type(value) == "table" then return value end
    if not arrays and type(value) == "number" then return value end
end

dofile("Game/Player/WarlockSoulFire.lua")
local SoulFire = XelAssist.Game.Player.WarlockSoulFire
local spellId
for _, spellId in ipairs({ 51683, 51684 }) do
    local facts, reason, handled = SoulFire:InferKnowledge(spellId)
    assert(handled and not reason and facts and facts.kind == "damage"
        and facts.kindExact and facts.ranged and facts.reagent
        and facts.reagentName == "Soul Shard"
        and facts.soulFireEvidence.shardItemId == 6265
        and facts.soulFireEvidence.shardCount == 1
        and facts.soulFireEvidence.baseDamage
            == (spellId == 51683 and 623 or 703),
        "each patch-5 Soul Fire rank must seal direct damage and one shard")
end

local unrelated, unrelatedReason, unrelatedHandled =
    SoulFire:InferKnowledge(686)
assert(not unrelated and not unrelatedReason and not unrelatedHandled,
    "unrelated Warlock spells must not be claimed")

rows[51683].reagentCount = { 0, 0, 0, 0, 0, 0, 0, 0 }
SoulFire:Invalidate()
local malformed, malformedReason, malformedHandled =
    SoulFire:InferKnowledge(51683)
assert(not malformed and malformedHandled
    and malformedReason == "Octo Soul Fire DBC topology is incomplete",
    "a free or shifted Soul Fire reagent topology must fail closed")
rows[51683] = row(305, 623, 161, 46, 52)
SoulFire:Invalidate()
local facts = assert(SoulFire:InferKnowledge(51683))

dofile("Graph/ActionConsumption.lua")
local state = { resource = 400,
    inventory = { reagentCounts = { ["Soul Shard"] = 2 } } }
local action = { actor = "player", spellId = 51683, facts = facts }
assert(XelAssist.Graph.ActionConsumption:Consume(state,
        { action = action, cost = 305 }, {})
    and state.resource == 95
    and state.inventory.reagentCounts["Soul Shard"] == 1,
    "a chosen Soul Fire must atomically spend its mana and exact shard")

UnitClass = function() return "Mage", "MAGE" end
SoulFire:Invalidate()
local wrongClass, _, wrongClassHandled = SoulFire:InferKnowledge(51684)
assert(not wrongClass and not wrongClassHandled,
    "numeric Soul Fire identities belong only to the Warlock player")

print("ok: exact patch-5 Soul Fire direct damage and Soul Shard payment")
