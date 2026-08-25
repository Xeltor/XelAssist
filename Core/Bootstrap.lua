-- One addon-owned namespace is the only runtime global API. WoW's 1.12
-- loader executes files in TOC order, so every later module attaches here.
XelAssist = XelAssist or {}
XelAssist.version = "0.8.6"
XelAssist.mode = XelAssist.mode or "smart"
XelAssist.Core = XelAssist.Core or {}
XelAssist.Game = XelAssist.Game or {}
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Combat = XelAssist.Combat or {}
XelAssist.Graph = XelAssist.Graph or {}
XelAssist.UI = XelAssist.UI or {}

-- Saved variables are initialized before the standalone engine loads.
if type(XelAssistDB) ~= "table" then XelAssistDB = {} end
if type(XelAssistCharDB) ~= "table" then XelAssistCharDB = {} end
BINDING_HEADER_XELASSIST = "XelAssist"
BINDING_NAME_XELASSIST_EXECUTE = "Smart Execute"
BINDING_NAME_XELASSIST_SINGLE = "Force Single Target"
BINDING_NAME_XELASSIST_AOE = "Force AoE"
BINDING_NAME_XELASSIST_SUPPORT = "Force Support / Healing"
BINDING_NAME_XELASSIST_BUFFS = "Buffs"
BINDING_NAME_XELASSIST_COOLDOWNS = "Toggle Cooldowns"
