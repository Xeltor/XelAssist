XelAssist = { Game = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
local operations = {}
UnitExists = function() return true end
UnitXP = function(operation)
    table.insert(operations, operation)
    if operation == "inSight" then return false end
    if operation == "behind" then return true end
end
dofile("Game/Geometry.lua")
local geometry = XelAssist.Game.Geometry:Observe("player", "target")
assert(geometry.lineOfSight == nil and geometry.behind == true
    and geometry.source == "UnitXP" and table.getn(operations) == 1
    and operations[1] == "behind",
    "unproven inSight hints must stay outside graph and execution legality")
UnitXP = nil
geometry = XelAssist.Game.Geometry:Observe("player", "target")
assert(geometry.lineOfSight == nil and geometry.behind == nil,
    "missing geometry evidence must remain unknown")
print("ok: proven positioning without invented line of sight")
