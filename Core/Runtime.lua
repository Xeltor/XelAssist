local XA = XelAssist
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
function XA:EnableEvidenceEvents()
    local names = { "NP_EnableAuraCastEvents", "NP_EnableSpellStartEvents",
        "NP_EnableSpellGoEvents" }
    local i
    if SetCVar then
        for i = 1, table.getn(names) do
            if not cvarEnabled(names[i]) then pcall(SetCVar, names[i], "1") end
        end
    end
    local nampower = (GetNampowerVersion or QueueSpellByName) and true or false
    self.evidenceEvents = { damage = nampower, miss = nampower, autoAttack = nampower,
        aura = cvarEnabled(names[1]), start = cvarEnabled(names[2]),
        go = cvarEnabled(names[3]) }
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
    if XelAssistCharDB.graphDepth == nil then XelAssistCharDB.graphDepth = 3 end
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

function XA:RecordDecision(plan, mode)
    if type(XelAssistLog) ~= "table" then XelAssistLog = {} end
    local state, action = plan.observed or {}, plan.action
    local resistanceComponents
    if plan.resistance and type(plan.resistance.components) == "table" then
        resistanceComponents = {}
        local i
        for i = 1, math.min(4, table.getn(plan.resistance.components)) do
            local component = plan.resistance.components[i]
            table.insert(resistanceComponents, {
                school = component.school, schoolName = component.schoolName,
                phase = component.componentPhase, weight = component.componentWeight,
                multiplier = component.multiplier, decisionWeight = component.decisionWeight,
                confidence = component.confidence, unknown = component.unknown and true or false,
                samples = component.samples })
        end
    end
    table.insert(XelAssistLog, { at = time and time() or 0, mode = mode,
        action = action.name, spellId = action.spellId, rank = action.rank,
        actor = action.actor or "player",
        executor = action.executor or "playerSpell", reason = plan.reason, status = "attempted",
        confidence = plan.confidence, value = math.floor(plan.value or 0),
        downtime = plan.downtime, threat = math.floor(plan.threat or 0),
        hp = state.health, hpMax = state.healthMax, targetHp = state.targetHealth,
        targetMax = state.targetMax, resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, aggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind,
        resistanceSchool = plan.resistance and plan.resistance.school,
        resistanceSchoolName = plan.resistance and plan.resistance.schoolName,
        resistanceMode = plan.resistance and plan.resistance.mode,
        resistanceComponents = resistanceComponents,
        resistanceMultiplier = plan.resistance and plan.resistance.multiplier,
        resistanceDecisionMultiplier = plan.resistance and plan.resistance.decisionMultiplier,
        resistanceDamageTakenMultiplier = plan.resistance and plan.resistance.damageTakenMultiplier,
        resistanceUncertaintyMultiplier = plan.resistance and plan.resistance.uncertaintyMultiplier,
        resistanceConfidence = plan.resistance and plan.resistance.confidence,
        resistanceSamples = plan.resistance and plan.resistance.samples,
        resistanceSource = plan.resistance and plan.resistance.source })
    while table.getn(XelAssistLog) > 200 do table.remove(XelAssistLog, 1) end
end

function XA:UpdateDecisionStatus(spellId, actor, status)
    if type(XelAssistLog) ~= "table" or not spellId then return false end
    actor = actor or "player"
    local spellName = SpellInfo and SpellInfo(spellId) or nil
    local i
    for i = table.getn(XelAssistLog), 1, -1 do
        local row = XelAssistLog[i]
        local active = row.status == "attempted" or row.status == "queued"
            or row.status == "accepted" or row.status == "start"
            or row.status == "channel" or row.status == "go"
        if active and row.actor == actor
            and (tonumber(row.spellId) == tonumber(spellId)
                or not row.spellId and spellName and row.action == spellName) then
            row.status = string.lower(status or "event")
            return true
        end
    end
    return false
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
        local ok, major, minor, patch = pcall(GetNampowerVersion)
        if ok and major then
            if minor ~= nil then runtime.nampower = tostring(major) .. "."
                .. tostring(minor) .. "." .. tostring(patch or 0)
            else runtime.nampower = tostring(major) end
        end
    end
    runtime.apis = { queue = QueueSpellByName and true or false,
        spellRecords = GetSpellRecField and true or false,
        exactUnits = GetUnitField and true or false,
        castInfo = GetCastInfo and true or false,
        rangeData = GetSpellRangeData and true or false,
        movement = PlayerIsMoving and true or false,
        targetResistances = (UnitResistance or GetUnitField) and true or false }
    local evidence = self:EnableEvidenceEvents()
    runtime.evidenceEvents = { damage = evidence.damage, miss = evidence.miss,
        autoAttack = evidence.autoAttack,
        aura = evidence.aura, start = evidence.start, go = evidence.go }
    local ok, actions = pcall(function()
        local found = XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or XelAssist.Game.Capabilities:Actions()
        if XelAssist.Game.Inventory then
            local items, i = XelAssist.Game.Inventory:Actions(), nil
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
        local runtime = self:RuntimeAudit()
        msg("mode=" .. self.mode .. ", execution=" .. (self.executionEnabled and "ready" or "disabled")
            .. ", graph=utility, depth=" .. (XelAssistCharDB.graphDepth or 3)
            .. ", nodes=" .. (runtime.actions or 0) .. ", inferred=" .. (runtime.inferred or 0)
            .. ", fallback=conservative hold, schema=" .. (runtime.schema or 4) .. ".")
        msg("SuperWoW=" .. (runtime.superWoW or "missing") .. ", Nampower="
            .. (runtime.nampower or (runtime.apis.queue and "present" or "missing"))
            .. ", DBC=" .. (runtime.apis.spellRecords and "yes" or "no")
            .. ", exact-units=" .. (runtime.apis.exactUnits and "yes" or "no") .. ".")
        msg("resistance outcomes: damage=" .. (runtime.evidenceEvents.damage and "on" or "off")
            .. ", miss=" .. (runtime.evidenceEvents.miss and "on" or "off")
            .. ", white swings=" .. (runtime.evidenceEvents.autoAttack and "on" or "off")
            .. ", aura=" .. (runtime.evidenceEvents.aura and "on" or "off")
            .. ", cast lifecycle=" .. (runtime.evidenceEvents.start
                and runtime.evidenceEvents.go and "on" or "off") .. ".")
        if runtime.lastError then msg("last graph error: " .. runtime.lastError, 1, 0.4, 0.25) end
        return
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
    if cmd == "log" then
        local first = math.max(1, table.getn(XelAssistLog) - 4)
        local i
        for i = first, table.getn(XelAssistLog) do
            local row = XelAssistLog[i]
            local resistance = ""
            if row.resistanceDecisionMultiplier then
                local school = row.resistanceSchoolName
                    or row.resistanceSchool ~= nil and XelAssist.Combat.Resistance
                        and XelAssist.Combat.Resistance:SchoolName(row.resistanceSchool)
                    or row.resistanceMode == "mixed" and "Mixed" or "effect"
                resistance = " · " .. school .. " "
                    .. math.floor(row.resistanceDecisionMultiplier * 100 + 0.5) .. "% scored"
                    .. " [" .. tostring(row.resistanceConfidence or "unknown")
                    .. ((row.resistanceSamples or 0) > 0
                        and ", " .. tostring(row.resistanceSamples) .. " samples" or "") .. "]"
                if type(row.resistanceComponents) == "table" then
                    local componentParts, componentTotal, componentIndex = {}, 0, nil
                    for componentIndex = 1, table.getn(row.resistanceComponents) do
                        componentTotal = componentTotal
                            + (tonumber(row.resistanceComponents[componentIndex].weight) or 0)
                    end
                    for componentIndex = 1, table.getn(row.resistanceComponents) do
                        local component = row.resistanceComponents[componentIndex]
                        local label = component.phase or component.schoolName
                            or component.school ~= nil and XelAssist.Combat.Resistance
                                and XelAssist.Combat.Resistance:SchoolName(component.school) or "part"
                        local share = componentTotal > 0
                            and math.floor((component.weight or 0) * 100 / componentTotal + 0.5)
                            or 0
                        table.insert(componentParts, label .. " "
                            .. math.floor((component.multiplier or 1) * 100 + 0.5)
                            .. "%@" .. share .. "%"
                            .. (component.unknown and " uncertain" or ""))
                    end
                    resistance = resistance .. " {" .. table.concat(componentParts, ", ") .. "}"
                end
                if row.resistanceMultiplier then
                    resistance = resistance .. " · expected "
                        .. math.floor(row.resistanceMultiplier * 100 + 0.5) .. "%"
                end
                if row.resistanceDamageTakenMultiplier
                    and math.abs(row.resistanceDamageTakenMultiplier - 1) > 0.001 then
                    resistance = resistance .. " · target modifier "
                        .. math.floor(row.resistanceDamageTakenMultiplier * 100 + 0.5) .. "%"
                end
                if row.resistanceUncertaintyMultiplier
                    and math.abs(row.resistanceUncertaintyMultiplier - 1) > 0.001 then
                    resistance = resistance .. " · confidence reserve "
                        .. math.floor(row.resistanceUncertaintyMultiplier * 100 + 0.5) .. "%"
                end
                if row.resistanceSource then
                    resistance = resistance .. " · " .. tostring(row.resistanceSource)
                end
            end
            msg("log " .. i .. ": " .. row.action .. " R" .. (row.rank or 0)
                .. " — " .. row.reason .. " (" .. row.confidence .. ", "
                .. (row.status or "unknown") .. ")" .. resistance)
        end
        if table.getn(XelAssistLog) == 0 then msg("decision log is empty.") end
        return
    end
    if cmd == "clearlog" then XelAssistLog = {}; msg("decision log cleared."); return end
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
    if event == "ADDON_LOADED" and arg1 == "XelAssist" then XA:Init() end
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
        XA:MarkPendingFailure(nil, XA:PlayerGUID())
    end
    if event == "SPELLCAST_INTERRUPTED" then
        -- The vanilla event carries no spell identity. A known fallback cast
        -- name is authoritative enough to clear only its matching reservation;
        -- with no name, retain the legacy single-current reservation fallback.
        XA:ClearCurrentPendingAura(XA:PlayerGUID(), XA.playerCastName)
        XA.playerCastUntil, XA.playerCastName = nil, nil
    end
    if event == "SPELL_FAILED_SELF" then
        local _, playerGuid = UnitExists("player")
        XA:MarkPendingFailure(arg1, playerGuid)
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
        local queueCode = tonumber(arg1)
        if queueCode == 0 or queueCode == 2 or queueCode == 4 then
            XA:TouchPendingSpell(arg2, "queued", 2, XA:PlayerGUID())
        else
            local lifecycle = XA:Lifecycle(arg2, XA:PlayerGUID(), nil)
            if lifecycle then
                lifecycle.state, lifecycle.poppedAt, lifecycle.lastAt =
                    "popped", GetTime(), GetTime()
            end
        end
    end
    if event == "SPELL_CAST_EVENT" then
        local casterGuid, ambiguous = XA:PendingCasterForSpell(arg2, arg4)
        if casterGuid and not ambiguous then
            if tonumber(arg1) == 1 then
                XA:TouchPendingSpell(arg2, "accepted", 2, casterGuid, arg4)
            else XA:MarkPendingFailure(arg2, casterGuid, arg4) end
        end
    end
    if (event == "SPELL_START_SELF" or event == "SPELL_START_OTHER")
        and XelAssist.Combat.Resistance and XelAssist.Combat.Resistance:IsOwnedCaster(arg3) then
        local castSeconds = math.max(0, tonumber(arg6) or 0) / 1000
        local channelSeconds = math.max(0, tonumber(arg7) or 0) / 1000
        local duration = castSeconds + channelSeconds
        XA:TouchPendingSpell(arg2, "started", duration + 2, arg3, arg4)
        local _, petGuid = UnitExists("pet")
        if arg3 == petGuid then
            XA.petCastGuid, XA.petCastSpellId = arg3, arg2
            XA.petCastUntil = GetTime() + math.max(0.05, duration)
            XA.petCastChannel = tonumber(arg8) == 1 and true or false
        end
    end
    if (event == "SPELL_GO_SELF" or event == "SPELL_GO_OTHER")
        and XelAssist.Combat.Resistance and XelAssist.Combat.Resistance:IsOwnedCaster(arg3) then
        XA:TouchPendingSpell(arg2, "go", 2, arg3, arg4)
        if XA.petCastGuid == arg3 and tonumber(XA.petCastSpellId) == tonumber(arg2)
            and not XA.petCastChannel then
            XA:ClearPetCast(arg2, arg3)
        end
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
        XelAssist.Combat.Observations:SpellDamage(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
    if (event == "AUTO_ATTACK_SELF" or event == "AUTO_ATTACK_OTHER")
        and XelAssist.Combat.Resistance then
        XelAssist.Game.Pets.EffectRuntime:ObserveAutoAttack(arg1, arg2,
            XelAssist.Combat.Resistance:AutoAttack(arg1, arg2, arg3, arg4,
                arg5, arg6, arg7, arg8, arg9))
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
            if castSpell then XA:UpdateDecisionStatus(arg4, "player", arg3) end
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.playerCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.playerCastName = SpellInfo and SpellInfo(arg4) or nil
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                XA.playerCastUntil = nil; XA.playerCastName = nil
            end
            if castSpell and arg3 == "CAST" then
                XA:TouchPendingSpell(arg4, "go", 2, playerGUID, arg2)
            elseif castSpell and arg3 == "FAIL" then
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
