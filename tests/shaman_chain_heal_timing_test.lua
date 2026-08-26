XelAssist = { Game = { Player = {} } }

local class, active, cast = "SHAMAN", 51376, 1900
local chains = { [1064] = true, [10622] = true, [10623] = true }
local reductions = { [51374] = 200, [51375] = 400, [51376] = 600,
    [51377] = 800, [51378] = 1000 }

function UnitClass() return "Shaman", class end
function IsPlayerSpell(id) return id == active end
function GetSpellRecField(id, field, array)
    local reduction = reductions[id]
    if chains[id] then
        if field == "spellFamilyName" then return 11 end
        if field == "spellFamilyFlags" then return 256 end
        if field == "castTime" then return 2500 end
        if array and field == "effect" then return { 10, 0, 0 } end
        if array and field == "effectImplicitTargetA" then return { 21, 0, 0 } end
    elseif reduction then
        if field == "spellFamilyName" then return 11 end
        if field == "spellFamilyFlags" then return 256 end
        if array and field == "effect" then return { 6, 0, 0 } end
        if array and field == "effectApplyAuraName" then return { 107, 0, 0 } end
        if array and field == "effectMiscValue" then return { 10, 0, 0 } end
        if array and field == "effectBasePoints" then
            return { 4294967295 - reduction, 0, 0 }
        end
    end
end
C_Spell = { GetSpellCastTime = function(id)
    assert(chains[id], "only Chain Heal timing may be queried")
    return cast
end }

dofile("Game/Player/ShamanChainHealTiming.lua")
local T = XelAssist.Game.Player.ShamanChainHealTiming
for id in pairs(chains) do
    local facts, reason, handled = T:InferKnowledge(id)
    assert(handled and not reason and facts and facts.kind == "heal"
        and facts.requiresExactShamanChainHealTiming,
        "all player Chain Heal ranks must receive exact timing ownership")
    local captured = T:CaptureFacts({ spellId = id }, facts)
    assert(captured.cast == 1.9 and captured.shamanChainHealCastExact
        and captured.shamanChainHealTalentSpellId == 51376,
        "the engine-effective cast time and active custom rank must be sealed")
end

active = nil; cast = 2500
local baseFacts = T:InferKnowledge(1064)
local base = T:CaptureFacts({ spellId = 1064 }, baseFacts)
assert(base.cast == 2.5 and base.shamanChainHealCastExact
    and base.shamanChainHealTalentSpellId == nil,
    "untalented Chain Heal must retain its exact base timing")

active = 51378; cast = 1500
local fastFacts = T:InferKnowledge(10622)
local fast = T:CaptureFacts({ spellId = 10622 }, fastFacts)
assert(fast.cast == 1.5 and fast.shamanChainHealTalentSpellId == 51378,
    "rank five must preserve its one-second reduction")

class = "MAGE"
local wrong, _, handled = T:InferKnowledge(1064)
assert(not wrong and not handled, "another class must not claim Chain Heal")

class = "SHAMAN"; active = 51374; cast = 2500
local original = GetSpellRecField
GetSpellRecField = function(id, field, array)
    local value = original(id, field, array)
    if id == 51374 and field == "effectMiscValue" then return { 11, 0, 0 } end
    return value
end
local rejected = T:CaptureFacts({ spellId = 1064 }, T:InferKnowledge(1064))
assert(rejected.shamanChainHealCastExact and rejected.cast == 2.5
    and rejected.shamanChainHealTalentSpellId == nil
    and rejected.shamanChainHealTalentOwnershipReason ==
        "Octo improved Chain Heal topology is incomplete",
    "shifted talent ownership must not corrupt exact engine timing")

print("ok: Octo improved Chain Heal engine timing is root-sealed")
