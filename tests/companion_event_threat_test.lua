XelAssist = { Game = { Pets = {} }, Graph = {} }
XelAssistCharDB = { petThreat = "tank" }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Graph/HostileState.lua")
dofile("Graph/State.lua")
dofile("Graph/CompanionThreat.lua")
dofile("Game/Pets/Effects.lua")
dofile("Graph/CompanionEventThreat.lua")

local State = XelAssist.Graph.State
local Threat = XelAssist.Graph.CompanionEventThreat
local guidA, guidB, keyA, keyB = {}, {}, {}, {}

local function hostile(key, guid, selected)
    return { key = key, guid = guid, selected = selected,
        health = 100, healthMax = 100, healthExact = true,
        projectedAuras = {}, targetAuras = {},
        threat = { playerHasAggro = selected, petHasAggro = false,
            playerDelta = 0, petDelta = 0 } }
end

local function combatState(selectedKey, effectTarget)
    local first, second = hostile(keyA, guidA, selectedKey == keyA),
        hostile(keyB, guidB, selectedKey == keyB)
    return { hostiles = { order = { keyA, keyB }, selectedKey = selectedKey,
            byKey = { [keyA] = first, [keyB] = second } },
        actors = { pet = { level = 60, hasAggro = false,
            pendingMeleeEffects = { Intimidation = { remaining = 15,
                targetGuid = effectTarget, chargeProbability = 1,
                threatBase = 100, threatLevel = 60 } } } } }
end

local melee = { actor = "pet", facts = {
    kind = "damage", damageActor = "pet", melee = true } }

local offSelected = combatState(keyB, guidA)
offSelected.actors.pet.threatEstimate = { delta = 400,
    observedHasAggro = false, projected = true }
local offRecord = offSelected.hostiles.byKey[keyA]
local offView = State:HostileContext(offSelected, keyA)
local offEffect = Threat:ConsumeMelee(
    offView, offSelected, melee, guidA, 1, offRecord, false)
assert(offEffect and offEffect.projectedThreat == 100
    and offRecord.companionThreatEstimate
    and offRecord.companionThreatEstimate.delta == 100
    and offSelected.actors.pet.threatEstimate.delta == 400,
    "real hostile contexts must commit deferred threat only to an off-target record")

local selected = combatState(keyB, guidB)
local selectedRecord = selected.hostiles.byKey[keyB]
local selectedView = State:HostileContext(selected, keyB)
local selectedEffect = Threat:ConsumeMelee(
    selectedView, selected, melee, guidB, 1, selectedRecord, true)
assert(selectedEffect and selectedRecord.companionThreatEstimate
    and selectedRecord.companionThreatEstimate.delta == 100
    and selected.actors.pet.threatEstimate
    and selected.actors.pet.threatEstimate.delta == 100,
    "selected deferred threat must update both its record and root pet mirror")

print("ok: deferred pet melee threat stays target-local with real contexts")
