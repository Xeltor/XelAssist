XelAssist={Game={Player={}},Graph={}}
table.getn=table.getn or function(t)local n=0 while t[n+1] do n=n+1 end return n end
function UnitClass() return "Mage","MAGE" end
function UnitGUID() return "mage-guid" end
function GetTime() return 100 end
local learned={[51928]=true,[52501]=true}
function IsPlayerSpell(id) return learned[id] or false end
local active=true
C_UnitAuras={GetUnitAuras=function()
 if not active then return {} end
 return {{spellId=51931,isHelpful=true,applications=3,duration=10,expirationTime=106},
 {spellId=52500,isHelpful=true,applications=1,duration=10,expirationTime=108}}
end}
local s={
 [51928]={school=2,attributes=464,procFlags=65536,procChance=100,procCharges=0,durationIndex=21,spellFamilyName=3},
 [52501]={school=4,attributes=464,procFlags=65536,procChance=100,procCharges=0,durationIndex=21,spellFamilyName=3},
 [51931]={school=2,dispel=1,procFlags=87376,procChance=100,procCharges=1,durationIndex=25,spellFamilyName=3,stackAmount=5},
 [52500]={school=4,dispel=1,attributes=327680,durationIndex=1,spellFamilyName=3},
 [11366]={school=2,spellFamilyName=3,spellFamilyFlags=1077936128,castingTimeIndex=171},
 [52516]={school=4,spellFamilyName=3,spellFamilyFlags=524288,spellFamilyFlags2=8,castingTimeIndex=1},
}
local a={
 [51928]={effect={6,0,0},effectApplyAuraName={42,0,0},effectTriggerSpell={51931,0,0}},
 [52501]={effect={6,0,0},effectApplyAuraName={42,0,0},effectTriggerSpell={52500,0,0}},
 [51931]={effect={6,0,0},effectBasePoints={4294966295,0,0},effectApplyAuraName={107,0,0},effectMiscValue={10,0,0},effectItemType={4194304,0,0}},
 [52500]={effect={6,6,77},effectBasePoints={4294967215,4294967215,0},effectApplyAuraName={108,108,0},effectMiscValue={1,19,0}},
 [11366]={effect={2,6,0}}, [52516]={effect={6,6,64}},
}
function GetSpellRecField(id,f,array) if array then local v=a[id] and a[id][f] or {0,0,0}; return {v[1],v[2],v[3]} end return s[id] and s[id][f] end
dofile("Game/Player/MageProcWindows.lua")
local R=XelAssist.Game.Player.MageProcWindows
local snap=R:Snapshot("MAGE")
assert(snap.exact and snap.hotStreak.active and snap.hotStreak.stacks==3 and snap.flashFreeze.active)
dofile("Graph/MageProcWindows.lua")
local G=XelAssist.Graph.MageProcWindows
local state={time=0,playerGcdReadyAt=0,actorReadyAt={player=0}}; assert(G:Attach(state,snap))
local pyro={spellId=11366,facts={cast=3,cost=125}}
pyro.facts=R:CaptureFacts(pyro,pyro.facts,state)
assert(pyro.facts.mageProcConsumerExact and pyro.facts.mageProcContract.cast==3)
local tip,reason,handled=G:PrepareLegal(pyro,state,{cast=6,cost=125})
assert(handled and not reason and tip.cast==3 and tip.mageProcConsumption)
local branch={}; G:Copy(state,branch); assert(G:Consume(branch,{action=pyro,tooltip=tip}))
local post,postReason=G:PrepareLegal(pyro,branch,{cast=6,cost=125})
assert(not post and postReason,"consumed root modifier timing was reused")
assert((G:PrepareLegal(pyro,state,{cast=6,cost=125})).cast==3,"sibling lost proc")
local icicles={spellId=52516,facts={cast=0,cost=200}}
icicles.facts=R:CaptureFacts(icicles,icicles.facts,state)
local ice=G:PrepareLegal(icicles,state,{cast=0,cost=200})
assert(ice.mageProcConsumption.kind=="flashFreeze")
active=false
local clean=R:Snapshot("MAGE"); assert(clean.exact and not clean.hotStreak.active and not clean.flashFreeze.active)
local plain={time=0,actorReadyAt={player=0}}; G:Attach(plain,clean)
local plainFacts=R:CaptureFacts({spellId=11366},{cast=6,cost=125},plain)
assert(not plainFacts.mageProcContract,"learned passive fabricated proc")
s[51931].stackAmount=4
active=true
local shifted=R:Snapshot("MAGE")
assert(not shifted.exact,"shifted aura topology accepted")
print("ok: observed-only Mage proc windows")
