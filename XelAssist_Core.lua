XelAssist = { version = "0.4.0", mode = "smart" }
local XA = XelAssist

local function msg(text, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. text, r or 0.35, g or 0.85, b or 1)
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
    if XelAssistCharDB.graphDepth == nil then XelAssistCharDB.graphDepth = 3 end
    if XelAssistCharDB.role == nil then XelAssistCharDB.role = "auto" end
    if XelAssistCharDB.allowAoe == nil then XelAssistCharDB.allowAoe = false end
    if XelAssistCharDB.petThreat == nil then XelAssistCharDB.petThreat = "auto" end
    if XelAssistCharDB.mode then self.mode = XelAssistCharDB.mode end
    XelAssistCharDB.fallback = nil
    XelAssistCharDB.schema = 4
    self:CheckDependencies()
    XelAssistUI:Build()
    XelAssistMinimap:Build()
end

function XA:RecordDecision(plan, mode)
    if type(XelAssistLog) ~= "table" then XelAssistLog = {} end
    local state, action = plan.observed or {}, plan.action
    table.insert(XelAssistLog, { at = time and time() or 0, mode = mode,
        action = action.name, rank = action.rank, actor = action.actor or "player",
        executor = action.executor or "playerSpell", reason = plan.reason, status = "attempted",
        confidence = plan.confidence, value = math.floor(plan.value or 0),
        downtime = plan.downtime, threat = math.floor(plan.threat or 0),
        hp = state.health, hpMax = state.healthMax, targetHp = state.targetHealth,
        targetMax = state.targetMax, resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, aggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind })
    while table.getn(XelAssistLog) > 200 do table.remove(XelAssistLog, 1) end
end

function XA:CheckDependencies()
    local missing = {}
    if not SpellInfo or not SUPERWOW_VERSION then table.insert(missing, "SuperWoW") end
    if not IsAddOnLoaded or not IsAddOnLoaded("SuperAPI") then table.insert(missing, "SuperAPI") end
    if not QueueSpellByName then table.insert(missing, "Nampower") end
    self.missing = missing
    self.executionEnabled = table.getn(missing) == 0
    if not self.executionEnabled then msg("execution disabled; missing " .. table.concat(missing, ", ") .. ".", 1, 0.25, 0.2) end
end

function XA:RuntimeAudit()
    if type(XelAssistCharDB.runtime) ~= "table" then XelAssistCharDB.runtime = {} end
    local runtime = XelAssistCharDB.runtime
    runtime.version = self.version
    runtime.schema = XelAssistCharDB.schema
    runtime.loadedAt = time and time() or 0
    runtime.superWoW = SUPERWOW_VERSION and tostring(SUPERWOW_VERSION) or nil
    if GetNampowerVersion then
        local ok, version = pcall(GetNampowerVersion)
        if ok and version then runtime.nampower = tostring(version) end
    end
    runtime.apis = { queue = QueueSpellByName and true or false,
        spellRecords = GetSpellRecField and true or false,
        exactUnits = GetUnitField and true or false,
        castInfo = GetCastInfo and true or false,
        rangeData = GetSpellRangeData and true or false,
        movement = PlayerIsMoving and true or false,
        targetResistances = GetUnitField and true or false }
    local ok, actions = pcall(function()
        local found = XelAssistActors and XelAssistActors:Actions() or XelAssistCapabilities:Actions()
        if XelAssistInventory then
            local items, i = XelAssistInventory:Actions(), nil
            for i = 1, table.getn(items) do table.insert(found, items[i]) end
        end
        return found
    end)
    if ok and type(actions) == "table" then
        local inferred, petActions, i = 0, 0, nil
        for i = 1, table.getn(actions) do
            if actions[i].facts and actions[i].facts.inferred then inferred = inferred + 1 end
            if actions[i].actor == "pet" then petActions = petActions + 1 end
        end
        runtime.actions = table.getn(actions)
        runtime.petActions = petActions
        runtime.petPresent = UnitExists("pet") and not UnitIsDead("pet") and true or false
        runtime.petSpellbook = GetSpellName and BOOKTYPE_PET and true or false
        runtime.petActionBar = GetPetActionInfo and true or false
        runtime.petCooldowns = GetPetActionCooldown and true or false
        runtime.inferred = inferred
        runtime.auditError = nil
    else
        runtime.actions, runtime.inferred = nil, nil
        runtime.auditError = tostring(actions or "action discovery failed")
    end
    return runtime
end

function XA:RecordError(detail)
    if type(XelAssistCharDB.runtime) ~= "table" then XelAssistCharDB.runtime = {} end
    XelAssistCharDB.runtime.lastError = tostring(detail or "unknown evaluation failure")
    XelAssistCharDB.runtime.lastErrorAt = time and time() or 0
end

function XA:TargetGUID()
    local exists, guid = UnitExists("target")
    if exists then return guid end
    return nil
end

function XA:PendingAuraKey(name, guid)
    if not name or not guid then return nil end
    return guid .. ":" .. name
end

function XA:MarkAuraPending(name, seconds, guid)
    if not name then return end
    if type(self.pendingAuras) ~= "table" then self.pendingAuras = {} end
    guid = guid or self:TargetGUID()
    local key = self:PendingAuraKey(name, guid)
    if not key then return end
    self.pendingAuras[key] = { name = name, target = guid, untilAt = GetTime() + (seconds or 2) }
    self.currentPendingAura = { key = key, name = name, target = guid }
end

function XA:ClearAuraPending(name, guid)
    local key = self:PendingAuraKey(name, guid or self:TargetGUID())
    if key and self.pendingAuras then self.pendingAuras[key] = nil end
    if self.currentPendingAura and self.currentPendingAura.key == key then self.currentPendingAura = nil end
end

function XA:ClearCurrentPendingAura()
    local current = self.currentPendingAura
    if current then self:ClearAuraPending(current.name, current.target) end
end

function XA:IsAuraPending(name)
    local key = self:PendingAuraKey(name, self:TargetGUID())
    local rec = key and self.pendingAuras and self.pendingAuras[key]
    if not rec then return false end
    if not rec.untilAt or rec.untilAt <= GetTime() then
        self.pendingAuras[key] = nil
        return false
    end
    return true
end

function XA:Fallback(reason)
    self.lastReason = "Conservative hold — " .. reason
    msg(self.lastReason .. ".", 1, 0.65, 0.2)
end

function XA:Execute(mode)
    if not self.executionEnabled then self:CheckDependencies(); if not self.executionEnabled then return end end
    local selected = mode or self.mode
    local ok, plan, err, fallback = pcall(function()
        local p, e, f = XelAssistGraph:Evaluate(selected, false)
        return p, e, f
    end)
    if not ok then self:RecordError(plan); self:Fallback("evaluation error"); return end
    if fallback then self:Fallback(err or "incomplete data"); return end
    if not plan then msg(err or "no legal action"); return end
    local a = plan.action
    local facts = a.facts
    if a.executor == "item" then
        if not XelAssistInventory:Execute(a) then self:Fallback("item unavailable"); return end
        self:RecordDecision(plan, selected)
        self.lastReason = a.name .. " — " .. plan.reason
        XelAssistUI:Refresh(true)
        return
    end
    if a.actor == "pet" then
        if not XelAssistActors:Execute(a) then self:Fallback("pet action unavailable"); return end
        self:RecordDecision(plan, selected)
        self.lastReason = a.name .. " — " .. plan.reason
        XelAssistUI:Refresh(true)
        return
    end
    local castName = XelAssistCapabilities:CastName(a)
    local unit = plan.target or ((not facts.ground) and "target" or nil)
    if XelAssistCapabilities:InRange(a.name, unit) == false then
        self.lastReason = "Move into range — " .. a.name
        XelAssistUI:Refresh(true)
        return
    end
    if facts.ground then
        CastSpellByName(castName, "CLICK")
    elseif plan.target == "target" and QueueSpellByName then
        QueueSpellByName(castName)
    elseif plan.target then
        CastSpellByName(castName, plan.target)
    elseif QueueSpellByName then
        QueueSpellByName(castName)
    else
        CastSpellByName(castName)
    end
    self:RecordDecision(plan, selected)
    if XelAssistObservations then XelAssistObservations:Submitted(a, plan.target, plan.tooltip) end
    if facts.kind == "dot" or facts.kind == "debuff" or facts.kind == "crowdControl" then
        self:MarkAuraPending(a.name, math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2))
    end
    self.lastReason = a.name .. " — " .. plan.reason
    XelAssistUI:Refresh(true)
end

function XA:SetMode(mode)
    self.mode = mode; XelAssistCharDB.mode = mode
    msg("mode set to " .. mode .. ".")
    XelAssistUI:Refresh(true)
end

function XA:Command(text)
    local cmd, arg = string.gsub(text or "", "^%s*(%S*)%s*(.-)%s*$", "%1"), nil
    cmd = string.lower(cmd or "")
    local p = string.find(text or "", "%s")
    if p then arg = string.gsub(string.sub(text, p + 1), "^%s*(.-)%s*$", "%1") end
    if cmd == "" or cmd == "execute" then self:Execute(); return end
    if cmd == "why" then msg(self.lastReason or XelAssistUI.lastReason or "no decision yet."); return end
    if cmd == "smart" or cmd == "single" or cmd == "aoe" or cmd == "support" then self:SetMode(cmd); return end
    if cmd == "cooldowns" or cmd == "reagents" or cmd == "consumables" then
        local current = XelAssistCharDB.toggles[cmd]
        XelAssistCharDB.toggles[cmd] = not current
        msg(cmd .. " " .. (not current and "enabled" or "disabled") .. ".")
        return
    end
    if cmd == "diagnostics" then
        local runtime = self:RuntimeAudit()
        msg("mode=" .. self.mode .. ", execution=" .. (self.executionEnabled and "ready" or "disabled")
            .. ", graph=utility, depth=" .. (XelAssistCharDB.graphDepth or 3)
            .. ", nodes=" .. (runtime.actions or 0) .. ", inferred=" .. (runtime.inferred or 0)
            .. ", fallback=conservative hold, schema=" .. (runtime.schema or 4) .. ".")
        msg("SuperWoW=" .. (runtime.superWoW or "missing") .. ", Nampower="
            .. (runtime.nampower or (runtime.apis.queue and "present" or "missing"))
            .. ", DBC=" .. (runtime.apis.spellRecords and "yes" or "no")
            .. ", exact-units=" .. (runtime.apis.exactUnits and "yes" or "no") .. ".")
        if runtime.lastError then msg("last graph error: " .. runtime.lastError, 1, 0.4, 0.25) end
        return
    end
    if cmd == "log" then
        local first = math.max(1, table.getn(XelAssistLog) - 4)
        local i
        for i = first, table.getn(XelAssistLog) do
            local row = XelAssistLog[i]
            msg("log " .. i .. ": " .. row.action .. " R" .. (row.rank or 0)
                .. " — " .. row.reason .. " (" .. row.confidence .. ", " .. (row.status or "unknown") .. ")")
        end
        if table.getn(XelAssistLog) == 0 then msg("decision log is empty.") end
        return
    end
    if cmd == "clearlog" then XelAssistLog = {}; msg("decision log cleared."); return end
    if cmd == "buff" or cmd == "buffs" then self:Execute("buff"); return end
    if cmd == "config" or cmd == "ui" then XelAssistConfig:Toggle(); return end
    if cmd == "show" then XelAssistUI.frame:Show(); XelAssistDB.ui.shown = true; return end
    if cmd == "hide" then XelAssistUI.frame:Hide(); XelAssistDB.ui.shown = false; return end
    msg("commands: execute, why, smart, single, aoe, support, buffs, cooldowns, reagents, consumables, diagnostics, log, clearlog, config, show, hide")
end

SLASH_XELASSIST1 = "/xassist"
SLASH_XELASSIST2 = "/xa"
SlashCmdList["XELASSIST"] = function(text) XA:Command(text) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
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
ev:RegisterEvent("SPELL_GO_SELF")
ev:RegisterEvent("SPELL_FAILED_SELF")
ev:RegisterEvent("SPELL_MISS_SELF")
ev:RegisterEvent("AURA_CAST_ON_SELF")
ev:RegisterEvent("AURA_CAST_ON_OTHER")
ev:RegisterEvent("DEBUFF_ADDED_OTHER")
ev:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "XelAssist" then XA:Init() end
    if event == "PLAYER_LOGIN" then
        local runtime = XA:RuntimeAudit()
        msg("v" .. XA.version .. " ready · " .. (runtime.actions or 0) .. " action nodes ("
            .. (runtime.inferred or 0) .. " inferred). Bind Smart Execute or click the action button.")
    end
    if event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        XelAssistCapabilities:Invalidate()
        if XelAssistActors then XelAssistActors:Invalidate() end
    end
    if event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "UNIT_PET" then
        if XelAssistActors then XelAssistActors:Invalidate() end
    end
    if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" then
        if XelAssistInventory then XelAssistInventory:Invalidate() end
    end
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" and arg1 and
        (string.find(string.lower(arg1), "resist") or string.find(string.lower(arg1), "miss")) then
        local _, rec
        for _, rec in pairs(XA.pendingAuras or {}) do
            if string.find(arg1, rec.name, 1, true) then
                XA:ClearAuraPending(rec.name, rec.target); break
            end
        end
    end
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" and XelAssistObservations then
        local outcome, outcomeTarget, outcomeSpell = XelAssistObservations:CombatMessage(arg1)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget)
        end
    end
    if event == "UI_ERROR_MESSAGE" and XelAssistObservations then
        XelAssistObservations:ErrorMessage(arg1)
    end
    if event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        XA:ClearCurrentPendingAura()
    end
    if event == "SPELL_FAILED_SELF" then
        local spellName = SpellInfo and SpellInfo(arg3) or nil
        if spellName then XA:ClearAuraPending(spellName, arg2) end
    end
    if event == "SPELL_GO_SELF" then
        local spellName = SpellInfo and SpellInfo(arg2) or nil
        local pendingKey = XA:PendingAuraKey(spellName, arg4)
        if pendingKey and XA.pendingAuras and XA.pendingAuras[pendingKey] then
            XA:MarkAuraPending(spellName, 2, arg4)
        end
    end
    if event == "SPELL_MISS_SELF" and XelAssistObservations then
        local outcome, outcomeTarget, outcomeSpell = XelAssistObservations:SpellMiss(arg1, arg2, arg3)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget)
        end
    end
    if event == "AURA_CAST_ON_SELF" or event == "AURA_CAST_ON_OTHER" then
        local spellName = SpellInfo and SpellInfo(arg1) or nil
        if spellName then XA:ClearAuraPending(spellName, arg3) end
    end
    if event == "DEBUFF_ADDED_OTHER" then
        local spellName = SpellInfo and SpellInfo(arg3) or nil
        if spellName then XA:ClearAuraPending(spellName, arg1) end
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
            if castSpell and type(XelAssistLog) == "table" then
                local i
                for i = table.getn(XelAssistLog), 1, -1 do
                    if XelAssistLog[i].action == castSpell and XelAssistLog[i].status == "attempted" then
                        XelAssistLog[i].status = string.lower(arg3 or "event")
                        break
                    end
                end
            end
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.playerCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.playerCastName = SpellInfo and SpellInfo(arg4) or nil
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                XA.playerCastUntil = nil; XA.playerCastName = nil
            end
            local castKey = XA:PendingAuraKey(castSpell, arg2)
            if castSpell and arg3 == "CAST" and castKey and XA.pendingAuras
                and XA.pendingAuras[castKey] then XA:MarkAuraPending(castSpell, 2, arg2)
            elseif castSpell and arg3 == "FAIL" then XA:ClearAuraPending(castSpell, arg2) end
        end
    end
end)
