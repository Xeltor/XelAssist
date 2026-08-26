XelAssist={Game={Player={}}}
function UnitClass() return "Rogue","ROGUE" end
function GetSpellRangeData(id) assert(id==2); return 0,5 end
local scalar={school=0,category=0,mechanic=0,attributes=2424848,
 attributesEx=134218240,attributesEx2=0,attributesEx3=1024,attributesEx4=0,
 stances=0,stancesNot=0,castingTimeIndex=1,recoveryTime=180000,
 categoryRecoveryTime=0,durationIndex=21,powerType=3,manaCost=40,
 manaCostPerlevel=0,rangeIndex=2,equippedItemClass=2,
 equippedItemSubClassMask=173555,equippedItemInventoryTypeMask=0,
 spellFamilyName=8,spellFamilyFlags=34359738368,startRecoveryCategory=133,
 startRecoveryTime=1000,dmgClass=2,preventionType=2}
local arrays={effect={31,0,80},effectDieSides={1,0,1},effectBaseDice={1,0,1},
 effectDicePerLevel={0,0,0},effectRealPointsPerLevel={0,0,0},
 effectBasePoints={134,0,1},effectImplicitTargetA={6,0,6},
 effectImplicitTargetB={0,0,0},effectApplyAuraName={0,0,0},
 effectItemType={0,0,0},effectTriggerSpell={0,0,0},
 effectPointsPerComboPoint={0,0,0}}
function GetSpellRecField(id,field,array)
 assert(id==52538); if array then local v=arrays[field] or {0,0,0}; return {v[1],v[2],v[3]} end
 return scalar[field]
end
dofile("Game/Player/RogueMarkForDeath.lua")
local M=XelAssist.Game.Player.RogueMarkForDeath
local profile=M:Profile()
assert(profile.exact and profile.weaponPercent==135 and profile.comboGain==2
 and profile.energyCost==40 and profile.cooldown==180
 and profile.requiresMainHandWeapon and profile.target=="hostile unit")
local facts,reason,handled=M:InferKnowledge(52538)
assert(handled and not reason and facts.kind=="builder" and facts.comboGain==2
 and facts.weaponHand=="main" and facts.usesWeaponSkill
 and facts.bypassesDodge and facts.bypassesParry and facts.bypassesBlock
 and not facts.alwaysHit and facts.requiresExactUsability)
local action={spellId=52538,facts=facts}
local captured=M:CaptureFacts(action,{cost=40})
assert(captured.weaponCoefficient==1.35 and captured.weaponNormalized==false
 and captured.comboGain==2 and captured.markForDeathPacketExact)
local forged=M:CaptureFacts({spellId=52538,facts={markForDeathEvidence={
 valid=true,exact=true,weaponPercent=134,comboGain=2,requiresMainHandWeapon=true}}},{})
assert(not forged.weaponCoefficient,"forged weapon packet accepted")
scalar.equippedItemSubClassMask=0; M:Invalidate()
local shifted,shiftReason=M:Profile()
assert(not shifted and shiftReason,"shifted equipment topology accepted")
print("ok: exact Rogue Mark for Death weapon/combo packet")
