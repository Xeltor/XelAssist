-- One bounded aura-name snapshot per root recipient. Graph actions share this
-- mutable observation instead of rescanning the same unit for every candidate.
XelAssist.Game.RootAuraEvidence = {}
local E = XelAssist.Game.RootAuraEvidence

local APPLICATION_KIND = { dot = true, debuff = true, crowdControl = true,
    buff = true, hot = true, absorb = true, resource = true }

local function relevant(action)
    local facts = action and action.facts or {}
    return APPLICATION_KIND[facts.kind] == true
end

local function spellName(spellId)
    spellId = tonumber(spellId)
    if not spellId or type(SpellInfo) ~= "function" then return nil, false end
    if spellId < -1 then spellId = spellId + 65536 end
    local ok, name = pcall(SpellInfo, spellId)
    if not ok or type(name) ~= "string" then return nil, false end
    return name, true
end

local function playerHelpful()
    if type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function" then return {}, false end
    local names, complete, index = {}, true, nil
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return names, false end
        if slot and slot ~= -1 then
            local idOK, spellId = pcall(GetPlayerBuffID, slot)
            if not idOK then return names, false end
            local name, resolved = spellName(spellId)
            if not resolved then complete = false end
            if name then names[name] = true end
        end
    end
    return names, complete
end

local function unitAuras(unit, helpful)
    local fn = helpful and UnitBuff or UnitDebuff
    if type(fn) ~= "function" then return {}, false end
    local names, complete, index = {}, true, nil
    for index = 1, 40 do
        local ok, texture, _, third, fourth, fifth = pcall(fn, unit, index)
        if not ok then return names, false end
        if not texture then return names, complete end
        local spellId = type(third) == "number" and third
            or type(fourth) == "number" and fourth
            or type(fifth) == "number" and fifth or nil
        local name, resolved = spellName(spellId)
        if not resolved then complete = false end
        if name then names[name] = true end
    end
    return names, complete
end

local function scan(unit, helpful)
    if helpful and unit == "player"
        and (type(GetPlayerBuff) == "function"
            or type(GetPlayerBuffID) == "function") then
        return playerHelpful()
    end
    return unitAuras(unit, helpful)
end

local function recipientKey(descriptor)
    if type(descriptor) ~= "table" then return nil end
    if descriptor.key ~= nil then return descriptor.key end
    if descriptor.guid ~= nil then return descriptor.guid end
    return descriptor.unit
end

function E:Capture(observed, action, descriptor)
    if not relevant(action) then return false, false end
    if type(observed) ~= "table" or type(descriptor) ~= "table" then
        return false, false
    end
    local hostile = descriptor.relation == "hostile"
    if hostile and descriptor.unit ~= "target" then return true, false end
    local key = recipientKey(descriptor)
    if key == nil or descriptor.unit == nil then return false, false end
    observed.auraEvidence = observed.auraEvidence or {}
    local recipient = observed.auraEvidence[key]
    if not recipient then recipient = {}; observed.auraEvidence[key] = recipient end
    local lane = hostile and "harmful" or "helpful"
    local record = recipient[lane]
    if not record then
        local names, complete = scan(descriptor.unit, not hostile)
        record = { complete = complete == true, names = names or {} }
        recipient[lane] = record
    end
    if record.names[action.name] == true then return true, true end
    return record.complete, false
end

function E:Relevant(action)
    return relevant(action)
end
