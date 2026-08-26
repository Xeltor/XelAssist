local function expect(value, message)
    if not value then error(message or "expectation failed") end
end

XelAssist = { Game = { Player = {} }, Graph = {} }

local row = { school=6, attributes=2147811328, attributesEx=0,
    recoveryTime=180000, durationIndex=18, powerType=0, manaCost=0,
    spellFamilyName=3, spellFamilyFlags=0, spellFamilyFlags2=32,
    effect={6,6,6}, effectApplyAuraName={65,64,214},
    effectBasePoints={29,0,-51}, effectImplicitTargetA={1,1,1},
    effectAmplitude={0,1000,0} }

GetSpellRecField = function(id, field, copied)
    expect(id == 12042, "unexpected spell identity")
    local value = row[field]
    expect(value ~= nil, "unexpected DBC field "..tostring(field))
    if copied then
        local out, key = {}, nil
        for key in pairs(value) do out[key] = value[key] end
        return out
    end
    return value
end

dofile("Game/Player/MageArcanePower.lua")
local A = XelAssist.Game.Player.MageArcanePower
local facts, reason, handled = A:InferKnowledge(12042)
expect(handled and facts and facts.kind == "buff" and facts.self
    and facts.unmodeledUnsafe, reason or "Arcane Power was not claimed")
local evidence = A:Evidence(facts)
expect(evidence and evidence.exact and evidence.cooldown == 180
    and evidence.castSpeedPercent == 30 and evidence.manaDrainPeriod == 1
    and evidence.manaDrainPercent == 1 and evidence.manaGainPercent == -50
    and evidence.lowManaTerminalThresholdPercent == 10
    and evidence.cancellable == false and not evidence.consequencesModeled,
    "fatal Octo Arcane Power consequences must remain sealed")

dofile("Game/ActionInference.lua")
local wired, wiredReason, wiredHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(12042)
expect(wiredHandled and wired and wired.mageArcanePower
    and wired.unmodeledUnsafe == facts.unmodeledUnsafe,
    wiredReason or "production class inference did not claim Arcane Power")

XelAssist.Graph.FormRequirements = { Blocker = function() return nil end }
XelAssist.Graph.EquipmentRequirements = { Blocker = function() return nil end }
dofile("Graph/ActionContextPolicy.lua")
expect(XelAssist.Graph.ActionContextPolicy:Blocker(
    { facts=facts }, { inCombat=true }, {}) == facts.unmodeledUnsafe,
    "Arcane Power must be rejected before generic buff scoring")

local other, otherReason, otherHandled = A:InferKnowledge(12043)
expect(not other and not otherHandled and otherReason == "spell is not Arcane Power",
    "the guard must not claim unrelated Mage actions")

row.effectAmplitude[4] = 0
A:Invalidate()
local invalid, invalidReason, invalidHandled = A:InferKnowledge(12042)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "topology"),
    "changed Arcane Power topology must fail closed without generic fallback")
row.effectAmplitude[4] = nil
row.effectApplyAuraName[3] = 0
A:Invalidate()
invalid, invalidReason, invalidHandled = A:InferKnowledge(12042)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "topology"),
    "missing terminal custom aura must fail closed")

print("ok: Octo Arcane Power fatal mana lifecycle fails closed")
