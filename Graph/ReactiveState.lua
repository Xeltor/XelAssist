-- Graph policy for player reactive requirements. Exact live aura-state bits
-- may legalize an immediate edge. Without a proven activation timestamp they
-- never survive a wait or preceding action, and chosen reactives are consumed
-- branch-locally instead of receiving a fabricated cooldown.
XelAssist.Graph.ReactiveState = {}
local R = XelAssist.Graph.ReactiveState
local Evidence = XelAssist.Game.Player.ReactiveEvidence

local function copied(values)
    local out, key, value = {}, nil, nil
    for key, value in pairs(values or {}) do out[key] = value end
    return out
end

local function rootUsability(state, action)
    local root = XelAssist.Graph.RootObservation
    if not (root and root.Usability) then return nil, nil end
    local record, status = root:Usability(state, action)
    if status ~= "known" or type(record) ~= "table"
        or record.known ~= true then return nil, nil end
    if record.usable == true then
        return true, "exact root spell usability"
    end
    if record.usable == false then
        return false, record.reason or "exact root spell usability"
    end
    return nil, nil
end

function R:Evaluate(action, state, actionStart)
    local facts = action and action.facts or {}
    if not facts.reactive or (action.actor or "player") ~= "player" then
        return nil, false, nil
    end
    if not Evidence then
        return "reactive state unknown", true, nil
    end
    local available, stateID, source = Evidence:Available(
        state and state.playerReactive, action)
    local fallback = false
    if available == nil then
        available, source = rootUsability(state, action)
        fallback = available ~= nil
    end
    local detail = { stateID = stateID, source = source,
        exact = available ~= nil, usabilityFallback = fallback }
    if available == nil then return "reactive state unknown", true, detail end
    local consumed = state.reactiveConsumed and (fallback
        and state.reactiveConsumed.rootUsability
        or stateID and state.reactiveConsumed[stateID])
    if not available or consumed then
        return "reactive state inactive", true, detail
    end
    local now = tonumber(state.time) or 0
    actionStart = tonumber(actionStart) or now
    if actionStart > now + 0.0001 or now > 0.0001 then
        detail.rootOnly = true
        return "reactive window phase unknown", true, detail
    end
    detail.available, detail.rootOnly = true, true
    return nil, true, detail
end

function R:Consume(state, action)
    if not (state and action and action.facts and action.facts.reactive
        and (action.actor or "player") == "player" and Evidence) then
        return false
    end
    local stateID, exact = Evidence:Requirement(action)
    state.reactiveConsumed = copied(state.reactiveConsumed)
    if exact and stateID and stateID > 0 then
        state.reactiveConsumed[stateID] = true
    else
        local available = rootUsability(state, action)
        if available ~= true then return false end
        -- With no exact shared aura-state identity, conservatively consume the
        -- one root-usability window for all such actions in this branch.
        state.reactiveConsumed.rootUsability = true
    end
    return true
end
