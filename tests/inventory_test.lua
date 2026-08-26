XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
INVSLOT_AMMO, INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED = 0, 16, 17, 18
NUM_BAG_SLOTS = 4
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
local links = { [0] = "[Sharp Arrow]", [16] = "[Broken Sword]", [18] = "[Long Bow]" }
local textures = { [0] = "ammo-texture", [16] = "sword-texture",
    [17] = "uncached-equipped-texture", [18] = "bow-texture" }
GetInventoryItemLink = function(_, slot) return links[slot] end
GetInventoryItemTexture = function(_, slot)
    return textures[slot]
end
GetInventoryItemCount = function(_, slot) return slot == 0 and 12 or 1 end
GetInventoryItemDurability = function(slot)
    if slot == 16 then return 0, 40 end
    if slot == 18 then return 30, 30 end
end
GetItemInfo = function(link)
    if string.find(link or "", "item:13446") then
        return "Major Healing Potion", link, 1, 45, 0, "Consumable", "Potion", 5, "", "potion"
    end
    if string.find(link or "", "item:1111") then
        return "Conjured Food", link, 1, 1, 0, "Consumable", "Food", 20, "", "food"
    end
    if string.find(link or "", "item:2222") then
        return "Healing Trinket", link, 2, 50, 50, "Armor", "Miscellaneous", 1,
            "INVTYPE_TRINKET", "trinket"
    end
    return "Long Bow", link, 1, 40, 30, "Weapon", "Bows", 1, "INVTYPE_RANGED", "bow"
end
C_Item = {
    GetItemInfoInstant = function(link)
        if string.find(link or "", "Broken Sword", 1, true) then
            return 1001, "Weapon", "Swords", "INVTYPE_WEAPON", "sword", 2, 7
        end
        if string.find(link or "", "Long Bow", 1, true) then
            return 1002, "Weapon", "Bows", "INVTYPE_RANGED", "bow", 2, 2
        end
    end,
    GetItemInventoryTypeByID = function(id)
        if id == 1001 then return 13 end
        if id == 1002 then return 15 end
    end,
}
GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end
local bagLinks = { [1] = "|Hitem:13446:0:0:0|h[Major Healing Potion]|h",
    [2] = "|Hitem:1111:0:0:0|h[Conjured Food]|h",
    [3] = "|Hitem:2222:0:0:0|h[Healing Trinket]|h" }
GetContainerItemLink = function(bag, slot)
    if bag == 0 then return bagLinks[slot] end
end
GetContainerItemInfo = function(_, slot) return "item-" .. slot, 2 end
local tipLines = {}
UIParent = {}
CreateFrame = function()
    return { SetOwner = function() end, ClearLines = function() tipLines = {} end,
        SetBagItem = function(_, _, slot)
            if slot == 1 then tipLines = { "Major Healing Potion", "Use: Restores 1050 to 1750 health." }
            elseif slot == 2 then tipLines = { "Conjured Food", "Restores 1000 health over 30 sec. Must remain seated." }
            else tipLines = { "Healing Trinket", "Use: Restores 2000 health." } end
        end }
end
getglobal = function(name)
    local index = tonumber(string.match(name, "(%d+)$"))
    if not tipLines[index] then return nil end
    return { GetText = function() return tipLines[index] end }
end
GetTime = function() return 10 end
local cooldownStart, cooldownDuration = 8, 5
GetContainerItemCooldown = function() return cooldownStart, cooldownDuration, 1 end
local usedBag, usedSlot
UseContainerItem = function(bag, slot) usedBag, usedSlot = bag, slot end

dofile("Game/Inventory.lua")
local inventory = XelAssist.Game.Inventory:Snapshot()
assert(inventory.ammo.known and inventory.ammo.count == 12 and inventory.ammo.link)
assert(inventory.mainHand.broken and not inventory.ranged.broken)
assert(inventory.mainHand.classificationKnown
    and inventory.mainHand.classID == 2 and inventory.mainHand.subClassID == 7
    and inventory.mainHand.inventoryType == 13,
    "combat equipment must retain exact numeric item classification")
assert(not inventory.offHand.classificationKnown and not inventory.offHand.empty,
    "an occupied cache-cold lane must remain unknown rather than become empty")
textures[17] = nil
local emptyInventory = XelAssist.Game.Inventory:Snapshot()
assert(emptyInventory.offHand.classificationKnown
    and emptyInventory.offHand.empty,
    "an exactly empty equipment lane must retain known emptiness")
assert(inventory.ranged.itemSubtype == "Bows")
assert(XelAssist.Game.Inventory:Blocker({ facts = { melee = true } }, { inventory = inventory }) == "broken main-hand")
assert(not XelAssist.Game.Inventory:Blocker({ actor = "pet", facts = { melee = true } }, { inventory = inventory }),
    "player equipment must not constrain a controlled actor")
inventory.ammo.count = 0
assert(XelAssist.Game.Inventory:Blocker({ facts = { ammunition = true } }, { inventory = inventory }) == "ammunition")
assert(not XelAssist.Game.Inventory:Blocker({ facts = { ranged = true } }, { inventory = inventory }),
    "generic ranged spells must not be mistaken for ammunition users")
local actions = XelAssist.Game.Inventory:Actions()
assert(table.getn(actions) == 1 and actions[1].name == "Major Healing Potion",
    "only the immediate-use potion should become an item action")
assert(actions[1].itemFacts.average == 1400 and actions[1].facts.self)
assert(actions[1].itemId == 13446)
assert(XelAssist.Game.Inventory:Cooldown(actions[1]) == 3)
cooldownStart, cooldownDuration = 0, 0
assert(XelAssist.Game.Inventory:Execute(actions[1]) and usedBag == 0 and usedSlot == 1)
bagLinks[1], bagLinks[2] = "|Hitem:9999:0:0:0|h[Other Item]|h", bagLinks[1]
usedBag, usedSlot = nil, nil
assert(XelAssist.Game.Inventory:Execute(actions[1]) and usedSlot == 2,
    "execution must re-resolve a moved item instead of using the stale slot")
bagLinks[2] = nil; usedBag, usedSlot = nil, nil
assert(not XelAssist.Game.Inventory:Execute(actions[1]) and not usedSlot,
    "execution must refuse when the exact item is no longer carried")
print("ok: equipment durability and ammunition constraints")
