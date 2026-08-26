XelAssist = { Game = { Player = {} }, Graph = {} }

local fields = {
    school=0, attributes=327696, attributesEx=134218240,
    attributesEx2=0, attributesEx3=0, attributesEx4=0, stances=196608,
    stancesNot=0, castingTimeIndex=1, recoveryTime=0,
    categoryRecoveryTime=0, durationIndex=0, powerType=1, manaCost=50,
    baseLevel=1, spellLevel=1, spellFamilyName=4, spellFamilyFlags=0,
    equippedItemClass=2, equippedItemSubClassMask=173555,
    equippedItemInventoryTypeMask=0, startRecoveryCategory=133,
    startRecoveryTime=1500, dmgClass=2, preventionType=2, rangeIndex=2,
    effect={31,121,0}, effectDieSides={1,1,0}, effectBaseDice={1,1,0},
    effectBasePoints={49,14,0}, effectImplicitTargetA={6,6,0},
    effectImplicitTargetB={0,0,0}, effectApplyAuraName={0,0,0},
    effectTriggerSpell={0,0,0},
}
GetSpellRecField = function(id, field) if id == 45579 then return fields[field] end end
GetSpellRangeData = function(index) if index == 2 then return 0, 5 end end
UnitClass = function() return "Warrior", "WARRIOR" end
IsPlayerSpell = function(id) return id == 45579 end

dofile("Game/Player/WarriorDevastate.lua")
dofile("Graph/WarriorDevastate.lua")
local Owner = XelAssist.Game.Player.WarriorDevastate
local Graph = XelAssist.Graph.WarriorDevastate

local facts, reason, handled = Owner:InferKnowledge(45579)
assert(handled and facts and not reason and facts.weaponPercent == 50
    and facts.stanceMask == 196608 and facts.requiresMainHandWeapon
    and facts.supplementalThreatUnknown == true,
    "learned Warrior must receive the exact bounded Devastate identity")

local record = { key="target-guid", selected=true, executable=true,
    projectedAuras={ ["Sunder Armor"]={ stacks=4, duration=30, remaining=12,
        mine=true, applicationProbability=1 } },
    modifierEffects={ ["Sunder Armor"]={ activeRoot=true, mine=true,
        expectedStacks=4, deliveryProbability=1 } } }
local projection
projection, reason, handled = Graph:Prepare(
    { spellId=45579, facts=facts }, {}, { record=record })
assert(handled and projection and not reason and projection.targetKey=="target-guid"
    and projection.weaponPercent==50 and projection.stackDamage==60
    and projection.sunderRefreshDuration==30
    and projection.supplementalThreat==nil
    and projection.supplementalThreatExact==false,
    "four exact Sunder stacks must add 60 damage and refresh without guessed threat")
local action = { spellId=45579, facts=facts }
local tooltip = Graph:PrepareLegal(action, {}, {record=record}, {cost=5})
assert(tooltip.weaponCoefficient == 0.5 and tooltip.weaponDirectFlat == 60,
    "Devastate packet did not reach generic weapon power")
XelAssist.Graph.HostileState = { ByKey=function(_,_,key)
    return key == record.key and record or nil
end }
record.projectedAuras["Sunder Armor"].remaining = 2
assert(Graph:Apply({},{action=action,tooltip=tooltip,targetKey=record.key,
    effectDelivery=1}) and record.projectedAuras["Sunder Armor"].remaining == 30,
    "landed Devastate did not refresh exact owned Sunder")

record.projectedAuras["Sunder Armor"].stacks = 4.5
projection, reason, handled = Graph:Prepare(
    { spellId=45579, facts=facts }, {}, { record=record })
assert(handled and projection == nil and reason,
    "probabilistic Sunder stacks must fail closed")

record.projectedAuras["Sunder Armor"].stacks = 4
record.selected = false
projection, reason, handled = Graph:Prepare(
    { spellId=45579, facts=facts }, {}, { record=record })
assert(handled and projection == nil and reason,
    "Devastate must never borrow a non-selected hostile's stacks")

record.selected = true
fields.effectBasePoints = {49,15,0}
Owner:Invalidate()
assert(Owner:InferKnowledge(45579) == nil,
    "recognized Devastate topology drift must fail closed")

fields.effectBasePoints = {49,14,0}
Owner:Invalidate()
IsPlayerSpell = function() return false end
facts, reason, handled = Owner:InferKnowledge(45579)
assert(handled and facts == nil and reason == "Devastate is not learned",
    "unlearned Devastate must not be owned")

print("ok: bounded Octo Warrior Devastate causal owner")
