-- Branch-local one-use Shadow Trance consequence. Only root-observed aura
-- state is copied; no future Nightfall proc is invented from its percentage.
XelAssist.Graph.WarlockNightfall = {}
local N = XelAssist.Graph.WarlockNightfall

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function N:Attach(state, snapshot)
    if not (state and snapshot and snapshot.available
        and snapshot.exact) then return false end
    state.warlockNightfall = copy(snapshot)
    return true
end

function N:Copy(source, target)
    target.warlockNightfall = source.warlockNightfall
        and copy(source.warlockNightfall) or nil
    return target.warlockNightfall ~= nil
end

function N:PrepareLegal(action, state, tooltip)
    if not (action and action.facts and action.facts.warlockNightfallConsumer) then
        return tooltip, nil, false
    end
    if action.facts.warlockNightfallConsumerExact ~= true then
        return nil, action.facts.warlockNightfallReason
            or "Shadow Bolt topology unavailable", true
    end
    local found = state and state.warlockNightfall
    if not (found and found.available and found.exact) then
        return nil, "Nightfall root state unavailable", true
    end
    local out = copy(tooltip)
    if found.active ~= true then return out, nil, true end
    local start = math.max(tonumber(state.time) or 0,
        tonumber(state.playerGcdReadyAt) or 0,
        tonumber(state.actorReadyAt and state.actorReadyAt.player) or 0)
    if not found.expiresAt or start >= found.expiresAt then
        return out, nil, true
    end
    out.cast, out.alwaysHit = 0, true
    out.warlockNightfallGuaranteedHit = { exact = true,
        spellId = action.spellId, auraSpellId = 17941 }
    out.warlockNightfallConsumption = { exact = true,
        spellId = action.spellId, auraSpellId = 17941,
        source = found.source }
    return out, nil, true
end

function N:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.warlockNightfallConsumption
    local found = state and state.warlockNightfall
    if not (marker and marker.exact and found and found.active
        and marker.auraSpellId == 17941 and candidate.action
        and marker.spellId == candidate.action.spellId) then return false end
    found.active, found.charges = false, 0
    found.expiresAt, found.remaining = nil, nil
    found.source = "projected one-use Shadow Trance consumption"
    return true
end
