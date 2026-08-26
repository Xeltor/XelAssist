table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Graph = {}, Game = {} }
dofile("Graph/ActorScoring.lua")

local function command(state)
    local context = { state = state, facts = { kind = "command" },
        kind = "command", action = { command = "attack" } }
    assert(XelAssist.Graph.ActorScoring:Score(context))
    return context
end

local pet = { health = 1000, healthMax = 1000 }
local durable = command({ targetHealthExact = true, targetHealth = 1000,
    actors = { pet = pet } })
assert(durable.value == 3200
    and durable.reason ==
        "starts companion participation while the target can survive",
    "exact durable targets must make one pet-engagement press competitive with ordinary high-rank damage")

local short = command({ targetHealthExact = true, targetHealth = 100,
    actors = { pet = pet } })
assert(short.value == 850,
    "a nearly defeated exact target must not receive invented long-fight companion value")

local unknown = command({ targetHealthExact = false, targetHealth = 1000,
    actors = { pet = pet } })
assert(unknown.value == 850,
    "percentage-scaled or unknown hostile health must retain the conservative command value")

local absent = command({ actors = { pet = pet } })
assert(absent.value == 850,
    "missing health evidence must never manufacture companion participation value")

print("ok: companion Attack admission uses only exact surviving combat runway")
