-- One causal clock for projected combat events. Each event keeps its own game
-- mechanic owner, while this module decides only when it happens.
XelAssist.Graph.Timeline = {}
local L = XelAssist.Graph.Timeline
local State = XelAssist.Graph.State
local Actions = XelAssist.Graph.ActionEffects
local AutoShot = XelAssist.Graph.AutoShotEffects
local Ongoing = XelAssist.Graph.OngoingEffects
local Companion = XelAssist.Graph.CompanionEvents
local CompanionResources = XelAssist.Graph.CompanionResources
local PlayerSwings = XelAssist.Graph.PlayerSwings

local function append(events, entry, order)
    entry.order = order
    if not entry.priority then
        if entry.owner == "action" then entry.priority = 20
        elseif entry.kind == "launch" then entry.priority = 30
        elseif entry.kind == "impact" then entry.priority = 40
        else entry.priority = 50 end
    end
    table.insert(events, entry)
    return order + 1
end

local function sortEvents(events)
    table.sort(events, function(left, right)
        if left.offset ~= right.offset then return left.offset < right.offset end
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        return left.order < right.order
    end)
end

local function hostileDefeated(out, candidate)
    if candidate.targetRelation ~= "hostile" then return false end
    if out.targetHealthExact and out.targetHealth <= 0 then return true end
    return not out.hostile
end

local function advancePetEffects(out, elapsed)
    if elapsed <= 0 then return end
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        XelAssist.Game.Pets.Effects:Advance(out, elapsed)
    end
end

local function advancePlayerResources(out, elapsed)
    local resources = XelAssist.Game.Player
        and XelAssist.Game.Player.Resources
    if resources then resources:Advance(out, elapsed) end
end

local function collectEvents(out, source, candidate, context, advanceWindow)
    local events, order = {}, 1
    local ongoingEvents
    if advanceWindow then
        ongoingEvents = Ongoing:Prepare(out, source, candidate, context)
    else ongoingEvents = Ongoing:Events(out, source, candidate, context) end
    local i
    for i = 1, table.getn(ongoingEvents) do
        order = append(events, ongoingEvents[i], order)
    end
    local autoTimeline = AutoShot
        and AutoShot:CreateTimeline(out, source, candidate, context)
    for i = 1, table.getn(autoTimeline and autoTimeline.events or {}) do
        if autoTimeline.events[i].offset <= autoTimeline.windowEnd then
            order = append(events, autoTimeline.events[i], order)
        end
    end
    local action = candidate.action
    if action and action.actor == "pet" and action.executor == "petAbility"
        and (tonumber(candidate.cast) or 0) > 0 then
        order = append(events, { owner = "action", kind = "chosenActionStart",
            offset = math.max(0, tonumber(candidate.wait) or 0),
            priority = 20 }, order)
    end
    append(events, { owner = "action", kind = "chosenAction",
        offset = context.applicationOffset,
        priority = candidate.ambientActionPriority or 20 }, order)
    sortEvents(events)
    return events, autoTimeline
end

local function startChosen(out, candidate, context)
    if hostileDefeated(out, candidate) then
        context.actionStartFailed = true
        return false
    end
    local started = CompanionResources
        and CompanionResources:BeginChosen(out, candidate, context)
    context.actionStarted, context.actionStartFailed = started and true or false,
        not started and true or nil
    return started
end

local function applyPassive(out, source, candidate, context, entry)
    if entry.kind == "petAutocastTimelineCap" and Companion then
        return Companion:Apply(out, source, candidate, context, entry)
    end
    local beforeAuras = Ongoing:AuraSnapshot(out)
    Ongoing:ApplyEvent(out, source, candidate, context, entry)
    return beforeAuras
end

-- Read-only scoring probe. It stops at the chosen-action event, including
-- same-offset events only when their priority causally precedes the action.
function L:BeforeAction(source, candidate)
    local out = State:Copy(source)
    local context = Actions:Context(source, candidate)
    local events, autoTimeline = collectEvents(
        out, source, candidate, context, false)
    local eventAuras = {}
    local elapsed, damageEvents, i = 0, 0, nil
    for i = 1, table.getn(events) do
        local entry = events[i]
        local prior = out.targetHealth
        local step = entry.offset - elapsed
        advancePetEffects(out, step)
        advancePlayerResources(out, step)
        Ongoing:AdvanceEventAuras(out, eventAuras, step)
        if out.targetHealthExact and out.targetHealth < prior then
            damageEvents = damageEvents + 1
        end
        elapsed = entry.offset
        if entry.owner == "action" and entry.kind == "chosenAction" then break end
        local excluded = candidate.ambientExcludedKind == entry.kind
            and candidate.ambientExcludedOffset
            and math.abs(entry.offset - candidate.ambientExcludedOffset) < 0.0001
        if not excluded then
            prior = out.targetHealth
            if entry.kind == "chosenActionStart" then
                startChosen(out, candidate, context)
            elseif entry.kind == "petAutocastTimelineCap" then
                applyPassive(out, source, candidate, context, entry)
            elseif entry.owner == "autoShot" then
                AutoShot:ApplyTimelineEvent(out, autoTimeline, entry)
            else
                local beforeAuras = Ongoing:AuraSnapshot(out)
                Ongoing:ApplyEvent(out, source, candidate, context, entry)
                Ongoing:TrackEventAuras(out, beforeAuras, eventAuras)
            end
            if out.targetHealthExact and out.targetHealth < prior then
                damageEvents = damageEvents + 1
            end
        end
    end
    return { targetHealth = out.targetHealth,
        defeated = hostileDefeated(out, candidate),
        damageEvents = damageEvents,
        autoLaunches = out.autoShot and out.autoShot.launches or 0,
        autoImpacts = out.autoShot and out.autoShot.impacts or 0 }
end

-- Scoring keeps intrinsic action value separate from the causal window that
-- reaches a future start. Timeline probes must still see that full window.
function L:BeforeScoredAction(source, candidate)
    local probe, key, value = {}, nil, nil
    for key, value in pairs(candidate) do probe[key] = value end
    probe.downtime = candidate.advanceDowntime or candidate.downtime
    return self:BeforeAction(source, probe)
end

function L:BeforePlayerSwing(source, candidate, impactDelay)
    local delay = tonumber(impactDelay)
    if not delay then return self:BeforeAction(source, candidate) end
    local probe, key, value = {}, nil, nil
    for key, value in pairs(candidate) do probe[key] = value end
    delay = math.max(0, delay)
    probe.wait, probe.cast, probe.occupancy, probe.downtime = delay, 0, 0, delay
    probe.ambientActionPriority = 1000000
    probe.ambientExcludedKind = "playerMainSwing"
    probe.ambientExcludedOffset = delay
    return self:BeforeAction(source, probe)
end

function L:Run(out, source, candidate, context)
    local events, autoTimeline = collectEvents(
        out, source, candidate, context, true)
    local eventAuras = {}
    local actionApplied, elapsed, i = false, 0, nil
    for i = 1, table.getn(events) do
        local entry = events[i]
        local step = entry.offset - elapsed
        advancePetEffects(out, step)
        advancePlayerResources(out, step)
        Ongoing:AdvanceEventAuras(out, eventAuras, step)
        elapsed = entry.offset
        if entry.kind == "chosenActionStart" then
            startChosen(out, candidate, context)
        elseif entry.owner == "action" then
            local action = candidate.action
            local needsStart = action.actor == "pet"
                and action.executor == "petAbility"
                and (tonumber(candidate.cast) or 0) > 0
            local castStarted = not needsStart or context.actionStarted
            if castStarted and not hostileDefeated(out, candidate)
                and Actions:Consume(out, candidate, context) then
                if PlayerSwings and PlayerSwings:Is(
                    candidate.action, candidate.tooltip) then
                    actionApplied = PlayerSwings:Arm(out, candidate)
                else
                    context.petEventContext = { applicationElapsed = 0 }
                    Actions:Apply(out, source, candidate, context)
                    context.petEventContext = nil
                    actionApplied = true
                end
            end
        elseif entry.owner == "autoShot" then
            AutoShot:ApplyTimelineEvent(out, autoTimeline, entry)
        elseif entry.kind == "petAutocastTimelineCap" then
            applyPassive(out, source, candidate, context, entry)
        else
            local beforeAuras = Ongoing:AuraSnapshot(out)
            Ongoing:ApplyEvent(out, source, candidate, context, entry)
            Ongoing:TrackEventAuras(out, beforeAuras, eventAuras)
        end
    end
    local remainder = candidate.downtime - elapsed
    advancePetEffects(out, remainder)
    advancePlayerResources(out, remainder)
    Ongoing:AdvanceEventAuras(out, eventAuras, remainder)
    if autoTimeline then AutoShot:FinishTimeline(out, autoTimeline) end
    out.chosenActionPrevented = not actionApplied and true or nil
    return out
end
