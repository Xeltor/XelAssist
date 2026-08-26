-- Unknown General/racial actions must not inherit generic combat utility.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

BOOKTYPE_SPELL = "spell"
UIParent = {}
local tabEvidence = true
GetNumSpellTabs = function() return tabEvidence and 2 or nil end
GetSpellTabInfo = function(index)
    if not tabEvidence then return nil end
    if index == 1 then return "General", nil, 0, 5 end
    return "Class", nil, 5, 1
end

local names = { "Attack", "War Stomp", "Stoneform", "Cannibalize",
    "Proven Shared Racial", "Class Bolt" }
local ids = { 6603, 20549, 20594, 20577, 99901, 99902 }
GetSpellName = function(slot)
    return names[slot], names[slot] and "Rank 1" or nil
end
GetSpellSlotTypeIdForName = function(castName)
    local index
    for index = 1, table.getn(names) do
        if castName == names[index] .. "(Rank 1)" then
            return index, "spell", ids[index]
        end
    end
end
IsPassiveSpell = function() return false end

local lines = {}
local tip = { SetOwner = function() end, ClearLines = function() end,
    SetSpell = function(_, slot) lines = {
        [2] = slot == 3 and "Makes you immune to poison"
            or slot == 4 and "Restores 35% health over 10 sec"
            or slot == 6 and "Deals 50 Arcane damage" or "" }
    end }
CreateFrame = function() return tip end
getglobal = function(name)
    local index = tonumber(string.gsub(name, "%D", ""))
    if not string.find(name, "TextLeft") or not lines[index]
        or lines[index] == "" then return nil end
    return { GetText = function() return lines[index] end }
end

XelAssist = { Game = { Player = {}, ActionInference = {
    ClassKnowledge = function() return nil, nil, false end,
    ExactKnowledge = function(_, spellId)
        if spellId == 20549 then
            return { kind = "crowdControl", duration = 2 }, nil, true
        end
        return nil, nil, false
    end,
} }, Combat = { Knowledge = {
    Attack = { kind = "command", playerAttack = true },
    ["Proven Shared Racial"] = { kind = "resource", self = true },
} }, Graph = {}, UI = {} }

dofile("Game/RacialActions.lua")
dofile("Game/Capabilities.lua")
local C = XelAssist.Game.Capabilities
C:BuildSpellIndex()
local actions = C.actions
assert(table.getn(actions) == 3 and actions[1].name == "Attack"
    and actions[2].name == "Proven Shared Racial"
    and actions[3].name == "Class Bolt"
    and actions[3].facts.kind == "damage",
    "unknown racial control, immunity and healing must fail closed while "
        .. "explicit shared and class-tab actions remain admissible")

tabEvidence = false
C:BuildSpellIndex()
assert(table.getn(C.actions) == 2 and C.actions[1].name == "Attack"
    and C.actions[2].name == "Proven Shared Racial",
    "missing tab provenance must disable generic inference, not known actions")

print("ok: racial combat optimization is enforced as an explicit deferral")
