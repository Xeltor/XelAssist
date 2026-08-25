-- Canonical, bounded hostile-unit observation. Only live unit tokens with an
-- exact opaque identity enter this snapshot; the graph may later consume the
-- records without treating an unavailable fact as safe or false.
XelAssist.Game.Hostiles = {}
local H = XelAssist.Game.Hostiles
local TargetSurvival = XelAssist.Game.TargetSurvival
local Engagement = XelAssist.Game.HostileEngagement

H.MAX_TARGETS = 5

local DIRECT_PROOF_UNITS = { "target", "mouseover", "pettarget" }

local SOURCE_PRIORITY = {
    selected = 1, mouseover = 2, companion = 3, raid = 4, party = 4,
}

local function call(fn, first, second, third)
    if not fn then return nil, false end
    local ok, value, extra, more
    if third ~= nil then ok, value, extra, more = pcall(fn, first, second, third)
    elseif second ~= nil then ok, value, extra, more = pcall(fn, first, second)
    elseif first ~= nil then ok, value, extra, more = pcall(fn, first)
    else ok, value, extra, more = pcall(fn) end
    if not ok then return nil, false end
    return value, true, extra, more
end

local function identity(unit)
    local exists, ok, guid = call(UnitExists, unit)
    if not ok or not exists or exists == 0 then return nil end
    if guid == nil or guid == "" or guid == "0x000000000"
        or guid == "0x0000000000000000" then return nil end
    return guid
end

local function truthy(fn, first, second)
    local value, ok = call(fn, first, second)
    if not ok then return nil end
    return value and value ~= 0 and true or false
end

local function hostile(unit)
    return truthy(UnitCanAttack, "player", unit) == true
end

local function deadState(unit)
    return truthy(UnitIsDead, unit)
end

local function sourcePriority(source)
    return SOURCE_PRIORITY[source] or 99
end

local function preferred(a, b)
    if a.sourcePriority ~= b.sourcePriority then
        return a.sourcePriority < b.sourcePriority
    end
    return a.discoveryOrder < b.discoveryOrder
end

local function locationContext()
    local inInstance, instanceOk, instanceType = call(IsInInstance)
    local zone, zoneOk = call(GetRealZoneText)
    local subZone, subZoneOk = call(GetSubZoneText)
    local minimapZone, minimapOk = call(GetMinimapZoneText)
    local instanceState
    if instanceOk then instanceState = inInstance and true or false end
    return { zone = zoneOk and zone or nil,
        subZone = subZoneOk and subZone or nil,
        minimapZone = minimapOk and minimapZone or nil,
        inInstance = instanceState,
        instanceType = instanceOk and instanceType or nil }
end

local function auraState(unit, filter)
    local encounter = XelAssist.Game.Encounter
    if not (encounter and encounter.Auras) then
        return { available = false, list = {}, byName = {} }
    end
    local observed, ok = call(encounter.Auras, encounter, unit, filter)
    if not ok or type(observed) ~= "table" then
        return { available = false, list = {}, byName = {} }
    end
    if observed.available ~= true then
        return { available = false, list = {}, byName = {} }
    end
    return observed
end

local function healthState(unit)
    local capabilities = XelAssist.Game.Capabilities
    if capabilities and capabilities.Health then
        local ok, health, maximum, exact = pcall(
            capabilities.Health, capabilities, unit)
        if ok and type(health) == "number" and type(maximum) == "number" then
            return health, maximum, exact == true, true
        end
    end
    local health, healthOk = call(UnitHealth, unit)
    local maximum, maximumOk = call(UnitHealthMax, unit)
    if healthOk and maximumOk and type(health) == "number"
        and type(maximum) == "number" then
        return health, maximum, false, true
    end
    return nil, nil, false, false
end

local function actorGeometry(from, unit)
    local capabilities = XelAssist.Game.Capabilities
    local out = { available = false, distance = nil, distanceKind = nil,
        lineOfSight = nil, behind = nil, source = nil }
    if from == "player" and capabilities and capabilities.Distance then
        local ok, distance, kind = pcall(
            capabilities.Distance, capabilities, unit)
        if ok then
            out.distance, out.distanceKind = distance, kind
            if type(distance) == "number" then out.available = true end
        end
    elseif XelAssist.Game.Actors and XelAssist.Game.Actors.Distance then
        local ok, distance, kind = pcall(
            XelAssist.Game.Actors.Distance, XelAssist.Game.Actors, from, unit)
        if ok then
            out.distance, out.distanceKind = distance, kind
            if type(distance) == "number" then out.available = true end
        end
    end
    if capabilities and capabilities.Geometry then
        local ok, geometry = pcall(
            capabilities.Geometry, capabilities, from, unit)
        if ok and type(geometry) == "table" then
            out.lineOfSight, out.behind, out.source = geometry.lineOfSight,
                geometry.behind, geometry.source
            if geometry.lineOfSight ~= nil or geometry.behind ~= nil then
                out.available = true
            end
        end
    end
    return out
end

local function castState(record)
    -- The installed 1.12 client evidence exposes no UnitCastingInfo or
    -- UnitChannelInfo. Current Nampower cast APIs describe the player, while
    -- SuperWoW's UNIT_CASTEVENT is the per-unit source. The existing runtime
    -- retains only its selected-target interval, so every other hostile stays
    -- explicitly unknown until a GUID-keyed event ledger is added.
    local cast = { available = false, active = nil,
        source = "per-hostile cast evidence unavailable" }
    local now = GetTime and GetTime() or 0
    if record.selected and XelAssist.targetCastGUID == record.guid
        and tonumber(XelAssist.targetCastUntil)
        and XelAssist.targetCastUntil > now then
        cast.available, cast.active = true, true
        cast.remaining = XelAssist.targetCastUntil - now
        cast.source = "SuperWoW selected-target cast event"
    end
    return cast
end

local function unitContext(record)
    local encounter = XelAssist.Game.Encounter
    local unitRecord
    if encounter and encounter.Unit then
        unitRecord = call(encounter.Unit, encounter, record.unit, "enemy")
    end
    local out, key, value = {}, nil, nil
    if type(unitRecord) == "table" then
        for key, value in pairs(unitRecord) do out[key] = value end
    else
        out = { id = record.unit, unit = record.unit, guid = record.guid,
            relation = "enemy", health = record.health,
            healthMax = record.healthMax, dead = record.dead }
    end
    out.guid = record.guid
    return out
end

local function enrich(record, selectedGuid, engagementContext)
    record.selected = record.guid == selectedGuid
    record.selectedExecutable = record.selected and record.dead == false
    record.health, record.healthMax, record.healthExact, record.healthAvailable =
        healthState(record.unit)
    record.survival = TargetSurvival and TargetSurvival:Observe(record.guid,
        record.health, record.healthMax, record.healthExact,
        GetTime and GetTime() or 0) or nil
    record.harmfulAuras = auraState(record.unit, "HARMFUL")
    record.helpfulAuras = auraState(record.unit, "HELPFUL")
    record.geometry = { player = actorGeometry("player", record.unit) }
    record.distance = record.geometry.player.distance
    record.distanceKind = record.geometry.player.distanceKind
    record.lineOfSight = record.geometry.player.lineOfSight
    record.behind = record.geometry.player.behind
    if engagementContext and engagementContext.petGuid then
        record.geometry.pet = actorGeometry("pet", record.unit)
    end
    if selectedGuid then
        if record.selected then
            record.geometry.selected = { available = true, distance = 0,
                distanceKind = "same unit", lineOfSight = true,
                behind = nil, source = "identity" }
        else
            record.geometry.selected = actorGeometry("target", record.unit)
        end
        record.selectedDistance = record.geometry.selected.distance
        record.selectedDistanceKind = record.geometry.selected.distanceKind
    end
    record.engagement = Engagement and Engagement:Observe(
        record, engagementContext)
        or { engaged = false, reason = "engagement capability unavailable" }
    record.engaged = record.engagement.engaged == true
    record.engagementUnit = record.engagement.unit
    record.engagedAddressable = not record.selected and record.dead == false
        and record.engaged
    record.addressable = record.selectedExecutable or record.engagedAddressable
    record.addressableSource = record.selectedExecutable
        and "selected hostile target" or record.engagedAddressable
            and record.engagement.reason or nil
    record.victim = record.engagement.victim
        or { available = false, targetsPlayer = nil, targetsPet = nil,
            targetsGroup = nil }
    record.hasPlayerAggro = record.victim.targetsPlayer
    record.hasPetAggro = record.victim.targetsPet
    record.cast = castState(record)
    record.casting = record.cast.active
    record.castRemaining = record.cast.remaining
    record.encounter = unitContext(record)
    record.reaction = record.encounter and record.encounter.reaction or nil
end

local function candidates()
    local out = {
        { unit = "target", source = "selected" },
        { unit = "mouseover", source = "mouseover" },
        { unit = "pettarget", source = "companion" },
    }
    local raidValue = call(GetNumRaidMembers)
    local partyValue = call(GetNumPartyMembers)
    local raid = tonumber(raidValue) or 0
    local party = tonumber(partyValue) or 0
    raid = math.max(0, math.min(40, raid))
    party = math.max(0, math.min(4, party))
    local count, prefix = raid > 0 and raid or party, raid > 0 and "raid" or "party"
    local i
    for i = 1, count do
        table.insert(out, { unit = prefix .. i .. "target", source = prefix })
    end
    return out
end

-- Cast transports expose opaque caster GUIDs but no trustworthy reaction.
-- Admit one only when the current unit-token snapshot, or one of the three
-- immediately addressable hostile tokens, proves that exact identity hostile.
-- The cache is bounded to retained snapshot records and is never persisted.
function H:ProvesGuid(guid)
    if guid == nil then return false end
    if self.observedGuids and self.observedGuids[guid] then return true end
    local i
    for i = 1, table.getn(DIRECT_PROOF_UNITS) do
        local unit = DIRECT_PROOF_UNITS[i]
        if identity(unit) == guid and hostile(unit) then return true end
    end
    return false
end

function H:ResetObserved()
    self.observedGuids = {}
end

function H:Snapshot()
    local working, discovery, selectedGuid = {}, {}, identity("target")
    local engagementContext = Engagement and Engagement:ObservationContext()
    local observed, i = candidates(), nil
    for i = 1, table.getn(observed) do
        local candidate = observed[i]
        local guid = identity(candidate.unit)
        local dead
        if guid then dead = deadState(candidate.unit) end
        if guid and hostile(candidate.unit) and dead ~= true then
            local record = working[guid]
            local priority = sourcePriority(candidate.source)
            if not record then
                record = { key = guid, guid = guid, unit = candidate.unit,
                    source = candidate.source, sourcePriority = priority,
                    discoveryOrder = i, dead = dead,
                    aliases = {}, aliasOrder = {}, sources = {}, aliasSources = {},
                    targetRef = { unit = candidate.unit, guid = guid,
                        relation = "hostile", source = candidate.source } }
                working[guid] = record
                table.insert(discovery, record)
            elseif priority < record.sourcePriority then
                record.unit, record.source = candidate.unit, candidate.source
                record.sourcePriority, record.discoveryOrder = priority, i
                record.targetRef.unit, record.targetRef.source =
                    candidate.unit, candidate.source
            end
            if not record.aliases[candidate.unit] then
                table.insert(record.aliasOrder, candidate.unit)
            end
            record.aliases[candidate.unit] = true
            record.sources[candidate.source] = true
            record.aliasSources[candidate.unit] = candidate.source
        end
    end
    table.sort(discovery, preferred)
    local total = table.getn(discovery)
    local snapshot = { order = {}, byKey = {}, byUnit = {}, total = total,
        capped = total > self.MAX_TARGETS, selectedKey = nil,
        -- Unit tokens are a bounded evidence set, never proof that every nearby
        -- hostile has been observed. An exhaustive provider may set this true
        -- in the future; the stock snapshot must withhold secondary AoE credit.
        discoveryComplete = false, additionalUnknown = true,
        location = locationContext() }
    local count = math.min(total, self.MAX_TARGETS)
    for i = 1, count do
        local record = discovery[i]
        enrich(record, selectedGuid, engagementContext)
        record.priority = i
        record.targetRef.priority = i
        snapshot.byKey[record.key] = record
        snapshot.order[i] = record.key
        local alias
        for alias in pairs(record.aliases) do
            snapshot.byUnit[alias] = record.key
        end
        if record.selected then snapshot.selectedKey = record.key end
    end
    self.observedGuids = {}
    for i = 1, table.getn(snapshot.order) do
        self.observedGuids[snapshot.order[i]] = true
    end
    return snapshot
end
