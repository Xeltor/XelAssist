table.getn = table.getn or function(values) return #values end
XelAssist = { Graph = {} }
dofile("Graph/ResourceInvestment.lua")
local Investment = XelAssist.Graph.ResourceInvestment

local shoot = { action = { actor = "player", facts = {
    wandRepeat = true } }, value = 0.01 }
local shot = { action = { actor = "player", facts = {
    wandContinuation = true } }, value = 24 }
local spell = { action = { actor = "player", facts = {
    kind = "damage" } }, value = 100 }

local started = Investment:Advance({ state = {} }, shoot,
    { state = {}, steps = { shoot }, total = 0.01 })
assert(started.wandSetupOpen and not Investment:Eligible(started),
    "a zero-output Shoot toggle must remain an unpublished setup lane")

local clipped = Investment:Advance(started, spell,
    { state = {}, steps = { shoot, spell }, total = 100.01 })
assert(clipped.wandSetupOpen and not Investment:Eligible(clipped),
    "a spell after Shoot must strand rather than falsely fulfill the wand lane")

local resolved = Investment:Advance(started, shot,
    { state = {}, steps = { shoot, shot }, total = 24.01 })
assert(not resolved.wandSetupOpen and Investment:Eligible(resolved),
    "the first causally resolved wand impact must close the setup lane")

local paths = {}
for index = 1, 6 do
    paths[index] = { state = {}, steps = { spell }, total = 100 - index }
end
table.insert(paths, started)
Investment:Retain(paths, 5, function(a, b) return a.total > b.total end)
local retained = false
for index = 1, table.getn(paths) do
    if paths[index] == started then retained = true end
end
assert(retained,
    "beam pruning must preserve one Shoot lane until its first real shot")

print("ok: wand setup survives beam pruning until a resolved impact")
