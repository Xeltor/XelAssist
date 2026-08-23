XelAssistCapabilities = {}
local C = XelAssistCapabilities
local TIP_NAME = "XelAssistScanTip"
local scanTip

function C:BuildSpellIndex()
    local slots, ranks = {}, {}
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        slots[name] = i
        local digits = string.gsub(rank or "", "%D", "")
        local value = tonumber(digits) or 1
        if not ranks[name] or value > ranks[name] then ranks[name] = value end
        i = i + 1
    end
    self.spellSlots = slots
    self.spellRanks = ranks
end

function C:Invalidate()
    self.spellSlots = nil
    self.spellRanks = nil
    self.costs = nil
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

function C:CanAfford(name)
    local cost = self:SpellCost(name)
    if not cost then return true end
    return (UnitMana("player") or 0) >= cost
end

function C:IsReady(name, projectedSeconds)
    local slot = self:SpellSlot(name)
    if not slot then return false end
    local start, duration = GetSpellCooldown(slot, BOOKTYPE_SPELL)
    if not start or start == 0 then return true end
    local remaining = start + duration - GetTime()
    return remaining <= (projectedSeconds or 0)
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

