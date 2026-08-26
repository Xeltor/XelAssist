-- Exact installed Shield Block and Octo Improved Shield Block ownership.
XelAssist.Game.Player.WarriorShieldBlock={}
local S=XelAssist.Game.Player.WarriorShieldBlock
S.SPELL_ID=2565; S.TALENT_ID=45575; S.DEFENSIVE_FORM_ID=18
local function scalar(id,f) if type(GetSpellRecField)~="function" then return nil end local ok,v=pcall(GetSpellRecField,id,f); return ok and tonumber(v) or nil end
local function tri(id,f,a,b,c) if type(GetSpellRecField)~="function" then return false end local ok,v=pcall(GetSpellRecField,id,f,1); return ok and type(v)=="table" and v[4]==nil and tonumber(v[1])==a and tonumber(v[2])==b and tonumber(v[3])==c end
local function exactBase()
 return scalar(2565,"school")==0 and scalar(2565,"attributes")==327696
  and scalar(2565,"attributesEx3")==2 and scalar(2565,"stances")==131072
  and scalar(2565,"durationIndex")==28 and scalar(2565,"powerType")==1
  and scalar(2565,"manaCost")==100 and scalar(2565,"recoveryTime")==5000
  and scalar(2565,"spellFamilyName")==4 and scalar(2565,"spellFamilyFlags")==4096
  and scalar(2565,"equippedItemClass")==4 and scalar(2565,"equippedItemSubClassMask")==64
  and scalar(2565,"procCharges")==1 and tri(2565,"effect",6,0,0)
  and tri(2565,"effectBasePoints",74,0,0) and tri(2565,"effectApplyAuraName",51,0,0)
end
local function exactTalent()
 return scalar(45575,"attributes")==262352 and scalar(45575,"spellFamilyName")==4
  and tri(45575,"effect",6,6,0) and tri(45575,"effectBasePoints",1,1000,0)
  and tri(45575,"effectApplyAuraName",107,107,0)
  and tri(45575,"effectMiscValue",4,1,0)
end
local function learned(id) if type(IsPlayerSpell)~="function" then return nil end local ok,v=pcall(IsPlayerSpell,id); if not ok or type(v)~="boolean" then return nil end return v end
local function warrior() if type(UnitClass)~="function" then return false end local ok,_,v=pcall(UnitClass,"player"); return ok and v=="WARRIOR" end
function S:InferKnowledge(id)
 if tonumber(id)~=2565 then return nil,"not Shield Block",false end
 if not warrior() then return nil,"player is not a Warrior",false end
 if learned(2565)~=true then return nil,"Shield Block ownership unavailable",true end
 if not exactBase() then return nil,"Shield Block topology shifted",true end
 local talent=learned(45575); if talent==nil then return nil,"Improved Shield Block ownership unavailable",true end
 if talent and not exactTalent() then return nil,"Improved Shield Block topology shifted",true end
 local duration
 if type(GetSpellDuration)=="function" then local ok,v=pcall(GetSpellDuration,2565); if ok then duration=tonumber(v) end end
 if not duration or duration<=0 or duration>60000 then return nil,"effective Shield Block duration unavailable",true end
 return {inferred=true,kind="defensive",kindExact=true,self=true,gcd=0,
  resourceType="rage",stanceMask=131072,requiresShield=true,
  testEquippedItemClass=4,testEquippedItemSubClassMask=64,
  warriorShieldBlock=true,warriorShieldBlockEvidence={exact=true,spellId=2565,
   talentSpellId=talent and 45575 or nil,charges=talent and 2 or 1,
   duration=duration/1000,blockChanceBonus=75,cost=10,
   source="installed patch-5 rows and engine-effective duration"},
  requiresExactUsability=true,submissionGuarded=true},nil,true
end

