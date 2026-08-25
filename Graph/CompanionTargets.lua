-- Shared target identity boundary for controlled-actor ambient events. Both
-- spell autocasts and ordinary swings resolve only against the hostile record
-- captured when their event was scheduled.
XelAssist.Graph.CompanionTargets = {}
local T = XelAssist.Graph.CompanionTargets
local State = XelAssist.Graph.State
local MAX_HOSTILES = 5

function T:Hostiles(state)
    local hostiles = state and state.hostiles
    if type(hostiles) ~= "table" or type(hostiles.order) ~= "table"
        or type(hostiles.byKey) ~= "table" then return nil end
    return hostiles
end

function T:ForGuid(state, guid)
    local hostiles = self:Hostiles(state)
    if not hostiles or guid == nil then return nil, nil end
    local direct = hostiles.byKey[guid]
    if direct and (direct.guid == nil or direct.guid == guid) then
        return guid, direct
    end
    local count = math.min(table.getn(hostiles.order), MAX_HOSTILES)
    local index
    for index = 1, count do
        local key = hostiles.order[index]
        local record = hostiles.byKey[key]
        if record and record.guid == guid then return key, record end
    end
    return nil, nil
end

function T:SelectedIdentity(state)
    local hostiles = self:Hostiles(state)
    if not hostiles then return state and state.targetGUID, nil, nil end
    local count = math.min(table.getn(hostiles.order), MAX_HOSTILES)
    local fallbackKey, fallback, index
    for index = 1, count do
        local key = hostiles.order[index]
        local record = hostiles.byKey[key]
        if record then
            if key == hostiles.selectedKey then
                return record.guid or key, key, record
            end
            if not fallback and record.selected == true then
                fallbackKey, fallback = key, record
            end
        end
    end
    if fallback then return fallback.guid or fallbackKey, fallbackKey, fallback end
    return nil, nil, nil
end

function T:IsSelected(state, key, record)
    local hostiles = self:Hostiles(state)
    if not hostiles then return false end
    if hostiles.selectedKey ~= nil then return key == hostiles.selectedKey end
    return record and record.selected == true
end

function T:ProvenDead(record)
    if not record then return true end
    if record.dead == true or record.projectedDefeated == true then return true end
    return record.healthExact == true and tonumber(record.health) ~= nil
        and tonumber(record.health) <= 0
end

function T:Capture(state, pet)
    if not (pet and pet.targetExists) then return nil, nil, nil end
    local hostiles = self:Hostiles(state)
    if hostiles then
        local petGuid, aliasGuid = pet.targetGuid, nil
        if type(hostiles.byUnit) == "table" then
            local aliasKey = hostiles.byUnit.pettarget
            local alias = aliasKey and hostiles.byKey[aliasKey]
            if alias then aliasGuid = alias.guid or aliasKey end
        end
        if petGuid ~= nil and aliasGuid ~= nil and petGuid ~= aliasGuid then
            return nil, nil, nil
        end
        local guid = petGuid or aliasGuid
        if guid == nil and pet.targetsCurrent == true then
            guid = self:SelectedIdentity(state)
        end
        local key, record = self:ForGuid(state, guid)
        if not key or self:ProvenDead(record) then return nil, nil, nil end
        return guid, key, true
    end
    if pet.targetsCurrent ~= true then return nil, nil, nil end
    local guid = pet.targetGuid or state.targetGUID
    if guid == nil or pet.targetGuid ~= nil and state.targetGUID ~= nil
        and pet.targetGuid ~= state.targetGUID then return nil, nil, nil end
    return guid, nil, false
end

function T:Resolve(state, entry)
    if entry.targetLocal then
        if not self:Hostiles(state) then return nil end
        local key, record = self:ForGuid(state, entry.targetGuid)
        if not key or key ~= entry.targetKey or self:ProvenDead(record) then
            return nil
        end
        record.projectedAuras = record.projectedAuras or {}
        record.threat = record.threat or { playerHasAggro = record.hasPlayerAggro,
            petHasAggro = record.hasPetAggro, playerDelta = 0, petDelta = 0 }
        local view = State.HostileContext and State:HostileContext(state, key)
        if not view then return nil end
        return view, key, record, self:IsSelected(state, key, record)
    end
    if self:Hostiles(state) or entry.targetGuid ~= state.targetGUID then return nil end
    if state.targetHealthExact and (tonumber(state.targetHealth) or 0) <= 0 then
        return nil
    end
    return state, nil, nil, true
end

function T:CandidateMatches(candidate, entry)
    if not candidate then return false end
    if entry.targetKey ~= nil and candidate.targetKey ~= nil then
        return entry.targetKey == candidate.targetKey
    end
    return entry.targetGuid ~= nil and candidate.targetGUID ~= nil
        and entry.targetGuid == candidate.targetGUID
end

function T:StillCurrent(state, pet, entry)
    if not pet.targetExists then return false end
    local guid, key = self:Capture(state, pet)
    return guid == entry.targetGuid and key == entry.targetKey
        and self:Resolve(state, entry) ~= nil
end
