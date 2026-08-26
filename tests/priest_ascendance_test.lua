table.getn=table.getn or function(v)return #v end
XelAssist={Game={Player={}},Graph={}}
local rows,active,token={},false,"PRIEST"
rows[52962]={school=1,attributes=256,attributesEx=268468224,attributesEx2=2097152,
 attributesEx3=0,attributesEx4=0,stances=0,stancesNot=0,castingTimeIndex=1,
 recoveryTime=300000,durationIndex=37,powerType=0,manaCost=280,manaCostPerlevel=0,
 manaCostPercentage=0,rangeIndex=1,spellFamilyName=6,spellFamilyFlags=2147483648,
 effect={6,6,64},effectDieSides={1,1,1},effectBaseDice={1,1,1},effectBasePoints={0,0,0},
 effectImplicitTargetA={1,1,1},effectImplicitTargetB={0,0,0},effectApplyAuraName={39,147,0},
 effectMiscValue={127,545341011,0},effectTriggerSpell={0,0,52963}}
rows[52963]={school=1,dispel=1,attributes=0,durationIndex=2,spellFamilyName=6,
 spellFamilyFlags=0,effect={6,6,6},effectApplyAuraName={108,108,109},
 effectBasePoints={-21,-34,99},effectBaseDice={1,1,1},effectImplicitTargetA={1,1,1},
 effectItemType={269888,269888,269888},effectMiscValue={10,14,0},effectTriggerSpell={0,0,52964}}
rows[52964]={school=1,dispel=1,durationIndex=1,rangeIndex=6,spellFamilyName=6,
 effect={6,0,0},effectApplyAuraName={118,0,0},effectBasePoints={14,0,0},
 effectImplicitTargetA={45,0,0},effectMiscValue={126,0,0},effectTriggerSpell={0,0,0}}
UnitClass=function()return "Priest",token end
GetSpellRecField=function(id,field,array)local v=rows[id]and rows[id][field]
 if array and type(v)=="table"then return{v[1],v[2],v[3]}end return v end
GetPlayerBuff=function(i)return i==0 and active and 7 or -1 end
GetPlayerBuffID=function()return 52963 end
C_Spell={GetSpellPowerCost=function(id)return{{type=0,cost=id==52962 and 280 or 67}}end,
 GetSpellCastTime=function()return 1600 end}
dofile("Game/Player/PriestAscendance.lua");dofile("Graph/PriestAscendance.lua")
local R=XelAssist.Game.Player.PriestAscendance;local G=XelAssist.Graph.PriestAscendance
local knowledge,reason,handled=R:InferKnowledge(52962)
assert(handled and knowledge and not reason and knowledge.self and knowledge.priestAscendance)
local facts=R:CaptureFacts({spellId=52962},{kind="modifier"},{})
assert(facts.cost==280 and facts.priestAscendanceCostExact)
local state={};assert(G:Attach(state) and state.priestAscendance.active==false)
local action={spellId=52962,facts=knowledge}
local prepared,blocked,claimed=G:Prepare(action,state,facts)
assert(claimed and not prepared and string.find(blocked,"post%-application"),
 "future activation must fail closed without post-application engine evidence")
active=true;assert(G:Attach(state) and state.priestAscendance.active)
local healed=R:CaptureFacts({spellId=2061},{kind="heal",cost=100,cast=2.5},state)
assert(healed.cost==67 and healed.cast==1.6 and healed.priestAscendanceConsumerExact,
 "observed aura must seal engine-effective heal cost and cast")
C_Spell.GetSpellCastTime=nil
healed=R:CaptureFacts({spellId=2061},{kind="heal",cost=100,cast=2.5},state)
assert(healed.cost==67 and healed.cast==2.5 and not healed.priestAscendanceConsumerExact
 and healed.priestAscendanceCastReason,
 "missing cast API must preserve prior fact and mark unresolved")
rows[52963].effectBasePoints={-20,-34,99};R:Invalidate()
assert(not R:InferKnowledge(52962),"mutated trigger aura must fail closed")
print("ok: exact observed Ascendance and withheld future branches")
