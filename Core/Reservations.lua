-- Short-lived cast and aura reservations. SuperWoW identities remain opaque
-- and atomic throughout lifecycle correlation; this module never serializes or
-- presents them.
local XA = XelAssist

function XA:TargetGUID()
    local exists, guid = UnitExists("target")
    if exists then return guid end
    return nil
end

local NO_IDENTITY = {}

local function internKey(owner, registryName, first, second, third, create)
    local registry = owner[registryName]
    if not registry then
        if not create then return nil end
        registry = {}; owner[registryName] = registry
    end
    first = first == nil and NO_IDENTITY or first
    second = second == nil and NO_IDENTITY or second
    third = third == nil and NO_IDENTITY or third
    local level2 = registry[first]
    if not level2 then
        if not create then return nil end
        level2 = {}; registry[first] = level2
    end
    local level3 = level2[second]
    if not level3 then
        if not create then return nil end
        level3 = {}; level2[second] = level3
    end
    local key = level3[third]
    if not key and create then key = {}; level3[third] = key end
    return key
end

local function releaseKey(owner, registryName, first, second, third, expected)
    local registry = owner[registryName]
    if not registry then return end
    first = first == nil and NO_IDENTITY or first
    second = second == nil and NO_IDENTITY or second
    third = third == nil and NO_IDENTITY or third
    local level2 = registry[first]
    local level3 = level2 and level2[second]
    if not level3 or level3[third] ~= expected then return end
    level3[third] = nil
    if not next(level3) then level2[second] = nil end
    if not next(level2) then registry[first] = nil end
end

function XA:PendingAuraKey(name, guid, casterGuid, create)
    if not name or guid == nil then return nil end
    casterGuid = casterGuid or self:PlayerGUID()
    return internKey(self, "pendingAuraKeys", guid, casterGuid, name,
        create and true or false)
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

function XA:LifecycleKey(spellId, casterGuid, targetGuid, create)
    if not spellId then return nil end
    return internKey(self, "lifecycleKeys", casterGuid or self:PlayerGUID(),
        usableGuid(targetGuid), spellId, create and true or false)
end

function XA:Lifecycle(spellId, casterGuid, targetGuid, create)
    if not spellId then return nil end
    if type(self.spellLifecycle) ~= "table" then self.spellLifecycle = {} end
    local at, stale, existingKey, existing = GetTime(), {}, nil, nil
    for existingKey, existing in pairs(self.spellLifecycle) do
        if at - (existing.lastAt or 0) > 60 then
            table.insert(stale, { key = existingKey, record = existing })
        end
    end
    local i
    for i = 1, table.getn(stale) do
        local item = stale[i]
        self.spellLifecycle[item.key] = nil
        releaseKey(self, "lifecycleKeys", item.record.casterGuid,
            item.record.targetGuid, item.record.spellId, item.key)
    end
    casterGuid = casterGuid or self:PlayerGUID()
    targetGuid = usableGuid(targetGuid)
    local key = self:LifecycleKey(spellId, casterGuid, targetGuid, create ~= false)
    local record = self.spellLifecycle[key]
    if not record and create ~= false then
        record = { spellId = spellId, casterGuid = casterGuid, targetGuid = targetGuid }
        self.spellLifecycle[key] = record
    end
    return record
end

function XA:MarkAuraPending(name, seconds, guid, spellId, casterGuid, auraBar)
    if not name then return end
    if type(self.pendingAuras) ~= "table" then self.pendingAuras = {} end
    guid = guid or self:TargetGUID()
    casterGuid = casterGuid or self:PlayerGUID()
    local key = self:PendingAuraKey(name, guid, casterGuid, true)
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
    if record and XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance.CancelSubmission then
        XelAssist.Combat.Resistance:CancelSubmission(record.spellId,
            record.casterGuid, record.target)
    end
    if key and self.pendingAuras then self.pendingAuras[key] = nil end
    local caster, current
    for caster, current in pairs(self.currentPendingAuras or {}) do
        if current.key == key then self.currentPendingAuras[caster] = nil end
    end
    if record then
        releaseKey(self, "pendingAuraKeys", record.target, record.casterGuid,
            record.name, key)
    end
end

function XA:ClearPendingBySpell(spellId, casterGuid, targetGuid)
    local matches, _, record = {}, nil, nil
    for _, record in pairs(self.pendingAuras or {}) do
        if tonumber(record.spellId) == tonumber(spellId)
            and (not casterGuid or record.casterGuid == casterGuid)
            and (not targetGuid or record.target == targetGuid) then
            table.insert(matches, { name = record.name, target = record.target,
                casterGuid = record.casterGuid })
        end
    end
    local i
    for i = 1, table.getn(matches) do
        self:ClearAuraPending(matches[i].name, matches[i].target,
            matches[i].casterGuid)
    end
    if XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance.CancelSubmission then
        XelAssist.Combat.Resistance:CancelSubmission(spellId, casterGuid, targetGuid)
    end
end

local function uniquePendingTarget(owner, spellId, casterGuid)
    local target, matches, _, candidate = nil, 0, nil, nil
    for _, candidate in pairs(owner.pendingAuras or {}) do
        if (not spellId or tonumber(candidate.spellId) == tonumber(spellId))
            and candidate.casterGuid == casterGuid then
            matches, target = matches + 1, candidate.target
        end
    end
    if matches == 1 then return target end
    return nil
end

function XA:TouchPendingSpell(spellId, state, seconds, casterGuid, targetGuid)
    casterGuid = casterGuid or self:PlayerGUID()
    targetGuid = usableGuid(targetGuid)
    if not targetGuid then
        local current = self.currentPendingAuras and self.currentPendingAuras[casterGuid]
        if current and tonumber(current.spellId) == tonumber(spellId) then
            targetGuid = current.target
        else targetGuid = uniquePendingTarget(self, spellId, casterGuid) end
    end
    if XelAssist.Game.Pets and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:ObserveCast(
            spellId, casterGuid, targetGuid, state)
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
    if not targetGuid then targetGuid = uniquePendingTarget(self, spellId, casterGuid) end
    if spellId and XelAssist.Game.Pets
        and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:ObserveCast(
            spellId, casterGuid, targetGuid, "failed")
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
            and self:PendingAuraKey(record.name, record.target,
                record.casterGuid) == onlyKey then
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
    local found, _, record = nil, nil, nil
    for _, record in pairs(self.pendingAuras or {}) do
        if tonumber(record.spellId) == tonumber(spellId)
            and (not targetGuid or record.target == targetGuid) then
            -- The event has no caster. Never guess if player and pet both own
            -- an otherwise matching reservation.
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
    if XelAssist.Game.Pets and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:IdentityChanged(self.lastPetGuid, petGuid)
    end
    self.lastPetGuid = petGuid
end

function XA:SweepPendingAuras()
    local expired, _, record = {}, nil, nil
    local at = GetTime()
    for _, record in pairs(self.pendingAuras or {}) do
        if record.failureAt and at - record.failureAt >= 0.20
            or not record.untilAt or record.untilAt <= at then
            table.insert(expired, { name = record.name, target = record.target,
                casterGuid = record.casterGuid })
        end
    end
    local i
    for i = 1, table.getn(expired) do
        self:ClearAuraPending(expired[i].name, expired[i].target,
            expired[i].casterGuid)
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
    return key and self.pendingAuras and self.pendingAuras[key] and true or false
end
