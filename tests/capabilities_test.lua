table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
UIParent = {}
GetTime = function() return 10 end
UnitLevel = function() return 60 end
GetLocale = function() return "enUS" end

local tooltipLines = {
    [2] = { left = "50 Mana", right = "30 yd range" },
    [3] = { left = "Deals 100 to 120 Frost damage.", right = nil },
}
local equippedLinks = {
    [1] = "|Hitem:100:0:0:0|h[Penetrating Hood]|h",
    [2] = "|Hitem:101:0:0:0|h[Focused Amulet]|h",
    [3] = "|Hitem:102:0:0:0|h[Armor Breaker]|h",
    [5] = "|Hitem:103:0:0:0|h[Insight Vest]|h",
    [6] = "|Hitem:105:0:0:0|h[Insight Belt]|h",
    [7] = "|Hitem:106:0:0:0|h[Dormant Breaker]|h",
    [16] = "|Hitem:200:0:0:0|h[Test Sword]|h",
    [17] = "|Hitem:201:0:0:0|h[Test Dagger]|h",
    [18] = "|Hitem:202:0:0:0|h[Test Bow]|h",
}
local equippedTooltipLines = {
    [1] = { [2] = { left = "Equip: Decreases the magical resistances of your spell targets by 12." } },
    [2] = { [2] = { left = "+8 Spell Penetration" } },
    [3] = { [2] = { left = "Equip: Your attacks ignore 40 of the target's armor." } },
    [5] = {
        [2] = { left = "Insight (2/2)" },
        [3] = { left = "Set: Decreases the magical resistances of your spell targets by 5.",
            color = { 0, 1, 0 } },
    },
    [6] = {
        [2] = { left = "Insight (2/2)" },
        [3] = { left = "Set: Decreases the magical resistances of your spell targets by 5.",
            color = { 0, 1, 0 } },
    },
    [7] = {
        [2] = { left = "Dormant Might (1/2)" },
        [3] = { left = "Set: Your attacks ignore 99 of the target's armor.",
            color = { 0.5, 0.5, 0.5 } },
    },
}
local activeTooltipLines = tooltipLines
local inventoryTooltipScans = 0
local tooltip = {}
tooltip.SetOwner = function() end
tooltip.ClearLines = function() end
tooltip.SetSpell = function() activeTooltipLines = tooltipLines end
tooltip.SetInventoryItem = function(_, _, slot)
    inventoryTooltipScans = inventoryTooltipScans + 1
    activeTooltipLines = equippedTooltipLines[slot] or {}
    return equippedLinks[slot] ~= nil
end
tooltip.NumLines = function()
    local highest, index = 0, nil
    for index in pairs(activeTooltipLines) do if index > highest then highest = index end end
    return highest
end
CreateFrame = function() return tooltip end
local localizedGlobals = { UNARMED = "Unarmed", SWORDS = "Swords",
    DAGGERS = "Daggers", BOWS = "Bows" }
getglobal = function(name)
    if localizedGlobals[name] then return localizedGlobals[name] end
    local side, index = string.find(name, "TextLeft") and "left" or "right", tonumber(string.gsub(name, "%D", ""))
    local row = activeTooltipLines[index]
    local value = row and row[side]
    if not value then return nil end
    return { GetText = function() return value end,
        GetTextColor = function()
            local color = row.color or { 1, 1, 1 }
            return color[1], color[2], color[3]
        end }
end
GetInventoryItemLink = function(_, slot) return equippedLinks[slot] end
GetInventoryItemTexture = function(_, slot) return equippedLinks[slot] and "texture" or nil end
GetItemStatsField = function(itemId, field)
    local records = { [200] = { class = 2, subclass = 7 },
        [201] = { class = 2, subclass = 15 }, [202] = { class = 2, subclass = 2 } }
    return records[itemId] and records[itemId][field]
end
UnitAttackBothHands = function() return 275, 5, 260, 3 end
UnitRangedAttack = function() return 290, 4 end
UnitAttackSpeed = function() return 2.5, 1.8 end
local offHandBroken = false
GetInventoryItemBroken = function(unit, slot)
    assert(unit == "player" and slot == 17)
    return offHandBroken
end
local formIndex, stableFormId = 0, 0
GetShapeshiftForm = function() return formIndex end
GetShapeshiftFormID = function() return stableFormId end
GetNumSkillLines = function() return 4 end
GetSkillLineInfo = function(index)
    local rows = {
        { "Unarmed", false, nil, 240, 0, 2, 300 },
        { "Swords", false, nil, 250, 0, 4, 300 },
        { "Daggers", false, nil, 220, 0, 1, 300 },
        { "Bows", false, nil, 230, 0, 3, 300 },
    }
    local row = rows[index]
    if row then return row[1], row[2], row[3], row[4], row[5], row[6], row[7] end
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
GetSpellRecField = function(spellId, field)
    if spellId == 300 then
        local modifier = { effect = { 6, 6, 0 }, effectApplyAuraName = { 22, 87, 0 },
            effectBasePoints = { -46, 5, 0 }, effectMiscValue = { 20, 20, 0 } }
        return modifier[field]
    end
    local values = { castTime = 2500, recoveryTime = 8000, categoryRecoveryTime = 6000,
        category = 44, startRecoveryTime = 1500, rangeIndex = 7, manaCost = 60,
        school = 4, spellLevel = 20, attributesEx4 = 1 }
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
local unitBytes1
GetUnitField = function(unit, field)
    if unit == "player" and field == "bytes1" then return unitBytes1 end
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
assert(facts.attributesEx4 == 1 and facts.ignoresResistances == true,
    "DBC ignore-resistance attribute missing")
assert(facts.dbcAverage and facts.dbcAverage > 100, "DBC effect magnitude missing")
assert(XelAssistCapabilities:GCDRemaining() == 0.3)
local health, maximum, exact = XelAssistCapabilities:Health("target")
assert(health == 4321 and maximum == 9876 and exact == true)
assert(XelAssistCapabilities:Usable(actions[1]) == true)
local distance, distanceKind = XelAssistCapabilities:Distance("target")
assert(distance == 6.5 and distanceKind == "hitbox", "NPC-capable UnitXP distance must have priority")
assert(XelAssistCapabilities:TalentPoints() == 10, "talent evidence was not read")
local weaponSkills = XelAssistCapabilities:WeaponSkills()
assert(weaponSkills.main.total == 280 and weaponSkills.off.total == 263
    and weaponSkills.ranged.total == 294 and weaponSkills.unarmed.total == 242,
    "current main/off/ranged and independent unarmed skills must remain distinct")
assert(weaponSkills.dualWield and weaponSkills.mainToken ~= weaponSkills.offToken,
    "off-hand weapon state must be explicit in the skill fingerprint")
assert(weaponSkills.dualWieldKnown and not weaponSkills.offHandBroken,
    "a usable off hand must have durability-proven dual-wield state")
offHandBroken = true
local brokenOffHandSkills = XelAssistCapabilities:WeaponSkills()
assert(brokenOffHandSkills.dualWieldKnown and brokenOffHandSkills.offHandBroken
    and not brokenOffHandSkills.dualWield and not brokenOffHandSkills.off,
    "a broken off hand must not activate the server's white dual-wield miss penalty")
offHandBroken = false
local savedBrokenAPI = GetInventoryItemBroken
GetInventoryItemBroken = nil
local uncertainOffHandSkills = XelAssistCapabilities:WeaponSkills()
assert(uncertainOffHandSkills.dualWield and not uncertainOffHandSkills.dualWieldKnown,
    "unknown off-hand durability must retain the conservative dual-wield table and expose uncertainty")
GetInventoryItemBroken = savedBrokenAPI
stableFormId, formIndex = 1, 2
local feralSkills = XelAssistCapabilities:WeaponSkills()
assert(feralSkills.formId == 1 and feralSkills.formSource == "ClassicAPI form ID"
    and feralSkills.noWeaponForm and feralSkills.mainToken == "form:1",
    "Cat Form must fingerprint the stable form instead of its ignored equipped weapon")
assert(feralSkills.main.total == 300 and not feralSkills.dualWield and not feralSkills.off,
    "no-weapon shapeshifts must use level-max feral skill without an off hand")
stableFormId, formIndex = 31, 3
local moonkinSkills = XelAssistCapabilities:WeaponSkills()
assert(not moonkinSkills.noWeaponForm and moonkinSkills.mainToken == weaponSkills.mainToken
    and moonkinSkills.dualWield and moonkinSkills.formWeaponUseKnown,
    "a weapon-using Druid form must retain the equipped weapon fingerprint")
stableFormId, formIndex = 99, 4
local customFormSkills = XelAssistCapabilities:WeaponSkills()
assert(not customFormSkills.formWeaponUseKnown
    and string.find(customFormSkills.mainToken, "form?:99:", 1, true) == 1,
    "an unverified custom form must partition its weapon rule instead of inheriting a stock form")
stableFormId, formIndex, unitBytes1 = nil, 1, 5 * 65536
local nampowerFeral = XelAssistCapabilities:WeaponSkills()
assert(nampowerFeral.formId == 5 and nampowerFeral.mainToken == "form:5"
    and nampowerFeral.formSource == "Nampower form field",
    "Nampower UNIT_FIELD_BYTES_1 must recover the stable Bear Form ID")
stableFormId, formIndex, unitBytes1 = 0, 0, nil
local savedBothHands, savedRanged = UnitAttackBothHands, UnitRangedAttack
UnitAttackBothHands, UnitRangedAttack = nil, nil
weaponSkills = XelAssistCapabilities:WeaponSkills()
assert(weaponSkills.main.total == 254 and weaponSkills.off.total == 221
    and weaponSkills.ranged.total == 233,
    "numeric item subclass plus localized skill lines must provide a safe API fallback")
UnitAttackBothHands, UnitRangedAttack = savedBothHands, savedRanged
local penetration = XelAssistCapabilities:Penetration()
assert(penetration.known and penetration.spell == 25 and penetration.armor == 40,
    "equipped penetration tooltip scan failed")
local scans = inventoryTooltipScans
penetration = XelAssistCapabilities:Penetration()
assert(inventoryTooltipScans == scans and penetration.spell == 25,
    "unchanged equipment penetration should use its cache")
equippedLinks[3] = "|Hitem:104:0:0:0|h[Stronger Armor Breaker]|h"
equippedTooltipLines[3][2].left = "Equip: Your attacks ignore 55 of the target's armor."
penetration = XelAssistCapabilities:Penetration()
assert(inventoryTooltipScans > scans and penetration.armor == 55,
    "equipment link changes must invalidate penetration automatically")
XelAssistCapabilities:Invalidate()
local savedInventoryAPI = GetInventoryItemLink
GetInventoryItemLink = nil
penetration = XelAssistCapabilities:Penetration()
assert(not penetration.known and penetration.spell == 0 and penetration.armor == 0,
    "missing inventory API must keep penetration unknown")
GetInventoryItemLink = savedInventoryAPI
tooltipLines[2] = { left = "Curses the target, reducing Fire and Frost resistances by 45 and increasing Fire and Frost damage taken by 6%.", right = nil }
tooltipLines[3] = { left = "Lasts 300 sec", right = "30 yd range" }
local resistanceDebuff = XelAssistCapabilities:Facts({ name = "Curse of Elements", slot = 2,
    spellId = 200, bookType = BOOKTYPE_SPELL })
assert(resistanceDebuff.targetResistanceReduction[2] == 45
    and resistanceDebuff.targetResistanceReduction[4] == 45
    and resistanceDebuff.targetDamageTaken[2] == 0.06
    and resistanceDebuff.targetDamageTaken[4] == 0.06,
    "target resistance/damage-taken tooltip semantics missing")
local partyModifier = XelAssistCapabilities:TargetModifierFacts(300,
    { resistanceDebuff = true, modifierGroup = "curseElements" })
assert(partyModifier.targetResistanceReduction[2] == 45
    and partyModifier.targetResistanceReduction[4] == 45
    and partyModifier.targetDamageTaken[2] == 0.06,
    "party-applied target modifiers must be recoverable from DBC arrays without a spellbook slot")
tooltipLines[2] = { left = "Finishing move that exposes the target, reducing armor by 450 per combo point.", right = nil }
tooltipLines[3] = { left = "Lasts 30 sec", right = nil }
local armorDebuff = XelAssistCapabilities:Facts({ name = "Expose Armor", slot = 3,
    spellId = 201, bookType = BOOKTYPE_SPELL })
assert(armorDebuff.targetArmorReduction == 450 and armorDebuff.targetArmorPerCombo,
    "target Armor reduction tooltip semantics missing")
tooltipLines[2] = { left = "Burns the enemy for 25 to 35 Fire damage and then an additional 60 Fire damage over 15 sec.", right = nil }
tooltipLines[3] = { left = "2 sec cast", right = "30 yd range" }
local hybrid = XelAssistCapabilities:Facts({ name = "Immolate", slot = 4,
    spellId = 348, bookType = BOOKTYPE_SPELL })
assert(hybrid.directDamage == 30 and hybrid.periodicDamage == 60 and hybrid.average == 90,
    "hybrid direct/periodic tooltip damage must remain separable")
tooltipLines[2] = { left = "Heals a friendly target for 100 to 120.", right = nil }
tooltipLines[3] = { left = "2 sec cast", right = "30 yd range" }
local inferred = XelAssistCapabilities:InferKnowledge(9)
assert(inferred and inferred.kind == "heal" and inferred.inferred, "unknown healing spell was not inferred")
passiveSpell = true
assert(XelAssistCapabilities:InferKnowledge(9) == nil, "passive spells must never become inferred actions")
print("ok: ranked spell IDs, DBC facts, tooltip penetration cache, GCD and exact health")
