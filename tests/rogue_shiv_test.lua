table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }
local row = { school=0, attributes=2424848, attributesEx=134217728,
    attributesEx2=1048576, attributesEx3=17235968, attributesEx4=1024,
    castingTimeIndex=1, recoveryTime=0, durationIndex=0, powerType=3,
    manaCost=20, baseLevel=60, spellLevel=60, rangeIndex=2, spellFamilyName=8,
    spellFamilyFlags=536870912, equippedItemClass=2,
    equippedItemSubClassMask=173555, startRecoveryCategory=133,
    startRecoveryTime=1000, dmgClass=2, preventionType=2,
    effect={3,0,0}, effectBasePoints={0,0,0},
    effectImplicitTargetA={1,0,0}, effectTriggerSpell={0,0,0} }
function UnitClass() return "Rogue", "ROGUE" end
function GetSpellRangeData() return 0, 5 end
function GetSpellRecField(id, field, copied)
    if id ~= 45609 then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
dofile("Game/Player/RogueShiv.lua")
local S = XelAssist.Game.Player.RogueShiv
local facts, reason, handled = S:InferKnowledge(45609)
assert(facts and not reason and handled and facts.kind == "builder"
    and facts.comboGain == 1 and facts.weaponHand == "off"
    and facts.requiresOffhandWeapon and facts.requiresExactTooltipCost
    and facts.poisonDeliveryUncredited)
local captured = S:CaptureFacts({ spellId=45609, facts=facts },
    { cost=37, tooltipCostExact=true })
assert(captured.weaponCoefficient == 1 and captured.comboGain == 1
    and captured.cost == 37 and captured.tooltipCostExact)
XelAssist.Graph.FormRequirements = nil
XelAssist.Graph.EquipmentRequirements = nil
XelAssist.Graph.ThreatDrop = nil
XelAssist.Graph.HunterAspects = nil
XelAssist.Graph.StealthSetup = nil
dofile("Graph/ActionContextPolicy.lua")
assert(XelAssist.Graph.ActionContextPolicy:Blocker(
    { facts=facts }, {}, { cost=20 }) == "dynamic action cost unavailable")
assert(XelAssist.Graph.ActionContextPolicy:Blocker(
    { facts=facts }, {}, captured) == nil)
S:Invalidate(); row.effect[1] = 2
local shifted, shiftedReason = S:InferKnowledge(45609)
assert(not shifted and shiftedReason == "Shiv DBC topology is incomplete")
print("ok: exact Shiv off-hand builder and dynamic-cost boundary")
