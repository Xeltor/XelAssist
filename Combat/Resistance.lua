-- Target resistance knowledge is learned evidence, not a creature rotation table.
-- Turtle's UnitResistance target values are preferred when their availability
-- is proven. Exact Nampower outcomes provide the normal learned fallback.
XelAssist.Combat.Resistance = { schema = 4, maxProfiles = 256, identities = {},
    sessionProfiles = {}, spellSchools = {}, spellMetadata = {}, numericEvidence = {},
    submissions = {}, recentSubmissions = {}, ownedCasters = {},
    unitResistanceProven = false, nampowerResistanceProven = false }
local R = XelAssist.Combat.Resistance
local HitDelivery = XelAssist.Combat.HitDelivery
local ResistanceMath = XelAssist.Combat.ResistanceMath
local submissionLedger = XelAssist.Combat.ResistanceSubmissions:New(R)

local SCHOOL_NAMES = { [0] = "Physical", [1] = "Holy", [2] = "Fire", [3] = "Nature",
    [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }
local BEAST_LORE_SPELL_ID = 1462
local BINARY_AURAS = { [7] = true, [12] = true, [14] = true, [22] = true,
    [25] = true, [26] = true, [27] = true, [33] = true, [67] = true }
local PERIODIC_DAMAGE_AURAS = { [3] = true, [53] = true, [89] = true }

local function now() return GetTime and GetTime() or 0 end
local function epoch() return time and time() or now() end
local function ageWeight(lastSeen, observedEpoch)
    return ResistanceMath:AgeWeight(lastSeen,
        observedEpoch ~= nil and observedEpoch or epoch())
end
local function expectedPartial(chance)
    return ResistanceMath:ExpectedPartial(chance)
end
local function inverseExpectedPartial(resisted)
    return ResistanceMath:InverseExpectedPartial(resisted)
end
local function innateResistancePoints(level, targetLevel)
    return ResistanceMath:InnateResistancePoints(level, targetLevel)
end
local function projectedLearnedMitigation(multiplier, reduction, level,
    periodic, school)
    return ResistanceMath:ProjectedLearnedMitigation(
        multiplier, reduction, level, periodic, school)
end
local function magicMultiplier(raw, level, penetration, targetLevel, school,
    innate, periodic)
    return ResistanceMath:MagicMultiplier(raw, level, penetration,
        targetLevel, school, innate, periodic)
end
local function binaryResistance(raw, level, penetration)
    return ResistanceMath:BinaryResistance(raw, level, penetration)
end
local function armorMultiplier(raw, level, penetration)
    return ResistanceMath:ArmorMultiplier(raw, level, penetration)
end
local function learnedValues(record, observedEpoch)
    return ResistanceMath:LearnedValues(record, observedEpoch)
end
local function learnedDelivery(record, prior, observedEpoch)
    return ResistanceMath:LearnedDelivery(record, prior, observedEpoch)
end
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
    return XelAssist.Combat.Delivery:Model(facts, metadata)
end

local function deliverySubtypeFor(facts, metadata, model)
    return XelAssist.Combat.Delivery:Subtype(facts, metadata, model)
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
    if not record and XelAssist.Game.Encounter then record = XelAssist.Game.Encounter:Unit(unit, "enemy") end
    record = record or {}
    local creatureId = tonumber(record.creatureId or call(UnitCreatureID, unit))
    if creatureId == 0 then creatureId = nil end
    local level = tonumber(record.level or (UnitLevel and UnitLevel(unit)))
    local isPlayer = record.isPlayer
    if isPlayer == nil and UnitIsPlayer then isPlayer = UnitIsPlayer(unit) and true or false end
    local defenseBase, defenseModifier, defenseObserved
    if isPlayer and UnitDefense then
        local ok, base, modifier = pcall(UnitDefense, unit)
        if ok and type(base) == "number" and base > 0 then
            defenseBase, defenseModifier, defenseObserved = base,
                tonumber(modifier) or 0, true
        end
    end
    local identity = { guid = guid, creatureId = creatureId, level = level,
        instanceType = encounter and encounter.instanceType,
        isPlayer = isPlayer and true or false,
        defenseBase = defenseBase, defenseModifier = defenseModifier,
        defenseObserved = defenseObserved == true, frozen = true }
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
    local penetration = XelAssist.Game.Capabilities and XelAssist.Game.Capabilities.Penetration
        and XelAssist.Game.Capabilities:Penetration() or { spell = nil, armor = nil, known = false }
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
        liveTrusted = trusted, liveSource = source, penetration = penetration,
        observedEpoch = epoch() }
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

local function deliveryKey(context)
    return XelAssist.Combat.Delivery:Key(context)
end

local function updateProfileDelivery(profile, spellId, context, evidence, weight)
    return XelAssist.Combat.Delivery:Record(profile, spellId, context, evidence, weight, epoch())
end
function R:CasterContext(casterGuid, school, state, action, targetGuid)
    local actor = action and action.facts and action.facts.damageActor or action and action.actor
    if not actor and casterGuid then
        local petGuid = state and state.actors and state.actors.pet
            and state.actors.pet.guid
        local playerGuid = state and state.actors and state.actors.player
            and state.actors.player.guid
        if casterGuid == petGuid then actor = "pet"
        elseif casterGuid == playerGuid then actor = "player"
        elseif not state and casterGuid == guidFor("pet") then actor = "pet"
        elseif not state and casterGuid == guidFor("player") then actor = "player" end
    end
    local owned = casterGuid and self.ownedCasters[casterGuid]
    if not actor and type(owned) == "table" then actor = owned.actor end
    actor = actor or "player"
    local level
    if actor == "pet" then
        if state then level = state.actors and state.actors.pet
            and state.actors.pet.level
        else level = type(owned) == "table" and owned.level
            or casterGuid == guidFor("pet") and UnitLevel and UnitLevel("pet") end
    elseif state then level = state.playerLevel
    else level = UnitLevel and UnitLevel("player") end
    local penetration, known = nil, false
    if actor == "player" then
        local values = state and state.targetResistance and state.targetResistance.penetration
        if not state and not values and XelAssist.Game.Capabilities
            and XelAssist.Game.Capabilities.Penetration then
            values = XelAssist.Game.Capabilities:Penetration()
        end
        if values then
            penetration = school == 0 and values.armor or values.spell
            known = values.known == true and penetration ~= nil
        end
    end
    local rounded = known and math.floor((tonumber(penetration) or 0) / 5 + 0.5) * 5
    local hitBonuses = HitDelivery:Bonuses(state, actor)
    local hitToken = HitDelivery:Token(hitBonuses)
    local behind, positionSource
    if state then
        if actor == "pet" then
            behind = state.actors and state.actors.pet and state.actors.pet.behind
        else behind = state.playerBehindTarget end
        if type(behind) == "boolean" then positionSource = "state UnitXP geometry" end
    end
    if not state and type(behind) ~= "boolean" and targetGuid
        and targetGuid == guidFor("target") and XelAssist.Game.Capabilities
        and XelAssist.Game.Capabilities.Geometry then
        local unit = actor == "pet" and "pet" or "player"
        local ok, geometry = pcall(XelAssist.Game.Capabilities.Geometry,
            XelAssist.Game.Capabilities, unit, "target")
        if ok and type(geometry) == "table" and type(geometry.behind) == "boolean" then
            behind, positionSource = geometry.behind, geometry.source or "live geometry"
        end
    end
    return { actor = actor, level = tonumber(level), penetration = tonumber(penetration),
        hitBonuses = hitBonuses,
        weaponSkills = state and state.weaponSkills or nil,
        frozenStateEvidence = state ~= nil,
        behindTarget = behind, positionKnown = type(behind) == "boolean",
        positionSource = positionSource or "position unavailable",
        penetrationKnown = known, key = actor .. ":l" .. tostring(level or 0)
            .. ":p" .. (rounded and tostring(rounded) or "?")
            .. (hitToken and ":h" .. hitToken or "") }
end

function R:PhaseContext(context, phase)
    return { actor = context.actor, level = context.level, penetration = context.penetration,
        hitBonuses = context.hitBonuses, weaponSkills = context.weaponSkills,
        frozenStateEvidence = context.frozenStateEvidence,
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
        hitBonuses = context.hitBonuses,
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
    if not (targetGuid and school and XelAssist.Combat.TargetModifiers
        and XelAssist.Combat.TargetModifiers.Active and XelAssist.Game.Encounter
        and XelAssist.Game.Encounter.Snapshot) then return 0, false end
    local encounter = XelAssist.Game.Encounter:Snapshot()
    if not (encounter and encounter.target and encounter.target.guid == targetGuid) then
        return 0, false
    end
    local reductions = XelAssist.Combat.TargetModifiers:Active(encounter, nil)
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
        -- The pet identity itself is a stable session-local context key. It may
        -- be an opaque SuperWoW value and must not be converted for storage.
        return guidFor("pet")
    end
    return nil
end

function R:SweepSubmissions()
    submissionLedger:Sweep()
end

function R:Submitted(action, targetGuid, tooltip, refresh)
    if not action or not action.spellId or not targetGuid then return end
    self:SweepSubmissions()
    local actor = action.facts and action.facts.damageActor or action.actor or "player"
    local casterGuid = guidFor(actor == "pet" and "pet" or "player")
    if casterGuid then
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
        submissionLedger:Put(targetGuid, casterGuid, action.spellId, {
            at = submittedAt,
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
            periodic = action.facts and (action.facts.kind == "dot"
                or action.facts.channel or action.facts.repeatablePersistentDamage)
                and true or false })
    end
end

function R:Submission(targetGuid, casterGuid, spellId)
    return submissionLedger:Get(targetGuid, casterGuid, spellId)
end

function R:TakeSubmission(targetGuid, casterGuid, spellId, force)
    return submissionLedger:Take(targetGuid, casterGuid, spellId, force)
end

function R:RecentSubmission(targetGuid, casterGuid, spellId)
    return submissionLedger:Recent(targetGuid, casterGuid, spellId)
end

-- Terminal cast failures must retire the graph's evidence reservation as well
-- as the UI tap guard. Missing-target Nampower failure events are handled by
-- matching the owned caster and spell id across the bounded submission table.
function R:CancelSubmission(spellId, casterGuid, targetGuid)
    return submissionLedger:Cancel(spellId, casterGuid, targetGuid)
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
    local delivery = XelAssist.Combat.Delivery:SpellTraits(dmgClass, attributesEx3Raw,
        rangeIndex, equippedItemClass)
    local facts = { school = school, binary = binary,
        periodic = periodic, directDamage = directDamage,
        dmgClass = delivery.dmgClass, rangeIndex = delivery.rangeIndex,
        combatRange = delivery.combatRange,
        equippedItemClass = delivery.equippedItemClass,
        usesWeaponSkill = delivery.usesWeaponSkill,
        deliveryModel = delivery.deliveryModel,
        deliveryModelKnown = delivery.deliveryModelKnown,
        deliveryModelSource = delivery.deliveryModelSource,
        deliverySubtype = delivery.deliverySubtype,
        normalRanged = delivery.normalRanged, alwaysHit = delivery.alwaysHit,
        alwaysHitKnown = delivery.alwaysHitKnown,
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
    if targetGuid == nil or spellId == nil then return end
    local bySpell = self.numericEvidence[targetGuid]
    if not bySpell then bySpell = {}; self.numericEvidence[targetGuid] = bySpell end
    bySpell[spellId] = now()
end
function R:NumericEventsEnabled()
    -- Nampower 4.6 emits damage and miss events unconditionally. The old
    -- helper comments naming per-stream CVars do not match the installed DLL.
    return (GetNampowerVersion or QueueSpellByName) and true or false
end
function R:ShouldTrainChat(targetGuid, spellId)
    if self:NumericEventsEnabled() then return false end
    local bySpell = targetGuid ~= nil and self.numericEvidence[targetGuid] or nil
    local at = bySpell and spellId ~= nil and bySpell[spellId] or nil
    return not at or now() - at > 1
end

-- Nampower exposes the resolved white-swing attack table directly. Keep this
-- evidence separate from damage mitigation: totalDamage is already downstream
-- of Armor, block, absorb, resistance, crit and glancing calculations, so it
-- cannot be inverted into a clean mitigation sample. It can, however, teach
-- the exact effective delivery outcome for the hand/skill/Defense/position
-- fingerprint used by the graph.
local function autoAttackDeliveryEvidence(totalDamage, hitInfo, victimState)
    return XelAssist.Combat.Delivery:AutoAttackEvidence(totalDamage, hitInfo, victimState)
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
    submissionLedger:ForgetRecent(targetGuid, casterGuid, spellId)
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

function R:School(action, tooltip, state)
    local facts = action and action.facts or {}
    local metadata = action and action.resistanceMetadata
        or action and action.spellId and self.spellMetadata[action.spellId]
    if not metadata and not (state
        or action and action.resistanceMetadataCaptured) then
        metadata = action and action.spellId
            and self:SpellFacts(action.spellId) or {}
    end
    metadata = metadata or {}
    local learned = action and action.spellId and self.spellSchools[action.spellId]
    if facts.mixedDamage and not facts.damageComponents then
        return nil, false, false, "mixed damage components unresolved"
    end
    local school
    if facts.dynamicSchool then
        local context = action and action.resistanceDynamicContext
        if not (state or action
            and action.resistanceDynamicContextCaptured) then
            context = self:DynamicContext(facts.dynamicSchool)
        end
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

local function baseSpellHit(attackerLevel, targetLevel, targetIsPlayer)
    return XelAssist.Combat.Delivery:BaseSpellHit(attackerLevel, targetLevel, targetIsPlayer)
end

function R:PhysicalDeliveryContext(action, metadata, context, identity)
    return XelAssist.Combat.Delivery:PhysicalContext(action, metadata, context, identity)
end

function R:ApplyPhysicalDeliveryContext(context, physical)
    return XelAssist.Combat.Delivery:ApplyPhysicalContext(context, physical)
end

local function basePhysicalHit(attackerLevel, targetLevel, targetIsPlayer)
    return XelAssist.Combat.Delivery:BasePhysicalHit(attackerLevel, targetLevel, targetIsPlayer)
end
function R:EstimateComponent(action, target, tooltip, state, component)
    local componentAction = { name = action.name, rank = action.rank, actor = action.actor,
        spellId = action.spellId,
        resistanceMetadata = action.resistanceMetadata,
        resistanceMetadataCaptured = action.resistanceMetadataCaptured,
        resistanceDynamicContext = action.resistanceDynamicContext,
        resistanceDynamicContextCaptured = action.resistanceDynamicContextCaptured,
        facts = { kind = action.facts.kind,
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

local function projectedActionFacts(action, tooltip, state)
    local facts = action and action.facts or {}
    local marker = tooltip and tooltip.warlockNightfallGuaranteedHit
    if type(marker) ~= "table" or marker.exact ~= true
        or marker.auraSpellId ~= 17941 or not action
        or marker.spellId ~= action.spellId
        or facts.warlockNightfallConsumerExact ~= true
        or not (state and state.warlockNightfall
            and state.warlockNightfall.active == true) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts) do out[key] = value end
    out.alwaysHit = true
    return out
end

function R:Estimate(action, target, tooltip, state, componentCall)
    local facts = projectedActionFacts(action, tooltip, state)
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
                spellId = action.spellId,
                resistanceMetadata = action.resistanceMetadata,
                resistanceMetadataCaptured = action.resistanceMetadataCaptured,
                resistanceDynamicContext = action.resistanceDynamicContext,
                resistanceDynamicContextCaptured = action.resistanceDynamicContextCaptured,
                facts = {} }
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

    local school, ignoresArmor, ignoreResistances, schoolSource =
        self:School(action, tooltip, state)
    local metadata = action and action.resistanceMetadata
        or action and action.spellId and self.spellMetadata[action.spellId]
    if not metadata and not (state
        or action and action.resistanceMetadataCaptured) then
        metadata = action and action.spellId
            and self:SpellFacts(action.spellId) or {}
    end
    metadata = metadata or {}
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
    local evidenceEpoch = state and (tonumber(state.resistanceEpoch)
        or snapshot and tonumber(snapshot.observedEpoch) or 0) or nil
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
    local raw, identity = live and tonumber(live[school]), snapshot and snapshot.identity
    if not identity and not state then
        local currentGuid = guidFor("target")
        identity = currentGuid and self.identities[currentGuid] or self:Identity("target")
    end
    if not identity then result.targetIdentityUnknown = true end
    local profile = self:Profile(identity, false)
    local rawSource = live and (snapshot.liveSource or "live target resistance") or nil
    local cached = profile and profile.raw and profile.raw[school]
    if raw == nil and cached and cached.kind == "base"
        and ageWeight(cached.lastSeen, evidenceEpoch) > 0.05 then
        raw, rawSource = tonumber(cached.value), "cached Turtle base resistance"
    end
    local rawKey = tostring(school) .. ":" .. tostring(context.key)
    local rawRecord = profile and profile.inferredRawContexts
        and profile.inferredRawContexts[rawKey]
    local rawSamples = rawRecord and (rawRecord.samples or 0)
        * ageWeight(rawRecord.lastSeen, evidenceEpoch) or 0
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
    local learnedMitigation, ignoredLanding, mitigationSamples =
        learnedValues(mitigationRecord, evidenceEpoch)
    local ignoredMitigation, learnedResistanceLanding, landSamples =
        learnedValues(landRecord, evidenceEpoch)
    local mitigationFromBaseline, landFromBaseline = false, false
    if mitigationContext.key ~= baselineMitigationContext.key and not learnedMitigation then
        local key = tostring(school) .. ":" .. tostring(baselineMitigationContext.key)
        local baseline = profile and profile.contexts and profile.contexts[key]
        learnedMitigation, ignoredLanding, mitigationSamples =
            learnedValues(baseline, evidenceEpoch)
        mitigationFromBaseline = learnedMitigation ~= nil
    end
    if landContext.key ~= baselineLandContext.key and not learnedResistanceLanding then
        local key = tostring(school) .. ":" .. tostring(baselineLandContext.key)
        local baseline = profile and profile.contexts and profile.contexts[key]
        ignoredMitigation, learnedResistanceLanding, landSamples =
            learnedValues(baseline, evidenceEpoch)
        landFromBaseline = learnedResistanceLanding ~= nil
    end
    local spellContextKey = action and action.spellId and tostring(action.spellId)
        .. ":" .. tostring(school) .. ":" .. tostring(landContext.key)
    local combinedRecord = spellContextKey and profile and profile.spells
        and profile.spells[spellContextKey]
    local ignoredCombinedMitigation, learnedCombined, combinedSamples =
        learnedValues(combinedRecord, evidenceEpoch)
    local combinedFromBaseline = false
    if landContext.key ~= baselineLandContext.key and not learnedCombined and action
        and action.spellId then
        local baselineKey = tostring(action.spellId) .. ":" .. tostring(school)
            .. ":" .. tostring(baselineLandContext.key)
        combinedRecord = profile and profile.spells and profile.spells[baselineKey]
        ignoredCombinedMitigation, learnedCombined, combinedSamples =
            learnedValues(combinedRecord, evidenceEpoch)
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
    else
        priorHit = HitDelivery:MagicPrior(baseSpellHit(attackerLevel, targetLevel,
            identity and identity.isPlayer), context.hitBonuses)
    end
    local learnedOrdinaryLanding, deliverySamples = learnedDelivery(
        deliveryRecord, priorHit, evidenceEpoch)
    local spellDeliveryKey = action and action.spellId
        and tostring(action.spellId) .. ":" .. currentDeliveryKey
    local spellDeliveryRecord = spellDeliveryKey and profile and profile.spellDeliveryContexts
        and profile.spellDeliveryContexts[spellDeliveryKey]
    -- A single exact outcome is written to both the general delivery context
    -- and its spell-specific context.  They are alternate estimates, not two
    -- independent rolls; calculate both from the same prior and prefer the
    -- exact spell estimate when it exists.
    local spellLanding, spellDeliverySamples = learnedDelivery(
        spellDeliveryRecord, priorHit, evidenceEpoch)
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
    if deliveryModel == "magic" then
        HitDelivery:ApplyMagicResult(result, context.hitBonuses)
    end
    if physicalContext then
        HitDelivery:ApplyPhysicalResult(result, physicalContext, alwaysHit)
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
        local unresolvedHit = deliveryModel == "magic" and context.hitBonuses
            and not context.hitBonuses.totalKnown
        local deliveryUnknown = (physicalContext and physicalContext.unknown or unresolvedHit)
            and (deliverySamples or 0) < 4
        local classificationUnknown = deliveryModelKnown ~= true
        result.deliveryPriorUnknown = classificationUnknown or deliveryUnknown and true
            or physicalContext and physicalContext.unknown or unresolvedHit or false
        result.unknown = not mitigationKnown or classificationUnknown
            or result.targetIdentityUnknown
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
            deliverySource = deliverySource
                .. HitDelivery:PhysicalSuffix(physicalContext)
            result.source = tostring(result.source) .. "; " .. deliverySource
        elseif deliveryModel == "magic" and context.hitBonuses then
            HitDelivery:AppendMagicSource(result, context.hitBonuses)
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
