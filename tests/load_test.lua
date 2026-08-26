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
COOLDOWN_FRAME_TYPE = nil
XelAssistTestRejectCooldownTemplate = true

local serial = 0
local createdFrames = {}
local widget = {}
function XelAssistTestNoteMethod(target, name)
    local calls = rawget(target, "methodCalls")
    if not calls then calls = {}; rawset(target, "methodCalls", calls) end
    calls[name] = (calls[name] or 0) + 1
end
widget.__index = function(self, key)
    if key == "CreateFontString" or key == "CreateTexture" then
        return function() serial = serial + 1; return setmetatable({ name = "Mock" .. serial }, widget) end
    end
    if key == "GetName" then return function(s) return s.name end end
    if key == "GetFrameLevel" then return function() return 1 end end
    if key == "GetPoint" then return function(s, index)
        XelAssistTestNoteMethod(s, "GetPoint")
        local points = rawget(s, "points")
        local point = points and points[index or 1]
        if point then return point[1], point[2], point[3], point[4], point[5] end
        return "CENTER", UIParent, "CENTER", 0, 0
    end end
    if key == "GetScale" then return function(s) return s.scale or 1 end end
    if key == "GetWidth" then return function(s) return s.width or 0 end end
    if key == "GetHeight" then return function(s) return s.height or 0 end end
    if key == "GetValue" then return function(s) return s.value or 1 end end
    if key == "GetChecked" then return function(s) return s.checked end end
    if key == "IsEnabled" then return function(s) return s.enabled ~= false end end
    if key == "IsShown" then return function(s) return s.visible ~= false end end
    if key == "GetText" then return function(s) return s.text end end
    if key == "GetStringWidth" then return function(s) return string.len(s.text or "") * 5 end end
    if key == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 10, "" end end
    if key == "SetText" then return function(s, value) s.text = value end end
    if key == "SetBackdrop" then return function(s, value) s.backdrop = value end end
    if key == "SetBackdropColor" then return function(s, r, g, b, a)
        s.backdropColor = { r, g, b, a }
    end end
    if key == "SetBackdropBorderColor" then return function(s, r, g, b, a)
        s.backdropBorderColor = { r, g, b, a }
    end end
    if key == "SetTexture" then return function(s, a, b, c, d)
        s.texture = { a, b, c, d }
    end end
    if key == "SetHighlightTexture" then return function(s, value)
        s.highlightTexture = value
    end end
    if key == "SetDesaturated" then return function(s, value) s.desaturated = value end end
    if key == "SetScale" then return function(s, value) s.scale = value end end
    if key == "SetWidth" then return function(s, value) s.width = value end end
    if key == "SetHeight" then return function(s, value)
        XelAssistTestNoteMethod(s, "SetHeight"); s.height = value
    end end
    if key == "SetValue" then return function(s, value) s.value = value end end
    if key == "SetChecked" then return function(s, value) s.checked = value end end
    if key == "SetPoint" then return function(s, point, relative, relativePoint, x, y)
        XelAssistTestNoteMethod(s, "SetPoint")
        local points = rawget(s, "points")
        if not points then points = {}; rawset(s, "points", points) end
        table.insert(points, { point, relative, relativePoint, x, y })
    end end
    if key == "ClearAllPoints" then return function(s)
        XelAssistTestNoteMethod(s, "ClearAllPoints"); rawset(s, "points", {})
    end end
    if key == "Enable" then return function(s) s.enabled = true end end
    if key == "Disable" then return function(s) s.enabled = false end end
    if key == "Show" then return function(s) s.visible = true end end
    if key == "Hide" then return function(s) s.visible = false end end
    if key == "SetScript" then return function(s, eventName, callback)
        XelAssistTestNoteMethod(s, "SetScript"); s[eventName] = callback
    end end
    if key == "RegisterEvent" then return function(s, eventName)
        local registered = rawget(s, "registered")
        if not registered then registered = {}; rawset(s, "registered", registered) end
        registered[eventName] = true
    end end
    return function() end
end

CreateFrame = function(frameType, name, parent, template)
    if template == "CooldownFrameTemplate" then
        XelAssistTestLastCooldownFrameType = frameType
        if XelAssistTestRejectCooldownTemplate then
            error("mock client rejected optional cooldown constructor")
        end
    end
    serial = serial + 1
    local frame = setmetatable({ name = name or ("Mock" .. serial), visible = true,
        enabled = true, frameType = frameType, parent = parent, template = template }, widget)
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
local queuedSpell, directlyCast, directUnit, queueCount, directCastCount =
    nil, nil, nil, 0, 0
local petActionCount, petActionSlot = 0, nil
QueueSpellByName = function(name, guid)
    queuedSpell, queueCount = name, queueCount + 1
    if XelAssistTestQueueHook then XelAssistTestQueueHook(name, guid) end
end
CastSpellByName = function(name, unit)
    directlyCast, directUnit, directCastCount = name, unit, directCastCount + 1
end
CastPetAction = function(slot)
    petActionSlot, petActionCount = slot, petActionCount + 1
end
IsAddOnLoaded = function() return true end
local mockTime = 0
GetTime = function() return mockTime end
GetNampowerVersion = function() return 4, 7, 1 end
GetOnSwingInfo = function() return XelAssistTestOnSwingNative end
local cvars = {}
GetCVar = function(name) return cvars[name] or "0" end
SetCVar = function(name, value) cvars[name] = tostring(value) end
UnitClass = function() return "Mage", "MAGE" end
UnitLevel = function() return 12 end
local unitNameCalls = {}
UnitName = function(unit)
    table.insert(unitNameCalls, unit)
    if unit == "target" then return "Target" end
    if unit == "party1" then return "Test Ally" end
    if unit == "party2" then return "An Extremely Long Friendly Target Name" end
    if unit == "pet" then return "Companion" end
    if unit == "player" then return "Player" end
    return unit
end
local testTargetGUID, testPetGUID
local testFriendlyGUIDs, testAssistUnits = {}, {}
UnitExists = function(unit)
    if unit == "target" and testTargetGUID then return true, testTargetGUID end
    if unit == "pet" and testPetGUID then return true, testPetGUID end
    if testFriendlyGUIDs[unit] then return true, testFriendlyGUIDs[unit] end
    return unit == "player", unit == "player" and "player-guid" or nil
end
IsSpellInRange = function(_, unit)
    return UnitExists(unit) and 1 or nil
end
UnitXP = function(operation, from, to)
    if operation == "distanceBetween" and UnitExists(from) and UnitExists(to) then
        return 3
    end
    if operation == "inSight" and UnitExists(from) and UnitExists(to) then
        return true
    end
    if operation == "behind" and UnitExists(from) and UnitExists(to) then
        return false
    end
    return nil
end
UnitCanAssist = function(_, unit)
    return unit == "player" or testAssistUnits[unit] and true or false
end
UnitCanAttack = function() return false end
UnitIsDead = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 1000 end
UnitHealthMax = function() return 1000 end
UnitMana = function() return 1000 end
UnitManaMax = function() return 1000 end
UnitPowerType = function() return 0 end
local liveBuffSpellIds = {}
UnitBuff = function(unit, index)
    local spellId = liveBuffSpellIds[unit]
    if spellId and index == 1 then return "buff-texture", 1, spellId end
    return nil
end
UnitDebuff = function() return nil end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
GetShapeshiftForm = function() return 0 end
GetComboPoints = function() return 0 end
GetInventoryItemLink = function() return nil end

local files = {}
local raw
for raw in io.lines("XelAssist.toc") do
    local path = string.gsub(raw, "\\", "/")
    if not string.find(path, "^#") and string.find(path, "%.lua%s*$") then
        table.insert(files, path)
    end
end
local i
for i = 1, table.getn(files) do dofile(files[i]) end

-- 0.8.28 loads the cross-class DBC decoder as recommendation-neutral
-- infrastructure. Any production caller would add cold client reads or rich
-- descriptor copies to the combat path before a consumer has been benchmarked.
local semanticMethods = { "Decode", "Resolve", "InferAction", "Apply", "Invalidate" }
for i = 1, table.getn(semanticMethods) do
    local name = semanticMethods[i]
    XelAssist.Game.SpellSemantics[name] = function()
        error("recommendation-neutral SpellSemantics caller: " .. name)
    end
end
local eventFrame
focusEventFrame = nil
attackRoundEventFrame = nil
for i = 1, table.getn(createdFrames) do
    local frame = createdFrames[i]
    local registered = rawget(frame, "registered")
    if registered and registered.ADDON_LOADED and frame.OnEvent then
        eventFrame = frame
    end
    if registered and registered.SPELL_ENERGIZE_BY_SELF
        and registered.PLAYER_CONTROL_LOST
        and registered.UNIT_AURA and frame.OnEvent then
        focusEventFrame = frame
    end
    if registered and registered.PET_ATTACK_START
        and registered.UNIT_ATTACK_SPEED and registered.UNIT_TARGET
        and not registered.SPELL_ENERGIZE_BY_SELF and frame.OnEvent then
        attackRoundEventFrame = frame
    end
end
assert(eventFrame, "core event dispatcher was not registered")
assert(focusEventFrame, "Hunter focus evidence dispatcher was not registered")
assert(attackRoundEventFrame,
    "companion attack-round invalidation dispatcher was not registered")
local function fireEvent(name, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    event, arg1, arg2, arg3, arg4 = name, a1, a2, a3, a4
    arg5, arg6, arg7, arg8, arg9 = a5, a6, a7, a8, a9
    eventFrame.OnEvent()
end
function fireFocusEvent(name, a1, a2, a3, a4)
    event, arg1, arg2, arg3, arg4 = name, a1, a2, a3, a4
    focusEventFrame.OnEvent()
end

XelAssist:Init()
XelAssist.UI.Settings:Build()
XelAssist.UI.HUD:Refresh(true)
function XelAssistTestExecutePublished()
    -- Execution tests publish outside the input call, matching the runtime HUD
    -- driver while retaining explicit control over each mocked graph result.
    XelAssist.UI.HUD:Refresh(true)
    XelAssist.Execute(XelAssist)
end
local savedCurrentCast = XelAssist.Game.Capabilities.CurrentCast
XelAssist.Game.Capabilities.CurrentCast = function()
    return "Test Channel", 2, true, 0, true, 15407
end
local channelSnapshot = XelAssist.Graph.State:Snapshot("smart")
XelAssist.Game.Capabilities.CurrentCast = savedCurrentCast
assert(channelSnapshot.playerCasting and channelSnapshot.playerChanneling
    and channelSnapshot.castRemaining == 2
    and channelSnapshot.playerCastSpellId == 15407,
    "graph state must preserve the native channel distinction")
assert(XelAssist.UI.HUD.frame and XelAssist.UI.HUD.frame.main, "recommendation frame did not build")
assert(XelAssist.UI.HUD.frame:GetWidth() == 372,
    "recommendation runway must reserve enough width for readable action contracts")
assert(table.getn(XelAssist.UI.HUD.frame.follow) == 4, "future-action runway should expose four slots")
assert(XelAssist.UI.Settings.frame and XelAssist.UI.Settings.frame.depth, "character graph controls did not build")
assert(getglobal("XelAssistDepthSliderText"):GetText() == "Decision steps shown"
    and string.find(XelAssist.UI.Settings.frame.depthHelp:GetText(),
        "current only", 1, true),
    "graph-depth control must explain the current-plus-future decision rail")
assert(XelAssist.UI.Settings.frame.soulShardReserve
    and not XelAssist.UI.Settings.frame.soulShardReserve:IsShown(),
    "the character-specific Soul Shard reserve must stay hidden off Warlock")
do
    local savedUnitClass = UnitClass
    UnitClass = function() return "Warlock", "WARLOCK" end
    XelAssist.UI.Settings:Refresh()
    local shardSlider = XelAssist.UI.Settings.frame.soulShardReserve
    assert(shardSlider:IsShown() and shardSlider:GetValue() == 3
        and XelAssistCharDB.soulShardReserve == 3
        and getglobal("XelAssistSoulShardSliderText"):GetText()
            == "Soul Shards kept: 3",
        "Warlocks must receive a visible character-specific three-shard reserve")
    shardSlider.value, this = 2, shardSlider
    shardSlider.OnValueChanged()
    assert(XelAssistCharDB.soulShardReserve == 2
        and getglobal("XelAssistSoulShardSliderText"):GetText()
            == "Soul Shards kept: 2",
        "the Soul Shard reserve slider must persist a bounded character value")
    XelAssistCharDB.soulShardReserve = 3
    UnitClass = savedUnitClass
    XelAssist.UI.Settings:Refresh()
end
assert(XelAssist.UI.HUD.frame.instrumentStyle
    and XelAssist.UI.Settings.frame.instrumentStyle
    and XelAssist.UI.HUD.frame.backdrop.edgeFile
        == XelAssist.UI.Settings.frame.backdrop.edgeFile
    and XelAssist.UI.HUD.frame.classStripe
    and XelAssist.UI.Settings.frame.classStripe
    and table.getn(XelAssist.UI.Settings.frame.sectionRails) == 4,
    "settings must share the HUD instrument backdrop, border, class stripe and quiet rails")
assert(rawget(XelAssist.UI.HUD.frame.main, "template") == nil
    and XelAssist.UI.HUD.frame.main.iconFrame
    and rawget(XelAssist.UI.HUD.frame.main, "cooldown") == nil
    and XelAssist.UI.HUD.frame.main.step:GetText() == "01"
    and rawget(XelAssist.UI.HUD.frame.follow[1], "border") == nil,
    "recommendation icons must survive an unavailable optional cooldown overlay")
assert(XelAssistTestLastCooldownFrameType == "Model",
    "Vanilla cooldown overlays must prefer the client-compatible Model frame type")
do
    XelAssistTestRejectCooldownTemplate = false
    local owner = CreateFrame("Button", nil, UIParent)
    local icon, _, cooldown = XelAssist.UI.Theme:CreateActionIcon(owner, 52, true)
    local first, second = cooldown and cooldown.points and cooldown.points[1],
        cooldown and cooldown.points and cooldown.points[2]
    assert(cooldown and first and second
        and first[1] == "TOPLEFT" and first[2] == icon
        and first[3] == "TOPLEFT" and first[4] == 0 and first[5] == 0
        and second[1] == "BOTTOMRIGHT" and second[2] == icon
        and second[3] == "BOTTOMRIGHT" and second[4] == 0 and second[5] == 0,
        "the HUD cooldown sweep must cover the exact rendered icon geometry")
    XelAssistTestRejectCooldownTemplate = true
end
assert(XelAssist.UI.Settings.frame.macro.frameType == "Frame"
    and XelAssist.UI.Settings.frame.macro.command == "/xa"
    and XelAssist.UI.Settings.frame.macro.text:GetText() == "/xa"
    and rawget(XelAssist.UI.Settings.frame.macro, "OnEditFocusGained") == nil,
    "the macro contract must be fixed /xa display text, never an editable field")
gameTooltipLines = {}; this = XelAssist.UI.Settings.frame.macro; this.OnEnter()
assert(string.find(table.concat(gameTooltipLines, "|"),
    "consumes one fresh graph publication", 1, true),
    "the fixed /xa help must explain its one-action execution contract")
gameTooltipLines = {}; this = XelAssist.UI.Settings.frame.cooldowns; this.OnEnter()
assert(XelAssist.UI.Settings.frame.cooldowns:GetWidth() == 158
    and string.find(table.concat(gameTooltipLines, "|"),
    "No currently learned graph-gated cooldown actions", 1, true),
    "the cooldown label must be hoverable and truthfully report when none are learned")
do
    local savedActions, savedFacts = XelAssist.Game.Actors.Actions,
        XelAssist.Game.Actors.Facts
    local iceOne = { name = "Ice Block", rank = 1, actor = "player",
        facts = { kind = "defensive", cooldown = true } }
    local iceTwo = { name = "Ice Block", rank = 2, actor = "player",
        facts = { kind = "defensive", cooldown = true } }
    local slowBurst = { name = "Slow Burst", rank = 1, actor = "player",
        facts = { kind = "damage" } }
    XelAssist.Game.Actors.Actions = function()
        return { iceOne, iceTwo, slowBurst,
            { name = "Frostbolt", rank = 1, actor = "player",
                facts = { kind = "damage" } },
            { name = "Major Healing Potion", rank = 1, actor = "player",
                facts = { kind = "heal", cooldown = true, consumable = true } } }
    end
    XelAssist.Game.Actors.Facts = function(_, action)
        return { cooldown = action == slowBurst and 45 or 0 }
    end
    local learned = XelAssist.UI.CooldownPolicy:LearnedActions()
    assert(table.getn(learned) == 2
        and (learned[1].action == iceTwo or learned[2].action == iceTwo),
        "cooldown help must deduplicate ranks and retain the learned highest rank")
    gameTooltipLines = {}; this = XelAssist.UI.Settings.frame.cooldowns; this.OnEnter()
    local policyTooltip = table.concat(gameTooltipLines, "|")
    assert(string.find(policyTooltip, "Ice Block", 1, true)
        and string.find(policyTooltip, "Slow Burst · 45s cooldown", 1, true)
        and not string.find(policyTooltip, "Frostbolt", 1, true)
        and not string.find(policyTooltip, "Major Healing Potion", 1, true)
        and not string.find(policyTooltip, "Presence of Mind", 1, true),
        "cooldown help must name only learned actions governed by the graph policy")
    XelAssist.Game.Actors.Actions, XelAssist.Game.Actors.Facts = savedActions, savedFacts
end
assert(XelAssist.UI.Minimap.button,
    "minimap entry must still build when the optional HUD cooldown is unavailable")
assert(XelAssistCharDB.visibleSteps == 3 and XelAssistCharDB.graphDepth == nil
    and XelAssistCharDB.role == "auto", "character defaults missing")
assert(XelAssistCharDB.toggles.consumables == false, "finite consumables must default disabled")
assert(XelAssistCharDB.schema == 5
    and XelAssistCharDB.toggles.engagedTargets == false,
    "saved-variable schema did not migrate with safe hostile-target defaults")
local runtime = XelAssist:RuntimeAudit()
assert(runtime.version == "0.8.75" and runtime.nampower == "4.7.1", "runtime versions missing")
assert(runtime.class == "MAGE" and runtime.level == 12
    and runtime.role == "auto" and runtime.session.decisions == 0,
    "runtime smoke identity and session evidence missing")
assert(runtime.actions == 0 and runtime.inferred == 0 and runtime.apis.queue,
    "runtime capability/node audit missing")
assert(not runtime.apis.comboOwner and not runtime.apis.comboDuration,
    "missing optional ClassicAPI combo bridges must remain visible fallbacks")
assert(not runtime.apis.equippedHit and not runtime.hitBonuses.equipmentKnown,
    "missing equipped-hit bridge must remain a visible conservative gap")
assert(runtime.evidenceEvents.damage and runtime.evidenceEvents.miss,
    "required Nampower outcome events were not enabled and audited")
assert(runtime.evidenceEvents.autoAttack
    and eventFrame.registered.AUTO_ATTACK_SELF
    and eventFrame.registered.AUTO_ATTACK_OTHER,
    "exact Nampower white-swing evidence events were not registered and audited")
assert(runtime.evidenceEvents.onSwingExact
    and eventFrame.registered.SPELL_ON_SWING_STATE
    and GetCVar("NP_QueueOnSwingSpells") == "0",
    "exact on-swing ownership must register its event and disable native replacement buffering")
local routedAutoAttack
local originalAutoAttack = XelAssist.Combat.Resistance.AutoAttack
routedAttackRound, routedPlayerRound = nil, nil
XelAssistTestOriginalAttackRoundObserve = XelAssist.Game.AttackRounds.Observe
XelAssistTestOriginalPlayerRoundObserve =
    XelAssist.Game.Player.AttackRounds.Observe
function XelAssist.Combat.Resistance:AutoAttack(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    routedAutoAttack = { a1, a2, a3, a4, a5, a6, a7, a8, a9 }
    return { actor = "pet", hand = "main", outcome = "miss", hitInfo = a4,
        evidence = "ordinary-miss", exactDelivery = true }
end
function XelAssist.Game.AttackRounds:Observe(attackerGuid, targetGuid, result, at)
    routedAttackRound = { attackerGuid, targetGuid, result, at }
end
function XelAssist.Game.Player.AttackRounds:Observe(
    attackerGuid, targetGuid, result, at)
    routedPlayerRound = { attackerGuid, targetGuid, result, at }
end
fireEvent("AUTO_ATTACK_SELF", "player-guid", "target-guid", 42, 4, 1, 2, 3, 4, 5)
XelAssist.Combat.Resistance.AutoAttack = originalAutoAttack
XelAssist.Game.AttackRounds.Observe = XelAssistTestOriginalAttackRoundObserve
XelAssist.Game.Player.AttackRounds.Observe =
    XelAssistTestOriginalPlayerRoundObserve
assert(routedAutoAttack and routedAutoAttack[1] == "player-guid"
    and routedAutoAttack[2] == "target-guid" and routedAutoAttack[3] == 42
    and routedAutoAttack[4] == 4 and routedAutoAttack[9] == 5,
    "core must forward all nine Nampower white-swing fields unchanged")
assert(routedAttackRound and routedAttackRound[1] == "player-guid"
    and routedAttackRound[2] == "target-guid"
    and routedAttackRound[3].outcome == "miss"
    and routedAttackRound[4] == mockTime,
    "core must route the classified round and exact observation time once")
local hostileResetReason
local originalHostileReset = XelAssist.Game.HostileAttackRounds.Reset
function XelAssist.Game.HostileAttackRounds:Reset(reason)
    hostileResetReason = reason
end
fireEvent("UNIT_AURA", "player")
assert(hostileResetReason == "player mitigation regime changed",
    "player aura changes must retire stale post-mitigation hostile rounds")
hostileResetReason = nil
fireEvent("UNIT_INVENTORY_CHANGED", "player")
assert(hostileResetReason == "player mitigation regime changed",
    "equipment changes must retire stale post-mitigation hostile rounds")
XelAssist.Game.HostileAttackRounds.Reset = originalHostileReset
assert(routedPlayerRound and routedPlayerRound[1] == "player-guid"
    and routedPlayerRound[2] == "target-guid"
    and routedPlayerRound[3].exactDelivery
    and routedPlayerRound[4] == mockTime,
    "core must route the same classified packet to the separate player ledger")
assert(runtime.evidenceEvents.aura and runtime.evidenceEvents.start
    and runtime.evidenceEvents.go and runtime.evidenceEvents.castResult
    and eventFrame.registered.SPELL_CAST_RESULT_SELF,
    "gated Nampower aura/cast lifecycle events were not enabled and audited")
assert(focusEventFrame.registered.SPELL_ENERGIZE_BY_SELF
    and focusEventFrame.registered.SPELL_ENERGIZE_BY_OTHER
    and focusEventFrame.registered.SPELL_ENERGIZE_ON_SELF
    and XelAssist.Game.Pets.FocusEvidence.externalEnergizeAvailable,
    "focus energize exclusion events must be registered before learning")
assert(focusEventFrame.registered.PLAYER_CONTROL_LOST
    and focusEventFrame.registered.PLAYER_CONTROL_GAINED
    and focusEventFrame.registered.UNIT_AURA,
    "control-regime transitions must invalidate learned Hunter focus")
local routedEnergize
local originalObserveEnergize = XelAssist.Game.Pets.FocusEvidence.ObserveEnergize
function XelAssist.Game.Pets.FocusEvidence:ObserveEnergize(targetGuid, powerType, at)
    routedEnergize = { targetGuid, powerType, at }
    return true
end
fireFocusEvent("SPELL_ENERGIZE_BY_OTHER", "pet-focus-guid", "caster-guid", 123, 2)
XelAssist.Game.Pets.FocusEvidence.ObserveEnergize = originalObserveEnergize
assert(routedEnergize and routedEnergize[1] == "pet-focus-guid"
    and routedEnergize[2] == 2 and routedEnergize[3] == mockTime,
    "Nampower energize target and power type must route to focus attribution")
local modifierReset
local originalModifierChanged = XelAssist.Game.Pets.FocusEvidence.ModifierChanged
function XelAssist.Game.Pets.FocusEvidence:ModifierChanged(reason)
    modifierReset = reason
end
fireFocusEvent("CHARACTER_POINTS_CHANGED")
assert(modifierReset == "talent points changed")
fireFocusEvent("PLAYER_CONTROL_LOST")
XelAssist.Game.Pets.FocusEvidence.ModifierChanged = originalModifierChanged
assert(modifierReset == "player control regime changed",
    "control loss must conservatively invalidate Eyes-of-the-Beast focus")
XelAssist.Game.Pets.FocusEvidence.guid = "private-pet-guid"
XelAssist.Game.Pets.FocusEvidence.verifiedAmount = 20
XelAssist.Game.Pets.FocusEvidence.verifiedObservedInterval = 4
XelAssist.Game.Pets.FocusEvidence.verifiedInterval = 4.8
XelAssist.Game.Pets.FocusEvidence.verifiedSamples = 3
XelAssist.Game.Pets.FocusEvidence.phaseAt = mockTime
XelAssist.Game.Pets.FocusEvidence.externalEnergizeAvailable = true
XelAssist.Game.Pets.FocusEvidence.lastFocus = 50
XelAssist.Game.Pets.FocusEvidence.lastFocusMax = 100
XelAssist.Game.Pets.FocusEvidence.lastObservedAt = mockTime
chatMessages = {}
XelAssist:Command("diagnostics")
XelAssistTestDiagnosticText = table.concat(chatMessages, "|")
assert(string.find(XelAssistTestDiagnosticText, "Hunter focus: executable", 1, true)
    and string.find(XelAssistTestDiagnosticText, "conservative=4.80s", 1, true),
    "diagnostics must expose the executable Hunter focus evidence state")
assert(not string.find(XelAssistTestDiagnosticText, "private-pet-guid", 1, true),
    "Hunter focus diagnostics must never print pet identity")
XelAssist.Game.Pets.FocusEvidence:ResetSession()
XelAssist.Game.Pets.FocusEvidence:SetEnergizeEvidenceAvailable(true)
local tooltipResistance = { school = 2, schoolName = "Fire", multiplier = 0.8,
    decisionMultiplier = 1.2, damageTakenMultiplier = 1.5, uncertaintyMultiplier = 1,
    source = "test target data", confidence = "observed", samples = 3,
    raw = 100, penetration = 0, penetrationUnknown = true, unknown = false }
local tooltipAction = { name = "Frostbolt", rank = 1, actor = "player",
    facts = { kind = "damage" } }
local followAction = { name = "Fireball", rank = 1, actor = "pet",
    facts = { kind = "damage" } }
local estimatedFollowAction = { name = "Arcane Intellect", rank = 1, actor = "player",
    facts = { kind = "buff" } }
local displayPlan = { action = tooltipAction, target = "target", reason = "test resistance",
    confidence = "partial data", value = 1, threat = 1, downtime = 1.5,
    maxSliceMs = 2.5, observed = {},
    shieldBlockPrevention = { prevented = 36.5625,
        expectedBlocks = 1.828125, rounds = 3, blockSamples = 2 },
    survival = { available = true, timeToDie = 4.2, incomingDps = 120,
        observedFor = 3.5, confidence = "observed", decisionFactor = 0.64 },
    rootBlockers = { ["Backstab:1:player"] = { name = "Backstab", rank = 1,
        actor = "player", reasons = { ["must be behind target"] = 1 } } },
    resistance = tooltipResistance, follow = { followAction, estimatedFollowAction }, path = {
        { action = tooltipAction, target = "target", resistance = tooltipResistance },
        { action = followAction, target = "target", reason = "future exploit", downtime = 1.5,
            resistance = tooltipResistance,
            survival = { available = true, timeToDie = 3.1, incomingDps = 120,
                observedFor = 3.5, confidence = "observed", decisionFactor = 0.5 },
            spatialConditionFingerprint = "range:effect:pet:target:remain::30",
            spatialConditions = { { kind = "range",
                detail = "effect remains within 30 yd" } } },
        { action = estimatedFollowAction, target = "player", reason = "future setup",
            downtime = 3, estimated = true },
    } }
gameTooltipLines = {}; XelAssist.UI.HUD.lastPlan = displayPlan; XelAssist.UI.HUD.lastReason = "test"
this = XelAssist.UI.HUD.frame.main; this.OnEnter()
local tooltipText = table.concat(gameTooltipLines, "|")
assert(string.find(tooltipText, "Graph-scored factor 120%", 1, true)
    and string.find(tooltipText, "Fire: 80% expected output", 1, true)
    and string.find(tooltipText, "penetration unknown", 1, true)
    and string.find(tooltipText, "Target survival ~4.2s", 1, true)
    and string.find(tooltipText, "action output 64%", 1, true)
    and string.find(tooltipText, "Backstab — must be behind target", 1, true)
    and not string.find(tooltipText, "penetration 0", 1, true),
    "main tooltip must explain output, scored factor, unknowns and gated alternatives")
tooltipResistance.mode = "mixed"
tooltipResistance.components = {
    { school = 0, schoolName = "Physical", componentWeight = 0.6,
        multiplier = 0.5, decisionWeight = 0.3, unknown = false },
    { school = 3, schoolName = "Nature", componentWeight = 0.4,
        multiplier = 0.8, decisionWeight = 0.28, unknown = true,
        penetrationUnknown = true },
}
gameTooltipLines = {}; this = XelAssist.UI.HUD.frame.main; this.OnEnter()
tooltipText = table.concat(gameTooltipLines, "|")
assert(string.find(tooltipText, "Physical 50% · 60% share", 1, true)
    and string.find(tooltipText, "Nature 80% · 40% share", 1, true)
    and string.find(tooltipText, "uncertain", 1, true),
    "mixed resistance UI must expose each component's normalized share and uncertainty")
local savedEvaluatorForTooltip = XelAssist.Graph.Evaluate
XelAssistTestSavedAsyncGraph = {
    beginEvaluation = XelAssist.Graph.BeginEvaluation,
    resumeEvaluation = XelAssist.Graph.ResumeEvaluation,
    cancelEvaluation = XelAssist.Graph.CancelEvaluation,
}
XelAssist.Graph.Evaluate = function() return displayPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
local actionFrame = XelAssist.UI.HUD.frame
do
    local driver = XelAssist.UI.HUD.driver
    assert(driver and rawget(driver, "parent") == UIParent
        and rawget(actionFrame, "OnUpdate") == nil,
        "the always-live controller, not the hideable visual HUD, must own evaluation")
    local rootCalls = actionFrame.methodCalls
    local geometryBefore = { getPoint = rootCalls.GetPoint or 0,
        setHeight = rootCalls.SetHeight or 0,
        clearPoints = rootCalls.ClearAllPoints or 0,
        setPoint = rootCalls.SetPoint or 0 }
    local rowScriptsBefore = {}
    for i = 1, table.getn(actionFrame.follow) do
        rowScriptsBefore[i] = actionFrame.follow[i].methodCalls.SetScript or 0
    end
    local async = { synchronous = 0, begun = 0, resumed = 0,
        cancelled = 0, sessions = {} }
    async.PlanFor = function(mode, observedAt)
        local plan, key, value = {}, nil, nil
        if mode == "buff" then
            plan = { action = estimatedFollowAction, target = "player",
                targetRelation = "self", reason = "prepares a lasting buff",
                confidence = "client data", value = 1, threat = 0,
                downtime = 1.5, observed = {}, follow = {},
                path = { { action = estimatedFollowAction,
                    target = "player", targetRelation = "self" } } }
        else
            for key, value in pairs(displayPlan) do plan[key] = value end
        end
        plan.observedAt = observedAt
        return plan
    end
    XelAssist.Graph.Evaluate = function()
        async.synchronous = async.synchronous + 1
        error("the live driver must not call synchronous Graph.Evaluate")
    end
    XelAssist.Graph.BeginEvaluation = function(_, mode, preview, observedAt)
        async.begun = async.begun + 1
        local session = { id = async.begun, mode = mode, preview = preview,
            observedAt = observedAt, resumes = 0,
            plan = async.PlanFor(mode, observedAt) }
        table.insert(async.sessions, session)
        return session
    end
    XelAssist.Graph.ResumeEvaluation = function(_, session)
        assert(session and not session.cancelled,
            "a cancelled graph job must never be resumed")
        async.resumed, session.resumes = async.resumed + 1, session.resumes + 1
        if session.forceStale then
            session.stale = true
            return true, nil, "combat topology changed during evaluation"
        end
        if session.resumes < 2 then return false, nil, nil end
        return true, session.plan, nil
    end
    XelAssist.Graph.CancelEvaluation = function(_, session, reason)
        async.cancelled = async.cancelled + 1
        session.cancelled, session.cancelReason = true, reason
        return true
    end
    async.savedRender, async.renderCalls = XelAssist.UI.HUD.Render, 0
    XelAssist.UI.HUD.Render = function(owner, plan, err, changed)
        async.renderCalls = async.renderCalls + 1
        return async.savedRender(owner, plan, err, changed)
    end
    local stableAlpha = actionFrame:GetAlpha()
    local stableStatus = actionFrame.status:GetText()
    local stableRootRevision = actionFrame.xelCurrentRenderRevision
    local stableRowRevisions = {}
    for i = 1, table.getn(actionFrame.follow) do
        stableRowRevisions[i] = actionFrame.follow[i].xelRenderRevision
    end
    XelAssist.UI.HUD:SetUpdating("input publication consumed")
    assert(actionFrame:GetAlpha() == stableAlpha
        and actionFrame.status:GetText() == stableStatus
        and actionFrame.xelCurrentRenderRevision == stableRootRevision,
        "an in-flight replacement must not flash or repaint the committed HUD")
    for i = 1, table.getn(actionFrame.follow) do
        assert(actionFrame.follow[i].xelRenderRevision == stableRowRevisions[i],
            "an in-flight replacement must not repaint committed runway rows")
    end
    async.snapshot = XelAssist.Core.RecommendationSnapshot
    async.generationBeforeTarget = async.snapshot.generation or 0
    async.revisionBeforeTarget = actionFrame.xelCurrentRenderRevision
    event = "PLAYER_TARGET_CHANGED"; driver.OnEvent()
    assert(async.begun == 0 and async.resumed == 0 and async.synchronous == 0,
        "a target event must only invalidate and schedule graph work")
    arg1 = 0; driver.OnUpdate()
    async.abandoned = XelAssist.UI.HUD.activeEvaluation
    assert(async.begun == 1 and async.resumed == 0 and async.abandoned
        and async.abandoned.session == async.sessions[1]
        and async.synchronous == 0,
        "the next frame must begin, but not synchronously execute, target work")
    arg1 = 0.01; driver.OnUpdate()
    assert(async.resumed == 1 and async.sessions[1].resumes == 1
        and async.snapshot.generation == async.generationBeforeTarget
        and async.renderCalls == 0
        and actionFrame.xelCurrentRenderRevision == async.revisionBeforeTarget,
        "a pending slice must neither publish nor render a partial recommendation")

    event = "PLAYER_TARGET_CHANGED"; driver.OnEvent()
    assert(async.cancelled == 1 and async.sessions[1].cancelled
        and XelAssist.UI.HUD.activeEvaluation == nil,
        "new target evidence must cancel the prior pending graph job")
    async.staleGeneration = async.snapshot.generation
    assert(not XelAssist.UI.RecommendationController:Commit(
            XelAssist.UI.HUD, async.abandoned, async.sessions[1].plan, nil)
        and async.snapshot.generation == async.staleGeneration
        and async.renderCalls == 0,
        "an invalidated graph ticket must never publish after late completion")
    arg1 = 0; driver.OnUpdate()
    async.replacement = XelAssist.UI.HUD.activeEvaluation
    assert(async.begun == 2 and async.resumed == 1 and async.replacement
        and async.replacement.session == async.sessions[2],
        "the replacement target job must begin on the next frame")

    async.ensured = XelAssist.UI.HUD:EnsureEvaluation(XelAssist.mode)
    XelAssist:Execute()
    XelAssist:Execute()
    assert(not async.ensured and async.begun == 2 and async.cancelled == 1
        and XelAssist.UI.HUD.activeEvaluation == async.replacement,
        "repeated same-mode input must reuse one pending graph job")
    arg1 = 0.01; driver.OnUpdate()
    assert(async.sessions[2].resumes == 1
        and async.snapshot.generation == async.staleGeneration
        and async.renderCalls == 0,
        "the replacement's first pending slice must remain unpublished")
    XelAssist:Execute()
    XelAssist.UI.HUD:EnsureEvaluation(XelAssist.mode)
    assert(async.begun == 2 and async.cancelled == 1
        and XelAssist.UI.HUD.activeEvaluation == async.replacement,
        "Ensure and Execute must not restart a same-mode job between slices")
    arg1 = 0.01; driver.OnUpdate()
    assert(async.sessions[2].resumes == 2
        and XelAssist.UI.HUD.activeEvaluation == nil
        and async.snapshot.generation == async.staleGeneration + 1
        and async.snapshot.mode == XelAssist.mode and async.snapshot.plan
        and async.snapshot.plan.action == tooltipAction
        and async.renderCalls == 1
        and (rootCalls.GetPoint or 0) == geometryBefore.getPoint
        and (rootCalls.SetHeight or 0) == geometryBefore.setHeight
        and (rootCalls.ClearAllPoints or 0) == geometryBefore.clearPoints
        and (rootCalls.SetPoint or 0) == geometryBefore.setPoint,
        "only a completed replacement may publish without reanchoring the HUD")
    for i = 1, table.getn(actionFrame.follow) do
        assert((actionFrame.follow[i].methodCalls.SetScript or 0) == rowScriptsBefore[i],
            "prediction handlers must be installed once during HUD construction")
    end

    async.smartGeneration = async.snapshot.generation
    XelAssist:Execute("buff")
    assert(async.begun == 2 and XelAssist.UI.HUD.requestedMode == "buff"
        and async.snapshot.generation == async.smartGeneration
        and async.snapshot.mode == nil and async.snapshot.plan == nil,
        "forced buff input must retire the incompatible mode without synchronous graph work")
    arg1 = 0; driver.OnUpdate()
    async.buffEvaluation = XelAssist.UI.HUD.activeEvaluation
    assert(async.begun == 3 and async.sessions[3].mode == "buff"
        and async.sessions[3].resumes == 0
        and async.snapshot.generation == async.smartGeneration,
        "the buff job must begin without publishing before any resume")
    XelAssist:Execute("buff")
    assert(XelAssist.UI.HUD.activeEvaluation == async.buffEvaluation
        and async.begun == 3 and async.cancelled == 1,
        "repeated forced-mode input must retain its existing pending job")
    arg1 = 0.01; driver.OnUpdate()
    assert(async.sessions[3].resumes == 1
        and async.snapshot.mode == nil and async.snapshot.plan == nil
        and async.snapshot.generation == async.smartGeneration
        and async.renderCalls == 1,
        "a pending buff slice must not publish a replacement plan")
    arg1 = 0.01; driver.OnUpdate()
    assert(async.sessions[3].resumes == 2 and async.snapshot.mode == "buff"
        and async.snapshot.generation == async.smartGeneration + 1
        and async.snapshot.plan.action == estimatedFollowAction
        and async.renderCalls == 2,
        "forced buff mode may publish only after its graph job completes")
    async.generationBeforeStale = async.snapshot.generation
    XelAssist.UI.HUD:RequestRefresh(false, "buff")
    arg1 = 0; driver.OnUpdate()
    async.staleEvaluation = XelAssist.UI.HUD.activeEvaluation
    async.staleEvaluation.session.forceStale = true
    arg1 = 0.01; driver.OnUpdate()
    assert(XelAssist.UI.HUD.activeEvaluation == nil
        and XelAssist.UI.HUD.refreshRequested
        and async.snapshot.generation == async.generationBeforeStale
        and async.snapshot.plan.action == estimatedFollowAction
        and async.renderCalls == 2,
        "hard-stale graph work must schedule replacement without publishing or erasing the last complete plan")
    arg1 = 0; driver.OnUpdate()
    assert(async.begun == 5 and XelAssist.UI.HUD.activeEvaluation
        and XelAssist.UI.HUD.activeEvaluation.session == async.sessions[5],
        "hard-stale work must begin one replacement on the next frame")
    XelAssist.UI.RecommendationController:CancelActive(
        XelAssist.UI.HUD, "stale fixture complete")
    async.savedReach = XelAssist.Core.ExecutionReach.Validate
    XelAssist.Core.ExecutionReach.Validate = function() return false, "range" end
    async.rejectedPlan = async.PlanFor("buff", mockTime)
    async.rejectedPlan.liveSnapshot = true
    async.rejectedGeneration = async.snapshot.generation
    assert(not XelAssist.UI.RecommendationController:Commit(
            XelAssist.UI.HUD, { mode = "buff", ticket =
                async.snapshot:Ticket("buff", mockTime) },
            async.rejectedPlan, nil)
        and async.snapshot.generation == async.rejectedGeneration
        and async.snapshot.plan == nil and XelAssist.UI.HUD.refreshRequested,
        "a final live-evidence rejection must schedule replacement without publishing HOLD")
    XelAssist.Core.ExecutionReach.Validate = async.savedReach
    XelAssist.UI.HUD:ClearExecutionMode()
    XelAssist.UI.HUD.Render = async.savedRender
end
XelAssist.Graph.BeginEvaluation = XelAssistTestSavedAsyncGraph.beginEvaluation
XelAssist.Graph.ResumeEvaluation = XelAssistTestSavedAsyncGraph.resumeEvaluation
XelAssist.Graph.CancelEvaluation = XelAssistTestSavedAsyncGraph.cancelEvaluation
XelAssist.Graph.Evaluate = savedEvaluatorForTooltip

XelAssistTestSavedReachValidate =
    XelAssist.Core.ExecutionReach.Validate
XelAssistTestSavedPublicationValidate =
    XelAssist.Core.PublicationGuard.Validate
XelAssist.Core.PublicationGuard.Validate = function() return true end
XelAssist.Core.ExecutionReach.Validate = function()
    return false, "range"
end
XelAssist.Graph.Evaluate = function(_, mode, preview, observedAt)
    XelAssistTestObservedAt = observedAt
    return { liveSnapshot = true, observedAt = observedAt,
        action = { name = "Stale Shadow Bolt", actor = "player",
            executor = "playerSpell", facts = { kind = "damage" } },
        target = "target", reason = "stale range probe",
        observed = {}, follow = {}, path = {} }, nil, false
end
XelAssistTestFreshPlan, XelAssistTestFreshError =
    XelAssist.UI.RecommendationController:Evaluate(
        XelAssist.UI.HUD, true)
assert(XelAssistTestObservedAt == mockTime
    and XelAssistTestFreshPlan == nil
    and string.find(XelAssistTestFreshError,
        "State changed during evaluation: range", 1, true)
    and XelAssist.Core.RecommendationSnapshot.plan == nil,
    "a range-stale live graph plan must be rejected before publication")
XelAssist.Core.ExecutionReach.Validate =
    XelAssistTestSavedReachValidate
XelAssist.Core.PublicationGuard.Validate =
    XelAssistTestSavedPublicationValidate
XelAssist.Graph.Evaluate = function() return displayPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.route:GetText() == "You -> Target",
    "current action must visibly identify its actor and target")
local labelGuid, replacementLabelGuid = {}, {}
testFriendlyGUIDs.party1, testAssistUnits.party1 = labelGuid, true
local identityLabelPlan = { action = tooltipAction, target = labelGuid,
    targetRef = { unit = "party1", guid = labelGuid, relation = "ally",
        source = "party" },
    reason = "identity label", confidence = "client data", value = 1,
    threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }
XelAssist.Graph.Evaluate = function() return identityLabelPlan, nil, false end
local labelCalls = table.getn(unitNameCalls)
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.route:GetText() == "You -> Test Ally"
    and table.getn(unitNameCalls) == labelCalls + 1
    and unitNameCalls[table.getn(unitNameCalls)] == "party1",
    "HUD labels may resolve UnitName only through a matching captured target reference")
testFriendlyGUIDs.party1 = replacementLabelGuid
labelCalls = table.getn(unitNameCalls)
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.route:GetText() == "You -> Ally"
    and table.getn(unitNameCalls) == labelCalls,
    "a replaced target must use a role label without reading UnitName or rendering its opaque GUID")
testFriendlyGUIDs.party1, testAssistUnits.party1 = nil, nil
XelAssist.Graph.Evaluate = function() return displayPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
assert(string.find(actionFrame.status:GetText(), "NOW", 1, true)
    and string.find(actionFrame.status:GetText(), "OPEN", 1, true),
    "current partial-data action must expose immediate timing and open evidence")
assert(actionFrame:GetHeight() == 76,
    "future rows must render outside the fixed 76px current card without self-resizing")
assert(actionFrame.main:IsEnabled(), "a valid current recommendation must enable execution")
local mainPoint, mainRelative, mainRelativePoint, mainX, mainY = actionFrame.main:GetPoint()
assert(mainPoint == "TOPLEFT" and mainRelative == actionFrame
    and mainRelativePoint == "TOPLEFT" and mainX == 12 and mainY == -12,
    "the current action must stay anchored to the top card as the runway grows")
local actorLeft, actorRelative, actorRelativePoint, actorX, actorY = actionFrame.actorBar:GetPoint(1)
local actorRight, actorRightRelative, actorRightPoint, actorRightX, actorRightY =
    actionFrame.actorBar:GetPoint(2)
assert(actorLeft == "TOPLEFT" and actorRelative == actionFrame
    and actorRelativePoint == "TOPLEFT" and actorX == 7 and actorY == -72
    and actorRight == "TOPRIGHT" and actorRightRelative == actionFrame
    and actorRightPoint == "TOPRIGHT" and actorRightX == -7 and actorRightY == -72,
    "the companion marker must remain on the current-card boundary")
local movePoint, moveRelative, moveRelativePoint = actionFrame.move:GetPoint()
assert(movePoint == "TOPRIGHT" and moveRelative == actionFrame
    and moveRelativePoint == "TOPRIGHT",
    "the drag handle must remain inside the clamped current card")
local firstFollow, secondFollow = actionFrame.follow[1], actionFrame.follow[2]
assert(firstFollow:IsShown() and firstFollow:GetHeight() == 24
    and firstFollow.route:GetText() == "Companion -> Target"
    and firstFollow.name:GetText() == "Fireball"
    and string.find(firstFollow.time:GetText(), "+", 1, true)
    and string.find(firstFollow.time:GetText(), "s", 1, true)
    and firstFollow.certainty:GetText() == "IF"
    and firstFollow.action == followAction and firstFollow.candidate == displayPlan.path[2],
    "first future row must expose actor, target, action, timing, open evidence, and source candidate")
assert(secondFollow:IsShown() and secondFollow:GetHeight() == 24
    and secondFollow.route:GetText() == "You -> Self"
    and secondFollow.name:GetText() == "Arcane Intellect"
    and secondFollow.certainty:GetText() == "EST"
    and secondFollow.action == estimatedFollowAction
    and secondFollow.candidate == displayPlan.path[3],
    "estimated future row must remain visibly distinct without relying on color")
do
local currentRevision = actionFrame.xelCurrentRenderRevision
local firstRevision = firstFollow.xelRenderRevision
local secondRevision = secondFollow.xelRenderRevision
local revisedCondition = { action = followAction, target = "target",
    reason = "future exploit", downtime = 1.5, resistance = tooltipResistance,
    spatialConditionFingerprint = "range:effect:pet:target:remain::25",
    spatialConditions = { { kind = "range",
        detail = "effect remains within 25 yd" } } }
local conditionPlan = { action = tooltipAction, target = "target",
    reason = "test resistance", confidence = "partial data", value = 1,
    threat = 1, downtime = 1.5, observed = {}, resistance = tooltipResistance,
    rootBlockers = displayPlan.rootBlockers,
    follow = { followAction, estimatedFollowAction }, path = {
        displayPlan.path[1], revisedCondition, displayPlan.path[3] } }
XelAssist.Graph.Evaluate = function() return conditionPlan, nil, false end
XelAssist.UI.HUD:Refresh(false)
assert(actionFrame.xelCurrentRenderRevision == currentRevision
    and firstFollow.xelRenderRevision == firstRevision
    and firstFollow.candidate == revisedCondition,
    "new condition evidence with the same visible IF contract must update the tooltip without repainting the current card or row")

local replacementFollow = { name = "Fire Blast", rank = 1, actor = "player",
    facts = { kind = "damage" } }
local branchPlan = { action = tooltipAction, target = "target",
    reason = "test resistance", confidence = "partial data", value = 1,
    threat = 1, downtime = 1.5, observed = {}, resistance = tooltipResistance,
    rootBlockers = displayPlan.rootBlockers,
    follow = { followAction, replacementFollow }, path = {
        displayPlan.path[1], revisedCondition,
        { action = replacementFollow, target = "target", reason = "new branch",
            downtime = 1.5, estimated = true } } }
XelAssist.Graph.Evaluate = function() return branchPlan, nil, false end
XelAssist.UI.HUD:Refresh(false)
assert(actionFrame.xelCurrentRenderRevision == currentRevision
    and firstFollow.xelRenderRevision == firstRevision
    and secondFollow.xelRenderRevision == secondRevision + 1
    and secondFollow.name:GetText() == "Fire Blast",
    "a future-only branch change must repaint only the changed slot")
XelAssist.Graph.Evaluate = function() return displayPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
end
assert(firstFollow.iconFrame.texture[1] == 0.72
    and secondFollow.iconFrame.texture[1] == RAID_CLASS_COLORS.MAGE.r,
    "the single icon frame must preserve companion violet versus player class color")
assert(rawget(firstFollow, "OnClick") == nil and rawget(secondFollow, "OnClick") == nil,
    "future action rows must remain read-only")
gameTooltipLines = {}; this = XelAssist.UI.HUD.frame.follow[1]; this.OnEnter()
local futureTooltip = table.concat(gameTooltipLines, "|")
assert(string.find(futureTooltip, "Graph-scored factor 120%", 1, true)
    and string.find(futureTooltip, "0.0s wait", 1, true)
    and string.find(futureTooltip, "1.5s occupied", 1, true)
    and string.find(futureTooltip, "Target survival ~3.1s", 1, true)
    and string.find(futureTooltip, "action output 50%", 1, true)
    and string.find(futureTooltip, "If effect remains within 30 yd", 1, true),
    "predicted tooltip must expose conditions, resistance, wait and occupancy")
gameTooltipLines = {}; this = actionFrame.main; this.OnEnter()
tooltipText = string.lower(table.concat(gameTooltipLines, "|"))
assert(string.find(tooltipText, "one fresh publication", 1, true)
    and string.find(tooltipText, "at most one action", 1, true),
    "current action tooltip must explain one-shot publication consumption")
local savedExecute, executeCalls = XelAssist.Execute, 0
XelAssist.Execute = function() executeCalls = executeCalls + 1 end
this = actionFrame.main; this.OnClick()
XelAssist.Execute = savedExecute
assert(executeCalls == 1, "one main-button click must request exactly one execution")

XelAssistCharDB.visibleSteps = 1
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame:GetHeight() == 76 and not actionFrame.follow[1]:IsShown(),
    "one visible step must hide predictions without resizing the current card")
mainPoint, mainRelative, mainRelativePoint, mainX, mainY = actionFrame.main:GetPoint()
assert(mainPoint == "TOPLEFT" and mainRelative == actionFrame
    and mainRelativePoint == "TOPLEFT" and mainX == 12 and mainY == -12,
    "depth changes must not move the current action inside the frame")
XelAssistCharDB.visibleSteps = 3

local groundAction = { name = "Blizzard", rank = 1, actor = "player",
    facts = { kind = "damage", ground = true } }
local groundPlan = { action = groundAction, target = "target", reason = "area control",
    confidence = "client data", value = 1, threat = 1, downtime = 1.5,
    observed = {}, follow = {}, path = { { action = groundAction, target = "target" } } }
XelAssist.Graph.Evaluate = function() return groundPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.route:GetText() == "You -> Ground placement",
    "ground actions must not pretend to execute on the selected unit")
assert(actionFrame:GetHeight() == 76 and actionFrame.follow[1]:IsShown()
    and actionFrame.follow[1].placeholder
    and actionFrame.follow[1].route:GetText() == "NO CONTINUATION"
    and actionFrame.follow[1].name:GetText() == "No useful next step"
    and not actionFrame.follow[2]:IsShown(),
    "requested look-ahead must retain one truthful future placeholder rail")
gameTooltipLines = {}; this = actionFrame.follow[1]; this.OnEnter()
assert(string.find(table.concat(gameTooltipLines, "|"),
    "no positively scored continuation", 1, true),
    "future placeholder help must explain why no predicted action is shown")

resourcePlan = { action = tooltipAction, target = "target",
    reason = "test resource gate", confidence = "client data", value = 1,
    threat = 1, downtime = 1.5, observed = {}, follow = {},
    path = { { action = tooltipAction, target = "target" } },
    budgetLimited = true, terminal = { kind = "resource",
        resourceName = "Energy", current = 10, maximum = 100,
        required = 45, timingKnown = false, unreachable = false } }
XelAssist.Graph.Evaluate = function() return resourcePlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.follow[1].route:GetText() == "ENERGY GATE"
    and actionFrame.follow[1].name:GetText() == "10 / 45 energy"
    and actionFrame.follow[1].time:GetText() == "--"
    and actionFrame.follow[1].certainty:GetText() == "OPEN",
    "a path-local resource gate must take precedence over the global search budget")
gameTooltipLines = {}; this = actionFrame.follow[1]; this.OnEnter()
assert(string.find(table.concat(gameTooltipLines, "|"),
    "no timestamp or future action was invented", 1, true),
    "an unknown recovery clock must remain explicit and untimed")
resourcePlan = nil

local longFollowAction = { name = "An Extraordinarily Long Spell Name", rank = 1,
    actor = "player", facts = { kind = "heal" } }
local longTargetGuid = {}
testFriendlyGUIDs.party2, testAssistUnits.party2 = longTargetGuid, true
local longPlan = { action = tooltipAction, target = "target", reason = "test fit",
    confidence = "client data", value = 1, threat = 1, downtime = 1.5, observed = {},
    follow = { longFollowAction }, path = {
        { action = tooltipAction, target = "target" },
        { action = longFollowAction, target = "party2",
            targetRef = { unit = "party2", guid = longTargetGuid,
                relation = "ally", source = "party" },
            reason = "future fit", downtime = 1.5 },
    } }
XelAssist.Graph.Evaluate = function() return longPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
assert(actionFrame.follow[1].route:GetStringWidth() <= 112
    and actionFrame.follow[1].name:GetStringWidth() <= 112
    and string.find(actionFrame.follow[1].route:GetText(), "..", 1, true)
    and string.find(actionFrame.follow[1].name:GetText(), "..", 1, true)
    and actionFrame.follow[1].certainty:GetText() == "MODEL",
    "long future contracts must fit one row and unproven predictions must say MODEL")
testFriendlyGUIDs.party2, testAssistUnits.party2 = nil, nil

XelAssist.Graph.Evaluate = function() return displayPlan, nil, false end
XelAssist.UI.HUD:Refresh(true)
XelAssist.Graph.Evaluate = savedEvaluatorForTooltip
tooltipResistance.school, tooltipResistance.schoolName = nil, nil
XelAssistLog = {}
local smokeDecisions = XelAssistCharDB.runtime.session.decisions
XelAssist:RecordDecision(displayPlan, "smart")
assert(XelAssistLog[1].resistanceDecisionMultiplier == 1.2
    and XelAssistLog[1].resistanceConfidence == "observed"
    and XelAssistLog[1].resistanceSamples == 3
    and XelAssistLog[1].resistanceMode == "mixed"
    and XelAssistLog[1].survivalTimeToDie == 4.2
    and XelAssistLog[1].survivalIncomingDps == 120
    and XelAssistLog[1].survivalDecisionFactor == 0.64
    and XelAssistLog[1].shieldBlockPrevented == 36.5625
    and XelAssistLog[1].shieldBlockExpectedBlocks == 1.828125
    and XelAssistLog[1].shieldBlockIncomingRounds == 3
    and XelAssistLog[1].shieldBlockSamples == 2,
    "decision log must retain resistance, survival and bounded mitigation evidence")
assert(XelAssistCharDB.runtime.session.decisions == smokeDecisions + 1
    and XelAssistCharDB.runtime.session.maxSliceMs == displayPlan.maxSliceMs,
    "decision recording must persist automatic session smoke evidence")
chatMessages = {}
XelAssist:Command("log")
local readableLog = table.concat(chatMessages, "|")
assert(string.find(readableLog, "Mixed 120% scored", 1, true)
    and string.find(readableLog, "Physical 50%@60%", 1, true)
    and string.find(readableLog, "Nature 80%@40% uncertain", 1, true)
    and string.find(readableLog, "survival 4.2s @ 120/s", 1, true)
    and string.find(readableLog, "64% output", 1, true),
    "the readable decision log must print resistance components and survival pressure")

do
    local savedFallbackRefresh = XelAssist.UI.HUD.RequestRefresh
    local fallbackRefreshes = 0
    XelAssist.UI.HUD.RequestRefresh = function()
        fallbackRefreshes = fallbackRefreshes + 1
    end
    chatMessages = {}
    XelAssist:Fallback("Move into range — Test Strike")
    assert(table.getn(chatMessages) == 0 and fallbackRefreshes == 1
        and string.find(XelAssist.lastReason, "Move into range", 1, true),
        "routine execution holds must update the HUD without spamming chat")
    XelAssist.UI.HUD.RequestRefresh = savedFallbackRefresh
end

local function resetCastState()
    XelAssist.pendingAuras = {}
    XelAssist.pendingAuraKeys = {}
    XelAssist.currentPendingAuras = {}
    XelAssist.spellLifecycle = {}
    XelAssist.lifecycleKeys = {}
    XelAssist:ClearPetCast()
    XelAssist.Core.PlayerNormalQueue:Reset()
    XelAssist.Combat.Resistance.submissions = {}
    XelAssist.Combat.Resistance.recentSubmissions = {}
end

local immolateAction = { name = "Immolate", spellId = 348, actor = "player",
    facts = { kind = "dot", cast = 0 } }

resetCastState()
mockTime = 0
queueAction = { name = "Serpent Sting", spellId = 1978,
    facts = { kind = "dot" } }
queueRecord = XelAssist.Core.PlayerNormalQueue:Arm(queueAction,
    { gcd = 1.5 }, queueAction.name, "target-a", 0, 0)
fireEvent("SPELL_CAST_EVENT", 1, 1978, 0, "target-a")
XelAssist.Core.PlayerNormalQueue:Finalize(queueRecord, true)
assert(queueRecord.phase == "attempted"
    and XelAssist.Core.PlayerNormalQueue:Current() == queueRecord,
    "runtime client-attempt routing must retain normal ownership")
fireEvent("SPELL_START_SELF", 0, 1978, "player-guid", "target-a", 0, 0, 0, 0)
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "runtime player start evidence must release an attempted normal owner")

queueRecord = XelAssist.Core.PlayerNormalQueue:Arm(queueAction,
    { gcd = 1.5 }, queueAction.name, "target-a", 0, 0)
fireEvent("SPELL_QUEUE_EVENT", 2, 1978)
XelAssist.Core.PlayerNormalQueue:Finalize(queueRecord, true)
fireEvent("SPELL_START_SELF", 0, 1978, "player-guid", "target-a", 0, 0, 0, 0)
assert(XelAssist.Core.PlayerNormalQueue:Current() == queueRecord
    and queueRecord.phase == "queued",
    "runtime start evidence for an active same spell must not release a queued follow-up")
fireEvent("SPELL_CAST_EVENT", 1, 1978, 0, "target-a")
fireEvent("SPELL_QUEUE_EVENT", 3, 1978)
assert(queueRecord.phase == "popped",
    "runtime queue-pop routing must retain the in-flight owner")
fireEvent("SPELL_GO_SELF", 0, 1978, "player-guid", "target-a")
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "runtime player GO evidence must release the popped owner")

queueRecord = XelAssist.Core.PlayerNormalQueue:Arm(queueAction,
    { gcd = 1.5 }, queueAction.name, "target-a", 0, 0)
fireEvent("SPELL_CAST_EVENT", 1, 1978, 0, "target-a")
XelAssist.Core.PlayerNormalQueue:Finalize(queueRecord, true)
fireEvent("SPELL_FAILED_SELF", 1978, 77, 1)
fireEvent("SPELL_QUEUE_EVENT", 2, 1978)
assert(XelAssist.Core.PlayerNormalQueue:Current() == queueRecord
    and queueRecord.phase == "queued",
    "runtime retry queue evidence must supersede provisional server failure")
fireEvent("PLAYER_ENTERING_WORLD")
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "world entry must reset session-only queue ownership")

resetCastState()
mockTime = 0
local opaqueTargetGuid, opaqueCasterGuid = {}, {}
XelAssist:TouchPendingSpell(348, "queued", 2, opaqueCasterGuid, opaqueTargetGuid)
XelAssist:MarkAuraPending("Immolate", 2, opaqueTargetGuid, 348, opaqueCasterGuid,
    "debuff")
local opaquePendingKey = XelAssist:PendingAuraKey("Immolate", opaqueTargetGuid,
    opaqueCasterGuid)
local opaqueLifecycleKey = XelAssist:LifecycleKey(348, opaqueCasterGuid,
    opaqueTargetGuid)
assert(type(opaquePendingKey) == "table"
    and XelAssist.pendingAuras[opaquePendingKey].target == opaqueTargetGuid
    and XelAssist.pendingAuras[opaquePendingKey].casterGuid == opaqueCasterGuid
    and XelAssist:IsAuraPending(
        "Immolate", opaqueCasterGuid, opaqueTargetGuid)
    and type(opaqueLifecycleKey) == "table"
    and XelAssist.spellLifecycle[opaqueLifecycleKey].targetGuid == opaqueTargetGuid,
    "pending aura and lifecycle keys must preserve opaque target and caster identities")
local savedCancelSubmission = XelAssist.Combat.Resistance.CancelSubmission
XelAssist.Combat.Resistance.CancelSubmission = function() end
XelAssist:ClearAuraPending("Immolate", opaqueTargetGuid, opaqueCasterGuid)
XelAssist.Combat.Resistance.CancelSubmission = savedCancelSubmission
assert(not XelAssist.pendingAuras[opaquePendingKey]
    and not XelAssist.pendingAuraKeys[opaqueTargetGuid],
    "clearing an opaque reservation must release its bounded composite-key branch")
mockTime = 61
XelAssist:Lifecycle(999, {}, nil)
assert(not XelAssist.spellLifecycle[opaqueLifecycleKey]
    and not XelAssist.lifecycleKeys[opaqueCasterGuid],
    "stale lifecycle cleanup must release opaque composite-key branches")

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
XelAssist.Combat.Resistance:Submitted(immolateAction, "target-a", { duration = 15 })
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
    and not XelAssist.Combat.Resistance:Submission(
        "target-a", "player-guid", 348),
    "a terminal interruption must clear UI and resistance reservations together")

resetCastState()
mockTime = 2
testTargetGUID = "target-a"
XelAssist.Combat.Resistance:Submitted(
    immolateAction, testTargetGUID, { duration = 15 })
XelAssist:MarkAuraPending(
    "Immolate", 2, testTargetGUID, 348, "player-guid", "debuff")
XelAssistTestAmbiguousOwner = XelAssist.Core.PlayerNormalQueue:Arm(
    immolateAction, { gcd = 1.5 }, "Immolate(Rank 1)",
    testTargetGUID, 0, 0)
XelAssist.Core.PlayerNormalQueue:CastEvent(
    1, 348, 0, testTargetGUID, "exact-current")
XelAssist.Core.PlayerNormalQueue:Finalize(
    XelAssistTestAmbiguousOwner, true)
fireEvent("SPELLCAST_FAILED")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1, "0")
mockTime = mockTime + 0.3
assert(XelAssist:IsAuraPending("Immolate")
    and XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 348)
    and XelAssist.Core.PlayerNormalQueue:Current()
        == XelAssistTestAmbiguousOwner,
    "ambiguous failure evidence must not poison an exact owned reservation")
fireEvent("SPELL_CAST_EVENT",
    0, 348, 0, testTargetGUID, 0, "different-attempt")
mockTime = mockTime + 0.3
assert(XelAssist:IsAuraPending("Immolate")
    and XelAssist.Core.PlayerNormalQueue:Current()
        == XelAssistTestAmbiguousOwner,
    "a rejected same-spell CAST0 must not poison another exact attempt")
fireEvent("UNIT_CASTEVENT",
    "player-guid", testTargetGUID, "FAIL", 348, 0)
mockTime = mockTime + 0.3
assert(XelAssist:IsAuraPending("Immolate")
    and XelAssist.Core.PlayerNormalQueue:Current()
        == XelAssistTestAmbiguousOwner,
    "a rejected identityless UNIT FAIL must not poison an exact live attempt")
fireEvent("SPELL_CAST_RESULT_SELF",
    0, 348, testTargetGUID, 77, "exact-current")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1, "exact-current")
fireEvent("SPELL_GO_SELF",
    0, 348, "player-guid", testTargetGUID)
mockTime = mockTime + 0.3
assert(not XelAssist:IsAuraPending("Immolate")
    and not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 348),
    "an identityless GO must not resurrect an exact failed reservation")

resetCastState()
XelAssist.Combat.Resistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid")
fireEvent("AURA_CAST_ON_OTHER", 348, "other-caster", "target-a", 6, 3, 0, 0, 15000, 0)
assert(XelAssist:IsAuraPending("Immolate"),
    "another caster's identical aura must not steal our confirmation")
fireEvent("DEBUFF_ADDED_OTHER", "target-a", 1, 348, 1)
assert(XelAssist:IsAuraPending("Immolate"),
    "caster-less debuff events must not clear an owned reservation")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 2)
local cappedSubmission = XelAssist.Combat.Resistance:Submission("target-a", "player-guid", 348)
assert(XelAssist:IsAuraPending("Immolate")
    and cappedSubmission
    and cappedSubmission.applicationUncertain == "target debuff bar full",
    "a full debuff bar must mark the real application submission uncertain")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 0)
local landedSubmission = XelAssist.Combat.Resistance:RecentSubmission("target-a", "player-guid", 348)
XelAssistTestConfirmedApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate", "target-a", "player-guid")]
assert(XelAssist:IsAuraPending("Immolate")
    and XelAssistTestConfirmedApplication
    and XelAssistTestConfirmedApplication.state == "application-confirmed"
    and XelAssistTestConfirmedApplication.confirmedAt == mockTime
    and XelAssist.currentPendingAuras["player-guid"] == nil
    and landedSubmission and landedSubmission.applicationConfirmed,
    "an uncapped exact owned aura event must retain a detached visibility guard")
mockTime = mockTime + 0.74
assert(XelAssist:IsAuraPending("Immolate"),
    "the landed-aura guard must span the event-to-debuff visibility gap")
mockTime = mockTime + 0.02
assert(not XelAssist:IsAuraPending("Immolate"),
    "the landed-aura visibility guard must expire without inventing aura duration")

resetCastState()
mockTime = 20
XelAssist.Combat.Resistance:Submitted(
    immolateAction, "target-a", { duration = 15 })
XelAssist:TouchPendingSpell(
    348, "started", 3.5, "player-guid", "target-a")
XelAssist:MarkAuraPending(
    "Immolate", 3.5, "target-a", 348, "player-guid", "debuff")
XelAssist.Game.Player.ChannelRuntime:Start(
    348, "target-a", 3500, false)
XelAssistTestUndelayedApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate", "target-a", "player-guid")]
XelAssistTestUndelayedDeadline = XelAssistTestUndelayedApplication.untilAt
fireEvent("SPELL_DELAYED_SELF", "player-guid", 499)
fireEvent("SPELL_DELAYED_SELF", "player-guid", 658)
fireEvent("SPELL_DELAYED_SELF", "player-guid", 600)
fireEvent("SPELL_DELAYED_SELF", "player-guid", 400)
assert(math.abs(XelAssistTestUndelayedApplication.untilAt
        - XelAssistTestUndelayedDeadline - 2.157) < 0.001
    and math.abs(XelAssistTestUndelayedApplication.delaySeconds - 2.157) < 0.001
    and math.abs(XelAssist.playerCastUntil - mockTime - 5.657) < 0.001,
    "exact self pushback must extend active cast timing and its application guard")
XelAssistTestPushback = XelAssist.Game.Player.PushbackEvidence:Snapshot()
assert(XelAssistTestPushback and XelAssistTestPushback.samples == 4
    and math.abs(XelAssistTestPushback.meanDelay - 0.53925) < 0.00001
    and XelAssistTestPushback.minimumDelay == 0.4
    and XelAssistTestPushback.maximumDelay == 0.658,
    "accepted normal-cast delays must teach the bounded graph timing envelope")
mockTime = XelAssistTestUndelayedDeadline + 0.25
assert(XelAssist:IsAuraPending("Immolate"),
    "a pushed-back cast must not outlive its application reservation")
fireEvent("AURA_CAST_ON_OTHER",
    348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 0)
XelAssistTestDelayedApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Immolate", "target-a", "player-guid")]
assert(XelAssistTestDelayedApplication
    and XelAssistTestDelayedApplication.state == "application-confirmed"
    and math.abs(XelAssistTestDelayedApplication.untilAt
        - mockTime - 0.75) < 0.001,
    "a pushed-back cast must bridge from exact landing into visibility grace")
mockTime = mockTime + 0.76
assert(not XelAssist:IsAuraPending("Immolate"),
    "the pushed-back application visibility guard must remain bounded")

resetCastState()
mockTime = 25
XelAssist:TouchPendingSpell(
    172, "started", 3.5, "player-guid", "target-a")
XelAssist:MarkAuraPending(
    "Corruption", 3.5, "target-a", 172, "player-guid", "debuff")
XelAssistTestStartedDeadline = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey(
        "Corruption", "target-a", "player-guid")].untilAt
XelAssist:TouchPendingSpell(
    348, "queued", 3.5, "player-guid", "target-b")
XelAssist:MarkAuraPending(
    "Immolate", 3.5, "target-b", 348, "player-guid", "debuff")
XelAssistTestQueuedApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey(
        "Immolate", "target-b", "player-guid")]
XelAssistTestQueuedDeadline = XelAssistTestQueuedApplication.untilAt
fireEvent("SPELL_DELAYED_SELF", "player-guid", 1000)
assert(math.abs(XelAssist.pendingAuras[XelAssist:PendingAuraKey(
        "Corruption", "target-a", "player-guid")].untilAt
        - XelAssistTestStartedDeadline - 1) < 0.001
    and XelAssistTestQueuedApplication.untilAt == XelAssistTestQueuedDeadline,
    "pushback must find the unique started aura behind a newer queued aura")

resetCastState()
mockTime = 30
XelAssist:MarkAuraPending(
    "Immolate", 0.10, "off-target-guid", 348, "player-guid", "debuff")
mockTime = mockTime + 0.11
assert(not XelAssist:IsAuraPending(
        "Immolate", "player", "off-target-guid"),
    "the overrun regression must first sweep the provisional reservation")
mockTime = mockTime + 0.24
fireEvent("AURA_CAST_ON_OTHER",
    348, "player-guid", "off-target-guid", 6, 3, 0, 0, 15000, 1)
XelAssistTestRecoveredApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey(
        "Immolate", "off-target-guid", "player-guid")]
assert(XelAssistTestRecoveredApplication
    and XelAssistTestRecoveredApplication.target == "off-target-guid"
    and XelAssistTestRecoveredApplication.casterGuid == "player-guid"
    and XelAssistTestRecoveredApplication.spellId == 348
    and XelAssistTestRecoveredApplication.state == "application-confirmed"
    and math.abs(XelAssistTestRecoveredApplication.untilAt
        - mockTime - 0.75) < 0.001,
    "an irrelevant buff cap must not suppress an expired debuff's landing guard")
mockTime = mockTime + 0.74
assert(XelAssist:IsAuraPending(
        "Immolate", "player", "off-target-guid"),
    "the rebuilt landing guard must block through its full visibility gap")
mockTime = mockTime + 0.02
assert(not XelAssist:IsAuraPending(
        "Immolate", "player", "off-target-guid"),
    "the rebuilt off-target landing guard must expire normally")

resetCastState()
mockTime = 31
XelAssist:MarkAuraPending(
    "Immolate", 0.10, "capped-target-guid", 348, "player-guid", "debuff")
mockTime = mockTime + 0.11
assert(not XelAssist:IsAuraPending(
        "Immolate", "player", "capped-target-guid"),
    "the capped reconstruction regression must sweep its provisional guard")
fireEvent("AURA_CAST_ON_OTHER",
    348, "player-guid", "capped-target-guid", 6, 3, 0, 0, 15000, 2)
XelAssistTestRecoveredCappedApplication = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey(
        "Immolate", "capped-target-guid", "player-guid")]
assert(XelAssistTestRecoveredCappedApplication
    and XelAssistTestRecoveredCappedApplication.state == "debuff-cap-uncertain"
    and XelAssist.Combat.Resistance:RecentSubmission(
        "capped-target-guid", "player-guid", 348) == nil,
    "an actual debuff cap must rebuild uncertainty without claiming a landing")

resetCastState()
XelAssist.Combat.Resistance:Submitted(
    immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending(
    "Immolate", 3, "target-a", 348, "player-guid", "debuff")
fireEvent("SPELL_MISS_SELF", "player-guid", "target-a", 348, 2)
assert(not XelAssist:IsAuraPending("Immolate")
    and not XelAssist.Combat.Resistance:Submission(
        "target-a", "player-guid", 348),
    "an exact resisted application must immediately reopen a valid retry")

resetCastState()
XelAssist.Combat.Resistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 0.15, nil, 348, "player-guid")
mockTime = mockTime + 0.16
assert(not XelAssist:IsAuraPending("Immolate")
    and not XelAssist.Combat.Resistance:Submission(
        "target-a", "player-guid", 348),
    "natural tap-guard expiry must cancel the matching resistance submission")

resetCastState()
XelAssist:MarkAuraPending("Immolate", 2, nil, 348, "player-guid")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1)
mockTime = mockTime + 0.21
assert(not XelAssist:IsAuraPending("Immolate"),
    "an unretried exact failure must expire the reservation after its grace window")

resetCastState()
testPetGUID = "pet-guid"
XelAssist.Combat.Resistance.ownedCasters[testPetGUID] = {
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
XelAssist.Combat.Resistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid")
fireEvent("AURA_CAST_ON_OTHER", 348, testPetGUID, "target-a", 6, 3, 0, 0, 15000, 0)
assert(XelAssist:IsAuraPending("Immolate", "player", "target")
    and XelAssist.Combat.Resistance:Submission("target-a", "player-guid", 348),
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
XelAssistTestConfirmedSelfBuff = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")]
assert(XelAssistTestConfirmedSelfBuff
    and XelAssistTestConfirmedSelfBuff.state == "application-confirmed",
    "an exact self-buff event must retain the same visibility guard")
mockTime = mockTime + 0.76
assert(not XelAssist:IsAuraPending("Arcane Intellect", "player", "player"),
    "the self-buff visibility guard must expire normally")
XelAssist:MarkAuraPending("Arcane Intellect", 3, "player-guid", 1459, "player-guid")
fireEvent("AURA_CAST_ON_SELF", 1459, "player-guid", "player-guid", 6, 3, 0, 0, 1800000, 1)
local cappedBuff = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")]
assert(cappedBuff and cappedBuff.state == "buff-cap-uncertain",
    "a full friendly buff bar must keep an explicitly uncertain application guard")

resetCastState()
XelAssist.Combat.Resistance:Submitted(immolateAction, "target-a", { duration = 15 })
XelAssist:MarkAuraPending("Immolate", 3, "target-a", 348, "player-guid", "debuff")
fireEvent("AURA_CAST_ON_OTHER", 348, "player-guid", "target-a", 6, 3, 0, 0, 15000, 1)
local irrelevantBuffCap = XelAssist.Combat.Resistance:RecentSubmission(
    "target-a", "player-guid", 348)
assert(XelAssist:IsAuraPending("Immolate")
    and XelAssist.pendingAuras[XelAssist:PendingAuraKey(
        "Immolate", "target-a", "player-guid")].state == "application-confirmed"
    and irrelevantBuffCap and irrelevantBuffCap.applicationConfirmed,
    "an irrelevant full buff bar must still retain hostile application visibility grace")
mockTime = mockTime + 0.76
assert(not XelAssist:IsAuraPending("Immolate"),
    "the hostile application visibility grace must remain bounded")
XelAssist:MarkAuraPending("Arcane Intellect", 3, "player-guid", 1459,
    "player-guid", "buff")
fireEvent("AURA_CAST_ON_SELF", 1459, "player-guid", "player-guid", 6, 3, 0, 0,
    1800000, 2)
assert(XelAssist:IsAuraPending("Arcane Intellect", "player", "player")
    and XelAssist.pendingAuras[XelAssist:PendingAuraKey(
        "Arcane Intellect", "player-guid", "player-guid")].state
        == "application-confirmed",
    "an irrelevant full debuff bar must retain friendly application visibility grace")
mockTime = mockTime + 0.76
assert(not XelAssist:IsAuraPending("Arcane Intellect", "player", "player"),
    "the friendly application visibility grace must remain bounded")

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
XelAssist.Combat.Resistance:Submitted(seductionAction, "target-a", { duration = 3 })
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
    and not XelAssist.Combat.Resistance:Submission(
        "target-a", testPetGUID, 6358),
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
local evaluator = XelAssist.Graph.Evaluate
XelAssist.Graph.Evaluate = function() error("synthetic graph failure") end
XelAssist.UI.HUD:Refresh(true)
assert(string.find(XelAssist.UI.HUD.lastReason, "Graph data could not be evaluated"), "preview failure did not hold safely")
assert(XelAssistCharDB.runtime.lastError, "graph failure was not retained for diagnostics")
assert(not XelAssist.UI.HUD.frame.main:IsEnabled() and XelAssist.UI.HUD.frame:GetHeight() == 76,
    "evaluation failure must disable execution and collapse the runway")
for i = 1, table.getn(XelAssist.UI.HUD.frame.follow) do
    assert(not XelAssist.UI.HUD.frame.follow[i]:IsShown()
        and rawget(XelAssist.UI.HUD.frame.follow[i], "action") == nil
        and rawget(XelAssist.UI.HUD.frame.follow[i], "candidate") == nil,
        "evaluation failure must clear every stale future row")
end
XelAssist.Graph.Evaluate = evaluator
XelAssistTestSupportedNampowerVersion = GetNampowerVersion
GetNampowerVersion = function() return 4, 6, 2 end
XelAssist:CheckDependencies()
assert(not XelAssist.executionEnabled
    and table.concat(XelAssist.missing, ",") == "Nampower 4.7.0+",
    "pre-attempt-ID Nampower must not enable ambiguous queue execution")
GetNampowerVersion = XelAssistTestSupportedNampowerVersion
XelAssist:CheckDependencies()
assert(XelAssist.executionEnabled,
    "restoring Nampower 4.7 must restore execution")
XelAssist.executionEnabled = false; XelAssist.missing = { "Nampower" }
XelAssist.UI.HUD:Refresh(true)
assert(string.find(XelAssist.UI.HUD.lastReason, "Dependencies missing: Nampower"), "dependency state was not surfaced")
assert(not XelAssist.UI.HUD.frame.main:IsEnabled() and XelAssist.UI.HUD.frame:GetHeight() == 76,
    "dependency hold must remain visibly non-executable")
XelAssist.executionEnabled = true
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Frostbolt", spellId = 116,
            rank = 1, rankText = "Rank 1", facts = { kind = "damage" } },
        target = "target", targetGUID = testTargetGUID,
        targetRelation = "hostile",
        targetRef = { unit = "target", guid = testTargetGUID,
            relation = "hostile", source = "selected" },
        reason = "test", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
XelAssist.UI.HUD:Refresh(true)
assert(XelAssist.UI.HUD.frame.main:IsEnabled()
    and XelAssist.UI.HUD.frame:GetHeight() == 76
    and XelAssist.UI.HUD.frame.follow[1].placeholder
    and not XelAssist.UI.HUD.frame.follow[2]:IsShown(),
    "a later valid recommendation must restore execution with only its truthful horizon row")
local priorExecutionCanAttack = UnitCanAttack
UnitCanAttack = function(_, unit) return unit == "target" end
XelAssistTestQueueHook = function(_, guid)
    assert(guid == testTargetGUID,
        "the mocked normal queue must receive the captured hostile GUID")
    fireEvent("SPELL_QUEUE_EVENT", 2, 116)
end
XelAssistTestExecutePublished()
XelAssistTestQueueHook = nil
UnitCanAttack = priorExecutionCanAttack
assert(queuedSpell == "Frostbolt(Rank 1)" and not directlyCast,
    "selected-target actions must use the Nampower queue: reason="
        .. tostring(XelAssist.lastReason) .. " guid="
        .. tostring(testTargetGUID) .. " queued=" .. tostring(queuedSpell)
        .. " direct=" .. tostring(directlyCast))
fireEvent("SPELL_CAST_EVENT", 1, 116, 0, testTargetGUID, 0, "501")
fireEvent("SPELL_QUEUE_EVENT", 3, 116)
fireEvent("SPELL_GO_SELF", 0, 116, "player-guid", testTargetGUID)
assert(XelAssist.Core.PlayerNormalQueue:Current(),
    "identityless compatibility GO evidence must not release an ID-bound attempt")
fireEvent("SPELL_CAST_RESULT_SELF", 1, 116, testTargetGUID, 0, "501")
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "the mocked queued lifecycle must release on its exact result ID")

-- Nampower can discard a normal queue with code 3 before any cast attempt.
-- That terminal drop must also retire the graph reservation so the very next
-- physical input can submit the DoT again.
resetCastState()
XelAssistTestQueueCountBeforeDrop = queueCount
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Immolate", spellId = 348,
            rank = 1, rankText = "Rank 1", actor = "player",
            executor = "playerSpell", facts = { kind = "dot" } },
        target = "target", targetGUID = testTargetGUID,
        targetRelation = "hostile",
        targetRef = { unit = "target", guid = testTargetGUID,
            relation = "hostile", source = "selected" },
        reason = "drop retry test", confidence = "client data", value = 1,
        threat = 1, wait = 0, cast = 0, downtime = 0,
        observed = {}, follow = {}, path = {},
        tooltip = { gcd = 1.5, normalGcd = true, duration = 15 } }, nil, false
end
priorExecutionCanAttack = UnitCanAttack
UnitCanAttack = function(_, unit) return unit == "target" end
XelAssistTestQueueHook = function(_, guid)
    assert(guid == testTargetGUID)
    fireEvent("SPELL_QUEUE_EVENT", 2, 348)
end
XelAssistTestExecutePublished()
XelAssistTestDroppedPendingKey = XelAssist:PendingAuraKey(
    "Immolate", testTargetGUID, "player-guid")
assert(queueCount == XelAssistTestQueueCountBeforeDrop + 1
    and XelAssist.pendingAuras[XelAssistTestDroppedPendingKey],
    "the accepted queued DoT must establish its tap guard")
fireEvent("SPELL_QUEUE_EVENT", 3, 348)
XelAssistTestDroppedLifecycle = XelAssist:Lifecycle(
    348, "player-guid", nil, false)
assert(not XelAssist.Core.PlayerNormalQueue:Current()
    and not XelAssist.pendingAuras[XelAssistTestDroppedPendingKey]
    and XelAssistTestDroppedLifecycle
    and XelAssistTestDroppedLifecycle.state == "dropped",
    "an asynchronous normal queue drop must clear its exact graph reservation")
XelAssistTestExecutePublished()
assert(queueCount == XelAssistTestQueueCountBeforeDrop + 2,
    "the first input after an asynchronous drop must be allowed to resubmit")
XelAssistTestDroppedPendingKey = XelAssist:PendingAuraKey(
    "Immolate", testTargetGUID, "player-guid")
fireEvent("SPELLCAST_FAILED")
fireEvent("SPELL_FAILED_SELF", 348, 77, 1, "drop-retry")
fireEvent("SPELL_QUEUE_EVENT", 2, 348)
fireEvent("SPELL_CAST_EVENT", 0, 348, 0, testTargetGUID, 0, "drop-retry")
fireEvent("SPELL_QUEUE_EVENT", 3, 348)
mockTime = mockTime + 0.3
XelAssist:SweepPendingAuras()
XelAssistTestRetryOwner = XelAssist.Core.PlayerNormalQueue:Current()
XelAssistTestRetryPending = XelAssist.pendingAuras[
    XelAssistTestDroppedPendingKey]
XelAssistTestRetrySubmission = XelAssist.Combat.Resistance:Submission(
    testTargetGUID, "player-guid", 348)
assert(XelAssist.Core.PlayerNormalQueue:Current()
    and XelAssist.Core.PlayerNormalQueue:Current().phase == "queued"
    and XelAssist.pendingAuras[XelAssistTestDroppedPendingKey]
    and XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 348),
    "a later owned failure/retry must survive identityless failure, CAST0, old pop, and grace expiry: owner="
        .. tostring(XelAssistTestRetryOwner and XelAssistTestRetryOwner.phase)
        .. " pending=" .. tostring(XelAssistTestRetryPending ~= nil)
        .. " submission=" .. tostring(XelAssistTestRetrySubmission ~= nil))
fireEvent("SPELL_QUEUE_EVENT", 3, 348)
XelAssistTestQueueHook = nil
UnitCanAttack = priorExecutionCanAttack

-- Server result precedes legacy failure and a synchronous retry. The new
-- generation must survive both the old failure event and a stale old result.
mockTime = mockTime + 1
XelAssistTestRetryRecord = XelAssist.Core.PlayerNormalQueue:Arm(
    { name = "Frostbolt", spellId = 116, facts = { kind = "damage" } },
    { gcd = 1.5 }, "Frostbolt(Rank 1)", testTargetGUID, 0, 0)
fireEvent("SPELL_CAST_EVENT", 1, 116, 0, testTargetGUID, 0, "601")
fireEvent("SPELL_CAST_RESULT_SELF", 0, 116, testTargetGUID, 65, "601")
fireEvent("SPELL_FAILED_SELF", 116, 65, 1, "601")
fireEvent("SPELL_QUEUE_EVENT", 2, 116)
fireEvent("SPELL_CAST_EVENT", 1, 116, 0, testTargetGUID, 0, "602")
fireEvent("SPELL_CAST_RESULT_SELF", 1, 116, testTargetGUID, 0, "601")
assert(XelAssist.Core.PlayerNormalQueue:Current() == XelAssistTestRetryRecord,
    "a stale pre-retry result must not release the new attempt generation")
fireEvent("SPELL_CAST_RESULT_SELF", 1, 116, testTargetGUID, 0, "602")
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "the retry's exact server result must release its owned generation")
queuedSpell, directlyCast, directUnit = nil, nil, nil
testFriendlyGUIDs.party1, testAssistUnits.party1 = "ally-a", true
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Flash Heal", rank = 1, rankText = "Rank 1", facts = { kind = "heal" } },
        target = "party1", targetRelation = "ally",
        targetRef = { unit = "party1", guid = "ally-a", source = "party" },
        reason = "test", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
local validFriendlyCastCount, validFriendlyQueueCount = directCastCount, queueCount
XelAssistTestExecutePublished()
assert(directCastCount == validFriendlyCastCount + 1
    and queueCount == validFriendlyQueueCount
    and directlyCast == "Flash Heal(Rank 1)" and directUnit == "ally-a"
    and not queuedSpell,
    "with the normal slot free, an exact friendly reference must cast to its captured GUID")

resetCastState()
local waitingFriendlyCasts, waitingFriendlyQueue = directCastCount, queueCount
local waitingFriendlyLog = table.getn(XelAssistLog)
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Flash Heal", rank = 1, rankText = "Rank 1",
            facts = { kind = "heal" } },
        target = "party1", targetRelation = "ally", wait = 2,
        targetRef = { unit = "party1", guid = "ally-a", relation = "ally",
            source = "party" },
        reason = "test future ally", confidence = "client data", value = 1,
        threat = 1, downtime = 3.5, observed = {}, follow = {}, path = {} }, nil, false
end
XelAssistTestExecutePublished()
assert(directCastCount == waitingFriendlyCasts and queueCount == waitingFriendlyQueue
    and table.getn(XelAssistLog) == waitingFriendlyLog
    and not next(XelAssist.pendingAuras)
    and string.find(XelAssist.lastReason, "ally action not ready", 1, true),
    "an off-target friendly action outside the queue window must hold without side effects")

local waitingGroundCasts, waitingGroundQueue = directCastCount, queueCount
local waitingGroundLog = table.getn(XelAssistLog)
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Blizzard", rank = 1, rankText = "Rank 1",
            facts = { kind = "damage", ground = true } },
        target = "target", targetGUID = testTargetGUID,
        targetRelation = "hostile", wait = 2,
        targetRef = { unit = "target", guid = testTargetGUID,
            relation = "hostile", source = "selected" },
        reason = "test future ground", confidence = "client data", value = 1,
        threat = 1, downtime = 3.5, observed = {}, follow = {}, path = {} }, nil, false
end
local priorGroundCanAttack = UnitCanAttack
UnitCanAttack = function(_, unit) return unit == "target" end
XelAssistTestExecutePublished()
UnitCanAttack = priorGroundCanAttack
assert(directCastCount == waitingGroundCasts and queueCount == waitingGroundQueue
    and table.getn(XelAssistLog) == waitingGroundLog
    and string.find(XelAssist.lastReason, "action not ready", 1, true),
    "a future ground action must hold because it cannot use the forced spell queue")

local savedItemExecute, itemDispatches = XelAssist.Game.Inventory.Execute, 0
XelAssist.Game.Inventory.Execute = function() itemDispatches = itemDispatches + 1; return true end
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Healing Potion", executor = "item",
            facts = { kind = "heal", consumable = true } },
        target = "player", wait = 2, reason = "test future item",
        confidence = "client data", value = 1, threat = 0, downtime = 2,
        observed = {}, follow = {}, path = {} }, nil, false
end
local waitingItemLog = table.getn(XelAssistLog)
XelAssistTestExecutePublished()
XelAssist.Game.Inventory.Execute = savedItemExecute
assert(itemDispatches == 0 and table.getn(XelAssistLog) == waitingItemLog
    and string.find(XelAssist.lastReason, "item action not ready", 1, true),
    "a future item action must hold without use or decision-log side effects")

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
testFriendlyGUIDs.party1 = "ally-new"
local staleObservation = { name = "unchanged" }
XelAssist.Combat.Observations.last = staleObservation
local staleCastCount, staleQueueCount = directCastCount, queueCount
local staleLogCount = table.getn(XelAssistLog)
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Renew", spellId = 139, rank = 1,
            rankText = "Rank 1", facts = { kind = "hot" } },
        target = "party1", targetRelation = "ally",
        targetRef = { unit = "party1", guid = "ally-old", relation = "ally",
            source = "party" },
        reason = "test stale ally", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {},
        tooltip = { duration = 15 } }, nil, false
end
XelAssistTestExecutePublished()
assert(directCastCount == staleCastCount and queueCount == staleQueueCount
    and not next(XelAssist.pendingAuras)
    and table.getn(XelAssistLog) == staleLogCount
    and XelAssist.Combat.Observations.last == staleObservation
    and string.find(XelAssist.lastReason, "ally changed", 1, true),
    "a recycled friendly token must hold without cast, queue, log, observation or aura side effects")

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
testFriendlyGUIDs.party1 = "ally-race"
local savedRangeVerdict = XelAssist.Game.Range.SpellVerdict
XelAssist.Game.Range.SpellVerdict = function(_, _, castName, unit)
    assert(castName == "Flash Heal(Rank 1)",
        "runtime range checks must use the exact rank-qualified cast name")
    assert(unit == "party1", "friendly validation must retain the captured unit token for range")
    testFriendlyGUIDs.party1 = "ally-replacement"
    return true
end
local raceCastCount, raceQueueCount = directCastCount, queueCount
local raceLogCount = table.getn(XelAssistLog)
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Flash Heal", rank = 1, rankText = "Rank 1",
            facts = { kind = "heal" } },
        target = "party1", targetRelation = "ally",
        targetRef = { unit = "party1", guid = "ally-race", relation = "ally",
            source = "party" },
        reason = "test dispatch race", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
XelAssistTestExecutePublished()
XelAssist.Game.Range.SpellVerdict = savedRangeVerdict
assert(directCastCount == raceCastCount and queueCount == raceQueueCount
    and not next(XelAssist.pendingAuras)
    and table.getn(XelAssistLog) == raceLogCount
    and string.find(XelAssist.lastReason, "ally changed", 1, true),
    "a friendly identity change after range validation must be caught immediately before dispatch: "
        .. tostring(XelAssist.lastReason) .. " casts="
        .. tostring(directCastCount - raceCastCount) .. " queues="
        .. tostring(queueCount - raceQueueCount))

queuedSpell, directlyCast, directUnit = nil, nil, nil
testTargetGUID, testAssistUnits.target = "friendly-target-guid", true
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Flash Heal", rank = 1, rankText = "Rank 1",
            facts = { kind = "heal" } },
        target = "target",
        targetRef = { unit = "target", guid = "friendly-target-guid", relation = "ally",
            source = "selected" },
        reason = "test selected ally", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
local selectedAllyCastCount, selectedAllyQueueCount = directCastCount, queueCount
XelAssistTestExecutePublished()
assert(directCastCount == selectedAllyCastCount + 1
    and queueCount == selectedAllyQueueCount
    and directUnit == "friendly-target-guid" and not queuedSpell,
    "a friendly selected-target reference must never enter the hostile Nampower queue")
testTargetGUID, testAssistUnits.target = nil, nil

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
testPetGUID, testAssistUnits.pet = "pet-guid", true
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Mend Pet", rank = 1, rankText = "Rank 1",
            facts = { kind = "heal" } },
        target = "pet",
        targetRef = { unit = "pet", guid = "pet-guid", relation = "pet",
            source = "controlled" },
        reason = "test pet target", confidence = "client data", value = 1,
        threat = 1, downtime = 1.5, observed = {}, follow = {}, path = {} }, nil, false
end
local petTargetCastCount = directCastCount
XelAssistTestExecutePublished()
assert(directCastCount == petTargetCastCount + 1 and directUnit == "pet-guid"
    and not queuedSpell,
    "a player spell targeting the pet must validate and cast to the captured pet GUID")
testPetGUID, testAssistUnits.pet = nil, nil

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, "unchanged"
local originalUnitClass, originalAutoRepeat, originalUnitCanAttack =
    UnitClass, IsAutoRepeatAction, UnitCanAttack
local originalIsSpellInRange = IsSpellInRange
UnitClass = function() return "Hunter", "HUNTER" end
IsAutoRepeatAction = function() return false end
IsSpellInRange = function(_, unit) return unit == "target" and 1 or nil end
UnitCanAttack = function(_, unit) return unit == "target" end
testTargetGUID = "hunter-auto-target"
XelAssist.Combat.AutoShot:Reset(true)
local autoPlan = { action = { name = "Auto Shot", spellId = 75, rank = 1,
        rankText = "", actor = "player", facts = { kind = "autoRepeat",
            autoRepeat = true, cast = 0, gcd = 0 } },
    target = "target", targetGUID = "hunter-auto-target",
    targetRelation = "hostile",
    targetRef = { unit = "target", guid = "hunter-auto-target",
        relation = "hostile", source = "selected" },
    reason = "test sustained shot", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0.05,
    observed = {}, follow = {}, path = {}, tooltip = {} }
XelAssist.Graph.Evaluate = function() return autoPlan, nil, false end
local autoCasts, autoQueues, autoLog = directCastCount, queueCount, table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(directCastCount == autoCasts + 1 and queueCount == autoQueues
    and directlyCast == "Auto Shot" and directUnit == nil,
    "Auto Shot activation must dispatch directly once rather than enter the spell queue")
XelAssistTestExecutePublished()
assert(directCastCount == autoCasts + 1 and queueCount == autoQueues
    and table.getn(XelAssistLog) == autoLog + 1
    and string.find(XelAssist.lastReason, "state uncertain", 1, true),
    "a second tap before the client update must hold without toggling Auto Shot off")
XelAssist.Combat.AutoShot:Reset(true)

queuedSpell, directlyCast, directUnit = nil, nil, nil
XelAssistTestSavedCurrentCastingInfo, XelAssistTestSavedAttackTarget =
    GetCurrentCastingInfo, AttackTarget
XelAssistTestLivePlayerAttack, XelAssistTestPlayerAttackCalls = 0, 0
GetCurrentCastingInfo = function()
    return 0, 0, 0, 0, 0, 0, XelAssistTestLivePlayerAttack
end
AttackTarget = function()
    XelAssistTestPlayerAttackCalls = XelAssistTestPlayerAttackCalls + 1
end
XelAssist.Game.PlayerAttack:Reset()
XelAssistTestPlayerAttackPlan = { action = { name = "Attack", spellId = 6603,
        rank = 1, rankText = "", actor = "player", executor = "playerSpell",
        facts = { kind = "command", playerAttack = true, ambient = true,
            startOnly = true, melee = true, whiteAttack = true,
            cast = 0, gcd = 0, effectMinRange = 0, effectMaxRange = 5,
            effectRangeHitbox = true } },
    target = "target", targetGUID = "hunter-auto-target",
    targetRelation = "hostile",
    targetRef = { unit = "target", guid = "hunter-auto-target",
        relation = "hostile", source = "selected" },
    reason = "test player melee start", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0.05,
    observed = {}, follow = {}, path = {}, tooltip = {} }
XelAssist.Graph.Evaluate = function()
    return XelAssistTestPlayerAttackPlan, nil, false
end
XelAssistTestAttackCasts, XelAssistTestAttackQueues, XelAssistTestAttackLog =
    directCastCount, queueCount, table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(XelAssistTestPlayerAttackCalls == 1
    and directCastCount == XelAssistTestAttackCasts
    and queueCount == XelAssistTestAttackQueues
    and table.getn(XelAssistLog) == XelAssistTestAttackLog + 1,
    "Attack must use AttackTarget once without entering a spell cast or queue")
XelAssistTestExecutePublished()
assert(XelAssistTestPlayerAttackCalls == 1
    and directCastCount == XelAssistTestAttackCasts
    and queueCount == XelAssistTestAttackQueues
    and table.getn(XelAssistLog) == XelAssistTestAttackLog + 1
    and string.find(XelAssist.lastReason, "start pending", 1, true),
    "a repeated /xa input must hold while the player Attack state is pending")
XelAssistTestLivePlayerAttack = 1
XelAssistTestExecutePublished()
assert(XelAssistTestPlayerAttackCalls == 1
    and table.getn(XelAssistLog) == XelAssistTestAttackLog + 1
    and string.find(XelAssist.lastReason, "already active", 1, true),
    "a live active player Attack must never be toggled by another /xa input")
XelAssist.Game.PlayerAttack:Reset()
GetCurrentCastingInfo, AttackTarget = XelAssistTestSavedCurrentCastingInfo,
    XelAssistTestSavedAttackTarget
UnitClass, IsAutoRepeatAction, UnitCanAttack = originalUnitClass,
    originalAutoRepeat, originalUnitCanAttack
IsSpellInRange = originalIsSpellInRange
testTargetGUID = nil

-- A Hunter command has two independently captured recipients: the player
-- casts the button on the controlled pet while its triggered result affects
-- the exact hostile unit the pet is already attacking.  Exercise that
-- dispatch contract here, including every mutable identity/state recheck.
resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
local savedHunterUnitExists, savedHunterUnitIsUnit = UnitExists, UnitIsUnit
local savedHunterUnitCanAttack, savedHunterSpellUsable = UnitCanAttack, IsSpellUsable
local savedHunterUnitXP = UnitXP
local hunterPetTargetMatches = true
local hunterUsable = true
local hunterPetDistance, hunterCommandDistance = 3, 20
local hunterTargetGuid, hunterPetGuid = {}, {}
testTargetGUID, testPetGUID = hunterTargetGuid, hunterPetGuid
testAssistUnits.pet = true
UnitExists = function(unit)
    if unit == "pettarget" then
        return true, hunterPetTargetMatches and testTargetGUID or "other-target-guid"
    end
    return savedHunterUnitExists(unit)
end
UnitIsUnit = function(a, b)
    if a == "pettarget" and b == "target" then return hunterPetTargetMatches end
    return savedHunterUnitIsUnit(a, b)
end
UnitCanAttack = function(_, unit) return unit == "target" end
UnitXP = function(operation, from, to)
    if operation == "distanceBetween" and from == "pet" and to == "target" then
        return hunterPetDistance
    end
    if operation == "distanceBetween" and from == "player" and to == "target" then
        return hunterCommandDistance
    end
    if operation == "inSight" then return true end
    if operation == "behind" then return false end
    return nil
end
IsSpellUsable = function(name)
    assert(name == "Kill Command",
        "Hunter critical revalidation must query the exact cast name")
    return hunterUsable and 1 or 0, 0
end
local killCommandAction = { name = "Kill Command", spellId = 41827, rank = 1,
    rankText = "", actor = "player", executor = "playerSpell",
    facts = { kind = "damage", pet = true, fixedTarget = "pet",
        effectTarget = "target", effectActor = "pet", damageActor = "pet",
        requiresHunterCritical = true, resultSpellId = 41828, gcd = 0,
        requiresPetMelee = true, effectMinRange = 0, effectMaxRange = 5,
        commandMaxRange = 45 } }
local killCommandEffect = XelAssist.Combat.TriggeredActions:ResultAction(
    killCommandAction)
assert(killCommandEffect.spellId == 41828 and killCommandEffect.actor == "pet",
    "Kill Command must expose its exact pet-owned triggered result")
local killCommandPlan = { action = killCommandAction,
    effectAction = killCommandEffect, actor = "player",
    target = "target", targetGUID = hunterTargetGuid,
    targetRelation = "hostile",
    targetRef = { unit = "target", guid = hunterTargetGuid,
        relation = "hostile", source = "selected" },
    castTarget = "pet", castTargetGUID = hunterPetGuid,
    castTargetRelation = "pet",
    castTargetRef = { unit = "pet", guid = hunterPetGuid,
        relation = "pet", source = "controlled" },
    reason = "test Hunter dual target", confidence = "client data",
    value = 1, threat = 1, wait = 0, cast = 0, downtime = 0,
    observed = { actors = { pet = { unit = "pet", guid = hunterPetGuid } } },
    follow = {}, path = {}, tooltip = {}, effectTooltip = {} }
XelAssist.Graph.Evaluate = function() return killCommandPlan, nil, false end
local killCasts, killQueues = directCastCount, queueCount
local killLog = table.getn(XelAssistLog)
XelAssist.Combat.Observations.last = { name = "before Kill Command" }
XelAssistTestExecutePublished()
local killSubmission = XelAssist.Combat.Resistance:Submission(
    hunterTargetGuid, hunterPetGuid, 41828)
assert(directCastCount == killCasts + 1 and queueCount == killQueues
    and directlyCast == "Kill Command" and directUnit == hunterPetGuid
    and table.getn(XelAssistLog) == killLog + 1,
    "Kill Command must cast directly on its captured pet without entering the hostile queue")
assert(XelAssist.Combat.Observations.last
    and XelAssist.Combat.Observations.last.spellId == 41828
    and XelAssist.Combat.Observations.last.actor == "pet"
    and XelAssist.Combat.Observations.last.target == hunterTargetGuid
    and killSubmission,
    "Kill Command observation must correlate result 41828 from the pet to the captured hostile")

resetCastState()
hunterPetTargetMatches = false
local mismatchCasts, mismatchQueues = directCastCount, queueCount
local mismatchLog = table.getn(XelAssistLog)
local mismatchObservation = { name = "pettarget mismatch sentinel" }
XelAssist.Combat.Observations.last = mismatchObservation
XelAssistTestExecutePublished()
assert(directCastCount == mismatchCasts and queueCount == mismatchQueues
    and table.getn(XelAssistLog) == mismatchLog
    and XelAssist.Combat.Observations.last == mismatchObservation
    and not next(XelAssist.Combat.Resistance.submissions)
    and string.find(XelAssist.lastReason, "companion target changed", 1, true),
    "Kill Command must hold without side effects when pettarget no longer matches the hostile")

resetCastState()
hunterPetTargetMatches = true
hunterPetDistance = 8
local rangeCasts, rangeQueues = directCastCount, queueCount
local rangeLog = table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(directCastCount == rangeCasts and queueCount == rangeQueues
    and table.getn(XelAssistLog) == rangeLog
    and not next(XelAssist.Combat.Resistance.submissions)
    and string.find(XelAssist.lastReason, "out of melee range", 1, true),
    "Kill Command must hold while the captured pet cannot reach its target")
hunterPetDistance = 3

resetCastState()
hunterPetTargetMatches = true
hunterUsable = true
testTargetGUID = hunterTargetGuid
local savedHunterDistance = XelAssist.Game.Actors.Distance
local raceRangeChecks = 0
XelAssist.Game.Actors.Distance = function(_, actor, unit)
    assert(actor == "pet" and unit == "target",
        "dual-target reach validation must inspect pet-to-hostile geometry")
    raceRangeChecks = raceRangeChecks + 1
    testTargetGUID = {}
    return 3, "hitbox"
end
local hunterRaceCasts, hunterRaceQueues = directCastCount, queueCount
local hunterRaceLog = table.getn(XelAssistLog)
local hunterRaceObservation = { name = "hostile race sentinel" }
XelAssist.Combat.Observations.last = hunterRaceObservation
XelAssistTestExecutePublished()
XelAssist.Game.Actors.Distance = savedHunterDistance
assert(raceRangeChecks >= 1 and directCastCount == hunterRaceCasts
    and queueCount == hunterRaceQueues and table.getn(XelAssistLog) == hunterRaceLog
    and XelAssist.Combat.Observations.last == hunterRaceObservation
    and not next(XelAssist.Combat.Resistance.submissions)
    and (string.find(XelAssist.lastReason, "effect target changed", 1, true)
        or string.find(XelAssist.lastReason, "selected hostile changed", 1, true)),
    "Kill Command must catch a hostile identity race immediately before dispatch: "
        .. tostring(XelAssist.lastReason))

resetCastState()
testTargetGUID = hunterTargetGuid
hunterUsable = false
local expiredCasts, expiredQueues = directCastCount, queueCount
local expiredLog = table.getn(XelAssistLog)
local expiredObservation = { name = "critical expired sentinel" }
XelAssist.Combat.Observations.last = expiredObservation
XelAssistTestExecutePublished()
assert(directCastCount == expiredCasts and queueCount == expiredQueues
    and table.getn(XelAssistLog) == expiredLog
    and XelAssist.Combat.Observations.last == expiredObservation
    and not next(XelAssist.Combat.Resistance.submissions)
    and string.find(XelAssist.lastReason, "state", 1, true),
    "Kill Command must recheck and hold when its Hunter-critical state has expired")

UnitExists, UnitIsUnit = savedHunterUnitExists, savedHunterUnitIsUnit
UnitCanAttack, IsSpellUsable, UnitXP = savedHunterUnitCanAttack,
    savedHunterSpellUsable, savedHunterUnitXP
testTargetGUID, testPetGUID, testAssistUnits.pet = nil, nil, nil

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, "unchanged"
local revivePlan = { action = { name = "Revive Pet", spellId = 982, rank = 1,
        rankText = "", actor = "player", facts = { kind = "summon",
            petLifecycle = "revive", fixedTarget = "pet", cast = 10 } },
    target = "pet", targetRelation = "pet", reason = "test dead pet lifecycle",
    confidence = "client data", value = 1, threat = 0, wait = 0, cast = 10,
    downtime = 10, observed = {}, follow = {}, path = {}, tooltip = {} }
XelAssist.Graph.Evaluate = function() return revivePlan, nil, false end
local reviveCasts, reviveQueues = directCastCount, queueCount
XelAssistTestExecutePublished()
assert(directCastCount == reviveCasts + 1 and queueCount == reviveQueues
    and directlyCast == "Revive Pet" and directUnit == nil,
    "a verified pet lifecycle spell must use its implicit recipient without a dead-unit GUID")

resetCastState()
revivePlan.action.name, revivePlan.action.spellId = "Call Pet", 883
revivePlan.action.facts.petLifecycle = "call"
revivePlan.action.facts.fixedTarget, revivePlan.action.facts.cast = nil, 0
revivePlan.target, revivePlan.targetRelation = "player", "self"
revivePlan.targetRef = { unit = "player", guid = "player-guid",
    relation = "self", source = "self" }
revivePlan.wait, revivePlan.cast, revivePlan.downtime = 1.2, 0, 1.2
revivePlan.tooltip = { gcd = 1.5, normalGcd = true }
XelAssistTestFutureCallCasts, XelAssistTestFutureCallQueue =
    directCastCount, queueCount
XelAssistTestFutureCallLog = table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(directCastCount == XelAssistTestFutureCallCasts
    and queueCount == XelAssistTestFutureCallQueue
    and table.getn(XelAssistLog) == XelAssistTestFutureCallLog
    and string.find(XelAssist.lastReason, "action not ready", 1, true),
    "a future implicit-target pet lifecycle spell must hold instead of claiming the self queue")

resetCastState()
testTargetGUID = "pet-runtime-target"
local evaluatedPetGuid, replacementPetGuid = {}, {}
testPetGUID = evaluatedPetGuid
local savedPetActionUnitExists, savedPetActionUnitIsUnit = UnitExists, UnitIsUnit
local savedPetActionUnitCanAttack = UnitCanAttack
local petActionTargetMatches = true
UnitExists = function(unit)
    if unit == "pettarget" then return true, petActionTargetMatches
        and testTargetGUID or "other-pet-target" end
    return savedPetActionUnitExists(unit)
end
UnitIsUnit = function(a, b)
    if a == "pettarget" and b == "target" then return petActionTargetMatches end
    return savedPetActionUnitIsUnit(a, b)
end
UnitCanAttack = function(_, unit) return unit == "target" end
local petRuntimeAction = { name = "Spell Lock", spellId = 6358, rank = 1,
    rankText = "Rank 1", actor = "pet", executor = "petAbility", actionSlot = 5,
    actorRef = { unit = "pet", guid = evaluatedPetGuid, relation = "controlled",
        source = "pet" },
    facts = { kind = "interrupt", ranged = true } }
local petRuntimePlan = { action = petRuntimeAction, actor = "pet", target = "target",
    targetGUID = "pet-runtime-target", targetRelation = "hostile",
    targetRef = { unit = "target", guid = "pet-runtime-target", relation = "hostile",
        source = "selected" },
    reason = "test exact companion", confidence = "client data",
    value = 1, threat = 0, downtime = 0, follow = {}, path = {},
    tooltip = { minRange = 0, maxRange = 30 },
    observed = { actors = { pet = { unit = "pet", guid = evaluatedPetGuid,
        actorRef = petRuntimeAction.actorRef } } } }
XelAssist.Graph.Evaluate = function() return petRuntimePlan, nil, false end
local validPetDispatches = petActionCount
XelAssistTestExecutePublished()
assert(petActionCount == validPetDispatches + 1 and petActionSlot == 5,
    "an independently ready pet action must dispatch only for its captured actor identity")
local wrongPetTargetDispatches, wrongPetTargetLog = petActionCount,
    table.getn(XelAssistLog)
local wrongPetTargetObservation = XelAssist.Combat.Observations.last
petActionTargetMatches = false
XelAssistTestExecutePublished()
assert(petActionCount == wrongPetTargetDispatches
    and table.getn(XelAssistLog) == wrongPetTargetLog
    and XelAssist.Combat.Observations.last == wrongPetTargetObservation
    and not next(XelAssist.pendingAuras)
    and string.find(XelAssist.lastReason, "companion target changed", 1, true),
    "a hostile pet ability must hold when the pet is attacking another enemy")
petActionTargetMatches = true
local staleTargetDispatches, staleTargetLog = petActionCount, table.getn(XelAssistLog)
testTargetGUID = "replacement-runtime-target"
XelAssistTestExecutePublished()
assert(petActionCount == staleTargetDispatches
    and table.getn(XelAssistLog) == staleTargetLog
    and (string.find(XelAssist.lastReason, "target changed", 1, true)
        or string.find(XelAssist.lastReason, "selected hostile changed", 1, true)),
    "a selected-target pet action must hold when that token changes before dispatch: "
        .. tostring(XelAssist.lastReason))
testTargetGUID = "pet-runtime-target"
local stalePetDispatches, stalePetLog = petActionCount, table.getn(XelAssistLog)
local stalePetObservation = XelAssist.Combat.Observations.last
testPetGUID = replacementPetGuid
XelAssistTestExecutePublished()
assert(petActionCount == stalePetDispatches
    and table.getn(XelAssistLog) == stalePetLog
    and XelAssist.Combat.Observations.last == stalePetObservation
    and not next(XelAssist.pendingAuras)
    and string.find(XelAssist.lastReason, "companion changed", 1, true),
    "pet replacement must hold without dispatch, log, observation or pending-aura side effects")
UnitExists, UnitIsUnit, UnitCanAttack = savedPetActionUnitExists,
    savedPetActionUnitIsUnit, savedPetActionUnitCanAttack
testPetGUID, testTargetGUID = nil, nil

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Arcane Intellect", spellId = 1459, slot = 1, rank = 1,
            rankText = "Rank 1", actor = "player", facts = { kind = "buff" } },
        target = "player",
        targetRef = { unit = "player", guid = "player-guid", relation = "self",
            source = "self" },
        reason = "test aura guard", confidence = "client data",
        value = 1, threat = 0, wait = 1.2, downtime = 1.5,
        observed = {}, follow = {}, path = {},
        tooltip = { duration = 1800, gcd = 1.5, normalGcd = true } }, nil, false
end
XelAssistTestSelfCastCount, XelAssistTestSelfQueueCount = directCastCount, queueCount
XelAssistTestQueueHook = function(_, guid)
    assert(guid == "player-guid",
        "a queued self buff must remain bound to the captured player GUID")
    fireEvent("SPELL_QUEUE_EVENT", 2, 1459)
end
XelAssistTestExecutePublished()
XelAssistTestQueueHook = nil
XelAssistTestSelfPending = XelAssist.pendingAuras[
    XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")]
assert(directCastCount == XelAssistTestSelfCastCount
    and queueCount == XelAssistTestSelfQueueCount + 1
    and queuedSpell == "Arcane Intellect(Rank 1)" and not directlyCast
    and XelAssistTestSelfPending and XelAssistTestSelfPending.target == "player-guid"
    and XelAssist:IsAuraPending("Arcane Intellect", "player", "player"),
    "a future self buff and its aura guard must use the exact normal queue target")
fireEvent("SPELL_CAST_EVENT", 1, 1459, 0, "player-guid", 0, "self-701")
fireEvent("SPELL_CAST_RESULT_SELF", 1, 1459, "player-guid", 0, "self-701")
assert(not XelAssist.Core.PlayerNormalQueue:Current(),
    "the exact self-cast result must release normal queue ownership")
XelAssistTestPendingRepeatCasts, XelAssistTestPendingRepeatQueue =
    directCastCount, queueCount
XelAssistTestPendingRepeatLog = table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(directCastCount == XelAssistTestPendingRepeatCasts
    and queueCount == XelAssistTestPendingRepeatQueue
    and table.getn(XelAssistLog) == XelAssistTestPendingRepeatLog
    and XelAssist.pendingAuras[
        XelAssist:PendingAuraKey("Arcane Intellect", "player-guid", "player-guid")]
        == XelAssistTestSelfPending,
    "the dispatch boundary must reject a positive aura whose exact application is pending")

resetCastState()
liveBuffSpellIds.player = 1459
local liveRepeatCasts, liveRepeatLog = directCastCount, table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(directCastCount == liveRepeatCasts
    and table.getn(XelAssistLog) == liveRepeatLog
    and not next(XelAssist.pendingAuras),
    "the player dispatch boundary must recheck a live buff immediately before casting")
liveBuffSpellIds.player = nil

resetCastState()
queuedSpell, directlyCast, directUnit = nil, nil, nil
XelAssistTestSavedSelfQueueApi, XelAssistTestUnavailableSelfCasts =
    QueueSpellByName, directCastCount
XelAssistTestUnavailableSelfQueue = queueCount
XelAssistTestUnavailableSelfLog = table.getn(XelAssistLog)
QueueSpellByName = nil
XelAssistTestExecutePublished()
QueueSpellByName = XelAssistTestSavedSelfQueueApi
assert(directCastCount == XelAssistTestUnavailableSelfCasts
    and queueCount == XelAssistTestUnavailableSelfQueue
    and table.getn(XelAssistLog) == XelAssistTestUnavailableSelfLog
    and string.find(XelAssist.lastReason, "ally action not ready", 1, true),
    "a future self buff must hold safely when the exact normal queue API is unavailable")

resetCastState()
XelAssist.Graph.Evaluate = function()
    return { action = { name = "Arcane Intellect", spellId = 1459, rank = 1,
            rankText = "Rank 1", actor = "player", facts = { kind = "buff" } },
        target = "player",
        targetRef = { unit = "player", guid = "player-guid", relation = "self",
            source = "self" },
        reason = "test ambient self action", confidence = "client data",
        value = 1, threat = 0, wait = 0, downtime = 0,
        observed = {}, follow = {}, path = {},
        tooltip = { duration = 1800, gcd = 0, normalGcd = false } }, nil, false
end
XelAssistTestAmbientSelfCasts, XelAssistTestAmbientSelfQueue =
    directCastCount, queueCount
XelAssistTestExecutePublished()
assert(directCastCount == XelAssistTestAmbientSelfCasts + 1
    and queueCount == XelAssistTestAmbientSelfQueue
    and directlyCast == "Arcane Intellect(Rank 1)" and directUnit == "player-guid",
    "a non-GCD self action must retain the direct exact-target dispatch lane")

resetCastState()
local buffPetGuid = {}
testPetGUID, testAssistUnits.pet = buffPetGuid, true
liveBuffSpellIds.pet = 1459
local petBuffAction = { name = "Arcane Intellect", spellId = 1459, actor = "pet",
    executor = "petAbility", actionSlot = 4,
    actorRef = { unit = "pet", guid = buffPetGuid, relation = "controlled",
        source = "pet" },
    facts = { kind = "buff", self = true } }
local petBuffPlan = { action = petBuffAction, actor = "pet", target = "pet",
    targetGUID = buffPetGuid,
    targetRef = { unit = "pet", guid = buffPetGuid, relation = "pet",
        source = "controlled" },
    reason = "test live pet buff", confidence = "client data", value = 1,
    threat = 0, downtime = 0, follow = {}, path = {},
    observed = { actors = { pet = { unit = "pet", guid = buffPetGuid,
        actorRef = petBuffAction.actorRef } } } }
XelAssist.Graph.Evaluate = function() return petBuffPlan, nil, false end
local petBuffDispatches, petBuffLog = petActionCount, table.getn(XelAssistLog)
XelAssistTestExecutePublished()
assert(petActionCount == petBuffDispatches
    and table.getn(XelAssistLog) == petBuffLog
    and not next(XelAssist.pendingAuras),
    "the pet dispatch boundary must recheck a live buff before issuing CastPetAction")
liveBuffSpellIds.pet, testPetGUID, testAssistUnits.pet = nil, nil, nil

-- Hunter Raptor Strike uses its own exact on-swing owner. Dispatch must close
-- the lane before synchronous native callbacks, defer resistance submission,
-- and re-anchor the player main-hand round only when native consumes it.
resetCastState()
XelAssistTestSavedHunterCanAttack, XelAssistTestSavedHunterAttackSpeed,
    XelAssistTestSavedHunterDamage =
    UnitCanAttack, UnitAttackSpeed, UnitDamage
UnitCanAttack = function(_, unit) return unit == "target" end
UnitAttackSpeed = function(unit)
    assert(unit == "player")
    return 2
end
UnitDamage = function(unit)
    assert(unit == "player")
    return 40, 60, 0, 0, 0, 0, 1
end
testTargetGUID, mockTime, XelAssistTestOnSwingNative =
    "hunter-melee-target", 50, nil
XelAssist.Game.Player.OnSwingEvents:Reset("Hunter execution test")
XelAssistTestRaptorAction = { name = "Raptor Strike", spellId = 2973, rank = 1,
    rankText = "Rank 1", actor = "player", executor = "playerSpell",
    facts = { kind = "damage", melee = true, onNextSwing = true,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true } }
XelAssistTestRaptorPlan = { action = XelAssistTestRaptorAction, target = "target",
    targetGUID = testTargetGUID, targetRelation = "hostile",
    targetRef = { unit = "target", guid = testTargetGUID,
        relation = "hostile", source = "selected" },
    reason = "test exact Hunter on-swing", confidence = "client data",
    value = 1, threat = 80, rawPower = 80, power = 80,
    cost = 10, costKnown = true, cast = 0, wait = 0,
    occupancy = 0.05, downtime = 0.05, observed = {}, follow = {}, path = {},
    tooltip = { onNextSwing = true, school = 0, cost = 10,
        cooldown = 6, gcd = 1.5 } }
XelAssist.Graph.Evaluate = function()
    return XelAssistTestRaptorPlan, nil, false
end
XelAssistTestRaptorQueues = queueCount
XelAssistTestQueueHook = function(_, guid)
    assert(guid == testTargetGUID,
        "Raptor Strike must retain the graph-selected hostile identity")
    XelAssistTestOnSwingNative = { pending = 1, armed = 1, spellId = 2973,
        targetGuid = testTargetGUID, attemptId = "9001", buffered = 0,
        bufferedSpellId = 0, bufferedAttemptId = "0" }
    fireEvent("SPELL_ON_SWING_STATE", 0, 2973, testTargetGUID, "9001")
    fireEvent("SPELL_CAST_EVENT", 1, 2973, 2,
        testTargetGUID, 0, "9001")
end
assert(not XelAssist.Combat.Resistance:Submission(
    testTargetGUID, "player-guid", 2973))
XelAssistTestExecutePublished()
XelAssistTestQueueHook = nil
XelAssistTestArmedRaptor = XelAssist.Game.Player.OnSwing:Snapshot()
assert(queueCount == XelAssistTestRaptorQueues + 1
    and XelAssistTestArmedRaptor.occupied
    and XelAssistTestArmedRaptor.owner == "xelassist"
    and XelAssistTestArmedRaptor.attemptId == "9001"
    and not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 2973),
    "Raptor input must own one exact lane without early impact submission")
XelAssistTestExecutePublished()
assert(queueCount == XelAssistTestRaptorQueues + 1
    and string.find(XelAssist.lastReason, "already armed", 1, true),
    "a repeated Hunter input must not replace or buffer the armed strike")
fireEvent("SPELL_DAMAGE_EVENT_SELF", testTargetGUID,
    "player-guid", 2973, 80, 0, 0, 0, 0)
assert(not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 2973)
    and XelAssist.Combat.Resistance:RecentSubmission(
        testTargetGUID, "player-guid", 2973)
    and XelAssist.Game.Player.AttackRounds:Status().phaseKnown,
    "an exact damage packet before native code 5 must resolve impact without a stale submission")
XelAssistTestOnSwingNative = nil
fireEvent("SPELL_ON_SWING_STATE", 5, 2973, testTargetGUID, "9001")
assert(not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 2973),
    "captured arm target must not be treated as the resolved swing victim")
fireEvent("SPELL_GO_SELF", 0, 2973, "player-guid", testTargetGUID, 0, 1)
assert(not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 2973)
    and XelAssist.Combat.Resistance:RecentSubmission(
        testTargetGUID, "player-guid", 2973)
    and not XelAssist.Game.Player.OnSwing:Snapshot().occupied
    and XelAssist.Game.Player.AttackRounds:Status().phaseKnown,
    "later native evidence must not resurrect a consumed impact submission")

resetCastState()
XelAssist.Game.Player.OnSwingEvents:Reset("missing actual Hunter target")
XelAssist.Game.Player.AttackRounds:Reset("missing actual Hunter target")
XelAssistTestMissingTargetRecord = assert(XelAssist.Game.Player.OnSwing:Arm(
    XelAssistTestRaptorAction, XelAssistTestRaptorPlan.tooltip,
    testTargetGUID, 80, 10, true))
XelAssistTestOnSwingNative = { pending = 1, armed = 1, spellId = 2973,
    targetGuid = testTargetGUID, attemptId = "9002", buffered = 0,
    bufferedSpellId = 0, bufferedAttemptId = "0" }
fireEvent("SPELL_ON_SWING_STATE", 0, 2973, testTargetGUID, "9002")
fireEvent("SPELL_CAST_EVENT", 1, 2973, 2,
    testTargetGUID, 0, "9002")
assert(XelAssist.Game.Player.OnSwing:Finalize(
    XelAssistTestMissingTargetRecord, true))
XelAssistTestOnSwingNative = nil
fireEvent("SPELL_ON_SWING_STATE", 5, 2973, testTargetGUID, "9002")
fireEvent("SPELL_GO_SELF", 0, 2973, "player-guid", nil, 0, 1)
assert(not XelAssist.Combat.Resistance:Submission(
        testTargetGUID, "player-guid", 2973)
    and not XelAssist.Game.Player.AttackRounds:Status().phaseKnown,
    "a captured arm target must never substitute for a missing actual GO victim")
UnitCanAttack, UnitAttackSpeed, UnitDamage = XelAssistTestSavedHunterCanAttack,
    XelAssistTestSavedHunterAttackSpeed, XelAssistTestSavedHunterDamage
testTargetGUID, XelAssistTestOnSwingNative = nil, nil

-- Exercise active Shoot continuation through the actual TOC load order. This
-- catches module captures that a standalone test with pre-seeded dependencies
-- cannot observe.
XelAssistTestWandState = { hostile = true, targetGUID = "wand-target",
    targetHealth = 100, targetHealthExact = true,
    targetDistance = 20,
    resource = 20, resourceMax = 100,
    wand = { active = true, activeKnown = true,
        targetGuid = "wand-target", damage = 12, speed = 2,
        nextShotIn = 0.4, tooltip = { minRange = 0, maxRange = 30 } } }
XelAssistTestWandCandidate = XelAssist.Graph.WandCommitment:Candidate(
    XelAssistTestWandState)
assert(XelAssistTestWandCandidate and XelAssist.Graph.WandCommitment:Apply(
        XelAssistTestWandState, XelAssistTestWandCandidate)
        and XelAssistTestWandState.targetHealth == 88,
    "TOC-loaded wand continuation must reach hostile damage projection")

print("ok: full TOC-order load, initialization, UI, config and minimap")
