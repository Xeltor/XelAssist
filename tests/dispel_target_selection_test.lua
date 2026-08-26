XelAssist = { Graph = {}, Game = {} }
table.getn = table.getn or function(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end
XelAssist.Graph.State = {
    Descriptor = function(_, unit, relation, source, guid, key, record)
        return { unit = unit, relation = relation, source = source,
            guid = guid, key = key, record = record }
    end,
    FriendlyByKey = function(_, state, key)
        return state.friendlies.byKey[key]
    end,
    FriendlyByUnit = function(_, state, unit)
        local key = state.friendlies.byUnit[unit]
        return key and state.friendlies.byKey[key] or nil
    end,
}
XelAssist.Graph.HostileTargetPolicy = {
    Eligible = function() return false end,
}
XelAssist.Game.Friendlies = {
    TargetKeys = function(_, snapshot) return snapshot.order end,
}
XelAssist.Game.Pets = { Actions = {
    FixedTarget = function() return nil end,
} }
XelAssist.Game.Actors = { DispelTarget = function()
    error("recipient expansion must not perform live aura reads")
end }

dofile("Graph/TargetSelection.lua")
local Selection = XelAssist.Graph.TargetSelection
local party = { unit = "party1", relation = "party",
    guid = "party-guid", key = "party-key", dead = false }
local player = { unit = "player", relation = "self",
    guid = "player-guid", key = "player-key", dead = false }
local enemy = { unit = "target", relation = "hostile",
    guid = "enemy-guid", key = "enemy-key", selected = true }
local state = {
    friendlies = { order = { "party-key", "player-key" },
        byKey = { ["party-key"] = party, ["player-key"] = player },
        byUnit = { party1 = "party-key", player = "player-key" } },
    hostiles = { order = { "enemy-key" }, selectedKey = "enemy-key",
        byKey = { ["enemy-key"] = enemy } },
    targetGUID = "enemy-guid",
}
local dispel = { actor = "player", executor = "playerSpell",
    facts = { kind = "dispel" } }
local targets = Selection:Targets(dispel, state)
assert(Selection:VariableFriendlyAction(dispel)
    and table.getn(targets) == 3
    and targets[1].guid == "party-guid"
    and targets[2].guid == "player-guid"
    and targets[3].guid == "enemy-guid"
    and targets[3].relation == "hostile",
    "dispels must expose every retained friendly plus the selected hostile")

local heal = { actor = "player", executor = "playerSpell",
    facts = { kind = "heal" } }
targets = Selection:Targets(heal, state)
assert(table.getn(targets) == 2 and targets[2].guid == "player-guid",
    "ordinary friendly support expansion must remain unchanged")

print("ok: exact dispel recipient expansion without live-read targeting")
