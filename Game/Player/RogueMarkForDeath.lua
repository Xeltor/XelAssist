-- Exact installed patch-5 Mark for Death weapon/combo packet. This describes
-- the action's causal packet, not a priority: generic graph delivery decides
-- whether the hostile-target weapon hit lands and therefore awards its points.
XelAssist.Game.Player.RogueMarkForDeath = {}
local M=XelAssist.Game.Player.RogueMarkForDeath
M.SPELL_ID=52538
M.IMPOSSIBLE_DODGE_PARRY_BLOCK=2097152
local PROFILE

local function scalar(field)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,value=pcall(GetSpellRecField,M.SPELL_ID,field)
    return ok and tonumber(value) or nil
end
local function triple(field,a,b,c)
    if type(GetSpellRecField)~="function" then return false end
    local ok,v=pcall(GetSpellRecField,M.SPELL_ID,field,1)
    return ok and type(v)=="table" and v[4]==nil
        and tonumber(v[1])==a and tonumber(v[2])==b and tonumber(v[3])==c
end
local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=v end return o end
local function rogue()
    if type(UnitClass)~="function" then return false end
    local ok,_,token=pcall(UnitClass,"player"); return ok and token=="ROGUE"
end
local function rangeExact()
    if scalar("rangeIndex")~=2 or type(GetSpellRangeData)~="function" then return false end
    local ok,minimum,maximum=pcall(GetSpellRangeData,2)
    return ok and tonumber(minimum)==0 and tonumber(maximum)==5
end
local function topology()
    local attributes=scalar("attributes")
    return scalar("school")==0 and scalar("category")==0
        and scalar("mechanic")==0 and attributes==2424848
        and math.floor(attributes/M.IMPOSSIBLE_DODGE_PARRY_BLOCK)
            - math.floor(attributes/(M.IMPOSSIBLE_DODGE_PARRY_BLOCK*2))*2==1
        and scalar("attributesEx")==134218240 and scalar("attributesEx2")==0
        and scalar("attributesEx3")==1024 and scalar("attributesEx4")==0
        and scalar("stances")==0 and scalar("stancesNot")==0
        and scalar("castingTimeIndex")==1 and scalar("recoveryTime")==180000
        and scalar("categoryRecoveryTime")==0 and scalar("durationIndex")==21
        and scalar("powerType")==3 and scalar("manaCost")==40
        and scalar("manaCostPerlevel")==0 and scalar("rangeIndex")==2
        and scalar("equippedItemClass")==2
        and scalar("equippedItemSubClassMask")==173555
        and scalar("equippedItemInventoryTypeMask")==0
        and scalar("spellFamilyName")==8
        and scalar("spellFamilyFlags")==34359738368
        and scalar("startRecoveryCategory")==133
        and scalar("startRecoveryTime")==1000
        and scalar("dmgClass")==2 and scalar("preventionType")==2
        and triple("effect",31,0,80)
        and triple("effectDieSides",1,0,1)
        and triple("effectBaseDice",1,0,1)
        and triple("effectDicePerLevel",0,0,0)
        and triple("effectRealPointsPerLevel",0,0,0)
        and triple("effectBasePoints",134,0,1)
        and triple("effectImplicitTargetA",6,0,6)
        and triple("effectImplicitTargetB",0,0,0)
        and triple("effectApplyAuraName",0,0,0)
        and triple("effectItemType",0,0,0)
        and triple("effectTriggerSpell",0,0,0)
        and triple("effectPointsPerComboPoint",0,0,0)
        and rangeExact()
end

function M:Profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil,PROFILE.reason end
    if not topology() then
        PROFILE={valid=false,exact=false,reason="Mark for Death DBC topology is incomplete"}
        return nil,PROFILE.reason
    end
    PROFILE={valid=true,exact=true,spellId=self.SPELL_ID,
        weaponPercent=135,comboGain=2,energyCost=40,cooldown=180,gcd=1,
        minRange=0,maxRange=5,requiresMainHandWeapon=true,
        equipmentClass=2,equipmentSubclassMask=173555,
        bypassesDodge=true,bypassesParry=true,bypassesBlock=true,
        bypassesOrdinaryMiss=false,target="hostile unit",
        source="installed patch-5 Spell.dbc Mark for Death topology"}
    return copy(PROFILE)
end

function M:InferKnowledge(spellId)
    if tonumber(spellId)~=self.SPELL_ID then return nil,"not Mark for Death",false end
    if not rogue() then return nil,"player is not a Rogue",false end
    local found,reason=self:Profile()
    if not found then return nil,reason,true end
    return {inferred=true,kind="builder",kindExact=true,melee=true,school=0,
        comboBuilder=true,comboGain=2,weaponPercent=135,weaponHand="main",
        usesWeaponSkill=true,requiresMainHandWeapon=true,
        markForDeath=true,markForDeathEvidence=found,
        deliveryModel="physical",deliverySubtype="melee",
        bypassesDodge=true,bypassesParry=true,bypassesBlock=true,
        alwaysHit=false,requiresExactUsability=true,submissionGuarded=true,
        source=found.source},nil,true
end

function M:CaptureFacts(action,facts)
    local out=copy(facts); local evidence=action and action.facts and action.facts.markForDeathEvidence
    if not (action and tonumber(action.spellId)==self.SPELL_ID and type(evidence)=="table"
        and evidence.valid==true and evidence.exact==true
        and evidence.weaponPercent==135 and evidence.comboGain==2
        and evidence.requiresMainHandWeapon==true) then return out end
    out.weaponCoefficient=1.35; out.weaponNormalized=false
    out.weaponHand="main"; out.usesWeaponSkill=true
    out.comboGain=2; out.comboBuilder=true
    out.markForDeathPacketExact=true
    return out
end

function M:Invalidate() PROFILE=nil end
