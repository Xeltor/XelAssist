-- Exact DBC equipped-item requirements remain active at every search depth.
-- The graph checks only the three combat equipment lanes and never infers
-- weapon or shield classes from localized item names.
XelAssist.Graph.EquipmentRequirements = {}
local E = XelAssist.Graph.EquipmentRequirements

local SLOTS = { "mainHand", "offHand", "ranged" }

local function flagSet(mask, bit)
    mask, bit = tonumber(mask), tonumber(bit)
    if not mask or mask <= 0 or not bit or bit <= 0 then return false end
    return math.floor(mask / bit)
        - math.floor(mask / (bit * 2)) * 2 == 1
end

local function maskAllows(mask, identifier)
    mask = tonumber(mask)
    if not mask or mask <= 0 then return true end
    identifier = tonumber(identifier)
    if not identifier or identifier < 0 or identifier > 31
        or math.floor(identifier) ~= identifier then return nil end
    return flagSet(mask, 2 ^ identifier)
end

local function matches(record, requiredClass, subclassMask, inventoryMask)
    if not record or record.classificationKnown ~= true then return nil end
    if record.empty then return false end
    if record.broken then return false end
    if tonumber(record.classID) ~= requiredClass then return false end
    local subclass = maskAllows(subclassMask, record.subClassID)
    local inventory = maskAllows(inventoryMask, record.inventoryType)
    if subclass == nil or inventory == nil then return nil end
    return subclass and inventory and true or false
end

function E:Blocker(state, tooltip)
    local requiredClass = tonumber(tooltip and tooltip.equippedItemClass)
    if not requiredClass or requiredClass < 0 then return nil end
    local inventory = state and state.inventory
    if type(inventory) ~= "table" then return "equipment state unavailable" end
    if tooltip.requiresOffhandWeapon == true then
        local result = matches(inventory.offHand, requiredClass,
            tooltip.equippedItemSubClassMask,
            tooltip.equippedItemInventoryTypeMask)
        if result == nil then return "off-hand classification unavailable" end
        return result and nil or "required off-hand weapon missing or broken"
    end
    local unknown, index = false, nil
    for index = 1, table.getn(SLOTS) do
        local result = matches(inventory[SLOTS[index]], requiredClass,
            tooltip.equippedItemSubClassMask,
            tooltip.equippedItemInventoryTypeMask)
        if result == true then return nil end
        if result == nil then unknown = true end
    end
    if unknown then return "equipment classification unavailable" end
    return "required equipment missing or broken"
end
