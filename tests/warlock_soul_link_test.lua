XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value) return #value end

local learned, playerClass = true, "WARLOCK"
local dbcReads = 0
local records = {
    [19028] = {
        school = 5, attributes = 336, attributesEx = 268435456,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        durationIndex = 21, baseLevel = 40, spellLevel = 40,
        powerType = 0, manaCost = 0, rangeIndex = 1,
        spellFamilyName = 5,
        description = "Damage is increased by $25228s1% and $25228s2% is split.",
        effect = { 6, 0, 0 }, effectApplyAuraName = { 4, 0, 0 },
        effectImplicitTargetA = { 1, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectTriggerSpell = { 0, 0, 0 },
    },
    [25228] = {
        school = 5, attributes = 537198656, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 1048576, attributesEx4 = 0,
        durationIndex = 21, baseLevel = 40, spellLevel = 40,
        powerType = 0, manaCost = 0, rangeIndex = 1,
        targetCreatureType = 4, spellFamilyName = 5,
        effect = { 119, 119, 0 }, effectApplyAuraName = { 79, 81, 0 },
        effectBasePoints = { 4, 19, 0 }, effectBaseDice = { 1, 1, 0 },
        effectImplicitTargetA = { 1, 1, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectMiscValue = { 127, 127, 0 },
        effectMultipleValue = { 0, 1, 0 },
    },
}

UnitClass = function() return "Localized Warlock", playerClass end
IsPlayerSpell = function(spellId)
    assert(spellId == 19028, "talent knowledge must use stable identity")
    return learned
end
GetSpellRecField = function(spellId, field, array)
    dbcReads = dbcReads + 1
    local value = records[spellId] and records[spellId][field]
    if array == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellName = function()
    error("Soul Link mechanics must not read localized spell names")
end

dofile("Game/Player/WarlockSoulLink.lua")
local Runtime = XelAssist.Game.Player.WarlockSoulLink

local snapshot = Runtime:Snapshot()
assert(snapshot and snapshot.exact and snapshot.available and snapshot.learned
    and snapshot.talentSpellId == 19028 and snapshot.effectSpellId == 25228
    and snapshot.damageMultiplier == 1.05 and snapshot.splitFraction == 0.20,
    "installed linked DBC rows must seal the exact Soul Link profile")
local firstReads = dbcReads
snapshot.damageMultiplier = 99
local second = Runtime:Snapshot("WARLOCK")
assert(second.damageMultiplier == 1.05 and dbcReads == firstReads,
    "profile cache must return immutable copies without repeated DBC work")

learned = false
local absent = Runtime:Snapshot("WARLOCK")
assert(absent and absent.exact and absent.talentKnown
    and absent.learned == false and Runtime:Evidence(absent),
    "an exact unlearned talent must remain distinct from unavailable evidence")
learned = true
assert(Runtime:Snapshot("MAGE") == nil,
    "the Warlock leaf must stay absent for unrelated classes")

local savedKnowledge = IsPlayerSpell
IsPlayerSpell = nil
local unavailable = Runtime:Snapshot("WARLOCK")
assert(unavailable and not unavailable.exact and unavailable.reason,
    "missing broad talent knowledge must fail closed")
IsPlayerSpell = savedKnowledge

Runtime:Invalidate()
records[25228].effectApplyAuraName[2] = 80
local malformed = Runtime:Snapshot("WARLOCK")
assert(malformed and not malformed.exact and malformed.reason,
    "a changed split-aura topology must never retain Soul Link constants")
records[25228].effectApplyAuraName[2] = 81
Runtime:Invalidate()
snapshot = Runtime:Snapshot("WARLOCK")

dofile("Graph/WarlockSoulLink.lua")
local Graph = XelAssist.Graph.WarlockSoulLink

local function state(petHealth)
    local petKey = "g:demon-guid"
    return {
        pet = true,
        actors = { player = { guid = "player-guid" }, pet = {
            guid = "demon-guid", ownerClass = "WARLOCK",
            health = petHealth, healthMax = 100, healthExact = true,
            dead = false, targetExists = true, targetsCurrent = true,
            hasAggro = true,
        } },
        friendlies = { order = { petKey }, byUnit = { pet = petKey },
            byKey = { [petKey] = { key = petKey, unit = "pet",
                guid = "demon-guid", health = petHealth,
                healthMax = 100, exact = true } } },
    }
end

local root = state(100)
assert(Graph:Attach(root, snapshot) and Graph:Active(root),
    "an exact learned profile plus live Warlock demon must activate Soul Link")
local adjusted, known, active = Graph:AdjustOutgoing(root, "player", 200)
assert(adjusted == 210 and known and active,
    "player damage must receive the exact all-school multiplier")
adjusted, known, active = Graph:AdjustOutgoing(root, "pet", 100)
assert(adjusted == 105 and known and active,
    "controlled demon damage must receive the same exact multiplier")
adjusted, known, active = Graph:AdjustOutgoing(root, "enemy", 100)
assert(adjusted == 100 and known and not active,
    "unrelated actors must never inherit Soul Link damage")

local plan = Graph:PlanResidual(root, { kind = "player" }, 80, true)
assert(plan and plan.playerDamage == 64 and plan.petDamage == 16 and plan.exact,
    "only the post-absorb residual may be split twenty percent")
local playerDamage, applied
playerDamage, plan, applied = Graph:ApplyResidual(
    root, { kind = "player" }, 80, true)
assert(applied and playerDamage == 64 and root.actors.pet.health == 84
    and root.friendlies.byKey["g:demon-guid"].health == 84
    and root.lastSoulLinkSplit == plan,
    "split damage must atomically debit and synchronize the controlled demon")

root = state(100)
Graph:Attach(root, snapshot)
playerDamage, plan, applied = Graph:ApplyResidual(
    root, "player", 7, true)
assert(applied and playerDamage == 6 and plan.petDamage == 1,
    "exact server percentage splitting must preserve integer truncation")

root = state(10)
Graph:Attach(root, snapshot)
playerDamage, plan, applied = Graph:ApplyResidual(
    root, "player", 100, true)
assert(applied and playerDamage == 80 and plan.petDamage == 20
    and plan.petDefeated and root.actors.pet.dead and root.pet == false
    and not Graph:Active(root),
    "a lethal split must remove Soul Link from later graph descendants")
adjusted, known, active = Graph:AdjustOutgoing(root, "player", 100)
assert(adjusted == 100 and known and not active,
    "later damage must lose the link bonus after projected demon death")

root = state(100)
Graph:Attach(root, snapshot)
playerDamage, plan, applied = Graph:ApplyResidual(
    root, "player", 12.5, false)
assert(applied and playerDamage == 10 and plan.petDamage == 2.5
    and not plan.exact and root.actors.pet.healthExact == false
    and root.soulLinkSplitPartial,
    "expected incoming damage may split fractionally but must close exact survival")

root = state(100)
Graph:Attach(root, snapshot)
local unchanged, noPlan, handled = Graph:ApplyResidual(
    root, { kind = "pet" }, 80, true)
assert(unchanged == 80 and noPlan == nil and not handled
    and root.actors.pet.health == 100,
    "damage already aimed at the demon must never be split again")

learned = false
absent = Runtime:Snapshot("WARLOCK")
Graph:Attach(root, absent)
adjusted, known, active = Graph:AdjustOutgoing(root, "player", 100)
assert(adjusted == 100 and known and not active,
    "an exactly unlearned Soul Link must be a known neutral profile")
learned = true

root = state(100)
root.actors.pet.ownerClass = nil
Graph:Attach(root, snapshot)
adjusted, known = Graph:AdjustOutgoing(root, "player", 100)
assert(adjusted == 100 and not known,
    "unknown companion ownership must fail closed without guessed damage")

-- Production integration: action potency receives the multiplier once, and
-- hostile incoming damage reaches Soul Link only after the absorb owner.
XelAssist.Combat = {}
XelAssist.Game.Capabilities = {
    BonusDamage = function() return 0 end,
    WeaponDamage = function() return 0 end,
    RangedDamage = function() return 0 end,
}
dofile("Graph/ActionPower.lua")
local integrated = state(100)
integrated.classMechanicClass = "WARLOCK"
Graph:Attach(integrated, snapshot)
local action = { name = "Opaque bolt", rank = 1, actor = "player",
    facts = { kind = "damage" } }
local power = XelAssist.Graph.ActionPower:Estimate(
    action, { average = 100, school = 5, cost = 0 }, integrated)
assert(power == 105,
    "production action power must apply Soul Link outgoing damage once")

XelAssist.Graph.IncomingAbsorbs = {
    Consume = function(_, _, _, damage, probability)
        return math.max(0, damage - 10) * probability, 10, false
    end,
}
dofile("Graph/IncomingConsequences.lua")
integrated.actors.player.health = 100
integrated.actors.player.healthMax = 100
integrated.actors.player.healthExact = true
local result = XelAssist.Graph.IncomingConsequences:Apply(integrated, {
    probability = 1,
    consequence = { kind = "damage", amount = 50, school = 5,
        targetGuid = "player-guid" },
})
assert(result and result.absorbed == 10 and result.soulLinkSplit
    and result.soulLinkSplit.incomingDamage == 40
    and integrated.actors.player.health == 68
    and integrated.actors.pet.health == 92,
    "production incoming path must split only the post-absorb residual")

print("ok: exact causal Warlock Soul Link damage and demon split")
