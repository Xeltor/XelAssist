XelAssist = { Game = { Player = {} }, Graph = {} }
if not table.getn then function table.getn(value)
 local count=0; while value[count+1]~=nil do count=count+1 end; return count
end end
local fields = {
 [17364]={school=0,spellFamilyName=11,spellFamilyFlags2=512,category=971,
  attributes=65536,attributesEx=512,attributesEx3=1024,castingTimeIndex=1,
  durationIndex=21,categoryRecoveryTime=8000,procChance=101,
  spellLevel=30,powerType=0,manaCostPercentage=10,
  rangeIndex=2,equippedItemClass=2,equippedItemSubClassMask=173555,
  startRecoveryCategory=133,startRecoveryTime=1500,dmgClass=2,preventionType=2,
  effect={31,64,0},effectImplicitTargetA={6,1,0},effectTriggerSpell={0,52412,0}},
 [52412]={dispel=1,attributesEx3=67108864,spellFamilyName=11,
  spellFamilyFlags2=512,spellLevel=30,school=0,procChance=100,procFlags=69972,
  procCharges=2,durationIndex=29,effect={6,0,0},effectBasePoints={24,0,0},
  effectApplyAuraName={79,0,0},effectMiscValue={8,0,0},
  effectImplicitTargetA={1,0,0}},
}
GetSpellRecField=function(id,field) return fields[id] and fields[id][field] end
UnitClass=function() return "Shaman","SHAMAN" end
GetSpellDuration=function(id) assert(id==52412); return 12000 end
GetTime=function() return 100 end
C_UnitAuras={GetPlayerAuraBySpellID=function(id)
 assert(id==52412); return {applications=2,duration=12,expirationTime=109} end}
dofile("Game/Player/ShamanStormstrike.lua")
dofile("Graph/ShamanStormstrike.lua")
local R,G=XelAssist.Game.Player.ShamanStormstrike,XelAssist.Graph.ShamanStormstrike
local facts,reason,handled=R:InferKnowledge(17364)
assert(handled and facts and not reason and facts.shamanStormstrikeEvidence.damageTakenMultiplier==1.25)
local snap=R:Snapshot("SHAMAN")
assert(snap.exact and snap.active and snap.charges==2 and snap.remaining==9)
local state={time=0}; assert(G:Attach(state,snap))
assert(state.shamanStormstrike.p2==1)
local nature={spellId=403,actor="player",facts={kind="damage",schoolMask=8}}
local multiplier,marker,claimed=G:PrepareDamage(state,nature,nature.facts)
assert(claimed and multiplier==1.25 and marker.activeProbability==1)
local sibling={}; assert(G:Copy(state,sibling))
assert(G:Consume(state,{action=nature,effectDelivery=.5,
 shamanStormstrikeConsumption=marker}))
assert(state.shamanStormstrike.p2==.5 and state.shamanStormstrike.p1==.5
 and sibling.shamanStormstrike.p2==1)
multiplier,marker=G:PrepareDamage(state,nature,nature.facts)
assert(multiplier==1.25)
assert(G:Consume(state,{action=nature,effectDelivery=1,
 shamanStormstrikeConsumption=marker}))
assert(state.shamanStormstrike.p2==0 and state.shamanStormstrike.p1==.5
 and state.shamanStormstrike.p0==.5)
multiplier=G:PrepareDamage(state,nature,nature.facts)
assert(multiplier==1.125)
local scoring={state=state,action=nature,tooltip=nature.facts,expectedPower=80}
assert(G:Adjust(scoring) and scoring.expectedPower==90
 and scoring.shamanStormstrikeExpectedDamage==10
 and scoring.shamanStormstrikeConsumption.activeProbability==.5)
local periodic={actor="player",facts={kind="damage",schoolMask=8,periodic=true}}
assert(G:PrepareDamage(state,periodic,periodic.facts)==1)
assert(G:PrepareDamage(state,nature,nature.facts,10)==1,
 "expired Stormstrike must not amplify a delayed impact")
local pet={actor="pet",facts={kind="damage",schoolMask=8}}
assert(G:PrepareDamage(state,pet,pet.facts)==1)
local strikeFacts=R:CaptureFacts({spellId=17364},{kind="damage"})
local strike={action={spellId=17364,facts=strikeFacts},tooltip=strikeFacts,
 effectDelivery=.8}
assert(G:Apply(state,strike))
assert(math.abs(state.shamanStormstrike.p2-.8)<.000001
 and math.abs(state.shamanStormstrike.p1-.1)<.000001)
assert(G:Advance(state,12) and state.shamanStormstrike.p0==1)
C_UnitAuras.GetPlayerAuraBySpellID=function() return nil end
local inactive=R:Snapshot("SHAMAN")
assert(inactive.exact and inactive.active==false and inactive.charges==0)
local empty={}; assert(G:Attach(empty,inactive) and empty.shamanStormstrike.p0==1)
local mixed={}; snap.remaining,snap.charges,snap.active=2,1,true
assert(G:Attach(mixed,snap))
assert(G:Apply(mixed,{action={spellId=17364,facts=strikeFacts},
 tooltip=strikeFacts,effectDelivery=.5}))
assert(G:Advance(mixed,3) and mixed.shamanStormstrike.p0==.5
 and mixed.shamanStormstrike.p2==.5,
 "a missed refresh must retain the old expiry while a landed refresh gets 12 seconds")
dofile("Game/ActionInference.lua")
local inferred=XelAssist.Game.ActionInference:ClassKnowledge(17364)
assert(inferred and inferred.shamanStormstrike and inferred.melee,
 "production action inference omitted Stormstrike")
dofile("Graph/ClassEvidence.lua")
local captured=XelAssist.Graph.ClassEvidence:CaptureFacts(
 {spellId=17364}, {kind="damage"}, {})
assert(captured.shamanStormstrikeEvidence,
 "production class evidence omitted Stormstrike")
dofile("Graph/ClassState.lua")
local root={}; assert(XelAssist.Graph.ClassState:Attach(root))
local branch={}; assert(XelAssist.Graph.ClassState:Copy(root,branch)
 and branch.shamanStormstrike,"production class state omitted Stormstrike")
dofile("Graph/Candidate.lua")
local built=XelAssist.Graph.Candidate:Build({action=nature,facts=nature.facts,
 descriptor={},tooltip=nature.facts,shamanStormstrikeConsumption=marker})
assert(built.shamanStormstrikeConsumption==marker,
 "production candidate transport omitted Stormstrike consumption")
print("ok: exact Stormstrike two-charge Nature amplifier lifecycle")
