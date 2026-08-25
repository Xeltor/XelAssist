-- Graph-owned copies of the session hostile-cast ledger. Opaque identities
-- remain comparison keys only; graph branches never mutate live observations.
XelAssist.Graph.HostileCastState = {}
local C = XelAssist.Graph.HostileCastState

local function copyTable(source)
    if type(source) ~= "table" then return source end
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

local function hostileByGuid(state, guid)
    local hostiles = state and state.hostiles
    if guid == nil or type(hostiles) ~= "table"
        or type(hostiles.byKey) ~= "table" then return nil, nil end
    local i, key, record
    for i = 1, table.getn(hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey[key]
        if record and (record.guid or key) == guid then return record, key end
    end
    return nil, nil
end

local function casterLevel(state, guid, record)
    record = record or hostileByGuid(state, guid)
    local encounter = record and record.encounter
    local level = encounter and tonumber(encounter.level)
    if not level and record and record.unit and UnitLevel then
        local ok, observed = pcall(UnitLevel, record.unit)
        if ok then level = tonumber(observed) end
    end
    return level
end

local function castRecord(state, cast)
    local hostiles = state and state.hostiles
    local key = cast and cast.hostileKey
    local record = key ~= nil and hostiles and hostiles.byKey
        and hostiles.byKey[key] or nil
    if record and (record.guid or key) == cast.casterGuid then
        return record, key
    end
    record, key = hostileByGuid(state, cast and cast.casterGuid)
    if cast then cast.hostileKey = key end
    return record, key
end

local function syncRecord(state, cast, active, refresh)
    local record, key = castRecord(state, cast)
    if not record then return end
    if active then
        record.cast = cast
        record.casting = true
        record.castRemaining = math.max(0, tonumber(cast.remaining) or 0)
        record.castProbability = tonumber(cast.probability) or 1
    elseif not record.cast or record.cast.generation == cast.generation then
        record.cast = { available = true, active = false,
            generation = cast.generation, source = cast.source }
        record.casting, record.castRemaining, record.castProbability =
            false, 0, 0
    end
    if refresh ~= false and XelAssist.Graph.State
        and XelAssist.Graph.State.RefreshHostileRecord then
        XelAssist.Graph.State:RefreshHostileRecord(state, key)
    end
end

local function appendObserved(state, collection, observed)
    local cast = copyTable(observed)
    local record, key = hostileByGuid(state, cast.casterGuid)
    cast.hostileKey = key
    cast.probability = tonumber(cast.probability) or 1
    cast.remaining = math.max(0, tonumber(cast.remaining) or 0)
    local facts = XelAssist.Game.HostileSpellFacts
    local level = casterLevel(state, cast.casterGuid, record)
    if facts and facts.ForCast and level then
        cast.consequence, cast.consequenceReason = facts:ForCast(
            cast, level)
    elseif not level then cast.consequenceReason = "caster level is unavailable"
    else cast.consequenceReason = "hostile spell facts unavailable" end
    collection.byCaster[cast.casterGuid] = cast
    table.insert(collection.order, cast.casterGuid)
    syncRecord(state, cast, true, false)
end

function C:Attach(state, observedAt)
    local collection = { order = {}, byCaster = {} }
    local ledger = XelAssist.Game.HostileCasts
    local observed = ledger and ledger.Snapshot
        and ledger:Snapshot(observedAt) or {}
    local i
    for i = 1, table.getn(observed) do
        appendObserved(state, collection, observed[i])
    end
    state.hostileCasts = collection
    if XelAssist.Graph.State and XelAssist.Graph.State.SyncActiveHostile then
        XelAssist.Graph.State:SyncActiveHostile(state)
    end
    return collection
end

function C:Copy(collection, state)
    if type(collection) ~= "table" then return collection end
    local out = { order = {}, byCaster = {} }
    local i, casterGuid, cast
    for i = 1, table.getn(collection.order or {}) do
        casterGuid = collection.order[i]
        cast = collection.byCaster and collection.byCaster[casterGuid]
        if cast then
            local row = copyTable(cast)
            row.consequence = copyTable(cast.consequence)
            out.byCaster[casterGuid] = row
            table.insert(out.order, casterGuid)
            if state then syncRecord(state, row, true, false) end
        end
    end
    return out
end

function C:Find(state, casterGuid, generation)
    local collection = state and state.hostileCasts
    local cast = collection and collection.byCaster
        and collection.byCaster[casterGuid] or nil
    if cast and generation ~= nil
        and cast.generation ~= generation then return nil end
    return cast
end

function C:Advance(state, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    if elapsed <= 0 then return end
    local collection = state and state.hostileCasts
    local changed, i, cast = false, nil, nil
    for i = 1, table.getn(collection and collection.order or {}) do
        cast = collection.byCaster[collection.order[i]]
        if cast then
            cast.remaining = math.max(0,
                (tonumber(cast.remaining) or 0) - elapsed)
            syncRecord(state, cast, true, false)
            changed = true
        end
    end
    if changed and XelAssist.Graph.State
        and XelAssist.Graph.State.SyncActiveHostile then
        XelAssist.Graph.State:SyncActiveHostile(state)
    end
end

function C:Retire(state, casterGuid, generation)
    local collection = state and state.hostileCasts
    local cast = self:Find(state, casterGuid, generation)
    if not (collection and cast) then return nil end
    collection.byCaster[casterGuid] = nil
    local i
    for i = table.getn(collection.order), 1, -1 do
        if collection.order[i] == casterGuid then
            table.remove(collection.order, i)
            break
        end
    end
    syncRecord(state, cast, false)
    return cast
end

function C:SetProbability(state, casterGuid, generation, probability)
    local cast = self:Find(state, casterGuid, generation)
    if not cast then return nil end
    cast.probability = math.max(0, math.min(1,
        tonumber(probability) or 0))
    syncRecord(state, cast, cast.probability > 0.05)
    return cast
end
