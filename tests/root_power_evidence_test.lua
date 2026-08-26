table.getn = table.getn or function(value) return #value end
XelAssist = { Game = {}, Graph = {}, Combat = {} }
XelAssistCharDB = {}
BOOKTYPE_SPELL = "spell"

local calls = { basis = 0, melee = 0, ranged = 0, bonus = 0 }
GetTime = function() return 100 end
GetSpellCooldown = function() return 0, 0 end
GetPetActionsUsable = function() return true end

XelAssist.Game.WeaponPower = { Basis = function(_, action, facts)
    calls.basis = calls.basis + 1
    local lane = action.facts.ranged and facts.school == 0 and 200 or 100
    local normalized = facts.weaponNormalized and 10 or 0
    return lane + normalized, { exact = true, lane = lane,
        normalized = facts.weaponNormalized and true or false }
end }
XelAssist.Game.Capabilities = {
    Usable = function() return true end,
    WeaponDamage = function()
        calls.melee = calls.melee + 1
        return 80
    end,
    RangedDamage = function()
        calls.ranged = calls.ranged + 1
        return 90
    end,
    BonusDamage = function(_, school)
        calls.bonus = calls.bonus + 1
        return school == 5 and 25 or 0
    end,
}
XelAssist.Game.Actors = { Facts = function(_, action)
    local facts = action.facts
    return { cost = 10, cast = 0, gcd = 1.5, average = 50,
        school = facts.school, dbcAverage = 50,
        weaponCoefficient = facts.weaponCoefficient,
        weaponNormalized = facts.weaponNormalized }
end }
XelAssist.Graph.ResistanceEvidence = nil
XelAssist.Graph.TargetSelection = { Targets = function() return {} end }

dofile("Game/RootPowerEvidence.lua")
dofile("Graph/RootActionFacts.lua")
dofile("Graph/RootObservation.lua")

local actions = {}
for index = 1, 20 do
    actions[index] = { name = "Melee Rank " .. index, rank = index,
        slot = index, spellId = 1000 + index, actor = "player",
        executor = "playerSpell", facts = { kind = "damage", melee = true,
            school = 0, weaponCoefficient = 1, weaponNormalized = true } }
end
for index = 21, 30 do
    actions[index] = { name = "Shadow Rank " .. index, rank = index,
        slot = index, spellId = 1000 + index, actor = "player",
        executor = "playerSpell", facts = { kind = "damage", school = 5 } }
end
actions[31] = { name = "String-school ranged", rank = 1, slot = 31,
    spellId = 1031, actor = "player", executor = "playerSpell",
    facts = { kind = "damage", ranged = true, school = "0",
        weaponCoefficient = 1, weaponNormalized = true } }
actions[32] = { name = "Ranged normalized", rank = 1, slot = 32,
    spellId = 1032, actor = "player", executor = "playerSpell",
    facts = { kind = "damage", ranged = true, school = 0,
        weaponCoefficient = 1, weaponNormalized = true } }
actions[33] = { name = "Melee ordinary", rank = 1, slot = 33,
    spellId = 1033, actor = "player", executor = "playerSpell",
    facts = { kind = "damage", melee = true, school = 0,
        weaponCoefficient = 1 } }

local state = { inventory = {} }
local observed = assert(XelAssist.Graph.RootObservation:Begin(state, actions, 100))
local steps = 0
while not XelAssist.Graph.RootObservation:Step(observed) do
    steps = steps + 1
    assert(steps < 100, "root power capture did not finish")
end
assert(XelAssist.Graph.RootObservation:Seal(observed))
assert(calls.basis == 3,
    "rank actions must share melee normalized, ranged normalized and ordinary lanes")
assert(calls.melee == 1 and calls.ranged == 1,
    "DBC weapon additions must query each live damage lane once")
assert(calls.bonus == 3,
    "spell power must be captured once for each distinct school")

local sealed = assert(XelAssist.Graph.RootObservation:Actions(state))
local first = assert(XelAssist.Graph.RootObservation:Power(state, sealed[1]))
local twentieth = assert(XelAssist.Graph.RootObservation:Power(state, sealed[20]))
local shadow = assert(XelAssist.Graph.RootObservation:Power(state, sealed[21]))
local ranged = assert(XelAssist.Graph.RootObservation:Power(state, sealed[32]))
assert(first.weaponBasis == 110 and twentieth.weaponBasis == 110
    and ranged.weaponBasis == 210,
    "shared lanes must retain the correct immutable basis")
assert(shadow.bonusDamage == 25 and shadow.bonusKnown == true,
    "school-local spell power must remain exact")

XelAssist.Game.WeaponPower.Basis = function() error("sealed basis reread") end
XelAssist.Game.Capabilities.BonusDamage = function() error("sealed bonus reread") end
assert(XelAssist.Graph.RootObservation:Power(state, sealed[1]).weaponBasis == 110,
    "sealed power evidence must not reread mutable APIs")

print("ok: root power evidence shares live lanes across ranks")
