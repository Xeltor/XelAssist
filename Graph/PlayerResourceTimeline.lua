-- Causal start boundary for player-resource actions. Waiting remains eligible
-- for a verified root clock; mana casting may retire or rearm it at the exact
-- spell start without adding live API work to descendant graph nodes.
XelAssist.Graph.PlayerResourceTimeline = {}
local P = XelAssist.Graph.PlayerResourceTimeline

local function resources()
    return XelAssist.Game.Player and XelAssist.Game.Player.Resources
end

function P:Append(events, state, candidate, order, window)
    local model = resources()
    if not (model and model:IsManaSpend(state, candidate)) then return order end
    local offset = math.max(0, tonumber(candidate.wait) or 0)
    if offset > (tonumber(window) or math.huge) then return order end
    events[table.getn(events) + 1] = { owner = "action",
        kind = "chosenActionStart", offset = offset, priority = 20,
        order = order }
    return order + 1
end

function P:Begin(state, candidate)
    local model = resources()
    return not model or model:BeginChosen(state, candidate)
end
