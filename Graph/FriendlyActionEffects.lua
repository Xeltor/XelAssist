-- Target-local friendly consequences. Exact class mechanics may replace a
-- generic entry, but action order and utility remain graph-derived.
XelAssist.Graph.FriendlyActionEffects = {}
local F = XelAssist.Graph.FriendlyActionEffects
local State = XelAssist.Graph.State
local HunterAspects = XelAssist.Graph.HunterAspects
local ClassMechanics = XelAssist.Graph.ClassMechanics

function F:Apply(out, candidate, context)
    if context.classMechanicHandled then return true, false end
    if candidate.targetRelation == "hostile" then return nil end
    local target = State:FriendlyByKey(out, candidate.targetKey)
    local triage = candidate.healingTriage
    local targetExact = target and target.healthExact
    if targetExact == nil and target then targetExact = target.exact end
    if triage and (triage.recipient ~= candidate.targetKey
        or candidate.targetGUID ~= triage.recipientGUID
        or not target or target.guid ~= triage.recipientGUID
        or targetExact ~= true or target.dead == true
        or target.projectedDefeated == true) then return nil, true end
    if target and HunterAspects
        and HunterAspects:Apply(target, candidate, context) then return true, false end
    local kind = context.facts.kind
    if not (target and (kind == "heal" or kind == "hot"
        or kind == "absorb" or kind == "buff")) then return nil, false end
    if kind == "heal" then
        target.health = math.min(target.healthMax,
            target.health + candidate.power)
    elseif kind == "hot" then
        local duration = math.max(1,
            tonumber(candidate.tooltip.duration) or 12)
        target.auras = target.auras or {}
        target.auras[context.action.name] = {
            duration = duration, remaining = duration, mine = true,
            periodicHealRate = candidate.power / duration,
            applicationProbability = 1,
        }
    elseif kind == "absorb" then
        if ClassMechanics
            and ClassMechanics:ApplyExactAbsorb(out, target, candidate) then
            return true, false
        end
        local duration = tonumber(candidate.tooltip.duration)
        target.absorbs = target.absorbs or {}
        target.absorbs[context.action.name] = {
            amount = candidate.power, duration = duration,
            remaining = duration, applicationProbability = 1,
        }
        if ClassMechanics then ClassMechanics:AfterAbsorb(out, candidate) end
    elseif kind == "buff" then
        local duration = tonumber(candidate.tooltip.duration)
        target.auras = target.auras or {}
        target.auras[context.action.name] = {
            duration = duration, remaining = duration, mine = true,
            applicationProbability = 1,
        }
    end
    return true, false
end
