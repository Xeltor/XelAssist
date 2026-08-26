-- Search-pure Cat energy consequence for exact player-owned bleed ticks.
XelAssist.Graph.DruidAncientBrutality = {}
local A = XelAssist.Graph.DruidAncientBrutality

local function finite(value)
    value = tonumber(value)
    return value and value == value and value ~= math.huge
        and value ~= -math.huge and value or nil
end

local function valid(found)
    local owner = XelAssist.Game.Player.DruidAncientBrutality
    local spec = found and owner and owner.RANKS[found.rank]
    return found and found.available == true and found.exact == true
        and found.talentID == owner.TALENT_ID and spec
        and found.talentSpellId == spec.talentSpellId
        and found.triggerSpellId == spec.triggerSpellId
        and found.energy == spec.energy and found.powerType == owner.ENERGY
        and found.formID == owner.CAT_FORM
end

function A:Attach(state, token)
    local owner = XelAssist.Game.Player.DruidAncientBrutality
    if not (state and owner and token == "DRUID") then return false end
    local found = owner:Snapshot()
    state.druidAncientBrutality = found
    return valid(found) and true or found.available == true
end

function A:Copy(source, target)
    local found = source and source.druidAncientBrutality
    if not found then return end
    local out, key, value = {}, nil, nil
    for key, value in pairs(found) do out[key] = value end
    target.druidAncientBrutality = out
end

local function playerBleedTick(entry)
    local aura = entry and entry.aura
    local action = aura and aura.periodicAction
    local facts = action and action.facts
    return entry.kind == "periodicTick" and aura.mine == true
        and facts and facts.bleed == true
        and (action.actor == nil or action.actor == "player")
end

-- `scale` is EventAuras' sealed application probability. Fractional energy is
-- expected-value state, matching probabilistic damage branches in the graph.
function A:ApplyTick(state, entry, delivered, scale)
    local found = state and state.druidAncientBrutality
    local form = state and state.druidFormState
    local gain, current, maximum = valid(found) and finite(found.energy),
        finite(state and state.resource), finite(state and state.resourceMax)
    scale = finite(scale)
    if not (delivered == true and playerBleedTick(entry) and gain
        and scale and scale >= 0 and scale <= 1 and form
        and form.available == true and form.formID == found.formID
        and state.resourceType == found.powerType and current and maximum
        and current >= 0 and maximum >= current) then return false end
    local applied = math.max(0, math.min(maximum - current, gain * scale))
    state.resource = current + applied
    local actor = state.actors and state.actors.player
    if actor and finite(actor.resource) and finite(actor.resourceMax)
        and actor.resourceMax == maximum then actor.resource = state.resource end
    state.druidAncientBrutalityLast = { exact = true, expected = scale < 1,
        energy = applied, triggerSpellId = found.triggerSpellId,
        source = found.source }
    return true
end
