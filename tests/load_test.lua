table.getn = table.getn or function(t) return #t end
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"
UIParent = {}
SlashCmdList = {}
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
SUPERWOW_VERSION = 2

local serial = 0
local widget = {}
widget.__index = function(self, key)
    if key == "CreateFontString" or key == "CreateTexture" then
        return function() serial = serial + 1; return setmetatable({ name = "Mock" .. serial }, widget) end
    end
    if key == "GetName" then return function(s) return s.name end end
    if key == "GetFrameLevel" then return function() return 1 end end
    if key == "GetPoint" then return function() return "CENTER", UIParent, "CENTER", 0, 0 end end
    if key == "GetScale" then return function(s) return s.scale or 1 end end
    if key == "GetValue" then return function(s) return s.value or 1 end end
    if key == "GetChecked" then return function(s) return s.checked end end
    if key == "IsShown" then return function(s) return s.shown ~= false end end
    if key == "GetText" then return function(s) return s.text end end
    if key == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 10, "" end end
    if key == "SetText" then return function(s, value) s.text = value end end
    if key == "SetScale" then return function(s, value) s.scale = value end end
    if key == "SetValue" then return function(s, value) s.value = value end end
    if key == "SetChecked" then return function(s, value) s.checked = value end end
    if key == "Show" then return function(s) s.shown = true end end
    if key == "Hide" then return function(s) s.shown = false end end
    if key == "SetScript" then return function(s, eventName, callback) s[eventName] = callback end end
    return function() end
end

CreateFrame = function(_, name)
    serial = serial + 1
    return setmetatable({ name = name or ("Mock" .. serial), shown = true }, widget)
end
Minimap = CreateFrame("Frame", "Minimap")
getglobal = function(name)
    if not _G[name] then _G[name] = CreateFrame("Frame", name) end
    return _G[name]
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
CooldownFrame_SetTimer = function() end
GetBindingKey = function() return "F" end
GetSpellName = function() return nil end
GetSpellTexture = function() return nil end
GetSpellCooldown = function() return 0, 0, 1 end
SpellInfo = function(id) return "Spell " .. tostring(id) end
local queuedSpell, directlyCast, directUnit
QueueSpellByName = function(name) queuedSpell = name end
CastSpellByName = function(name, unit) directlyCast, directUnit = name, unit end
IsAddOnLoaded = function() return true end
GetTime = function() return 0 end
GetNampowerVersion = function() return "test-3.0" end
UnitClass = function() return "Mage", "MAGE" end
local testTargetGUID
UnitExists = function(unit)
    if unit == "target" and testTargetGUID then return true, testTargetGUID end
    return unit == "player", unit == "player" and "player-guid" or nil
end
UnitCanAssist = function() return false end
UnitCanAttack = function() return false end
UnitIsDead = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 1000 end
UnitHealthMax = function() return 1000 end
UnitMana = function() return 1000 end
UnitManaMax = function() return 1000 end
UnitPowerType = function() return 0 end
UnitBuff = function() return nil end
UnitDebuff = function() return nil end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
GetShapeshiftForm = function() return 0 end
GetComboPoints = function() return 0 end
GetInventoryItemLink = function() return nil end

local files = { "XelAssist_Prelude.lua", "XelAssist_Capabilities.lua", "XelAssist_Actions.lua",
    "XelAssist_Actors.lua", "XelAssist_Observations.lua", "XelAssist_Inventory.lua",
    "XelAssist_Graph.lua", "XelAssist_UI.lua", "XelAssist_Config.lua",
    "XelAssist_Minimap.lua", "XelAssist_Core.lua" }
local i
for i = 1, table.getn(files) do dofile(files[i]) end

XelAssist:Init()
XelAssistConfig:Build()
XelAssistUI:Refresh(true)
assert(XelAssistUI.frame and XelAssistUI.frame.main, "recommendation frame did not build")
assert(table.getn(XelAssistUI.frame.follow) == 4, "future-action runway should expose four slots")
assert(XelAssistConfig.frame and XelAssistConfig.frame.depth, "character graph controls did not build")
assert(XelAssistMinimap.button, "minimap entry did not build")
assert(XelAssistCharDB.graphDepth == 3 and XelAssistCharDB.role == "auto", "character defaults missing")
assert(XelAssistCharDB.toggles.consumables == false, "finite consumables must default disabled")
assert(XelAssistCharDB.schema == 4, "saved-variable schema did not migrate")
local runtime = XelAssist:RuntimeAudit()
assert(runtime.version == "0.4.0" and runtime.nampower == "test-3.0", "runtime versions missing")
assert(runtime.actions == 0 and runtime.inferred == 0 and runtime.apis.queue,
    "runtime capability/node audit missing")
testTargetGUID = "target-a"
XelAssist:MarkAuraPending("Immolate", 2)
assert(XelAssist:IsAuraPending("Immolate"), "submitted aura was not reserved")
testTargetGUID = "target-b"
assert(not XelAssist:IsAuraPending("Immolate"), "pending aura must be target scoped")
testTargetGUID = "target-a"
assert(XelAssist:IsAuraPending("Immolate"), "target switching must not delete the original reservation")
XelAssist:ClearCurrentPendingAura()
assert(not XelAssist:IsAuraPending("Immolate"), "interrupted aura reservation was not cleared")
local evaluator = XelAssistGraph.Evaluate
XelAssistGraph.Evaluate = function() error("synthetic graph failure") end
XelAssistUI:Refresh(true)
assert(string.find(XelAssistUI.lastReason, "Graph data could not be evaluated"), "preview failure did not hold safely")
assert(XelAssistCharDB.runtime.lastError, "graph failure was not retained for diagnostics")
XelAssistGraph.Evaluate = evaluator
XelAssist.executionEnabled = false; XelAssist.missing = { "Nampower" }
XelAssistUI:Refresh(true)
assert(string.find(XelAssistUI.lastReason, "Dependencies missing: Nampower"), "dependency state was not surfaced")
XelAssist.executionEnabled = true
XelAssistGraph.Evaluate = function()
    return { action = { name = "Frostbolt", rank = 1, rankText = "Rank 1", facts = { kind = "damage" } },
        target = "target", reason = "test", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
XelAssist:Execute()
assert(queuedSpell == "Frostbolt(Rank 1)" and not directlyCast,
    "selected-target actions must use the Nampower queue")
queuedSpell, directlyCast, directUnit = nil, nil, nil
XelAssistGraph.Evaluate = function()
    return { action = { name = "Flash Heal", rank = 1, rankText = "Rank 1", facts = { kind = "heal" } },
        target = "party1", reason = "test", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
XelAssist:Execute()
assert(directlyCast == "Flash Heal(Rank 1)" and directUnit == "party1" and not queuedSpell,
    "explicit friendly-unit actions must preserve their target")
print("ok: full TOC-order load, initialization, UI, config and minimap")
