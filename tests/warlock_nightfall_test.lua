XelAssist={Game={Player={}},Graph={}}
table.getn=table.getn or function(t)local n=0 while t[n+1] do n=n+1 end return n end
function UnitClass() return "Warlock","WARLOCK" end
function UnitGUID() return "player-guid" end
function GetTime() return 100 end
function IsPlayerSpell(id) return id==18095 end
local active=true
C_UnitAuras={GetUnitAuras=function()
    if not active then return {} end
    return {{spellId=17941,isHelpful=true,duration=10,expirationTime=106}}
end}
local scalars={
 [18094]={school=0,attributes=464,procFlags=262144,procChance=2,procCharges=0,durationIndex=21,spellFamilyName=5},
 [18095]={school=0,attributes=464,procFlags=262144,procChance=4,procCharges=0,durationIndex=21,spellFamilyName=5},
 [17941]={school=5,attributes=65536,durationIndex=1,spellFamilyName=5,spellFamilyFlags=0},
 [17964]={school=5,spellFamilyName=5},
 [686]={school=5,spellFamilyName=5,spellFamilyFlags=1,castTime=1700},
}
local arrays={
 [18094]={effect={6,0,0},effectApplyAuraName={42,0,0},effectItemType={16410,0,0},effectTriggerSpell={17941,0,0}},
 [18095]={effect={6,0,0},effectApplyAuraName={42,0,0},effectItemType={16410,0,0},effectTriggerSpell={17941,0,0}},
 [17941]={effect={6,64,0},effectBasePoints={4294967195,0,0},effectImplicitTargetA={1,1,0},effectApplyAuraName={108,0,0},effectMiscValue={10,0,0},effectItemType={1,0,0},effectTriggerSpell={0,17964,0}},
 [17964]={effect={6,0,0},effectBasePoints={99,0,0},effectApplyAuraName={107,0,0},effectItemType={16,0,0}},
 [686]={effect={2,0,0},effectImplicitTargetA={6,0,0}},
}
function GetSpellRecField(id,field,array)
    if array then local v=arrays[id] and arrays[id][field] or {0,0,0}; return {v[1],v[2],v[3]} end
    return scalars[id] and scalars[id][field]
end
dofile("Game/Player/WarlockNightfall.lua")
local R=XelAssist.Game.Player.WarlockNightfall
local facts=R:CaptureFacts({spellId=686},{kind="damage"})
assert(facts.warlockNightfallConsumer and facts.warlockNightfallConsumerExact)
local snapshot=R:Snapshot("WARLOCK")
assert(snapshot.available and snapshot.exact and snapshot.learned and snapshot.active
    and snapshot.procChance==4 and snapshot.charges==1 and snapshot.expiresAt==6)
dofile("Graph/WarlockNightfall.lua")
local G=XelAssist.Graph.WarlockNightfall
local state={time=0,playerGcdReadyAt=0,actorReadyAt={player=0}}
assert(G:Attach(state,snapshot))
local action={spellId=686,actor="player",facts=facts}
local tip,reason,handled=G:PrepareLegal(action,state,{cast=1.7})
assert(handled and not reason and tip.cast==0 and tip.alwaysHit
    and tip.warlockNightfallGuaranteedHit.exact and tip.warlockNightfallConsumption)
local branch={}; assert(G:Copy(state,branch))
assert(G:Consume(branch,{action=action,tooltip=tip}) and not branch.warlockNightfall.active)
local original=G:PrepareLegal(action,state,{cast=1.7})
assert(original.cast==0,"sibling branch must retain the root proc")
local after=G:PrepareLegal(action,branch,{cast=1.7})
assert(after.cast==1.7,"consumed branch must not reuse Shadow Trance")
active=false
local inactive=R:Snapshot("WARLOCK")
assert(inactive.exact and not inactive.active)
local plain={time=0,playerGcdReadyAt=0,actorReadyAt={player=0}}
G:Attach(plain,inactive)
assert((G:PrepareLegal(action,plain,{cast=1.7})).cast==1.7,
    "learned Nightfall must not fabricate an unobserved proc")
print("ok: root-sealed branch-local one-use Nightfall")
