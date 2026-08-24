-- Equipment and carried-resource evidence that can constrain combat actions.
XelAssistInventory = {}
local I = XelAssistInventory
local scanTip
local TIP_NAME = "XelAssistItemScanTooltip"

local function itemId(link)
    local _, _, value = string.find(link or "", "item:(%d+)")
    return value and tonumber(value) or nil
end

local function cooldownFacts(id)
    if not id or not GetItemIdCooldown then return nil, nil, nil end
    local ok, info = pcall(GetItemIdCooldown, id)
    if not ok or type(info) ~= "table" then return nil, nil, nil end
    local duration = math.max(info.individualDurationMs or 0,
        info.categoryDurationMs or 0) / 1000
    local remaining = math.max(info.cooldownRemainingMs or 0,
        info.individualRemainingMs or 0, info.categoryRemainingMs or 0) / 1000
    local group = info.categoryId and info.categoryId > 0 and "item:" .. info.categoryId or nil
    return remaining, duration > 0 and duration or nil, group
end

local function number(text)
    if not text then return nil end
    local cleaned = string.gsub(text, ",", "")
    return tonumber(cleaned)
end

local function itemTooltip(bag, slot)
    if not CreateFrame then return nil end
    if not scanTip then scanTip = CreateFrame("GameTooltip", TIP_NAME, nil, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE"); scanTip:ClearLines()
    scanTip:SetBagItem(bag, slot)
    local lines, i = {}, nil
    for i = 1, 20 do
        local line = getglobal(TIP_NAME .. "TextLeft" .. i)
        local text = line and line:GetText()
        if text then table.insert(lines, text) end
    end
    return lines
end

local function inferImmediateUse(lines)
    local joined, name, i = "", lines and lines[1] or nil, nil
    for i = 2, table.getn(lines or {}) do joined = joined .. " " .. string.lower(lines[i]) end
    if joined == "" or string.find(joined, "must remain seated")
        or string.find(joined, "over %d+ sec") then return nil end
    local _, _, low, high = string.find(joined, "restores ([%d,]+) to ([%d,]+) health")
    if not low then _, _, low = string.find(joined, "restores ([%d,]+) health") end
    if low then
        low, high = number(low), number(high)
        return name, { kind = "heal", self = true, consumable = true, combatOnly = true },
            (low + (high or low)) / 2
    end
    _, _, low, high = string.find(joined, "restores ([%d,]+) to ([%d,]+) mana")
    if not low then _, _, low = string.find(joined, "restores ([%d,]+) mana") end
    if low then
        low, high = number(low), number(high)
        return name, { kind = "resource", self = true, consumable = true, combatOnly = true,
            resourceType = "mana" }, (low + (high or low)) / 2
    end
    return nil
end

local function equipped(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil
    local current, maximum
    if GetInventoryItemDurability then current, maximum = GetInventoryItemDurability(slot) end
    return { slot = slot, link = link, durability = current, durabilityMax = maximum,
        broken = link and maximum and maximum > 0 and current == 0 and true or false }
end

function I:Snapshot()
    local ammoSlot = INVSLOT_AMMO or 0
    local rangedSlot = INVSLOT_RANGED or 18
    local ammoLink = GetInventoryItemLink and GetInventoryItemLink("player", ammoSlot) or nil
    local ammoCount = GetInventoryItemCount and GetInventoryItemCount("player", ammoSlot) or nil
    local ranged = equipped(rangedSlot)
    if ranged.link and GetItemInfo then
        local _, _, _, _, _, itemType, itemSubtype = GetItemInfo(ranged.link)
        ranged.itemType, ranged.itemSubtype = itemType, itemSubtype
    end
    local itemCounts, actions, reagentCounts, i = {}, self:Actions(), {}, nil
    for i = 1, table.getn(actions) do
        local id = actions[i].itemId
        if id then itemCounts[id] = (itemCounts[id] or 0) + (actions[i].count or 1) end
    end
    local spells = XelAssistCapabilities and XelAssistCapabilities:Actions() or {}
    for i = 1, table.getn(spells) do
        local reagent = spells[i].facts and spells[i].facts.reagentName
        if reagent and reagentCounts[reagent] == nil and GetItemCount then
            local ok, count = pcall(GetItemCount, reagent)
            if ok then reagentCounts[reagent] = tonumber(count) or 0 end
        end
    end
    return {
        mainHand = equipped(INVSLOT_MAINHAND or 16),
        offHand = equipped(INVSLOT_OFFHAND or 17),
        ranged = ranged,
        ammo = { slot = ammoSlot, link = ammoLink, count = ammoCount,
            known = GetInventoryItemCount and true or false },
        itemCounts = itemCounts, reagentCounts = reagentCounts
    }
end

function I:Invalidate()
    self.actions = nil
end

function I:Actions()
    if self.actions then return self.actions end
    local actions, bag, slot = {}, nil, nil
    if GetContainerNumSlots and GetContainerItemLink and GetContainerItemInfo then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local texture, count, locked = GetContainerItemInfo(bag, slot)
                    local id = itemId(link)
                    local itemName, _, _, _, _, itemType, _, _, equipLocation = nil
                    if GetItemInfo then
                        itemName, _, _, _, _, itemType, _, _, equipLocation = GetItemInfo(link)
                    end
                    local consumableClass = ITEM_CLASS_CONSUMABLE or "Consumable"
                    local safeClass = itemType == consumableClass
                        and (not equipLocation or equipLocation == "")
                    local tooltipName, facts, average = inferImmediateUse(itemTooltip(bag, slot))
                    if id and safeClass and not locked and tooltipName and facts and average then
                        local remaining, duration, cooldownGroup = cooldownFacts(id)
                        local action = { name = itemName or tooltipName, rank = 1, rankText = "",
                            actor = "player", executor = "item", bag = bag, bagSlot = slot,
                            itemId = id, itemLink = link, texture = texture, count = count or 1,
                            facts = facts, itemFacts = { average = average, cost = 0, cast = 0,
                                gcd = 1.5, cooldown = duration, cooldownGroup = cooldownGroup,
                                source = "item tooltip" }, initialCooldown = remaining }
                        table.insert(actions, action)
                    end
                end
            end
        end
    end
    self.actions = actions
    return actions
end

function I:Facts(action)
    return action.itemFacts or { cost = 0, cast = 0, gcd = 1.5, source = "item" }
end

function I:Cooldown(action)
    local remaining = cooldownFacts(action.itemId)
    if remaining ~= nil then return remaining end
    if not (action.bag and action.bagSlot and GetContainerItemCooldown) then return nil end
    if itemId(GetContainerItemLink(action.bag, action.bagSlot)) ~= action.itemId then return nil end
    local start, duration, enabled = GetContainerItemCooldown(action.bag, action.bagSlot)
    if enabled == 0 then return nil end
    return math.max(0, (start or 0) + (duration or 0) - GetTime())
end

function I:Find(action)
    if not action or not action.itemId then return nil, nil end
    local bag, slot
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            if itemId(GetContainerItemLink(bag, slot)) == action.itemId then
                local _, count, locked = GetContainerItemInfo(bag, slot)
                if (count or 0) > 0 and not locked then return bag, slot end
            end
        end
    end
    return nil, nil
end

function I:Execute(action)
    if action.executor ~= "item" then return false end
    if CursorHasItem and CursorHasItem() then return false end
    local bag, slot = self:Find(action)
    if not bag then return false end
    action.bag, action.bagSlot = bag, slot
    local remaining = self:Cooldown(action)
    if remaining == nil or remaining > 0 then return false end
    if UseItemIdOrName then UseItemIdOrName(action.itemId)
    elseif UseContainerItem then UseContainerItem(bag, slot)
    else return false end
    return true
end

function I:Blocker(action, state)
    local facts, inventory = action.facts or {}, state.inventory
    if not inventory then return nil end
    if action.actor and action.actor ~= "player" then return nil end
    if action.executor == "item" and action.itemId and inventory.itemCounts
        and (inventory.itemCounts[action.itemId] or 0) <= 0 then return "item unavailable" end
    if facts.ammunition and inventory.ammo.known and (inventory.ammo.count or 0) <= 0 then
        return "ammunition"
    end
    if facts.melee and inventory.mainHand.broken then return "broken main-hand" end
    if facts.weaponRanged and inventory.ranged.broken then return "broken ranged weapon" end
    return nil
end
