XelAssist={Game={Player={}},Graph={}}
local r={[2565]={school=0,attributes=327696,attributesEx3=2,stances=131072,durationIndex=28,powerType=1,manaCost=100,recoveryTime=5000,spellFamilyName=4,spellFamilyFlags=4096,equippedItemClass=4,equippedItemSubClassMask=64,procCharges=1,effect={6,0,0},effectBasePoints={74,0,0},effectApplyAuraName={51,0,0}},[45575]={attributes=262352,spellFamilyName=4,effect={6,6,0},effectBasePoints={1,1000,0},effectApplyAuraName={107,107,0},effectMiscValue={4,1,0}}}
GetSpellRecField=function(id,f)return r[id]and r[id][f]end
UnitClass=function()return"Warrior","WARRIOR"end
IsPlayerSpell=function(id)return id==2565 or id==45575 end
GetSpellDuration=function()return 6000 end
dofile("Game/Player/WarriorShieldBlock.lua");dofile("Graph/WarriorShieldBlock.lua")
local R=XelAssist.Game.Player.WarriorShieldBlock;local G=XelAssist.Graph.WarriorShieldBlock
local f,reason,handled=R:InferKnowledge(2565);assert(handled and f and not reason and f.warriorShieldBlockEvidence.charges==2 and f.warriorShieldBlockEvidence.duration==6)
local state={time=2,resourceType=1,resource=30,playerResourceExact=true,playerForm={available=true,formID=18},inventory={offHand={classificationKnown=true,classID=4,subClassID=6,broken=false}}}
local tip;tip,reason,handled=G:Prepare({spellId=2565,facts=f},state,{cost=10});assert(handled and tip and not reason)
assert(G:Apply(state,{tooltip=tip}) and state.warriorShieldBlock.charges==2)
local sibling={warriorShieldBlock={active=true,charges=2,expiresAt=8}}
assert(not G:ConsumeObservedBlock(state,{whiteSwing=true,victimKind="player",outcomeExact=false,blockedAmount=20}),"estimated swing must not consume")
assert(G:ConsumeObservedBlock(state,{whiteSwing=true,victimKind="player",outcomeExact=true,blockedAmount=20}) and state.warriorShieldBlock.charges==1 and sibling.warriorShieldBlock.charges==2)
assert(not G:ConsumeObservedBlock(state,{whiteSwing=true,victimKind="pet",outcomeExact=true,blockedAmount=20}),"other victim must not consume")
assert(G:ConsumeObservedBlock(state,{whiteSwing=true,victimKind="player",outcomeExact=true,blockedAmount=1}) and not state.warriorShieldBlock.active)
state.time=2;assert(G:Apply(state,{tooltip=tip}));G:Advance(state,6);assert(not state.warriorShieldBlock.active and state.warriorShieldBlock.charges==0)
r[2565].procCharges=2;assert(R:InferKnowledge(2565)==nil,"topology drift must fail closed")
print("ok: exact Warrior Shield Block charges and observed-block consumption")
