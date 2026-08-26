XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local scalar = {
    [45651] = { school=3, attributes=0, attributesEx2=329728,
        attributesEx3=131072, attributesEx4=16, durationIndex=56,
        powerType=0, manaCost=0, spellFamilyName=9 },
    [45652] = { school=3, attributes=0, attributesEx2=327680,
        durationIndex=4, procFlags=324, spellFamilyName=9 },
}
local arrays = {
    [45651] = { effect={6,0,0}, effectApplyAuraName={21,0,0},
        effectBasePoints={4,0,0}, effectAmplitude={5000,0,0},
        effectImplicitTargetA={4,0,0}, effectTriggerSpell={0,0,0} },
    [45652] = { effect={6,0,0}, effectTriggerSpell={45664,0,0} },
    [45664] = { effect={30,0,0}, effectBasePoints={49,0,0} },
}
function GetSpellRecField(id, field, array)
    if array then
        local value = arrays[id] and arrays[id][field] or {0,0,0}
        return { value[1], value[2], value[3] }
    end
    return scalar[id] and scalar[id][field]
end

dofile("Game/Player/HunterManaAspects.lua")
local Runtime = XelAssist.Game.Player.HunterManaAspects
local viper, reason, handled = Runtime:InferKnowledge(45651)
assert(handled and not reason and viper.hunterAspectEffectRepresented
    and viper.hunterManaAspectEvidence.maximumManaPercent == 5)
local snake = Runtime:InferKnowledge(45652)
assert(snake and snake.hunterAspectEffectRepresented == false
    and snake.hunterManaAspectEvidence.procGenerationProjectable == false)

XelAssist.Graph.HunterAspects = {
    Current = function() return "Aspect of the Viper", true end,
}
dofile("Graph/HunterManaAspects.lua")
local Graph = XelAssist.Graph.HunterManaAspects
local state = { time=0, resource=100, resourceMax=1000, resourceType=0,
    playerResourceExact=true, playerResourceReserved=0,
    actors={player={resource=100}} }
assert(Graph:Attach(state) and state.hunterManaAspect.nextIn == 5)
assert(Graph:Advance(state,4) == 0 and state.resource == 100)
assert(Graph:Advance(state,1) == 50 and state.resource == 150)

local action = { spellId=45651, facts=viper }
assert(Graph:Apply(state,action))
state.resource = 0
assert(Graph:Advance(state,10) == 100 and state.resource == 100)
assert(Graph:Apply(state,{spellId=13165,facts={hunterAspect=true}}) == false)
assert(state.hunterManaAspect == nil,"non-Viper aspect retained Viper clock")

Graph:Apply(state,action)
state.resource, state.time = 0, 0
dofile("Game/Player/Resources.lua")
local Resources = XelAssist.Game.Player.Resources
assert(Resources:ResourceAt(state,10) == 100)
assert(Resources:Earliest(state,100,0) == 10)

scalar[45651].attributesEx3 = 0
Runtime:Invalidate()
local shifted, shiftedReason = Runtime:InferKnowledge(45651)
assert(not shifted and shiftedReason,"shifted Viper topology accepted")
print("ok: exact Hunter Viper mana clock and fail-closed Snake proc")
