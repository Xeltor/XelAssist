XelAssistGraph = {}
local G = XelAssistGraph

local MAX_STATES = 40
local MAX_MS = 2
local WIDTH = 4
local DEPTH = 3

local function pct(unit)
    local max = UnitHealthMax(unit) or 0
    if max <= 0 then return 100 end
    return (UnitHealth(unit) or 0) * 100 / max
end

local function addTalentState(s)
    s.talents = {}
    local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
    local tab
    for tab = 1, tabs do
        local count = GetNumTalents(tab) or 0
        local i
        for i = 1, count do
            local name, _, _, _, rank = GetTalentInfo(tab, i)
            if name then s.talents[name] = rank or 0 end
        end
    end
end

local function bestFriendly()
    if UnitExists("mouseover") and UnitCanAssist("player", "mouseover") and not UnitIsDead("mouseover") then
        return "mouseover", pct("mouseover")
    end
    if UnitExists("target") and UnitCanAssist("player", "target") and not UnitIsDead("target") then
        return "target", pct("target")
    end
    local best, hp = "player", pct("player")
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    local i
    if raid > 0 then
        for i = 1, raid do
            local unit = "raid" .. i
            local p = pct(unit)
            if UnitExists(unit) and not UnitIsDead(unit) and p < hp then best = unit; hp = p end
        end
    else
        for i = 1, party do
            local unit = "party" .. i
            local p = pct(unit)
            if UnitExists(unit) and not UnitIsDead(unit) and p < hp then best = unit; hp = p end
        end
    end
    return best, hp
end

function G:Snapshot(mode)
    local _, class = UnitClass("player")
    local healUnit, healHP = bestFriendly()
    local s = {
        class = class, mode = mode, mana = UnitMana("player") or 0,
        manaMax = UnitManaMax("player") or 0, health = pct("player"),
        combo = GetComboPoints and GetComboPoints() or 0,
        hostile = UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target"),
        healUnit = healUnit, healHP = healHP, moving = PlayerIsMoving and PlayerIsMoving() or false,
        pet = UnitExists("pet") and not UnitIsDead("pet"), form = GetShapeshiftForm and GetShapeshiftForm() or 0,
        equippedWand = GetInventoryItemLink("player", 18) and true or false,
        targetCasting = XelAssist and XelAssist.targetCastUntil and XelAssist.targetCastUntil > GetTime(),
        playerCasting = XelAssist and XelAssist.playerCastUntil and XelAssist.playerCastUntil > GetTime(),
        castRemaining = XelAssist and XelAssist.playerCastUntil and math.max(0, XelAssist.playerCastUntil - GetTime()) or 0,
        selectedFriendly = UnitExists("target") and UnitCanAssist("player", "target") and not UnitIsDead("target"),
        buffUnit = UnitExists("target") and UnitCanAssist("player", "target") and not UnitIsDead("target") and "target" or "player",
    }
    addTalentState(s)
    return s
end

local function legal(a, s, toggles)
    if not XelAssistCapabilities:KnowsSpell(a[1]) then return false end
    if a.minCombo and s.combo < a.minCombo then return false end
    if a.pet and not s.pet then return false end
    if a.reagent and not toggles.reagents then return false end
    if a.consumable and not toggles.consumables then return false end
    if a.cooldown and not toggles.cooldowns then return false end
    if a[1] == "Shoot" and not s.equippedWand then return false end
    if a.selfOnly and s.buffUnit ~= "player" then return false end
    if a.manaOnly and UnitPowerType(s.buffUnit) ~= 0 then return false end
    if a.nonMana and UnitPowerType(s.buffUnit) == 0 then return false end
    if a[3] == "filler" and s.moving then return false end
    if a[3] == "interrupt" and not s.targetCasting then return false end
    if a[3] == "reactive" then return false end
    if a[3] == "execute" and XelAssistCapabilities:TargetHealthPercent() > 20 then return false end
    if a[3] == "debuff" and XelAssistCapabilities:TargetHasDebuff(a[1]) then return false end
    if a[3] == "buff" and XelAssistCapabilities:UnitHasBuff(s.buffUnit, a[1]) then return false end
    if (a[3] == "triage" or a[3] == "efficient triage" or a[3] == "group triage") and s.healHP >= 90 then return false end
    if a[3] == "emergency triage" and s.healHP >= 55 then return false end
    if a[3] == "maintenance" and s.healHP >= 95 then return false end
    if a[3] == "emergency" and s.health >= 35 then return false end
    return XelAssistCapabilities:IsReady(a[1], s.castRemaining) and XelAssistCapabilities:CanAfford(a[1])
end

local function score(a, s, depth, prior)
    local v = a[2]
    if a[3] == "triage" or a[3] == "emergency triage" then v = v + (100 - s.healHP) * 8 end
    if a[3] == "emergency" then v = v + (100 - s.health) * 9 end
    if a[3] == "resource recovery" and s.manaMax > 0 then v = v + (1 - s.mana / s.manaMax) * 500 end
    if prior and prior == a[1] then v = v - 250 end
    return v / depth
end

local function copyTop(actions, s, toggles)
    local out = {}
    local i
    for i = 1, table.getn(actions) do
        local a = actions[i]
        if legal(a, s, toggles) then table.insert(out, a) end
    end
    table.sort(out, function(a, b) return a[2] > b[2] end)
    while table.getn(out) > WIDTH do table.remove(out) end
    return out
end

function G:Evaluate(mode, preview)
    local started = GetTime()
    local s = self:Snapshot(mode)
    local profile = XelAssistProfiles[s.class]
    if not profile then return nil, "missing class profile", true end
    local key = mode
    if key == "support" then key = "heal" end
    if key == "smart" then
        if s.selectedFriendly and profile.buff then key = "buff"
        elseif s.targetCasting and profile.interrupt then key = "interrupt"
        elseif s.health < 35 and profile.defensive then key = "defensive"
        elseif s.healHP < 45 and profile.heal then key = "heal"
        else key = "damage" end
    end
    if key == "single" then key = "damage" end
    local actions = profile[key]
    if not actions then actions = profile.damage end
    if (key == "damage" or key == "aoe" or key == "interrupt") and not s.hostile then
        return nil, "select a hostile target", false
    end
    if not actions then return nil, "profile has no branch", true end
    local toggles = XelAssistCharDB.toggles
    local frontier = copyTop(actions, s, toggles)
    local paths = {}
    local expanded = 0
    local depth
    for depth = 1, DEPTH do
        local nextPaths = {}
        local i
        for i = 1, table.getn(frontier) do
            if expanded >= MAX_STATES or (GetTime() - started) * 1000 > MAX_MS then
                return nil, "graph budget exceeded", true
            end
            local a = frontier[i]
            expanded = expanded + 1
            local prior = paths[i] and paths[i].last or nil
            nextPaths[i] = { action = paths[i] and paths[i].action or a,
                value = (paths[i] and paths[i].value or 0) + score(a, s, depth, prior), last = a[1] }
        end
        paths = nextPaths
    end
    table.sort(paths, function(a, b) return a.value > b.value end)
    local best = paths[1]
    if not best then return nil, "no legal graph action", true end
    local follow = {}
    local i
    for i = 1, table.getn(frontier) do
        if frontier[i][1] ~= best.action[1] and table.getn(follow) < 2 then table.insert(follow, frontier[i]) end
    end
    local actionTarget
    if key == "heal" then actionTarget = s.healUnit
    elseif key == "buff" then actionTarget = best.action.selfOnly and "player" or s.buffUnit end
    return { action = best.action, follow = follow, reason = best.action[3], target = actionTarget,
        confidence = profile.confidence, expanded = expanded, elapsed = (GetTime() - started) * 1000 }, nil, false
end
