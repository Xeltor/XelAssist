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
local WandCommitment = XelAssist.Graph.WandCommitment
local EventAuras = XelAssist.Graph.EventAuras
local HostileCasts = XelAssist.Graph.HostileCastEvents
local HealthTransfer = XelAssist.Graph.HealthTransfer
local AmbientTargetHealth = XelAssist.Graph.AmbientTargetHealth
local PlayerTaunt = XelAssist.Graph.PlayerTaunt
local NIL_PROBE_TARGET = {}

local function memoActionKey(action)
    local facts = action and action.facts or {}
    local actor = action and (action.actor or "player") or "player"
    local executor = action and action.executor
    if not (action and action.name and actor == "player"
        and (executor == nil or executor == "playerSpell")) then return nil end
    if facts.channel or facts.autoRepeat or facts.wandRepeat or facts.playerAttack
        or facts.onNextSwing or facts.onSwing or facts.exclusiveFamily then
        return nil
    end
    return actor .. "\001" .. action.name
end

local function repeatedActionKeys(actions)
    local seen, repeated, any, i = {}, {}, false, nil
    for i = 1, table.getn(actions or {}) do
        local key = memoActionKey(actions[i])
        if key then
            if seen[key] then repeated[key], any = true, true
            else seen[key] = true end
        end
    end
    return any and repeated or nil
end

-- Scoring asks the causal timeline for target health before every legal rank.
-- Ranks of the same player spell often have an identical pre-application
-- schedule, so repeating the deep state copy cannot change that forecast.  The
-- cache is attached to one Engine evaluation and inherited by its graph states;
-- it never survives into the next live observation.
function L:BeginEvaluation(state, actions)
    if not state then return nil end
    state.xelTimelineProbeCache, state.xelTimelineProbeState = nil, nil
    local eligible = repeatedActionKeys(actions)
    if not eligible then return nil end
    local cache = { byState = {}, eligible = eligible,
        hits = 0, misses = 0, bypasses = 0 }
    state.xelTimelineProbeCache = cache
    state.xelTimelineProbeState = {}
    return cache
end

local function probeTarget(candidate)
    if candidate.targetKey ~= nil then return candidate.targetKey, "key" end
    if candidate.targetGUID ~= nil then return candidate.targetGUID, "guid" end
    if candidate.target ~= nil then return candidate.target, "unit" end
    return NIL_PROBE_TARGET, "none"
end

local function scalar(value)
    if value == nil then return "" end
    if value == true then return "1" end
    if value == false then return "0" end
    return tostring(value)
end

local function probeSignature(candidate)
    local action = candidate and candidate.action
    local tooltip = candidate and candidate.tooltip or {}
    -- These actions can change an ambient clock before their scored application,
    -- or carry rank-specific target-modifier state.  Keep their established
    -- exact probe path instead of assuming equivalence.
    if tooltip.onNextSwing or tooltip.onSwing
        or tooltip.targetArmorReduction or tooltip.targetResistanceReduction
        or tooltip.targetDamageTaken then return nil end
    return table.concat({ scalar(action.name),
        scalar(action.facts and action.facts.kind),
        scalar(candidate.wait), scalar(candidate.cast),
        scalar(candidate.occupancy), scalar(candidate.downtime),
        scalar(candidate.actionStart), scalar(candidate.gcd),
        scalar(candidate.normalGcd), scalar(candidate.targetRelation),
        scalar(candidate.targetSource), scalar(candidate.ambientExcludedKind),
        scalar(candidate.ambientExcludedOffset) }, "\001")
end

local function cachedProbe(source, candidate)
    local cache = source and source.xelTimelineProbeCache
    local group = memoActionKey(candidate and candidate.action)
    if not (cache and group and cache.eligible[group]) then
        if cache then cache.bypasses = cache.bypasses + 1 end
        return nil, nil, cache
    end
    local signature = probeSignature(candidate)
    if not signature then
        cache.bypasses = cache.bypasses + 1
        return nil, nil, cache
    end
    local stateKey = source.xelTimelineProbeState or source
    local stateCache = cache.byState[stateKey]
    if not stateCache then stateCache = {}; cache.byState[stateKey] = stateCache end
    local target, kind = probeTarget(candidate)
    local targetCache = stateCache[target]
    if not targetCache then targetCache = {}; stateCache[target] = targetCache end
    local key = kind .. "\001" .. signature
    return targetCache[key], { bucket = targetCache, key = key }, cache
end

local function syncCandidateTarget(state, candidate)
    if not (candidate and candidate.targetRelation == "hostile"
        and state.hostiles) then return end
    if candidate.targetSource == "engaged" and candidate.targetKey ~= nil
        and State.SyncHostileContext then
        State:SyncHostileContext(state, candidate.targetKey)
    elseif State.SyncSelectedHostile then
        State:SyncSelectedHostile(state)
    end
end

local function append(events, entry, order, window)
    if window and (tonumber(entry.offset) or math.huge) > window then
        return order
    end
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

local function actorDefeated(out, candidate)
    local action = candidate and candidate.action or {}
    local actorName = action.actor == "pet" and "pet" or "player"
    local actor = out.actors and out.actors[actorName]
    if actor and actor.dead then return true end
    local health = actor and tonumber(actor.health)
    local exact = actor and actor.healthExact
    if exact == nil and actor then exact = actor.exact end
    if health ~= nil and exact ~= false then return health <= 0 end
    if actorName == "player" then
        return out.dead == true or tonumber(out.health) ~= nil
            and out.health <= 0
    end
    return false
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

local function advanceWand(out, elapsed)
    if WandCommitment then WandCommitment:Advance(out, elapsed) end
end

local function advanceState(out, elapsed, persistentAuras, eventAuras)
    if elapsed <= 0 then return end
    advancePetEffects(out, elapsed)
    advancePlayerResources(out, elapsed)
    advanceWand(out, elapsed)
    Ongoing:AdvanceState(out, elapsed, persistentAuras)
    Ongoing:AdvanceEventAuras(out, eventAuras, elapsed)
    if PlayerTaunt then PlayerTaunt:Advance(out) end
    if HostileCasts then HostileCasts:Advance(out, elapsed) end
end

local function finishPetReadyAt(out, candidate, actionApplied)
    local action = candidate and candidate.action
    local pet = out.actors and out.actors.pet
    if not (actionApplied and action and action.actor == "pet" and pet
        and pet.actionReadyIn) then return end
    out.actorReadyAt = out.actorReadyAt or {}
    out.actorReadyAt.pet = math.max(tonumber(out.actorReadyAt.pet) or 0,
        (tonumber(out.time) or 0) + math.max(0, pet.actionReadyIn))
end

local function finishChosenBranches(out, candidate, context)
    local aura = out.auras and candidate.action
        and out.auras[candidate.action.name]
    if aura and EventAuras then
        EventAuras:AgeBranches(aura, context.applicationElapsed or 0)
    end
end

local function collectEvents(out, source, candidate, context)
    local events, order = {}, 1
    local window = math.max(0, tonumber(candidate.downtime) or 0)
    local ongoingEvents = Ongoing:Prepare(out, source, candidate, context)
    local i
    for i = 1, table.getn(ongoingEvents) do
        order = append(events, ongoingEvents[i], order, window)
    end
    local hostileEvents = HostileCasts
        and HostileCasts:Events(out, candidate) or {}
    for i = 1, table.getn(hostileEvents) do
        order = append(events, hostileEvents[i], order, window)
    end
    local transferEvents = HealthTransfer
        and HealthTransfer:Events(out, source, candidate) or {}
    for i = 1, table.getn(transferEvents) do
        order = append(events, transferEvents[i], order, window)
    end
    local autoTimeline = AutoShot
        and AutoShot:CreateTimeline(out, source, candidate, context)
    for i = 1, table.getn(autoTimeline and autoTimeline.events or {}) do
        if autoTimeline.events[i].offset <= autoTimeline.windowEnd then
            order = append(events, autoTimeline.events[i], order, window)
        end
    end
    local action = candidate.action
    if action and action.actor == "pet" and action.executor == "petAbility"
        and (tonumber(candidate.cast) or 0) > 0 then
        order = append(events, { owner = "action", kind = "chosenActionStart",
            offset = math.max(0, tonumber(candidate.wait) or 0),
            priority = 20 }, order, window)
    end
    append(events, { owner = "action", kind = "chosenAction",
        offset = context.applicationOffset,
        priority = candidate.ambientActionPriority or 20 }, order, window)
    sortEvents(events)
    return events, autoTimeline
end

local function startChosen(out, candidate, context)
    if hostileDefeated(out, candidate) or actorDefeated(out, candidate) then
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
    local beforeAuras = Ongoing:AuraSnapshot(out)
    if entry.kind == "petAutocastTimelineCap" and Companion then
        Companion:Apply(out, source, candidate, context, entry)
        return beforeAuras
    end
    Ongoing:ApplyEvent(out, source, candidate, context, entry)
    return beforeAuras
end

-- Read-only scoring probe. It stops at the chosen-action event, including
-- same-offset events only when their priority causally precedes the action.
function L:BeforeAction(source, candidate)
    local out = State:Copy(source)
    local context = Actions:Context(source, candidate)
    local persistentAuras = Ongoing:PersistentAuraSnapshot(out)
    local events, autoTimeline = collectEvents(out, source, candidate, context)
    local eventAuras = {}
    local elapsed, damageEvents, i = 0, 0, nil
    for i = 1, table.getn(events) do
        local entry = events[i]
        local prior = out.targetHealth
        local step = entry.offset - elapsed
        advanceState(out, step, persistentAuras, eventAuras)
        if out.targetHealthExact and out.targetHealth < prior then
            damageEvents = damageEvents + 1
        end
        elapsed = entry.offset
        if entry.owner == "action" and entry.kind == "chosenAction" then
            syncCandidateTarget(out, candidate)
            break
        end
        local excluded = candidate.ambientExcludedKind == entry.kind
            and candidate.ambientExcludedOffset
            and math.abs(entry.offset - candidate.ambientExcludedOffset) < 0.0001
        if not excluded then
            prior = out.targetHealth
            if entry.kind == "chosenActionStart" then
                startChosen(out, candidate, context)
            elseif entry.kind == "petAutocastTimelineCap" then
                local beforeAuras = applyPassive(
                    out, source, candidate, context, entry)
                Ongoing:TrackEventAuras(out, beforeAuras, eventAuras)
            elseif entry.owner == "autoShot" then
                AutoShot:ApplyTimelineEvent(out, autoTimeline, entry)
            elseif entry.owner == "hostileCast" then
                HostileCasts:Apply(out, entry)
            elseif entry.owner == "healthTransfer" then
                HealthTransfer:ApplyEvent(out, candidate, context, entry)
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
    local hit, slot, cache = cachedProbe(source, probe)
    if hit then
        cache.hits = cache.hits + 1
        return hit
    end
    local result
    if source.targetHealthExact and probe.targetRelation == "hostile"
        and AmbientTargetHealth
        and not AmbientTargetHealth:CanChange(source) then
        result = { targetHealth = source.targetHealth,
            defeated = hostileDefeated(source, probe), damageEvents = 0,
            autoLaunches = 0, autoImpacts = 0 }
    else result = self:BeforeAction(source, probe) end
    if slot then
        cache.misses = cache.misses + 1
        slot.bucket[slot.key] = result
    end
    return result
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
    local persistentAuras = Ongoing:PersistentAuraSnapshot(out)
    local events, autoTimeline = collectEvents(out, source, candidate, context)
    local eventAuras = {}
    local actionApplied, elapsed, i = false, 0, nil
    for i = 1, table.getn(events) do
        local entry = events[i]
        local step = entry.offset - elapsed
        advanceState(out, step, persistentAuras, eventAuras)
        elapsed = entry.offset
        if entry.kind == "chosenActionStart" then
            syncCandidateTarget(out, candidate)
            startChosen(out, candidate, context)
        elseif entry.owner == "action" then
            syncCandidateTarget(out, candidate)
            local action = candidate.action
            local needsStart = action.actor == "pet"
                and action.executor == "petAbility"
                and (tonumber(candidate.cast) or 0) > 0
            local castStarted = not needsStart or context.actionStarted
            local transferReady = not HealthTransfer
                or HealthTransfer:CanResolve(candidate)
            if castStarted and not hostileDefeated(out, candidate)
                and not actorDefeated(out, candidate)
                and transferReady
                and Actions:Consume(out, candidate, context) then
                if PlayerSwings and PlayerSwings:Is(
                    candidate.action, candidate.tooltip) then
                    actionApplied = PlayerSwings:Arm(out, candidate)
                else
                    context.petEventContext = { applicationElapsed = 0 }
                    Actions:Apply(out, source, candidate, context)
                    context.petEventContext = nil
                    finishChosenBranches(out, candidate, context)
                    actionApplied = true
                end
            end
        elseif entry.owner == "autoShot" then
            AutoShot:ApplyTimelineEvent(out, autoTimeline, entry)
        elseif entry.owner == "hostileCast" then
            HostileCasts:Apply(out, entry)
        elseif entry.owner == "healthTransfer" then
            HealthTransfer:ApplyEvent(out, candidate, context, entry)
        elseif entry.kind == "petAutocastTimelineCap" then
            local beforeAuras = applyPassive(
                out, source, candidate, context, entry)
            Ongoing:TrackEventAuras(out, beforeAuras, eventAuras)
        else
            local beforeAuras = Ongoing:AuraSnapshot(out)
            Ongoing:ApplyEvent(out, source, candidate, context, entry)
            Ongoing:TrackEventAuras(out, beforeAuras, eventAuras)
        end
    end
    local remainder = candidate.downtime - elapsed
    advanceState(out, remainder, persistentAuras, eventAuras)
    finishPetReadyAt(out, candidate, actionApplied)
    if autoTimeline then AutoShot:FinishTimeline(out, autoTimeline) end
    syncCandidateTarget(out, candidate)
    out.chosenActionPrevented = not actionApplied and true or nil
    -- A completed transition is a new immutable graph node.  Context views of
    -- this node inherit the marker, while sibling/descendant nodes never share
    -- memoized health forecasts accidentally.
    if out.xelTimelineProbeCache then out.xelTimelineProbeState = {} end
    return out
end
