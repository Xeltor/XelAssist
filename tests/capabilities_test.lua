table.getn = table.getn or function(t) return #t end
BOOKTYPE_SPELL = "spell"
UIParent = {}
GetTime = function() return 10 end
UnitLevel = function() return 60 end

local tooltipLines = {
    [2] = { left = "50 Mana", right = "30 yd range" },
    [3] = { left = "Deals 100 to 120 Frost damage.", right = nil },
}
local tooltip = {}
tooltip.SetOwner = function() end
tooltip.ClearLines = function() end
tooltip.SetSpell = function() end
CreateFrame = function() return tooltip end
getglobal = function(name)
    local side, index = string.find(name, "TextLeft") and "left" or "right", tonumber(string.gsub(name, "%D", ""))
    local value = tooltipLines[index] and tooltipLines[index][side]
    if not value then return nil end
    return { GetText = function() return value end }
end

GetSpellName = function(slot)
    if slot == 1 then return "Frostbolt", "Rank 1" end
    if slot == 2 then return "Frostbolt", "Rank 2" end
    return nil
end
GetSpellSlotTypeIdForName = function(name)
    if name == "Frostbolt(Rank 1)" then return 1, "spell", 116 end
    if name == "Frostbolt(Rank 2)" then return 2, "spell", 205 end
    return 0, "unknown", 0
end
GetSpellRecField = function(_, field)
    local values = { castTime = 2500, recoveryTime = 8000, categoryRecoveryTime = 6000,
        category = 44, startRecoveryTime = 1500, rangeIndex = 7, manaCost = 60,
        school = 4, spellLevel = 20 }
    if field == "effectBasePoints" then return { 89, 0, 0 } end
    if field == "effectDieSides" then return { 20, 0, 0 } end
    if field == "effectRealPointsPerLevel" then return { 1, 0, 0 } end
    if field == "effectPointsPerComboPoint" then return { 0, 0, 0 } end
    return values[field]
end
GetSpellRangeData = function(index)
    assert(index == 7); return 8, 30, 0, "Long Range"
end
GetSpellDuration = function() return 12000 end
GetSpellIdCooldown = function() return { gcdCategoryRemainingMs = 300 } end
GetUnitField = function(unit, field)
    if unit == "target" and field == "health" then return 4321 end
    if unit == "target" and field == "maxHealth" then return 9876 end
    return nil
end
UnitExists = function() return true end
UnitXP = function(operation, from, unit)
    assert(operation == "distanceBetween" and from == "player" and unit == "target")
    return 6.5
end
UnitDistanceSquared = function() return 400 end
IsSpellUsable = function() return 1, 0 end
local passiveSpell = false
IsPassiveSpell = function() return passiveSpell end
GetNumTalentTabs = function() return 2 end
GetNumTalents = function(tab) return tab == 1 and 2 or 1 end
GetTalentInfo = function(tab, talent)
    local ranks = { [1] = { 5, 3 }, [2] = { 2 } }
    return "Talent", nil, 1, 1, ranks[tab][talent]
end

dofile("XelAssist_Actions.lua")
dofile("XelAssist_Capabilities.lua")

local actions = XelAssistCapabilities:Actions()
assert(table.getn(actions) == 2, "all learned ranks should become graph nodes")
assert(actions[1].spellId == 116 and actions[2].spellId == 205, "ranked spell IDs were not resolved")
assert(XelAssistCapabilities:CastName(actions[1]) == "Frostbolt(Rank 1)")

local facts = XelAssistCapabilities:Facts(actions[1])
assert(facts.cost == 50, "talent-adjusted tooltip cost should override base DBC cost")
assert(facts.cast == 2.5 and facts.gcd == 1.5 and facts.cooldown == 8)
assert(facts.cooldownGroup == 44 and facts.categoryCooldown == 6)
assert(facts.minRange == 8 and facts.maxRange == 30 and facts.duration == 12)
assert(facts.average == 110 and facts.school == 4)
assert(facts.dbcAverage and facts.dbcAverage > 100, "DBC effect magnitude missing")
assert(XelAssistCapabilities:GCDRemaining() == 0.3)
local health, maximum, exact = XelAssistCapabilities:Health("target")
assert(health == 4321 and maximum == 9876 and exact == true)
assert(XelAssistCapabilities:Usable(actions[1]) == true)
local distance, distanceKind = XelAssistCapabilities:Distance("target")
assert(distance == 6.5 and distanceKind == "hitbox", "NPC-capable UnitXP distance must have priority")
assert(XelAssistCapabilities:TalentPoints() == 10, "talent evidence was not read")
tooltipLines[2] = { left = "Heals a friendly target for 100 to 120.", right = nil }
tooltipLines[3] = { left = "2 sec cast", right = "30 yd range" }
local inferred = XelAssistCapabilities:InferKnowledge(9)
assert(inferred and inferred.kind == "heal" and inferred.inferred, "unknown healing spell was not inferred")
passiveSpell = true
assert(XelAssistCapabilities:InferKnowledge(9) == nil, "passive spells must never become inferred actions")
print("ok: ranked spell IDs, talent/DBC facts, tooltip overrides, GCD and exact health")
