-- Live evidence that an observed hostile belongs to the player's current
-- fight. Mere visibility or mouseover is never enough for off-selected casts.
XelAssist.Game.HostileEngagement = {}
local E = XelAssist.Game.HostileEngagement

local function call(fn, first, second)
    if not fn then return nil, false, nil end
    local ok, value, extra
    if second ~= nil then ok, value, extra = pcall(fn, first, second)
    elseif first ~= nil then ok, value, extra = pcall(fn, first)
    else ok, value, extra = pcall(fn) end
    if not ok then return nil, false, nil end
    return value, true, extra
end
local function identity(unit)
    local exists, ok, guid = call(UnitExists, unit)
    if not ok or not exists or exists == 0 or guid == nil or guid == ""
        or guid == "0x000000000" or guid == "0x0000000000000000" then
        return nil
    end
    return guid
end

local function truthy(fn, first, second)
    local value, ok = call(fn, first, second)
    if not ok or value == nil then return nil end
    return value and value ~= 0 and true or false
end

local function groupUnits()
    local out, raid, party, i = {}, 0, 0, nil
    local value, ok = call(GetNumRaidMembers)
    if ok then raid = math.max(0, math.min(40, tonumber(value) or 0)) end
    value, ok = call(GetNumPartyMembers)
    if ok then party = math.max(0, math.min(4, tonumber(value) or 0)) end
    if raid > 0 then
        for i = 1, raid do table.insert(out, "raid" .. i) end
    else
        for i = 1, party do table.insert(out, "party" .. i) end
    end
    return out
end

function E:ObservationContext()
    local context = { playerGuid = identity("player"),
        petGuid = identity("pet"), groupByGuid = {} }
    local units, i = groupUnits(), nil
    for i = 1, table.getn(units) do
        local guid = identity(units[i])
        if guid ~= nil then context.groupByGuid[guid] = units[i] end
    end
    return context
end

local function victim(unit, context)
    local token = unit .. "target"
    local guid = identity(token)
    if guid == nil then
        return { available = false, unit = token, guid = nil,
            targetsPlayer = nil, targetsPet = nil, targetsGroup = nil }
    end
    context = context or E:ObservationContext()
    local out = { available = true, unit = token, guid = guid,
        targetsPlayer = context.playerGuid ~= nil and guid == context.playerGuid }
    if context.petGuid then out.targetsPet = guid == context.petGuid end
    out.groupUnit = context.groupByGuid[guid]
    out.targetsGroup = out.groupUnit ~= nil and true or false
    return out
end

local function aliases(record)
    if type(record.aliasOrder) == "table"
        and table.getn(record.aliasOrder) > 0 then return record.aliasOrder end
    return record.unit and { record.unit } or {}
end

local function evidence(unit, reason, owner, observedVictim)
    return { engaged = true, unit = unit, reason = reason,
        owner = owner, victim = observedVictim }
end

function E:Observe(record, context)
    if not record then return { engaged = false, reason = "enemy unavailable" } end
    context = context or self:ObservationContext()
    if record.selected then
        return evidence("target", "selected hostile", nil,
            victim("target", context))
    end
    local observed, i = aliases(record), nil
    for i = 1, table.getn(observed) do
        local unit = observed[i]
        local currentVictim = victim(unit, context)
        if currentVictim.targetsPlayer then
            return evidence(unit, "attacking player", "player", currentVictim)
        end
        if currentVictim.targetsPet then
            return evidence(unit, "attacking companion", "pet", currentVictim)
        end
        if currentVictim.targetsGroup then
            return evidence(unit, "attacking group", currentVictim.groupUnit,
                currentVictim)
        end
    end
    return { engaged = false, reason = "active fight not proven" }
end

function E:Validate(ref)
    if type(ref) ~= "table" or ref.relation ~= "hostile"
        or ref.unit == nil or ref.guid == nil then
        return nil, "hostile identity unavailable"
    end
    local guid = identity(ref.unit)
    if guid == nil or guid ~= ref.guid then return nil, "engaged enemy changed" end
    if truthy(UnitCanAttack, "player", ref.unit) ~= true then
        return nil, "engaged unit is not hostile"
    end
    local dead = truthy(UnitIsDead, ref.unit)
    if dead == nil then return nil, "engaged enemy life state unavailable" end
    if dead then return nil, "engaged enemy defeated" end
    if ref.unit == "target" and ref.source == "selected" then
        return guid, nil, { engaged = true, unit = "target",
            reason = "selected hostile" }
    end
    local observed = self:Observe({ unit = ref.unit, aliasOrder = { ref.unit },
        guid = guid, selected = false }, self:ObservationContext())
    if not observed.engaged then
        return nil, observed.reason or "active fight no longer proven"
    end
    local finalGuid = identity(ref.unit)
    if finalGuid == nil or finalGuid ~= guid then
        return nil, "engaged enemy changed"
    end
    return guid, nil, observed
end
