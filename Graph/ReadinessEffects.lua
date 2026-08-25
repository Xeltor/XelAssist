-- Chosen-action cooldown and actor-readiness projection. Keeping this clock
-- separate prevents ActionEffects from owning both mechanics and scheduling.
XelAssist.Graph.ReadinessEffects = {}
local R = XelAssist.Graph.ReadinessEffects

local function projectAction(out, action, readyAt)
    local ledger = XelAssist.Graph.CooldownLedger
    if ledger and ledger:IsPrepared(out) and ledger:Supports(action) then
        return ledger:Project(out, action, readyAt)
    end
    out.readyAt[(action.actor or "player") .. ":" .. action.name] = readyAt
end

local function projectGroup(out, group, readyAt)
    local ledger = XelAssist.Graph.CooldownLedger
    if ledger and ledger:IsPrepared(out) then
        return ledger:ProjectGroup(out, group, readyAt)
    end
    out.readyAt["group:" .. group] = readyAt
end

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
    if (action.actor or "player") == "player" and candidate.normalGcd then
        out.playerGcdReadyAt = math.max(tonumber(out.playerGcdReadyAt) or 0,
            actionStart + math.max(0, tonumber(candidate.gcd) or 0))
    end
    if candidate.tooltip.cooldown and candidate.tooltip.cooldown > 0 then
        projectAction(out, action,
            applicationAt + candidate.tooltip.cooldown)
    end
    if facts.reactive then
        projectAction(out, action, applicationAt + 60)
    end
    if facts.nextInstant then out.instantNext = true
    elseif facts.kind ~= "modifier" and out.instantNext then
        out.instantNext = false
    end
    local group = facts.cooldownGroup or candidate.tooltip.cooldownGroup
    local category = candidate.tooltip.categoryCooldown
    if group and category and category > 0 then
        projectGroup(out, group, applicationAt + category)
    end
    if XelAssist.Graph.CompanionEvents then
        XelAssist.Graph.CompanionEvents:SyncChosenCooldown(
            out, candidate, context)
    end
end
