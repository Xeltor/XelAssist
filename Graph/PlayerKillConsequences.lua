-- Bounded transition observer for exact player-owned killing blows. It keeps
-- class proc consumers independent from every individual damage implementation.
XelAssist.Graph.PlayerKillConsequences = {}
local K = XelAssist.Graph.PlayerKillConsequences
local State = XelAssist.Graph.State
local MAX_HOSTILES = 12

local function playerOwned(candidate, entry)
    if entry.owner == "action" then
        local action, facts = candidate.action, candidate.action.facts or {}
        local actor = facts.damageActor or facts.effectActor
            or action.actor or "player"
        return actor == "player"
    end
    if entry.owner == "autoShot" or entry.kind == "playerMainSwing"
        or entry.kind == "playerOffhandSwing" or entry.kind == "leechChannelTick"
        or entry.kind == "leechChannelFinish" then return true end
    if entry.kind == "periodicTick" or entry.kind == "periodicSegment" then
        return entry.aura and (entry.aura.periodicThreatActor or "player")
            == "player"
    end
    return false
end
function K:Capture(state, candidate, entry)
    local tap = state and state.priestSpiritTap
    if not (tap and tap.available == true and tap.exact == true
        and tap.learned == true) then return nil end
    if not playerOwned(candidate, entry) then return nil end
    local out, hostiles = {}, state and state.hostiles
    if hostiles and hostiles.byKey then
        local i, count = nil, math.min(table.getn(hostiles.order or {}), MAX_HOSTILES)
        for i = 1, count do
            local key, record = hostiles.order[i], hostiles.byKey[hostiles.order[i]]
            if record and record.healthExact == true
                and tonumber(record.health) and record.health > 0 then
                out[key] = { key = key, guid = record.guid,
                    health = record.health }
            end
        end
    elseif state and state.targetHealthExact == true
        and tonumber(state.targetHealth) and state.targetHealth > 0 then
        out.selected = { guid = state.targetGUID, health = state.targetHealth }
    end
    return next(out) and out or nil
end
local function deadAfter(state, before)
    if before.key ~= nil then
        local record = State:HostileByKey(state, before.key)
        return record and record.healthExact == true
            and tonumber(record.health) and record.health <= 0
    end
    return state.targetHealthExact == true and tonumber(state.targetHealth)
        and state.targetHealth <= 0
end
function K:Resolve(state, candidate, entry, captured)
    if not captured then return 0 end
    local tap, count, _, before = XelAssist.Graph.PriestSpiritTap, 0, nil, nil
    if not tap then return 0 end
    for _, before in pairs(captured) do
        if deadAfter(state, before)
            and tap:OnExactPlayerKill(state, before) then count = count + 1 end
    end
    return count
end
