-- Exact local-player Warrior stance and Defiance threat evidence. This module
-- reports one bounded multiplier component only; it does not score actions,
-- mutate graph state, model companions, or claim to include unrelated buffs.
XelAssist.Game.Player.Threat = {}
local T = XelAssist.Game.Player.Threat

local BATTLE_FORM_ID = 17
local DEFENSIVE_FORM_ID = 18
local BERSERKER_FORM_ID = 19
local DEFIANCE_TAB = 3
local DEFIANCE_INDEX = 9
local DEFIANCE_TALENT_ID = 144
local DEFIANCE_MAX_RANK = 5
local LOWEST_MULTIPLIER = 0.80
local DEFENSIVE_BASE = 1.30
local DEFENSIVE_PER_RANK = 0.03

local function integer(value, low, high)
    if type(value) ~= "number" or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function playerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or type(class) ~= "string" then return nil end
    return class
end

local FORMS = {
    [BATTLE_FORM_ID] = { name = "battle", multiplier = LOWEST_MULTIPLIER,
        stanceSpellID = 2457, passiveSpellID = 21156 },
    [DEFENSIVE_FORM_ID] = { name = "defensive",
        stanceSpellID = 71, passiveSpellID = 7376 },
    [BERSERKER_FORM_ID] = { name = "berserker", multiplier = LOWEST_MULTIPLIER,
        stanceSpellID = 2458, passiveSpellID = 7381 },
}

local DEFIANCE_SPELL_IDS = {
    [1] = 12303, [2] = 12788, [3] = 12789, [4] = 12791, [5] = 12792,
}

local STOCK_FORMS = {
    [1] = BATTLE_FORM_ID,
    [2] = DEFENSIVE_FORM_ID,
    [3] = BERSERKER_FORM_ID,
}

local function stance()
    if type(GetShapeshiftFormID) == "function" then
        local ok, value = pcall(GetShapeshiftFormID)
        value = ok and integer(value, BATTLE_FORM_ID, BERSERKER_FORM_ID) or nil
        if value and FORMS[value] then
            return value, "ClassicAPI SpellShapeshiftForm ID"
        end
    end
    if type(GetShapeshiftForm) == "function" then
        local ok, value = pcall(GetShapeshiftForm)
        value = ok and integer(value, 1, 3) or nil
        if value and STOCK_FORMS[value] then
            return STOCK_FORMS[value], "stock Warrior stance index"
        end
    end
    return nil, "live Warrior stance unavailable"
end

local function defianceRank()
    if type(GetTalentInfo) ~= "function" then
        return nil, "Defiance rank unavailable"
    end
    local ok, _, _, _, _, rank = pcall(
        GetTalentInfo, DEFIANCE_TAB, DEFIANCE_INDEX)
    rank = ok and integer(rank, 0, DEFIANCE_MAX_RANK) or nil
    if rank == nil then return nil, "Defiance rank unavailable" end
    return rank, "stock GetTalentInfo(3,9)"
end

local function defensiveMultiplier(rank)
    return DEFENSIVE_BASE * (1 + DEFENSIVE_PER_RANK * rank)
end

local function profile(formID, formSource, rank, rankSource)
    local form = formID and FORMS[formID] or nil
    local minimum, maximum, multiplier, exact
    if form and form.multiplier then
        minimum, maximum = form.multiplier, form.multiplier
        multiplier, exact = form.multiplier, true
    elseif form and form.name == "defensive" then
        minimum = DEFENSIVE_BASE
        maximum = defensiveMultiplier(DEFIANCE_MAX_RANK)
        if rank ~= nil then
            multiplier = defensiveMultiplier(rank)
            minimum, maximum, exact = multiplier, multiplier, true
        else exact = false end
    else
        minimum = LOWEST_MULTIPLIER
        maximum = defensiveMultiplier(rank or DEFIANCE_MAX_RANK)
        exact = false
    end
    local source = "installed-client Warrior stance/Defiance profile; "
        .. formSource
    if form and form.name == "defensive" or not form then
        source = source .. "; " .. rankSource
    end
    return {
        actor = "player", playerOnly = true,
        component = "warriorStanceDefiance",
        formID = formID, stance = form and form.name or nil,
        stanceSpellID = form and form.stanceSpellID or nil,
        stancePassiveSpellID = form and form.passiveSpellID or nil,
        defianceTalentID = DEFIANCE_TALENT_ID,
        defianceRank = rank, defianceSpellID = rank and DEFIANCE_SPELL_IDS[rank] or nil,
        multiplier = multiplier, minimum = minimum, maximum = maximum,
        exact = exact, source = source,
        stanceSource = formSource, defianceSource = rankSource,
    }
end

function T:Snapshot()
    if playerClass() ~= "WARRIOR" then return nil end
    local formID, formSource = stance()
    local form = formID and FORMS[formID] or nil
    local rank, rankSource
    if not form or form.name == "defensive" then
        rank, rankSource = defianceRank()
    else rankSource = "Defiance inactive outside Defensive Stance" end
    return profile(formID, formSource, rank, rankSource)
end
