table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"
UIParent = {}
SlashCmdList = {}
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
SUPERWOW_VERSION = 2

local serial = 0
local createdFrames = {}
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
    if key == "RegisterEvent" then return function(s, eventName)
        local registered = rawget(s, "registered")
        if not registered then registered = {}; rawset(s, "registered", registered) end
        registered[eventName] = true
    end end
    return function() end
end

CreateFrame = function(_, name)
    serial = serial + 1
    local frame = setmetatable({ name = name or ("Mock" .. serial), shown = true }, widget)
    table.insert(createdFrames, frame)
    return frame
end
Minimap = CreateFrame("Frame", "Minimap")
getglobal = function(name)
    if not _G[name] then _G[name] = CreateFrame("Frame", name) end
    return _G[name]
end

local chatMessages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) table.insert(chatMessages, value) end }
local gameTooltipLines = {}
GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, value) table.insert(gameTooltipLines, value) end,
    AddLine = function(_, value) table.insert(gameTooltipLines, value) end,
    Show = function() end,
    Hide = function() end,
}
CooldownFrame_SetTimer = function() end
GetBindingKey = function() return "F" end
GetSpellName = function() return nil end
GetSpellTexture = function() return nil end
GetSpellCooldown = function() return 0, 0, 1 end
SpellInfo = function(id)
    if id == 348 then return "Immolate" end
    if id == 6358 then return "Seduction" end
    if id == 1459 then return "Arcane Intellect" end
    return "Spell " .. tostring(id)
end
local queuedSpell, directlyCast, directUnit
QueueSpellByName = function(name) queuedSpell = name end
CastSpellByName = function(name, unit) directlyCast, directUnit = name, unit end
IsAddOnLoaded = function() return true end
local mockTime = 0
GetTime = function() return mockTime end
GetNampowerVersion = function() return "test-3.0" end
local cvars = {}
GetCVar = function(name) return cvars[name] or "0" end
SetCVar = function(name, value) cvars[name] = tostring(value) end
UnitClass = function() return "Mage", "MAGE" end
local testTargetGUID, testPetGUID
UnitExists = function(unit)
    if unit == "target" and testTargetGUID then return true, testTargetGUID end
    if unit == "pet" and testPetGUID then return true, testPetGUID end
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

local files = { "XelAssist_Prelude.lua", "XelAssist_Capabilities.lua", "XelAssist_Delivery.lua",
    "XelAssist_Actions.lua",
    "XelAssist_Encounter.lua", "XelAssist_TargetModifiers.lua", "XelAssist_Resistance.lua",
    "XelAssist_Actors.lua", "XelAssist_Observations.lua", "XelAssist_Inventory.lua",
    "XelAssist_Graph.lua", "XelAssist_UI.lua", "XelAssist_Config.lua",
    "XelAssist_Minimap.lua", "XelAssist_Core.lua" }
local i
for i = 1, table.getn(files) do dofile(files[i]) end
local eventFrame
for i = 1, table.getn(createdFrames) do
    local frame = createdFrames[i]
    local registered = rawget(frame, "registered")
    if registered and registered.ADDON_LOADED and frame.OnEvent then
        eventFrame = frame
    end
end
assert(eventFrame, "core event dispatcher was not registered")
local function fireEvent(name, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    event, arg1, arg2, arg3, arg4 = name, a1, a2, a3, a4
    arg5, arg6, arg7, arg8, arg9 = a5, a6, a7, a8, a9
    eventFrame.OnEvent()
end

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
assert(runtime.version == "0.5.0" and runtime.nampower == "test-3.0", "runtime versions missing")
assert(runtime.actions == 0 and runtime.inferred == 0 and runtime.apis.queue,
    "runtime capability/node audit missing")
assert(runtime.evidenceEvents.damage and runtime.evidenceEvents.miss,
    "required Nampower outcome events were not enabled and audited")
assert(runtime.evidenceEvents.autoAttack
    and eventFrame.registered.AUTO_ATTACK_SELF
    and eventFrame.registered.AUTO_ATTACK_OTHER,
    "exact Nampower white-swing evidence events were not registered and audited")
local routedAutoAttack
local originalAutoAttack = XelAssistResistance.AutoAttack
function XelAssistResistance:AutoAttack(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    routedAutoAttack = { a1, a2, a3, a4, a5, a6, a7, a8, a9 }
end
fireEvent("AUTO_ATTACK_SELF", "player-guid", "target-guid", 42, 4, 1, 2, 3, 4, 5)
XelAssistResistance.AutoAttack = originalAutoAttack
assert(routedAutoAttack and routedAutoAttack[1] == "player-guid"
    and routedAutoAttack[2] == "target-guid" and routedAutoAttack[3] == 42
    and routedAutoAttack[4] == 4 and routedAutoAttack[9] == 5,
    "core must forward all nine Nampower white-swing fields unchanged")
assert(runtime.evidenceEvents.aura and runtime.evidenceEvents.start and runtime.evidenceEvents.go,
    "gated Nampower aura/cast lifecycle events were not enabled and audited")
local tooltipResistance = { school = 2, schoolName = "Fire", multiplier = 0.8,
    decisionMultiplier = 1.2, damageTakenMultiplier = 1.5, uncertaintyMultiplier = 1,
    source = "test target data", confidence = "observed", samples = 3,
    raw = 100, penetration = 0, penetrationUnknown = true, unknown = false }
local tooltipAction = { name = "Frostbolt", rank = 1, facts = { kind = "damage" } }
local followAction = { name = "Fireball", rank = 1, facts = { kind = "damage" } }
local displayPlan = { action = tooltipAction, target = "target", reason = "test resistance",
    confidence = "partial data", value = 1, threat = 1, downtime = 1.5, observed = {},
    resistance = tooltipResistance, follow = { followAction }, path = {
        { action = tooltipAction, resistance = tooltipResistance },
        { action = followAction, reason = "future exploit", downtime = 1.5,
            resistance = tooltipResistance },
    } }
gameTooltipLines = {}; XelAssistUI.lastPlan = displayPlan; XelAssistUI.lastReason = "test"
this = XelAssistUI.frame.main; this.OnEnter()
local tooltipText = table.concat(gameTooltipLines, "|")
assert(string.find(tooltipText, "Graph-scored factor 120%", 1, true)
    and string.find(tooltipText, "Fire: 80% expected output", 1, true)
    and string.find(tooltipText, "penetration unknown", 1, true)
    and not string.find(tooltipText, "penetration 0", 1, true),
    "main tooltip must explain expected output, the scored factor and unknown penetration")
tooltipResistance.mode = "mixed"
tooltipResistance.components = {
    { school = 0, schoolName = "Physical", componentWeight = 0.6,
        multiplier = 0.5, decisionWeight = 0.3, unknown = false },
    { school = 3, schoolName = "Nature", componentWeight = 0.4,
        multiplier = 0.8, decisionWeight = 0.28, unknown = true,
        penetrationUnknown = true },
}
gameTooltipLines = {}; this = XelAssistUI.frame.main; this.OnEnter()
tooltipText = table.concat(gameTooltipLines, "|")
assert(string.find(tooltipText, "Physical 50% · 60% share", 1, true)
    and string.find(tooltipText, "Nature 80% · 40% share", 1, true)
    and string.find(tooltipText, "uncertain", 1, true),
    "mixed resistance UI must expose each component's normalized share and uncertainty")
local savedEvaluatorForTooltip = XelAssistGraph.Evaluate
XelAssistGraph.Evaluate = function() return displayPlan, nil, false end
XelAssistUI:Refresh(true)
gameTooltipLines = {}; this = XelAssistUI.frame.follow[1]; this.OnEnter()
assert(string.find(table.concat(gameTooltipLines, "|"), "Graph-scored factor 120%", 1, true),
    "predicted-action tooltip must retain its resistance explanation")
XelAssistGraph.Evaluate = savedEvaluatorForTooltip
tooltipResistance.school, tooltipResistance.schoolName = nil, nil
XelAssistLog = {}
XelAssist:RecordDecision(displayPlan, "smart")
assert(XelAssistLog[1].resistanceDecisionMultiplier == 1.2
    and XelAssistLog[1].resistanceConfidence == "observed"
    and XelAssistLog[1].resistanceSamples == 3
    and XelAssistLog[1].resistanceMode == "mixed",
    "decision log must retain the resistance value and evidence actually scored")
chatMessages = {}
XelAssist:Command("log")
local readableLog = table.concat(chatMessages, "|")
assert(string.find(readableLog, "Mixed 120% scored", 1, true)
    and string.find(readableLog, "Physical 50%@60%", 1, true)
    and string.find(readableLog, "Nature 80%@40% uncertain", 1, true),
    "the readable decision log must print its mixed score, component shares and uncertainty")

local function resetCastState()
    XelAssist.pendingAuras = {}
    XelAssist.currentPendingAuras = {}
    XelAssist.spellLifecycle = {}
    XelAssist:ClearPetCast()
    XelAssistResistance.submissions = {}
    XelAssistResistance.recentSubmissions = {}
end

local immolateAction = { name = "Immolate", spellId = 348, actor = "player",
    facts = { kind = "dot", cast = 0 } }

resetCastState()
testTargetGUID = "target-a"
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid")
assert(XelAssist:IsAuraPending("Immolate"), "submitted aura was not reserved")
testTargetGUID = "target-b"
assert(not XelAssist:IsAuraPending("Immolate"), "pending aura must be target scoped")
testTargetGUID = "target-a"
assert(XelAssist:IsAuraPending("Immolate"), "target switching must not delete the original reservation")
XelAssist:ClearCurrentPendingAura()
assert(not XelAssist:IsAuraPending("Immolate"), "interrupted aura reservation was not cleared")

resetCastState()
mockTime = 1
XelAssistResistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid", "debuff")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1)
assert(XelAssist:IsAuraPending("Immolate"),
    "a retryable Nampower failure must keep the tap guard during its grace window")
fireEvent("SPELL_QUEUE_EVENT", 2, 348)
mockTime = mockTime + 0.3
assert(XelAssist:IsAuraPending("Immolate"),
    "a Nampower-retained retry must supersede the earlier failure")
fireEvent("SPELLCAST_INTERRUPTED")
assert(not XelAssist:IsAuraPending("Immolate")
    and not XelAssistResistance.submissions["target-a:player-guid:348"],
    "a terminal interruption must clear UI and resistance reservations together")

resetCastState()
XelAssistResistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid")
fireEvent("AURA_CAST_ON_OTHER", 348, "other-caster", "target-a", 6, 3, 0, 0, 15000, 0)
assert(XelAssist:IsAuraPending("Immolate"),
    "another caster's identical aura must not steal our confirmation")
fireEvent("DEBUFF_ADDED_OTHER", "target-a", 1, 348, 1)
assert(XelAssist:IsAuraPending("Immolate"),
    "caster-less debuff events must not clear an owned reservation")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 2)
local cappedSubmission = XelAssistResistance:Submission("target-a", "player-guid", 348)
assert(XelAssist:IsAuraPending("Immolate")
    and cappedSubmission
    and cappedSubmission.applicationUncertain == "target debuff bar full",
    "a full debuff bar must mark the real application submission uncertain")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 0)
local landedSubmission = XelAssistResistance:RecentSubmission("target-a", "player-guid", 348)
assert(not XelAssist:IsAuraPending("Immolate")
    and landedSubmission and landedSubmission.applicationConfirmed,
    "an uncapped exact owned aura event must confirm evidence and clear the tap guard")

resetCastState()
XelAssistResistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 0.15, nil, 348, "player-guid")
mockTime = mockTime + 0.16
assert(not XelAssist:IsAuraPending("Immolate")
    and not XelAssistResistance.submissions["target-a:player-guid:348"],
    "natural tap-guard expiry must cancel the matching resistance submission")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1)
mockTime = mockTime + 0.21
assert(not XelAssist:IsAuraPending("Immolate"),
    "an unretried exact failure must expire the reservation after its grace window")

resetCastState()
testPetGUID = "pet-guid"
XelAssistResistance.ownedCasters[testPetGUID] = {
    at = mockTime, actor = "pet", level = 60 }
XelAssist:MarkAuraPending("Corruption", 2, "target-a", 172, "player-guid")
XelAssist:MarkAuraPending("Immolate", 2, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Seduction", 4, nil, 6358, testPetGUID)
fireEvent("SPELLCAST_FAILED")
local olderPlayer = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Corruption", "target-a")]
local failedPlayer = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate", "target-a")]
local untouchedPet = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Seduction", "target-a", testPetGUID)]
assert(failedPlayer and failedPlayer.failureAt == mockTime
    and olderPlayer and not olderPlayer.failureAt
    and untouchedPet and not untouchedPet.failureAt,
    "argumentless vanilla failure must affect only the current player reservation")
mockTime = mockTime + 0.21
assert(not XelAssist:IsAuraPending("Immolate")
    and XelAssist:IsAuraPending("Corruption")
    and XelAssist:IsAuraPending("Seduction", "pet"),
    "argumentless player failure expiry must preserve older player and pet reservations")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 2, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Seduction", 4, "target-a", 6358, testPetGUID)
fireEvent("SPELLCAST_INTERRUPTED")
assert(not XelAssist:IsAuraPending("Immolate")
    and XelAssist:IsAuraPending("Seduction", "pet"),
    "player interruption must not clear the pet's application reservation")

resetCastState()
XelAssist:MarkAuraPending("Immolate A", 3, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Immolate C", 3, "target-c", 348, "player-guid")
XelAssist:MarkAuraPending("Pet Immolate", 3, "target-b", 348, testPetGUID)
fireEvent("SPELL_CAST_EVENT", 1, 348, nil, "target-a")
local playerTargetA = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate A", "target-a")]
local playerTargetC = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate C", "target-c")]
local petTargetB = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Pet Immolate", "target-b", testPetGUID)]
assert(playerTargetA and playerTargetA.state == "accepted"
    and playerTargetC and playerTargetC.state == "submitted"
    and petTargetB and petTargetB.state == "submitted",
    "accepted lifecycle evidence must update only the matching target and caster")
fireEvent("SPELL_CAST_EVENT", 1, 348, nil, "target-b")
local playerLifecycle = XelAssist:Lifecycle(348, "player-guid", "target-a", false)
local petLifecycle = XelAssist:Lifecycle(348, testPetGUID, "target-b", false)
assert(petTargetB.state == "accepted"
    and playerTargetC.state == "submitted"
    and playerLifecycle and playerLifecycle.acceptedAt
    and petLifecycle and petLifecycle.acceptedAt,
    "same-spell lifecycle records must remain independently target/caster scoped")

resetCastState()
XelAssist:MarkAuraPending("Immolate A", 3, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Immolate C", 3, "target-c", 348, "player-guid")
fireEvent("SPELL_CAST_EVENT", 0, 348, nil, "target-a")
playerTargetA = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate A", "target-a", "player-guid")]
playerTargetC = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate C", "target-c", "player-guid")]
assert(playerTargetA.failureAt == mockTime and not playerTargetC.failureAt,
    "an exact cast failure must mark only its supplied target")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Immolate", 3, "target-b", 348, "player-guid")
fireEvent("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Immolate was resisted.")
assert(XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Immolate", "target-a", "player-guid")]
    and XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Immolate", "target-b", "player-guid")],
    "localized chat fallback must not mutate reservations when exact events are available")

resetCastState()
XelAssistResistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid")
fireEvent("AURA_CAST_ON_OTHER", 348, testPetGUID, "target-a", 6, 3, 0, 0, 15000, 0)
assert(XelAssist:IsAuraPending("Immolate", "player", "target")
    and XelAssistResistance:Submission("target-a", "player-guid", 348),
    "an owned pet aura without a pet submission must not clear the player's application")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid")
XelAssist.playerCastUntil, XelAssist.playerCastName = mockTime + 5, "Immolate"
fireEvent("SPELLCAST_INTERRUPTED")
assert(not XelAssist.playerCastUntil and not XelAssist.playerCastName
    and not XelAssist:IsAuraPending("Immolate"),
    "movement interruption must clear matching fallback occupancy and reservation")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid")
XelAssist.playerCastUntil, XelAssist.playerCastName = mockTime + 5, "Shadow Bolt"
fireEvent("SPELLCAST_INTERRUPTED")
assert(not XelAssist.playerCastUntil and not XelAssist.playerCastName
    and XelAssist:IsAuraPending("Immolate"),
    "an unrelated interrupted cast must not delete another aura reservation")

resetCastState()
XelAssist:MarkAuraPending("Arcane Intellect", 3, "player-guid", 1459, "player-guid")
fireEvent("AURA_CAST_ON_SELF", 1459, "player-guid", "player-guid", 6, 3, 0, 0, 1800000, 0)
assert(not XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")],
    "an exact self-buff aura event must end its application guard")
XelAssist:MarkAuraPending("Arcane Intellect", 3, "player-guid", 1459, "player-guid")
fireEvent("AURA_CAST_ON_SELF", 1459, "player-guid", "player-guid", 6, 3, 0, 0, 1800000, 1)
local cappedBuff = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")]
assert(cappedBuff and cappedBuff.state == "buff-cap-uncertain",
    "a full friendly buff bar must keep an explicitly uncertain application guard")

resetCastState()
XelAssistResistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid", "debuff")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 1)
local irrelevantBuffCap = XelAssistResistance:RecentSubmission(
    "target-a", "player-guid", 348)
assert(not XelAssist:IsAuraPending("Immolate")
    and irrelevantBuffCap and irrelevantBuffCap.applicationConfirmed,
    "a full target buff bar must not invalidate an exact hostile debuff application")
XelAssist:MarkAuraPending("Arcane Intellect", 3, "player-guid", 1459,
    "player-guid", "buff")
fireEvent("AURA_CAST_ON_SELF", 1459, "player-guid", "player-guid", 6, 3, 0, 0,
    1800000, 2)
assert(not XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")],
    "a full target debuff bar must not invalidate an exact friendly buff application")

resetCastState()
XelAssist:MarkAuraPending("Shared Spell Player", 3, "target-a", 348, "player-guid")
XelAssist:MarkAuraPending("Shared Spell Pet", 3, "target-a", 348, testPetGUID)
fireEvent("SPELL_CAST_EVENT", 1, 348, nil, "target-a")
local ambiguousPlayer = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Shared Spell Player", "target-a", "player-guid")]
local ambiguousPet = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Shared Spell Pet", "target-a", testPetGUID)]
assert(ambiguousPlayer and ambiguousPlayer.state == "submitted"
    and ambiguousPet and ambiguousPet.state == "submitted",
    "a caster-less ambiguous cast event must not guess between player and pet")

resetCastState()
local seductionAction = { name = "Seduction", spellId = 6358, actor = "pet",
    facts = { kind = "crowdControl", cast = 1.5, channel = true } }
XelAssistResistance:Submitted(seductionAction, "target-a", { duration = 3 })
XelAssist:MarkAuraPending("Seduction", 6, "target-a", 6358, testPetGUID)
fireEvent("SPELL_START_OTHER", 0, 6358, testPetGUID, "target-a", 0, 1500, 3000, 1)
assert(XelAssist.petCastGuid == testPetGUID and XelAssist.petCastChannel
    and math.abs(XelAssist.petCastUntil - (mockTime + 4.5)) < 0.001,
    "owned pet start must sum cast preparation and channel time into occupancy")
local channelUntil = XelAssist.petCastUntil
fireEvent("SPELL_GO_OTHER", 0, 6358, testPetGUID, "target-a")
assert(XelAssist.petCastUntil == channelUntil and XelAssist.petCastChannel,
    "a matching channel GO event must not clear live pet occupancy")
fireEvent("SPELL_GO_OTHER", 0, 9999, testPetGUID, "target-a")
fireEvent("SPELL_FAILED_OTHER", testPetGUID, 9999)
assert(XelAssist.petCastUntil == channelUntil
    and XelAssist:IsAuraPending("Seduction", "pet"),
    "unrelated pet GO and failure events must not clear another spell's occupancy")
fireEvent("SPELL_FAILED_OTHER", testPetGUID, 6358)
assert(not XelAssist:IsAuraPending("Seduction", "pet") and not XelAssist.petCastUntil
    and not XelAssistResistance.submissions["target-a:pet-guid:6358"],
    "matching terminal pet failure must clear cast and application reservations")

resetCastState()
XelAssist:MarkAuraPending("Seduction", 6, "target-a", 6358, testPetGUID)
XelAssist.petCastGuid, XelAssist.petCastSpellId = testPetGUID, 6358
XelAssist.petCastUntil, XelAssist.petCastChannel = mockTime + 4, true
local replacedPetGUID = testPetGUID
testPetGUID = "replacement-pet-guid"
fireEvent("UNIT_PET", "player")
assert(not XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Seduction", "target-a", replacedPetGUID)]
    and not XelAssist.currentPendingAuras[replacedPetGUID]
    and not XelAssist.petCastUntil,
    "pet replacement must retire only the old pet's pending execution state")

XelAssistLog = {}
local lifecyclePlan = { action = { name = "Immolate", spellId = 348, rank = 1,
        actor = "player", executor = "playerSpell", facts = { kind = "dot" } },
    reason = "lifecycle test", confidence = "client data", value = 1, threat = 1,
    observed = {}, resistance = nil }
XelAssist:RecordDecision(lifecyclePlan, "smart")
fireEvent("UNIT_CASTEVENT", "player-guid", "target-a", "START", 348, 1000)
fireEvent("UNIT_CASTEVENT", "player-guid", "target-a", "CAST", 348, 0)
assert(XelAssistLog[1].status == "cast",
    "player START then CAST must reach a terminal decision status")
local petLifecyclePlan = { action = { name = "Seduction", spellId = 6358, rank = 1,
        actor = "pet", executor = "petSpell", facts = { kind = "crowdControl" } },
    reason = "pet lifecycle test", confidence = "client data", value = 1, threat = 1,
    observed = {}, resistance = nil }
XelAssist:RecordDecision(petLifecyclePlan, "smart")
fireEvent("UNIT_CASTEVENT", testPetGUID, "target-a", "CHANNEL", 6358, 1000)
fireEvent("UNIT_CASTEVENT", testPetGUID, "target-a", "CAST", 6358, 0)
assert(XelAssistLog[2].status == "cast",
    "pet CHANNEL then CAST must update the pet decision status")
testPetGUID = nil
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
resetCastState()
XelAssistGraph.Evaluate = function()
    return { action = { name = "Arcane Intellect", spellId = 1459, rank = 1,
            rankText = "Rank 1", actor = "player", facts = { kind = "buff" } },
        target = "player", reason = "test aura guard", confidence = "client data",
        value = 1, threat = 0, downtime = 1.5, observed = {}, follow = {}, path = {},
        tooltip = { duration = 1800 } }, nil, false
end
XelAssist:Execute()
assert(XelAssist:IsAuraPending("Arcane Intellect", "player", "player"),
    "friendly aura execution must reserve its cast-to-application latency window")
print("ok: full TOC-order load, initialization, UI, config and minimap")
