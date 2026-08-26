-- Root-only composition of mutable action facts. Each evidence owner captures
-- its own domain; this coordinator only preserves their deterministic order.
XelAssist.Graph.RootActionFacts = {}
local F = XelAssist.Graph.RootActionFacts

local function combinedFacts(action, captured)
    if type(captured) ~= "table" then return captured end
    local facts, key, value = {}, nil, nil
    for key, value in pairs(action and action.facts or {}) do
        facts[key] = value
    end
    -- Runtime evidence is newer than catalogue inference. Keep it authoritative
    -- when both owners describe the same field.
    for key, value in pairs(captured) do facts[key] = value end
    return facts
end

function F:Capture(action, state)
    local forms, actors = XelAssist.Graph.DruidForms, XelAssist.Game.Actors
    local facts, known
    if forms then facts, known = forms:CaptureFacts(action, actors)
    elseif actors and actors.Facts then
        known, facts = pcall(actors.Facts, actors, action)
        known = known and type(facts) == "table"
    end
    facts = combinedFacts(action, facts)
    if facts and XelAssist.Graph.WarriorStances then facts =
        XelAssist.Graph.WarriorStances:CaptureFacts(action, facts) end
    if facts and XelAssist.Game.CrowdControl then facts =
        XelAssist.Game.CrowdControl:CaptureFacts(action, facts) end
    if facts and XelAssist.Graph.ClassMechanics then facts =
        XelAssist.Graph.ClassMechanics:CaptureFacts(action, facts, state) end
    return facts, known
end
