-- Target-aura presence and refresh eligibility. Root observations own mutable
-- client reads; projected branches consume only recipient-local aura records.
XelAssist.Graph.TargetAuras = {}
local A = XelAssist.Graph.TargetAuras
local State = XelAssist.Graph.State

local APPLICATION_BLOCK_THRESHOLD = 0.75

local function refreshWindow(action, aura)
    -- Vanilla periodic damage has no rollover/pandemic window. Reapplying it
    -- before expiry resets the tick clock and can erase the final tick, so an
    -- observed or projected owned DoT remains active for its full lifetime.
    -- Other aura kinds retain the generic bounded refresh window.
    if action and action.facts and action.facts.kind == "dot" then return 0 end
    return math.max(1.5, (tonumber(aura and aura.duration) or 0) * 0.2)
end

local function observed(state, action, descriptor)
    local root = XelAssist.Graph.RootObservation
    if not root then return nil, "absent" end
    return root:Aura(state, action, descriptor)
end

function A:Frozen(action, state, descriptor)
    local active, status = observed(state, action, descriptor)
    if status ~= "known" and status ~= "absent" then
        return true, "aura evidence unknown"
    end
    return active and true or false, status
end

local function friendlyActive(action, state, descriptor)
    local record = descriptor and descriptor.record
        or descriptor and State:FriendlyByKey(state, descriptor.key)
    if not record then return false end
    local aura = record.auras and record.auras[action.name]
    if not aura and record.absorbs and record.absorbs[action.name] then
        aura = record.absorbs[action.name]
    end
    if aura then
        if type(aura) ~= "table" then return true end
        local probability = tonumber(aura.applicationProbability) or 1
        local refresh = refreshWindow(action, aura)
        if probability >= APPLICATION_BLOCK_THRESHOLD
            and (aura.remaining == nil or aura.remaining > refresh) then
            return true
        end
    end
    if (state.time or 0) <= 0 then
        local active, status = A:Frozen(action, state, descriptor)
        if status ~= "absent" then
            return active, status ~= "known" and status or nil
        end
        if XelAssist.Game.Capabilities.UnitHasBuff then
            return XelAssist.Game.Capabilities:UnitHasBuff(
                descriptor.unit, action.name)
        end
    end
    return false
end

function A:Active(action, state, descriptor)
    local mechanics = XelAssist.Graph.ClassMechanics
    if mechanics and type(mechanics.AuraActive) == "function" then
        local exact, handled, reason = mechanics:AuraActive(
            action, state, descriptor)
        if handled then return exact, reason end
    end
    if descriptor and descriptor.relation ~= "hostile" then
        return friendlyActive(action, state, descriptor)
    end
    local future = state.auras[action.name]
    if action.facts.stackable then
        local futureProbability = type(future) == "table"
            and tonumber(future.applicationProbability) or 1
        local stacks = futureProbability >= APPLICATION_BLOCK_THRESHOLD
            and type(future) == "table"
            and tonumber(future.expectedStacks or future.stacks) or 0
        local live = state.targetAuras and state.targetAuras[action.name]
        local liveProbability = live
            and (tonumber(live.applicationProbability) or 1) or 0
        stacks = math.max(stacks or 0,
            liveProbability >= APPLICATION_BLOCK_THRESHOLD
                and (tonumber(live.stacks) or 1) or 0)
        return stacks >= action.facts.stackable
            and not action.facts.refreshAtStackCap
    end
    if future then
        if type(future) ~= "table" then return true end
        local probability = tonumber(future.applicationProbability) or 1
        local refresh = refreshWindow(action, future)
        if probability >= APPLICATION_BLOCK_THRESHOLD
            and (future.remaining == nil or future.remaining > refresh) then
            return true
        end
    end
    local aura = state.targetAuras and state.targetAuras[action.name]
    if not aura and descriptor and descriptor.unit == "target"
        and (state.time or 0) <= 0 then
        local active, status = self:Frozen(action, state, descriptor)
        if status ~= "absent" then
            return active, status ~= "known" and status or nil
        end
        return XelAssist.Game.Capabilities:TargetHasDebuff(action.name)
    end
    if not aura then return false end
    if (tonumber(aura.applicationProbability) or 1)
        < APPLICATION_BLOCK_THRESHOLD then return false end
    if action.facts.kind == "dot" and aura.mine == false then return false end
    local refresh = refreshWindow(action, aura)
    if aura.remaining ~= nil and aura.remaining <= refresh then return false end
    return true
end
