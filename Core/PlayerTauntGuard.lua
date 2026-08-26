-- Fail-closed live boundary for player Taunt. The graph may explain why a
-- Taunt is useful, but publication and dispatch must still prove that the
-- selected enemy is attacking the player's current companion or group member.
XelAssist.Core = XelAssist.Core or {}
XelAssist.Core.PlayerTauntGuard = {}
local W = XelAssist.Core.PlayerTauntGuard

local function unitGuid(unit)
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists or exists == 0 or guid == nil or guid == ""
        or guid == "0x000000000"
        or guid == "0x0000000000000000" then return nil end
    return guid
end

local function selectedHostile(plan)
    local guard = XelAssist.Core and XelAssist.Core.TargetGuard
    if not (guard and type(guard.ValidateSelectedHostile) == "function") then
        return nil, "selected hostile validation unavailable"
    end
    local ref = plan.castTargetRef or plan.targetRef
    local ok, guid, reason, hostile = pcall(
        guard.ValidateSelectedHostile, guard, plan, "target", ref)
    if not ok then return nil, "selected hostile validation unavailable" end
    if hostile ~= true or guid == nil then
        return nil, reason or "selected hostile unavailable"
    end
    return guid, nil
end

local function exactCall(owner, method, first, second)
    if type(owner) ~= "table" or type(owner[method]) ~= "function" then
        return nil, false
    end
    local ok, value = pcall(owner[method], owner, first, second)
    if not ok then return nil, false end
    return value, true
end

local function count(api, maximum)
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api)
    value = ok and tonumber(value) or nil
    if value == nil then return nil end
    value = math.floor(value)
    if value < 0 then value = 0 end
    if value > maximum then value = maximum end
    return value
end

local function victimOwner(victimGuid)
    local playerGuid = unitGuid("player")
    if playerGuid == nil then return nil, "player identity unavailable" end
    if victimGuid == playerGuid then return nil, "target already attacks player" end

    local petGuid = unitGuid("pet")
    if petGuid ~= nil and victimGuid == petGuid then return "pet", nil end

    local raid = count(GetNumRaidMembers, 40)
    if raid == nil then return nil, "group roster unavailable" end
    local prefix, members
    if raid > 0 then
        prefix, members = "raid", raid
    else
        members = count(GetNumPartyMembers, 4)
        if members == nil then return nil, "group roster unavailable" end
        prefix = "party"
    end
    local i
    for i = 1, members do
        local unit = prefix .. tostring(i)
        if unitGuid(unit) == victimGuid then return unit, nil end
    end
    return nil, "target victim is outside your group"
end

local function defensiveStance()
    if type(GetShapeshiftForm) ~= "function" then return nil end
    local ok, value = pcall(GetShapeshiftForm)
    if not ok then return nil end
    return value == 2
end

local function exactTauntKind(action)
    local facts = action and action.facts or {}
    if tonumber(action and action.spellId) == 355
        and facts.warriorTaunt == true then return "warrior" end
    local player = XelAssist.Game and XelAssist.Game.Player or {}
    if player.PaladinHandOfReckoning
        and player.PaladinHandOfReckoning:Evidence(action) then
        return "paladin"
    end
    if player.DruidGrowl and player.DruidGrowl:Evidence(action) then
        return "druid"
    end
    return nil
end

function W:Validate(plan)
    local action = type(plan) == "table" and plan.action or nil
    local facts = type(action) == "table" and action.facts or nil
    if type(facts) ~= "table" or not facts.playerTaunt then return true, nil end
    local tauntKind = exactTauntKind(action)
    if not tauntKind then return false, "Taunt identity unavailable" end
    if (tonumber(plan.wait) or 0) > 0 then return false, "Taunt must be ready now" end

    local targetGuid, reason = selectedHostile(plan)
    if targetGuid == nil then return false, reason end
    if tauntKind == "warrior" and defensiveStance() ~= true then
        return false, "Defensive Stance required"
    end

    local capabilities = XelAssist.Game and XelAssist.Game.Capabilities
    local usable, known = exactCall(capabilities, "Usable", action)
    if not known or usable ~= true then return false, "Taunt unavailable" end
    local ready
    ready, known = exactCall(capabilities, "IsReady", action.name, 0)
    if not known or ready ~= true then return false, "Taunt on cooldown" end

    local victimGuid = unitGuid("targettarget")
    if victimGuid == nil then return false, "target victim unavailable" end
    local victimUnit
    victimUnit, reason = victimOwner(victimGuid)
    if victimUnit == nil then return false, reason end

    local castName = action.name
    if capabilities and type(capabilities.CastName) == "function" then
        castName, known = exactCall(capabilities, "CastName", action)
        if not known or castName == nil then
            return false, "Taunt range unavailable"
        end
    end
    local inRange
    inRange, known = exactCall(capabilities, "InRange", castName, "target")
    if not known or inRange ~= true then return false, "Taunt range required" end

    local finalTarget
    finalTarget, reason = selectedHostile(plan)
    if finalTarget == nil or finalTarget ~= targetGuid then
        return false, reason or "selected hostile changed"
    end
    if unitGuid("targettarget") ~= victimGuid then
        return false, "target victim changed"
    end
    if unitGuid(victimUnit) ~= victimGuid then
        return false, "target victim group identity changed"
    end
    return true, nil
end
