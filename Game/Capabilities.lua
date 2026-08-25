XelAssist.Game.Capabilities = {}
local C = XelAssist.Game.Capabilities
local TIP_NAME = "XelAssistScanTip"
local scanTip
local function tooltipText(slot, bookType)
    if not scanTip then scanTip = CreateFrame("GameTooltip", TIP_NAME, nil, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE"); scanTip:ClearLines()
    scanTip:SetSpell(slot, bookType or BOOKTYPE_SPELL)
    local text, i = "", nil
    for i = 2, 12 do
        local left = getglobal(TIP_NAME .. "TextLeft" .. i)
        local right = getglobal(TIP_NAME .. "TextRight" .. i)
        if left and left:GetText() then text = text .. " " .. left:GetText() end
        if right and right:GetText() then text = text .. " " .. right:GetText() end
    end
    return string.lower(text)
end

-- Unknown active spells can still become graph nodes when their live tooltip
-- states an unambiguous combat effect. This deliberately avoids guessing buffs,
-- debuffs, targets, threat, or special prerequisites from a spell name.
function C:InferKnowledge(slot, bookType)
    if IsPassiveSpell then
        local ok, passive = pcall(IsPassiveSpell, slot, bookType or BOOKTYPE_SPELL)
        if ok and (passive == true or passive == 1) then return nil end
    end
    local text = tooltipText(slot, bookType)
    if text == "" then return nil end
    local facts = { inferred = true }
    if string.find(text, "interrupts spellcasting") or string.find(text, "interrupting spell") then
        facts.kind = "interrupt"
    elseif string.find(text, "absorbs ") and string.find(text, "damage") then
        facts.kind = "absorb"
    elseif string.find(text, "heals ")
        or string.find(text, "restores ") and string.find(text, " health") then
        facts.kind = (string.find(text, "over %d+ sec") or string.find(text, "every %d+ sec")) and "hot" or "heal"
    elseif string.find(text, "restores ") and (string.find(text, " mana")
        or string.find(text, " energy") or string.find(text, " rage")) then
        facts.kind = "resource"; facts.self = true
    elseif string.find(text, "reduces all damage") or string.find(text, "immune to")
        or string.find(text, "damage taken") and (string.find(text, "caster") or string.find(text, "you")) then
        facts.kind = "defensive"; facts.self = true
    elseif string.find(text, "deals .-damage") or string.find(text, "causes .-damage")
        or string.find(text, "inflicts .-damage") or string.find(text, "for %d+ .-damage") then
        facts.kind = (string.find(text, "over %d+ sec") or string.find(text, "every %d+ sec")) and "dot" or "damage"
    else
        return nil
    end
    if string.find(text, "channeled") then facts.channel = true end
    if string.find(text, "all enemies") or string.find(text, "nearby enemies")
        or string.find(text, "enemies within") then facts.aoe = true end
    if string.find(text, "reagent") then facts.reagent = true end
    local _, _, cooldown = string.find(text, "(%d+) min cooldown")
    if cooldown and tonumber(cooldown) and tonumber(cooldown) >= 1 then facts.cooldown = true end
    return facts
end

function C:BuildSpellIndex()
    local slots, ranks, actions = {}, {}, {}
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        slots[name] = i
        local digits = string.gsub(rank or "", "%D", "")
        local value = tonumber(digits) or 1
        if not ranks[name] or value > ranks[name] then ranks[name] = value end
        local knowledge = XelAssist.Combat.Knowledge and XelAssist.Combat.Knowledge[name]
        if not knowledge then knowledge = self:InferKnowledge(i) end
        if knowledge then
            local castName = name
            if rank and rank ~= "" then castName = name .. "(" .. rank .. ")" end
            local spellId
            if GetSpellSlotTypeIdForName then
                local ok, _, _, foundId = pcall(GetSpellSlotTypeIdForName, castName)
                if ok and foundId and foundId ~= 0 then spellId = foundId end
            elseif GetSpellIdForName then
                local ok, foundId = pcall(GetSpellIdForName, castName)
                if ok and foundId and foundId ~= 0 then spellId = foundId end
            end
            table.insert(actions, { name = name, rankText = rank or "", rank = value,
                slot = i, spellId = spellId, bookType = BOOKTYPE_SPELL,
                actor = "player", executor = "playerSpell", facts = knowledge })
        end
        i = i + 1
    end
    self.spellSlots = slots
    self.spellRanks = ranks
    self.actions = actions
end

function C:Invalidate()
    self.spellSlots = nil
    self.spellRanks = nil
    self.actions = nil
    self.costs = nil
    self.tooltipFacts = nil
    self.talentPoints = nil
    self:InvalidateEquipment()
end

function C:InvalidateEquipment()
    self.penetrationCache = nil
    self.penetrationFingerprint = nil
end

local WEAPON_SKILL_GLOBAL = {
    [0] = "AXES", [1] = "TWO_HANDED_AXES", [2] = "BOWS", [3] = "GUNS",
    [4] = "MACES", [5] = "TWO_HANDED_MACES", [6] = "POLEARMS", [7] = "SWORDS",
    [8] = "TWO_HANDED_SWORDS", [10] = "STAVES", [13] = "UNARMED",
    [15] = "DAGGERS", [16] = "THROWN", [18] = "CROSSBOWS", [19] = "WANDS",
}
local WEAPON_SKILL_ENGLISH = {
    [0] = "Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns",
    [4] = "Maces", [5] = "Two-Handed Maces", [6] = "Polearms", [7] = "Swords",
    [8] = "Two-Handed Swords", [10] = "Staves", [13] = "Unarmed",
    [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows", [19] = "Wands",
}

local function safeCall(fn, a, b, c)
    if not fn then return nil end
    local ok, first, second, third, fourth
    if c ~= nil then ok, first, second, third, fourth = pcall(fn, a, b, c)
    elseif b ~= nil then ok, first, second, third, fourth = pcall(fn, a, b)
    elseif a ~= nil then ok, first, second, third, fourth = pcall(fn, a)
    else ok, first, second, third, fourth = pcall(fn) end
    if ok then return first, second, third, fourth end
    return nil
end

local function equippedItemId(slot)
    if GetEquippedItem then
        local item = safeCall(GetEquippedItem, "player", slot)
        local itemId = type(item) == "table" and tonumber(item.itemId)
        if itemId and itemId > 0 then return itemId end
    end
    local link = safeCall(GetInventoryItemLink, "player", slot)
    local _, _, itemId = string.find(link or "", "item:(%d+)")
    return tonumber(itemId)
end

local function itemClassAndSubclass(slot)
    local itemId = equippedItemId(slot)
    if not itemId then return nil, nil, nil end
    if GetItemStatsField then
        local class = tonumber(safeCall(GetItemStatsField, itemId, "class"))
        local subclass = tonumber(safeCall(GetItemStatsField, itemId, "subclass"))
        if class ~= nil and subclass ~= nil then return class, subclass, itemId end
    end
    return nil, nil, itemId
end

local function skillLineName(subclass)
    local globalName = WEAPON_SKILL_GLOBAL[subclass]
    local localized = globalName and getglobal and getglobal(globalName) or nil
    if type(localized) == "string" and localized ~= "" then return localized end
    local locale = safeCall(GetLocale)
    if locale == "enUS" or locale == "enGB" then return WEAPON_SKILL_ENGLISH[subclass] end
    return nil
end

local function skillLine(expected)
    if not expected or not GetSkillLineInfo then return nil end
    local count = tonumber(safeCall(GetNumSkillLines))
    local maximum = count and math.min(512, count) or 512
    local index
    for index = 1, maximum do
        local ok, name, isHeader, _, rank, temporary, modifier, maximumRank =
            pcall(GetSkillLineInfo, index)
        if not ok then break end
        if not name then break end
        if not isHeader and name == expected and tonumber(rank) then
            local base = tonumber(rank) or 0
            local bonus = tonumber(modifier) or tonumber(temporary) or 0
            return { base = base, modifier = bonus, total = base + bonus,
                maximum = tonumber(maximumRank), known = true,
                source = "localized skill line" }
        end
    end
    return nil
end

local function attackSkill(fn, position)
    local a, b, c, d = safeCall(fn, "player")
    local base, modifier
    if position == "off" then base, modifier = c, d
    else base, modifier = a, b end
    base, modifier = tonumber(base), tonumber(modifier)
    if base == nil then return nil end
    modifier = modifier or 0
    return { base = base, modifier = modifier, total = base + modifier,
        known = true, source = position == "ranged" and "UnitRangedAttack"
            or "UnitAttackBothHands" }
end

local function weaponToken(slot, fallback)
    local link = safeCall(GetInventoryItemLink, "player", slot)
    if not link then return fallback end
    local _, _, item = string.find(link, "item:([^|]+)")
    return item and tostring(slot) .. ":" .. item or tostring(slot) .. ":equipped"
end

local function inventoryItemBroken(slot)
    if GetInventoryItemBroken then
        local broken = safeCall(GetInventoryItemBroken, "player", slot)
        if broken ~= nil then return broken == true or broken == 1, true end
    end
    if GetInventoryItemDurability then
        local current, maximum = safeCall(GetInventoryItemDurability, slot)
        current, maximum = tonumber(current), tonumber(maximum)
        if current ~= nil and maximum and maximum > 0 then
            return current <= 0, true
        end
    end
    return false, false
end

-- ClassicAPI exposes the stable SpellShapeshiftForm.dbc ID directly. Nampower's
-- UNIT_FIELD_BYTES_1 mirror is an exact fallback: on the 1.12 client the form
-- occupies byte 2 (zero based), unlike the action-bar index returned by the
-- stock GetShapeshiftForm API. Only Cat/Bear/Dire Bear use the server's
-- level-max feral skill and ignore the equipped weapon.
local NO_WEAPON_FORM = { [1] = true, [5] = true, [8] = true }
local KNOWN_WEAPON_FORM = { [0] = true, [17] = true, [18] = true, [19] = true,
    [28] = true, [30] = true, [31] = true }
local function stableShapeshiftForm()
    if GetShapeshiftFormID then
        local form = tonumber(safeCall(GetShapeshiftFormID))
        if form and form >= 0 then return form, "ClassicAPI form ID" end
    end
    if GetUnitField then
        local bytes = tonumber(safeCall(GetUnitField, "player", "bytes1"))
        if bytes and bytes >= 0 then
            local shifted = math.floor(bytes / 65536)
            return shifted - math.floor(shifted / 256) * 256, "Nampower form field"
        end
    end
    return nil, "stable form ID unavailable"
end

-- The Turtle client exposes the current form/equipment-aware attack skills
-- directly. Numeric Nampower item subclasses plus localized global strings are
-- only a fallback, avoiding English subtype comparisons on non-English clients.
-- Each hand remains separate so a low off-hand or ranged skill can never be
-- silently replaced by the main-hand value.
function C:WeaponSkills()
    local out = { source = "client attack skill APIs", known = false }
    if UnitAttackBothHands then
        out.main = attackSkill(UnitAttackBothHands, "main")
        out.off = attackSkill(UnitAttackBothHands, "off")
    elseif UnitAttack then
        out.main = attackSkill(UnitAttack, "main")
    end
    if UnitRangedAttack then out.ranged = attackSkill(UnitRangedAttack, "ranged") end

    local mainClass, mainSubclass = itemClassAndSubclass(16)
    local offClass, offSubclass = itemClassAndSubclass(17)
    local rangedClass, rangedSubclass = itemClassAndSubclass(18)
    if not out.main then
        out.main = skillLine(skillLineName(mainClass == 2 and mainSubclass or 13))
    end
    if not out.off and offClass == 2 then out.off = skillLine(skillLineName(offSubclass)) end
    if not out.ranged and rangedClass == 2 then
        out.ranged = skillLine(skillLineName(rangedSubclass))
    end
    out.unarmed = skillLine(skillLineName(13))

    local formId, formSource = stableShapeshiftForm()
    local formIndex = tonumber(safeCall(GetShapeshiftForm)) or 0
    local noWeaponForm = formId and NO_WEAPON_FORM[formId] and true or false
    local formWeaponUseKnown = formId ~= nil
        and (NO_WEAPON_FORM[formId] or KNOWN_WEAPON_FORM[formId]) and true
        or formId == nil and formIndex == 0 and true or false
    local _, offSpeed = safeCall(UnitAttackSpeed, "player")
    local hasOffHand = type(offSpeed) == "number" and offSpeed > 0
        or offClass == 2 and true or false
    local offBroken, offUsableKnown = false, true
    if hasOffHand then offBroken, offUsableKnown = inventoryItemBroken(17) end
    out.dualWieldKnown = noWeaponForm or not hasOffHand or offUsableKnown
    -- If durability is unavailable, retain the equipped dual-wield table as
    -- the conservative estimate but expose that its usability is unknown.
    -- A proven broken off hand is excluded exactly, matching server weapon
    -- selection.
    out.dualWield = not noWeaponForm and hasOffHand
        and not (offUsableKnown and offBroken) or false
    out.offHandBroken = hasOffHand and offBroken or false
    if not out.dualWield then out.off = nil end
    if noWeaponForm then
        local level = tonumber(safeCall(UnitLevel, "player"))
        if level and level > 0 then
            out.main = { base = level * 5, modifier = 0, total = level * 5,
                maximum = level * 5, known = true,
                source = "no-weapon shapeshift level-max skill" }
        end
    end
    out.form, out.formId, out.formIndex = formId or formIndex, formId, formIndex
    out.formKnown, out.formSource = formId ~= nil, formSource
    out.noWeaponForm = noWeaponForm
    out.formWeaponUseKnown = formWeaponUseKnown
    local equippedMainToken = weaponToken(16, "unarmed")
    out.mainToken = noWeaponForm and "form:" .. tostring(formId)
        or not formWeaponUseKnown and formIndex ~= 0
            and "form?:" .. tostring(formId or formIndex) .. ":" .. equippedMainToken
        or equippedMainToken
    out.offToken = out.dualWield and weaponToken(17, "offhand") or "none"
    out.rangedToken = weaponToken(18, "none")
    out.known = out.main and out.main.known or out.ranged and out.ranged.known or false
    return out
end

-- Talent effects that alter cost, cast time, range, damage or healing are
-- reflected by the live spell tooltip/DBC facts. Keep a small evidence count
-- as well, and invalidate those derived facts whenever talents change.
function C:TalentPoints()
    if self.talentPoints ~= nil then return self.talentPoints end
    if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return nil end
    local spent, tab, talent = 0, nil, nil
    local tabs = tonumber(GetNumTalentTabs()) or 0
    for tab = 1, tabs do
        local talents = tonumber(GetNumTalents(tab)) or 0
        for talent = 1, talents do
            local _, _, _, _, rank = GetTalentInfo(tab, talent)
            spent = spent + (tonumber(rank) or 0)
        end
    end
    self.talentPoints = spent
    return spent
end

function C:Actions()
    if not self.actions then self:BuildSpellIndex() end
    return self.actions
end

function C:SpellSlot(name)
    if not self.spellSlots then self:BuildSpellIndex() end
    return self.spellSlots[name]
end

function C:SpellRank(name)
    if not self.spellRanks then self:BuildSpellIndex() end
    return self.spellRanks[name] or 0
end

function C:KnowsSpell(name)
    return self:SpellSlot(name) ~= nil
end

function C:SpellCost(name)
    if not self.costs then self.costs = {} end
    if self.costs[name] then return self.costs[name] end
    local slot = self:SpellSlot(name)
    if not slot then return nil end
    if not scanTip then scanTip = CreateFrame("GameTooltip", TIP_NAME, nil, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetSpell(slot, BOOKTYPE_SPELL)
    local cost
    local i
    for i = 2, 4 do
        local line = getglobal(TIP_NAME .. "TextLeft" .. i)
        local value = line and line:GetText()
        if value then
            value = string.gsub(value, ",", "")
            local _, _, number = string.find(value, "^(%d+) %a+$")
            if number then cost = tonumber(number); break end
        end
    end
    if cost then self.costs[name] = cost end
    return cost
end

local function numberFrom(text, pattern)
    if not text then return nil end
    text = string.gsub(text, ",", "")
    local _, _, value = string.find(text, pattern)
    return value and tonumber(value) or nil
end

local function penetrationResult(spell, armor, known, reason)
    return { spell = spell or 0, armor = armor or 0, known = known and true or false,
        source = known and "equipment tooltips" or "unavailable", reason = reason }
end

local function equippedFingerprint()
    if not GetInventoryItemLink then return nil, nil, "inventory link API" end
    local links, parts, slot = {}, {}, nil
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if not ok then return nil, nil, "inventory link API" end
        if not link and GetInventoryItemTexture then
            local textureOK, texture = pcall(GetInventoryItemTexture, "player", slot)
            if not textureOK then return nil, nil, "inventory texture API" end
            if texture then return nil, nil, "uncached equipped item" end
        end
        links[slot] = link
        parts[slot] = tostring(slot) .. "=" .. tostring(link or "")
    end
    return table.concat(parts, "\031"), links, nil
end

local function activeSetBonus(line)
    if not line or not line.GetTextColor then return false end
    local ok, red, green, blue = pcall(line.GetTextColor, line)
    return ok and type(red) == "number" and type(green) == "number" and type(blue) == "number"
        and green > red + 0.05 and green > blue + 0.05
end

local function penetrationValue(text, setBonus)
    if not text then return nil, nil end
    local lower = string.lower(string.gsub(text, ",", ""))
    local prefix = setBonus and "^set:%s*" or "^equip:%s*"
    local armor = numberFrom(lower, prefix .. "your attacks ignore (%d+) of the target's armor")
    local spell = numberFrom(lower,
        prefix .. "decreases the magical resistances of your spell targets by (%d+)")
    if not setBonus then
        armor = armor or numberFrom(lower, "^%+(%d+) armor penetration")
            or numberFrom(lower, "^armor penetration %+(%d+)")
        spell = spell or numberFrom(lower, "^%+(%d+) spell penetration")
            or numberFrom(lower, "^spell penetration %+(%d+)")
    end
    return spell, armor
end

-- Vanilla has no trustworthy numeric penetration API. Equipment tooltips are
-- the narrow fallback: only English strings with unambiguous wording count.
-- The full equipped links form the cache key, so gear/enchant changes refresh
-- this even if the caller did not receive an inventory event.
function C:Penetration()
    if not (CreateFrame and getglobal and GetLocale) then
        return penetrationResult(0, 0, false, "tooltip APIs")
    end
    local localeOK, locale = pcall(GetLocale)
    if not localeOK or (locale ~= "enUS" and locale ~= "enGB") then
        return penetrationResult(0, 0, false, "unsupported locale")
    end
    local fingerprint, links, fingerprintError = equippedFingerprint()
    if not fingerprint then return penetrationResult(0, 0, false, fingerprintError) end
    if self.penetrationCache and self.penetrationFingerprint == fingerprint then
        local cached = self.penetrationCache
        return penetrationResult(cached.spell, cached.armor, true)
    end

    if not scanTip then
        local ok, tooltip = pcall(CreateFrame, "GameTooltip", TIP_NAME, nil, "GameTooltipTemplate")
        if not ok then return penetrationResult(0, 0, false, "tooltip creation") end
        scanTip = tooltip
    end
    if not scanTip or not scanTip.SetOwner or not scanTip.ClearLines
        or not scanTip.SetInventoryItem or not scanTip.NumLines then
        return penetrationResult(0, 0, false, "inventory tooltip API")
    end
    local ownerOK = pcall(scanTip.SetOwner, scanTip, UIParent, "ANCHOR_NONE")
    if not ownerOK then return penetrationResult(0, 0, false, "inventory tooltip owner") end

    local totalSpell, totalArmor, seenSets, slot = 0, 0, {}, nil
    for slot = 1, 19 do
        if links[slot] then
            pcall(scanTip.ClearLines, scanTip)
            local ok, hasItem = pcall(scanTip.SetInventoryItem, scanTip, "player", slot)
            if not ok or not hasItem then
                return penetrationResult(0, 0, false, "unavailable equipped tooltip")
            end
            local linesOK, lineCount = pcall(scanTip.NumLines, scanTip)
            if not linesOK or type(lineCount) ~= "number" then
                return penetrationResult(0, 0, false, "inventory tooltip lines")
            end
            local setName, lineIndex, side = nil, nil, nil
            for lineIndex = 1, lineCount do
                for side = 1, 2 do
                    local suffix = side == 1 and "TextLeft" or "TextRight"
                    local line = getglobal(TIP_NAME .. suffix .. lineIndex)
                    local text = line and line.GetText and line:GetText() or nil
                    if text then
                        local _, _, foundSet = string.find(text, "^(.+) %(%d+/%d+%)")
                        if foundSet then setName = foundSet end
                        local spell, armor = penetrationValue(text, false)
                        totalSpell = totalSpell + (spell or 0)
                        totalArmor = totalArmor + (armor or 0)
                        local setSpell, setArmor = penetrationValue(text, true)
                        if (setSpell or setArmor) and setName and activeSetBonus(line) then
                            local key = setName .. ":" .. tostring(setSpell or 0) .. ":" .. tostring(setArmor or 0)
                            if not seenSets[key] then
                                seenSets[key] = true
                                totalSpell = totalSpell + (setSpell or 0)
                                totalArmor = totalArmor + (setArmor or 0)
                            end
                        end
                    end
                end
            end
        end
    end
    self.penetrationFingerprint = fingerprint
    self.penetrationCache = { spell = totalSpell, armor = totalArmor }
    return penetrationResult(totalSpell, totalArmor, true)
end

local function maskContains(mask, school)
    mask = math.max(0, tonumber(mask) or 0)
    local divisor = 2 ^ school
    return math.floor(mask / divisor) - math.floor(mask / (divisor * 2)) * 2 == 1
end

-- Party-applied target modifiers may not exist in our spellbook, so their
-- tooltip slot is unavailable. DBC effect arrays still expose the resistance
-- school mask and damage-taken aura amount by spell id.
function C:TargetModifierFacts(spellId, semantics)
    if not spellId or not GetSpellRecField then return {} end
    if not self.targetModifierFacts then self.targetModifierFacts = {} end
    local cacheKey = tostring(spellId) .. ":" .. tostring(semantics and semantics.modifierGroup or "")
    if self.targetModifierFacts[cacheKey] then return self.targetModifierFacts[cacheKey] end
    local function array(field)
        local ok, value = pcall(GetSpellRecField, spellId, field, 1)
        if ok and type(value) == "table" then return value end
        return nil
    end
    local effects = array("effect")
    local auras = array("effectApplyAuraName")
    local base = array("effectBasePoints")
    local misc = array("effectMiscValue")
    local perCombo = array("effectPointsPerComboPoint")
    local out = { targetResistanceReduction = {}, targetDamageTaken = {},
        source = "client DBC target modifier" }
    local i
    for i = 1, math.max(table.getn(effects or {}), table.getn(auras or {})) do
        if not effects or effects[i] == 6 then
            local aura = auras and tonumber(auras[i])
            local baseValue = tonumber(base and base[i])
            local signed = baseValue and baseValue + 1 or nil
            local amount = math.abs(signed or 0)
            local mask = tonumber(misc and misc[i]) or 0
            if aura == 22 or aura == 123 or aura == 143 then
                local school
                for school = 0, 6 do
                    if maskContains(mask, school) then
                        if school == 0 and (semantics and semantics.armorDebuff
                            or not semantics and signed and signed < 0) then
                            out.targetArmorReduction = math.max(out.targetArmorReduction or 0, amount)
                            if perCombo and tonumber(perCombo[i])
                                and math.abs(tonumber(perCombo[i])) > 0 then
                                out.targetArmorPerCombo = true
                            end
                        elseif school > 0 and (semantics and semantics.resistanceDebuff
                            or not semantics and signed and signed < 0) then
                            out.targetResistanceReduction[school] = math.max(
                                out.targetResistanceReduction[school] or 0, amount)
                        end
                    end
                end
            elseif aura == 87 and signed and signed > 0 then
                local school
                for school = 0, 6 do
                    if maskContains(mask, school) then
                        out.targetDamageTaken[school] = math.max(
                            out.targetDamageTaken[school] or 0, amount / 100)
                    end
                end
            end
        end
    end
    if not next(out.targetResistanceReduction) then out.targetResistanceReduction = nil end
    if not next(out.targetDamageTaken) then out.targetDamageTaken = nil end
    out.recognized = out.targetArmorReduction ~= nil
        or out.targetResistanceReduction ~= nil or out.targetDamageTaken ~= nil
    if out.recognized then
        out.modifierGroup = semantics and semantics.modifierGroup
            or "dbc:" .. tostring(spellId)
    end
    self.targetModifierFacts[cacheKey] = out
    return out
end

-- Best-effort facts from the client tooltip. Unknown values stay nil: the
-- graph prices uncertainty but never invents a damage, heal, range or timer.
function C:Facts(action)
    if not self.tooltipFacts then self.tooltipFacts = {} end
    local bookType = action.bookType or BOOKTYPE_SPELL
    local cacheKey = tostring(bookType) .. ":" .. tostring(action.slot)
    local hit = self.tooltipFacts[cacheKey]
    if hit then return hit end
    if not scanTip then scanTip = CreateFrame("GameTooltip", TIP_NAME, nil, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE"); scanTip:ClearLines()
    scanTip:SetSpell(action.slot, bookType)
    local out = { cost = nil, cast = nil, cooldown = nil, minRange = nil,
        maxRange = nil, low = nil, high = nil, duration = nil, gcd = nil,
        source = "tooltip" }
    local description = ""
    local function dbc(field)
        if not (action.spellId and GetSpellRecField) then return nil end
        local ok, value = pcall(GetSpellRecField, action.spellId, field)
        if ok and type(value) == "number" then return value end
        return nil
    end
    local function dbcArray(field)
        if not (action.spellId and GetSpellRecField) then return nil end
        local ok, value = pcall(GetSpellRecField, action.spellId, field, 1)
        if ok and type(value) == "table" then return value end
        return nil
    end
    local castMs = dbc("castTime")
    local recoveryMs = dbc("recoveryTime")
    local categoryRecoveryMs = dbc("categoryRecoveryTime")
    local cooldownGroup = dbc("category")
    local gcdMs = dbc("startRecoveryTime")
    local rangeIndex = dbc("rangeIndex")
    out.school = dbc("school")
    local gcdCategory = XelAssist.Game.SpellClassification:Apply(action, out, dbc)
    if castMs then out.cast = castMs / 1000 end
    if recoveryMs and recoveryMs > 0 then out.cooldown = recoveryMs / 1000 end
    if categoryRecoveryMs and categoryRecoveryMs > 0 then out.categoryCooldown = categoryRecoveryMs / 1000 end
    if cooldownGroup and cooldownGroup > 0 then out.cooldownGroup = cooldownGroup end
    if gcdMs ~= nil then out.gcd = gcdMs / 1000 end
    if rangeIndex and GetSpellRangeData then
        local ok, minRange, maxRange = pcall(GetSpellRangeData, rangeIndex)
        if ok then out.minRange, out.maxRange = minRange, maxRange end
    end
    if action.spellId and GetSpellDuration then
        local ok, durationMs = pcall(GetSpellDuration, action.spellId)
        if ok and durationMs and durationMs > 0 then out.duration = durationMs / 1000 end
    end
    local dbcCost = dbc("manaCost")
    if dbcCost and dbcCost > 0 then out.cost = dbcCost end
    local basePoints = dbcArray("effectBasePoints")
    local dieSides = dbcArray("effectDieSides")
    local perLevel = dbcArray("effectRealPointsPerLevel")
    local perCombo = dbcArray("effectPointsPerComboPoint")
    if basePoints then
        local level = UnitLevel and UnitLevel("player") or 60
        local spellLevel = dbc("spellLevel") or level
        local scaledLevel = math.max(0, level - spellLevel)
        local best, bestCombo = 0, 0
        local j
        for j = 1, table.getn(basePoints) do
            local amount = math.abs((basePoints[j] or 0) + 1)
                + math.abs((dieSides and dieSides[j] or 0)) / 2
                + math.abs((perLevel and perLevel[j] or 0)) * scaledLevel
            if amount > best then best = amount end
            local combo = math.abs(perCombo and perCombo[j] or 0)
            if combo > bestCombo then bestCombo = combo end
        end
        if best > 0 then out.dbcAverage = best end
        if bestCombo > 0 then out.comboBonus = bestCombo end
    end
    if out.cast or out.cooldown or out.gcd or out.maxRange or out.duration
        or out.cost or out.attributes ~= nil or gcdCategory ~= nil then
        out.source = "dbc"
    end
    local i
    for i = 2, 10 do
        local left = getglobal(TIP_NAME .. "TextLeft" .. i)
        local right = getglobal(TIP_NAME .. "TextRight" .. i)
        local lt = left and left:GetText()
        local rt = right and right:GetText()
        local text = (lt or "") .. " " .. (rt or "")
        description = description .. " " .. string.lower(string.gsub(text, ",", ""))
        local tooltipCost = numberFrom(lt, "^(%d+) %a+$")
        if tooltipCost then out.cost = tooltipCost end
        if string.find(text, "Instant") then out.cast = 0 end
        if not out.cast then out.cast = numberFrom(text, "(%d+%.?%d*) sec cast") end
        if not out.cooldown then out.cooldown = numberFrom(text, "(%d+%.?%d*) sec cooldown") end
        if not out.maxRange then out.maxRange = numberFrom(text, "(%d+%.?%d*) yd range") end
        if not out.duration then
            out.duration = numberFrom(text, "[Ll]asts (%d+%.?%d*) sec")
                or numberFrom(text, "for (%d+%.?%d*) sec")
        end
        if not out.low and (string.find(string.lower(text), "damage") or string.find(string.lower(text), "heal")
            or string.find(string.lower(text), "absorb")) then
            local clean = string.gsub(text, ",", "")
            local _, _, low, high = string.find(clean, "(%d+) to (%d+)")
            if low then out.low = tonumber(low); out.high = tonumber(high) end
        end
    end
    if not out.low then
        for i = 2, 10 do
            local left = getglobal(TIP_NAME .. "TextLeft" .. i)
            local text = left and left:GetText()
            local lower = text and string.lower(string.gsub(text, ",", ""))
            if lower then
                local exact = numberFrom(lower, "for (%d+) %a* ?damage")
                    or numberFrom(lower, "deals (%d+) %a* ?damage")
                    or numberFrom(lower, "causes (%d+) %a* ?damage")
                    or numberFrom(lower, "absorbs (%d+)")
                    or numberFrom(lower, "heals? .- for (%d+)")
                if exact and (not out.low or exact > out.low) then out.low, out.high = exact, exact end
            end
        end
    end
    if out.low and not out.high then out.high = out.low end
    out.average = out.low and ((out.low + (out.high or out.low)) / 2) or nil
    local _, _, directLow, directHigh, periodic = string.find(description,
        "for (%d+) to (%d+) [^%.]-damage and then an additional (%d+) [^%.]-damage over")
    local direct
    if directLow then direct = (tonumber(directLow) + tonumber(directHigh)) / 2
    else
        _, _, direct, periodic = string.find(description,
            "for (%d+) [^%.]-damage and then an additional (%d+) [^%.]-damage over")
        if not direct then
            _, _, direct, periodic = string.find(description,
                "deals (%d+) [^%.]-damage and an additional (%d+) [^%.]-damage over")
        end
        direct, periodic = tonumber(direct), tonumber(periodic)
    end
    periodic = tonumber(periodic)
    if direct and periodic then
        out.directDamage, out.periodicDamage = direct, periodic
        out.average = direct + periodic
    end
    if string.find(description, "armor") then
        out.targetArmorReduction = numberFrom(description, "reducing armor by (%d+)")
            or numberFrom(description, "reduce.-armor by (%d+)")
            or numberFrom(description, "decrease.-armor.-by (%d+)")
            or numberFrom(description, "armor.-reducing it by (%d+)")
        if out.targetArmorReduction and string.find(description, "per combo point") then
            out.targetArmorPerCombo = true
        end
    end
    local resistanceAmount = numberFrom(description, "resistances by (%d+)")
        or numberFrom(description, "resistance by (%d+)")
    if resistanceAmount and string.find(description, "reduc") then
        out.targetResistanceReduction = {}
        local names = { [1] = "holy", [2] = "fire", [3] = "nature",
            [4] = "frost", [5] = "shadow", [6] = "arcane" }
        local school, name
        for school, name in pairs(names) do
            if string.find(description, name, 1, true) then
                out.targetResistanceReduction[school] = resistanceAmount
            end
        end
    end
    local damagePercent = numberFrom(description, "damage taken by (%d+)%%")
    if damagePercent and string.find(description, "increas") then
        out.targetDamageTaken = {}
        local names = { [1] = "holy", [2] = "fire", [3] = "nature",
            [4] = "frost", [5] = "shadow", [6] = "arcane" }
        local school, name
        for school, name in pairs(names) do
            if string.find(description, name, 1, true) then
                out.targetDamageTaken[school] = damagePercent / 100
            end
        end
    end
    XelAssist.Game.SpellTiming:Apply(action, out)
    self.tooltipFacts[cacheKey] = out
    return out
end
function C:WeaponDamage()
    if GetUnitField then
        local okLow, low = pcall(GetUnitField, "player", "minDamage")
        local okHigh, high = pcall(GetUnitField, "player", "maxDamage")
        if okLow and okHigh and type(low) == "number" and type(high) == "number" then
            return (low + high) / 2
        end
    end
    if not UnitDamage then return nil end
    local ok, low, high = pcall(UnitDamage, "player")
    if not ok or type(low) ~= "number" or type(high) ~= "number" then return nil end
    return (low + high) / 2
end
function C:RangedDamage()
    if GetUnitField then
        local okLow, low = pcall(GetUnitField, "player", "minRangedDamage")
        local okHigh, high = pcall(GetUnitField, "player", "maxRangedDamage")
        if okLow and okHigh and type(low) == "number" and type(high) == "number" then
            return (low + high) / 2
        end
    end
    return nil
end

function C:BonusDamage(school)
    if not GetSpellPower or type(school) ~= "number" or school < 1 or school > 6 then return 0 end
    local now = GetTime()
    if self.powerAt ~= now then
        local ok, physical, holy, fire, nature, frost, shadow, arcane = pcall(GetSpellPower)
        self.powerAt = now
        self.powerValues = ok and { physical, holy, fire, nature, frost, shadow, arcane } or {}
    end
    return math.max(0, tonumber(self.powerValues[school + 1]) or 0)
end

function C:Health(unit)
    if GetUnitField then
        local okHealth, health = pcall(GetUnitField, unit, "health")
        local okMax, maximum = pcall(GetUnitField, unit, "maxHealth")
        if okHealth and okMax and type(health) == "number" and type(maximum) == "number" and maximum > 0 then
            return health, maximum, true
        end
    end
    local health, maximum = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
    local exact = unit ~= "target" or UnitCanAssist("player", unit)
    return health, maximum, exact
end

-- Unit tokens such as mouseover, target, partyN, and raidN are transient.
-- Bind the token to SuperWoW's opaque identity while taking the snapshot, then
-- carry this record unchanged through planning.  The GUID must never be
-- coerced: callers may pass it back to SuperWoW, but must not parse, stringify,
-- persist, or use it as a player-facing label.
local function currentUnitGuid(unit)
    if not unit or not UnitExists then return nil, nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 then return nil, nil end
    if guid == nil or guid == "" then return true, nil end
    return true, guid
end

function C:UnitRef(unit, relation, source)
    local exists, guid = currentUnitGuid(unit)
    if not exists or guid == nil then return nil end
    return { unit = unit, guid = guid, relation = relation, source = source }
end

function C:SameUnitRef(ref)
    if type(ref) ~= "table" or not ref.unit or ref.guid == nil then return false end
    local exists, guid = currentUnitGuid(ref.unit)
    return exists and guid ~= nil and guid == ref.guid and true or false
end

-- Revalidate identity before every explicit friendly cast.  A roster slot or
-- mouseover token that now names somebody else is not followed: the caller
-- must hold and build a fresh graph snapshot instead.
function C:ValidateFriendlyRef(ref)
    if type(ref) ~= "table" or not ref.unit or ref.guid == nil then
        return nil, "ally identity unavailable"
    end
    local exists, guid = currentUnitGuid(ref.unit)
    if not exists or guid == nil then return nil, "ally unavailable" end
    if guid ~= ref.guid then return nil, "ally changed" end
    if ref.relation ~= "self" then
        if not UnitCanAssist then return nil, "ally no longer friendly" end
        local ok, assist = pcall(UnitCanAssist, "player", ref.unit)
        if not ok or not assist or assist == 0 then return nil, "ally no longer friendly" end
    end
    if UnitIsDead then
        local ok, dead = pcall(UnitIsDead, ref.unit)
        if ok and (dead == true or dead == 1) then return nil, "ally defeated" end
    end
    return ref.unit, nil
end

function C:CastName(action)
    if action.rankText and action.rankText ~= "" then
        return action.name .. "(" .. action.rankText .. ")"
    end
    return action.name
end

function C:Distance(unit)
    if not unit or not UnitExists(unit) then return nil, nil end
    -- UnitXP is the installed client's NPC-capable, hitbox-aware source. The
    -- squared-distance API is a useful fallback but may resolve players only.
    if UnitXP then
        local ok, distance = pcall(UnitXP, "distanceBetween", "player", unit)
        if ok and type(distance) == "number" and distance >= 0 then return distance, "hitbox" end
    end
    if UnitDistanceSquared then
        local ok, squared = pcall(UnitDistanceSquared, unit)
        if ok and type(squared) == "number" and squared >= 0 then return math.sqrt(squared), "center" end
    end
    return nil, nil
end

function C:Geometry(from, to)
    local out = { source = nil, lineOfSight = nil, behind = nil }
    if not UnitXP or not from or not to or not UnitExists(from) or not UnitExists(to) then return out end
    local ok, value = pcall(UnitXP, "inSight", from, to)
    if ok and type(value) == "boolean" then out.lineOfSight, out.source = value, "UnitXP" end
    ok, value = pcall(UnitXP, "behind", from, to)
    if ok and type(value) == "boolean" then out.behind, out.source = value, "UnitXP" end
    return out
end

function C:CanAfford(name)
    local cost = self:SpellCost(name)
    if not cost then return true end
    return (UnitMana("player") or 0) >= cost
end

-- Nampower exposes proc/stance usability separately from cooldown and cost.
-- Only an explicit unusable result blocks; missing API/data remains unknown.
function C:Usable(action)
    if not IsSpellUsable then return nil end
    local ok, usable, outOfResource = pcall(IsSpellUsable, self:CastName(action))
    if not ok then return nil end
    if usable == 1 then return true end
    if usable == 0 then return false, outOfResource == 1 and "resource" or "state" end
    return nil
end

function C:IsReady(name, projectedSeconds)
    local slot = self:SpellSlot(name)
    if not slot then return false end
    local start, duration = GetSpellCooldown(slot, BOOKTYPE_SPELL)
    if not start or start == 0 then return true end
    local remaining = start + duration - GetTime()
    return remaining <= (projectedSeconds or 0)
end

-- Nampower's detailed cast record is the authority while it is available.
-- UNIT_CASTEVENT remains only a compatibility fallback in the core; its end
-- timing can arrive a frame early and must not drive the live recommendation.
function C:CurrentCast()
    if GetCastInfo then
        local ok, info = pcall(GetCastInfo)
        if ok and info then
            local spellId = info.spellId or 0
            local remaining = (info.castRemainingMs or 0) / 1000
            local name = spellId ~= 0 and SpellInfo and SpellInfo(spellId) or nil
            local gcd = (info.gcdRemainingMs or 0) / 1000
            return name, math.max(0, remaining), true, math.max(0, gcd),
                tonumber(info.castType) == 3
        end
    end
    if GetCurrentCastingInfo then
        local ok, castId, visualId, _, casting, channeling = pcall(GetCurrentCastingInfo)
        if ok and (casting == 1 or channeling == 1) then
            local spellId = castId ~= 0 and castId or visualId
            local name = spellId and spellId ~= 0 and SpellInfo and SpellInfo(spellId) or nil
            return name, 0, true, 0, channeling == 1
        end
    end
    return nil, 0, false, 0
end

function C:GCDRemaining()
    if GetSpellIdCooldown then
        local actions = self:Actions()
        local i
        for i = 1, table.getn(actions) do
            if actions[i].spellId then
                local ok, cooldown = pcall(GetSpellIdCooldown, actions[i].spellId)
                if ok and type(cooldown) == "table" and cooldown.gcdCategoryRemainingMs then
                    return math.max(0, cooldown.gcdCategoryRemainingMs / 1000)
                end
            end
        end
    end
    return 0
end

-- Only an explicit out-of-range result blocks an action. Nampower accepts an
-- explicit unit token, allowing the same authoritative query for selected and
-- off-target friendly units. Invalid or unsupported queries remain unknown.
function C:InRange(name, unit)
    if not unit or not IsSpellInRange then return nil end
    local ok, result = pcall(IsSpellInRange, name, unit)
    if not ok then return nil end
    if result == 0 then return false end
    if result == 1 then return true end
    return nil
end

local function auraName(unit, index, helpful)
    local texture, stacks, d3, d4, d5
    if helpful then texture, stacks, d3, d4, d5 = UnitBuff(unit, index)
    else texture, stacks, d3, d4, d5 = UnitDebuff(unit, index) end
    if not texture then return nil end
    local id
    if type(d3) == "number" then id = d3
    elseif type(d4) == "number" then id = d4
    elseif type(d5) == "number" then id = d5 end
    if id and id < -1 then id = id + 65536 end
    return id and SpellInfo and SpellInfo(id) or nil
end

function C:UnitHasBuff(unit, name)
    if unit == "player" and GetPlayerBuff and GetPlayerBuffID then
        local i
        for i = 0, 31 do
            local slot = GetPlayerBuff(i, "HELPFUL")
            if slot and slot ~= -1 then
                local id = GetPlayerBuffID(slot)
                if id and id < -1 then id = id + 65536 end
                if id and SpellInfo(id) == name then return true end
            end
        end
        return false
    end
    local i
    for i = 1, 40 do
        local found = auraName(unit, i, true)
        if not UnitBuff(unit, i) then break end
        if found == name then return true end
    end
    return false
end

function C:TargetHasDebuff(name)
    local i
    for i = 1, 40 do
        local found = auraName("target", i, false)
        if not UnitDebuff("target", i) then break end
        if found == name then return true end
    end
    return false
end

function C:TargetHealthPercent()
    local maximum = UnitHealthMax("target") or 0
    if maximum <= 0 then return 100 end
    return (UnitHealth("target") or 0) * 100 / maximum
end
