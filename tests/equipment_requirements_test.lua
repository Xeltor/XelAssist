-- Shield/weapon requirements are sealed DBC masks, not localized action-name
-- exceptions, and must remain enforced after graph time advances.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end
XelAssist = { Graph = {} }
dofile("Graph/EquipmentRequirements.lua")
local Equipment = XelAssist.Graph.EquipmentRequirements

local function item(classID, subClassID, inventoryType, broken)
    return { classificationKnown = true, classID = classID,
        subClassID = subClassID, inventoryType = inventoryType,
        broken = broken and true or false }
end
local empty = { classificationKnown = true, empty = true }
local shield = item(4, 6, 14, false)
local sword = item(2, 7, 13, false)
local bow = item(2, 2, 15, false)
local state = { time = 14, inventory = {
    mainHand = sword, offHand = shield, ranged = bow } }
local shieldFacts = { equippedItemClass = 4,
    equippedItemSubClassMask = 64, equippedItemInventoryTypeMask = 16384 }

assert(Equipment:Blocker(state, shieldFacts) == nil,
    "an exact equipped shield must satisfy both DBC masks")
state.inventory.offHand = empty
assert(Equipment:Blocker(state, shieldFacts)
    == "required equipment missing or broken",
    "a future wait must not create a missing shield")
state.inventory.offHand = item(4, 6, 14, true)
assert(Equipment:Blocker(state, shieldFacts)
    == "required equipment missing or broken",
    "a proven broken shield cannot satisfy a combat requirement")
state.inventory.offHand = { classificationKnown = false }
assert(Equipment:Blocker(state, shieldFacts)
    == "equipment classification unavailable",
    "an occupied but uncached equipment lane must fail closed")
assert(Equipment:Blocker({}, shieldFacts) == "equipment state unavailable",
    "missing root equipment evidence must fail closed")
assert(Equipment:Blocker({}, { equippedItemClass = -1 }) == nil,
    "a DBC record with no equipment requirement must remain unconstrained")
state.inventory.offHand = shield
assert(Equipment:Blocker(state, { equippedItemClass = 2,
        equippedItemSubClassMask = 128,
        equippedItemInventoryTypeMask = 8192 }) == nil,
    "an exact main-hand sword must satisfy a class/subclass/type constraint")

print("ok: exact DBC combat equipment requirements survive graph depth")
