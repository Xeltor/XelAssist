XelAssist={Game={Player={}},Graph={}}
local s={[45802]={school=1,attributes=327680,procFlags=4,procChance=100,procCharges=0,durationIndex=9,powerType=0,manaCost=210,rangeIndex=1,spellFamilyName=10,spellFamilyFlags=33554432,startRecoveryCategory=133,startRecoveryTime=1500},[45814]={school=1,attributes=262144,attributesEx3=512,attributesEx4=128,rangeIndex=2,dmgClass=2},[45815]={school=1,attributes=2097152,attributesEx2=536870912,attributesEx3=196608},[45816]={school=1,attributes=2097152,attributesEx3=262656,maxLevel=68,baseLevel=60,spellLevel=60,rangeIndex=13,dmgClass=2},[45817]={school=1,attributes=2097152,attributesEx2=536870912,attributesEx3=196608}}
local a={[45802]={effect={6,6,6},effectBasePoints={19,10,45816},effectImplicitTargetA={1,1,1},effectApplyAuraName={4,42,4},effectItemType={30,0,45816},effectTriggerSpell={0,45814,0}},[45814]={effect={31,0,0},effectBasePoints={19,0,0},effectImplicitTargetA={6,0,0}},[45815]={effect={2,0,0},effectBasePoints={0,0,0},effectImplicitTargetA={1,0,0}},[45816]={effect={2,0,0},effectDieSides={30,0,0},effectBaseDice={1,0,0},effectRealPointsPerLevel={6.099999904632568,0,0},effectBasePoints={169,0,0},effectImplicitTargetA={6,0,0}},[45817]={effect={2,0,0},effectBasePoints={0,0,0},effectImplicitTargetA={1,0,0}}}
function GetSpellRecField(id,f,array) if array then local v=a[id] and a[id][f] or {0,0,0};return {v[1],v[2],v[3]} end return s[id] and s[id][f] end
dofile("Game/Player/PaladinMartyr.lua");local R=XelAssist.Game.Player.PaladinMartyr
local p=R:Profile();assert(p.exact and p.weaponHolyCoefficient==.2 and not p.compoundRepresentable and not p.selfHealthArithmeticExact)
local facts=R:CaptureFacts({spellId=20271},{weaponHand="main"});assert(facts.paladinMartyrJudgement and facts.paladinMartyrExact)
dofile("Graph/PaladinMartyr.lua");local G=XelAssist.Graph.PaladinMartyr
local state={paladinAuraState={available=true,player={activeSeal={spellId=45802,exact=true,recipientRelation="self"}}}}
assert(G:Attach(state,R:Snapshot()))
local outcome,reason,handled=G:JudgementOutcome({spellId=20271,facts=facts},state)
assert(handled and reason and outcome.exact and not outcome.representable and outcome.consumesSeal and outcome.holy.spellId==45816 and not outcome.selfHealth.exact)
local hit=G:WeaponOutcome({facts={weaponHand="main"}},state)
assert(hit and hit.holy.weaponCoefficient==.2 and not hit.representable)
s[45816].rangeIndex=6;R:Invalidate();assert(not R:Profile(),"shifted Judgement accepted")
print("ok: bounded Paladin Seal of the Martyr topology")
