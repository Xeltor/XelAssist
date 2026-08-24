XelAssistCapabilities = {}
local C = XelAssistCapabilities
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
        local knowledge = XelAssistKnowledge and XelAssistKnowledge[name]
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
    if out.cast or out.cooldown or out.gcd or out.maxRange or out.duration or out.cost then out.source = "dbc" end
    local i
    for i = 2, 10 do
        local left = getglobal(TIP_NAME .. "TextLeft" .. i)
        local right = getglobal(TIP_NAME .. "TextRight" .. i)
        local lt = left and left:GetText()
        local rt = right and right:GetText()
        local text = (lt or "") .. " " .. (rt or "")
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
            return name, math.max(0, remaining), true, math.max(0, gcd)
        end
    end
    if GetCurrentCastingInfo then
        local ok, castId, visualId, _, casting, channeling = pcall(GetCurrentCastingInfo)
        if ok and (casting == 1 or channeling == 1) then
            local spellId = castId ~= 0 and castId or visualId
            local name = spellId and spellId ~= 0 and SpellInfo and SpellInfo(spellId) or nil
            return name, 0, true, 0
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

-- Only an explicit out-of-range result blocks an action. Nampower's
-- IsSpellInRange is authoritative for the selected target; other unit tokens
-- are left unknown instead of being rejected by a guessed distance threshold.
function C:InRange(name, unit)
    if not unit or unit ~= "target" or not IsSpellInRange then return nil end
    local ok, result = pcall(IsSpellInRange, name)
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
