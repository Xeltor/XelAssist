-- Exact, bounded capture for dispels. This module does not choose a class
-- rotation or assign value to named spells: installed-client spell semantics
-- prove which aura types an action can remove, while the live aura API proves
-- that the exact recipient currently carries a matching harmful/helpful aura.
-- Capture is exclusively a RootObservation (or equivalent pre-search capture)
-- operation. Graph time zero is not authorization for live reads because a
-- frame-sliced root search may resume later; search must consume frozen results.
XelAssist.Graph.DispelDecision = {}
local D = XelAssist.Graph.DispelDecision

D.MAX_AURAS = 40
D.MAX_TYPES = 8

local FRIENDLY = { self = true, player = true, pet = true,
    party = true, raid = true, ally = true, friendly = true,
    external = true }
local DISPEL_TYPE = { magic = true, curse = true, disease = true,
    poison = true, enrage = true }
local INFER_RELATION = { self = true, pet = true, party = true,
    raid = true, friendly = true, hostile = true, polymorphic = true }

local function normalized(value)
    if type(value) ~= "string" or value == "" then return nil end
    return string.lower(value)
end

local function validGuid(guid)
    return guid ~= nil and guid ~= "" and guid ~= "0x000000000"
        and guid ~= "0x0000000000000000"
end

local function liveGuid(unit)
    if type(UnitExists) ~= "function" or unit == nil then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 then return nil end
    if guid == nil and type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, unit)
        if not ok then guid = nil end
    end
    if not validGuid(guid) then return nil end
    return guid
end

local function relationFor(descriptor)
    if type(descriptor) ~= "table" then return nil, nil end
    local relation = descriptor.relation
    if relation == "hostile" then return "hostile", "hostile" end
    if not FRIENDLY[relation] then return nil, nil end
    local exact = descriptor.record and descriptor.record.relation or relation
    if exact == "self" or exact == "player" then return "friendly", "self" end
    if exact == "pet" or exact == "party" or exact == "raid" then
        return "friendly", exact
    end
    return "friendly", "friendly"
end

local function friendlyRecord(state, descriptor)
    local snapshot = state and state.friendlies
    if not (snapshot and snapshot.byKey and descriptor.key ~= nil) then
        return nil
    end
    local record = snapshot.byKey[descriptor.key]
    if descriptor.record ~= nil and descriptor.record ~= record then return nil end
    return record
end

local function hostileRecord(state, descriptor)
    local snapshot = state and state.hostiles
    if snapshot and snapshot.byKey then
        if descriptor.key == nil then return nil end
        local record = snapshot.byKey[descriptor.key]
        if descriptor.record ~= nil and descriptor.record ~= record then return nil end
        if snapshot.selectedKey ~= nil then
            if snapshot.selectedKey ~= descriptor.key then return nil end
        elseif not (record and record.selected == true) then return nil end
        return record
    end
    return descriptor.record
end

local function retainedRecipient(state, descriptor, relation)
    if type(state) ~= "table" or not validGuid(descriptor.guid)
        or descriptor.unit == nil then
        return nil, "dispel recipient identity unavailable"
    end
    if relation == "hostile" then
        local record = hostileRecord(state, descriptor)
        if descriptor.unit ~= "target" or descriptor.source ~= "selected"
            or not (record and record.selected == true
                and record.guid == descriptor.guid and record.dead ~= true)
            or state.targetGUID ~= nil and state.targetGUID ~= descriptor.guid then
            return nil, "offensive dispel requires the selected hostile"
        end
        return record
    end
    local record = friendlyRecord(state, descriptor)
    if not (record and record.guid == descriptor.guid
        and record.unit == descriptor.unit and record.dead ~= true) then
        return nil, "friendly dispel recipient is not retained"
    end
    return record
end

local function semanticCompatible(semantic, exactRelation)
    if semantic == "friendly" then return exactRelation ~= "hostile" end
    if semantic == "hostile" then return exactRelation == "hostile" end
    if semantic == "self" then return exactRelation == "self" end
    return semantic == exactRelation
end

-- Discovery may classify the mechanic before a target exists. A recognized
-- dispel opcode and type are sufficient for generic action discovery even when
-- its unit recipient is explicitly polymorphic. This never admits a cast:
-- Capture must still resolve a retained exact recipient and live aura type.
function D:InferKnowledge(spellId)
    local semantics = XelAssist.Game and XelAssist.Game.SpellSemantics
    if not (semantics and type(semantics.Decode) == "function"
        and tonumber(spellId)) then
        return nil, "dispel spell semantics unavailable"
    end
    local ok, descriptor = pcall(semantics.Decode, semantics, tonumber(spellId))
    if not ok or type(descriptor) ~= "table"
        or descriptor.available ~= true or descriptor.passive == true then
        return nil, "dispel spell semantics unavailable"
    end
    local atoms = descriptor.atoms or {}
    if table.getn(atoms) > D.MAX_TYPES then
        return nil, "dispel semantic budget exceeded"
    end
    local types, seen, polymorphic, index = {}, {}, false, nil
    for index = 1, table.getn(atoms) do
        local atom = atoms[index]
        local recipient = type(atom) == "table" and atom.recipient or nil
        local primary = recipient and recipient.primary or nil
        local relation = primary and primary.relation
        local auraType = type(atom) == "table"
            and normalized(atom.dispelType) or nil
        local recipientProven = recipient and primary
            and INFER_RELATION[relation]
            and (recipient.exact == true or relation == "polymorphic"
                and primary.resolved == false)
        if type(atom) == "table" and atom.kind == "dispel"
            and DISPEL_TYPE[auraType]
            and recipientProven and not seen[auraType] then
            seen[auraType] = true
            table.insert(types, auraType)
            if relation == "polymorphic" then polymorphic = true end
        end
    end
    if table.getn(types) == 0 then
        return nil, "no proven dispel semantic atom"
    end
    return { kind = "dispel", inferred = true, dbcDispel = true,
        requiresDispelCapture = true, dispelPolymorphic = polymorphic,
        semanticDispelTypes = types,
        source = "installed-client dispel semantic atom" }, nil
end

local function dispelTypes(action, exactRelation)
    local semantics = XelAssist.Game and XelAssist.Game.SpellSemantics
    if not (semantics and type(semantics.Resolve) == "function"
        and action and tonumber(action.spellId)) then
        return nil, "dispel spell semantics unavailable"
    end
    local ok, descriptor = pcall(semantics.Resolve, semantics,
        action.spellId, { targetRelation = exactRelation })
    if not ok or type(descriptor) ~= "table" or descriptor.complete ~= true
        or descriptor.admissible == false then
        return nil, descriptor and descriptor.reasons
            and descriptor.reasons[1] or "dispel spell semantics incomplete"
    end
    if table.getn(descriptor.atoms or {}) > D.MAX_TYPES then
        return nil, "dispel semantic budget exceeded"
    end
    local types, seen, index = {}, {}, nil
    for index = 1, table.getn(descriptor.atoms or {}) do
        local atom = descriptor.atoms[index]
        if type(atom) == "table" and atom.kind == "dispel" then
            local recipient = atom.recipient
            local primary = recipient and recipient.primary
            local relation = primary and primary.relation
            local auraType = normalized(atom.dispelType)
            if recipient and recipient.exact == true and auraType
                and semanticCompatible(relation, exactRelation)
                and not seen[auraType] then
                seen[auraType] = true
                table.insert(types, auraType)
            end
        end
    end
    if table.getn(types) == 0 then
        return nil, "spell cannot dispel this recipient"
    end
    return types, descriptor
end

local function auraSnapshot(unit, filter)
    local encounter = XelAssist.Game and XelAssist.Game.Encounter
    if not (encounter and type(encounter.Auras) == "function") then
        return nil, "aura observation unavailable"
    end
    local ok, snapshot = pcall(encounter.Auras, encounter, unit, filter)
    if not ok or type(snapshot) ~= "table" or snapshot.available ~= true
        or type(snapshot.list) ~= "table" then
        return nil, "aura observation unavailable"
    end
    if table.getn(snapshot.list) > D.MAX_AURAS then
        return nil, "aura observation exceeds decision budget"
    end
    return snapshot
end

local function observedEffects(snapshot, types)
    local supported, effects, index, auraType = {}, {}, nil, nil
    for index = 1, table.getn(types) do supported[types[index]] = true end
    for index = 1, table.getn(snapshot.list) do
        local aura = snapshot.list[index]
        auraType = type(aura) == "table" and normalized(aura.dispelType) or nil
        local remaining = type(aura) == "table"
            and tonumber(aura.remaining) or nil
        local active = type(aura) == "table" and (aura.remaining == nil
            or remaining ~= nil and remaining > 0)
        if auraType and supported[auraType] and aura.boss ~= true
            and active then
            local effect = effects[auraType]
            if not effect then
                effect = { dispelType = auraType, count = 0, auras = {} }
                effects[auraType] = effect
            end
            effect.count = effect.count + 1
            table.insert(effect.auras, { name = aura.name,
                spellId = aura.spellId, remaining = aura.remaining,
                identityKnown = type(aura.name) == "string"
                    and aura.name ~= "" and tonumber(aura.spellId) ~= nil })
        end
    end
    local ordered = {}
    for index = 1, table.getn(types) do
        local effect = effects[types[index]]
        if effect then
            effect.identityKnown = effect.count == 1
                and effect.auras[1].identityKnown or false
            effect.aura = effect.identityKnown and effect.auras[1] or nil
            table.insert(ordered, effect)
        end
    end
    return ordered
end

function D:Capture(action, state, descriptor)
    if type(state) ~= "table" or tonumber(state.time) ~= 0 then
        return nil, "dispel requires root observation"
    end
    local relation, exactRelation = relationFor(descriptor)
    if not relation then return nil, "dispel recipient relation unavailable" end
    local record, reason = retainedRecipient(state, descriptor, relation)
    if not record then return nil, reason end
    local before = liveGuid(descriptor.unit)
    if before == nil or before ~= descriptor.guid then
        return nil, "dispel recipient changed"
    end
    local types, semanticReason = dispelTypes(action, exactRelation)
    if not types then return nil, semanticReason end
    local filter = relation == "hostile" and "HELPFUL" or "HARMFUL"
    local snapshot
    snapshot, reason = auraSnapshot(descriptor.unit, filter)
    if not snapshot then return nil, reason end
    local after = liveGuid(descriptor.unit)
    if after == nil or after ~= before then return nil, "dispel recipient changed" end
    local effects = observedEffects(snapshot, types)
    if table.getn(effects) == 0 then return nil, "nothing eligible to dispel" end
    return { spellId = tonumber(action.spellId), target = descriptor.unit,
        targetGUID = descriptor.guid, targetKey = descriptor.key,
        targetRelation = relation, exactRelation = exactRelation,
        filter = filter, types = types, effects = effects,
        captured = true, observed = true,
        source = "installed-client dispel semantics plus exact live aura type" }, nil
end

-- Search consumes a frozen capture through this projection and performs no
-- live reads. It records only what the dispel guarantees: at least one aura in
-- each represented type is removed. When several auras share a type, their
-- individual identity remains unknown rather than deleting an arbitrary aura.
function D:Apply(state, decision)
    if type(state) ~= "table" or type(decision) ~= "table"
        or decision.captured ~= true or decision.observed ~= true
        or not validGuid(decision.targetGUID) then
        return false
    end
    local effects = decision.effects
    local count = type(effects) == "table" and table.getn(effects) or 0
    if count == 0 or count > D.MAX_TYPES then return false end
    local projection, index = {}, nil
    for index = 1, count do
        local effect = effects[index]
        local auraType = type(effect) == "table"
            and normalized(effect.dispelType) or nil
        if not auraType then return false end
        local identityKnown = effect.identityKnown == true
            and type(effect.aura) == "table"
        projection[auraType] = { removedLowerBound = 1,
            identityKnown = identityKnown,
            aura = identityKnown and effect.aura or nil }
    end
    state.dispelProjection = state.dispelProjection or {}
    local target = state.dispelProjection[decision.targetGUID]
    if not target then
        target = {}
        state.dispelProjection[decision.targetGUID] = target
    end
    if type(target) ~= "table" then return false end
    local auraType, value
    for auraType, value in pairs(projection) do target[auraType] = value end
    return true
end
