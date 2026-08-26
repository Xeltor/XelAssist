-- Recipient enumeration is separate from legality: this module identifies the
-- exact cast recipient for each live-discovered action without scoring it.
XelAssist.Graph.TargetSelection = {}
local T = XelAssist.Graph.TargetSelection
local S = XelAssist.Graph.State
local HostilePolicy = XelAssist.Graph.HostileTargetPolicy

local function friendlyDescriptor(state, record)
    if not record then return nil end
    return S:Descriptor(record.unit, record.relation or "friendly",
        record.source, record.guid, record.key, record)
end

local function hostileDescriptor(state)
    local snapshot = state and state.hostiles
    local record
    if snapshot and snapshot.byKey then
        local key = snapshot.selectedKey
            or snapshot.byUnit and snapshot.byUnit.target
        record = key ~= nil and snapshot.byKey[key] or nil
        if not record then
            local i, candidate
            for i = 1, table.getn(snapshot.order or {}) do
                candidate = snapshot.byKey[snapshot.order[i]]
                if candidate and candidate.selected then
                    record = candidate
                    break
                end
            end
        end
    end
    if not record and snapshot and type(snapshot.selected) == "table" then
        record = snapshot.selected
    end
    local legacy = state and state.targetRef
    local recordRef = record and record.targetRef
    local guid = record and (record.guid or recordRef and recordRef.guid)
        or legacy and legacy.guid or state and state.targetGUID
    local priority = record and (record.priority
        or recordRef and recordRef.priority) or legacy and legacy.priority
    local key = record and (record.key or guid) or guid or "target"
    local ref = guid ~= nil and { key = key, unit = "target", guid = guid,
        relation = "hostile", source = "selected", priority = priority } or nil
    return { unit = "target", relation = "hostile", source = "selected",
        guid = guid, key = key, record = record, targetRef = ref }
end

local function observedHostileDescriptor(record)
    local engagement = record and record.engagement
    local unit = engagement and engagement.unit or record and record.unit
    if not (record and unit and record.guid ~= nil) then return nil end
    local ref = { key = record.key, unit = unit, guid = record.guid,
        relation = "hostile", source = "engaged",
        observedSource = record.source,
        engagement = engagement and engagement.reason,
        priority = record.priority }
    return { unit = unit, relation = "hostile", source = "engaged",
        guid = record.guid, key = record.key, record = record, targetRef = ref }
end

local function hostileDescriptors(action, state, selected)
    local out = {}
    selected = selected or hostileDescriptor(state)
    if selected and selected.guid ~= nil then table.insert(out, selected) end
    local snapshot = state and state.hostiles
    if not (HostilePolicy and snapshot and snapshot.order
        and snapshot.byKey) then return out end
    local i
    for i = 1, table.getn(snapshot.order) do
        local key, record = snapshot.order[i], nil
        record = snapshot.byKey[key]
        if record and not record.selected
            and HostilePolicy:Eligible(action, state, record) then
            local descriptor = observedHostileDescriptor(record)
            if descriptor then table.insert(out, descriptor) end
        end
    end
    return out
end

local function unitDescriptor(state, unit, relation, source)
    if relation == "hostile" then return hostileDescriptor(state) end
    local record = S:FriendlyByUnit(state, unit)
    if record then return friendlyDescriptor(state, record) end
    if unit == "pet" and state.actors and state.actors.pet then
        local pet = state.actors.pet
        local ref = pet.actorRef or pet.guid ~= nil and { unit = "pet",
            guid = pet.guid, relation = "pet", source = source } or nil
        return { unit = unit, relation = relation, source = source,
            guid = ref and ref.guid, key = ref and ref.guid or "pet",
            record = pet, targetRef = ref }
    end
    return S:Descriptor(unit, relation, source, nil, nil, nil)
end

local function effectDescriptor(action, state, recipient)
    local effectTarget = action.facts and action.facts.effectTarget
    if not (recipient and effectTarget == "target") then return recipient end
    local effect = unitDescriptor(state, "target", "hostile", "selected")
    effect.castUnit = recipient.unit
    effect.castRelation = recipient.relation
    effect.castSource = recipient.source
    effect.castGuid = recipient.guid
    effect.castTargetRef = recipient.targetRef
    return effect
end

function T:VariableFriendlyAction(action)
    if action.actor == "pet" or action.executor == "item" or action.facts.self then
        return false
    end
    local kind = action.facts.kind
    return kind == "heal" or kind == "hot" or kind == "absorb"
        or kind == "buff" or kind == "dispel"
end

function T:Fixed(action, state)
    local facts, kind = action.facts, action.facts.kind
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Actions then
        local unit, relation, source = XelAssist.Game.Pets.Actions:FixedTarget(action)
        if unit then
            return effectDescriptor(action, state,
                unitDescriptor(state, unit, relation, source))
        end
    end
    if action.actor == "pet" then
        if facts.petThreatDrop then
            return unitDescriptor(state, "pet", "pet", "companion")
        end
        if kind == "petHeal" then
            return unitDescriptor(state, "pet", "pet", "companion")
        end
        if facts.petSacrifice then
            return unitDescriptor(state, "player", "self", "self")
        end
        if kind == "buff" or kind == "absorb" then
            if facts.self then
                return unitDescriptor(state, "pet", "pet", "companion")
            end
            return friendlyDescriptor(state, S:PrimaryFriendly(state))
        end
        if kind == "command" then
            if action.command == "attack" then
                return unitDescriptor(state, "target", "hostile", "selected")
            end
            return unitDescriptor(state, "pet", "pet", "companion")
        end
        if kind == "dispel" then
            return unitDescriptor(state, "target", "hostile", "selected")
        end
        return unitDescriptor(state, "target", "hostile", "selected")
    end
    if facts.targetLocalThreatDrop then
        return unitDescriptor(state, "target", "hostile", "selected")
    end
    if kind == "summon" or facts.self or kind == "defensive"
        or kind == "resource" or kind == "threatDrop" or kind == "modifier" then
        return unitDescriptor(state, "player", "self", "self")
    end
    return unitDescriptor(state, "target", "hostile", "selected")
end

function T:Targets(action, state)
    if not self:VariableFriendlyAction(action) then
        local fixed = self:Fixed(action, state)
        if action.facts.targetLocalThreatDrop then
            return fixed and { fixed } or {}
        end
        if fixed and fixed.relation == "hostile" then
            local hostile = hostileDescriptors(action, state, fixed)
            if table.getn(hostile) > 0 then return hostile end
        end
        return fixed and { fixed } or {}
    end
    local out, i, order = {}, nil,
        XelAssist.Game.Friendlies:TargetKeys(state.friendlies, action)
    for i = 1, table.getn(order) do
        local record = S:FriendlyByKey(state, order[i])
        if record and not record.dead then
            table.insert(out, friendlyDescriptor(state, record))
        end
    end
    -- Installed-client semantics decide whether a dispel is friendly-only,
    -- hostile-only or polymorphic. Enumerate both retained recipient classes
    -- here; the frozen per-edge capture rejects every incompatible relation.
    if action.facts.kind == "dispel" then
        local hostile = hostileDescriptor(state)
        if hostile and hostile.guid ~= nil then table.insert(out, hostile) end
    end
    return out
end
