-- Observed-only build-5875 Mage proc windows. Learned passives establish
-- ownership, but only an exact numeric player aura establishes availability.
XelAssist.Game.Player.MageProcWindows = {}
local M = XelAssist.Game.Player.MageProcWindows

M.HOT = { [51927]={chance=50,aura=51930}, [51928]={chance=100,aura=51931} }
M.FREEZE = { [51999]={chance=50,aura=52500}, [52501]={chance=100,aura=52500} }
M.PYRO = { [11366]=true,[12505]=true,[12522]=true,[12523]=true,[12524]=true,
    [12525]=true,[12526]=true,[12527]=true,[18809]=true }
M.ICICLES = { [52516]=true,[51991]=true,[51995]=true,[51997]=true }
M.MAX_AURAS = 48

local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=v end return o end
local function number(v,lo,hi) v=tonumber(v); return v and v==v and v>=lo and v<=hi and v or nil end
local function integer(v,lo,hi) v=number(v,lo,hi); return v and math.floor(v)==v and v or nil end
local function scalar(id,f)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,f); return ok and tonumber(v) or nil
end
local function triple(id,f)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,f,1)
    if not ok or type(v)~="table" or table.getn(v)~=3 then return nil end
    return v
end
local function eq(v,a,b,c) return v and v[1]==a and v[2]==b and v[3]==c end
local function flag(value, bit)
    return math.floor(value / bit) - math.floor(value / (bit * 2)) * 2 == 1
end
local function token()
    if type(UnitClass)~="function" then return nil end
    local ok,_,v=pcall(UnitClass,"player"); return ok and v or nil
end
local function guid()
    if type(UnitGUID)~="function" then return nil end
    local ok,v=pcall(UnitGUID,"player"); return ok and v or nil
end

local function passiveExact(id, spec, freeze)
    return scalar(id,"school")== (freeze and 4 or 2)
        and scalar(id,"attributes")==464 and scalar(id,"procFlags")==65536
        and scalar(id,"procChance")==spec.chance and scalar(id,"procCharges")==0
        and scalar(id,"durationIndex")==21 and scalar(id,"spellFamilyName")==3
        and eq(triple(id,"effect"),6,0,0)
        and eq(triple(id,"effectApplyAuraName"),42,0,0)
        and eq(triple(id,"effectTriggerSpell"),spec.aura,0,0)
end
local function hotAuraExact(id)
    return scalar(id,"school")==2 and scalar(id,"dispel")==1
        and scalar(id,"procFlags")==87376 and scalar(id,"procChance")==100
        and scalar(id,"procCharges")==1 and scalar(id,"durationIndex")==25
        and scalar(id,"spellFamilyName")==3 and scalar(id,"stackAmount")==5
        and eq(triple(id,"effect"),6,0,0)
        and eq(triple(id,"effectBasePoints"),4294966295,0,0)
        and eq(triple(id,"effectApplyAuraName"),107,0,0)
        and eq(triple(id,"effectMiscValue"),10,0,0)
        and eq(triple(id,"effectItemType"),4194304,0,0)
end
local function freezeAuraExact()
    local id=52500
    return scalar(id,"school")==4 and scalar(id,"dispel")==1
        and scalar(id,"attributes")==327680 and scalar(id,"durationIndex")==1
        and scalar(id,"spellFamilyName")==3
        and eq(triple(id,"effect"),6,6,77)
        and eq(triple(id,"effectBasePoints"),4294967215,4294967215,0)
        and eq(triple(id,"effectApplyAuraName"),108,108,0)
        and eq(triple(id,"effectMiscValue"),1,19,0)
end
local function consumerExact(id, kind)
    if scalar(id,"spellFamilyName")~=3 then return false end
    if kind=="hotStreak" then
        local flags=scalar(id,"spellFamilyFlags")
        return scalar(id,"school")==2 and flags
            and flag(flags,4194304)
            and scalar(id,"castingTimeIndex")==171
            and eq(triple(id,"effect"),2,6,0)
    end
    return scalar(id,"school")==4 and scalar(id,"spellFamilyFlags")==524288
        and scalar(id,"spellFamilyFlags2")==8
        and scalar(id,"castingTimeIndex")==1
        and eq(triple(id,"effect"),6,6,64)
end

function M:CaptureFacts(action, facts, state)
    local id=action and action.spellId
    local kind=self.PYRO[id] and "hotStreak" or self.ICICLES[id] and "flashFreeze"
    if not kind then return facts end
    local out=copy(facts); out.mageProcConsumer=kind
    out.mageProcConsumerExact=consumerExact(id,kind)
    if not out.mageProcConsumerExact then
        out.mageProcReason="Mage proc consumer topology is incomplete"; return out
    end
    local root=state and state.mageProcWindows
    if root and root.available and root.exact and root[kind]
        and root[kind].active then
        local cast=number(out.cast,0,600)
        local cost=number(out.cost,0,1000000)
        if cast~=nil and cost~=nil then
            out.mageProcContract={ exact=true, kind=kind, spellId=id,
                auraSpellId=root[kind].auraSpellId, cast=cast, cost=cost,
                source="engine-effective root action facts" }
        end
    end
    return out
end

local function learned(which, freeze)
    local found,spec=nil,nil
    for id,v in pairs(which) do
        local ok,has=pcall(IsPlayerSpell,id)
        if not ok or type(has)~="boolean" then return nil,nil,"ownership unavailable" end
        if has then
            if found then return nil,nil,"multiple ranks learned" end
            found,spec=id,v
        end
    end
    if found and not passiveExact(found,spec,freeze) then return nil,nil,"passive topology shifted" end
    return found,spec
end

function M:Snapshot(class)
    local out={available=false,exact=false,source="numeric Mage passive and observed self aura"}
    if class~="MAGE" or token()~="MAGE" or type(IsPlayerSpell)~="function"
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras)=="function")
        or type(GetTime)~="function" then out.reason="Mage proc evidence unavailable"; return out end
    local hotId,hotSpec,reason=learned(self.HOT,false)
    if reason then out.reason="Hot Streak "..reason; return out end
    local freezeId,freezeSpec; freezeId,freezeSpec,reason=learned(self.FREEZE,true)
    if reason then out.reason="Flash Freeze "..reason; return out end
    local before=guid(); local ok,list=pcall(C_UnitAuras.GetUnitAuras,"player","HELPFUL")
    local clockOK,now=pcall(GetTime)
    if not before or not ok or type(list)~="table" or table.getn(list)>self.MAX_AURAS
        or guid()~=before or not clockOK then out.reason="Mage aura snapshot unavailable"; return out end
    local hot={learned=hotId~=nil,learnedSpellId=hotId,active=false}
    local freeze={learned=freezeId~=nil,learnedSpellId=freezeId,active=false}
    for i=1,table.getn(list) do
        local a=list[i]; local id=type(a)=="table" and integer(a.spellId,1,4294967295)
        if not id then out.reason="numeric self aura evidence unavailable"; return out end
        local kind=(id==51930 or id==51931) and "hot" or id==52500 and "freeze"
        if kind then
            local dest=kind=="hot" and hot or freeze
            local expected=kind=="hot" and hotSpec and hotSpec.aura or freezeSpec and freezeSpec.aura
            local stacks=integer(a.applications,1,kind=="hot" and 5 or 1)
            local duration=number(a.duration,0.001,3600); local expiration=number(a.expirationTime,now,now+3600)
            local topology
            if kind=="hot" then topology=hotAuraExact(id)
            else topology=freezeAuraExact() end
            if dest.active or id~=expected or not topology or a.isHelpful~=true
                or not stacks or not duration or not expiration or expiration-now>duration+0.001 then
                out.reason="Mage proc aura ownership or lifetime is incoherent"; return out
            end
            dest.active,dest.auraSpellId,dest.stacks,dest.expiresAt=true,id,stacks,expiration-now
        end
    end
    out.available,out.exact,out.guid=true,true,before
    out.hotStreak,out.flashFreeze=hot,freeze
    return out
end
