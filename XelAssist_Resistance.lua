-- Target resistance knowledge is learned evidence, not a creature rotation table.
-- Turtle's UnitResistance target values are preferred when their availability
-- is proven. Exact Nampower outcomes provide the normal learned fallback.
XelAssistResistance = { schema = 4, maxProfiles = 256, identities = {},
    sessionProfiles = {}, spellSchools = {}, spellMetadata = {}, numericEvidence = {},
    submissions = {}, recentSubmissions = {}, ownedCasters = {},
    unitResistanceProven = false, nampowerResistanceProven = false }
local R = XelAssistResistance

local SCHOOL_NAMES = { [0] = "Physical", [1] = "Holy", [2] = "Fire", [3] = "Nature",
    [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }
local PROFILE_PRIOR, LAND_PRIOR = 3, 4
local PROFILE_HALF_LIFE = 30 * 24 * 60 * 60
local BEAST_LORE_SPELL_ID = 1462
local BINARY_AURAS = { [7] = true, [12] = true, [14] = true, [22] = true,
    [25] = true, [26] = true, [27] = true, [33] = true, [67] = true }
local PERIODIC_DAMAGE_AURAS = { [3] = true, [53] = true, [89] = true }

local function now() return GetTime and GetTime() or 0 end
local function epoch() return time and time() or now() end
local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end
local function truncate(value)
    value = tonumber(value) or 0
    if value < 0 then return math.ceil(value) end
    return math.floor(value)
end
local function hasFlag(value, flag)
    value, flag = tonumber(value) or 0, tonumber(flag) or 1
    return math.floor(value / flag) - math.floor(value / (flag * 2)) * 2 == 1
end
local function call(fn, value)
    if not fn then return nil end
    local ok, result = pcall(fn, value)
    if ok then return result end
    return nil
end
local function guidFor(unit)
    if not UnitExists or not unit then return nil end
    local exists, guid = UnitExists(unit)
    if exists then return guid end
    return nil
end
local function dbc(spellId, field, array)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value
    if array then ok, value = pcall(GetSpellRecField, spellId, field, 1)
    else ok, value = pcall(GetSpellRecField, spellId, field) end
    if ok then return value end
    return nil
end

-- Delivery and mitigation are independent axes. The server chooses the
-- ordinary hit table from Spell.dbc DmgClass (with the normal-ranged wand
-- exception), never from damage school. Only an explicit semantic override
-- outranks DBC; range-oriented `melee`/`ranged` catalogue hints are fallbacks
-- when the row is unavailable.
local function deliveryModelFor(facts, metadata)
    facts, metadata = facts or {}, metadata or {}
    if facts.deliveryModel == "physical" or facts.deliveryModel == "magic"
        or facts.deliveryModel == "none" then
        return facts.deliveryModel, true, "action semantics"
    end
    if metadata.deliveryModel == "physical" or metadata.deliveryModel == "magic"
        or metadata.deliveryModel == "none" then
        return metadata.deliveryModel, metadata.deliveryModelKnown ~= false,
            metadata.deliveryModelSource or "client DBC"
    end
    if facts.whiteAttack then return "physical", true, "white attack" end
    if facts.weaponRanged or facts.melee then
        return "physical", false, "catalogue delivery fallback"
    end
    return "unknown", false, "delivery class unavailable"
end

local function deliverySubtypeFor(facts, metadata, model)
    facts, metadata = facts or {}, metadata or {}
    if model ~= "physical" then return nil end
    return facts.deliverySubtype or metadata.deliverySubtype
        or facts.weaponRanged and "ranged" or facts.melee and "melee" or "unknown"
end

function R:SchoolName(school)
    return SCHOOL_NAMES[tonumber(school)] or "Unknown"
end

function R:Store()
    if type(XelAssistDB) ~= "table" then XelAssistDB = {} end
    local store = XelAssistDB.resistanceKnowledge
    if type(store) ~= "table" or store.schema ~= self.schema then
        store = { schema = self.schema, profiles = {} }
        XelAssistDB.resistanceKnowledge = store
    end
    if type(store.profiles) ~= "table" then store.profiles = {} end
    return store
end

function R:PruneProfiles()
    local profiles = self:Store().profiles
    local count, key = 0, nil
    for key in pairs(profiles) do count = count + 1 end
    while count > self.maxProfiles do
        local oldestKey, oldestAt, profile = nil, nil, nil
        for key, profile in pairs(profiles) do
            local seen = tonumber(profile.lastSeen) or 0
            if not oldestAt or seen < oldestAt then oldestKey, oldestAt = key, seen end
        end
        if not oldestKey then break end
        profiles[oldestKey], count = nil, count - 1
    end
end

function R:Identity(unit, encounter)
    local guid = guidFor(unit)
    if not guid then return nil end
    local record
    if encounter and encounter.target and encounter.target.guid == guid then record = encounter.target end
    if not record and XelAssistEncounter then record = XelAssistEncounter:Unit(unit, "enemy") end
    record = record or {}
    local creatureId = tonumber(record.creatureId or call(UnitCreatureID, unit))
    if creatureId == 0 then creatureId = nil end
    local level = tonumber(record.level or (UnitLevel and UnitLevel(unit)))
    local isPlayer = record.isPlayer
    if isPlayer == nil and UnitIsPlayer then isPlayer = UnitIsPlayer(unit) and true or false end
    local identity = { guid = guid, creatureId = creatureId, level = level,
        instanceType = encounter and encounter.instanceType, isPlayer = isPlayer and true or false }
    if creatureId and not identity.isPlayer then
        identity.profileKey = "npc:" .. tostring(creatureId) .. ":l" .. tostring(level or 0)
            .. ":" .. tostring(identity.instanceType or "world")
    end
    self.identities[guid] = identity
    return identity
end

function R:RememberUnit(unit, encounter)
    local guid = guidFor(unit)
    if not encounter and guid and self.identities[guid] then return self.identities[guid] end
    return self:Identity(unit, encounter)
end

local function normalizeVector(values)
    if type(values) ~= "table" then return nil end
    local zeroBased, out, found, school = values[0] ~= nil, {}, false, nil
    for school = 0, 6 do
        local value = tonumber(zeroBased and values[school] or values[school + 1])
        if value then
            if value >= 2147483648 then value = value - 4294967296 end
            if school == 0 and value < 0 then value = 0 end
            out[school], found = value, true
        end
    end
    if found then return out end
    return nil
end

function R:NampowerVector(unit)
    if not GetUnitField or not unit or not guidFor(unit) then return nil end
    local ok, values = pcall(GetUnitField, unit, "resistances", 1)
    if not ok then return nil end
    return normalizeVector(values)
end

function R:UnitResistanceVector(unit)
    if not UnitResistance or not unit or not guidFor(unit) then return nil end
    local values, details, school = {}, {}, nil
    for school = 0, 6 do
        local ok, base, effective, positive, negative = pcall(UnitResistance, unit, school)
        if not ok or type(effective) ~= "number" then return nil end
        values[school] = school == 0 and math.max(0, effective) or effective
        details[school] = { base = tonumber(base), effective = effective,
            positive = tonumber(positive), negative = tonumber(negative) }
    end
    return values, details
end

function R:OwnSpecialInfo(encounter)
    local auras = encounter and encounter.targetHarmful and encounter.targetHarmful.list
    if type(auras) ~= "table" then return false end
    local i
    for i = 1, table.getn(auras) do
        local aura = auras[i]
        if aura and aura.mine == true and (tonumber(aura.spellId) == BEAST_LORE_SPELL_ID
            or aura.name == "Beast Lore") then return true end
    end
    return false
end

-- Turtle exposes target UnitResistance and MobStats relies on that contract.
-- A positive hostile Armor value proves the call returned target data. An
-- all-zero vector remains unproven unless our own Beast Lore grants visibility.
function R:LiveVector(unit, encounter)
    local vector, details = self:UnitResistanceVector(unit)
    local special = self:OwnSpecialInfo(encounter)
    if vector and vector[0] > 0 then self.unitResistanceProven = true end
    if vector and (self.unitResistanceProven or special) then
        return vector, details, special and "Turtle UnitResistance + player Beast Lore"
            or "Turtle UnitResistance target data", true
    end
    local raw = self:NampowerVector(unit)
    if raw and raw[0] > 0 then self.nampowerResistanceProven = true end
    if raw and (self.nampowerResistanceProven or special) then
        return raw, nil, special and "Nampower field + player Beast Lore"
            or "Nampower target field", true
    end
    return nil, details, vector and "all-zero target field not proven"
        or "hostile target field unavailable", false
end

function R:Snapshot(unit, encounter)
    local identity = self:Identity(unit, encounter)
    if not identity then return nil end
    local penetration = XelAssistCapabilities and XelAssistCapabilities.Penetration
        and XelAssistCapabilities:Penetration() or { spell = nil, armor = nil, known = false }
    local live, details, source, trusted = self:LiveVector(unit, encounter)
    if live and identity.profileKey then
        local profile = self:Profile(identity, true)
        if type(profile.raw) ~= "table" then profile.raw = {} end
        local school
        for school = 0, 6 do
            local previous = profile.raw[school]
            local detail = details and details[school]
            local base = detail and tonumber(detail.base)
            profile.raw[school] = { value = base ~= nil and base or live[school],
                effective = live[school], kind = base ~= nil and "base" or "effective",
                lastSeen = epoch(),
                samples = math.min(64, ((previous and previous.samples) or 0) + 1), source = source }
        end
        profile.lastSeen = epoch()
    end
    return { identity = identity, live = live, liveDetails = details,
        liveTrusted = trusted, liveSource = source, penetration = penetration }
end

function R:Profile(identity, create)
    if not identity then return nil end
    local profiles, key
    if identity.profileKey then profiles, key = self:Store().profiles, identity.profileKey
    else profiles, key = self.sessionProfiles, identity.guid end
    if not key then return nil end
    local profile = profiles[key]
    if not profile and create then
        profile = { schema = self.schema, creatureId = identity.creatureId,
            level = identity.level, instanceType = identity.instanceType, lastSeen = epoch(),
            raw = {}, schools = {}, contexts = {}, deliveryContexts = {},
            spellDeliveryContexts = {}, spells = {}, inferredRawContexts = {} }
        profiles[key] = profile
        if identity.profileKey then self:PruneProfiles() end
    end
    return profile
end

local function trimRecord(record)
    if (record.samples or 0) < 64 and (record.landSamples or 0) < 64 then return end
    local factor = 0.75
    record.samples = (record.samples or 0) * factor
    record.delivered = (record.delivered or 0) * factor
    record.full = (record.full or 0) * factor
    record.partial = (record.partial or 0) * factor
    record.landSamples = (record.landSamples or 0) * factor
    record.landHits = (record.landHits or 0) * factor
    record.resistMisses = (record.resistMisses or 0) * factor
    record.ordinaryMisses = (record.ordinaryMisses or 0) * factor
    record.resistanceRejects = (record.resistanceRejects or 0) * factor
end

local function updateRecord(record, delivered, weight, landEvidence)
    trimRecord(record)
    weight = tonumber(weight) or 1
    if delivered ~= nil then
        delivered = clamp(delivered, 0, 1.75)
        record.samples = (record.samples or 0) + weight
        record.delivered = (record.delivered or 0) + delivered * weight
        if delivered <= 0 then record.full = (record.full or 0) + weight
        elseif delivered < 0.999 then record.partial = (record.partial or 0) + weight end
    end
    if landEvidence == true or landEvidence == "hit" then
        record.landSamples = (record.landSamples or 0) + weight
        record.landHits = (record.landHits or 0) + weight
    elseif landEvidence == false or landEvidence == "resistance-reject" then
        record.landSamples = (record.landSamples or 0) + weight
        record.resistMisses = (record.resistMisses or 0) + weight
        record.resistanceRejects = (record.resistanceRejects or 0) + weight
    elseif landEvidence == "ordinary-miss" then
        record.ordinaryMisses = (record.ordinaryMisses or 0) + weight
    end
    record.lastSeen = epoch()
end

local function trimDelivery(record)
    if (record.samples or 0) < 64 then return end
    record.samples = (record.samples or 0) * 0.75
    record.hits = (record.hits or 0) * 0.75
    record.misses = (record.misses or 0) * 0.75
end

local function updateDelivery(record, evidence, weight)
    if evidence ~= true and evidence ~= "hit" and evidence ~= "ordinary-miss" then return end
    trimDelivery(record)
    weight = tonumber(weight) or 1
    record.samples = (record.samples or 0) + weight
    if evidence == true or evidence == "hit" then
        record.hits = (record.hits or 0) + weight
    else
        record.misses = (record.misses or 0) + weight
    end
    record.lastSeen = epoch()
end

local function deliveryKey(context)
    local prefix = ""
    if context and context.deliveryModel == "physical" then
        prefix = "physical-" .. tostring(context.deliverySubtype or "unknown") .. ":"
    end
    return prefix .. tostring(context and (context.deliveryKey or context.key) or "unknown")
end

local function updateProfileDelivery(profile, spellId, context, evidence, weight)
    if not profile or (evidence ~= true and evidence ~= "hit"
        and evidence ~= "ordinary-miss") then return end
    local model = context and context.deliveryModel
    if model == "none" or model == "unknown"
        or context and context.deliveryModelKnown == false and model ~= "physical" then return end
    if type(profile.deliveryContexts) ~= "table" then profile.deliveryContexts = {} end
    local key = deliveryKey(context)
    local shared = profile.deliveryContexts[key] or {}
    updateDelivery(shared, evidence, weight)
    profile.deliveryContexts[key] = shared
    if spellId then
        if type(profile.spellDeliveryContexts) ~= "table" then
            profile.spellDeliveryContexts = {}
        end
        local spellKey = tostring(spellId) .. ":" .. key
        local specific = profile.spellDeliveryContexts[spellKey] or {}
        updateDelivery(specific, evidence, weight)
        profile.spellDeliveryContexts[spellKey] = specific
    end
end

function R:CasterContext(casterGuid, school, state, action, targetGuid)
    local actor = action and action.facts and action.facts.damageActor or action and action.actor
    if not actor and casterGuid then
        if casterGuid == guidFor("pet") then actor = "pet"
        elseif casterGuid == guidFor("player") then actor = "player" end
    end
    local owned = casterGuid and self.ownedCasters[casterGuid]
    if not actor and type(owned) == "table" then actor = owned.actor end
    actor = actor or "player"
    local level
    if actor == "pet" then
        level = state and state.actors and state.actors.pet and state.actors.pet.level
            or type(owned) == "table" and owned.level
            or casterGuid == guidFor("pet") and UnitLevel and UnitLevel("pet")
    else level = state and state.playerLevel or (UnitLevel and UnitLevel("player")) end
    local penetration, known = nil, false
    if actor == "player" then
        local values = state and state.targetResistance and state.targetResistance.penetration
        if not values and XelAssistCapabilities and XelAssistCapabilities.Penetration then
            values = XelAssistCapabilities:Penetration()
        end
        if values then
            penetration = school == 0 and values.armor or values.spell
            known = values.known == true and penetration ~= nil
        end
    end
    local rounded = known and math.floor((tonumber(penetration) or 0) / 5 + 0.5) * 5
    local behind, positionSource
    if state then
        if actor == "pet" then
            behind = state.actors and state.actors.pet and state.actors.pet.behind
        else behind = state.playerBehindTarget end
        if type(behind) == "boolean" then positionSource = "state UnitXP geometry" end
    end
    if type(behind) ~= "boolean" and targetGuid
        and targetGuid == guidFor("target") and XelAssistCapabilities
        and XelAssistCapabilities.Geometry then
        local unit = actor == "pet" and "pet" or "player"
        local ok, geometry = pcall(XelAssistCapabilities.Geometry,
            XelAssistCapabilities, unit, "target")
        if ok and type(geometry) == "table" and type(geometry.behind) == "boolean" then
            behind, positionSource = geometry.behind, geometry.source or "live geometry"
        end
    end
    return { actor = actor, level = tonumber(level), penetration = tonumber(penetration),
        behindTarget = behind, positionKnown = type(behind) == "boolean",
        positionSource = positionSource or "position unavailable",
        penetrationKnown = known, key = actor .. ":l" .. tostring(level or 0)
            .. ":p" .. (rounded and tostring(rounded) or "?") }
end

function R:PhaseContext(context, phase)
    return { actor = context.actor, level = context.level, penetration = context.penetration,
        penetrationKnown = context.penetrationKnown, deliveryModel = context.deliveryModel,
        deliveryModelKnown = context.deliveryModelKnown,
        deliveryModelSource = context.deliveryModelSource,
        deliverySubtype = context.deliverySubtype, deliveryCombined = context.deliveryCombined,
        deliveryKey = tostring(context.deliveryKey or context.key) .. ":" .. tostring(phase),
        modifierReduction = context.modifierReduction,
        phase = phase,
        key = tostring(context.key) .. ":" .. tostring(phase) }
end

local function modifierToken(value)
    value = tonumber(value) or 0
    if math.abs(value) < 0.0001 then return nil end
    local scaled
    if value < 0 then scaled = math.ceil(value * 100 - 0.5)
    else scaled = math.floor(value * 100 + 0.5) end
    local rounded = scaled / 100
    if rounded == math.floor(rounded) then rounded = math.floor(rounded) end
    return tostring(rounded)
end

-- Resistance-changing target auras affect landed-hit mitigation (and binary
-- delivery) but not the caster's ordinary hit table. Keep the modifier state in
-- the evidence key while retaining an unmodified deliveryKey for hit learning.
function R:ModifierContext(context, reduction)
    local token = modifierToken(reduction)
    if not token then return context end
    return { actor = context.actor, level = context.level,
        penetration = context.penetration, penetrationKnown = context.penetrationKnown,
        deliveryModel = context.deliveryModel,
        deliveryModelKnown = context.deliveryModelKnown,
        deliveryModelSource = context.deliveryModelSource,
        deliverySubtype = context.deliverySubtype,
        deliveryCombined = context.deliveryCombined,
        deliveryKey = context.deliveryKey or context.key,
        modifierReduction = tonumber(reduction) or 0,
        key = tostring(context.key) .. ":r" .. token }
end

function R:ActiveResistanceReduction(targetGuid, school)
    if not (targetGuid and school and XelAssistGraph
        and XelAssistGraph.ActiveTargetModifiers and XelAssistEncounter
        and XelAssistEncounter.Snapshot) then return 0, false end
    local encounter = XelAssistEncounter:Snapshot()
    if not (encounter and encounter.target and encounter.target.guid == targetGuid) then
        return 0, false
    end
    local reductions = XelAssistGraph:ActiveTargetModifiers(encounter, nil)
    return reductions and tonumber(reductions[school]) or 0, true
end

-- Dynamic damage schools are only reusable while the source that produced the
-- observation is unchanged. The context is session-only and deliberately uses
-- stable IDs/links rather than player, pet, or item names.
function R:DynamicContext(source)
    if source == "equippedWand" then
        if not GetInventoryItemLink then return nil end
        local ok, link = pcall(GetInventoryItemLink, "player", 18)
        return ok and link and source .. ":" .. tostring(link) or nil
    elseif source == "activeSeal" then
        if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end
        local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
        if not ok or type(list) ~= "table" then return nil end
        local i
        for i = 1, table.getn(list) do
            local aura = list[i]
            local name = aura and aura.name and string.lower(aura.name)
            if name and string.find(name, "seal of ", 1, true) == 1 then
                return source .. ":" .. tostring(aura.spellId or aura.name)
            end
        end
        return nil
    elseif source == "petResult" then
        local guid = guidFor("pet")
        return guid and source .. ":" .. tostring(guid) or nil
    end
    return nil
end

local function submissionKey(targetGuid, casterGuid, spellId)
    if not targetGuid or not casterGuid or not spellId then return nil end
    return targetGuid .. ":" .. casterGuid .. ":" .. tostring(spellId)
end

function R:SweepSubmissions()
    local at, keys, key, record = now(), {}, nil, nil
    for key, record in pairs(self.submissions) do
        if at - (record.at or 0) > 30 then table.insert(keys, { table = self.submissions, key = key }) end
    end
    for key, record in pairs(self.recentSubmissions) do
        local retention = math.max(4, math.min(60, (tonumber(record.duration) or 0) + 2))
        if at - (record.consumedAt or record.at or 0) > retention then
            table.insert(keys, { table = self.recentSubmissions, key = key })
        end
    end
    local i
    for i = 1, table.getn(keys) do keys[i].table[keys[i].key] = nil end
end

function R:Submitted(action, targetGuid, tooltip, refresh)
    if not action or not action.spellId or not targetGuid then return end
    self:SweepSubmissions()
    local actor = action.facts and action.facts.damageActor or action.actor or "player"
    local casterGuid = guidFor(actor == "pet" and "pet" or "player")
    local key = submissionKey(targetGuid, casterGuid, action.spellId)
    if key then
        local submittedAt = now()
        local cast = tonumber(action.facts and action.facts.cast)
        if cast == nil then cast = tonumber(tooltip and tooltip.cast) or 0 end
        local metadata = self:SpellFacts(action.spellId)
        local resistanceSchool = self:School(action, tooltip)
        local deliveryModel, deliveryModelKnown, deliveryModelSource =
            deliveryModelFor(action.facts, metadata)
        local deliverySubtype = deliverySubtypeFor(action.facts, metadata, deliveryModel)
        local resistanceReduction, resistanceReductionKnown = 0, false
        if resistanceSchool ~= nil then
            resistanceReduction, resistanceReductionKnown =
                self:ActiveResistanceReduction(targetGuid, resistanceSchool)
        end
        local level = UnitLevel and UnitLevel(actor == "pet" and "pet" or "player") or nil
        local physicalContext
        if deliveryModel == "physical" then
            local casterContext = self:CasterContext(casterGuid, resistanceSchool, nil,
                action, targetGuid)
            casterContext.deliverySubtype = deliverySubtype
            casterContext.deliveryModelKnown = deliveryModelKnown
            casterContext.deliveryModelSource = deliveryModelSource
            physicalContext = self:PhysicalDeliveryContext(action, metadata, casterContext,
                self.identities[targetGuid])
        end
        self.ownedCasters[casterGuid] = { at = submittedAt, actor = actor, level = level }
        self.submissions[key] = { at = submittedAt, targetGuid = targetGuid,
            casterGuid = casterGuid, spellId = action.spellId,
            readyAt = submittedAt + math.max(0, cast), refresh = refresh and true or false,
            resistanceSchool = resistanceSchool,
            resistanceReduction = resistanceReduction,
            resistanceReductionKnown = resistanceReductionKnown,
            deliveryModel = deliveryModel, deliveryModelKnown = deliveryModelKnown,
            deliveryModelSource = deliveryModelSource, deliverySubtype = deliverySubtype,
            physicalContext = physicalContext,
            dynamicContext = self:DynamicContext(action.facts and action.facts.dynamicSchool),
            hasDirect = tooltip and tonumber(tooltip.directDamage) ~= nil
                and tonumber(tooltip.directDamage) > 0 or metadata.directDamage or false,
            duration = tonumber(tooltip and tooltip.duration),
            channel = action.facts and action.facts.channel and true or false,
            periodic = action.facts and (action.facts.kind == "dot" or action.facts.channel)
                and true or false }
    end
end

function R:Submission(targetGuid, casterGuid, spellId)
    self:SweepSubmissions()
    local key = submissionKey(targetGuid, casterGuid, spellId)
    local record = key and self.submissions[key]
    if record and now() - (record.at or 0) <= 30 then
        return record
    end
    if key then self.submissions[key] = nil end
    return nil
end

function R:TakeSubmission(targetGuid, casterGuid, spellId, force)
    local key = submissionKey(targetGuid, casterGuid, spellId)
    local record = self:Submission(targetGuid, casterGuid, spellId)
    if record and (force or now() >= (record.readyAt or record.at or 0)) then
        self.submissions[key] = nil
        record.consumedAt = now()
        self.recentSubmissions[key] = record
        return record
    end
    return nil
end

function R:RecentSubmission(targetGuid, casterGuid, spellId)
    self:SweepSubmissions()
    local key = submissionKey(targetGuid, casterGuid, spellId)
    local record = key and self.recentSubmissions[key]
    local retention = record and math.max(4, math.min(60,
        (tonumber(record.duration) or 0) + 2)) or 4
    if record and now() - (record.consumedAt or record.at or 0) <= retention then return record end
    if key then self.recentSubmissions[key] = nil end
    return nil
end

-- Terminal cast failures must retire the graph's evidence reservation as well
-- as the UI tap guard. Missing-target Nampower failure events are handled by
-- matching the owned caster and spell id across the bounded submission table.
function R:CancelSubmission(spellId, casterGuid, targetGuid)
    local keys, key, record = {}, nil, nil
    for key, record in pairs(self.submissions) do
        if (not spellId or tonumber(record.spellId) == tonumber(spellId))
            and (not casterGuid or record.casterGuid == casterGuid)
            and (not targetGuid or record.targetGuid == targetGuid) then
            table.insert(keys, key)
        end
    end
    local i
    for i = 1, table.getn(keys) do self.submissions[keys[i]] = nil end
    return table.getn(keys)
end

function R:AuraLanded(targetGuid, spellId, exactCasterGuid)
    if not targetGuid or not spellId then return nil end
    local casters = {}
    if exactCasterGuid then table.insert(casters, exactCasterGuid)
    else
        local playerGuid, petGuid = guidFor("player"), guidFor("pet")
        if playerGuid then table.insert(casters, playerGuid) end
        if petGuid then table.insert(casters, petGuid) end
    end
    local i
    for i = 1, table.getn(casters) do
        local casterGuid = casters[i]
        local submission = self:TakeSubmission(targetGuid, casterGuid, spellId, true)
        if submission then
            submission.applicationConfirmed = true
            local metadata = self:SpellFacts(spellId)
            local learned = self.spellSchools[spellId]
            local school = learned and learned.lastSchool or metadata.school
            local deliveryModel = submission.deliveryModel
            local deliveryModelKnown = submission.deliveryModelKnown
            local deliveryModelSource = submission.deliveryModelSource
            if not deliveryModel then
                deliveryModel, deliveryModelKnown, deliveryModelSource =
                    deliveryModelFor(nil, metadata)
            end
            if school and school >= 0
                and not (deliveryModel == "magic" and metadata.binary
                    and submission.directDeliveryConfirmed) then
                local base = self:CasterContext(casterGuid, school, nil, nil, targetGuid)
                base.deliveryModel = deliveryModel
                base.deliveryModelKnown = deliveryModelKnown
                base.deliveryModelSource = deliveryModelSource
                base.deliverySubtype = base.deliveryModel == "physical"
                    and (submission.deliverySubtype or metadata.deliverySubtype or "unknown") or nil
                base.deliveryCombined = deliveryModel == "magic" and metadata.binary and true or false
                if base.deliveryModel == "physical" then
                    local physical = submission.physicalContext
                        or self:PhysicalDeliveryContext(nil, metadata, base,
                            self.identities[targetGuid])
                    self:ApplyPhysicalDeliveryContext(base, physical)
                end
                local modifierKnown = true
                if base.deliveryCombined and school > 0 then
                    local reduction
                    if tonumber(submission.resistanceSchool) == school
                        and submission.resistanceReductionKnown == true then
                        reduction = tonumber(submission.resistanceReduction) or 0
                    else
                        reduction, modifierKnown =
                            self:ActiveResistanceReduction(targetGuid, school)
                    end
                    if modifierKnown then base = self:ModifierContext(base, reduction) end
                end
                local context = self:PhaseContext(base,
                    submission.periodic and "application" or "direct")
                if modifierKnown then
                    self:Observe(targetGuid, spellId, school, nil, "application-landed",
                        context, 1, true)
                else
                    self:ObserveDelivery(targetGuid, spellId, context, 1, true)
                end
            end
            return school, true
        end
    end
    return nil, false
end

function R:Observe(guid, spellId, school, delivered, outcome, context, weight, landEvidence)
    school = tonumber(school)
    if not guid or school == nil or school < 0 or school > 6 then return nil end
    local identity = self.identities[guid]
    if not identity and guid == guidFor("target") then identity = self:Identity("target") end
    if not identity then return nil end
    local profile = self:Profile(identity, true)
    if not profile then return nil end
    context = context or self:CasterContext(nil, school)
    local deliveryEvidence = landEvidence
    if context.deliveryModel == "none" or context.deliveryModel == "unknown"
        or context.deliveryModelKnown == false then
        -- These events still carry valid landed-hit mitigation, but they do
        -- not prove anything about an ordinary hit table. Do not let
        -- guaranteed/unknown delivery contaminate known magic or physical
        -- landing records.
        landEvidence = nil
    end
    local aggregate = profile.schools[school] or {}
    updateRecord(aggregate, delivered, weight, landEvidence)
    profile.schools[school] = aggregate
    local contextKey = tostring(school) .. ":" .. tostring(context.key or "unknown")
    local contextual = profile.contexts[contextKey] or {}
    updateRecord(contextual, delivered, weight, landEvidence)
    profile.contexts[contextKey] = contextual
    if not context.deliveryCombined and (deliveryEvidence == true or deliveryEvidence == "hit"
        or deliveryEvidence == "ordinary-miss") then
        updateProfileDelivery(profile, spellId, context, deliveryEvidence, weight)
    end
    profile.lastSeen = contextual.lastSeen
    if spellId then
        local spellKey = tostring(spellId) .. ":" .. tostring(school) .. ":"
            .. tostring(context.key or "unknown")
        local spell = profile.spells[spellKey] or {}
        updateRecord(spell, delivered, weight, landEvidence)
        profile.spells[spellKey] = spell
    end
    return contextual, aggregate
end

-- Ordinary hit-table evidence is useful even when the target is no longer
-- selected and its current resistance-modifier state cannot be reconstructed.
-- Keep that evidence in the modifier-independent delivery table without
-- creating a false baseline mitigation or binary-resistance observation.
function R:ObserveDelivery(guid, spellId, context, weight, evidence)
    if not guid or not context or context.deliveryCombined then return nil end
    local identity = self.identities[guid]
    if not identity and guid == guidFor("target") then identity = self:Identity("target") end
    if not identity then return nil end
    local profile = self:Profile(identity, true)
    if not profile then return nil end
    updateProfileDelivery(profile, spellId, context, evidence, weight)
    profile.lastSeen = epoch()
    return profile
end

local function mitigationValues(value)
    if type(value) ~= "string" then return 0, 0, 0 end
    local _, _, absorbed, blocked, resisted = string.find(value, "^([^,]*),([^,]*),([^,]*)$")
    return tonumber(absorbed) or 0, tonumber(blocked) or 0, tonumber(resisted) or 0
end
local function auraType(value)
    if type(value) ~= "string" then return nil end
    local _, _, _, _, _, aura = string.find(value, "^([^,]*),([^,]*),([^,]*),([^,]*)$")
    return tonumber(aura)
end

function R:SpellFacts(spellId)
    if not spellId then return {} end
    if self.spellMetadata[spellId] then return self.spellMetadata[spellId] end
    local school = tonumber(dbc(spellId, "school"))
    local attributesEx3Raw = tonumber(dbc(spellId, "attributesEx3"))
    local attributesEx3 = attributesEx3Raw or 0
    local attributesEx4 = tonumber(dbc(spellId, "attributesEx4")) or 0
    local dmgClass = tonumber(dbc(spellId, "dmgClass"))
    local rangeIndex = tonumber(dbc(spellId, "rangeIndex"))
    local equippedItemClass = tonumber(dbc(spellId, "equippedItemClass"))
    local effects, auras = dbc(spellId, "effect", true), dbc(spellId, "effectApplyAuraName", true)
    local binary, periodic, directDamage = false, false, false
    if type(effects) == "table" then
        local i
        for i = 1, table.getn(effects) do
            if effects[i] == 2 or effects[i] == 9 or effects[i] == 17
                or effects[i] == 31 or effects[i] == 58 or effects[i] == 121 then
                directDamage = true
            end
            -- A non-aura effect on a damaging magic spell is conservatively
            -- direct-capable even when a custom Turtle effect ID is unknown.
            if dmgClass == 1 and school and school ~= 0
                and effects[i] and effects[i] ~= 0 and effects[i] ~= 6 then
                directDamage = true
            end
            if dmgClass == 1 and school and school ~= 0 and (effects[i] == 68
                or effects[i] == 98
                or effects[i] == 6 and auras and BINARY_AURAS[auras[i]]) then
                binary = true
            end
            if effects[i] == 6 and auras and PERIODIC_DAMAGE_AURAS[auras[i]] then
                periodic = true
            end
        end
    end
    local normalRanged = hasFlag(attributesEx3, 32768)
    local alwaysHit = hasFlag(attributesEx3, 262144)
    -- The server predicate is the DBC range index itself, not the client range
    -- row's flags. SPELL_RANGE_IDX_COMBAT is index 2 in the supported client.
    local combatRange
    if rangeIndex ~= nil then combatRange = rangeIndex == 2 end
    local usesWeaponSkill
    if rangeIndex == 2 or equippedItemClass == 2 then
        usesWeaponSkill = true
    elseif rangeIndex ~= nil and equippedItemClass ~= nil then
        usesWeaponSkill = false
    end
    local deliveryModel
    if dmgClass == 2 or dmgClass == 3
        or dmgClass == 1 and normalRanged then deliveryModel = "physical"
    elseif dmgClass == 1 then deliveryModel = "magic"
    elseif dmgClass == 0 then deliveryModel = "none" end
    local facts = { school = school, binary = binary,
        periodic = periodic, directDamage = directDamage,
        dmgClass = dmgClass, rangeIndex = rangeIndex, combatRange = combatRange,
        equippedItemClass = equippedItemClass, usesWeaponSkill = usesWeaponSkill,
        deliveryModel = deliveryModel, deliveryModelKnown = deliveryModel ~= nil,
        deliveryModelSource = deliveryModel and "client DBC DmgClass" or nil,
        deliverySubtype = (dmgClass == 3 or dmgClass == 1 and normalRanged) and "ranged"
            or dmgClass == 2 and "melee" or nil,
        normalRanged = normalRanged, alwaysHit = alwaysHit,
        alwaysHitKnown = attributesEx3Raw ~= nil,
        ignoreResistances = hasFlag(attributesEx4, 1),
        source = "client DBC" }
    self.spellMetadata[spellId] = facts
    return facts
end

function R:MarkApplicationUncertain(targetGuid, spellId, casterGuid, reason)
    local submission = self:Submission(targetGuid, casterGuid, spellId)
    if submission then
        submission.applicationUncertain = reason or "application uncertain"
        return true
    end
    return false
end

function R:RememberSpellSchool(spellId, school, observedAura, dynamicContext)
    if not spellId or school == nil then return nil end
    local entry = self.spellSchools[spellId] or { bySchool = {} }
    entry.bySchool[school] = (entry.bySchool[school] or 0) + 1
    entry.lastSchool, entry.lastAt, entry.lastAura = school, now(), observedAura
    if dynamicContext then
        if not entry.byContext then entry.byContext = {} end
        local contextual = entry.byContext[dynamicContext] or { bySchool = {} }
        contextual.bySchool[school] = (contextual.bySchool[school] or 0) + 1
        contextual.lastSchool, contextual.lastAt = school, now()
        entry.byContext[dynamicContext] = contextual
    end
    local count, ignored = 0, nil
    for ignored in pairs(entry.bySchool) do count = count + 1 end
    entry.mixed = count > 1
    self.spellSchools[spellId] = entry
    return entry
end

function R:IsOwnedCaster(guid)
    if not guid then return false end
    if guid == guidFor("player") or guid == guidFor("pet") then
        local pet = guid == guidFor("pet")
        self.ownedCasters[guid] = { at = now(), actor = pet and "pet" or "player",
            level = UnitLevel and UnitLevel(pet and "pet" or "player") or nil }
        return true
    end
    local seen = self.ownedCasters[guid]
    local seenAt = type(seen) == "table" and seen.at or seen
    if seenAt and now() - seenAt <= 60 then return true end
    if seen then self.ownedCasters[guid] = nil end
    return false
end
function R:MarkNumeric(targetGuid, spellId)
    if targetGuid and spellId then self.numericEvidence[targetGuid .. ":" .. tostring(spellId)] = now() end
end
function R:NumericEventsEnabled()
    -- Nampower 4.6 emits damage and miss events unconditionally. The old
    -- helper comments naming per-stream CVars do not match the installed DLL.
    return (GetNampowerVersion or QueueSpellByName) and true or false
end
function R:ShouldTrainChat(targetGuid, spellId)
    if self:NumericEventsEnabled() then return false end
    local at = targetGuid and spellId and self.numericEvidence[targetGuid .. ":" .. tostring(spellId)]
    return not at or now() - at > 1
end

-- Nampower exposes the resolved white-swing attack table directly. Keep this
-- evidence separate from damage mitigation: totalDamage is already downstream
-- of Armor, block, absorb, resistance, crit and glancing calculations, so it
-- cannot be inverted into a clean mitigation sample. It can, however, teach
-- the exact effective delivery outcome for the hand/skill/Defense/position
-- fingerprint used by the graph.
local function autoAttackDeliveryEvidence(totalDamage, hitInfo, victimState)
    totalDamage = math.max(0, tonumber(totalDamage) or 0)
    hitInfo, victimState = tonumber(hitInfo), tonumber(victimState)
    if hitInfo == nil or victimState == nil then return nil, "invalid outcome" end
    -- The same opcode is also used by SendMeleeAttackingStateUpdate for melee
    -- spells. Nampower forwards those with NOACTION, so accepting them here
    -- would train yellow outcomes into the white-swing Attack node.
    if hasFlag(hitInfo, 65536) then return nil, "melee spell packet" end
    if hasFlag(hitInfo, 16) then return "ordinary-miss", "miss" end
    if victimState == 2 then return "ordinary-miss", "dodge" end
    if victimState == 3 then return "ordinary-miss", "parry" end
    if victimState == 6 then return "ordinary-miss", "evade" end
    if victimState == 7 then return "ordinary-miss", "immune" end
    if victimState == 8 then return "ordinary-miss", "deflect" end
    -- Upstream uses BLOCKS only for a full block; partial blocks stay NORMAL.
    if victimState == 5 then return "ordinary-miss", "full block" end
    if victimState == 1 then return "hit", "hit" end
    -- UNAFFECTED is documented with HITINFO_MISS. If a custom client emits it
    -- without that flag, or the otherwise undocumented INTERRUPT state, do not
    -- guess and pollute a learned hit table.
    return nil, "unclassified victim state"
end

function R:AutoAttack(attackerGuid, targetGuid, totalDamage, hitInfo, victimState,
    subDamageCount, blockedAmount, totalAbsorb, totalResist)
    if not targetGuid or not self:IsOwnedCaster(attackerGuid) then return nil end
    local evidence, outcome = autoAttackDeliveryEvidence(totalDamage, hitInfo, victimState)
    local playerGuid, petGuid = guidFor("player"), guidFor("pet")
    local actor = attackerGuid == petGuid and "pet"
        or attackerGuid == playerGuid and "player" or nil
    local owned = self.ownedCasters[attackerGuid]
    if not actor and type(owned) == "table" then actor = owned.actor end
    if actor ~= "player" and actor ~= "pet" then return nil end
    local hand = hasFlag(hitInfo, 4) and "off" or "main"
    if not evidence then
        return { actor = actor, hand = hand, evidence = nil, outcome = outcome,
            exactDelivery = false, totalDamage = math.max(0, tonumber(totalDamage) or 0),
            hitInfo = tonumber(hitInfo), victimState = tonumber(victimState) }
    end
    local identity = self.identities[targetGuid]
    if targetGuid == guidFor("target") then
        identity = self:RememberUnit("target") or identity
    end
    if not identity then
        -- A pet can auto-attack a GUID other than the selected target. Retain
        -- that evidence only for this exact session GUID until richer identity
        -- data becomes available; never promote an unknown GUID to an NPC key.
        identity = { guid = targetGuid }
        self.identities[targetGuid] = identity
    end
    local action = { name = "Attack", actor = actor, facts = {
        kind = "damage", school = 0, melee = true, whiteAttack = true,
        weaponHand = hand, deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, alwaysHit = false } }
    local context = self:CasterContext(attackerGuid, 0, nil, action, targetGuid)
    context.deliveryModel = "physical"
    context.deliveryModelKnown = true
    context.deliveryModelSource = "Nampower auto-attack outcome"
    context.deliverySubtype = "melee"
    context.deliveryCombined = false
    local physical = self:PhysicalDeliveryContext(action, {}, context, identity)
    self:ApplyPhysicalDeliveryContext(context, physical)
    context = self:PhaseContext(context, "direct")
    self:ObserveDelivery(targetGuid, nil, context, 1, evidence)
    return { actor = actor, hand = hand, evidence = evidence, outcome = outcome,
        exactDelivery = evidence ~= nil, totalDamage = math.max(0, tonumber(totalDamage) or 0),
        hitInfo = tonumber(hitInfo), victimState = tonumber(victimState),
        subDamageCount = tonumber(subDamageCount), blocked = tonumber(blockedAmount) or 0,
        absorbed = tonumber(totalAbsorb) or 0, resisted = tonumber(totalResist) or 0,
        physicalContext = physical }
end

local expectedPartial, inverseExpectedPartial

local function innateResistancePoints(level, targetLevel)
    if type(level) ~= "number" or level <= 0 or type(targetLevel) ~= "number" then return 0 end
    return truncate((8 * (targetLevel - level)) * level / 63)
end

function R:ObserveInferredRaw(profile, school, resistedFraction, context, targetLevel)
    if not profile or school < 1 or resistedFraction < 0 or resistedFraction > 0.75
        or not context or not context.level or context.level <= 0 then return end
    if not context.penetrationKnown then return end
    if type(profile.inferredRawContexts) ~= "table" then profile.inferredRawContexts = {} end
    local key = tostring(school) .. ":" .. tostring(context.key)
    local record = profile.inferredRawContexts[key]
        or { samples = 0, resistedTotal = 0 }
    if record.samples >= 64 then
        record.samples = record.samples * 0.75
        record.resistedTotal = record.resistedTotal * 0.75
    end
    record.samples = record.samples + 1
    record.resistedTotal = record.resistedTotal + resistedFraction
    local normalizedTargetLevel = tonumber(targetLevel)
    if normalizedTargetLevel == -1 then normalizedTargetLevel = context.level + 3
    elseif normalizedTargetLevel and normalizedTargetLevel <= 0 then
        normalizedTargetLevel = nil
    end
    record.level, record.targetLevel = context.level, normalizedTargetLevel
    record.penetration = context.penetration or 0
    record.lastSeen = epoch()
    profile.inferredRawContexts[key] = record
end

function R:DamageEvent(targetGuid, casterGuid, spellId, amount, mitigation, hitInfo, school, effectAura)
    if not targetGuid or not self:IsOwnedCaster(casterGuid) then return nil end
    school = tonumber(school)
    if not school or school < 0 or school > 6 then return nil end
    local absorbed, blocked, resisted = mitigationValues(mitigation)
    local observedAura = auraType(effectAura)
    local metadata = self:SpellFacts(spellId)
    local pendingAtEvent = self:Submission(targetGuid, casterGuid, spellId)
    local contextSubmission = pendingAtEvent
        or self:RecentSubmission(targetGuid, casterGuid, spellId)
    local eventDeliveryModel = contextSubmission and contextSubmission.deliveryModel
    local eventDeliveryKnown = contextSubmission and contextSubmission.deliveryModelKnown
    local eventDeliverySource = contextSubmission and contextSubmission.deliveryModelSource
    if not eventDeliveryModel then
        eventDeliveryModel, eventDeliveryKnown, eventDeliverySource =
            deliveryModelFor(nil, metadata)
    end
    local explicitPeriodic = PERIODIC_DAMAGE_AURAS[observedAura] and true or false
    local inferredPeriodic, phaseUnknown = false, false
    if not explicitPeriodic and metadata.periodic then
        -- Nampower's non-melee packet path discards its periodicLog byte and
        -- exports aura type zero. A hybrid's first packet is direct while its
        -- later unreserved packets are periodic; pure DoTs/channels are
        -- periodic even while their application submission is still pending.
        if pendingAtEvent and pendingAtEvent.refresh
            and now() < (pendingAtEvent.readyAt or pendingAtEvent.at or 0) then
            inferredPeriodic = true
        elseif pendingAtEvent and pendingAtEvent.refresh then
            -- Once the new cast could have impacted, an aura-type-0 packet is
            -- observationally ambiguous with an old tick. Preserve its school
            -- but train neither phase until the exact aura event arrives.
            pendingAtEvent.ambiguousRefreshPacket = true
            pendingAtEvent.phaseAmbiguous = true
            phaseUnknown = true
        elseif contextSubmission and contextSubmission.phaseAmbiguous then
            phaseUnknown = true
        elseif pendingAtEvent and pendingAtEvent.periodic
            and pendingAtEvent.hasDirect and pendingAtEvent.directSeen then
            inferredPeriodic = true
        elseif pendingAtEvent then
            inferredPeriodic = pendingAtEvent.periodic and not pendingAtEvent.hasDirect
        elseif contextSubmission and contextSubmission.periodic
            and contextSubmission.hasDirect and contextSubmission.directSeen then
            inferredPeriodic = true
        elseif contextSubmission and contextSubmission.periodic
            and contextSubmission.hasDirect and not contextSubmission.directSeen then
            inferredPeriodic = false
        elseif metadata.directDamage then
            -- With neither a submission nor an explicit aura type, a hybrid's
            -- direct impact and an old aura tick are observationally
            -- indistinguishable. Keep the school evidence but do not train the
            -- wrong mitigation phase.
            phaseUnknown = true
        else
            inferredPeriodic = true
        end
    elseif not explicitPeriodic and pendingAtEvent and pendingAtEvent.periodic
        and (pendingAtEvent.channel or not pendingAtEvent.hasDirect) then
        inferredPeriodic = true
    end
    local observed = { school = school, schoolMask = 2 ^ school,
        ignoresArmor = observedAura == 89,
        binary = eventDeliveryModel == "magic" and metadata.binary and true or false,
        deliveryModel = eventDeliveryModel, deliveryModelKnown = eventDeliveryKnown,
        ignoreResistances = metadata.ignoreResistances,
        periodic = explicitPeriodic or inferredPeriodic,
        phaseUnknown = phaseUnknown,
        periodicSource = explicitPeriodic and "aura type"
            or inferredPeriodic and "spell lifecycle" or "direct packet",
        at = now(), source = "Nampower damage event" }
    if contextSubmission and not observed.periodic and not observed.phaseUnknown then
        contextSubmission.directSeen = true
    end
    self:RememberSpellSchool(spellId, school, observedAura,
        contextSubmission and contextSubmission.dynamicContext)
    self:MarkNumeric(targetGuid, spellId)
    if observed.phaseUnknown then return observed end
    amount = math.max(0, tonumber(amount) or 0)
    local basis = amount + math.max(0, absorbed) + math.max(0, resisted)
        - math.max(0, -resisted)
    if basis <= 0 then return observed end
    observed.delivered, observed.resisted = 1 - resisted / basis, resisted
    observed.absorbed, observed.blocked, observed.basis = absorbed, blocked, basis
    local baseContext = self:CasterContext(casterGuid, school, nil, nil, targetGuid)
    baseContext.deliveryModel = eventDeliveryModel
    baseContext.deliveryModelKnown = eventDeliveryKnown
    baseContext.deliveryModelSource = eventDeliverySource
    baseContext.deliverySubtype = baseContext.deliveryModel == "physical"
        and (contextSubmission and contextSubmission.deliverySubtype
            or metadata.deliverySubtype or "unknown") or nil
    baseContext.deliveryCombined = observed.binary
    if baseContext.deliveryModel == "physical" then
        local physical = contextSubmission and contextSubmission.physicalContext
            or self:PhysicalDeliveryContext(nil, metadata, baseContext,
                self.identities[targetGuid])
        self:ApplyPhysicalDeliveryContext(baseContext, physical)
    end
    local submittedReduction, submittedReductionKnown
    if contextSubmission and tonumber(contextSubmission.resistanceSchool) == school then
        submittedReduction = tonumber(contextSubmission.resistanceReduction) or 0
        submittedReductionKnown = contextSubmission.resistanceReductionKnown == true
    end
    local currentReduction, currentReductionKnown =
        self:ActiveResistanceReduction(targetGuid, school)
    local activeReduction, activeReductionKnown
    if observed.periodic then
        activeReduction, activeReductionKnown = currentReduction, currentReductionKnown
    elseif submittedReductionKnown then
        activeReduction, activeReductionKnown = submittedReduction, true
    else
        activeReduction, activeReductionKnown = currentReduction, currentReductionKnown
    end
    local applicationReduction, applicationReductionKnown
    if submittedReductionKnown then
        applicationReduction, applicationReductionKnown = submittedReduction, true
    else
        applicationReduction, applicationReductionKnown =
            currentReduction, currentReductionKnown
    end
    local mitigationBaseContext = activeReductionKnown
        and self:ModifierContext(baseContext, activeReduction) or baseContext
    local applicationBaseContext = applicationReductionKnown
        and self:ModifierContext(baseContext, applicationReduction) or baseContext
    local context = self:PhaseContext(mitigationBaseContext,
        observed.periodic and "periodic" or "direct")
    local delivered = observed.binary and resisted >= 0 and 1 or observed.delivered
    local pending = self:Submission(targetGuid, casterGuid, spellId)
    local submission
    if contextSubmission and contextSubmission.applicationUncertain then
        -- A full debuff bar can still allow a hybrid's direct damage. Keep the
        -- reservation for exact/timeout resolution and never promote that
        -- packet into application success.
    elseif contextSubmission and contextSubmission.periodic
        and contextSubmission.hasDirect and not observed.periodic then
        -- A hybrid's direct packet proves only its direct portion. The exact
        -- caster-bearing aura event remains the application proof, avoiding a
        -- later cap event or an old refresh tick being mistaken for success.
    elseif observed.periodic then
        if pending and not pending.refresh then
            submission = self:TakeSubmission(targetGuid, casterGuid, spellId, false)
        end
    else
        -- A direct event cannot belong to an older periodic application, so it
        -- is exact evidence even if client/server timing is slightly early.
        submission = self:TakeSubmission(targetGuid, casterGuid, spellId, true)
    end
    local sharedApplication = submission and submission.periodic
    local directAlreadyConfirmed = contextSubmission
        and contextSubmission.directDeliveryConfirmed
    local combinedAlreadyConfirmed = observed.binary and contextSubmission
        and contextSubmission.applicationConfirmed
    local landEvidence = not observed.periodic and not sharedApplication
        and not directAlreadyConfirmed and not combinedAlreadyConfirmed and true or nil
    if school == 0 or metadata.ignoreResistances and resisted >= 0 then delivered = nil end
    local modifierEvidenceKnown = activeReductionKnown
        or (delivered == nil and not (observed.binary and school > 0))
    if modifierEvidenceKnown then
        self:Observe(targetGuid, spellId, school, delivered, "damage", context, 1, landEvidence)
    else
        observed.modifierStateUnknown = true
        if landEvidence then
            self:ObserveDelivery(targetGuid, spellId, context, 1, landEvidence)
        end
    end
    if landEvidence and contextSubmission then
        contextSubmission.directDeliveryConfirmed = true
    end
    if submission and submission.periodic then
        local applicationContext = self:PhaseContext(applicationBaseContext, "application")
        if applicationReductionKnown or not (observed.binary and school > 0) then
            self:Observe(targetGuid, spellId, school, nil, "application-landed",
                applicationContext, 1, true)
        else
            self:ObserveDelivery(targetGuid, spellId, applicationContext, 1, true)
        end
    end
    if submission then submission.applicationConfirmed = true end
    local identity = self.identities[targetGuid]
    local profile = self:Profile(identity, false)
    if school > 0 and not observed.periodic and not observed.binary
        and not metadata.ignoreResistances and resisted >= 0
        and activeReductionKnown and profile and math.abs(activeReduction or 0) < 0.0001 then
        self:ObserveInferredRaw(profile, school, resisted / basis, baseContext,
            identity and identity.level)
    end
    return observed
end

function R:Miss(spellId, targetGuid, missInfo, casterGuid)
    missInfo = tonumber(missInfo)
    if not missInfo or missInfo < 1 or missInfo > 11 or not targetGuid then return nil end
    local metadata = self:SpellFacts(spellId)
    local learned = self.spellSchools[spellId]
    local school = learned and learned.lastSchool or metadata.school
    local submission = self:TakeSubmission(targetGuid, casterGuid, spellId, true)
    local key = submissionKey(targetGuid, casterGuid, spellId)
    if key then self.recentSubmissions[key] = nil end
    self:MarkNumeric(targetGuid, spellId)
    -- Every defined miss outcome is terminal for this evidence reservation.
    -- Code 1 is an ordinary delivery failure. vMaNGOS also emits code 2 for a
    -- nonbinary magic hit failure; for binary spells it represents the one
    -- combined base-hit/resistance roll. Neither can be inverted into a raw
    -- resistance value.
    local deliveryModel = submission and submission.deliveryModel
    local deliveryModelKnown = submission and submission.deliveryModelKnown
    local deliveryModelSource = submission and submission.deliveryModelSource
    if not deliveryModel then
        deliveryModel, deliveryModelKnown, deliveryModelSource =
            deliveryModelFor(nil, metadata)
    end
    local physicalDelivery = deliveryModel == "physical"
    local physicalFailure = physicalDelivery and (missInfo == 1 or missInfo == 3
        or missInfo == 4 or missInfo == 5 or missInfo == 9)
    local binaryCombined = deliveryModel == "magic" and metadata.binary and missInfo == 2
    local physicalCombined = physicalDelivery and missInfo == 2
    local combinedReject = binaryCombined or physicalCombined
    local ordinaryFailure = missInfo == 1 or physicalFailure
        or not physicalDelivery and not metadata.binary and missInfo == 2
    if (ordinaryFailure or combinedReject) and school ~= nil then
        local baseContext = self:CasterContext(casterGuid, school, nil, nil, targetGuid)
        baseContext.deliveryModel = deliveryModel
        baseContext.deliveryModelKnown = deliveryModelKnown
        baseContext.deliveryModelSource = deliveryModelSource
        baseContext.deliverySubtype = physicalDelivery
            and (submission and submission.deliverySubtype
                or metadata.deliverySubtype or "unknown") or nil
        baseContext.deliveryCombined = combinedReject and true or false
        if physicalDelivery then
            local physical = submission and submission.physicalContext
                or self:PhysicalDeliveryContext(nil, metadata, baseContext,
                    self.identities[targetGuid])
            self:ApplyPhysicalDeliveryContext(baseContext, physical)
        end
        local modifierKnown = true
        -- Magical binary rejects depend on the active school-resistance
        -- modifier. A physical spell's code-2 mechanic reject is a separate
        -- melee-spell roll and remains useful after a target swap.
        if binaryCombined and school > 0 then
            local reduction
            if submission and tonumber(submission.resistanceSchool) == school
                and submission.resistanceReductionKnown == true then
                reduction = tonumber(submission.resistanceReduction) or 0
            else
                reduction, modifierKnown =
                    self:ActiveResistanceReduction(targetGuid, school)
            end
            if modifierKnown then
                baseContext = self:ModifierContext(baseContext, reduction)
            end
        end
        local phase = (submission and submission.periodic or metadata.periodic)
            and "application" or "direct"
        if modifierKnown then
            self:Observe(targetGuid, spellId, school, nil,
                combinedReject and "combined-reject" or "ordinary-miss",
                self:PhaseContext(baseContext, phase), 1,
                combinedReject and "resistance-reject" or "ordinary-miss")
        end
    end
    return school
end

function R:School(action, tooltip)
    local facts = action and action.facts or {}
    local metadata = action and action.spellId and self:SpellFacts(action.spellId) or {}
    local learned = action and action.spellId and self.spellSchools[action.spellId]
    if facts.mixedDamage and not facts.damageComponents then
        return nil, false, false, "mixed damage components unresolved"
    end
    local school
    if facts.dynamicSchool then
        local context = self:DynamicContext(facts.dynamicSchool)
        local contextual = context and learned and learned.byContext and learned.byContext[context]
        school = contextual and contextual.lastSchool
    else
        school = tonumber(facts.school) or tooltip and tonumber(tooltip.school)
            or metadata.school or learned and not learned.mixed and learned.lastSchool
    end
    if school == nil and facts.bleed then school = 0 end
    local ignoresArmor = facts.bleed or facts.ignoresArmor or false
    local ignoreResistances = facts.ignoreResistances or tooltip and tooltip.ignoresResistances
        or metadata.ignoreResistances or false
    local source = facts.dynamicSchool and school
            and "observed " .. tostring(facts.dynamicSchool) .. " school"
        or school ~= nil and "client spell school" or "damage school unknown"
    return school, ignoresArmor and true or false, ignoreResistances and true or false, source
end

local function ageWeight(lastSeen)
    if not lastSeen then return 0 end
    local age = math.max(0, epoch() - lastSeen)
    return 0.5 ^ (age / PROFILE_HALF_LIFE)
end

-- Expected damage removed by vMaNGOS's discrete 0/25/50/75% resistance
-- outcome table at each resistance-chance breakpoint. Its nominal 100%
-- bucket is capped to 75% for damage, matching the server implementation.
local PARTIAL_TABLE = {
    { 0.00, 0.0000 }, { 0.03, 0.0250 }, { 0.05, 0.0575 },
    { 0.08, 0.0775 }, { 0.10, 0.1000 }, { 0.13, 0.1300 },
    { 0.15, 0.1525 }, { 0.18, 0.1725 }, { 0.20, 0.2000 },
    { 0.23, 0.2300 }, { 0.25, 0.2500 }, { 0.28, 0.2700 },
    { 0.30, 0.2950 }, { 0.33, 0.3250 }, { 0.35, 0.3475 },
    { 0.38, 0.3725 }, { 0.40, 0.3975 }, { 0.43, 0.4275 },
    { 0.45, 0.4475 }, { 0.48, 0.4650 }, { 0.50, 0.4950 },
    { 0.53, 0.5075 }, { 0.55, 0.5300 }, { 0.58, 0.5550 },
    { 0.60, 0.5725 }, { 0.62, 0.5900 }, { 0.65, 0.6100 },
    { 0.68, 0.6300 }, { 0.70, 0.6525 }, { 0.73, 0.6675 },
    { 0.75, 0.6875 },
}

expectedPartial = function(chance)
    chance = clamp(chance, 0, 0.75)
    local i
    for i = 2, table.getn(PARTIAL_TABLE) do
        local high, low = PARTIAL_TABLE[i], PARTIAL_TABLE[i - 1]
        if chance <= high[1] then
            local span = high[1] - low[1]
            local ratio = span > 0 and (chance - low[1]) / span or 0
            return low[2] + (high[2] - low[2]) * ratio
        end
    end
    return PARTIAL_TABLE[table.getn(PARTIAL_TABLE)][2]
end

inverseExpectedPartial = function(resisted)
    resisted = tonumber(resisted)
    if not resisted or resisted < 0 then return nil end
    local maximum = PARTIAL_TABLE[table.getn(PARTIAL_TABLE)][2]
    if resisted >= maximum then return 0.75 end
    local i
    for i = 2, table.getn(PARTIAL_TABLE) do
        local high, low = PARTIAL_TABLE[i], PARTIAL_TABLE[i - 1]
        if resisted <= high[2] then
            local span = high[2] - low[2]
            local ratio = span > 0 and (resisted - low[2]) / span or 0
            return low[1] + (high[1] - low[1]) * ratio
        end
    end
    return 0.75
end

local function projectedLearnedMitigation(multiplier, reduction, level, periodic, school)
    multiplier, reduction, level = tonumber(multiplier), tonumber(reduction), tonumber(level)
    if not multiplier or not reduction or reduction <= 0 or not level or level <= 0 then
        return multiplier
    end
    if school == 0 then
        if multiplier >= 1 then return multiplier end
        local constant = 400 + 85 * level
        local inferredArmor = constant * (1 / math.max(0.05, multiplier) - 1)
        local projectedArmor = math.max(0, inferredArmor - reduction)
        return constant / (constant + projectedArmor)
    end
    local delta = reduction * 0.15 / level
    if periodic then delta = delta * 0.1 end
    if multiplier < 1 then
        local chance = inverseExpectedPartial(1 - multiplier)
        if not chance then return multiplier end
        return 1 - expectedPartial(math.max(0, chance - delta))
    elseif multiplier > 1 then
        local chance = inverseExpectedPartial(multiplier - 1)
        if not chance then return multiplier end
        return 1 + expectedPartial(math.min(0.75, chance + delta))
    end
    return multiplier
end

-- vMaNGOS is used as a Vanilla prior, while live Turtle fields and outcomes
-- remain authoritative. Positive resistance becomes a 0..75% resistance
-- chance; the discrete partial-resist table bends above 50%. Classic periodic
-- damage scales that chance before the table lookup, not the final result.
-- Negative target resistance uses the effective caster's maximum skill and the
-- same table as vulnerability. Innate level-difference resistance applies to every magical
-- school in the Vanilla server prior, including otherwise-zero Holy.
local function magicMultiplier(raw, level, penetration, targetLevel, school, innate, periodic)
    if type(raw) ~= "number" or type(level) ~= "number" or level <= 0 then return nil end
    local effective = raw - math.max(0, tonumber(penetration) or 0)
    if raw >= 0 then effective = math.max(0, effective) end
    -- Server vulnerability is resolved before innate higher-level resistance.
    if effective < 0 then
        -- vMaNGOS calls GetSkillMaxForLevel on the caster here. For an owned
        -- player/pet action this is the effective attacker level, floored at
        -- skill 100, not the victim's defensive level.
        local vulnerabilityCap = math.max(20, level) * 5
        local chance = clamp(-effective / vulnerabilityCap, 0, 0.75)
        if periodic then chance = chance * 0.1 end
        local vulnerability = expectedPartial(chance)
        return 1 + vulnerability, effective, -vulnerability, -chance
    end
    local modeled = effective
    if innate and type(targetLevel) == "number" then
        modeled = modeled + innateResistancePoints(level, targetLevel)
    end
    local chance = clamp(modeled * 0.15 / level, 0, 0.75)
    if periodic then chance = chance * 0.1 end
    local resisted = expectedPartial(chance)
    return 1 - resisted, effective, resisted, chance
end

local function binaryResistance(raw, level, penetration, targetLevel)
    if type(raw) ~= "number" or type(level) ~= "number" or level <= 0 then return nil end
    local effective = raw - math.max(0, tonumber(penetration) or 0)
    if raw >= 0 then effective = math.max(0, effective) end
    if effective < 0 then
        local cap = math.max(20, level) * 5
        local chance = -clamp(-effective / cap, 0, 0.75)
        return chance, 1 + expectedPartial(-chance), effective
    end
    return clamp(effective * 0.15 / level, 0, 0.75), 1, effective
end

local function armorMultiplier(raw, level, penetration)
    if type(raw) ~= "number" or type(level) ~= "number" or level <= 0 then return nil end
    local effective = math.max(0, raw - math.max(0, tonumber(penetration) or 0))
    local constant = 400 + 85 * level
    local mitigated = math.min(0.75, effective / (effective + constant))
    return 1 - mitigated, effective, mitigated
end

local function learnedValues(record)
    if not record then return nil, nil, 0 end
    local recency = ageWeight(record.lastSeen)
    local samples = (record.samples or 0) * recency
    local mitigation
    if samples > 0 then
        mitigation = ((record.delivered or 0) + PROFILE_PRIOR)
            / ((record.samples or 0) + PROFILE_PRIOR)
        mitigation = 1 - (1 - mitigation) * recency
    end
    local landSamples = (record.landSamples or 0) * recency
    local landing
    if landSamples > 0 then
        landing = ((record.landHits or 0) + LAND_PRIOR)
            / ((record.landSamples or 0) + LAND_PRIOR)
        landing = 1 + (landing - 1) * recency
    end
    return mitigation, landing, math.max(samples, landSamples)
end

local function baseSpellHit(attackerLevel, targetLevel, targetIsPlayer)
    if type(attackerLevel) ~= "number" or attackerLevel <= 0
        or type(targetLevel) ~= "number" or targetLevel <= 0 then return 0.96 end
    local difference = targetLevel - attackerLevel
    local percent
    if difference < 3 then percent = 96 - difference
    else percent = 94 - (difference - 2) * (targetIsPlayer and 7 or 11) end
    return clamp(percent / 100, 0.22, 0.99)
end

local function compactContextToken(value)
    value = tostring(value or "?")
    local hash, index = 0, nil
    for index = 1, string.len(value) do
        local nextHash = hash * 131 + string.byte(value, index)
        hash = nextHash - math.floor(nextHash / 1000003) * 1000003
    end
    return tostring(hash)
end

local function targetDefense(identity, actor, attackerLevel)
    local level = identity and tonumber(identity.level)
    if level == -1 and attackerLevel and attackerLevel > 0 then level = attackerLevel + 3 end
    if identity and identity.isPlayer then
        -- vMaNGOS uses the victim player's maximum Defense when the attacker
        -- is another player, including permanent and temporary Defense
        -- bonuses. A pet/non-player attacker instead checks the victim's
        -- current Defense. UnitDefense exposes the current base plus the same
        -- bonus term when the hostile unit API supplies a non-zero value.
        local liveBase, liveModifier
        if identity.guid == guidFor("target") and UnitDefense then
            local ok, base, modifier = pcall(UnitDefense, "target")
            if ok and type(base) == "number" and base > 0 then
                liveBase, liveModifier = base, tonumber(modifier) or 0
            end
        end
        if actor == "player" and level and level > 0 then
            local maximum = level * 5
            if liveBase then
                return math.max(0, maximum + liveModifier), true,
                    "PvP maximum defense plus live bonuses"
            end
            return maximum, false, "PvP defense bonuses unverified"
        end
        if actor ~= "player" and liveBase then
            local total = liveBase + liveModifier
            if total > 0 then
                return total, true, "live player defense vs non-player attacker"
            end
        end
        return level and level > 0 and level * 5 or nil, false,
            "hostile player current defense unverified"
    end
    if level and level > 0 then
        return level * 5, true, identity and identity.isPlayer
            and "PvP maximum defense" or "NPC level defense"
    end
    return nil, false, "target defense unavailable"
end

local function physicalHitFromSkills(attackerSkill, defense, targetLevel,
    targetIsPlayer, dualWieldWhite)
    if type(attackerSkill) ~= "number" or type(defense) ~= "number" then return nil end
    local difference = attackerSkill - defense
    local miss
    if targetIsPlayer then miss = 5 - difference * 0.04
    elseif difference < -10 then miss = 5 - difference * 0.2
    else miss = 5 - difference * 0.1 end
    if dualWieldWhite then miss = miss + 19 end
    if not targetIsPlayer and type(targetLevel) == "number"
        and targetLevel > 0 and targetLevel < 10 then
        miss = miss * targetLevel / 10
    end
    miss = clamp(miss, 0, 60)
    return 1 - miss / 100, miss
end

-- Build only the initial physical miss roll here. Dodge/parry/block/mechanic
-- outcomes remain exact learned evidence because their availability depends on
-- position and target flags. The +19% dual-wield term is valid only for white
-- melee swings; yellow abilities and ranged attacks never inherit it.
function R:PhysicalDeliveryContext(action, metadata, context, identity)
    local facts = action and action.facts or {}
    metadata = metadata or {}
    local subtype = context and context.deliverySubtype or facts.deliverySubtype
        or metadata.deliverySubtype or facts.weaponRanged and "ranged"
        or facts.melee and "melee" or "unknown"
    local hand = facts.weaponHand or (subtype == "ranged" and "ranged" or "main")
    if hand ~= "main" and hand ~= "off" and hand ~= "ranged" then hand = "main" end
    -- Current vMaNGOS uses BASE_ATTACK for the miss roll of melee specials,
    -- even when later damage/proc processing identifies an off-hand weapon.
    -- OFF_ATTACK skill is therefore valid only for an actual off-hand white
    -- swing until the live fork proves otherwise.
    if hand == "off" and facts.whiteAttack ~= true then hand = "main" end
    local actualSkill
    if facts.whiteAttack or facts.weaponRanged or facts.usesWeaponSkill == true
        or metadata.usesWeaponSkill == true then actualSkill = true
    elseif facts.usesWeaponSkill == false or metadata.usesWeaponSkill == false then
        actualSkill = false
    end
    local actor = context and context.actor or action and action.actor or "player"
    local level = context and tonumber(context.level)
    local skills = actor == "player" and XelAssistCapabilities
        and XelAssistCapabilities.WeaponSkills and XelAssistCapabilities:WeaponSkills() or nil
    local record, attackerSkill, skillKnown, skillSource, weaponToken
    if actor ~= "player" then
        attackerSkill, skillKnown = level and level > 0 and level * 5 or nil,
            level and level > 0 and true or false
        skillSource = skillKnown and "unit level skill" or "unit skill unavailable"
        actualSkill = true
    elseif actualSkill == true then
        record = type(skills) == "table" and skills[hand] or nil
        attackerSkill = record and tonumber(record.total)
        skillKnown = record and record.known == true and attackerSkill ~= nil or false
        skillSource = record and record.source or "current weapon skill unavailable"
        weaponToken = type(skills) == "table" and skills[hand .. "Token"] or nil
    elseif actualSkill == false then
        attackerSkill, skillKnown = level and level > 0 and level * 5 or nil,
            level and level > 0 and true or false
        skillSource = skillKnown and "spell uses level-max skill" or "level-max skill unavailable"
    else
        skillKnown, skillSource = false, "spell weapon-skill mode unavailable"
    end
    local defense, defenseKnown, defenseSource = targetDefense(identity, actor, level)
    local dualRelevant = facts.whiteAttack == true and subtype ~= "ranged"
    local dualStateKnown = not dualRelevant
    if dualRelevant and type(skills) == "table" then
        if skills.dualWieldKnown ~= nil then
            dualStateKnown = skills.dualWieldKnown == true
        else
            -- Compatibility with a capability provider that predates the
            -- explicit durability-aware certainty bit.
            dualStateKnown = skills.dualWield ~= nil
        end
    end
    local dual = dualRelevant and type(skills) == "table"
        and skills.dualWield == true or false
    local targetLevel = identity and tonumber(identity.level)
    if targetLevel == -1 and level and level > 0 then targetLevel = level + 3 end
    local hit, miss = physicalHitFromSkills(attackerSkill, defense, targetLevel,
        identity and identity.isPlayer, dual)
    local positionRelevant = subtype ~= "ranged"
    local positionKnown = positionRelevant and context
        and context.positionKnown == true and type(context.behindTarget) == "boolean" or false
    local attackPosition = not positionRelevant and "not-applicable"
        or positionKnown and (context.behindTarget and "behind" or "front") or "unknown"
    local modeToken = actualSkill == true and "1" or actualSkill == false and "0" or "?"
    local modelKnown = context and context.deliveryModelKnown == true
    local alwaysHit, alwaysHitKnown
    if facts.alwaysHit ~= nil then
        alwaysHit, alwaysHitKnown = facts.alwaysHit and true or false, true
    elseif metadata.alwaysHitKnown then
        alwaysHit, alwaysHitKnown = metadata.alwaysHit and true or false, true
    elseif facts.whiteAttack then
        alwaysHit, alwaysHitKnown = false, true
    else
        alwaysHit, alwaysHitKnown = false, false
    end
    local token = "w" .. hand .. ":s" .. tostring(attackerSkill or "?")
        .. ":sk" .. (skillKnown and "1" or "0")
        .. ":d" .. tostring(defense or "?")
        .. ":dk" .. (defenseKnown and "1" or "0") .. ":u" .. modeToken
        .. ":wt" .. (facts.whiteAttack == true and "1" or "0")
        .. ":mc" .. (modelKnown and "1" or "0")
        .. ":ah" .. (not alwaysHitKnown and "?" or alwaysHit and "1" or "0")
        .. ":x" .. compactContextToken(weaponToken or (actualSkill == false and "level" or "?"))
        .. ":dw" .. (not dualStateKnown and "?" or dual and "1" or "0")
        .. ":p" .. attackPosition
    local priorGaps = {}
    if not skillKnown then table.insert(priorGaps, "weapon skill") end
    if not defenseKnown then table.insert(priorGaps, "target Defense") end
    if not modelKnown then table.insert(priorGaps, "delivery class") end
    if not alwaysHitKnown then table.insert(priorGaps, "always-hit flag") end
    if type(skills) == "table" and skills.formWeaponUseKnown == false then
        table.insert(priorGaps, "shapeshift weapon rule")
    end
    if hit == nil then table.insert(priorGaps, "base miss roll") end
    if not dualStateKnown then table.insert(priorGaps, "off-hand durability") end
    if positionRelevant and not positionKnown then table.insert(priorGaps, "attack position") end
    -- The stock/Nampower APIs do not expose a complete additive +hit total or
    -- a target's live dodge/parry/block table. Exact hit/miss outcomes learn
    -- those omitted sub-rolls in this fully partitioned context.
    if not alwaysHit then table.insert(priorGaps, "+hit") end
    if facts.whiteAttack then
        table.insert(priorGaps, "active defenses")
    elseif subtype == "ranged" then
        table.insert(priorGaps, "mechanic resistance")
    else
        table.insert(priorGaps, "active defenses/mechanic resistance")
    end
    return { key = token, subtype = subtype, hand = hand,
        weaponSkill = attackerSkill, weaponSkillKnown = skillKnown,
        weaponSkillSource = skillSource, usesWeaponSkill = actualSkill,
        targetDefense = defense, targetDefenseKnown = defenseKnown,
        targetDefenseSource = defenseSource, dualWieldWhitePenalty = dual and 19 or 0,
        whiteAttack = facts.whiteAttack == true,
        dualWieldStateKnown = dualStateKnown,
        deliveryModelKnown = modelKnown,
        alwaysHit = alwaysHit, alwaysHitKnown = alwaysHitKnown,
        formWeaponUseKnown = type(skills) == "table" and skills.formWeaponUseKnown,
        attackPosition = attackPosition, positionKnown = positionKnown,
        positionRelevant = positionRelevant,
        positionSource = positionKnown and context.positionSource
            or positionRelevant and "position unavailable" or "ranged attack table",
        hitChance = hit, missChance = miss,
        priorGaps = table.concat(priorGaps, ", "), unknown = table.getn(priorGaps) > 0,
        hitBonusKnown = false, hitBonusSource = "+hit excluded from skill prior" }
end

function R:ApplyPhysicalDeliveryContext(context, physical)
    if not context or not physical then return context end
    -- A submission can know that an action is melee/ranged from graph facts
    -- even when its DBC row is incomplete. Restore that captured subtype on
    -- delayed combat events so learned outcomes use the exact key Estimate
    -- will read for the action.
    context.deliverySubtype = physical.subtype or context.deliverySubtype
    -- Armor/spell penetration changes landed-hit mitigation, never the
    -- physical hit table. Keep it in context.key for mitigation while the
    -- delivery key uses a deliberate not-applicable marker. This also lets a
    -- first dynamic-school wand miss train the later discovered school.
    context.deliveryKey = tostring(context.actor or "player") .. ":l"
        .. tostring(context.level or 0) .. ":p-:" .. tostring(physical.key)
    context.weaponSkill = physical.weaponSkill
    context.targetDefense = physical.targetDefense
    context.attackPosition = physical.attackPosition
    context.positionKnown = physical.positionKnown
    context.physicalDelivery = physical
    return context
end

-- Physical spell attacks use the weapon table, not the magic spell table.
-- This level prior is retained only when a live skill or target-defense input
-- is unavailable; the result is marked as delivery-unknown by Estimate.
local function basePhysicalHit(attackerLevel, targetLevel, targetIsPlayer)
    if type(attackerLevel) ~= "number" or attackerLevel <= 0
        or type(targetLevel) ~= "number" or targetLevel <= 0 then return 0.95 end
    local difference = targetLevel - attackerLevel
    local miss
    if targetIsPlayer then miss = 5 + math.max(0, difference) * 0.2
    elseif difference > 2 then miss = 5 + difference
    else miss = 5 + difference * 0.5 end
    return clamp(1 - miss / 100, 0.40, 0.99)
end

local function learnedDelivery(record, prior)
    if not record then return nil, 0 end
    local recency = ageWeight(record.lastSeen)
    local samples = (record.samples or 0) * recency
    if samples <= 0 then return nil, 0 end
    local posterior = ((record.hits or 0) + LAND_PRIOR * prior)
        / ((record.samples or 0) + LAND_PRIOR)
    return prior + (posterior - prior) * recency, samples
end

function R:EstimateComponent(action, target, tooltip, state, component)
    local componentAction = { name = action.name, rank = action.rank, actor = action.actor,
        spellId = action.spellId, facts = { kind = action.facts.kind,
            school = component.school, ignoresArmor = component.mitigation == "none"
                and component.school == 0 or component.ignoresArmor,
            melee = action.facts.melee, ranged = action.facts.ranged,
            weaponRanged = action.facts.weaponRanged,
            whiteAttack = action.facts.whiteAttack,
            weaponHand = action.facts.weaponHand,
            usesWeaponSkill = action.facts.usesWeaponSkill,
            deliveryModel = action.facts.deliveryModel,
            deliverySubtype = action.facts.deliverySubtype,
            ignoreMitigation = component.mitigation == "none",
            ignoreResistances = component.ignoreResistances } }
    local componentTooltip = { school = component.school }
    return self:Estimate(componentAction, target, componentTooltip, state, true)
end

local CONFIDENCE_RANK = { ["unknown"] = 0, ["partial"] = 1,
    ["limited samples"] = 2, ["inferred field"] = 3, ["observed"] = 4,
    ["learned"] = 5, ["modeled"] = 6, ["live target data"] = 7,
    ["corroborated"] = 8, ["spell effect"] = 9 }

local function componentConfidence(parts, unknown)
    if unknown then return "partial" end
    local weakest, weakestRank, i = "modeled", CONFIDENCE_RANK.modeled, nil
    for i = 1, table.getn(parts) do
        local value = parts[i].confidence or "unknown"
        local rank = CONFIDENCE_RANK[value] or 0
        if rank < weakestRank then weakest, weakestRank = value, rank end
    end
    return weakest
end

function R:Estimate(action, target, tooltip, state, componentCall)
    local facts = action and action.facts or {}
    if not componentCall and type(facts.damageComponents) == "table" then
        local totalWeight, totalMultiplier, parts, i = 0, 0, {}, nil
        for i = 1, table.getn(facts.damageComponents) do
            local component = facts.damageComponents[i]
            local weight = tonumber(component.weight or component.weaponMultiplier) or 0
            if weight > 0 then
                local estimate = self:EstimateComponent(action, target, tooltip, state, component)
                estimate.componentWeight = weight
                totalWeight, totalMultiplier = totalWeight + weight,
                    totalMultiplier + weight * (estimate.multiplier or 1)
                table.insert(parts, estimate)
            end
        end
        if totalWeight > 0 then
            local unknown, penetrationUnknown, samples, i = false, false, 0, nil
            for i = 1, table.getn(parts) do
                if parts[i].unknown then unknown = true end
                if parts[i].penetrationUnknown then penetrationUnknown = true end
                samples = samples + (parts[i].samples or 0)
            end
            return { school = nil, schoolName = "Mixed", multiplier = totalMultiplier / totalWeight,
                expectedMultiplier = totalMultiplier / totalWeight,
                source = "component-weighted resistance",
                confidence = componentConfidence(parts, unknown),
                samples = samples, unknown = unknown, components = parts, mode = "mixed",
                penetrationUnknown = penetrationUnknown }
        end
    end

    -- Hybrid spells such as Immolate and Moonfire have an ordinary direct
    -- impact plus periodic damage. The application/direct portion uses the
    -- normal school model while periodic ticks use the reduced DoT resistance
    -- shape. Keep both components visible to the graph rather than collapsing
    -- the whole tooltip into either regime.
    local directDamage = tooltip and tonumber(tooltip.directDamage)
    local periodicDamage = tooltip and tonumber(tooltip.periodicDamage)
    if not componentCall and directDamage and directDamage > 0
        and periodicDamage and periodicDamage > 0 then
        local function phaseAction(phase)
            local copy = { name = action.name, rank = action.rank, actor = action.actor,
                spellId = action.spellId, facts = {} }
            local key, value
            for key, value in pairs(facts) do copy.facts[key] = value end
            copy.facts.resistancePhase = phase
            return copy
        end
        local phaseTooltip = { school = tooltip.school }
        local direct = self:Estimate(phaseAction("direct"), target, phaseTooltip, state, true)
        local periodic = self:Estimate(phaseAction("periodic"), target, phaseTooltip, state, true)
        direct.componentWeight, direct.componentPhase = directDamage, "direct"
        periodic.componentWeight, periodic.componentPhase = periodicDamage, "periodic"
        local total = directDamage + periodicDamage
        local multiplier = (directDamage * (direct.multiplier or 1)
            + periodicDamage * (periodic.multiplier or 1)) / total
        local sharedLanding
        if direct.landChance and periodic.landChance then
            sharedLanding = math.min(direct.landChance, periodic.landChance)
        else sharedLanding = direct.landChance or periodic.landChance end
        local landedValue = sharedLanding and sharedLanding > 0
            and multiplier / sharedLanding or nil
        local unknown = direct.unknown or periodic.unknown
        local source
        if direct.source == periodic.source then source = "direct + periodic; " .. tostring(direct.source)
        else source = "direct + periodic resistance" end
        return { school = direct.school or periodic.school,
            schoolName = direct.schoolName or periodic.schoolName,
            schoolMask = direct.schoolMask or periodic.schoolMask,
            multiplier = multiplier, expectedMultiplier = multiplier,
            source = source, confidence = componentConfidence({ direct, periodic }, unknown),
            samples = (direct.samples or 0) + (periodic.samples or 0),
            deliverySamples = math.max(direct.deliverySamples or 0,
                periodic.deliverySamples or 0),
            unknown = unknown, components = { direct, periodic }, mode = "hybrid",
            landChance = sharedLanding, mitigationOnLand = landedValue,
            baseHitChance = direct.baseHitChance or periodic.baseHitChance,
            deliveryModel = direct.deliveryModel or periodic.deliveryModel,
            deliverySubtype = direct.deliverySubtype or periodic.deliverySubtype,
            raw = direct.raw or periodic.raw, effective = direct.effective or periodic.effective,
            penetration = direct.penetration or periodic.penetration,
            penetrationUnknown = direct.penetrationUnknown or periodic.penetrationUnknown,
            projectedReduction = direct.projectedReduction or periodic.projectedReduction,
            directDamage = directDamage, periodicDamage = periodicDamage }
    end

    local school, ignoresArmor, ignoreResistances, schoolSource = self:School(action, tooltip)
    local metadata = action and action.spellId and self:SpellFacts(action.spellId) or {}
    local result = { school = school, schoolName = self:SchoolName(school), multiplier = 1,
        expectedMultiplier = 1, source = schoolSource or "unknown", confidence = "unknown",
        samples = 0, unknown = true, ignoresArmor = ignoresArmor,
        ignoreResistances = ignoreResistances }
    if school ~= nil then result.schoolMask = 2 ^ school end
    if target ~= "target" or school == nil then return result end
    local kind = facts.kind
    local damageKind = kind == "damage" or kind == "dot" or kind == "builder"
    local deliveryModel, deliveryModelKnown, deliveryModelSource =
        deliveryModelFor(facts, metadata)
    local physicalDelivery = deliveryModel == "physical"
    local noOrdinaryDelivery = deliveryModel == "none"
    local physicalSubtype = deliverySubtypeFor(facts, metadata, deliveryModel)
    local alwaysHit = facts.alwaysHit or metadata.alwaysHit or false
    result.alwaysHit = alwaysHit and true or false

    local snapshot = state and state.targetResistance
    local live = snapshot and snapshot.live
    if facts.resistancePhase then result.periodic = facts.resistancePhase == "periodic"
    else result.periodic = facts.kind == "dot" or facts.channel or metadata.periodic or false end
    result.binary = deliveryModel == "magic" and (facts.binary or metadata.binary) or false
    local context = self:CasterContext(nil, school, state, action)
    -- `facts.ranged` describes targeting geometry in the action catalogue; it
    -- does not mean the spell uses the physical ranged hit table.  Delivery
    -- class must come from the school, an explicit semantic override, or DBC.
    context.deliveryModel = deliveryModel
    context.deliveryModelKnown = deliveryModelKnown
    context.deliveryModelSource = deliveryModelSource
    context.deliverySubtype = physicalSubtype
    local attackerLevel = context.level or tonumber(state and state.playerLevel) or 0
    local targetLevel = snapshot and snapshot.identity and snapshot.identity.level
        or state and state.encounter and state.encounter.target and state.encounter.target.level
    if targetLevel == -1 and attackerLevel and attackerLevel > 0 then
        targetLevel, result.targetLevelEstimated = attackerLevel + 3, true
    end
    local pen = context.penetrationKnown and (context.penetration or 0) or 0
    result.penetration, result.penetrationUnknown = pen, not context.penetrationKnown
    local raw = live and tonumber(live[school])

    local identity = snapshot and snapshot.identity
    if not identity then
        local currentGuid = guidFor("target")
        identity = currentGuid and self.identities[currentGuid] or self:Identity("target")
    end
    local profile = self:Profile(identity, false)
    local rawSource = live and (snapshot.liveSource or "live target resistance") or nil
    local cached = profile and profile.raw and profile.raw[school]
    if raw == nil and cached and cached.kind == "base" and ageWeight(cached.lastSeen) > 0.05 then
        raw, rawSource = tonumber(cached.value), "cached Turtle base resistance"
    end
    local rawKey = tostring(school) .. ":" .. tostring(context.key)
    local rawRecord = profile and profile.inferredRawContexts
        and profile.inferredRawContexts[rawKey]
    local rawSamples = rawRecord and (rawRecord.samples or 0) * ageWeight(rawRecord.lastSeen) or 0
    if raw == nil and rawRecord and rawSamples >= 8 and inverseExpectedPartial then
        local mean = (rawRecord.resistedTotal or 0) / math.max(0.001, rawRecord.samples)
        local chance = inverseExpectedPartial(mean)
        if chance then
            local inferenceLevel = rawRecord.level or attackerLevel
            local inferenceTargetLevel = rawRecord.targetLevel or targetLevel
            if inferenceTargetLevel == -1 and inferenceLevel and inferenceLevel > 0 then
                inferenceTargetLevel = inferenceLevel + 3
            end
            raw = math.max(0, chance * inferenceLevel / 0.15
                - innateResistancePoints(inferenceLevel, inferenceTargetLevel)
                + (rawRecord.penetration or 0))
        end
    end
    if raw ~= nil and not rawSource and rawRecord then
        rawSource = "inferred resistance from " .. tostring(math.floor(rawSamples + 0.5))
            .. " damage outcomes"
    end
    local projectedReduction = snapshot and snapshot.projectedReduction
        and tonumber(snapshot.projectedReduction[school]) or 0
    if raw ~= nil and projectedReduction and projectedReduction ~= 0 then
        -- On the supported post-1.8 server path, penetration/reduction cannot
        -- turn a nonnegative base resistance into vulnerability. An already
        -- negative base remains negative and can become more vulnerable.
        if school == 0 or raw >= 0 then raw = math.max(0, raw - projectedReduction)
        else raw = raw - projectedReduction end
        rawSource = (rawSource or "target resistance") .. " after projected "
            .. tostring(snapshot.projectedBy or "debuff")
        result.projectedReduction = projectedReduction
    elseif projectedReduction and projectedReduction ~= 0 then
        result.projectedReduction = projectedReduction
    end
    local physicalContext
    if physicalDelivery then
        physicalContext = self:PhysicalDeliveryContext(action, metadata, context, identity)
        self:ApplyPhysicalDeliveryContext(context, physicalContext)
    end
    local mitigationPhase = result.periodic and "periodic" or "direct"
    local landPhase = facts.resistancePhase and "application"
        or result.periodic and "application" or "direct"
    local baselineMitigationContext = self:PhaseContext(context, mitigationPhase)
    local baselineLandContext = self:PhaseContext(context, landPhase)
    local modifierContext = self:ModifierContext(context, projectedReduction)
    local mitigationContext = self:PhaseContext(modifierContext, mitigationPhase)
    local landContext = self:PhaseContext(modifierContext, landPhase)
    local mitigationKey = tostring(school) .. ":" .. tostring(mitigationContext.key)
    local landKey = tostring(school) .. ":" .. tostring(landContext.key)
    local mitigationRecord = profile and profile.contexts and profile.contexts[mitigationKey]
    local landRecord = profile and profile.contexts and profile.contexts[landKey]
    local learnedMitigation, ignoredLanding, mitigationSamples = learnedValues(mitigationRecord)
    local ignoredMitigation, learnedResistanceLanding, landSamples = learnedValues(landRecord)
    local mitigationFromBaseline, landFromBaseline = false, false
    if mitigationContext.key ~= baselineMitigationContext.key and not learnedMitigation then
        local key = tostring(school) .. ":" .. tostring(baselineMitigationContext.key)
        local baseline = profile and profile.contexts and profile.contexts[key]
        learnedMitigation, ignoredLanding, mitigationSamples = learnedValues(baseline)
        mitigationFromBaseline = learnedMitigation ~= nil
    end
    if landContext.key ~= baselineLandContext.key and not learnedResistanceLanding then
        local key = tostring(school) .. ":" .. tostring(baselineLandContext.key)
        local baseline = profile and profile.contexts and profile.contexts[key]
        ignoredMitigation, learnedResistanceLanding, landSamples = learnedValues(baseline)
        landFromBaseline = learnedResistanceLanding ~= nil
    end
    local spellContextKey = action and action.spellId and tostring(action.spellId)
        .. ":" .. tostring(school) .. ":" .. tostring(landContext.key)
    local combinedRecord = spellContextKey and profile and profile.spells
        and profile.spells[spellContextKey]
    local ignoredCombinedMitigation, learnedCombined, combinedSamples =
        learnedValues(combinedRecord)
    local combinedFromBaseline = false
    if landContext.key ~= baselineLandContext.key and not learnedCombined and action
        and action.spellId then
        local baselineKey = tostring(action.spellId) .. ":" .. tostring(school)
            .. ":" .. tostring(baselineLandContext.key)
        combinedRecord = profile and profile.spells and profile.spells[baselineKey]
        ignoredCombinedMitigation, learnedCombined, combinedSamples =
            learnedValues(combinedRecord)
        combinedFromBaseline = learnedCombined ~= nil
    end
    local currentDeliveryKey = deliveryKey(landContext)
    local deliveryRecord = profile and profile.deliveryContexts
        and profile.deliveryContexts[currentDeliveryKey]
    local magicGuaranteedDelivery = noOrdinaryDelivery
        or deliveryModel == "magic" and (ignoreResistances or alwaysHit)
    local priorHit
    if magicGuaranteedDelivery then priorHit = 1
    elseif physicalDelivery then
        -- Physical ALWAYS_HIT suppresses only the initial miss sub-roll; exact
        -- dodge/parry/block/mechanic outcomes are still learned separately.
        -- Retain their conservative prior while making the ordinary miss term
        -- weapon-skill aware whenever the client inputs are known.
        if alwaysHit then
            priorHit = basePhysicalHit(attackerLevel, targetLevel, identity and identity.isPlayer)
        else
            priorHit = physicalContext and physicalContext.hitChance
                or basePhysicalHit(attackerLevel, targetLevel, identity and identity.isPlayer)
        end
    else priorHit = baseSpellHit(attackerLevel, targetLevel, identity and identity.isPlayer) end
    local learnedOrdinaryLanding, deliverySamples = learnedDelivery(deliveryRecord, priorHit)
    local spellDeliveryKey = action and action.spellId
        and tostring(action.spellId) .. ":" .. currentDeliveryKey
    local spellDeliveryRecord = spellDeliveryKey and profile and profile.spellDeliveryContexts
        and profile.spellDeliveryContexts[spellDeliveryKey]
    -- A single exact outcome is written to both the general delivery context
    -- and its spell-specific context.  They are alternate estimates, not two
    -- independent rolls; calculate both from the same prior and prefer the
    -- exact spell estimate when it exists.
    local spellLanding, spellDeliverySamples = learnedDelivery(spellDeliveryRecord, priorHit)
    local ordinaryLanding = magicGuaranteedDelivery and 1
        or spellLanding or learnedOrdinaryLanding or priorHit
    deliverySamples = math.max(deliverySamples or 0, spellDeliverySamples or 0)
    local projectedLearned = false
    if raw == nil and projectedReduction > 0 and mitigationFromBaseline
        and learnedMitigation then
        learnedMitigation = projectedLearnedMitigation(learnedMitigation,
            projectedReduction, attackerLevel, result.periodic, school)
        projectedLearned = true
    end
    if raw == nil and projectedReduction > 0 and result.binary
        and combinedFromBaseline and learnedCombined and ordinaryLanding > 0 then
        local resistanceLanding = clamp(learnedCombined / ordinaryLanding, 0.01, 1)
        resistanceLanding = math.min(1,
            resistanceLanding + projectedReduction * 0.15 / math.max(1, attackerLevel))
        learnedCombined = ordinaryLanding * resistanceLanding
        projectedLearned = true
    end
    local effectiveSamples = math.max(mitigationSamples, landSamples)
    result.samples = math.floor(effectiveSamples + 0.5)
    result.deliverySamples = math.floor((deliverySamples or 0) + 0.5)
    result.baseHitChance = priorHit
    result.deliveryModel = deliveryModel
    result.deliveryModelKnown = deliveryModelKnown
    result.deliveryModelSource = deliveryModelSource
    result.deliverySubtype = physicalSubtype
    if physicalContext then
        result.weaponHand = physicalContext.hand
        result.weaponSkill = physicalContext.weaponSkill
        result.weaponSkillKnown = physicalContext.weaponSkillKnown
        result.weaponSkillSource = physicalContext.weaponSkillSource
        result.usesActualWeaponSkill = physicalContext.usesWeaponSkill
        result.targetDefense = physicalContext.targetDefense
        result.targetDefenseKnown = physicalContext.targetDefenseKnown
        result.targetDefenseSource = physicalContext.targetDefenseSource
        result.weaponMissChance = physicalContext.missChance
        result.hitBonusKnown = physicalContext.hitBonusKnown
        result.hitBonusSource = physicalContext.hitBonusSource
        result.attackPosition = physicalContext.attackPosition
        result.positionKnown = physicalContext.positionKnown
        result.positionRelevant = physicalContext.positionRelevant
        result.positionSource = physicalContext.positionSource
        result.ordinaryMissBypassed = alwaysHit and true or false
        result.dualWieldWhitePenalty = physicalContext.dualWieldWhitePenalty
        result.dualWieldStateKnown = physicalContext.dualWieldStateKnown
        result.formWeaponUseKnown = physicalContext.formWeaponUseKnown
        result.deliveryPriorGaps = physicalContext.priorGaps
        result.deliveryPriorUnknown = physicalContext.unknown
    end
    result.mode = school == 0 and "armor" or (result.binary and "binary"
        or result.periodic and "periodic-magic" or "magic-partial")

    local modeled, effective, resisted, resistanceChance, binaryDamage
    if school == 0 then
        modeled, effective, resisted = armorMultiplier(raw, attackerLevel, pen)
    elseif result.binary then
        if (ignoreResistances or alwaysHit) and (raw == nil or raw >= 0) then
            modeled, effective, resisted, resistanceChance = 1, raw, 0, 0
        else
            resistanceChance, binaryDamage, effective = binaryResistance(raw,
                attackerLevel, pen, targetLevel)
            resisted = resistanceChance
            modeled = binaryDamage
        end
    elseif ignoreResistances then
        if raw ~= nil and raw < 0 then
            modeled, effective, resisted, resistanceChance = magicMultiplier(raw,
                attackerLevel, pen, targetLevel, school,
                not (identity and identity.isPlayer), result.periodic)
        else modeled, effective, resisted, resistanceChance = 1, raw, 0, 0 end
    else
        modeled, effective, resisted, resistanceChance = magicMultiplier(raw, attackerLevel, pen,
            targetLevel, school, not (identity and identity.isPlayer), result.periodic)
    end
    local modeledSource
    if modeled then modeledSource = rawSource end

    local mitigationOnLand, landChance
    local mitigationKnown = false
    local physicalMechanicLanding = physicalDelivery and combinedRecord
        and (combinedRecord.resistanceRejects or 0) > 0 and learnedCombined or nil
    if school == 0 and not damageKind then
        landChance = ordinaryLanding * (physicalMechanicLanding or 1)
        mitigationOnLand, mitigationKnown = 1, true
        if physicalMechanicLanding then
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        end
        result.mode = "physical-effect"
    elseif ignoreResistances and physicalDelivery and school > 0 then
        landChance = ordinaryLanding * (physicalMechanicLanding or 1)
        local bypassLearned = learnedMitigation and math.max(1, learnedMitigation)
        if raw ~= nil and raw >= 0 then mitigationOnLand = 1
        elseif modeled and bypassLearned then
            local weight = math.min(0.75, effectiveSamples / (effectiveSamples + 8))
            mitigationOnLand = modeled * (1 - weight) + bypassLearned * weight
        else mitigationOnLand = bypassLearned or modeled or 1 end
        mitigationKnown = true
        if physicalMechanicLanding then
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        end
        result.mode = "physical-delivery-ignore-resistance"
    elseif ignoreResistances then
        landChance = 1
        local bypassLearned = learnedMitigation and math.max(1, learnedMitigation)
        if raw ~= nil and raw >= 0 then mitigationOnLand = 1
        elseif modeled and bypassLearned then
            local weight = math.min(0.75, effectiveSamples / (effectiveSamples + 8))
            mitigationOnLand = modeled * (1 - weight) + bypassLearned * weight
        else mitigationOnLand = bypassLearned or modeled or 1 end
        mitigationKnown = true
        result.mode = "ignore-resistance"
    elseif facts.ignoreMitigation or school == 0 and ignoresArmor then
        landChance = ordinaryLanding * (physicalMechanicLanding or 1)
        mitigationOnLand, mitigationKnown = 1, true
        if physicalMechanicLanding then
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        end
        result.mode = school == 0 and "ignore-armor" or "ignore-mitigation"
    elseif school == 0 then
        landChance = ordinaryLanding * (physicalMechanicLanding or 1)
        if physicalMechanicLanding then
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        end
        if modeled and learnedMitigation then
            local weight = math.min(0.75, effectiveSamples / (effectiveSamples + 8))
            mitigationOnLand = modeled * (1 - weight) + learnedMitigation * weight
        else mitigationOnLand = learnedMitigation or modeled end
        mitigationKnown = mitigationOnLand ~= nil
    elseif result.binary then
        local modeledResistanceLanding = resistanceChance and (1 - resistanceChance) or nil
        local resistanceLanding = modeledResistanceLanding
        local modeledCombined
        if magicGuaranteedDelivery then modeledCombined = 1
        else modeledCombined = resistanceLanding and ordinaryLanding * resistanceLanding
                or ordinaryLanding end
        if learnedCombined and not magicGuaranteedDelivery then
            local weight = math.min(0.8, combinedSamples / (combinedSamples + 6))
            landChance = modeledCombined * (1 - weight) + learnedCombined * weight
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        else landChance = modeledCombined end
        local binaryLearned = learnedMitigation and math.max(1, learnedMitigation)
        if modeled and binaryLearned then
            local weight = math.min(0.75, mitigationSamples / (mitigationSamples + 8))
            mitigationOnLand = modeled * (1 - weight) + binaryLearned * weight
        else mitigationOnLand = binaryLearned or modeled end
        mitigationKnown = mitigationOnLand ~= nil or resistanceLanding ~= nil
    else
        local resistanceLanding = physicalDelivery
            and (physicalMechanicLanding or 1) or learnedResistanceLanding or 1
        landChance = ordinaryLanding * resistanceLanding
        if physicalMechanicLanding then
            result.combinedDeliverySamples = math.floor(combinedSamples + 0.5)
        end
        if modeled and learnedMitigation then
            local weight = math.min(0.75, effectiveSamples / (effectiveSamples + 8))
            mitigationOnLand = modeled * (1 - weight) + learnedMitigation * weight
        else mitigationOnLand = learnedMitigation or modeled end
        mitigationKnown = mitigationOnLand ~= nil or learnedResistanceLanding ~= nil
    end
    if not landChance and mitigationOnLand then landChance = ordinaryLanding end
    if not mitigationOnLand and landChance then mitigationOnLand = 1 end
    if landChance and mitigationOnLand then
        local maximumLanding = (school == 0 or magicGuaranteedDelivery) and 1 or 0.99
        result.landChance = clamp(landChance, 0.01, maximumLanding)
        result.mitigationOnLand = clamp(mitigationOnLand, 0.05, 1.75)
        result.multiplier = result.landChance * result.mitigationOnLand
        result.expectedMultiplier, result.raw = result.multiplier, raw
        result.effective, result.resistChance = effective, resisted
        result.resistanceChance = resistanceChance
        local deliveryUnknown = physicalContext and physicalContext.unknown
            and (deliverySamples or 0) < 4
        local classificationUnknown = deliveryModelKnown ~= true
        result.deliveryPriorUnknown = classificationUnknown or deliveryUnknown and true
            or physicalContext and physicalContext.unknown or false
        result.unknown = not mitigationKnown or classificationUnknown
            or deliveryUnknown and true or false
        if not mitigationKnown then
            result.source = (physicalDelivery and "physical delivery prior" or "spell delivery prior")
                .. "; target " .. (school == 0 and "armor" or "resistance") .. " unknown"
            result.confidence = (deliverySamples or 0) >= 4 and "limited samples" or "unknown"
        elseif modeledSource and effectiveSamples > 0 then
            result.source = modeledSource .. " + " .. tostring(result.samples) .. " context outcomes"
            result.confidence = result.samples >= 8 and "corroborated" or "observed"
        elseif modeledSource then
            result.source = modeledSource
            result.confidence = live and "live target data" or "inferred field"
        else
            result.source = tostring(result.samples) .. " context outcomes"
            result.confidence = result.samples >= 8 and "learned" or "limited samples"
        end
        if ignoreResistances then
            result.source = tostring(result.source) .. "; ignores positive resistance"
            if result.confidence == "unknown" then result.confidence = "spell effect" end
        end
        if projectedLearned then
            result.source = tostring(result.source) .. " after projected "
                .. tostring(snapshot and snapshot.projectedBy or "resistance reduction")
        end
        if classificationUnknown then
            result.source = tostring(result.source) .. "; "
                .. tostring(deliveryModelSource or "delivery class unavailable")
        end
        if physicalContext then
            local deliverySource
            if physicalContext.unknown then
                deliverySource = "physical delivery prior incomplete ("
                    .. tostring(physicalContext.priorGaps or "unresolved inputs") .. ")"
                if (deliverySamples or 0) >= 4 then
                    deliverySource = deliverySource .. "; exact delivery outcomes used"
                elseif result.confidence ~= "unknown" then result.confidence = "partial" end
            else
                deliverySource = "skill " .. tostring(physicalContext.weaponSkill)
                    .. " vs defense " .. tostring(physicalContext.targetDefense)
                if physicalContext.missChance then
                    deliverySource = deliverySource .. " ("
                        .. tostring(math.floor(physicalContext.missChance * 10 + 0.5) / 10)
                        .. "% base miss)"
                end
            end
            if physicalContext.dualWieldWhitePenalty > 0 then
                deliverySource = deliverySource .. "; +19% white dual-wield miss"
            end
            if alwaysHit then deliverySource = deliverySource .. "; ordinary miss bypassed" end
            deliverySource = deliverySource .. "; +hit excluded from prior"
            result.source = tostring(result.source) .. "; " .. deliverySource
        end
    end
    return result
end

function R:Contrast(state, chosen)
    if not chosen or chosen.unknown or chosen.school == nil then return nil end
    local worst, worstSchool, school = 1, nil, nil
    for school = 0, 6 do
        local estimate = self:Estimate({ facts = { kind = "damage", school = school } },
            "target", { school = school }, state)
        if not estimate.unknown and estimate.multiplier < worst then
            worst, worstSchool = estimate.multiplier, school
        end
    end
    if worstSchool and worstSchool ~= chosen.school and chosen.multiplier - worst >= 0.12 then
        return "uses " .. chosen.schoolName .. " against elevated " .. self:SchoolName(worstSchool)
            .. " resistance"
    end
    return nil
end

function R:CurrentSummary(state)
    local rows, school = {}, nil
    local physicalVariants = {
        { name = "Physical melee", subtype = "melee", melee = true },
        { name = "Physical ranged", subtype = "ranged", weaponRanged = true },
    }
    local variantIndex
    for variantIndex = 1, table.getn(physicalVariants) do
        local variant = physicalVariants[variantIndex]
        local estimate = self:Estimate({ facts = { kind = "damage", school = 0,
            deliverySubtype = variant.subtype, melee = variant.melee,
            weaponRanged = variant.weaponRanged, usesWeaponSkill = true,
            weaponHand = variant.subtype == "ranged" and "ranged" or "main" } },
            "target", { school = 0 }, state)
        table.insert(rows, { school = 0, name = variant.name,
            multiplier = estimate.multiplier, raw = estimate.raw, source = estimate.source,
            samples = estimate.samples, unknown = estimate.unknown,
            landChance = estimate.landChance, mitigationOnLand = estimate.mitigationOnLand,
            weaponSkill = estimate.weaponSkill, targetDefense = estimate.targetDefense,
            deliveryPriorUnknown = estimate.deliveryPriorUnknown,
            attackPosition = estimate.attackPosition,
            positionKnown = estimate.positionKnown })
    end
    for school = 1, 6 do
        local estimate = self:Estimate({ facts = { kind = "damage", school = school } },
            "target", { school = school }, state)
        table.insert(rows, { school = school, name = estimate.schoolName,
            multiplier = estimate.multiplier, raw = estimate.raw, source = estimate.source,
            samples = estimate.samples, unknown = estimate.unknown,
            landChance = estimate.landChance, mitigationOnLand = estimate.mitigationOnLand })
    end
    return rows
end
