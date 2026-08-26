-- Exact patch-5 Ascendance identity and observed self-aura evidence. Mutable
-- healing costs/cast times come only from engine APIs while aura 52963 is live.
-- CC purge and Apotheosis recipients are intentionally not inferred.
XelAssist.Game.Player.PriestAscendance = {}
local A = XelAssist.Game.Player.PriestAscendance
A.SPELL_ID, A.AURA_ID, A.APOTHEOSIS_ID = 52962, 52963, 52964
A.PRIEST_FAMILY, A.FAMILY_FLAG, A.MANA = 6, 2147483648, 0
local PROFILE

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then return nil end
    return value
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, key, count, index = {}, nil, 0, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > 3
            or math.floor(key) ~= key then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do out[index] = finite(values[index]); if out[index] == nil then return nil end end
    return out
end
local function equal(v,a,b,c) return v and v[1]==a and v[2]==b and v[3]==c end
local function actionTopology()
    local id=A.SPELL_ID
    return scalar(id,"school")==1 and scalar(id,"attributes")==256
        and scalar(id,"attributesEx")==268468224
        and scalar(id,"attributesEx2")==2097152
        and scalar(id,"attributesEx3")==0 and scalar(id,"attributesEx4")==0
        and scalar(id,"stances")==0 and scalar(id,"stancesNot")==0
        and scalar(id,"castingTimeIndex")==1 and scalar(id,"recoveryTime")==300000
        and scalar(id,"durationIndex")==37 and scalar(id,"powerType")==A.MANA
        and scalar(id,"manaCost")==280 and scalar(id,"manaCostPerlevel")==0
        and scalar(id,"manaCostPercentage")==0 and scalar(id,"rangeIndex")==1
        and scalar(id,"spellFamilyName")==A.PRIEST_FAMILY
        and scalar(id,"spellFamilyFlags")==A.FAMILY_FLAG
        and equal(triple(id,"effect"),6,6,64)
        and equal(triple(id,"effectDieSides"),1,1,1)
        and equal(triple(id,"effectBaseDice"),1,1,1)
        and equal(triple(id,"effectBasePoints"),0,0,0)
        and equal(triple(id,"effectImplicitTargetA"),1,1,1)
        and equal(triple(id,"effectImplicitTargetB"),0,0,0)
        and equal(triple(id,"effectApplyAuraName"),39,147,0)
        and equal(triple(id,"effectMiscValue"),127,545341011,0)
        and equal(triple(id,"effectTriggerSpell"),0,0,A.AURA_ID)
end
local function auraTopology()
    local id=A.AURA_ID
    return scalar(id,"school")==1 and scalar(id,"dispel")==1
        and scalar(id,"attributes")==0 and scalar(id,"durationIndex")==2
        and scalar(id,"spellFamilyName")==A.PRIEST_FAMILY
        and scalar(id,"spellFamilyFlags")==0
        and equal(triple(id,"effect"),6,6,6)
        and equal(triple(id,"effectApplyAuraName"),108,108,109)
        and equal(triple(id,"effectBasePoints"),-21,-34,99)
        and equal(triple(id,"effectBaseDice"),1,1,1)
        and equal(triple(id,"effectImplicitTargetA"),1,1,1)
        and equal(triple(id,"effectItemType"),269888,269888,269888)
        and equal(triple(id,"effectMiscValue"),10,14,0)
        and equal(triple(id,"effectTriggerSpell"),0,0,A.APOTHEOSIS_ID)
end
local function apotheosisTopology()
    local id=A.APOTHEOSIS_ID
    return scalar(id,"school")==1 and scalar(id,"dispel")==1
        and scalar(id,"durationIndex")==1 and scalar(id,"rangeIndex")==6
        and scalar(id,"spellFamilyName")==A.PRIEST_FAMILY
        and equal(triple(id,"effect"),6,0,0)
        and equal(triple(id,"effectApplyAuraName"),118,0,0)
        and equal(triple(id,"effectBasePoints"),14,0,0)
        and equal(triple(id,"effectImplicitTargetA"),45,0,0)
        and equal(triple(id,"effectMiscValue"),126,0,0)
        and equal(triple(id,"effectTriggerSpell"),0,0,0)
end
local function profile()
    if PROFILE then return PROFILE.valid and PROFILE or nil, PROFILE.reason end
    local valid=actionTopology() and auraTopology() and apotheosisTopology()
    PROFILE=valid and {valid=true,exact=true,spellId=A.SPELL_ID,auraId=A.AURA_ID,
        apotheosisId=A.APOTHEOSIS_ID,healCastPercent=-20,healCostPercent=-33,
        source="installed Octo patch-5 Ascendance topology"}
        or {valid=false,reason="Ascendance DBC topology is incomplete"}
    return valid and PROFILE or nil, PROFILE.reason
end
local function priest()
    if type(UnitClass)~="function" then return false end
    local ok,_,token=pcall(UnitClass,"player"); return ok and token=="PRIEST"
end
local function auraActive()
    if not (type(GetPlayerBuff)=="function" and type(GetPlayerBuffID)=="function") then return nil end
    local index
    for index=0,31 do
        local ok,slot=pcall(GetPlayerBuff,index,"HELPFUL")
        if not ok then return nil end
        if slot and slot~=-1 then
            local idOK,id=pcall(GetPlayerBuffID,slot)
            if not idOK then return nil end
            if id and id< -1 then id=id+65536 end
            if tonumber(id)==A.AURA_ID then return true end
        end
    end
    return false
end
local function cost(id)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost)=="function") then return nil end
    local ok,costs=pcall(C_Spell.GetSpellPowerCost,id)
    if not ok or type(costs)~="table" or table.getn(costs)~=1
        or type(costs[1])~="table" then return nil end
    local value=finite(costs[1].cost)
    if tonumber(costs[1].type)~=A.MANA or not value or value<0 then return nil end
    return value
end
local function castTime(id)
    local api=C_Spell and C_Spell.GetSpellCastTime
    if type(api)~="function" then return nil end
    local ok,value=pcall(api,id); value=ok and finite(value) or nil
    return value and value>=0 and value/1000 or nil
end

function A:InferKnowledge(spellId)
    if tonumber(spellId)~=self.SPELL_ID then return nil,"not Ascendance",false end
    if not priest() then return nil,"player is not Priest",false end
    local found,reason=profile(); if not found then return nil,reason,true end
    return {inferred=true,kind="modifier",kindExact=true,self=true,
        fixedTarget="player",recipientRelation="friendly",
        recipientRelationExact=true,priestAscendance=true,
        requiresPriestAscendanceEvidence=true,submissionGuarded=true,
        priestAscendanceEvidence=found,source=found.source},nil,true
end
function A:Snapshot()
    if not priest() then return nil end
    local found,reason=profile(); if not found then return {exact=false,reason=reason} end
    local active=auraActive()
    if active==nil then return {exact=false,reason="Ascendance self aura unavailable"} end
    return {exact=true,active=active,auraId=self.AURA_ID,
        effectsProjectable=false,
        unresolved="future heal cast/cost require post-application engine evidence",
        source=found.source}
end
function A:CaptureFacts(action,facts,state)
    local out,key,value={},nil,nil; for key,value in pairs(facts or {}) do out[key]=value end
    if not (action and tonumber(action.spellId) and priest()) then return out end
    if tonumber(action.spellId)==self.SPELL_ID then
        local found,reason=profile(); if not found then out.priestAscendanceReason=reason; return out end
        local exactCost=cost(self.SPELL_ID)
        if exactCost==nil then out.priestAscendanceReason="Ascendance engine cost unavailable"; return out end
        out.cost=exactCost; out.priestAscendance=true
        out.priestAscendanceEvidence=found; out.priestAscendanceCostExact=true
        return out
    end
    local snapshot=state and state.priestAscendance
    local kind=out.kind
    if not (snapshot and snapshot.exact and snapshot.active
        and (kind=="heal" or kind=="hot")) then return out end
    local exactCost,exactCast=cost(tonumber(action.spellId)),castTime(tonumber(action.spellId))
    if exactCost~=nil then out.cost=exactCost; out.priestAscendanceCostExact=true end
    if exactCast~=nil then out.cast=exactCast; out.priestAscendanceCastExact=true
    else out.priestAscendanceCastReason="engine effective heal cast time unavailable" end
    out.priestAscendanceConsumerExact=exactCost~=nil and exactCast~=nil
    return out
end
function A:Invalidate() PROFILE=nil end
