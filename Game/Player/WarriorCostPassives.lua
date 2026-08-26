-- Root-sealed engine costs for ordinary Warrior rage attacks affected by
-- permanent patch-5 cost passives. The graph receives the engine's charged
-- value only when ownership, passive topology, SpellMod and C_Spell agree.
XelAssist.Game.Player.WarriorCostPassives = {}
local P = XelAssist.Game.Player.WarriorCostPassives

P.COST_OPERATION = 14
P.RAGE = 1
local ACTION_GROUP = {
    [78]="heroic", [284]="heroic", [285]="heroic", [1608]="heroic",
    [11564]="heroic", [11565]="heroic", [11566]="heroic",
    [11567]="heroic", [25286]="heroic",
    [1680]="whirlwind",
    [23881]="strike", [23892]="strike", [23893]="strike", [23894]="strike",
    [12294]="strike", [21551]="strike", [21552]="strike", [21553]="strike",
}
local PASSIVES = {
    [12282]={ group="heroic", rank=1, flat=-10, attributes=262608 },
    [12663]={ group="heroic", rank=2, flat=-20, attributes=262608 },
    [12664]={ group="heroic", rank=3, flat=-30, attributes=262608 },
    [24431]={ group="whirlwind", rank=1, flat=-30, attributes=192 },
    [53200]={ group="strike", rank=1, flat=-100, attributes=192 },
}
local ORDER = {
    heroic={12664,12663,12282}, whirlwind={24431}, strike={53200},
}

local function number(value)
    value = tonumber(value)
    return value and value == value and value or nil
end
local function integer(value)
    value = number(value)
    return value and math.floor(value) == value and value or nil
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and number(value) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = number(values[index])
        if out[index] == nil then return nil end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function learned(id)
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, id)
    if not ok then return nil end
    return value == true or value == 1
end
local function passiveExact(id, profile)
    return scalar(id,"attributes") == profile.attributes
        and scalar(id,"spellFamilyName") == 4
        and scalar(id,"procFlags") == 0
        and equal(triple(id,"effect"),6,0,0)
        and equal(triple(id,"effectApplyAuraName"),107,0,0)
        and equal(triple(id,"effectBasePoints"),profile.flat-1,0,0)
        and equal(triple(id,"effectImplicitTargetB"),1,0,0)
        and equal(triple(id,"effectMiscValue"),P.COST_OPERATION,0,0)
end
local function ownership(group)
    local order, index = ORDER[group], nil
    if not order then return nil end
    for index = 1, table.getn(order) do
        local id, profile = order[index], PASSIVES[order[index]]
        local owned = learned(id)
        if owned == nil then return nil end
        if owned then
            if not passiveExact(id,profile) then return nil end
            return { learned=true, spellId=id, rank=profile.rank,
                flat=profile.flat }
        end
    end
    return { learned=false, rank=0, flat=0 }
end
local function modifiers(id)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers,id,P.COST_OPERATION)
    flat, percent, changed = number(flat), number(percent), number(changed)
    if not ok or not flat or not percent or not changed then return nil end
    local rawPercent = percent
    -- Nampower's build-5875 wrapper exposes the engine's neutral percentage
    -- accumulator as 100 when there is no flat modifier. With a flat cost
    -- passive it already subtracts that baseline and returns zero.
    if flat==0 and changed==0 and percent==100 then percent=0 end
    return { flat=flat, percent=percent, rawPercent=rawPercent,
        changed=changed }
end
local function effective(id)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost)=="function") then
        return nil
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost,id)
    if not ok or type(costs)~="table" or table.getn(costs)~=1
        or type(costs[1])~="table" then return nil end
    local row, cost = costs[1], number(costs[1].cost)
    if integer(row.type)~=P.RAGE or not cost or cost<0
        or number(row.minCost)~=cost or number(row.costPercent)~=0
        or number(row.costPerSec)~=0 or number(row.requiredAuraID)~=0
        or row.hasRequiredAura~=false then return nil end
    return cost
end

function P:CaptureFacts(action, facts)
    local out, id = copy(facts), integer(action and action.spellId)
    local group = id and ACTION_GROUP[id]
    if not group then return out end
    local owner, mod, charged = ownership(group), modifiers(id), effective(id)
    local base = scalar(id,"manaCost")
    if scalar(id,"spellFamilyName")~=4 or scalar(id,"powerType")~=self.RAGE
        or not base or base<=0 or not owner or not mod or not charged
        or mod.flat~=owner.flat or mod.percent~=0
        or owner.learned and mod.changed==0
        or not owner.learned and mod.changed~=0
        or charged~=base+owner.flat or charged<0 then
        out.warriorCostEvidence = { available=false, exact=false,
            group=group, reason="Warrior effective rage cost evidence unavailable" }
        return out
    end
    out.cost = charged/10
    out.warriorCostEvidence = { available=true, exact=true, group=group,
        actionSpellId=id, baseRaw=base, chargedRaw=charged,
        cost=out.cost, passiveLearned=owner.learned,
        passiveSpellId=owner.spellId, passiveRank=owner.rank,
        modifierFlat=mod.flat, modifierPercent=mod.percent,
        modifierRawPercent=mod.rawPercent,
        source="patch-5 ownership plus engine-effective rage cost" }
    return out
end

function P:Evidence(subject)
    local facts = type(subject)=="table" and subject.facts or subject
    local found = facts and facts.warriorCostEvidence
    local group = found and ACTION_GROUP[found.actionSpellId]
    if not (type(found)=="table" and found.available==true
        and found.exact==true and group==found.group
        and number(found.baseRaw) and number(found.chargedRaw)
        and found.baseRaw>0 and found.chargedRaw>=0
        and found.cost==found.chargedRaw/10
        and found.modifierPercent==0
        and found.chargedRaw==found.baseRaw+found.modifierFlat) then return nil end
    local profile = found.passiveSpellId and PASSIVES[found.passiveSpellId]
    if found.passiveLearned==true then
        if not (profile and profile.group==group
            and found.passiveRank==profile.rank
            and found.modifierFlat==profile.flat) then return nil end
    elseif not (found.passiveLearned==false and found.passiveSpellId==nil
        and found.passiveRank==0 and found.modifierFlat==0) then return nil end
    return copy(found)
end

function P:Is(action)
    return action and ACTION_GROUP[integer(action.spellId)]~=nil
end
