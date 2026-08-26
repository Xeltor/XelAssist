XelAssist={Game={Player={}},Graph={}}
table.getn=table.getn or function(value) return #value end
local rows={}
for _,id in ipairs({20473,20929,20930,51786}) do rows[id]={school=1,attributes=327680,
 spellFamilyName=10,spellFamilyFlags=2097152,categoryRecoveryTime=20000,
 startRecoveryCategory=133,startRecoveryTime=1500,effect={3,0,0}} end
rows[51865]={school=0,spellFamilyName=10,durationIndex=21,procChance=100,
 procCharges=1,procFlags=16384,attributes=128,attributesEx=2048,effect={6,0,0},
 effectBasePoints={-501,0,0},effectApplyAuraName={107,0,0},
 effectItemType={2097152,0,0},effectMiscValue={21,0,0}}
rows[52661]={school=0,spellFamilyName=10,durationIndex=21,procChance=100,
 procCharges=1,procFlags=87056,attributes=192,attributesEx=0,effect={6,0,0},
 effectBasePoints={-101,0,0},effectApplyAuraName={108,0,0},
 effectItemType={2097152,0,0},effectMiscValue={11,0,0}}
GetSpellRecField=function(id,field) return rows[id] and rows[id][field] end
UnitClass=function() return "Paladin","PALADIN" end
UnitGUID=function() return "player-guid" end
C_UnitAuras={GetUnitAuras=function() return {
 {spellId=51865,isHelpful=true,applications=1},
 {spellId=52661,isHelpful=true,applications=1}} end}
dofile("Game/Player/PaladinHolyShockModifiers.lua")
dofile("Graph/PaladinHolyShockModifiers.lua")
local Runtime=XelAssist.Game.Player.PaladinHolyShockModifiers
local Graph=XelAssist.Graph.PaladinHolyShockModifiers
local snapshot=Runtime:Snapshot("PALADIN")
assert(snapshot.available and snapshot.exact and snapshot.gcd.active
 and snapshot.cooldown.active,"both exact observed modifier auras must be owned")
local state={}; assert(Graph:Attach(state,snapshot))
local facts=Runtime:CaptureFacts({spellId=51786},{gcd=1,cooldown=0},state)
local action={spellId=51786,facts=facts}
local tooltip,reason,handled=Graph:PrepareLegal(action,state,{gcd=1.5,cooldown=20})
assert(handled and tooltip and not reason and tooltip.gcd==1 and tooltip.cooldown==0
 and tooltip.holyShockModifierConsumption.gcdAura==51865
 and tooltip.holyShockModifierConsumption.cooldownAura==52661,
 "engine-effective GCD and cooldown must be sealed without recomputing modifiers")
local sibling={}; Graph:Copy(state,sibling)
assert(Graph:Consume(state,{action=action,tooltip=tooltip})
 and state.paladinHolyShockModifiers.gcd.consumed
 and state.paladinHolyShockModifiers.cooldown.consumed
 and sibling.paladinHolyShockModifiers.gcd.active,
 "consumption must affect only the selected branch")
tooltip,reason,handled=Graph:PrepareLegal(action,state,{gcd=1.5,cooldown=20})
assert(handled and tooltip==nil and reason,
 "post-consumption baseline timing must fail closed until refreshed")
rows[52661].effectBasePoints={-100,0,0}
snapshot=Runtime:Snapshot("PALADIN")
assert(not snapshot.available and snapshot.reason,
 "recognized modifier topology drift must fail closed")
print("ok: Paladin Holy Shock observed modifier-chain consumption")
