-- Installed patch-5 Seal of the Martyr linkage. The two outgoing Holy packets
-- are numeric; their paired self-damage arithmetic is private and deliberately
-- prevents the compound action from being treated as fully representable.
XelAssist.Game.Player.PaladinMartyr={}
local M=XelAssist.Game.Player.PaladinMartyr
M.SEAL_ID=45802; M.PROC_ID=45814; M.PROC_SELF_ID=45815
M.JUDGEMENT_ACTION_ID=20271; M.JUDGEMENT_ID=45816; M.JUDGEMENT_SELF_ID=45817
local CACHE
local function scalar(id,f) if type(GetSpellRecField)~="function" then return nil end local ok,v=pcall(GetSpellRecField,id,f);return ok and tonumber(v) or nil end
local function triple(id,f,a,b,c) if type(GetSpellRecField)~="function" then return false end local ok,v=pcall(GetSpellRecField,id,f,1);return ok and type(v)=="table" and v[4]==nil and tonumber(v[1])==a and tonumber(v[2])==b and tonumber(v[3])==c end
local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=type(v)=="table" and copy(v) or v end return o end
local function seal()
 return scalar(45802,"school")==1 and scalar(45802,"attributes")==327680
  and scalar(45802,"procFlags")==4 and scalar(45802,"procChance")==100
  and scalar(45802,"procCharges")==0 and scalar(45802,"durationIndex")==9
  and scalar(45802,"powerType")==0 and scalar(45802,"manaCost")==210
  and scalar(45802,"rangeIndex")==1 and scalar(45802,"spellFamilyName")==10
  and scalar(45802,"spellFamilyFlags")==33554432
  and scalar(45802,"startRecoveryCategory")==133 and scalar(45802,"startRecoveryTime")==1500
  and triple(45802,"effect",6,6,6) and triple(45802,"effectBasePoints",19,10,45816)
  and triple(45802,"effectImplicitTargetA",1,1,1)
  and triple(45802,"effectApplyAuraName",4,42,4)
  and triple(45802,"effectItemType",30,0,45816)
  and triple(45802,"effectTriggerSpell",0,45814,0)
end
local function proc()
 return scalar(45814,"school")==1 and scalar(45814,"attributes")==262144
  and scalar(45814,"attributesEx3")==512 and scalar(45814,"attributesEx4")==128
  and scalar(45814,"rangeIndex")==2 and scalar(45814,"dmgClass")==2
  and triple(45814,"effect",31,0,0) and triple(45814,"effectBasePoints",19,0,0)
  and triple(45814,"effectImplicitTargetA",6,0,0)
end
local function selfRows()
 return scalar(45815,"school")==1 and scalar(45815,"attributes")==2097152
  and scalar(45815,"attributesEx2")==536870912 and scalar(45815,"attributesEx3")==196608
  and triple(45815,"effect",2,0,0) and triple(45815,"effectBasePoints",0,0,0)
  and triple(45815,"effectImplicitTargetA",1,0,0)
  and scalar(45817,"school")==1 and scalar(45817,"attributes")==2097152
  and scalar(45817,"attributesEx2")==536870912 and scalar(45817,"attributesEx3")==196608
  and triple(45817,"effect",2,0,0) and triple(45817,"effectBasePoints",0,0,0)
  and triple(45817,"effectImplicitTargetA",1,0,0)
end
local function judgement()
 return scalar(45816,"school")==1 and scalar(45816,"attributes")==2097152
  and scalar(45816,"attributesEx3")==262656 and scalar(45816,"maxLevel")==68
  and scalar(45816,"baseLevel")==60 and scalar(45816,"spellLevel")==60
  and scalar(45816,"rangeIndex")==13 and scalar(45816,"dmgClass")==2
  and triple(45816,"effect",2,0,0) and triple(45816,"effectDieSides",30,0,0)
  and triple(45816,"effectBaseDice",1,0,0)
  and triple(45816,"effectRealPointsPerLevel",6.099999904632568,0,0)
  and triple(45816,"effectBasePoints",169,0,0)
  and triple(45816,"effectImplicitTargetA",6,0,0)
end
function M:Profile()
 if CACHE then return CACHE.valid and copy(CACHE) or nil,CACHE.reason end
 if not (seal() and proc() and judgement() and selfRows()) then CACHE={valid=false,reason="Martyr linked topology is incomplete"};return nil,CACHE.reason end
 CACHE={valid=true,exact=true,sealSpellId=45802,procSpellId=45814,
  judgementSpellId=45816,weaponHolyCoefficient=.20,sealEnergyLink=45816,
  judgementBasePoints=169,judgementDieSides=30,judgementPointsPerLevel=6.099999904632568,
  procSelfSpellId=45815,judgementSelfSpellId=45817,
  selfHealthArithmeticExact=false,compoundRepresentable=false,
  gap="self-health recipient is numeric but private damage arithmetic/linkage is not",
  source="installed patch-5 Martyr seal/trigger/Judgement topology"}
 return copy(CACHE)
end
function M:CaptureFacts(action,facts)
 local id=tonumber(action and action.spellId); if id~=45802 and id~=20271 then return facts end
 local out=copy(facts);local p,reason=self:Profile()
 out.paladinMartyr=id==45802 or nil;out.paladinMartyrJudgement=id==20271 or nil
 out.paladinMartyrExact=p~=nil;out.paladinMartyrEvidence=p
 out.paladinMartyrReason=not p and reason or nil
 return out
end
function M:Snapshot()
 local p,reason=self:Profile()
 return p and {available=true,exact=true,profile=p} or
  {available=false,exact=false,reason=reason}
end
function M:Invalidate() CACHE=nil end
