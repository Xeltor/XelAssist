-- Recipient enumeration is separate from legality: this module identifies the
-- exact cast recipient for each live-discovered action without scoring it.
XelAssist.Graph.TargetSelection = {}
local T = XelAssist.Graph.TargetSelection
local S = XelAssist.Graph.State

local function friendlyDescriptor(state, record)
    if not record then return nil end
    return S:Descriptor(record.unit, record.relation or "friendly",
        record.source, record.guid, record.key, record)
end

local function unitDescriptor(state, unit, relation, source)
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
    if relation == "hostile" then
        local ref = state.targetRef
        return { unit = unit, relation = relation, source = source,
            guid = ref and ref.guid or state.targetGUID,
            key = ref and ref.guid or state.targetGUID or "target",
            targetRef = ref }
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
    return kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff"
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
            local unit = XelAssist.Game.Actors:DispelTarget(state)
            if not unit then return nil end
            if unit == "target" and state.hostile then
                return unitDescriptor(state, unit, "hostile", "selected")
            end
            return unitDescriptor(state, unit, "friendly", "dispel")
        end
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
    return out
end
