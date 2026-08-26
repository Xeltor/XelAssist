XelAssist = { Graph = { State = {} } }
XelAssist.Graph.State.FriendlyByKey = function() return nil end
XelAssist.Graph.RootObservation = {
    Aura = function() return nil, "absent" end,
}
dofile("Graph/TargetAuras.lua")

local A = XelAssist.Graph.TargetAuras
local dot = { name = "Rend", facts = { kind = "dot" } }
local debuff = { name = "Sunder Armor", facts = { kind = "debuff" } }
local state = { time = 2, auras = {}, targetAuras = {
    Rend = { mine = true, duration = 9, remaining = 1.4,
        applicationProbability = 1 },
    ["Sunder Armor"] = { mine = true, duration = 30, remaining = 1.4,
        applicationProbability = 1 },
} }

assert(A:Active(dot, state, { relation = "hostile" }) == true,
    "Rend must remain blocked while its final Vanilla tick is pending")
state.targetAuras.Rend.remaining = 0
assert(A:Active(dot, state, { relation = "hostile" }) == false,
    "an expired periodic effect must become eligible")
assert(A:Active(debuff, state, { relation = "hostile" }) == false,
    "ordinary debuffs must retain their bounded early refresh window")

state.targetAuras.Rend = nil
state.auras.Rend = { mine = true, duration = 9, remaining = 0.2,
    applicationProbability = 1 }
assert(A:Active(dot, state, { relation = "hostile" }) == true,
    "projected branches must also preserve a pending final tick")

print("ok: Vanilla periodic effects cannot clip their final tick")
