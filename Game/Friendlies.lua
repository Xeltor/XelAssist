-- Canonical, bounded friendly-unit state for graph target expansion. This
-- module observes live units but owns no persistence and records no unit names.
XelAssist.Game.Friendlies = {}
local F = XelAssist.Game.Friendlies

F.MAX_TARGETS = 3

local function identityField(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "key" or string.sub(lower, -4) == "guid"
end

local function deepCopy(value, atomic, seen, field)
    if type(value) ~= "table" then return value end
    if identityField(field) or atomic and atomic[value] then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        out[deepCopy(key, atomic, seen)] = deepCopy(entry, atomic, seen, key)
    end
    return out
end

local function identity(unit)
    if not UnitExists or not unit then return false, nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 then return false, nil end
    return true, guid
end

local function truthyCall(fn, first, second)
    if not fn then return false end
    local ok, result = pcall(fn, first, second)
    return ok and result and result ~= 0 and true or false
end

local function assistable(unit)
    if unit == "player" then return true end
    return truthyCall(UnitCanAssist, "player", unit)
end

local function alive(unit, actor)
    if actor and actor.dead then return false end
    if not UnitIsDead then return true end
    local ok, dead = pcall(UnitIsDead, unit)
    return ok and dead ~= true and dead ~= 1
end

local function relationFor(unit, actor)
    if unit == "player" then return "self" end
    if unit == "pet" then return "pet" end
    if string.sub(unit or "", 1, 4) == "raid" then return "raid" end
    if string.sub(unit or "", 1, 5) == "party" then return "party" end
    if actor and actor.relation and actor.relation ~= "ally" then return actor.relation end
    return "external"
end

local function healthFor(unit, actor)
    local health, maximum, exact
    if XelAssist.Game.Capabilities and XelAssist.Game.Capabilities.Health then
        local ok, observed, observedMax, observedExact =
            pcall(XelAssist.Game.Capabilities.Health, XelAssist.Game.Capabilities, unit)
        if ok then health, maximum, exact = observed, observedMax, observedExact end
    end
    if type(health) ~= "number" and UnitHealth then
        local ok, observed = pcall(UnitHealth, unit)
        if ok then health = observed end
    end
    if type(maximum) ~= "number" and UnitHealthMax then
        local ok, observed = pcall(UnitHealthMax, unit)
        if ok then maximum = observed end
    end
    if type(health) ~= "number" and actor then health = actor.health end
    if type(maximum) ~= "number" and actor then maximum = actor.healthMax end
    health, maximum = tonumber(health) or 0, tonumber(maximum) or 0
    if exact == nil and actor then exact = actor.exact or actor.healthExact end
    if exact == nil then exact = assistable(unit) end
    return health, maximum, exact and true or false
end

local function distanceFor(unit, actor)
    if unit == "player" then return 0, "self" end
    if XelAssist.Game.Capabilities and XelAssist.Game.Capabilities.Distance then
        local ok, distance, kind =
            pcall(XelAssist.Game.Capabilities.Distance, XelAssist.Game.Capabilities, unit)
        if ok and type(distance) == "number" then return distance, kind end
    end
    if actor and type(actor.distance) == "number" then
        return actor.distance, actor.distanceKind
    end
    return nil, nil
end

local function lineOfSightFor(unit, actor)
    if unit == "player" then return true end
    if XelAssist.Game.Capabilities and XelAssist.Game.Capabilities.Geometry then
        local ok, geometry =
            pcall(XelAssist.Game.Capabilities.Geometry, XelAssist.Game.Capabilities, "player", unit)
        if ok and type(geometry) == "table" then return geometry.lineOfSight end
    end
    if actor then return actor.lineOfSight end
    return nil
end

local function unknownAuras()
    return { available = false }
end

local function fallbackAuraState(unit)
    if not UnitBuff or not SpellInfo then return unknownAuras() end
    local out, i = { available = true }, nil
    for i = 1, 40 do
        local ok, texture, stacks, d3, d4, d5 = pcall(UnitBuff, unit, i)
        if not ok then return unknownAuras() end
        if not texture then break end
        local id
        if type(d3) == "number" then id = d3
        elseif type(d4) == "number" then id = d4
        elseif type(d5) == "number" then id = d5 end
        if id and id < -1 then id = id + 65536 end
        local nameOk, name = false, nil
        if id then nameOk, name = pcall(SpellInfo, id) end
        if nameOk and type(name) == "string" then
            out[name] = { name = name, spellId = id, stacks = stacks,
                applicationProbability = 1, source = "unit aura" }
        end
    end
    return out
end

local function auraState(unit)
    if not (XelAssist.Game.Encounter and XelAssist.Game.Encounter.Auras) then
        return fallbackAuraState(unit)
    end
    local ok, observed = pcall(XelAssist.Game.Encounter.Auras, XelAssist.Game.Encounter, unit, "HELPFUL")
    if not ok or type(observed) ~= "table" or observed.available ~= true then
        return fallbackAuraState(unit)
    end
    local out, name, aura = { available = true }, nil, nil
    for name, aura in pairs(observed.byName or {}) do
        if type(aura) == "table" then out[name] = deepCopy(aura) end
    end
    return out
end

local function unknownAbsorbs()
    -- Helpful aura availability does not establish absorb amounts.
    return { available = false }
end

local function targetRelation(relation)
    if relation == "self" or relation == "pet" then return relation end
    return "ally"
end

local function keyFor(unit, guid)
    if type(guid) == "string" and guid ~= "" then return "g:" .. guid end
    if guid ~= nil then return guid end
    return "u:" .. tostring(unit)
end

local function stableKey(record)
    if type(record.key) == "string" then return record.key end
    return "u:" .. tostring(record.unit or "")
end

local function missing(record)
    return math.max(0, (record.healthMax or 0) - (record.health or 0))
end

local function missingFraction(record)
    if not record.healthMax or record.healthMax <= 0 then return 0 end
    return missing(record) / record.healthMax
end

local function preferred(a, b)
    if a.explicit ~= b.explicit then return a.explicit > b.explicit end
    if a.targetedByCurrentEnemy ~= b.targetedByCurrentEnemy then
        return a.targetedByCurrentEnemy
    end
    local aFraction, bFraction = missingFraction(a), missingFraction(b)
    if aFraction ~= bFraction then return aFraction > bFraction end
    local aMissing, bMissing = missing(a), missing(b)
    if aMissing ~= bMissing then return aMissing > bMissing end
    return stableKey(a) < stableKey(b)
end

local function hostileVictim()
    local targetExists = identity("target")
    if not targetExists or not truthyCall(UnitCanAttack, "player", "target") then
        return nil, false
    end
    local victimExists, victimGuid = identity("targettarget")
    return victimGuid, victimExists
end

local function isVictim(record, victimGuid, victimExists)
    if not victimExists then return false end
    if victimGuid and record.guid then return victimGuid == record.guid end
    if not UnitIsUnit then return false end
    local unit
    for unit in pairs(record.aliases) do
        if truthyCall(UnitIsUnit, unit, "targettarget") then return true end
    end
    return false
end

local function observeAuras(record)
    if not record.auraObserved then
        record.auras, record.auraObserved = auraState(record.unit), true
    end
end

local function retainRecord(out, record, priority)
    if out.byKey[record.key] then return end
    record.priority, record.targetRef.priority = priority, priority
    out.byKey[record.key] = record
    local alias
    for alias in pairs(record.aliases) do out.byUnit[alias] = record.key end
end

local function buffPresent(record, name)
    observeAuras(record)
    if record.auras[name] then return true end
    if record.auras.available then return false end
    local capabilities = XelAssist.Game.Capabilities
    if not (capabilities and capabilities.UnitHasBuff) then return nil end
    local ok, active = pcall(capabilities.UnitHasBuff, capabilities, record.unit, name)
    if not ok then return nil end
    return active and true or false
end

local function variableBuffs()
    local out, seen, actions, i = {}, {},
        XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts and action.facts.kind == "buff"
            and action.actor ~= "pet" and action.executor ~= "item"
            and not action.facts.self and not seen[action.name] then
            seen[action.name] = true
            table.insert(out, action.name)
        end
    end
    return out
end

local function addBuffLanes(out, all)
    local names, nameIndex, candidateIndex = variableBuffs(), nil, nil
    for nameIndex = 1, table.getn(names) do
        local name, keys = names[nameIndex], {}
        out.byAction[name] = keys
        for candidateIndex = 1, table.getn(all) do
            local record = all[candidateIndex]
            if buffPresent(record, name) == false then
                retainRecord(out, record, candidateIndex)
                table.insert(keys, record.key)
                break
            end
        end
    end
end

function F:Snapshot(actors)
    local working, all = {}, {}

    local function add(unit, actor, source, explicit)
        local exists, liveGuid = identity(unit)
        if not exists or not alive(unit, actor) or not assistable(unit) then return end
        local guid = liveGuid or (actor and actor.guid)
        local key = keyFor(unit, guid)
        local record = working[key]
        if record then
            record.aliases[unit] = true
            if explicit > record.explicit then record.explicit = explicit end
            return
        end
        local health, healthMax, exact = healthFor(unit, actor)
        local distance, kind = distanceFor(unit, actor)
        local relation = relationFor(unit, actor)
        record = { key = key, unit = unit, guid = guid,
            targetRef = { key = key, unit = unit, guid = guid,
                relation = targetRelation(relation), source = source },
            relation = relation, source = source,
            health = health, healthMax = healthMax, exact = exact,
            distance = distance, kind = kind, distanceKind = kind,
            lineOfSight = lineOfSightFor(unit, actor), explicit = explicit,
            targetedByCurrentEnemy = false, aliases = { [unit] = true },
            auras = unknownAuras(), absorbs = unknownAbsorbs() }
        working[key] = record
    end

    local player = actors and actors.player or nil
    add("player", player, "self", 0)
    local pet = actors and actors.pet or nil
    add("pet", pet, "controlled", 0)
    local allies = actors and actors.allies or {}
    local i
    for i = 1, table.getn(allies) do
        local ally = allies[i]
        if type(ally) == "table" and ally.unit then
            add(ally.unit, ally, relationFor(ally.unit, ally), 0)
        end
    end
    add("target", nil, "selected", 1)
    add("mouseover", nil, "mouseover", 2)

    local victimGuid, victimExists = hostileVictim()
    local _, record
    for _, record in pairs(working) do
        record.targetedByCurrentEnemy = isVictim(record, victimGuid, victimExists)
        table.insert(all, record)
    end
    table.sort(all, preferred)

    local total = table.getn(all)
    local out = { order = {}, byKey = {}, byUnit = {}, byAction = {}, total = total,
        capped = total > self.MAX_TARGETS }
    local count = math.min(total, self.MAX_TARGETS)
    for i = 1, count do
        record = all[i]
        observeAuras(record)
        retainRecord(out, record, i)
        table.insert(out.order, record.key)
    end
    addBuffLanes(out, all)
    return out
end

function F:TargetKeys(snapshot, action)
    if action and action.facts and action.facts.kind == "buff"
        and snapshot and snapshot.byAction and snapshot.byAction[action.name] then
        return snapshot.byAction[action.name]
    end
    return snapshot and snapshot.order or {}
end

function F:Copy(snapshot)
    if type(snapshot) ~= "table" then return snapshot end
    -- SuperWoW GUIDs are opaque values and may be tables. Preserve those exact
    -- identities while copying mutable graph state around them.
    local atomic, key, record = {}, nil, nil
    for key, record in pairs(snapshot.byKey or {}) do
        if type(key) == "table" then atomic[key] = true end
        if type(record) == "table" then
            if type(record.guid) == "table" then atomic[record.guid] = true end
            if record.targetRef and type(record.targetRef.guid) == "table" then
                atomic[record.targetRef.guid] = true
            end
        end
    end
    return deepCopy(snapshot, atomic, {})
end
