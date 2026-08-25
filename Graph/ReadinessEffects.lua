-- Chosen-action cooldown and actor-readiness projection. Keeping this clock
-- separate prevents ActionEffects from owning both mechanics and scheduling.
XelAssist.Graph.ReadinessEffects = {}
local R = XelAssist.Graph.ReadinessEffects

function R:Apply(out, candidate, context)
    local action, facts = context.action, context.facts
    local actionStart = tonumber(candidate.actionStart)
        or (tonumber(out.time) or 0) - (tonumber(candidate.downtime) or 0)
            + (tonumber(candidate.wait) or 0)
    local applicationAt = actionStart + math.max(0, tonumber(candidate.cast) or 0)
    if not facts.autoRepeat then
        local actor = action.actor or "player"
        out.actorReadyAt[actor] = math.max(
            tonumber(out.actorReadyAt[actor]) or 0, tonumber(out.time) or 0)
    end
    if candidate.tooltip.cooldown and candidate.tooltip.cooldown > 0 then
        out.readyAt[(action.actor or "player") .. ":" .. action.name]
            = applicationAt + candidate.tooltip.cooldown
    end
    if facts.reactive then
        out.readyAt[(action.actor or "player") .. ":" .. action.name]
            = applicationAt + 60
    end
    if facts.nextInstant then out.instantNext = true
    elseif facts.kind ~= "modifier" and out.instantNext then
        out.instantNext = false
    end
    local group = facts.cooldownGroup or candidate.tooltip.cooldownGroup
    local category = candidate.tooltip.categoryCooldown
    if group and category and category > 0 then
        out.readyAt["group:" .. group] = applicationAt + category
    end
    if XelAssist.Graph.CompanionEvents then
        XelAssist.Graph.CompanionEvents:SyncChosenCooldown(
            out, candidate, context)
    end
end
