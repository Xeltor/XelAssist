-- Causal clocks for auras created or replaced by timeline events. Hostile
-- collections are keyed by opaque identity so same-named effects on different
-- enemies never share cadence, damage, or expiration state.
XelAssist.Graph.EventAuras = {}
local A = XelAssist.Graph.EventAuras
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects

local MAX_HOSTILES = 5
local LOCAL = {}
local SCHEDULES = setmetatable({}, { __mode = "k" })

local function scheduleFor(state)
    local schedule = SCHEDULES[state]
    if not schedule and state and type(state.hostiles) == "table" then
        schedule = SCHEDULES[state.hostiles]
    end
    return schedule
end

local function scheduleBranch(state, key, guid, create)
    local schedule = scheduleFor(state)
    if not schedule then return nil end
    local branch
    if key == nil then branch = schedule.localTarget
    else branch = schedule.byKey[key] end
    if branch and branch.guid ~= guid then branch = nil end
    if not branch and create then
        branch = { guid = guid, byName = {} }
        if key == nil then schedule.localTarget = branch
        else schedule.byKey[key] = branch end
    end
    return branch
end

function A:BeginScheduled(state)
    local schedule = { byKey = {} }
    SCHEDULES[state] = schedule
    if state and type(state.hostiles) == "table" then
        SCHEDULES[state.hostiles] = schedule
    end
end

function A:ScheduledToken(state, key, guid, name, aura)
    local branch = scheduleBranch(state, key, guid, true)
    if not branch then return nil end
    local token = branch.byName[name]
    if not token then token = { scale = 1 }; branch.byName[name] = token end
    if aura then aura.periodicExternalToken = token end
    return token
end

function A:InvalidateScheduled(state, key, guid, name)
    local branch = scheduleBranch(state, key, guid, false)
    if branch then branch.byName[name] = nil end
end

function A:ScheduledCurrent(state, key, guid, name, token)
    local branch = scheduleBranch(state, key, guid, false)
    return branch ~= nil and branch.byName[name] == token
end

function A:ScaleScheduled(state, key, guid, name, scale)
    local branch = scheduleBranch(state, key, guid, false)
    local token = branch and branch.byName[name]
    if token then token.scale = (tonumber(token.scale) or 1) * scale end
end

function A:ScheduledScale(token)
    return token and (tonumber(token.scale) or 1) or 1
end

local function hostilesOf(state)
    local hostiles = state and state.hostiles
    if type(hostiles) ~= "table" or type(hostiles.order) ~= "table"
        or type(hostiles.byKey) ~= "table" then return nil end
    return hostiles
end

local function stateIdentity(state)
    local hostiles = hostilesOf(state)
    local key = state and state.targetContextKey
        or hostiles and hostiles.selectedKey or nil
    local record = hostiles and key ~= nil and hostiles.byKey[key] or nil
    local guid = record and (record.guid or key) or state and state.targetGUID
    return key, guid
end

function A:InvalidateStateAura(state, name)
    local key, guid = stateIdentity(state)
    self:InvalidateScheduled(state, key, guid, name)
end

function A:ScaleStateAura(state, name, scale)
    local key, guid = stateIdentity(state)
    self:ScaleScheduled(state, key, guid, name, scale)
end

local function scaleClock(aura, scale)
    if type(aura) ~= "table" then return nil end
    aura.periodicRate = math.max(0, tonumber(aura.periodicRate) or 0) * scale
    aura.applicationProbability = (tonumber(
        aura.applicationProbability) or 1) * scale
    return aura
end

function A:ScaleAuraTree(aura, scale)
    if type(aura) ~= "table" then return end
    scaleClock(aura, scale)
    local i
    for i = 1, table.getn(aura.periodicBranches or {}) do
        scaleClock(aura.periodicBranches[i], scale)
    end
end

local function failureBranches(prior, scale)
    if type(prior) ~= "table" or scale <= 0 then return nil end
    local nested, branches = prior.periodicBranches, {}
    prior.periodicBranches = nil
    table.insert(branches, scaleClock(prior, scale))
    local i
    for i = 1, table.getn(nested or {}) do
        table.insert(branches, scaleClock(nested[i], scale))
    end
    return branches
end

function A:ReplaceScheduledAura(state, key, guid, name, delivery, prior)
    delivery = math.max(0, math.min(1, tonumber(delivery) or 1))
    if delivery >= 1 then
        self:InvalidateScheduled(state, key, guid, name)
        return nil
    end
    local failure = 1 - delivery
    self:ScaleScheduled(state, key, guid, name, failure)
    return failureBranches(prior, failure)
end

function A:ReplaceStateAura(state, name, delivery, prior)
    local key, guid = stateIdentity(state)
    return self:ReplaceScheduledAura(
        state, key, guid, name, delivery, prior)
end

local function activeAt(aura, offset)
    if type(aura) ~= "table" then return nil end
    local remaining = tonumber(aura.remaining)
    if remaining ~= nil and remaining <= offset then return nil end
    return aura
end

function A:PriorStacks(prior, source, name, offset)
    local projected = activeAt(source and source.auras
        and source.auras[name], offset)
    local live = activeAt(source and source.targetAuras
        and source.targetAuras[name], offset)
    return math.max(type(prior) == "table" and (prior.expectedStacks
            or prior.stacks or 0) or 0,
        projected and (projected.expectedStacks or projected.stacks or 0) or 0,
        live and (live.expectedStacks or live.stacks or 1) or 0)
end

local function selected(state, key, record)
    local hostiles = hostilesOf(state)
    if not hostiles then return false end
    if hostiles.selectedKey ~= nil then return hostiles.selectedKey == key end
    return record and record.selected == true
end

local function syncSelected(state, key, record, changed)
    if not changed or not selected(state, key, record) then return end
    if State.SyncSelectedHostile then State:SyncSelectedHostile(state) end
    local threat = record and record.threat
    if threat and threat.projectedPlayerHasAggro ~= nil then
        state.hasAggro = threat.projectedPlayerHasAggro
    end
    if threat and threat.projectedPetHasAggro ~= nil
        and state.actors and state.actors.pet then
        state.actors.pet.hasAggro = threat.projectedPetHasAggro
    end
    if record.dead == true and state.autoShot then state.autoShot.active = false end
end

function A:ApplyPeriodicThreat(record, aura, dealt)
    local actor = aura and aura.periodicThreatActor
    local multiplier = aura and tonumber(aura.periodicThreatMultiplier)
    if not (record and actor and multiplier and dealt > 0) then return end
    local amount = dealt * multiplier
    record.projectedThreat = record.projectedThreat or {}
    record.projectedThreat[actor] =
        (tonumber(record.projectedThreat[actor]) or 0) + amount
    record.threat = record.threat or {}
    local field = actor == "pet" and "petDelta" or "playerDelta"
    record.threat[field] = (tonumber(record.threat[field]) or 0) + amount
end

function A:Damage(aura, state, span)
    if not span or span <= 0 then return 0 end
    if not (state and aura.periodicRawRate and aura.periodicAction
        and XelAssist.Combat.Resistance) then
        return math.max(0, aura.periodicRate or 0) * span
    end
    local conditional = Effects:OverWindow(aura.periodicAction, "target",
        aura.periodicTooltip or {}, state, 0, span, "periodic", true)
    if not conditional then
        return math.max(0, aura.periodicRate or 0) * span
    end
    return math.max(0, aura.periodicRawRate) * span
        * (tonumber(aura.applicationProbability) or 1) * conditional
end

function A:Snapshot(state)
    local snapshot, hostiles = {}, hostilesOf(state)
    if not hostiles then
        local name, aura
        for name, aura in pairs(state.auras or {}) do snapshot[name] = aura end
        return snapshot
    end
    local bucket = { byKey = {} }
    snapshot[LOCAL] = bucket
    local i, count = nil, math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key, record, refs = hostiles.order[i], nil, {}
        record = hostiles.byKey[key]
        if record then
            local name, aura
            for name, aura in pairs(record.projectedAuras or {}) do
                refs[name] = aura
            end
            bucket.byKey[key] = refs
        end
    end
    return snapshot
end

function A:Track(state, before, tracked)
    local hostiles = hostilesOf(state)
    if not hostiles then
        local name, aura
        for name, aura in pairs(state.auras or {}) do
            if before[name] ~= aura then tracked[name] = aura end
        end
        for name, aura in pairs(tracked) do
            if not state.auras or state.auras[name] ~= aura then
                tracked[name] = nil
            end
        end
        return
    end
    local prior = before[LOCAL] or { byKey = {} }
    local bucket = tracked[LOCAL]
    if not bucket then bucket = { byKey = {} }; tracked[LOCAL] = bucket end
    local seen, i, count = {}, nil,
        math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key, record = hostiles.order[i], nil
        record, seen[key] = hostiles.byKey[key], true
        if record then
            local current = record.projectedAuras or {}
            local old = prior.byKey[key] or {}
            local target = bucket.byKey[key]
            local name, aura
            for name, aura in pairs(current) do
                if old[name] ~= aura then
                    if not target then target = {}; bucket.byKey[key] = target end
                    target[name] = aura
                end
            end
            for name, aura in pairs(target or {}) do
                if current[name] ~= aura then target[name] = nil end
            end
        end
    end
    local key
    for key in pairs(bucket.byKey) do
        if not seen[key] then bucket.byKey[key] = nil end
    end
end

local function advanceClock(aura, elapsed)
    if type(aura) ~= "table" or aura.remaining == nil then
        return 0, false, true
    end
    local active = math.min(aura.remaining, elapsed)
    local interval = tonumber(aura.periodicInterval)
    local nextTick = tonumber(aura.periodicNextIn)
    local damageSpan = active
    if interval and interval > 0 and nextTick then
        local ticks = 0
        while nextTick <= active do
            nextTick, ticks = nextTick + interval, ticks + 1
        end
        aura.periodicNextIn = math.max(0, nextTick - active)
        damageSpan = ticks * interval
    end
    aura.remaining = math.max(0, aura.remaining - elapsed)
    return damageSpan, active > 0, aura.remaining > 0
end

function A:AgeBranches(aura, elapsed)
    local branches = type(aura) == "table" and aura.periodicBranches
    local i
    for i = table.getn(branches or {}), 1, -1 do
        local _, _, alive = advanceClock(branches[i], elapsed)
        if not alive then table.remove(branches, i) end
    end
end

function A:PromoteBranch(aura)
    local branches = type(aura) == "table" and aura.periodicBranches
    if table.getn(branches or {}) <= 0 then return false end
    local promoted = table.remove(branches, 1)
    local key
    for key in pairs(aura) do aura[key] = nil end
    for key in pairs(promoted) do aura[key] = promoted[key] end
    if table.getn(branches) > 0 then aura.periodicBranches = branches end
    return true
end

local function applyDamage(self, aura, view, span, record, health, exact)
    if span <= 0 or not aura.periodicRate or not exact
        or not health or health <= 0 then return health end
    local beforeHealth = health
    health = math.max(0, health - self:Damage(aura, view, span))
    self:ApplyPeriodicThreat(record, aura, beforeHealth - health)
    return health
end

local function advanceSet(self, state, tracked, elapsed, key, record)
    local auras
    if record then auras = record.projectedAuras
    else auras = state.auras end
    local view = key ~= nil and State.HostileContext
        and State:HostileContext(state, key) or state
    if not view then return end
    local exact = record and record.healthExact == true
        or not record and state.targetHealthExact == true
    local health
    if record then health = tonumber(record.health)
    else health = tonumber(state.targetHealth) end
    local guid = record and (record.guid or key) or state.targetGUID
    local changed, name, aura = false, nil, nil
    for name, aura in pairs(tracked or {}) do
        if not auras or auras[name] ~= aura then
            tracked[name] = nil
        elseif type(aura) == "table" and aura.remaining then
            local span, progressed, alive = advanceClock(aura, elapsed)
            health = applyDamage(self, aura, view, span, record, health, exact)
            local branches, i = aura.periodicBranches, nil
            for i = table.getn(branches or {}), 1, -1 do
                local branch = branches[i]
                local external = branch.periodicExternalToken
                    and self:ScheduledCurrent(state, key, guid, name,
                        branch.periodicExternalToken)
                if not external then
                    branch.periodicExternalToken = nil
                    local branchSpan, branchProgressed, branchAlive =
                        advanceClock(branch, elapsed)
                    health = applyDamage(self, branch, view, branchSpan,
                        record, health, exact)
                    progressed = branchProgressed or progressed
                    if not branchAlive then table.remove(branches, i) end
                end
            end
            if not alive and not self:PromoteBranch(aura) then
                if aura.targetModifier then
                    Effects:RemoveTargetModifier(view, name)
                end
                auras[name], tracked[name] = nil, nil
                changed = true
            end
            changed = progressed or changed
        end
    end
    if record then
        record.health, view.targetHealth = health, health
        if exact and health and health <= 0 then
            record.dead, record.projectedDefeated = true, true
        end
    else
        state.targetHealth = health
        if exact and health and health <= 0 then
            state.hostile = false
            if state.autoShot then state.autoShot.active = false end
        end
    end
    if record then syncSelected(state, key, record, changed) end
end

function A:Advance(state, tracked, elapsed)
    if not elapsed or elapsed <= 0 then return end
    local hostiles = hostilesOf(state)
    if not hostiles then advanceSet(self, state, tracked, elapsed) return end
    local bucket = tracked and tracked[LOCAL]
    if not bucket then return end
    local i, count = nil, math.min(table.getn(hostiles.order), MAX_HOSTILES)
    for i = 1, count do
        local key, record = hostiles.order[i], nil
        record = hostiles.byKey[key]
        if record and bucket.byKey[key] then
            advanceSet(self, state, bucket.byKey[key], elapsed, key, record)
        end
    end
end
