XelAssist = { version = "0.5.0", mode = "smart" }
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
    XelAssistUI:Build()
    XelAssistMinimap:Build()
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

function XA:PendingAuraKey(name, guid, casterGuid)
    if not name or not guid then return nil end
    return guid .. ":" .. tostring(casterGuid or self:PlayerGUID()) .. ":" .. name
end

local function usableGuid(guid)
    if not guid or guid == "" or guid == "0x000000000"
        or guid == "0x0000000000000000" then return nil end
    return guid
end

function XA:PlayerGUID()
    local exists, guid = UnitExists("player")
    return exists and guid or "player"
end

function XA:LifecycleKey(spellId, casterGuid, targetGuid)
    if not spellId then return nil end
    return tostring(casterGuid or self:PlayerGUID()) .. ":"
        .. tostring(usableGuid(targetGuid) or "*") .. ":" .. tostring(spellId)
end

function XA:Lifecycle(spellId, casterGuid, targetGuid, create)
    if not spellId then return nil end
    if type(self.spellLifecycle) ~= "table" then self.spellLifecycle = {} end
    local at, stale, existingKey, existing = GetTime(), {}, nil, nil
    for existingKey, existing in pairs(self.spellLifecycle) do
        if at - (existing.lastAt or 0) > 60 then table.insert(stale, existingKey) end
    end
    local staleIndex
    for staleIndex = 1, table.getn(stale) do self.spellLifecycle[stale[staleIndex]] = nil end
    local key = self:LifecycleKey(spellId, casterGuid, targetGuid)
    local record = self.spellLifecycle[key]
    if not record and create ~= false then
        record = { spellId = spellId, casterGuid = casterGuid or self:PlayerGUID(),
            targetGuid = usableGuid(targetGuid) }
        self.spellLifecycle[key] = record
    end
    return record
end

function XA:MarkAuraPending(name, seconds, guid, spellId, casterGuid, auraBar)
    if not name then return end
    if type(self.pendingAuras) ~= "table" then self.pendingAuras = {} end
    guid = guid or self:TargetGUID()
    casterGuid = casterGuid or self:PlayerGUID()
    local key = self:PendingAuraKey(name, guid, casterGuid)
    if not key then return end
    local lifecycle = self:Lifecycle(spellId, casterGuid, guid, false)
        or self:Lifecycle(spellId, casterGuid, nil, false)
    if lifecycle and GetTime() - (lifecycle.lastAt or 0) > 0.25 then lifecycle = nil end
    local positiveAt = lifecycle and math.max(lifecycle.queuedAt or 0,
        lifecycle.acceptedAt or 0, lifecycle.startedAt or 0, lifecycle.goAt or 0) or 0
    local failureAt = lifecycle and lifecycle.failureAt
    local record = { name = name, target = guid, spellId = spellId,
        casterGuid = casterGuid, submittedAt = GetTime(),
        untilAt = GetTime() + (seconds or 2),
        state = lifecycle and lifecycle.state or "submitted", auraBar = auraBar }
    if failureAt and failureAt > positiveAt then record.failureAt = failureAt end
    self.pendingAuras[key] = record
    if type(self.currentPendingAuras) ~= "table" then self.currentPendingAuras = {} end
    self.currentPendingAuras[casterGuid] = { key = key, name = name, target = guid,
        spellId = spellId, casterGuid = casterGuid, auraBar = auraBar }
end

function XA:ClearAuraPending(name, guid, casterGuid)
    local key = self:PendingAuraKey(name, guid or self:TargetGUID(), casterGuid)
    local record = key and self.pendingAuras and self.pendingAuras[key]
    if record and XelAssistResistance and XelAssistResistance.CancelSubmission then
        XelAssistResistance:CancelSubmission(record.spellId, record.casterGuid, record.target)
    end
    if key and self.pendingAuras then self.pendingAuras[key] = nil end
    local caster, current
    for caster, current in pairs(self.currentPendingAuras or {}) do
        if current.key == key then self.currentPendingAuras[caster] = nil end
    end
end

function XA:ClearPendingBySpell(spellId, casterGuid, targetGuid)
    local matches, key, record = {}, nil, nil
    for key, record in pairs(self.pendingAuras or {}) do
        if tonumber(record.spellId) == tonumber(spellId)
            and (not casterGuid or record.casterGuid == casterGuid)
            and (not targetGuid or record.target == targetGuid) then
            table.insert(matches, { name = record.name, target = record.target,
                casterGuid = record.casterGuid })
        end
    end
    local i
    for i = 1, table.getn(matches) do
        self:ClearAuraPending(matches[i].name, matches[i].target, matches[i].casterGuid)
    end
    if XelAssistResistance and XelAssistResistance.CancelSubmission then
        XelAssistResistance:CancelSubmission(spellId, casterGuid, targetGuid)
    end
end

function XA:TouchPendingSpell(spellId, state, seconds, casterGuid, targetGuid)
    casterGuid = casterGuid or self:PlayerGUID()
    targetGuid = usableGuid(targetGuid)
    if not targetGuid then
        local current = self.currentPendingAuras and self.currentPendingAuras[casterGuid]
        if current and tonumber(current.spellId) == tonumber(spellId) then
            targetGuid = current.target
        else
            local uniqueTarget, matches, _, candidate = nil, 0, nil, nil
            for _, candidate in pairs(self.pendingAuras or {}) do
                if tonumber(candidate.spellId) == tonumber(spellId)
                    and candidate.casterGuid == casterGuid then
                    matches, uniqueTarget = matches + 1, candidate.target
                end
            end
            if matches == 1 then targetGuid = uniqueTarget end
        end
    end
    local lifecycle = self:Lifecycle(spellId, casterGuid, targetGuid)
    if lifecycle then
        local at = GetTime()
        lifecycle.state, lifecycle.lastAt = state, at
        if state == "queued" then lifecycle.queuedAt = at
        elseif state == "accepted" then lifecycle.acceptedAt = at
        elseif state == "started" then lifecycle.startedAt = at
        elseif state == "go" then lifecycle.goAt = at end
        lifecycle.failureAt = nil
    end
    local _, record
    for _, record in pairs(self.pendingAuras or {}) do
        if tonumber(record.spellId) == tonumber(spellId)
            and record.casterGuid == casterGuid
            and targetGuid and record.target == targetGuid then
            record.state, record.failureAt = state, nil
            record.untilAt = math.max(record.untilAt or 0, GetTime() + (seconds or 2))
        end
    end
end

function XA:MarkPendingFailure(spellId, casterGuid, targetGuid)
    casterGuid = casterGuid or self:PlayerGUID()
    targetGuid = usableGuid(targetGuid)
    local at = GetTime()
    local current = self.currentPendingAuras and self.currentPendingAuras[casterGuid]
    if not targetGuid and current
        and (not spellId or tonumber(current.spellId) == tonumber(spellId)) then
        targetGuid = current.target
    end
    if not targetGuid then
        local uniqueTarget, matches, _, candidate = nil, 0, nil, nil
        for _, candidate in pairs(self.pendingAuras or {}) do
            if (not spellId or tonumber(candidate.spellId) == tonumber(spellId))
                and candidate.casterGuid == casterGuid then
                matches, uniqueTarget = matches + 1, candidate.target
            end
        end
        if matches == 1 then targetGuid = uniqueTarget end
    end
    local lifecycle = spellId and self:Lifecycle(spellId, casterGuid, targetGuid) or nil
    if lifecycle then
        lifecycle.state, lifecycle.failureAt, lifecycle.lastAt = "failed-tentative", at, at
    end
    local onlyKey = current and current.target == targetGuid
        and (not spellId or tonumber(current.spellId) == tonumber(spellId))
        and current.key or nil
    if targetGuid and not onlyKey then
        local _, candidate
        for _, candidate in pairs(self.pendingAuras or {}) do
            if candidate.target == targetGuid and candidate.casterGuid == casterGuid
                and (not spellId or tonumber(candidate.spellId) == tonumber(spellId)) then
                onlyKey = self:PendingAuraKey(candidate.name, candidate.target, casterGuid)
                break
            end
        end
    end
    if not onlyKey then return end
    local _, record
    for _, record in pairs(self.pendingAuras or {}) do
        if (not spellId or tonumber(record.spellId) == tonumber(spellId))
            and record.casterGuid == casterGuid
            and self:PendingAuraKey(record.name, record.target, record.casterGuid) == onlyKey then
            record.state, record.failureAt = "failed-tentative", at
            record.untilAt = math.max(record.untilAt or 0, at + 0.30)
        end
    end
end

function XA:ClearCurrentPendingAura(casterGuid, expectedName, expectedSpellId)
    casterGuid = casterGuid or self:PlayerGUID()
    local current = self.currentPendingAuras and self.currentPendingAuras[casterGuid]
    if not current then return false end
    if expectedName and current.name ~= expectedName then return false end
    if expectedSpellId and tonumber(current.spellId) ~= tonumber(expectedSpellId) then
        return false
    end
    self:ClearAuraPending(current.name, current.target, casterGuid)
    return true
end

function XA:PendingCasterForSpell(spellId, targetGuid)
    targetGuid = usableGuid(targetGuid)
    local found
    local _, record
    for _, record in pairs(self.pendingAuras or {}) do
        if tonumber(record.spellId) == tonumber(spellId)
            and (not targetGuid or record.target == targetGuid) then
            -- SPELL_CAST_EVENT has no caster GUID and can describe either the
            -- player or some pet casts. Never guess when both actors own the
            -- same spell/target reservation; later caster-bearing events will
            -- resolve each lifecycle exactly.
            if found and found ~= record.casterGuid then return nil, true end
            found = record.casterGuid
        end
    end
    return found, false
end

function XA:ClearPetCast(spellId, casterGuid)
    if casterGuid and self.petCastGuid ~= casterGuid then return false end
    if spellId and tonumber(self.petCastSpellId) ~= tonumber(spellId) then return false end
    self.petCastUntil, self.petCastGuid, self.petCastSpellId, self.petCastChannel =
        nil, nil, nil, nil
    return true
end

function XA:HandlePetIdentityChange()
    local petExists, petGuid = UnitExists("pet")
    petGuid = petExists and petGuid or nil
    local playerGuid = self:PlayerGUID()
    local stale, _, record = {}, nil, nil
    for _, record in pairs(self.pendingAuras or {}) do
        if record.casterGuid ~= playerGuid and record.casterGuid ~= petGuid then
            table.insert(stale, { name = record.name, target = record.target,
                casterGuid = record.casterGuid })
        end
    end
    local i
    for i = 1, table.getn(stale) do
        self:ClearAuraPending(stale[i].name, stale[i].target, stale[i].casterGuid)
    end
    if self.petCastGuid and self.petCastGuid ~= petGuid then
        self:ClearPetCast(nil, self.petCastGuid)
    end
    self.lastPetGuid = petGuid
end

function XA:SweepPendingAuras()
    local expired, key, rec = {}, nil, nil
    local at = GetTime()
    for key, rec in pairs(self.pendingAuras or {}) do
        if rec.failureAt and at - rec.failureAt >= 0.20
            or not rec.untilAt or rec.untilAt <= at then
            table.insert(expired, { name = rec.name, target = rec.target,
                casterGuid = rec.casterGuid })
        end
    end
    local i
    for i = 1, table.getn(expired) do
        self:ClearAuraPending(expired[i].name, expired[i].target, expired[i].casterGuid)
    end
end

function XA:IsAuraPending(name, actor, target)
    self:SweepPendingAuras()
    local casterGuid
    if actor == "pet" then
        local exists, guid = UnitExists("pet")
        casterGuid = exists and guid or nil
    elseif actor and actor ~= "player" then casterGuid = actor
    else casterGuid = self:PlayerGUID() end
    local targetGuid
    if target then
        local exists, guid = UnitExists(target)
        targetGuid = exists and guid or target
    else targetGuid = self:TargetGUID() end
    local key = self:PendingAuraKey(name, targetGuid, casterGuid)
    local rec = key and self.pendingAuras and self.pendingAuras[key]
    if not rec then return false end
    return true
end

local function applicationGuarded(facts, tooltip)
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" then return true end
    return kind == "resource" and (facts.channel
        or tooltip and (tonumber(tooltip.duration) or 0) > 0) and true or false
end

local function auraBarForFacts(facts)
    local kind = facts and facts.kind
    if kind == "dot" or kind == "debuff" or kind == "crowdControl" then
        return "debuff"
    end
    if kind == "buff" or kind == "hot" or kind == "absorb" then return "buff" end
    if kind == "resource" then return facts.self and "buff" or "debuff" end
    return nil
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
        if XelAssistObservations then XelAssistObservations:Submitted(a, plan.target, plan.tooltip) end
        if applicationGuarded(facts, plan.tooltip) then
            local _, petGuid = UnitExists("pet")
            local _, pendingTarget = UnitExists(plan.target or "target")
            self:MarkAuraPending(a.name,
                math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2),
                pendingTarget, a.spellId, petGuid, auraBarForFacts(facts))
        end
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
    if applicationGuarded(facts, plan.tooltip) then
        local _, playerGuid = UnitExists("player")
        local _, pendingTarget = UnitExists(plan.target or "target")
        self:MarkAuraPending(a.name,
            math.max(2, (plan.wait or 0) + (plan.cast or 0) + 2),
            pendingTarget, a.spellId, playerGuid, auraBarForFacts(facts))
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
        local state = XelAssistGraph:Snapshot(self.mode)
        if not state.hostile or not XelAssistResistance then
            msg("select a hostile target to inspect resistance evidence."); return
        end
        local rows = XelAssistResistance:CurrentSummary(state)
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
                    or row.resistanceSchool ~= nil and XelAssistResistance
                        and XelAssistResistance:SchoolName(row.resistanceSchool)
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
                            or component.school ~= nil and XelAssistResistance
                                and XelAssistResistance:SchoolName(component.school) or "part"
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
    if cmd == "config" or cmd == "ui" then XelAssistConfig:Toggle(); return end
    if cmd == "show" then XelAssistUI.frame:Show(); XelAssistDB.ui.shown = true; return end
    if cmd == "hide" then XelAssistUI.frame:Hide(); XelAssistDB.ui.shown = false; return end
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
        XelAssistCapabilities:Invalidate()
        if XelAssistActors then XelAssistActors:Invalidate() end
    end
    if event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "UNIT_PET" then
        if event == "UNIT_PET" then XA:HandlePetIdentityChange() end
        if XelAssistActors then XelAssistActors:Invalidate() end
    end
    if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" then
        if XelAssistInventory then XelAssistInventory:Invalidate() end
        if event == "UNIT_INVENTORY_CHANGED" and XelAssistCapabilities then
            XelAssistCapabilities:InvalidateEquipment()
        end
    end
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" and XelAssistObservations then
        local outcome, outcomeTarget, outcomeSpell = XelAssistObservations:CombatMessage(arg1)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget, XA:PlayerGUID())
        end
    end
    if event == "UI_ERROR_MESSAGE" and XelAssistObservations then
        XelAssistObservations:ErrorMessage(arg1)
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
    if event == "SPELL_FAILED_OTHER" and XelAssistResistance
        and XelAssistResistance:IsOwnedCaster(arg1) then
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
        and XelAssistResistance and XelAssistResistance:IsOwnedCaster(arg3) then
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
        and XelAssistResistance and XelAssistResistance:IsOwnedCaster(arg3) then
        XA:TouchPendingSpell(arg2, "go", 2, arg3, arg4)
        if XA.petCastGuid == arg3 and tonumber(XA.petCastSpellId) == tonumber(arg2)
            and not XA.petCastChannel then
            XA:ClearPetCast(arg2, arg3)
        end
    end
    if (event == "SPELL_MISS_SELF" or event == "SPELL_MISS_OTHER")
        and XelAssistObservations and XelAssistResistance
        and XelAssistResistance:IsOwnedCaster(arg1) then
        local outcome, outcomeTarget, outcomeSpell = XelAssistObservations:SpellMiss(
            arg3, arg2, arg4, arg1)
        if outcome == "retry" or outcome == "immune" then
            XA:ClearAuraPending(outcomeSpell, outcomeTarget, arg1)
        end
    end
    if (event == "SPELL_DAMAGE_EVENT_SELF" or event == "SPELL_DAMAGE_EVENT_OTHER")
        and XelAssistObservations then
        XelAssistObservations:SpellDamage(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
    if (event == "AUTO_ATTACK_SELF" or event == "AUTO_ATTACK_OTHER")
        and XelAssistResistance then
        XelAssistResistance:AutoAttack(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    end
    if event == "AURA_CAST_ON_SELF" or event == "AURA_CAST_ON_OTHER" then
        local spellName = SpellInfo and SpellInfo(arg1) or nil
        local owned = XelAssistResistance and XelAssistResistance:IsOwnedCaster(arg2)
        local pendingKey = XA:PendingAuraKey(spellName, arg3, arg2)
        local pending = pendingKey and XA.pendingAuras and XA.pendingAuras[pendingKey]
        local buffCapped, debuffCapped = flagSet(arg9, 1), flagSet(arg9, 2)
        local expectedBar = pending and pending.auraBar
        if not expectedBar and event == "AURA_CAST_ON_SELF" then expectedBar = "buff" end
        local auraCapped = expectedBar == "buff" and buffCapped
            or expectedBar == "debuff" and debuffCapped
            or not expectedBar and (buffCapped or debuffCapped)
        local capReason = expectedBar == "buff" and "target buff bar full"
            or expectedBar == "debuff" and "target debuff bar full"
            or buffCapped and "target buff bar full" or "target debuff bar full"
        if owned and not auraCapped then
            local landed, confirmed = XelAssistResistance:AuraLanded(arg3, arg1, arg2)
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
            if XelAssistResistance.MarkApplicationUncertain then
                XelAssistResistance:MarkApplicationUncertain(arg3, arg1, arg2,
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
