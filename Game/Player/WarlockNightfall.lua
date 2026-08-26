-- Exact build-5875 Nightfall ownership, Shadow Trance aura and Shadow Bolt
-- consumer identity. Proc generation is intentionally not projected: only a
-- numeric aura already observed at the root can create the one-use contract.
XelAssist.Game.Player.WarlockNightfall = {}
local N = XelAssist.Game.Player.WarlockNightfall

N.PASSIVES = { [18094] = 2, [18095] = 4 }
N.AURA_ID = 17941
N.BOLTS = { [686]=true,[695]=true,[705]=true,[1088]=true,[1106]=true,
    [7641]=true,[11659]=true,[11660]=true,[11661]=true,[25307]=true }
N.MAX_AURAS = 48

local function finite(v, low, high)
    v=tonumber(v); return v and v==v and v~=math.huge and v~=-math.huge
        and v>=low and v<=high and v or nil
end
local function integer(v, low, high)
    v=finite(v,low,high); return v and math.floor(v)==v and v or nil
end
local function scalar(id, field)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,field); return ok and tonumber(v) or nil
end
local function triple(id, field)
    if type(GetSpellRecField)~="function" then return nil end
    local ok,v=pcall(GetSpellRecField,id,field,1)
    if not ok or type(v)~="table" or table.getn(v)~=3 then return nil end
    return v
end
local function eq(v,a,b,c) return v and v[1]==a and v[2]==b and v[3]==c end
local function classToken()
    if type(UnitClass)~="function" then return nil end
    local ok,_,token=pcall(UnitClass,"player"); return ok and token or nil
end
local function identity()
    if type(UnitGUID)~="function" then return nil end
    local ok,guid=pcall(UnitGUID,"player"); return ok and guid or nil
end

local function passiveExact(id, chance)
    return scalar(id,"school")==0 and scalar(id,"attributes")==464
        and scalar(id,"procFlags")==262144 and scalar(id,"procChance")==chance
        and scalar(id,"procCharges")==0 and scalar(id,"durationIndex")==21
        and scalar(id,"spellFamilyName")==5
        and eq(triple(id,"effect"),6,0,0)
        and eq(triple(id,"effectApplyAuraName"),42,0,0)
        and eq(triple(id,"effectItemType"),16410,0,0)
        and eq(triple(id,"effectTriggerSpell"),N.AURA_ID,0,0)
end

local function auraExact()
    return scalar(N.AURA_ID,"school")==5 and scalar(N.AURA_ID,"attributes")==65536
        and scalar(N.AURA_ID,"durationIndex")==1
        and scalar(N.AURA_ID,"spellFamilyName")==5
        and scalar(N.AURA_ID,"spellFamilyFlags")==0
        and eq(triple(N.AURA_ID,"effect"),6,64,0)
        and eq(triple(N.AURA_ID,"effectBasePoints"),4294967195,0,0)
        and eq(triple(N.AURA_ID,"effectImplicitTargetA"),1,1,0)
        and eq(triple(N.AURA_ID,"effectApplyAuraName"),108,0,0)
        and eq(triple(N.AURA_ID,"effectMiscValue"),10,0,0)
        and eq(triple(N.AURA_ID,"effectItemType"),1,0,0)
        and eq(triple(N.AURA_ID,"effectTriggerSpell"),0,17964,0)
        and scalar(17964,"school")==5 and scalar(17964,"spellFamilyName")==5
        and eq(triple(17964,"effect"),6,0,0)
        and eq(triple(17964,"effectBasePoints"),99,0,0)
        and eq(triple(17964,"effectApplyAuraName"),107,0,0)
        and eq(triple(17964,"effectItemType"),16,0,0)
end

function N:CaptureFacts(action, facts)
    if not (action and self.BOLTS[action.spellId]) then return facts end
    local out,k,v={},nil,nil; for k,v in pairs(facts or {}) do out[k]=v end
    local exact=scalar(action.spellId,"school")==5
        and scalar(action.spellId,"spellFamilyName")==5
        and scalar(action.spellId,"spellFamilyFlags")==1
        and scalar(action.spellId,"castTime") and scalar(action.spellId,"castTime")>0
        and eq(triple(action.spellId,"effect"),2,0,0)
        and eq(triple(action.spellId,"effectImplicitTargetA"),6,0,0)
    out.warlockNightfallConsumer=true
    out.warlockNightfallConsumerExact=exact and true or false
    if not exact then out.warlockNightfallReason="Shadow Bolt topology is incomplete" end
    return out
end

function N:Snapshot(token)
    local out={ available=false, exact=false, active=false,
        source="numeric Nightfall ownership and Shadow Trance aura" }
    if token~="WARLOCK" or classToken()~="WARLOCK" or type(IsPlayerSpell)~="function"
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras)=="function")
        or type(GetTime)~="function" then
        out.reason="Nightfall root evidence unavailable"; return out
    end
    local learned, learnedId, chance=false,nil,nil
    for id,value in pairs(self.PASSIVES) do
        local ok,has=pcall(IsPlayerSpell,id)
        if not ok or type(has)~="boolean" then
            out.reason="Nightfall ownership unavailable"; return out
        end
        if has then
            if learned then out.reason="multiple Nightfall ranks learned"; return out end
            learned,learnedId,chance=true,id,value
        end
    end
    if learned and not passiveExact(learnedId,chance) then
        out.reason="Nightfall passive topology is incomplete"; return out
    end
    local before=identity(); local ok,list=pcall(C_UnitAuras.GetUnitAuras,"player","HELPFUL")
    local clockOK,now=pcall(GetTime)
    if not before or not ok or type(list)~="table" or table.getn(list)>self.MAX_AURAS
        or identity()~=before or not clockOK then
        out.reason="Shadow Trance aura evidence unavailable"; return out
    end
    local active
    for i=1,table.getn(list) do
        local aura=list[i]; local id=type(aura)=="table" and integer(aura.spellId,1,4294967295)
        if not id then out.reason="numeric self aura evidence unavailable"; return out end
        if id==self.AURA_ID then
            if active or not learned or not auraExact() then
                out.reason="Shadow Trance ownership or topology is incoherent"; return out
            end
            local duration=finite(aura.duration,0.001,3600)
            local expiration=finite(aura.expirationTime,now,now+3600)
            if aura.isHelpful~=true or not duration or not expiration
                or expiration-now>duration+0.001 then
                out.reason="Shadow Trance lifetime evidence unavailable"; return out
            end
            active={ spellId=id, expiresAt=expiration-now, remaining=expiration-now }
        end
    end
    out.available,out.exact,out.learned,out.active=true,true,learned,active~=nil
    out.learnedSpellId,out.procChance,out.guid=learnedId,chance,before
    out.expiresAt=active and active.expiresAt or nil
    out.remaining=active and active.remaining or nil
    out.charges=active and 1 or 0
    return out
end
