table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
local now = 100
GetTime = function() return now end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
    if unit == "target" then return true, "target-guid" end
end
UnitHealth = function() return 800 end
UnitHealthMax = function() return 1000 end
UnitLevel = function(unit) return unit == "target" and 63 or 60 end
UnitClassification = function() return "worldboss" end
UnitCreatureType = function() return "Dragonkin" end
UnitReaction = function() return 2 end
GetRaidTargetIndex = function() return 8 end
UnitAffectingCombat = function() return true end
UnitIsDead = function() return false end
UnitCreatureID = function() return 12345 end
UnitCreatureTypeID = function() return 2 end
UnitCreatureFamilyID = function() return 0 end
UnitOwnerGUID = function() return nil end
UnitIsPlayer = function() return false end
IsInInstance = function() return true, "raid" end
GetRealZoneText = function() return "Test Raid" end
GetSubZoneText = function() return "Boss Room" end
GetMinimapZoneText = function() return "Boss Room" end
C_UnitAuras = { GetUnitAuras = function(_, filter)
    if filter == "HARMFUL" then return { { name = "Immolate", spellId = 348,
        applications = 1, duration = 15, expirationTime = 103,
        sourceUnit = "player", sourceGUID = "player-guid", dispelName = "Magic" } } end
    return {}
end }

dofile("XelAssist_Encounter.lua")
local snapshot = XelAssistEncounter:Snapshot()
assert(snapshot.inInstance and snapshot.instanceType == "raid" and snapshot.zone == "Test Raid")
assert(snapshot.target.creatureId == 12345 and snapshot.target.classification == "worldboss")
local aura = snapshot.targetHarmful.byName.Immolate
assert(aura and aura.mine and aura.remaining == 3 and aura.spellId == 348 and aura.dispelType == "Magic")
print("ok: encounter identity, location and owned timed aura state")
