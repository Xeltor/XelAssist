-- Exact player engagement semantics shared by the observed state, graph and
-- execution boundary. No ability-name list lives here: Spell.dbc decides which
-- hostile melee actions initiate sustained Attack.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.Engagement = {}
local E = XelAssist.Game.Player.Engagement

local function numericBoolean(value)
    if value == true or tonumber(value) == 1 then return true end
    if value == false or tonumber(value) == 0 then return false end
    return nil
end

local function flagSet(value, flag)
    value = math.max(0, tonumber(value) or 0)
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function auraStealth()
    if not (GetPlayerBuff and GetPlayerBuffID and GetSpellRecField) then
        return nil, false, "stealth state unavailable"
    end
    local index
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil, false, "player aura scan failed" end
        if slot and slot ~= -1 then
            local idOK, spellId = pcall(GetPlayerBuffID, slot)
            if not idOK or type(spellId) ~= "number" then
                return nil, false, "player aura identity unavailable"
            end
            if spellId < -1 then spellId = spellId + 65536 end
            local effectsOK, effects = pcall(
                GetSpellRecField, spellId, "effect", 1)
            local aurasOK, auras = pcall(
                GetSpellRecField, spellId, "effectApplyAuraName", 1)
            if not effectsOK or type(effects) ~= "table"
                or not aurasOK or type(auras) ~= "table" then
                return nil, false, "player aura DBC unavailable"
            end
            local effect
            for effect = 1, table.getn(auras) do
                if tonumber(effects[effect]) == 6
                    and tonumber(auras[effect]) == 16 then
                    return true, true, "player stealth aura DBC"
                end
            end
        end
    end
    return false, true, "player aura DBC"
end

function E:StealthState()
    if type(IsStealthed) == "function" then
        local ok, value = pcall(IsStealthed)
        value = ok and numericBoolean(value) or nil
        if value ~= nil then
            return value, true, "ClassicAPI player stealth flag"
        end
    end
    if type(GetUnitField) == "function" then
        local ok, bytes = pcall(GetUnitField, "player", "bytes1")
        if ok and type(bytes) == "number" then
            return flagSet(bytes, 33554432), true,
                "Nampower player stealth flag"
        end
    end
    return auraStealth()
end

function E:HostilePlayerAction(action, relation)
    local facts = action and action.facts or {}
    if relation ~= "hostile" or action and action.actor == "pet"
        or action and action.executor == "item"
        or facts.playerAttack or facts.autoRepeat
        or facts.effectActor == "pet" or facts.damageActor == "pet" then
        return false
    end
    return true
end

function E:AttackTransition(action, tooltip, relation)
    if not self:HostilePlayerAction(action, relation) then return nil end
    local facts = action and action.facts or {}
    tooltip = tooltip or {}
    if facts.stopsPlayerAttack == true
        or tooltip.stopsPlayerAttack == true then return "stop" end
    if facts.initiatesCombat == true
        or tooltip.initiatesCombat == true then return "start" end
    return nil
end

function E:Starts(action, tooltip, relation)
    return self:AttackTransition(action, tooltip, relation) == "start"
end

function E:PreservesStealth(action, tooltip)
    local facts = action and action.facts or {}
    tooltip = tooltip or {}
    return facts.preservesStealth == true or tooltip.preservesStealth == true
end

function E:Submitted(action, tooltip, relation, targetGuid, delay)
    local attack = XelAssist.Game.PlayerAttack
    if not attack then return false end
    local transition = self:AttackTransition(action, tooltip, relation)
    if transition == "stop" then
        if attack.Stopped then attack:Stopped() end
        return true
    end
    if transition ~= "start" or not attack.Submitted then return false end
    return attack:Submitted(targetGuid,
        math.max(0, tonumber(delay) or 0) + 0.75,
        "hostile action initiated Attack")
end
