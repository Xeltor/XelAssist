-- Root-captured Turtle Stinging Nettle evidence for Mongoose Bite.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.HunterStingingNettle = {}
local N = XelAssist.Game.Player.HunterStingingNettle
N.TALENTS, N.PERCENT = { 51580, 51579 }, { [51579]=20, [51580]=40 }
N.MONGOOSE = { [1495]=true, [14269]=true, [14270]=true, [14271]=true }
N.STINGS = { 33459,25295,13555,13554,13553,13552,13551,13550,13549,1978 }
local function copy(s) local o,k,v={},nil,nil; for k,v in pairs(s or {}) do o[k]=v end; return o end
local function scalar(id, field)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,field); return ok and tonumber(v) or nil
end
local function triple(id, field)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,field,1)
    if not ok or type(v)~="table" then return nil end
    local out,count,key,index={},0,nil,nil
    for key in pairs(v) do
        if type(key)~="number" or key<1 or key>3
            or key~=math.floor(key) then return nil end
        count=count+1
    end
    if count~=3 then return nil end
    for index=1,3 do
        out[index]=tonumber(v[index])
        if out[index]==nil then return nil end
    end
    return out
end
local function eq(v,a,b,c) return v and tonumber(v[1])==a and tonumber(v[2])==b and tonumber(v[3])==c end
local function known(id)
    if type(IsPlayerSpell)~="function" then return nil end
    local ok,v=pcall(IsPlayerSpell,id)
    if not ok then return nil end
    return v==true or v==1
end
local function mongoose(id)
    return N.MONGOOSE[id] and scalar(id,"spellFamilyName")==9
        and scalar(id,"spellFamilyFlags")==2
        and eq(triple(id,"effect"),2,31,0)
        and eq(triple(id,"effectImplicitTargetA"),6,6,0)
end
local function talent(id)
    local pct=N.PERCENT[id]
    return pct and scalar(id,"spellFamilyName")==9 and scalar(id,"attributes")==464
        and eq(triple(id,"effect"),6,0,0)
        and eq(triple(id,"effectApplyAuraName"),4,0,0)
        and eq(triple(id,"effectImplicitTargetA"),1,0,0)
        and eq(triple(id,"effectBasePoints"),pct-1,0,0)
end
local function sting(id)
    if scalar(id,"spellFamilyName")~=9 or scalar(id,"spellFamilyFlags")~=16384
        or not eq(triple(id,"effect"),6,0,0)
        or not eq(triple(id,"effectApplyAuraName"),3,0,0)
        or not eq(triple(id,"effectAmplitude"),3000,0,0)
        or not eq(triple(id,"effectImplicitTargetA"),6,0,0) then return nil end
    local p,d,s=triple(id,"effectBasePoints"),triple(id,"effectBaseDice"),triple(id,"effectDieSides")
    if not (p and d and s and tonumber(s[1])==1) then return nil end
    local tick=(tonumber(p[1]) or -1)+(tonumber(d[1]) or 0)
    return tick>0 and tick or nil
end
local function evidence(action)
    local id=tonumber(action and action.spellId); if not mongoose(id) then return nil end
    local talentId,index
    for index=1,table.getn(N.TALENTS) do
        local candidate=N.TALENTS[index]; local learned=known(candidate)
        if learned==nil then return nil,"Stinging Nettle knowledge unavailable" end
        if learned then talentId=candidate; break end
    end
    if not talentId then return {active=false,exact=true} end
    if not talent(talentId) then return nil,"Stinging Nettle talent topology changed" end
    local stingId
    for index=1,table.getn(N.STINGS) do
        local candidate=N.STINGS[index]; local learned=known(candidate)
        if learned==nil then return nil,"Serpent Sting knowledge unavailable" end
        if learned then stingId=candidate; break end
    end
    if not stingId then return nil,"highest Serpent Sting rank unavailable" end
    local tick=sting(stingId)
    if not tick or type(GetSpellDuration)~="function" then return nil,"Serpent Sting topology unavailable" end
    local ok,baseMs=pcall(GetSpellDuration,stingId); baseMs=ok and tonumber(baseMs) or nil
    local pct=N.PERCENT[talentId]; local duration=baseMs and baseMs*pct/100000 or nil
    if not duration or duration<=0 or duration/3~=math.floor(duration/3) then
        return nil,"Stinging Nettle tick duration unavailable" end
    return {active=true,exact=true,triggerSpellId=id,talentSpellId=talentId,
        stingSpellId=stingId,percent=pct,duration=duration,interval=3,
        tickDamage=tick,totalDamage=tick*duration/3,ignoresResistances=true,
        magnitudeEstimated=true,
        source="patch-5 DBC plus ClassicAPI StingingNettle trigger contract"}
end
function N:CaptureFacts(action,facts)
    local out=copy(facts); if not self.MONGOOSE[tonumber(action and action.spellId)] then return out end
    local found,reason=evidence(action); out.stingingNettleEvidence=found
    out.stingingNettleEvidenceReason=reason; out.requiresStingingNettleEvidence=true
    return out
end
function N:Evidence(subject)
    local facts=type(subject)=="table" and subject.facts or subject
    local found=facts and facts.stingingNettleEvidence
    return type(found)=="table" and found.exact==true and copy(found) or nil
end
