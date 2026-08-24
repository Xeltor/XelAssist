table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"
NUM_PET_ACTION_SLOTS = 10
local castSlot, attacked, followed, passive

UnitExists = function(unit)
    return unit == "player" or unit == "pet" or unit == "target" or unit == "pettarget"
end
UnitIsDead = function() return false end
UnitIsUnit = function(a, b) return a == "pettarget" and b == "target" end
UnitCreatureFamily = function(unit) return unit == "pet" and "Felhunter" or nil end
UnitCreatureType = function(unit) return unit == "pet" and "Demon" or nil end
UnitHealth = function(unit) return unit == "pet" and 700 or 1000 end
UnitHealthMax = function() return 1000 end
UnitMana = function(unit) return unit == "pet" and 220 or 1000 end
UnitManaMax = function(unit) return unit == "pet" and 300 or 1000 end
UnitXP = function(op, from, to)
    assert(op == "distanceBetween" and from == "pet" and to == "target")
    return 18
end
GetTime = function() return 10 end
GetPetActionInfo = function(slot)
    if slot == 1 then return "Attack", nil, "attack-icon", true, false, false, false end
    if slot == 2 then return "PET_MODE_DEFENSIVE", nil, "defensive-icon", true, true, false, false end
    if slot == 4 then return "Devour Magic", "Rank 2", "devour-icon", false, false, true, false end
    if slot == 5 then return "Spell Lock", "Rank 1", "lock-icon", false, false, false, false end
end
GetSpellName = function(slot, book)
    if book ~= BOOKTYPE_PET then return nil end
    if slot == 1 then return "Devour Magic", "Rank 2" end
    if slot == 2 then return "Spell Lock", "Rank 1" end
end
IsPassiveSpell = function() return false end
GetPetActionCooldown = function(slot)
    if slot == 5 then return 8, 4, 1 end
    return 0, 0, 1
end
CastPetAction = function(slot) castSlot = slot end
PetAttack = function() attacked = true end
PetFollow = function() followed = true end
PetPassiveMode = function() passive = true end

XelAssistCapabilities = {
    Actions = function() return { { name = "Shadow Bolt", actor = "player", facts = { kind = "damage" } } } end,
    InferKnowledge = function() return nil end,
    Facts = function() return { cost = 0, cast = 0, gcd = 0 } end,
    Geometry = function() return { lineOfSight = true, behind = false, source = "test" } end,
}

dofile("XelAssist_Actors.lua")

local pet = XelAssistActors:PetIdentity()
assert(pet and pet.family == "Felhunter" and pet.creatureType == "Demon" and pet.stance == "defensive")
assert(pet.resource == 220 and pet.resourceMax == 300 and pet.targetsCurrent)

local actions = XelAssistActors:Actions()
assert(table.getn(actions) == 6, "player, two pet spells, and three commands should be graph nodes")
local devour, lock
local i
for i = 1, table.getn(actions) do
    if actions[i].name == "Devour Magic" then devour = actions[i] end
    if actions[i].name == "Spell Lock" then lock = actions[i] end
end
assert(devour and devour.actor == "pet" and devour.actionSlot == 4)
assert(devour.autocastAllowed and not devour.autocastEnabled and devour.facts.kind == "dispel")
assert(lock and lock.actionSlot == 5 and lock.facts.kind == "interrupt")
assert(XelAssistActors:PetCooldown(lock) == 2)
assert(XelAssistActors:Execute(lock) and castSlot == 5)
assert(XelAssistActors:Execute(actions[4]) and attacked)
assert(XelAssistActors:Execute(actions[5]) and followed)
assert(XelAssistActors:Execute(actions[6]) and passive)
local actors = XelAssistActors:Snapshot()
assert(actors.player and actors.pet and actors.pet.distance == 18)
print("ok: controlled actor identity, pet spellbook, bar metadata, cooldowns, commands and execution")
