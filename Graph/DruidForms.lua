-- Graph adapter for exact Druid form evidence.  It translates a sealed action
-- cost into hidden-mana payment and keeps generic resource code unaware of
-- multi-power storage.  Form strategy remains an outcome of later graph edges.
XelAssist.Graph.DruidForms = {}
local D = XelAssist.Graph.DruidForms
local Forms = XelAssist.Game.Player.DruidFormState
local ShiftResources = XelAssist.Graph.DruidShiftResources
local BearThreat = XelAssist.Graph.DruidBearThreat
local CatThreat = XelAssist.Graph.DruidCatThreat
local FrenziedRegeneration = XelAssist.Graph.DruidFrenziedRegeneration

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

-- RootObservation delegates here so synthetic cancellation never reaches a
-- spell tooltip slot, while ordinary actions keep the established actor path.
function D:CaptureFacts(action, actors)
    local facts = action and action.facts or {}
    if facts.druidFormCancel then return Forms:CancelFacts(), true end
    if not (actors and type(actors.Facts) == "function") then return nil, false end
    local ok, captured = pcall(actors.Facts, actors, action)
    if not ok or type(captured) ~= "table" then return nil, false end
    if not facts.druidShapeshift then return captured, true end
    ok, captured = pcall(Forms.CaptureFacts, Forms, action, captured)
    return ok and type(captured) == "table" and captured or nil,
        ok and type(captured) == "table" or false
end

function D:Sync(state)
    local snapshot = state and state.druidFormState
    if not (snapshot and snapshot.available == true and snapshot.powers) then
        return false
    end
    local slot = snapshot.powers[snapshot.primaryType]
    local exact = slot and slot.currentKnown == true
        and slot.maximumKnown == true
        and tonumber(slot.current) ~= nil and tonumber(slot.maximum) ~= nil
    local minimum, minimumKnown
    if not exact and ShiftResources then
        minimum, minimumKnown = ShiftResources:ResourceFloor(snapshot)
    end
    state.resourceType = snapshot.primaryType
    state.resource = exact and slot.current or minimumKnown and minimum or 0
    state.resourceMax = exact and slot.maximum or minimumKnown
        and (tonumber(slot.priorObservedMaximum) or minimum) or 0
    state.playerResourceExact = exact and true or false
    state.playerResourceMinimumExact = not exact and minimumKnown and true or nil
    state.druidDestinationPowerUnknown = exact and nil or true
    state.playerForm = state.playerForm or {}
    state.playerForm.available, state.playerForm.formID = true,
        snapshot.formID
    state.playerForm.source = snapshot.projected
        and "projected exact Druid form transition" or snapshot.source
    if not exact or snapshot.primaryType ~= Forms.ENERGY then
        state.playerResourceClock = nil
    end
    local actor = state.actors and state.actors.player
    if actor then
        actor.resourceType = snapshot.primaryType
        actor.resource = state.resource
        actor.resourceMax = state.resourceMax
        actor.resourceExact = state.playerResourceExact
        actor.resourceMinimumExact = state.playerResourceMinimumExact
    end
    if state.role == "auto" then
        local form = Forms.FORMS[snapshot.formID]
        state.tank = form and form.tank and true or false
    end
    return true
end

function D:Attach(state)
    if not (Forms and Forms.Snapshot) then return false end
    local snapshot = Forms:Snapshot()
    if not (snapshot and snapshot.available == true) then return false end
    state.druidFormState = snapshot
    if ShiftResources then ShiftResources:Attach(state) end
    local synced = self:Sync(state)
    if synced and BearThreat then BearThreat:Attach(state) end
    if synced and CatThreat then CatThreat:Attach(state) end
    return synced
end

function D:Prepare(action, state, tooltip)
    local facts = action and action.facts or {}
    local evidence = tooltip and tooltip.druidFormEvidence
    local handled = evidence and evidence.recognized == true
        or facts.druidFormCancel == true
    if not handled then return tooltip, nil, false end
    local snapshot = state and state.druidFormState
    if not snapshot then return nil, "Druid form state unavailable", true end
    local projection, reason
    if facts.druidFormCancel then
        projection, reason = Forms:PrepareCancel(snapshot)
    else
        projection, reason = Forms:PrepareShift(action, snapshot, evidence)
    end
    if not projection then return nil, reason, true end
    if projection.kind == "shift" and ShiftResources then
        local bound = ShiftResources:Bind(snapshot, projection)
        if type(bound) == "table" then projection = bound end
    end
    if FrenziedRegeneration then
        local blocker, claimed = FrenziedRegeneration:FormBlocker(
            state, projection)
        if claimed and blocker then return nil, blocker, true end
    end
    local prepared = shallow(tooltip)
    prepared.cost = projection.cost.cost
    prepared.powerType = Forms.MANA
    prepared.druidFormTransition = projection
    return prepared, nil, true
end

function D:PrepareLegal(action, state, tooltip)
    local prepared, reason, handled = self:Prepare(action, state, tooltip)
    if handled then return prepared, reason end
    local snapshot = state and state.druidFormState
    local required = tooltip and tonumber(tooltip.powerType)
    if snapshot and snapshot.available == true and required ~= nil
        and required ~= snapshot.primaryType then
        return nil, "Druid form resource type"
    end
    return tooltip, nil
end

function D:Consume(state, candidate, context)
    local projection = candidate and candidate.druidFormTransition
    if not projection then return nil end
    if not (state and state.druidFormState
        and Forms:Spend(state.druidFormState, projection)) then return false end
    self:Sync(state)
    if context then context.druidFormCostPaid = true end
    return true
end

function D:Apply(state, candidate, context)
    local projection = candidate and candidate.druidFormTransition
    if not projection then return false end
    if not (context and context.druidFormCostPaid == true
        and state and state.druidFormState
        and Forms:Apply(state.druidFormState, projection, true)) then
        return false
    end
    if ShiftResources then
        ShiftResources:Apply(state.druidFormState, projection)
    end
    local synced = self:Sync(state)
    if synced and BearThreat then BearThreat:AfterForm(state) end
    if synced and CatThreat then CatThreat:AfterForm(state) end
    if synced and FrenziedRegeneration then
        FrenziedRegeneration:AfterForm(state, projection)
    end
    return synced
end

function D:CancelUsable()
    return Forms:CancelUsable()
end

function D:DispatchCancel(plan)
    return Forms:DispatchCancel(plan)
end
