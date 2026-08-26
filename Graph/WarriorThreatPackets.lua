-- Composition boundary for exact Warrior threat profiles. Individual leaves
-- own their DBC/server evidence; generic threat, stance, and swing modules use
-- one dispatcher and never grow spell-specific branches.
XelAssist.Graph.WarriorThreatPackets = {}
local W = XelAssist.Graph.WarriorThreatPackets
local Revenge = XelAssist.Graph.WarriorRevengeThreat
local Heroic = XelAssist.Graph.WarriorHeroicStrikeThreat
local PROFILES = { Revenge, Heroic }

function W:Blocker(action, state, descriptor)
    local index
    for index = 1, table.getn(PROFILES) do
        local profile = PROFILES[index]
        if profile then
            local reason, handled = profile:Blocker(
                action, state, descriptor)
            if handled then return reason, true end
        end
    end
    return nil, false
end

function W:Augment(context, threat, valueThreat)
    local index
    for index = 1, table.getn(PROFILES) do
        local profile = PROFILES[index]
        if profile then
            local left, right, handled, reason = profile:Augment(
                context, threat, valueThreat)
            if handled then return left, right, true, reason end
        end
    end
    return threat, valueThreat, false, nil
end

function W:AppliedThreat(context, candidate, appliedDamage)
    local index
    for index = 1, table.getn(PROFILES) do
        local profile = PROFILES[index]
        if profile then
            local amount, exact, handled, reason = profile:AppliedThreat(
                context, candidate, appliedDamage)
            if handled then return amount, exact, true, reason end
        end
    end
    return nil, nil, false, nil
end

function W:Exactness(context, current)
    local index
    for index = 1, table.getn(PROFILES) do
        local profile = PROFILES[index]
        if profile and profile:Is(context and context.action) then
            return profile:Exactness(context, current)
        end
    end
    return current
end

-- PlayerSwings resolves queued replacements outside ActionEffects. Reuse the
-- same compound packet here so future search attributes rank-flat threat once
-- at the actual main-hand event rather than at button-press time.
function W:SwingThreat(action, appliedDamage, delivery)
    return self:AppliedThreat(
        { action = action, effectDelivery = delivery },
        { effectDelivery = delivery }, appliedDamage)
end
