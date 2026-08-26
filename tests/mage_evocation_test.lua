local function expect(value, message)
    if not value then error(message or "expectation failed") end
end
table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {} }, Graph = {} }

local learned = { [51981] = true, [52586] = true, [52594] = true }
local rows = {
    [12051] = { school=6, attributes=65536, attributesEx=64,
        recoveryTime=480000, durationIndex=31, spellFamilyName=3,
        spellFamilyFlags=67108864, effect={6,6,0},
        effectApplyAuraName={110,134,0}, effectBasePoints={1499,99,0},
        effectImplicitTargetA={1,1,0}, effectAmplitude={0,0,0} },
    [51981] = { attributes=464, spellFamilyName=3, effect={6,6,6},
        effectApplyAuraName={108,108,108}, effectBasePoints={-6,-6,-6},
        effectMiscValue={1,19,1} },
    [52586] = { attributes=464, procFlags=65536, procChance=100,
        effect={6,0,0}, effectApplyAuraName={42,0,0},
        effectTriggerSpell={52591,0,0} },
    [52594] = { attributes=464, effect={6,0,0},
        effectApplyAuraName={4,0,0} },
    [52595] = { effect={6,6,0}, effectApplyAuraName={79,72,0},
        effectBasePoints={9,9,0}, effectMiscValue={126,126,0} },
}
IsPlayerSpell = function(id) return learned[id] == true end
GetSpellRecField = function(id, field, copied)
    local value = rows[id] and rows[id][field]
    expect(value ~= nil, "unexpected DBC field "..tostring(id)..":"..field)
    if copied then
        local out, key = {}, nil
        for key in pairs(value) do out[key] = value[key] end
        return out
    end
    return value
end

dofile("Game/Player/MageEvocation.lua")
local E = XelAssist.Game.Player.MageEvocation
local facts, reason, handled = E:InferKnowledge(12051)
expect(handled and facts and facts.kind == "resource" and facts.channel
    and facts.unmodeledUnsafe, reason or "Evocation was not claimed")
XelAssist.Graph.FormRequirements = { Blocker = function() return nil end }
XelAssist.Graph.EquipmentRequirements = { Blocker = function() return nil end }
dofile("Graph/ActionContextPolicy.lua")
expect(XelAssist.Graph.ActionContextPolicy:Blocker(
    { facts=facts }, { inCombat=true }, {}) == facts.unmodeledUnsafe,
    "Evocation must be rejected before generic resource/channel scoring")
local evidence = E:Evidence(facts)
expect(evidence and evidence.baseCooldown == 480
    and evidence.periodicAmplitudeAbsent
    and evidence.acceleratedArcanaActive
    and evidence.evocationMasteryActive
    and evidence.netherOverchargeActive,
    "linked Evocation identities must remain sealed")
expect(evidence.completionRequiredForNetherOvercharge
    and evidence.interruptionSuppressesNetherOvercharge
    and not evidence.fullChannelConsequenceModeled,
    "full-channel and interrupted branches must remain distinct and withheld")
expect(facts.unsafeDependencies[1] == "Spirit/MP5 mana amount"
    and facts.unsafeDependencies[2] == "player-global mana phase",
    "dynamic mana amount and phase must be explicit blockers")

rows[12051].effectAmplitude[4] = 0
E:Invalidate()
local invalid, invalidReason, invalidHandled = E:InferKnowledge(12051)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "topology"),
    "extra DBC array fields must fail closed")
rows[12051].effectAmplitude[4] = nil
rows[51981].effectMiscValue = { 1, 18, 1 }
E:Invalidate()
invalid, invalidReason, invalidHandled = E:InferKnowledge(12051)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "talent topology"),
    "changed Accelerated Arcana timing operation must fail closed")

print("ok: explicit Evocation dynamic-channel withholding contract")
