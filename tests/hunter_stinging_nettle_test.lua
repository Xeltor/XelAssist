local function expect(v,m) if not v then error(m) end end
table.getn=table.getn or function(v)return #v end
XelAssist={Game={Player={}},Graph={}}
local learned={[51579]=true,[1495]=true,[1978]=true}
local rows={
 [1495]={spellFamilyName=9,spellFamilyFlags=2,effect={2,31,0},effectImplicitTargetA={6,6,0}},
 [51579]={spellFamilyName=9,attributes=464,effect={6,0,0},effectApplyAuraName={4,0,0},effectImplicitTargetA={1,0,0},effectBasePoints={19,0,0}},
 [1978]={spellFamilyName=9,spellFamilyFlags=16384,effect={6,0,0},effectApplyAuraName={3,0,0},effectAmplitude={3000,0,0},effectImplicitTargetA={6,0,0},effectBasePoints={3,0,0},effectBaseDice={1,0,0},effectDieSides={1,0,0}},
}
IsPlayerSpell=function(id)return learned[id]==true end
GetSpellDuration=function(id)expect(id==1978,"wrong Sting rank");return 15000 end
GetSpellRecField=function(id,field,copied)
 local value=rows[id] and rows[id][field]
 expect(value~=nil,"unexpected DBC field "..tostring(id)..":"..field)
 if copied then
  local out,key={},nil
  for key in pairs(value) do out[key]=value[key] end
  return out
 end
 return value
end
dofile("Game/Player/HunterStingingNettle.lua")
local selected={key="hostile-a",guid="hostile-a",unit="target",
 projectedAuras={},targetAuras={}}
local other={key="hostile-b",guid="hostile-b",unit="mouseover",
 projectedAuras={},targetAuras={}}
XelAssist.Graph.State={
 HostileByKey=function(_,state,key)
  return state.hostiles and state.hostiles.byKey[key] or nil
 end,
 RefreshHostileRecord=function() end,
}
XelAssist.Graph.EventAuras={ReplaceScheduledAura=function(_,_,key,guid,_,_,prior)
 expect(key=="hostile-b" and guid=="hostile-b",
  "periodic branch must retain off-target identity")
 return prior and {prior} or nil
end}
dofile("Graph/HunterStingingNettle.lua")
local R,G=XelAssist.Game.Player.HunterStingingNettle,XelAssist.Graph.HunterStingingNettle
local facts=R:CaptureFacts({spellId=1495},{kind="damage"})
local evidence=R:Evidence(facts)
expect(evidence and evidence.duration==3 and evidence.tickDamage==4
 and evidence.totalDamage==4 and evidence.ignoresResistances
 and evidence.magnitudeEstimated,
 "rank-one Nettle must seal one irresistible baseline Sting tick")
local state={hostiles={selectedKey="hostile-a",byKey={
 ["hostile-a"]=selected,["hostile-b"]=other}},auras=selected.projectedAuras}
local context={facts=facts,tooltip=facts,state=state,
 descriptor={key="hostile-b",guid="hostile-b",relation="hostile"},
 effectDelivery=.75,downtime=1.5,value=100}
local transition,reason,handled=G:Prepare(context)
expect(handled and transition and not reason and transition.marginalDamage==4,
 "Mongoose Bite must prepare the exact marginal Sting")
G:Score(context)
expect(context.value==108 and transition.applicationProbability==.75,
 "Nettle score must remain conditional on the Mongoose hit")
expect(transition.targetKey=="hostile-b" and transition.targetGUID=="hostile-b",
 "prepared transition must pin the evaluated hostile")
expect(G:Apply(state,{targetKey="hostile-b",targetGUID="hostile-b",
 stingingNettleTransition=transition})
 and other.projectedAuras["Serpent Sting"].remaining==3
 and other.projectedAuras["Serpent Sting"].applicationProbability==.75
 and selected.projectedAuras["Serpent Sting"]==nil
 and state.auras==selected.projectedAuras,
 "off-target Mongoose must mutate only its pinned hostile record")
local before=other.projectedAuras["Serpent Sting"]
expect(not G:Apply(state,{targetKey="hostile-a",targetGUID="hostile-a",
 stingingNettleTransition=transition})
 and other.projectedAuras["Serpent Sting"]==before,
 "mutated candidate identity must reject without changing either hostile")
state.hostiles.byKey["hostile-b"]=nil
expect(not G:Apply(state,{targetKey="hostile-b",targetGUID="hostile-b",
 stingingNettleTransition=transition}),
 "absent pinned hostile must reject the transition")
state.hostiles.byKey["hostile-b"]=other
other.projectedAuras["Serpent Sting"]={remaining=4}
expect(select(3,G:Prepare(context))==false,
 "server keep-the-longer rule must preserve a longer Sting")
rows[51579].effectBasePoints[4]=0
facts=R:CaptureFacts({spellId=1495},{kind="damage"})
expect(not R:Evidence(facts) and facts.stingingNettleEvidenceReason,
 "DBC arrays with extra keys must fail closed")
rows[51579].effectBasePoints[4]=nil
rows[51579].effectBasePoints={18,0,0}
facts=R:CaptureFacts({spellId=1495},{kind="damage"})
expect(not R:Evidence(facts) and facts.stingingNettleEvidenceReason,
 "changed talent topology must fail closed")
print("ok: exact Mongoose-triggered Stinging Nettle consequence")
