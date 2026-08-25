local XA = XelAssist
local PlayerNormalQueue = XelAssist.Core.PlayerNormalQueue
local PlayerQueueEvents = XelAssist.Core.PlayerQueueEvents
local PlayerOnSwingEvents = XelAssist.Game.Player.OnSwingEvents
local function msg(text, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. text, r or 0.35, g or 0.85, b or 1)
end
local function cvarEnabled(name)
    if not GetCVar then return false end
    local ok, value = pcall(GetCVar, name)
    return ok and tostring(value) == "1"
end
local function flagSet(value, flag)
    value = math.max(0, tonumber(value) or 0)
    return math.floor(value / flag) - math.floor(value / (flag * 2)) * 2 == 1
end
local function nampowerAtLeast(major, minor, patch)
    if type(GetNampowerVersion) ~= "function" then return false end
    local ok, haveMajor, haveMinor, havePatch = pcall(GetNampowerVersion)
    if not ok then return false end
    haveMajor, haveMinor, havePatch = tonumber(haveMajor) or 0,
        tonumber(haveMinor) or 0, tonumber(havePatch) or 0
    if haveMajor ~= major then return haveMajor > major end
    if haveMinor ~= minor then return haveMinor > minor end
    return havePatch >= patch
end
function XA:EnableEvidenceEvents()
    local names = { "NP_EnableAuraCastEvents", "NP_EnableSpellStartEvents",
        "NP_EnableSpellGoEvents" }
    local i
    if SetCVar then
        for i = 1, table.getn(names) do
            if not cvarEnabled(names[i]) then pcall(SetCVar, names[i], "1") end
        end
        local ok, value = true, nil
        if GetCVar then ok, value = pcall(GetCVar, "NP_QueueOnSwingSpells") end
        if not ok or tostring(value) ~= "0" then
            pcall(SetCVar, "NP_QueueOnSwingSpells", "0")
        end
    end
    local nampower = (GetNampowerVersion or QueueSpellByName) and true or false
    self.evidenceEvents = { damage = nampower, miss = nampower, autoAttack = nampower,
        aura = cvarEnabled(names[1]), start = cvarEnabled(names[2]),
        go = cvarEnabled(names[3]), castResult = nampowerAtLeast(4, 7, 0),
        onSwingExact = type(GetOnSwingInfo) == "function" }
    return self.evidenceEvents
end

function XA:Init()
    if type(XelAssistDB.ui) ~= "table" then XelAssistDB.ui = {} end
    if type(XelAssistCharDB.toggles) ~= "table" then
        XelAssistCharDB.toggles = { cooldowns = false, reagents = false }
    end
    if XelAssistCharDB.toggles.petControl == nil then XelAssistCharDB.toggles.petControl = false end
    if XelAssistCharDB.toggles.petActions == nil then XelAssistCharDB.toggles.petActions = true end
    if XelAssistCharDB.toggles.consumables == nil then XelAssistCharDB.toggles.consumables = false end
    if type(XelAssistLog) ~= "table" then XelAssistLog = {} end
    if XelAssistDB.ui.locked == nil then XelAssistDB.ui.locked = false end
    if XelAssistDB.ui.scale == nil then XelAssistDB.ui.scale = 1 end
    if XelAssistDB.ui.shown == nil then XelAssistDB.ui.shown = true end
    if XelAssistDB.ui.minimap == nil then XelAssistDB.ui.minimap = true end
    XelAssistCharDB.visibleSteps = XelAssistCharDB.visibleSteps or XelAssistCharDB.graphDepth or 3
    XelAssistCharDB.graphDepth = nil
    if XelAssistCharDB.role == nil then XelAssistCharDB.role = "auto" end
    if XelAssistCharDB.allowAoe == nil then XelAssistCharDB.allowAoe = false end
    if XelAssistCharDB.petThreat == nil then XelAssistCharDB.petThreat = "auto" end
    if XelAssistCharDB.mode then self.mode = XelAssistCharDB.mode end
    XelAssistCharDB.fallback = nil
    XelAssistCharDB.schema = 4
    self:CheckDependencies()
    self:EnableEvidenceEvents()
    local petExists, petGuid = UnitExists("pet")
    self.lastPetGuid = petExists and petGuid or nil
    XelAssist.UI.HUD:Build()
    XelAssist.UI.Minimap:Build()
end

function XA:CheckDependencies()
    local missing = {}
    if not SpellInfo or not SUPERWOW_VERSION then table.insert(missing, "SuperWoW") end
    if not IsAddOnLoaded or not IsAddOnLoaded("SuperAPI") then table.insert(missing, "SuperAPI") end
    if not QueueSpellByName then
        table.insert(missing, "Nampower")
    elseif not nampowerAtLeast(4, 7, 0) then
        table.insert(missing, "Nampower 4.7.0+")
    end
    self.missing = missing
    self.executionEnabled = table.getn(missing) == 0
    if not self.executionEnabled then msg("execution disabled; missing " .. table.concat(missing, ", ") .. ".", 1, 0.25, 0.2) end
end

function XA:SetMode(mode)
    self.mode = mode; XelAssistCharDB.mode = mode
    msg("mode set to " .. mode .. ".")
    XelAssist.UI.HUD:Refresh(true)
end

function XA:Command(text)
    local cmd, arg = string.gsub(text or "", "^%s*(%S*)%s*(.-)%s*$", "%1"), nil
    cmd = string.lower(cmd or "")
    local p = string.find(text or "", "%s")
    if p then arg = string.gsub(string.sub(text, p + 1), "^%s*(.-)%s*$", "%1") end
    if cmd == "" or cmd == "execute" then self:Execute(); return end
    if cmd == "why" then msg(self.lastReason or XelAssist.UI.HUD.lastReason or "no decision yet."); return end
    if cmd == "smart" or cmd == "single" or cmd == "aoe" or cmd == "support" then self:SetMode(cmd); return end
    if cmd == "cooldowns" or cmd == "reagents" or cmd == "consumables" then
        local current = XelAssistCharDB.toggles[cmd]
        XelAssistCharDB.toggles[cmd] = not current
        msg(cmd .. " " .. (not current and "enabled" or "disabled") .. ".")
        return
    end
    if cmd == "diagnostics" then
        XelAssist.Core.Diagnostics:Print(self); return
    end
    if cmd == "resistance" or cmd == "resistances" then
        local state = XelAssist.Graph:Snapshot(self.mode)
        if not state.hostile or not XelAssist.Combat.Resistance then
            msg("select a hostile target to inspect resistance evidence."); return
        end
        local rows = XelAssist.Combat.Resistance:CurrentSummary(state)
        local parts, i = {}, nil
        for i = 1, table.getn(rows) do
            local row = rows[i]
            if row.unknown then
                local delivery = row.landChance
                    and " [" .. math.floor(row.landChance * 100 + 0.5)
                        .. "% land, landed-hit ?]" or ""
                table.insert(parts, row.name .. " ?" .. delivery)
            else
                local output = math.floor((row.multiplier or 1) * 100 + 0.5)
                local land = math.floor((row.landChance or 1) * 100 + 0.5)
                local landed = math.floor((row.mitigationOnLand or 1) * 100 + 0.5)
                table.insert(parts, row.name .. " " .. output .. "% output ["
                    .. land .. "% land, " .. landed .. "% landed-hit]")
            end
        end
        msg("expected delivery: " .. table.concat(parts, " · "))
        return
    end
    if cmd == "log" then XelAssist.Core.DecisionLog:PrintRecent(); return end
    if cmd == "clearlog" then XelAssist.Core.DecisionLog:Clear(); return end
    if cmd == "buff" or cmd == "buffs" then self:Execute("buff"); return end
    if cmd == "config" or cmd == "ui" then XelAssist.UI.Settings:Toggle(); return end
    if cmd == "show" then XelAssist.UI.HUD.frame:Show(); XelAssistDB.ui.shown = true; return end
    if cmd == "hide" then XelAssist.UI.HUD.frame:Hide(); XelAssistDB.ui.shown = false; return end
    msg("commands: execute, why, smart, single, aoe, support, buffs, cooldowns, reagents, consumables, resistance, diagnostics, log, clearlog, config, show, hide")
end

SLASH_XELASSIST1 = "/xassist"
SLASH_XELASSIST2 = "/xa"
SlashCmdList["XELASSIST"] = function(text) XA:Command(text) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:RegisterEvent("PET_BAR_UPDATE")
ev:RegisterEvent("PET_UI_UPDATE")
ev:RegisterEvent("UNIT_PET")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
if SpellInfo then ev:RegisterEvent("UNIT_CASTEVENT") end
ev:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
ev:RegisterEvent("SPELLCAST_FAILED")
ev:RegisterEvent("SPELLCAST_INTERRUPTED")
ev:RegisterEvent("UI_ERROR_MESSAGE")
ev:RegisterEvent("SPELL_QUEUE_EVENT")
ev:RegisterEvent("SPELL_CAST_EVENT")
if nampowerAtLeast(4, 7, 0) then ev:RegisterEvent("SPELL_CAST_RESULT_SELF") end
if type(GetOnSwingInfo) == "function" then
    pcall(ev.RegisterEvent, ev, "SPELL_ON_SWING_STATE")
end
ev:RegisterEvent("SPELL_START_SELF")
ev:RegisterEvent("SPELL_START_OTHER")
ev:RegisterEvent("SPELL_GO_SELF")
ev:RegisterEvent("SPELL_GO_OTHER")
ev:RegisterEvent("SPELL_FAILED_SELF")
ev:RegisterEvent("SPELL_FAILED_OTHER")
ev:RegisterEvent("SPELL_MISS_SELF")
ev:RegisterEvent("SPELL_MISS_OTHER")
ev:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
ev:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
-- Nampower 4.5+ enables its detailed white-swing stream when either event is
-- registered; no addon-owned compatibility CVar mutation is required.
ev:RegisterEvent("AUTO_ATTACK_SELF")
ev:RegisterEvent("AUTO_ATTACK_OTHER")
ev:RegisterEvent("AURA_CAST_ON_SELF")
ev:RegisterEvent("AURA_CAST_ON_OTHER")
ev:RegisterEvent("DEBUFF_ADDED_OTHER")
ev:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "XelAssist" then
        PlayerNormalQueue:Reset()
        PlayerOnSwingEvents:Reset("addon loaded")
        XA:Init()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        PlayerNormalQueue:Reset()
        PlayerOnSwingEvents:Reset("world transition")
    end
    if event == "SPELL_ON_SWING_STATE" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3, arg4)
    end
    if event == "PLAYER_LOGIN" then
        local runtime = XA:RuntimeAudit()
        msg("v" .. XA.version .. " ready · " .. (runtime.actions or 0) .. " action nodes ("
            .. (runtime.inferred or 0) .. " inferred). Bind Smart Execute or click the action button.")
    end
    if event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        XelAssist.Game.Capabilities:Invalidate()
        if XelAssist.Game.Actors then XelAssist.Game.Actors:Invalidate() end
    end
    if event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "UNIT_PET" then
        if event == "UNIT_PET" then XA:HandlePetIdentityChange() end
        if XelAssist.Game.Actors then XelAssist.Game.Actors:Invalidate() end
    end
    if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" then
        if XelAssist.Game.Inventory then XelAssist.Game.Inventory:Invalidate() end
        if event == "UNIT_INVENTORY_CHANGED" and XelAssist.Game.Capabilities then
            XelAssist.Game.Capabilities:InvalidateEquipment()
        end
    end
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" and XelAssist.Combat.Observations then
        local outcome, outcomeTarget, outcomeSpell = XelAssist.Combat.Observations:CombatMessage(arg1)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget, XA:PlayerGUID())
        end
    end
    if event == "UI_ERROR_MESSAGE" and XelAssist.Combat.Observations then
        XelAssist.Combat.Observations:ErrorMessage(arg1)
    end
    if event == "SPELLCAST_FAILED" then
        -- Nampower 4.7 follows with attempt-identified evidence. While a
        -- normal queue owner exists, this vanilla event could belong to an
        -- older same-spell generation, so bounded uncertainty is safer.
        if not PlayerNormalQueue:Current() then
            XA:MarkPendingFailure(nil, XA:PlayerGUID())
        end
    end
    if event == "SPELLCAST_INTERRUPTED" then
        -- The vanilla event carries no spell identity. A known fallback cast
        -- name is authoritative enough to clear only its matching reservation;
        -- with no name, retain the legacy single-current reservation fallback.
        XA:ClearCurrentPendingAura(XA:PlayerGUID(), XA.playerCastName)
        XA.playerCastUntil, XA.playerCastName = nil, nil
    end
    if event == "SPELL_FAILED_SELF" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3, arg4)
        local _, playerGuid = UnitExists("player")
        local matched = PlayerNormalQueue:ServerFailure(arg1, nil, arg4)
        if PlayerQueueEvents:Allows(arg1, matched) then
            XA:MarkPendingFailure(arg1, playerGuid)
        end
    end
    if event == "SPELL_FAILED_OTHER" and XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance:IsOwnedCaster(arg1) then
        local current = XA.currentPendingAuras and XA.currentPendingAuras[arg1]
        if current and tonumber(current.spellId) == tonumber(arg2) then
            XA:ClearAuraPending(current.name, current.target, arg1)
        end
        XA:ClearPetCast(arg2, arg1)
    end
    if event == "SPELL_QUEUE_EVENT" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2)
        PlayerQueueEvents:Handle(XA, arg1, arg2)
    end
    if event == "SPELL_CAST_EVENT" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3, arg4, arg5, arg6)
        local matched, disposition = PlayerNormalQueue:CastEvent(
            arg1, arg2, arg3, arg4, arg6)
        if PlayerQueueEvents:Allows(arg2, matched) then
            local casterGuid, ambiguous = XA:PendingCasterForSpell(arg2, arg4)
            if casterGuid and not ambiguous then
                if tonumber(arg1) == 1 then
                    XA:TouchPendingSpell(arg2, "accepted", 2, casterGuid, arg4)
                elseif disposition == "retry-preserved" then
                    XA:TouchPendingSpell(arg2, "queued", 2, casterGuid, arg4)
                else XA:MarkPendingFailure(arg2, casterGuid, arg4) end
            end
        end
    end
    if event == "SPELL_CAST_RESULT_SELF" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3, arg4, arg5)
        PlayerNormalQueue:ServerResult(arg1, arg2, arg3, arg4, arg5)
    end
    if (event == "SPELL_START_SELF" or event == "SPELL_START_OTHER")
        and XelAssist.Combat.Resistance and XelAssist.Combat.Resistance:IsOwnedCaster(arg3) then
        local routeEvidence = true
        if arg3 == XA:PlayerGUID() then
            routeEvidence = PlayerQueueEvents:Allows(arg2,
                PlayerNormalQueue:ServerAccepted(arg2, arg4))
        end
        local castSeconds = math.max(0, tonumber(arg6) or 0) / 1000
        local channelSeconds = math.max(0, tonumber(arg7) or 0) / 1000
        local duration = castSeconds + channelSeconds
        if routeEvidence then
            XA:TouchPendingSpell(arg2, "started", duration + 2, arg3, arg4)
        end
        local _, petGuid = UnitExists("pet")
        if arg3 == petGuid then
            XA.petCastGuid, XA.petCastSpellId = arg3, arg2
            XA.petCastUntil = GetTime() + math.max(0.05, duration)
            XA.petCastChannel = tonumber(arg8) == 1 and true or false
        end
    end
    if event == "SPELL_GO_SELF" then
        PlayerOnSwingEvents:Handle(event,
            arg1, arg2, arg3, arg4, arg5, arg6)
    end
    if (event == "SPELL_GO_SELF" or event == "SPELL_GO_OTHER")
        and XelAssist.Combat.Resistance and XelAssist.Combat.Resistance:IsOwnedCaster(arg3) then
        local routeEvidence = true
        if arg3 == XA:PlayerGUID() then
            routeEvidence = PlayerQueueEvents:Allows(arg2,
                PlayerNormalQueue:ServerAccepted(arg2, arg4))
        end
        if routeEvidence then
            XA:TouchPendingSpell(arg2, "go", 2, arg3, arg4)
        end
        if XA.petCastGuid == arg3 and tonumber(XA.petCastSpellId) == tonumber(arg2)
            and not XA.petCastChannel then
            XA:ClearPetCast(arg2, arg3)
        end
    end
    if event == "SPELL_MISS_SELF" then
        PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3, arg4)
    end
    if (event == "SPELL_MISS_SELF" or event == "SPELL_MISS_OTHER")
        and XelAssist.Combat.Observations and XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance:IsOwnedCaster(arg1) then
        local outcome, outcomeTarget, outcomeSpell = XelAssist.Combat.Observations:SpellMiss(
            arg3, arg2, arg4, arg1)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget, arg1)
        end
    end
    if (event == "SPELL_DAMAGE_EVENT_SELF" or event == "SPELL_DAMAGE_EVENT_OTHER")
        and XelAssist.Combat.Observations then
        if event == "SPELL_DAMAGE_EVENT_SELF" then
            PlayerOnSwingEvents:Handle(event, arg1, arg2, arg3)
        end
        XelAssist.Combat.Observations:SpellDamage(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
    if (event == "AUTO_ATTACK_SELF" or event == "AUTO_ATTACK_OTHER")
        and XelAssist.Combat.Resistance then
        local result = XelAssist.Combat.Resistance:AutoAttack(
            arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
        XelAssist.Game.Pets.EffectRuntime:ObserveAutoAttack(arg1, arg2, result)
        if XelAssist.Game.AttackRounds then
            XelAssist.Game.AttackRounds:Observe(arg1, arg2, result, GetTime())
        end
        if XelAssist.Game.Player and XelAssist.Game.Player.AttackRounds then
            XelAssist.Game.Player.AttackRounds:Observe(
                arg1, arg2, result, GetTime())
        end
    end
    if event == "AURA_CAST_ON_SELF" or event == "AURA_CAST_ON_OTHER" then
        local spellName = SpellInfo and SpellInfo(arg1) or nil
        local owned = XelAssist.Combat.Resistance and XelAssist.Combat.Resistance:IsOwnedCaster(arg2)
        local pendingKey = XA:PendingAuraKey(spellName, arg3, arg2)
        local pending = pendingKey and XA.pendingAuras and XA.pendingAuras[pendingKey]
        local buffCapped, debuffCapped = flagSet(arg9, 1), flagSet(arg9, 2)
        local expectedBar = pending and pending.auraBar
        if not expectedBar and event == "AURA_CAST_ON_SELF" then expectedBar = "buff" end
        local auraCapped = expectedBar == "buff" and buffCapped
            or expectedBar == "debuff" and debuffCapped
            or not expectedBar and (buffCapped or debuffCapped)
        XelAssist.Game.Pets.EffectRuntime:ObserveAura(
            arg1, arg2, arg3, arg8, auraCapped)
        local capReason = expectedBar == "buff" and "target buff bar full"
            or expectedBar == "debuff" and "target debuff bar full"
            or buffCapped and "target buff bar full" or "target debuff bar full"
        if owned and not auraCapped then
            local landed, confirmed = XelAssist.Combat.Resistance:AuraLanded(arg3, arg1, arg2)
            -- Hostile applications have a resistance evidence submission;
            -- friendly/self auras do not, but the exact caster+target+spell
            -- pending record is itself sufficient to end their tap guard.
            if spellName and (confirmed or pending) then
                XA:ClearAuraPending(spellName, arg3, arg2)
            end
        elseif owned and auraCapped and pending then
            pending.state = expectedBar == "buff" and "buff-cap-uncertain"
                or expectedBar == "debuff" and "debuff-cap-uncertain"
                or buffCapped and "buff-cap-uncertain" or "debuff-cap-uncertain"
            pending.untilAt = math.max(pending.untilAt or 0, GetTime() + 0.75)
            if XelAssist.Combat.Resistance.MarkApplicationUncertain then
                XelAssist.Combat.Resistance:MarkApplicationUncertain(arg3, arg1, arg2,
                    capReason)
            end
        end
    end
    if event == "DEBUFF_ADDED_OTHER" then
        -- This event has no caster identity. It is useful to the aura snapshot,
        -- but cannot confirm or clear our player/pet submission safely.
    end
    if event == "UNIT_CASTEVENT" then
        local _, targetGUID = UnitExists("target")
        local _, playerGUID = UnitExists("player")
        if targetGUID and arg1 == targetGUID then
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.targetCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.targetCastGUID = targetGUID
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                XA.targetCastUntil = nil; XA.targetCastGUID = nil
            end
        end
        if playerGUID and arg1 == playerGUID then
            local castSpell = SpellInfo and SpellInfo(arg4) or nil
            local matched
            if arg3 == "START" or arg3 == "CHANNEL" or arg3 == "CAST" then
                matched = PlayerNormalQueue:ServerAccepted(arg4, arg2)
            elseif arg3 == "FAIL" then
                matched = PlayerNormalQueue:ServerFailure(arg4, arg2)
            end
            local routeEvidence = PlayerQueueEvents:Allows(arg4, matched)
            if castSpell and routeEvidence then
                XA:UpdateDecisionStatus(arg4, "player", arg3)
            end
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.playerCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.playerCastName = SpellInfo and SpellInfo(arg4) or nil
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                XA.playerCastUntil = nil; XA.playerCastName = nil
            end
            if castSpell and routeEvidence and arg3 == "CAST" then
                XA:TouchPendingSpell(arg4, "go", 2, playerGUID, arg2)
            elseif castSpell and routeEvidence and arg3 == "FAIL" then
                XA:MarkPendingFailure(arg4, playerGUID, arg2)
            end
        end
        local _, petGUID = UnitExists("pet")
        if petGUID and arg1 == petGUID then
            XA:UpdateDecisionStatus(arg4, "pet", arg3)
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.petCastGuid, XA.petCastSpellId = petGUID, arg4
                XA.petCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.petCastChannel = arg3 == "CHANNEL"
                XA:TouchPendingSpell(arg4, "started", (arg5 or 1500) / 1000 + 2,
                    petGUID, arg2)
            elseif arg3 == "CAST" then
                XA:ClearPetCast(arg4, petGUID)
                XA:TouchPendingSpell(arg4, "go", 2, petGUID, arg2)
            elseif arg3 == "FAIL" then
                XA:ClearPetCast(arg4, petGUID)
                XA:ClearPendingBySpell(arg4, petGUID, arg2)
            end
        end
    end
end)
