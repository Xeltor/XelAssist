table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = {} }
XelAssistDB = { untouched = true }
NUM_PET_ACTION_SLOTS = 10

local classToken = "HUNTER"
local clock = 100
local petPresent = true
local petDead = false
local petGuid = {}
local petName = "Sable"
local petFamily = "Wolf"
local petTargetGuid = {}
local petFocus = 62
local attackBarActive = false
local hasPetUIOverride
local abandoned = false
local registered = {}

UnitClass = function() return "Hunter", classToken end
GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "pet" then return petPresent, petPresent and petGuid or nil end
    if unit == "pettarget" then
        return petPresent and petTargetGuid ~= nil, petPresent and petTargetGuid or nil
    end
    return unit == "player", nil
end
UnitName = function(unit) return unit == "pet" and petName or nil end
UnitCreatureFamily = function(unit) return unit == "pet" and petFamily or nil end
UnitHealth = function(unit) return unit == "pet" and (petDead and 0 or 731) or 0 end
UnitHealthMax = function(unit) return unit == "pet" and 900 or 0 end
UnitMana = function(unit) return unit == "pet" and petFocus or 0 end
UnitManaMax = function(unit) return unit == "pet" and 100 or 0 end
UnitIsDead = function(unit) return unit == "pet" and petDead end
HasPetUI = function()
    if hasPetUIOverride ~= nil then return hasPetUIOverride and 1 or nil, "HUNTER" end
    return petPresent and 1 or nil, "HUNTER"
end
GetPetHappiness = function() return 3, 125, 1 end
GetPetLoyalty = function() return "Beste vriend" end
GetPetExperience = function() return 321, 800 end
GetPetTrainingPoints = function() return 42, 17 end
GetPetFoodTypes = function() return "Meat", "Fish" end
GetPetActionInfo = function(slot)
    if slot == 1 then return "PET_ATTACK", nil, nil, true, attackBarActive end
end
PetAbandon = function() abandoned = true end

CreateFrame = function()
    return {
        RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(self, name, handler) self[name] = handler end
    }
end

dofile("Game/Pets/FocusEvidence.lua")
dofile("Game/Pets/FocusEvents.lua")
dofile("Game/Pets/Resources.lua")
dofile("Game/Pets/State.lua")
local S = XelAssist.Game.Pets.State

local snapshot = S:Snapshot()
assert(snapshot.supported and snapshot.lifecycle == "alive" and snapshot.present)
assert(snapshot.guid == petGuid and snapshot.guidKnown)
assert(snapshot.name == "Sable" and snapshot.family == "Wolf")
assert(snapshot.health == 731 and snapshot.healthMax == 900)
assert(snapshot.focus == 62 and snapshot.focusMax == 100)
assert(snapshot.happiness == 3 and snapshot.damagePercentage == 125
    and snapshot.loyaltyRate == 1)
assert(snapshot.loyaltyText == "Beste vriend",
    "localized loyalty evidence must remain raw text")
assert(snapshot.experience == 321 and snapshot.experienceNext == 800)
assert(snapshot.trainingTotal == 42 and snapshot.trainingSpent == 17
    and snapshot.trainingAvailable == 25)
assert(snapshot.foodTypesKnown and table.getn(snapshot.foodTypes) == 2
    and snapshot.foodTypes[1] == "Meat" and snapshot.foodTypes[2] == "Fish")
assert(snapshot.hasPetUIKnown and snapshot.hasPetUI and snapshot.petUIType == "HUNTER")
assert(snapshot.targetExists and snapshot.targetGuid == petTargetGuid)
assert(snapshot.lastKnown.guid == petGuid and snapshot.lastKnown.name == "Sable"
    and snapshot.lastKnown.family == "Wolf")
assert(not snapshot.attackActive and snapshot.attackActiveKnown)
assert(registered.PLAYER_PET_CHANGED and registered.PET_DISMISS_START
    and registered.UNIT_HAPPINESS and registered.UNIT_PET_TRAINING_POINTS)

assert(S:OnEvent("PET_ATTACK_START", nil, petGuid))
attackBarActive = true
snapshot = S:Snapshot()
assert(snapshot.attackActive and snapshot.attackActiveKnown)

petFocus, clock = 72, 104
assert(S:OnEvent("UNIT_FOCUS", "pet", petGuid))
petFocus, clock = 82, 108
assert(S:OnEvent("UNIT_FOCUS", "pet", petGuid))
petFocus, clock = 92, 112
assert(S:OnEvent("UNIT_FOCUS", "pet", petGuid))
snapshot = S:Snapshot()
assert(snapshot.resourceRegenKnown and snapshot.resourceRegen.verified
    and snapshot.resourceRegen.amount == 10
    and snapshot.resourceRegen.observedInterval == 4
    and snapshot.resourceRegen.interval == 4.8
    and not snapshot.resourceRegen.phaseKnown,
    "lifecycle snapshot must carry same-identity learned focus evidence")
snapshot.resourceRegen.interval = 1
assert(S.live.resourceRegen.interval == 4.8,
    "resource clocks must be copied out of live observation state")

petDead = true
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "dead" and snapshot.present and snapshot.guid == petGuid,
    "a defeated pet must remain observable by lifecycle")
assert(not snapshot.resourceRegenKnown and snapshot.resourceRegen == nil,
    "same-identity death must invalidate the learned focus regime")
assert(not S:OnEvent("PET_ATTACK_START", nil, petGuid),
    "a defeated pet cannot acquire an attacking state")
petDead = false
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "alive" and not snapshot.resourceRegenKnown,
    "same-identity revival must require fresh focus evidence")

local rememberedGuid = petGuid
petPresent = false
hasPetUIOverride = true
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "unknown" and not snapshot.present,
    "unexplained absence must never be inferred as dismissal")
assert(snapshot.hasPetUI,
    "pet UI evidence alone must not turn an absent pet into a lifecycle guess")
assert(snapshot.lastKnown.guid == rememberedGuid and snapshot.lastKnown.name == "Sable")
hasPetUIOverride = nil

S:ResetSession()
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "unknown" and snapshot.lastKnown == nil,
    "last-known identity is session state, not persistent configuration")

petPresent = true
petGuid = {}
petName, petFamily = "Ember", "Cat"
snapshot = S:Snapshot()
local dismissedGuid = petGuid
assert(snapshot.lifecycle == "alive")
assert(S:OnEvent("PET_DISMISS_START", nil, dismissedGuid))
assert(S.live.lifecycle == "alive" and S.live.dismissalPending,
    "dismiss start is only pending evidence while the pet remains present")
petPresent = false
assert(S:OnEvent("PLAYER_PET_CHANGED"))
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "dismissed" and snapshot.lastKnown.guid == dismissedGuid,
    "explicit dismiss evidence plus disappearance is a dismissal")

petPresent = true
petGuid = {}
petName, petFamily = "Quill", "Wind Serpent"
snapshot = S:Snapshot()
local oldGuid, replacementGuid = petGuid, {}
assert(S:OnEvent("PET_DISMISS_START", nil, oldGuid))
petGuid = replacementGuid
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "alive" and snapshot.guid == replacementGuid
    and not snapshot.dismissalPending,
    "replacement identity must clear the old pet dismissal evidence")
assert(not S:OnEvent("PET_ATTACK_STOP", nil, oldGuid),
    "stale events carrying an old opaque GUID must be ignored")

petPresent = false
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "unknown",
    "replacement loss must not inherit the old pet dismissal evidence")

petPresent = true
petGuid = {}
snapshot = S:Snapshot()
assert(S:OnEvent("PET_DISMISS_START", nil, petGuid))
clock = clock + 9
petPresent = false
snapshot = S:Snapshot()
assert(snapshot.lifecycle == "unknown",
    "expired dismiss-start evidence must not classify a later disappearance")

local before = S:Snapshot()
classToken = "MAGE"
S:ResetSession()
local unsupported = S:Snapshot()
assert(not unsupported.supported and unsupported.lifecycle == "unknown")
assert(XelAssistDB.untouched and not abandoned,
    "pet identity is session-only and this observer must never abandon a pet")
assert(before.lastKnown and before.lastKnown.guid ~= nil)

print("ok: Hunter pet lifecycle, identity, happiness, training, diet and stale-event evidence")
