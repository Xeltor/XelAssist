XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"
NUM_PET_ACTION_SLOTS = 10
local castSlot, attacked, followed, passive
local petGuid = {}
local playerGuid, targetGuid = {}, {}
local ownerClass, hidePetCost = "WARLOCK", false
local petFamily = "Felhunter"
local warlockBarRank = "Rank 2"

UnitClass = function(unit)
    if unit == "player" then return ownerClass == "HUNTER" and "Hunter" or "Warlock", ownerClass end
end

UnitExists = function(unit)
    if unit == "player" then return true, playerGuid end
    if unit == "pet" then return true, petGuid end
    if unit == "target" or unit == "pettarget" then return true, targetGuid end
    return false, nil
end
UnitIsDead = function() return false end
UnitIsUnit = function(a, b) return a == "pettarget" and b == "target" end
UnitCreatureFamily = function(unit) return unit == "pet" and petFamily or nil end
UnitCreatureType = function(unit)
    return unit == "pet" and (ownerClass == "HUNTER" and "Beast" or "Demon") or nil
end
UnitHealth = function(unit) return unit == "pet" and 700 or 1000 end
UnitHealthMax = function() return 1000 end
UnitMana = function(unit) return unit == "pet" and 220 or 1000 end
UnitManaMax = function(unit) return unit == "pet" and 300 or 1000 end
UnitAttackPower = function(unit)
    assert(unit == "pet")
    return 410, 25, -10
end
UnitXP = function(op, from, to)
    assert(op == "distanceBetween" and from == "pet" and to == "target")
    return 18
end
GetTime = function() return 10 end
GetPetActionInfo = function(slot)
    if slot == 1 then return "Attack", nil, "attack-icon", true, false, false, false end
    if slot == 2 then return "PET_MODE_DEFENSIVE", nil, "defensive-icon", true, true, false, false end
    if ownerClass == "HUNTER" then
        if slot == 4 then return "Bite", "Rank 8", "bite-icon", false, false, true, false end
        if slot == 5 then return "Growl", "Rank 7", "growl-icon", false, false, true, false end
        if slot == 6 then return "Prowl", "Rank 3", "prowl-icon", false, false, true, false end
        if slot == 7 then return "Thunderstomp", "Rank 4", "stomp-icon", false, false, true, true end
        return nil
    end
    if slot == 4 then return "Devour Magic", warlockBarRank, "devour-icon", false, false, true, true end
    if slot == 5 then return "Spell Lock", "Rank 1", "lock-icon", false, false, false, false end
end
GetSpellName = function(slot, book)
    if book ~= BOOKTYPE_PET then return nil end
    if ownerClass == "HUNTER" then
        if slot == 1 then return "Bite", "Rank 8" end
        if slot == 2 then return "Growl", "Rank 7" end
        if slot == 3 then return "Prowl", "Rank 3" end
        if slot == 4 then return "Thunderstomp", "Rank 4" end
        return nil
    end
    if slot == 1 then return "Devour Magic", "Rank 1" end
    if slot == 2 then return "Devour Magic", "Rank 2" end
    if slot == 3 then return "Devour Magic", "Rank 3" end
    if slot == 4 then return "Spell Lock", "Rank 1" end
end
GetSpellSlotTypeIdForName = function(name)
    if name == "Bite(Rank 8)" then return 1, BOOKTYPE_PET, 17261 end
    if name == "Growl(Rank 7)" then return 2, BOOKTYPE_PET, 14921 end
    if name == "Prowl(Rank 3)" then return 3, BOOKTYPE_PET, 24453 end
    if name == "Thunderstomp(Rank 4)" then return 4, BOOKTYPE_PET, 51156 end
    if name == "Devour Magic(Rank 1)" then return 0, BOOKTYPE_PET, 0 end
    if name == "Devour Magic(Rank 2)" then return 1, BOOKTYPE_PET, 19731 end
    if name == "Devour Magic(Rank 3)" then return 3, BOOKTYPE_PET, 19734 end
    if name == "Spell Lock(Rank 1)" then return 4, BOOKTYPE_PET, 19244 end
    return 0, "unknown", 0
end
GetSpellIdForName = function(name)
    if name == "Devour Magic(Rank 1)" then return 19505 end
    return 0
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

XelAssist.Game.Capabilities = {
    Actions = function() return { { name = "Shadow Bolt", actor = "player", facts = { kind = "damage" } } } end,
    InferKnowledge = function() return nil end,
    Facts = function(_, action)
        return { cost = not (hidePetCost and action
                and action.name == "Thunderstomp") and 0 or nil,
            cast = 0, gcd = 0 }
    end,
    Geometry = function() return { lineOfSight = true, behind = false, source = "test" } end,
    UnitRef = function(_, unit, relation, source)
        local exists, guid = UnitExists(unit)
        if not exists or guid == nil then return nil end
        return { unit = unit, guid = guid, relation = relation, source = source }
    end,
    SameUnitRef = function(_, ref)
        local exists, guid = UnitExists(ref.unit)
        return exists and guid == ref.guid
    end,
}

dofile("Combat/PetKnowledge.lua")
dofile("Game/Pets/Effects.lua")
dofile("Game/Pets/EffectRuntime.lua")
dofile("Game/Actors.lua")

local idFirst = XelAssist.Combat.PetKnowledge:Facts(2649, "Spell Lock", "HUNTER")
assert(idFirst and idFirst.kind == "petThreat" and idFirst.petThreatGain == 50
    and idFirst.petKnowledgeName == "Growl"
    and idFirst.petKnowledgeSource == "octowow dbc id",
    "spell ID must outrank a conflicting fallback name")
local hunterFallback = XelAssist.Combat.PetKnowledge:Facts(nil, "Screech", "HUNTER")
assert(hunterFallback and hunterFallback.kind == "damage" and hunterFallback.aoe
    and hunterFallback.petKnowledgeSource == "name fallback")
local cower = XelAssist.Combat.PetKnowledge:Facts(16697, "Cower", "HUNTER")
assert(cower and cower.kind == "petThreat" and cower.petThreatDrop == 225)
local familyById = XelAssist.Combat.PetKnowledge:Family(9, "Cat", "HUNTER")
assert(familyById and familyById.name == "Gorilla" and familyById.source == "octowow dbc id")
assert(not XelAssist.Combat.PetKnowledge:Facts(2649, "Growl", "WARLOCK"),
    "known owner class must prevent cross-class pet semantics")

local pet = XelAssist.Game.Actors:PetIdentity()
assert(pet and pet.family == "Felhunter" and pet.creatureType == "Demon" and pet.stance == "defensive")
assert(pet.resource == 220 and pet.resourceMax == 300 and pet.targetsCurrent
    and pet.targetGuid == targetGuid and pet.targetGuidKnown,
    "every controlled companion must retain its exact hostile target identity")
assert(pet.attackPowerKnown and pet.attackPower == 425,
    "controlled actor snapshots must expose exact live pet attack power")

local actions = XelAssist.Game.Actors:Actions()
assert(table.getn(actions) == 6, "player, two pet spells, and three commands should be graph nodes")
local devour, lock, devourCount = nil, nil, 0
local i
for i = 1, table.getn(actions) do
    if actions[i].name == "Devour Magic" then
        devour, devourCount = actions[i], devourCount + 1
    end
    if actions[i].name == "Spell Lock" then lock = actions[i] end
end
assert(devourCount == 1 and devour and devour.actor == "pet"
    and devour.actionSlot == 4 and devour.rankText == "Rank 2"
    and devour.spellId == 19731,
    "one pet bar slot must emit exactly its matching learned rank")
assert(devour.autocastAllowed and devour.autocastEnabled
    and devour.facts.kind == "dispel")
assert(lock and lock.actionSlot == 5 and lock.facts.kind == "interrupt")
assert(lock.actorRef and lock.actorRef.guid == petGuid,
    "pet actions must capture the opaque actor identity used for discovery")
assert(XelAssist.Game.Actors:PetCooldown(lock) == 2)
assert(XelAssist.Game.Actors:Execute(lock) and castSlot == 5)
assert(XelAssist.Game.Actors:Execute(actions[4]) and attacked)
assert(XelAssist.Game.Actors:Execute(actions[5]) and followed)
assert(XelAssist.Game.Actors:Execute(actions[6]) and passive)
local dispatchedSlot = castSlot
petGuid = {}
assert(not XelAssist.Game.Actors:Execute(lock) and castSlot == dispatchedSlot,
    "a stale pet action must not dispatch after the pet identity changes")
local replacementActions = XelAssist.Game.Actors:Actions()
local replacementLock
for i = 1, table.getn(replacementActions) do
    if replacementActions[i].name == "Spell Lock" then replacementLock = replacementActions[i] end
end
assert(replacementLock and replacementLock.actorRef.guid == petGuid
    and replacementLock.actorRef.guid ~= lock.actorRef.guid,
    "pet replacement must rebuild actions against the replacement identity")
local actors = XelAssist.Game.Actors:Snapshot()
assert(actors.player and actors.pet and actors.pet.distance == 18)
assert(table.getn(actors.pet.autocasts) == 1
    and actors.pet.autocasts[1].name == "Devour Magic"
    and actors.pet.autocasts[1].spellId == 19731,
    "one enabled pet bar slot must project exactly one matching-rank autocast")

warlockBarRank = "Rank 1"
XelAssist.Game.Actors:Invalidate()
local firstSlotActions = XelAssist.Game.Actors:Actions()
local firstSlotDevour
for i = 1, table.getn(firstSlotActions) do
    if firstSlotActions[i].name == "Devour Magic" then
        firstSlotDevour = firstSlotActions[i]
    end
end
assert(firstSlotDevour and firstSlotDevour.spellId == 19505,
    "a native first-slot zero ID must use the exact GetSpellIdForName fallback")

warlockBarRank = "Rank 99"
XelAssist.Game.Actors:Invalidate()
local fallbackActions = XelAssist.Game.Actors:Actions()
local fallbackDevour, fallbackCount = nil, 0
for i = 1, table.getn(fallbackActions) do
    if fallbackActions[i].name == "Devour Magic" then
        fallbackDevour, fallbackCount = fallbackActions[i], fallbackCount + 1
    end
end
assert(fallbackCount == 1 and fallbackDevour
    and fallbackDevour.rankText == "Rank 3" and fallbackDevour.spellId == 19734,
    "an unreadable pet bar rank must deterministically bind the highest learned rank")

ownerClass, petFamily, petGuid = "HUNTER", "Cat", {}
XelAssist.Game.Actors:Invalidate()
local hunterPet = XelAssist.Game.Actors:PetIdentity()
assert(hunterPet and hunterPet.ownerClass == "HUNTER" and hunterPet.familyId == 2
    and hunterPet.familySkillLine == 209 and hunterPet.creatureType == "Beast")
local hunterActions = XelAssist.Game.Actors:Actions()
assert(table.getn(hunterActions) == 8,
    "player, four Hunter pet actions, and three commands should be graph nodes")
local bite, growl, prowl, stomp
for i = 1, table.getn(hunterActions) do
    local action = hunterActions[i]
    if action.name == "Bite" then bite = action end
    if action.name == "Growl" then growl = action end
    if action.name == "Prowl" then prowl = action end
    if action.name == "Thunderstomp" then stomp = action end
end
assert(bite and bite.spellId == 17261 and bite.facts.kind == "damage"
    and bite.facts.petKnowledgeSource == "octowow dbc id")
assert(growl and growl.facts.kind == "petThreat"
    and growl.facts.petThreatGain == 415)
assert(prowl and prowl.facts.kind == "buff" and prowl.facts.self and prowl.facts.stealth)
assert(stomp and stomp.facts.kind == "damage" and stomp.facts.aoe
    and stomp.facts.school == 3 and stomp.facts.threat > 1)
local bestial = { name = "Bestial Wrath", spellId = 19574, facts = {
    petCombatBuff = true, petCombatEffects = {
        { key = "control-immunity", duration = 18,
            crowdControlImmune = true, sourceSpellId = 19574 },
        { key = "damage-enrage", duration = 8,
            damageMultiplier = 1.4, sourceSpellId = 52995 },
    } } }
local runtime = XelAssist.Game.Pets.EffectRuntime
runtime:Reset()
assert(runtime:Submitted(bestial, petGuid, nil, playerGuid)
    and runtime:ObserveCast(19574, playerGuid, petGuid, "go"))
hidePetCost = true
local reconstructed = XelAssist.Game.Actors:Snapshot().pet
assert(reconstructed.combatEffects["Bestial Wrath:damage-enrage"].remaining == 8
    and reconstructed.combatEffects["Bestial Wrath:control-immunity"].remaining == 18,
    "every fresh actor/graph snapshot must reconstruct confirmed pet effects")
assert(reconstructed.areaAutocastUnknown
    and table.getn(reconstructed.autocasts) == 1
    and reconstructed.autocasts[1].name == "Thunderstomp"
    and reconstructed.autocasts[1].cost == nil,
    "enabled pet autocasts must preserve area and unreadable-cost uncertainty")
print("ok: controlled identity plus ID-first Warlock and Hunter pet semantics")
