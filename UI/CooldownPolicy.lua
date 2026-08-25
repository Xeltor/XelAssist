XelAssist.UI.CooldownPolicy = {}
local Policy = XelAssist.UI.CooldownPolicy

local function explanation(action)
    local facts = action.facts or {}
    if facts.petCombatBuff then return "Boosts your companion during combat." end
    if facts.nextInstant then return "Sets up an immediate follow-up cast." end
    if facts.emergency then return "Emergency healing action." end
    if facts.kind == "defensive" or facts.kind == "absorb" then
        return "Defensive survival action."
    elseif facts.kind == "heal" or facts.kind == "hot" then
        return "High-impact healing action."
    elseif facts.kind == "crowdControl" then
        return "Crowd-control action."
    elseif facts.kind == "interrupt" then
        return "Interrupt action."
    elseif facts.kind == "threatDrop" then
        return "Threat-control action."
    elseif facts.kind == "buff" or facts.kind == "modifier" then
        return "Temporary combat boost."
    elseif facts.kind == "damage" or facts.kind == "dot"
        or facts.kind == "builder" then
        return facts.aoe and "High-impact area action."
            or "High-impact damage action."
    end
    return "Optional action reserved behind this setting."
end

local function factsFor(action)
    if not (XelAssist.Game.Actors and XelAssist.Game.Actors.Facts) then return {} end
    local ok, facts = pcall(function()
        return XelAssist.Game.Actors:Facts(action)
    end)
    return ok and type(facts) == "table" and facts or {}
end

local function gated(action, tooltip)
    local facts = action and action.facts or {}
    return not facts.consumable and (facts.cooldown
        or (tonumber(tooltip and tooltip.cooldown) or 0) >= 30)
end

function Policy:LearnedActions()
    if not (XelAssist.Game.Actors and XelAssist.Game.Actors.Actions) then return {} end
    local ok, actions = pcall(function() return XelAssist.Game.Actors:Actions() end)
    if not ok or type(actions) ~= "table" then return {} end
    local byKey, i = {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        local tooltip = factsFor(action)
        if gated(action, tooltip) then
            local actor = action.actor == "pet" and "pet" or "player"
            local key = actor .. "\001" .. tostring(action.name or "")
            local prior = byKey[key]
            if not prior or (tonumber(action.rank) or 0) > (tonumber(prior.action.rank) or 0) then
                byKey[key] = { action = action, tooltip = tooltip }
            end
        end
    end
    local out, _, entry = {}, nil, nil
    for _, entry in pairs(byKey) do table.insert(out, entry) end
    table.sort(out, function(a, b)
        local aPet, bPet = a.action.actor == "pet", b.action.actor == "pet"
        if aPet ~= bPet then return not aPet end
        return tostring(a.action.name or "") < tostring(b.action.name or "")
    end)
    return out
end

function Policy:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Major cooldowns")
    local actions = self:LearnedActions()
    if table.getn(actions) == 0 then
        GameTooltip:AddLine("No currently learned graph-gated cooldown actions.",
            0.78, 0.80, 0.84)
        GameTooltip:AddLine("This option has no effect until one is learned.",
            0.55, 0.58, 0.64)
    else
        GameTooltip:AddLine("Allows the graph to recommend these learned actions:",
            0.72, 0.82, 1)
        local i
        for i = 1, table.getn(actions) do
            local entry, action = actions[i], actions[i].action
            local actor = action.actor == "pet" and "Companion · " or ""
            local cooldown = tonumber(entry.tooltip.cooldown) or 0
            local duration = cooldown >= 30 and " · "
                .. math.floor(cooldown + 0.5) .. "s cooldown" or ""
            GameTooltip:AddLine(actor .. tostring(action.name) .. duration,
                action.actor == "pet" and 0.72 or 0.90,
                action.actor == "pet" and 0.48 or 0.93,
                action.actor == "pet" and 0.92 or 0.96)
            GameTooltip:AddLine(explanation(action), 0.62, 0.65, 0.70)
        end
    end
    GameTooltip:Show()
end
