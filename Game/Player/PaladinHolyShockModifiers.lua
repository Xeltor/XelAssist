-- Observed-only ownership for Octo's one-use Holy Shock timing modifiers.
-- Their proc generation is intentionally not forecast by the graph.
XelAssist.Game.Player.PaladinHolyShockModifiers = {}
local H = XelAssist.Game.Player.PaladinHolyShockModifiers

H.CONSUMERS = { [20473]=true, [20929]=true, [20930]=true, [51786]=true }
H.MODIFIERS = { [51865]="gcd", [52661]="cooldown" }
H.MAX_AURAS = 48

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and tonumber(value) or nil
end
local function triple(id, field, a, b, c)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    return ok and type(values) == "table" and values[4] == nil
        and tonumber(values[1]) == a and tonumber(values[2]) == b
        and tonumber(values[3]) == c
end
local function finite(value, low, high)
    value = tonumber(value)
    return value and value == value and value >= low and value <= high
        and value or nil
end
local function token()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, value = pcall(UnitClass, "player")
    return ok and value or nil
end
local function guid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, value = pcall(UnitGUID, "player")
    return ok and value or nil
end

local function consumerExact(id)
    return H.CONSUMERS[id] and scalar(id,"school") == 1
        and scalar(id,"attributes") == 327680
        and scalar(id,"spellFamilyName") == 10
        and scalar(id,"spellFamilyFlags") == 2097152
        and scalar(id,"categoryRecoveryTime") == 20000
        and scalar(id,"startRecoveryCategory") == 133
        and scalar(id,"startRecoveryTime") == 1500
        and triple(id,"effect",3,0,0)
end
local function modifierExact(id, kind)
    local gcd = kind == "gcd"
    return scalar(id,"school") == 0 and scalar(id,"spellFamilyName") == 10
        and scalar(id,"durationIndex") == 21
        and scalar(id,"procChance") == 100 and scalar(id,"procCharges") == 1
        and scalar(id,"procFlags") == (gcd and 16384 or 87056)
        and scalar(id,"attributes") == (gcd and 128 or 192)
        and scalar(id,"attributesEx") == (gcd and 2048 or 0)
        and triple(id,"effect",6,0,0)
        and triple(id,"effectBasePoints",gcd and -501 or -101,0,0)
        and triple(id,"effectApplyAuraName",gcd and 107 or 108,0,0)
        and triple(id,"effectItemType",2097152,0,0)
        and triple(id,"effectMiscValue",gcd and 21 or 11,0,0)
end

function H:CaptureFacts(action, facts, state)
    if not (action and self.CONSUMERS[tonumber(action.spellId)]) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.holyShockModifierConsumer = true
    out.holyShockModifierConsumerExact = consumerExact(tonumber(action.spellId))
    local root = state and state.paladinHolyShockModifiers
    if out.holyShockModifierConsumerExact and root and root.available
        and root.exact and (root.gcd.active or root.cooldown.active) then
        local gcd = finite(out.gcd, 0, 10)
        local cooldown = finite(out.cooldown, 0, 3600)
        if gcd and cooldown then
            out.holyShockModifierContract = { exact=true,
                spellId=tonumber(action.spellId), gcd=gcd, cooldown=cooldown,
                gcdAura=root.gcd.active and root.gcd.auraSpellId or nil,
                cooldownAura=root.cooldown.active
                    and root.cooldown.auraSpellId or nil,
                source="engine-effective Holy Shock timing at root" }
        end
    end
    return out
end
function H:Snapshot(class)
    local out = { available=false, exact=false,
        source="numeric observed self aura and installed patch-5 topology" }
    if class ~= "PALADIN" or token() ~= "PALADIN"
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras)=="function") then
        out.reason="Holy Shock modifier aura evidence unavailable"; return out
    end
    local before = guid()
    local ok, list = pcall(C_UnitAuras.GetUnitAuras,"player","HELPFUL")
    if not before or not ok or type(list)~="table"
        or table.getn(list)>self.MAX_AURAS or guid()~=before then
        out.reason="Holy Shock modifier snapshot was incoherent"; return out
    end
    out.gcd={active=false}; out.cooldown={active=false}
    local index
    for index=1,table.getn(list) do
        local aura=list[index]
        local id=type(aura)=="table" and finite(aura.spellId,1,4294967295)
        if not id then out.reason="numeric self aura evidence unavailable"; return out end
        local kind=self.MODIFIERS[id]
        if kind then
            local slot=out[kind]
            if slot.active or aura.isHelpful~=true or not modifierExact(id,kind)
                or (aura.applications~=nil and aura.applications~=1) then
                out.reason="Holy Shock modifier ownership shifted"; return out
            end
            slot.active,slot.auraSpellId,slot.consumed=true,id,false
        end
    end
    out.available,out.exact,out.guid=true,true,before
    return out
end
