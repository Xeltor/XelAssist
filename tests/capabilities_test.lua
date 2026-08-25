XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
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
    if spellId == 172 then
        local corruption = {
            castTime = 1500, recoveryTime = 0, categoryRecoveryTime = 0,
            category = 0, startRecoveryTime = 1500,
            startRecoveryCategory = 133, rangeIndex = 7, manaCost = 35,
            attributes = 0, school = 5, spellLevel = 1, baseLevel = 1,
            maxLevel = 60, attributesEx4 = 0,
            effect = { 6, 0, 0 }, effectApplyAuraName = { 3, 0, 0 },
            effectBasePoints = { 9, 0, 0 },
            effectBaseDice = { 1, 0, 0 }, effectDieSides = { 1, 0, 0 },
            effectDicePerLevel = { 0, 0, 0 },
            effectRealPointsPerLevel = { 0, 0, 0 },
            effectAmplitude = { 3000, 0, 0 },
            effectPointsPerComboPoint = { 0, 0, 0 },
        }
        return corruption[field]
    end
    if spellId == 348 and field == "effect" then return { 2, 6, 0 } end
    if spellId == 348 and field == "effectApplyAuraName" then return { 0, 3, 0 } end
    if spellId == 348 and field == "effectAmplitude" then return { 0, 3000, 0 } end
    if spellId == 2973 then
        local raptor = { attributes = 4, startRecoveryCategory = 0,
            startRecoveryTime = 1500, school = 0 }
        return raptor[field]
    end
    if spellId == 2974 then
        local replacement = { attributes = 1024, startRecoveryCategory = 0,
            startRecoveryTime = 1500, school = 0 }
        return replacement[field]
    end
    if spellId == 78 then
        local heroic = { attributes = 4, startRecoveryCategory = 0,
            startRecoveryTime = 0, school = 0, powerType = 1,
            manaCost = 150 }
        return heroic[field]
    end
    local values = { castTime = 2500, recoveryTime = 8000, categoryRecoveryTime = 6000,
        category = 44, startRecoveryTime = 1500, startRecoveryCategory = 133,
        rangeIndex = 7, manaCost = 60, attributes = 0,
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
UnitDistanceSquared = function() return 400, true end
IsSpellUsable = function() return 1, 0 end
local passiveSpell = false
IsPassiveSpell = function() return passiveSpell end
GetNumTalentTabs = function() return 2 end
GetNumTalents = function(tab) return tab == 1 and 2 or 1 end
GetTalentInfo = function(tab, talent)
    local ranks = { [1] = { 5, 3 }, [2] = { 2 } }
    return "Talent", nil, 1, 1, ranks[tab][talent]
end

dofile("Combat/Knowledge.lua")
dofile("Game/SpellTiming.lua")
dofile("Game/SpellClassification.lua")
dofile("Game/SpellPower.lua")
dofile("Game/SpellEffectPower.lua")
dofile("Game/SpellFactCache.lua")
dofile("Game/Range.lua")
dofile("Game/ResourceCost.lua")
dofile("Game/Capabilities.lua")
dofile("Graph/ActionPower.lua")

local savedGetCastInfo, savedGetCurrentCastingInfo = GetCastInfo,
    GetCurrentCastingInfo
GetCastInfo = function()
    return { spellId = 116, castRemainingMs = 1250,
        gcdRemainingMs = 300, castType = 3 }
end
local _, castRemaining, casting, gcdRemaining, channeling, castSpellId =
    XelAssist.Game.Capabilities:CurrentCast()
assert(casting and channeling and castRemaining == 1.25 and gcdRemaining == 0.3
    and castSpellId == 116,
    "the detailed cast record must preserve native channel state")
GetCastInfo = nil
GetCurrentCastingInfo = function() return 116, 0, 0, 0, 1 end
_, castRemaining, casting, gcdRemaining, channeling, castSpellId =
    XelAssist.Game.Capabilities:CurrentCast()
assert(casting and channeling and castRemaining == 0 and gcdRemaining == 0
    and castSpellId == 116,
    "the compatibility cast API must preserve its channel flag")
GetCastInfo, GetCurrentCastingInfo = savedGetCastInfo,
    savedGetCurrentCastingInfo

local actions = XelAssist.Game.Capabilities:Actions()
assert(table.getn(actions) == 2, "all learned ranks should become graph nodes")
assert(actions[1].spellId == 116 and actions[2].spellId == 205, "ranked spell IDs were not resolved")
assert(XelAssist.Game.Capabilities:CastName(actions[1]) == "Frostbolt(Rank 1)")

local facts = XelAssist.Game.Capabilities:Facts(actions[1])
assert(facts.cost == 50, "talent-adjusted tooltip cost should override base DBC cost")
assert(facts.cast == 2.5 and facts.gcd == 1.5 and facts.cooldown == 8)
assert(facts.cooldownGroup == 44 and facts.categoryCooldown == 6)
assert(facts.minRange == 8 and facts.maxRange == 30 and facts.duration == 12)
assert(facts.average == 110 and facts.school == 4)
assert(facts.attributesEx4 == 1 and facts.ignoresResistances == true,
    "DBC ignore-resistance attribute missing")
assert(facts.attributes == 0 and facts.onNextSwing == false
    and facts.startRecoveryCategory == 133 and facts.normalGcd == true,
    "DBC normal-GCD classification missing")
local raptorFacts = XelAssist.Game.Capabilities:Facts({ name = "Raptor Strike",
    slot = 3, spellId = 2973, bookType = BOOKTYPE_SPELL,
    facts = { kind = "damage", melee = true } })
assert(raptorFacts.attributes == 4 and raptorFacts.onNextSwing == true
    and raptorFacts.normalGcd == false,
    "DBC on-next-swing classification must not require typed action metadata")
local replacementFacts = XelAssist.Game.Capabilities:Facts({ name = "Replacement",
    slot = 4, spellId = 2974, bookType = BOOKTYPE_SPELL,
    facts = { kind = "damage", melee = true } })
assert(replacementFacts.attributes == 1024
    and replacementFacts.onNextSwing == true,
    "alternate DBC on-next-swing classification missing")
local savedTooltipLines = tooltipLines
tooltipLines = {}
local heroicFacts = XelAssist.Game.Capabilities:Facts({ name = "Heroic Strike",
    slot = 5, spellId = 78, bookType = BOOKTYPE_SPELL,
    facts = { kind = "damage", melee = true } })
tooltipLines = savedTooltipLines
assert(heroicFacts.powerType == 1 and heroicFacts.cost == 15,
    "raw DBC rage costs must be normalized from tenths to displayed rage")
assert(facts.dbcAverage and facts.dbcAverage > 100, "DBC effect magnitude missing")
assert(XelAssist.Game.Capabilities:GCDRemaining() == 0.3)
local health, maximum, exact = XelAssist.Game.Capabilities:Health("target")
assert(health == 4321 and maximum == 9876 and exact == true)
assert(XelAssist.Game.Capabilities:Usable(actions[1]) == true)
local distance, distanceKind = XelAssist.Game.Capabilities:Distance("target")
assert(distance == 6.5 and distanceKind == "hitbox", "NPC-capable UnitXP distance must have priority")
local savedUnitXP = UnitXP
UnitXP = nil
UnitDistanceSquared = function() return 0, false end
distance, distanceKind = XelAssist.Game.Capabilities:Distance("target")
assert(distance == nil and distanceKind == nil,
    "an unchecked ClassicAPI position must not become a real zero-yard distance")
UnitDistanceSquared = function() return 400, true end
distance, distanceKind = XelAssist.Game.Capabilities:Distance("target")
assert(distance == 20 and distanceKind == "center",
    "a checked center-distance fallback must remain available")
UnitXP = savedUnitXP

local savedUnitExists, savedUnitCanAssist, savedUnitIsDead = UnitExists, UnitCanAssist, UnitIsDead
local opaqueA, opaqueB = {}, {}
local liveGuid, liveExists, liveAssist, liveDead = opaqueA, true, true, false
UnitExists = function(unit)
    if not liveExists then return nil, nil end
    return true, liveGuid
end
UnitCanAssist = function(from, unit)
    assert(from == "player" and unit == "party1")
    return liveAssist
end
UnitIsDead = function(unit)
    assert(unit == "party1" or unit == "player")
    return liveDead
end
local allyRef = XelAssist.Game.Capabilities:UnitRef("party1", "friendly", "party")
assert(allyRef and allyRef.unit == "party1" and allyRef.guid == opaqueA
    and allyRef.relation == "friendly" and allyRef.source == "party",
    "friendly references must retain their transient token and untouched opaque GUID")
assert(XelAssist.Game.Capabilities:SameUnitRef(allyRef), "unchanged token identity must validate")
local validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(allyRef)
assert(validatedUnit == "party1" and validationReason == nil,
    "a live assistable reference must remain castable")
liveGuid = opaqueB
assert(not XelAssist.Game.Capabilities:SameUnitRef(allyRef),
    "a reused roster token must not match the snapshotted GUID")
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(allyRef)
assert(validatedUnit == nil and validationReason == "ally changed",
    "a reused roster token must request a fresh graph snapshot")
liveGuid, liveAssist = opaqueA, false
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(allyRef)
assert(validatedUnit == nil and validationReason == "ally no longer friendly",
    "a unit that is no longer assistable must not remain castable")
liveAssist, liveDead = true, true
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(allyRef)
assert(validatedUnit == nil and validationReason == "ally defeated",
    "a defeated friendly must not remain castable")
liveDead, liveExists = false, false
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(allyRef)
assert(validatedUnit == nil and validationReason == "ally unavailable",
    "a missing friendly must not remain castable")
assert(XelAssist.Game.Capabilities:UnitRef("party1", "friendly", "party") == nil,
    "an unavailable unit cannot produce an identity reference")
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef({ unit = "party1" })
assert(validatedUnit == nil and validationReason == "ally identity unavailable",
    "a reference without an opaque GUID must fail closed")
liveExists, liveGuid, liveAssist = true, opaqueA, false
local selfRef = XelAssist.Game.Capabilities:UnitRef("player", "self", "self")
validatedUnit, validationReason = XelAssist.Game.Capabilities:ValidateFriendlyRef(selfRef)
assert(validatedUnit == "player" and validationReason == nil,
    "self validation must not depend on the friendly-reaction API")
UnitExists, UnitCanAssist, UnitIsDead = savedUnitExists, savedUnitCanAssist, savedUnitIsDead

local rangeName, rangeUnit, rangeResult = nil, nil, 0
IsSpellInRange = function(name, unit)
    rangeName, rangeUnit = name, unit
    return rangeResult
end
assert(XelAssist.Game.Capabilities:InRange("Flash Heal(Rank 1)", "party1") == false
    and rangeName == "Flash Heal(Rank 1)" and rangeUnit == "party1",
    "authoritative range queries must receive the explicit friendly unit")
rangeResult = 1
assert(XelAssist.Game.Capabilities:InRange("Flash Heal(Rank 1)", "mouseover") == true
    and rangeUnit == "mouseover", "mouseover range must use its own unit token")
rangeResult = -1
assert(XelAssist.Game.Capabilities:InRange("Flash Heal(Rank 1)", "party1") == nil,
    "unsupported range verdicts must remain unknown")
local classicResult = false
C_Spell = { IsSpellInRange = function(name, unit)
    assert(name == "Attack" and unit == "target")
    return classicResult
end }
rangeResult = 1
assert(XelAssist.Game.Capabilities:InRange("Attack", "target") == false,
    "an exact geometric rejection must veto a permissive global verdict")
classicResult, rangeResult = nil, 0
assert(XelAssist.Game.Capabilities:InRange("Attack", "target") == false,
    "an explicit Nampower rejection must survive an unknown geometric verdict")
C_Spell.IsSpellInRange = function() error("unavailable") end
rangeResult = 1
assert(XelAssist.Game.Capabilities:InRange("Attack", "target") == true,
    "a failed geometric query must retain a positive Nampower verdict")
C_Spell = nil
IsSpellInRange = nil
assert(XelAssist.Game.Capabilities:InRange("Flash Heal(Rank 1)", "party1") == nil,
    "a missing range API must remain unknown")

assert(XelAssist.Game.Capabilities:TalentPoints() == 10, "talent evidence was not read")
local weaponSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(weaponSkills.main.total == 280 and weaponSkills.off.total == 263
    and weaponSkills.ranged.total == 294 and weaponSkills.unarmed.total == 242,
    "current main/off/ranged and independent unarmed skills must remain distinct")
assert(weaponSkills.dualWield and weaponSkills.mainToken ~= weaponSkills.offToken,
    "off-hand weapon state must be explicit in the skill fingerprint")
assert(weaponSkills.dualWieldKnown and not weaponSkills.offHandBroken,
    "a usable off hand must have durability-proven dual-wield state")
offHandBroken = true
local brokenOffHandSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(brokenOffHandSkills.dualWieldKnown and brokenOffHandSkills.offHandBroken
    and not brokenOffHandSkills.dualWield and not brokenOffHandSkills.off,
    "a broken off hand must not activate the server's white dual-wield miss penalty")
offHandBroken = false
local savedBrokenAPI = GetInventoryItemBroken
GetInventoryItemBroken = nil
local uncertainOffHandSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(uncertainOffHandSkills.dualWield and not uncertainOffHandSkills.dualWieldKnown,
    "unknown off-hand durability must retain the conservative dual-wield table and expose uncertainty")
GetInventoryItemBroken = savedBrokenAPI
stableFormId, formIndex = 1, 2
local feralSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(feralSkills.formId == 1 and feralSkills.formSource == "ClassicAPI form ID"
    and feralSkills.noWeaponForm and feralSkills.mainToken == "form:1",
    "Cat Form must fingerprint the stable form instead of its ignored equipped weapon")
assert(feralSkills.main.total == 300 and not feralSkills.dualWield and not feralSkills.off,
    "no-weapon shapeshifts must use level-max feral skill without an off hand")
stableFormId, formIndex = 31, 3
local moonkinSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(not moonkinSkills.noWeaponForm and moonkinSkills.mainToken == weaponSkills.mainToken
    and moonkinSkills.dualWield and moonkinSkills.formWeaponUseKnown,
    "a weapon-using Druid form must retain the equipped weapon fingerprint")
stableFormId, formIndex = 99, 4
local customFormSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(not customFormSkills.formWeaponUseKnown
    and string.find(customFormSkills.mainToken, "form?:99:", 1, true) == 1,
    "an unverified custom form must partition its weapon rule instead of inheriting a stock form")
stableFormId, formIndex, unitBytes1 = nil, 1, 5 * 65536
local nampowerFeral = XelAssist.Game.Capabilities:WeaponSkills()
assert(nampowerFeral.formId == 5 and nampowerFeral.mainToken == "form:5"
    and nampowerFeral.formSource == "Nampower form field",
    "Nampower UNIT_FIELD_BYTES_1 must recover the stable Bear Form ID")
stableFormId, formIndex, unitBytes1 = 0, 0, nil
local savedBothHands, savedRanged = UnitAttackBothHands, UnitRangedAttack
UnitAttackBothHands, UnitRangedAttack = nil, nil
weaponSkills = XelAssist.Game.Capabilities:WeaponSkills()
assert(weaponSkills.main.total == 254 and weaponSkills.off.total == 221
    and weaponSkills.ranged.total == 233,
    "numeric item subclass plus localized skill lines must provide a safe API fallback")
UnitAttackBothHands, UnitRangedAttack = savedBothHands, savedRanged
local penetration = XelAssist.Game.Capabilities:Penetration()
assert(penetration.known and penetration.spell == 25 and penetration.armor == 40,
    "equipped penetration tooltip scan failed")
local scans = inventoryTooltipScans
penetration = XelAssist.Game.Capabilities:Penetration()
assert(inventoryTooltipScans == scans and penetration.spell == 25,
    "unchanged equipment penetration should use its cache")
equippedLinks[3] = "|Hitem:104:0:0:0|h[Stronger Armor Breaker]|h"
equippedTooltipLines[3][2].left = "Equip: Your attacks ignore 55 of the target's armor."
penetration = XelAssist.Game.Capabilities:Penetration()
assert(inventoryTooltipScans > scans and penetration.armor == 55,
    "equipment link changes must invalidate penetration automatically")
XelAssist.Game.Capabilities:Invalidate()
local savedInventoryAPI = GetInventoryItemLink
GetInventoryItemLink = nil
penetration = XelAssist.Game.Capabilities:Penetration()
assert(not penetration.known and penetration.spell == 0 and penetration.armor == 0,
    "missing inventory API must keep penetration unknown")
GetInventoryItemLink = savedInventoryAPI
tooltipLines[2] = { left = "Curses the target, reducing Fire and Frost resistances by 45 and increasing Fire and Frost damage taken by 6%.", right = nil }
tooltipLines[3] = { left = "Lasts 300 sec", right = "30 yd range" }
local resistanceDebuff = XelAssist.Game.Capabilities:Facts({ name = "Curse of Elements", slot = 2,
    spellId = 200, bookType = BOOKTYPE_SPELL })
assert(resistanceDebuff.targetResistanceReduction[2] == 45
    and resistanceDebuff.targetResistanceReduction[4] == 45
    and resistanceDebuff.targetDamageTaken[2] == 0.06
    and resistanceDebuff.targetDamageTaken[4] == 0.06,
    "target resistance/damage-taken tooltip semantics missing")
local partyModifier = XelAssist.Game.Capabilities:TargetModifierFacts(300,
    { resistanceDebuff = true, modifierGroup = "curseElements" })
assert(partyModifier.targetResistanceReduction[2] == 45
    and partyModifier.targetResistanceReduction[4] == 45
    and partyModifier.targetDamageTaken[2] == 0.06,
    "party-applied target modifiers must be recoverable from DBC arrays without a spellbook slot")
tooltipLines[2] = { left = "Finishing move that exposes the target, reducing armor by 450 per combo point.", right = nil }
tooltipLines[3] = { left = "Lasts 30 sec", right = nil }
local armorDebuff = XelAssist.Game.Capabilities:Facts({ name = "Expose Armor", slot = 3,
    spellId = 201, bookType = BOOKTYPE_SPELL })
assert(armorDebuff.targetArmorReduction == 450 and armorDebuff.targetArmorPerCombo,
    "target Armor reduction tooltip semantics missing")
tooltipLines[2] = { left = "Burns the enemy for 25 to 35 Fire damage and then an additional 60 Fire damage over 15 sec.", right = nil }
tooltipLines[3] = { left = "2 sec cast", right = "30 yd range" }
local hybrid = XelAssist.Game.Capabilities:Facts({ name = "Immolate", slot = 4,
    spellId = 348, bookType = BOOKTYPE_SPELL, facts = { kind = "dot" } })
assert(hybrid.directDamage == 30 and hybrid.periodicDamage == 60
    and hybrid.average == 90 and hybrid.periodicInterval == 3
    and hybrid.damageTotalSource == "tooltip"
    and hybrid.periodicIntervalSource == "client DBC effectAmplitude",
    "hybrid damage and authoritative DBC tick cadence must remain separable")
tooltipLines[2] = { left = "Corrupts the target, causing 40 Shadow damage over 12 sec.", right = nil }
tooltipLines[3] = { left = "1.5 sec cast", right = "30 yd range" }
local gerundDot = XelAssist.Game.Capabilities:Facts({ name = "Corruption", slot = 5,
    spellId = 172, bookType = BOOKTYPE_SPELL, facts = { kind = "dot" } })
assert(gerundDot.average == 40 and gerundDot.damageTotalSource == "tooltip",
    "a complete periodic total using 'causing' must not collapse to one DBC tick")
tooltipLines[2] = { left = "Deals 10 Shadow damage every 3 sec over 12 sec.", right = nil }
tooltipLines[3] = { left = "1.5 sec cast", right = "30 yd range" }
local perTickAction = { name = "Corruption", slot = 7, spellId = 172,
    bookType = BOOKTYPE_SPELL, rank = 1, facts = { kind = "dot" } }
local perTickDot = XelAssist.Game.Capabilities:Facts(perTickAction)
assert(perTickDot.average == 10 and perTickDot.damageTotalSource == nil
    and perTickDot.dbcEffectAverage == 40
    and perTickDot.dbcEffectPeriodicDamage == 40
    and perTickDot.dbcEffectComplete,
    "a per-tick tooltip must retain the complete four-tick DBC total")
local perTickPower, perTickEstimated, perTickEvidence =
    XelAssist.Graph.ActionPower:Estimate(perTickAction, perTickDot, {}, "target-guid")
assert(perTickPower == 40 and perTickEstimated
    and perTickEvidence and perTickEvidence.complete
    and perTickEvidence.periodic == 40,
    "ActionPower must choose the complete DBC total over a per-tick tooltip value")
tooltipLines[2] = { left = "Deals 10 Fire damage.", right = nil }
local firstDemon = { name = "Firebolt", slot = 6, spellId = 3110,
    bookType = "pet", actor = "pet", actorRef = { guid = "demon-a" },
    facts = { kind = "damage" } }
local firstDemonFacts = XelAssist.Game.Capabilities:Facts(firstDemon)
tooltipLines[2] = { left = "Deals 20 Fire damage.", right = nil }
local cachedDemonFacts = XelAssist.Game.Capabilities:Facts(firstDemon)
local replacementDemonFacts = XelAssist.Game.Capabilities:Facts({ name = "Firebolt",
    slot = 6, spellId = 3110, bookType = "pet", actor = "pet",
    actorRef = { guid = "demon-b" }, facts = { kind = "damage" } })
assert(firstDemonFacts.average == 10 and cachedDemonFacts.average == 10
    and replacementDemonFacts.average == 20,
    "a replacement pet must not inherit tooltip facts from the prior identity's reused slot")
tooltipLines[2] = { left = "Heals a friendly target for 100 to 120.", right = nil }
tooltipLines[3] = { left = "2 sec cast", right = "30 yd range" }
local inferred = XelAssist.Game.Capabilities:InferKnowledge(9)
assert(inferred and inferred.kind == "heal" and inferred.inferred, "unknown healing spell was not inferred")
passiveSpell = true
assert(XelAssist.Game.Capabilities:InferKnowledge(9) == nil, "passive spells must never become inferred actions")
print("ok: ranked spell IDs, DBC facts, tooltip penetration cache, GCD and exact health")
