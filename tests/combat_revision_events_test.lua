XelAssist = { Core = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Core/CombatRevision.lua")
dofile("Core/CombatRevisionEvents.lua")
local Revision = XelAssist.Core.CombatRevision
local Events = XelAssist.Core.CombatRevisionEvents

Revision:Reset()
local names = {}
local frame = { RegisterEvent = function(_, name) names[name] = true end }
assert(Events:Register(frame) and names.PLAYER_TARGET_CHANGED
    and names.UNIT_HEALTH and names.UNIT_AURA
    and names.SPELL_UPDATE_COOLDOWN and names.UNIT_TARGET
    and names.UPDATE_SHAPESHIFT_FORM and names.UPDATE_SHAPESHIFT_FORMS,
    "the runtime must subscribe to graph-relevant stock evidence")

local initial = Revision:Snapshot()
assert(not Events:Observe("UNIT_HEALTH", "mouseover")
    and not Revision:AnyChanged(initial),
    "untracked transient units must not create combat churn")
assert(Events:Observe("UNIT_HEALTH", "target")
    and table.concat(Revision:ChangedDomains(initial), ",") == "health",
    "selected-target health must remain a soft freshness signal")

local beforeTraffic = Revision:Snapshot()
Events:Observe("SPELL_DAMAGE_EVENT_SELF")
assert(not Revision:HardChanged(beforeTraffic)
    and table.concat(Revision:ChangedDomains(beforeTraffic), ",")
        == "health,threat,engaged",
    "damage traffic must inform freshness without cancelling work")

local beforePetTarget = Revision:Snapshot()
Events:Observe("UNIT_TARGET", "pet")
assert(table.concat(Revision:ChangedDomains(beforePetTarget), ",")
        == "pet,threat,engaged",
    "companion victim changes must update pet, threat and engagement lanes")

local beforeTarget = Revision:Snapshot()
Events:Observe("PLAYER_TARGET_CHANGED")
assert(Revision:HardChanged(beforeTarget),
    "selected identity changes must invalidate old graph topology")

local beforeEquipment = Revision:Snapshot()
Events:Observe("UNIT_INVENTORY_CHANGED", "player")
assert(Revision:HardChanged(beforeEquipment)
    and table.concat(Revision:ChangedDomains(beforeEquipment), ",")
        == "inventory",
    "equipment changes must invalidate action power and inventory evidence")

local beforeForm = Revision:Snapshot()
Events:Observe("UPDATE_SHAPESHIFT_FORM")
assert(Revision:HardChanged(beforeForm),
    "stance or form changes must invalidate player threat evidence")

print("combat revision event tests passed")
