-- Turns a live player channel into a weighted graph commitment. Continuing the
-- remaining ticks and clipping them with a newly chosen action are competing
-- branches; neither is a hardcoded priority rule.
XelAssist.Graph.ChannelCommitment = {}
local C = XelAssist.Graph.ChannelCommitment
local HealthTransfer = XelAssist.Graph.HealthTransfer
local SpellTiming = XelAssist.Game.SpellTiming
local LeechChannel = XelAssist.Graph.LeechChannel
local Breakpoint = XelAssist.Graph.ChannelBreakpoint

local EXACT_CADENCE_SOURCE = "client DBC effectAmplitude"
local MAX_CHANNEL_TICKS = 40

local ACTION = { name = "Continue channel", rank = 0, actor = "player",
    executor = "instruction", facts = { kind = "channelContinuation",
        channelContinuation = true, gcd = 0 } }

local function actionFacts(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Facts then
        local facts, status = root:Facts(state, action)
        if status == "known" then return facts end
        if status ~= "absent" then return {} end
    end
    return XelAssist.Game.Actors:Facts(action) or {}
end

local function sameSpell(state, action)
    if not action or (action.actor or "player") ~= "player" then return false end
    if state.playerCastSpellId and action.spellId then
        return state.playerCastSpellId == action.spellId
    end
    return state.playerCastName ~= nil and action.name == state.playerCastName
end

function C:IsActive(state, action)
    return state and state.playerChanneling == true
        and (tonumber(state.castRemaining) or 0) > 0
        and sameSpell(state, action)
end

local function duration(action, tooltip, remaining)
    local facts = action and action.facts or {}
    return math.max(remaining, tonumber(tooltip and tooltip.duration) or 0,
        tonumber(facts.cast) or tonumber(tooltip and tooltip.cast) or 0,
        facts.channel and 3 or 0)
end

local function tickWindow(remaining, interval, nextTick)
    remaining, interval, nextTick = tonumber(remaining), tonumber(interval),
        tonumber(nextTick)
    if not (remaining and remaining >= 0 and interval and interval > 0
        and nextTick and nextTick >= 0) then
        return nil
    end
    local ticks, at = 0, nextTick
    while at <= remaining + 0.0001 and ticks < MAX_CHANNEL_TICKS do
        ticks, at = ticks + 1, at + interval
    end
    if at <= remaining + 0.0001 then return nil end
    return { remainingTicks = ticks,
        nextTickIn = ticks > 0 and nextTick or nil, interval = interval }
end

local function observedChannel(action, remaining)
    if type(GetCastInfo) ~= "function" or type(GetTime) ~= "function" then
        return nil
    end
    local ok, info = pcall(GetCastInfo)
    if not (ok and type(info) == "table"
        and tonumber(info.castType) == 3
        and tonumber(info.spellId) == tonumber(action and action.spellId)) then
        return nil
    end
    local started, observedRemaining = tonumber(info.castStartS),
        tonumber(info.castRemainingMs)
    if not (started and observedRemaining and observedRemaining >= 0) then
        return nil
    end
    observedRemaining = observedRemaining / 1000
    if math.abs(observedRemaining - remaining) > 0.08 then return nil end
    local elapsed = GetTime() - started
    if elapsed < -0.0001 or elapsed > 60 then return nil end
    return math.max(0, elapsed)
end

local function exactCadence(action, tooltip, remaining)
    if not (tooltip and tooltip.channelIntervalSource
        == EXACT_CADENCE_SOURCE and tonumber(tooltip.duration)
        and SpellTiming and SpellTiming.TickCount and SpellTiming.Next) then
        return nil
    end
    local interval, total = tonumber(tooltip.channelInterval),
        tonumber(tooltip.duration)
    local totalTicks = SpellTiming:TickCount(total, interval)
    if not totalTicks or totalTicks > MAX_CHANNEL_TICKS then return nil end
    local elapsed = observedChannel(action, remaining)
    if elapsed == nil then return nil end
    local nextTick = SpellTiming:Next(interval, elapsed)
    local cadence = tickWindow(remaining, interval, nextTick)
    if not cadence then return nil end
    cadence.total, cadence.totalTicks, cadence.source = total, totalTicks,
        tooltip.channelIntervalSource
    cadence.rootRemaining, cadence.rootNextTickIn = remaining,
        cadence.nextTickIn
    return cadence
end

local function remainingCadence(cadence, remaining)
    if not (cadence and tonumber(cadence.rootRemaining)
        and tonumber(cadence.rootNextTickIn)) then return nil end
    local progressed = cadence.rootRemaining - (tonumber(remaining) or -1)
    if progressed < -0.0001 then return nil end
    local nextTick = cadence.rootNextTickIn - math.max(0, progressed)
    while nextTick <= 0.0001 do nextTick = nextTick + cadence.interval end
    local timing = tickWindow(remaining, cadence.interval, nextTick)
    if timing then timing.totalTicks = cadence.totalTicks end
    return timing
end

local function continuationValue(state, kind, power, remaining, known, missing)
    if not known then return 500 end
    if kind == "damage" or kind == "builder" or kind == "dot" then
        local effective = power
        if state.targetHealthExact then
            effective = math.min(effective, math.max(0, state.targetHealth or 0))
        end
        local value = 250 + effective * 4 / math.max(0.5, remaining)
        if state.role == "damage" then value = value * 1.15
        elseif state.role == "healer" then value = value * 0.85 end
        return value
    elseif kind == "heal" or kind == "hot" or kind == "petHeal" then
        missing = math.max(0, tonumber(missing) or 0)
        local effective = math.min(power, missing)
        local value = effective * 5 / math.max(0.5, remaining)
        if state.role == "healer" then value = value * 1.25
        elseif state.role == "damage" then value = value * 0.85 end
        return value
    elseif kind == "resource" then
        local missing = math.max(0, (state.resourceMax or 0) - (state.resource or 0))
        return math.min(power, missing) * 4 / math.max(0.5, remaining)
    end
    return math.max(500, power * 2 / math.max(0.5, remaining))
end

local function friendlyTarget(state, guid, match)
    local fixed = match and match.facts and match.facts.fixedTarget
    local function fixedRecord()
        local target = fixed
            and XelAssist.Graph.State:FriendlyByUnit(state, fixed) or nil
        if target then return target end
        return fixed and state and state.actors and state.actors[fixed] or nil
    end
    if guid == nil and fixed then
        return fixedRecord()
    end
    if guid == nil then return nil end
    local target = XelAssist.Graph.State:FriendlyByKey(state, guid)
    if target then return target end
    local key, record
    for key, record in pairs(state.friendlies and state.friendlies.byKey or {}) do
        if record.guid == guid then return record end
    end
    target = fixedRecord()
    if target and target.guid == guid then return target end
    return nil
end

function C:Prepare(state, actions)
    state.channelCommitment = nil
    local remaining = math.max(0, tonumber(state.castRemaining) or 0)
    if not state.playerChanneling or remaining <= 0 then return end

    local match, tooltip, i
    for i = 1, table.getn(actions or {}) do
        if sameSpell(state, actions[i]) then
            match = actions[i]
            tooltip = actionFacts(state, match)
            break
        end
    end
    local known = match ~= nil
    local total, raw, estimated = remaining, 0, true
    if match then
        total = duration(match, tooltip, remaining)
        raw, estimated = XelAssist.Graph.ActionPower:Estimate(
            match, tooltip, state, state.playerCastTargetGUID or state.targetGUID)
    end
    local cadence = match and exactCadence(match, tooltip, remaining) or nil
    local power = 0
    if cadence then
        cadence.tickPower = math.max(0, tonumber(raw) or 0)
            / cadence.totalTicks
        power = cadence.tickPower * cadence.remainingTicks
    elseif match and not (match.facts and match.facts.healthFundedChannel) then
        known, estimated = false, true
    end
    local kind = match and match.facts.kind or "unknown"
    local selfChannel = match and match.facts.self and true or false
    local targetMatches = state.playerCastTargetGUID ~= nil
        and state.playerCastTargetGUID == state.targetGUID
    local friendly = friendlyTarget(state, state.playerCastTargetGUID, match)
    local friendlyMissing = friendly and math.max(0,
        (tonumber(friendly.healthMax) or 0) - (tonumber(friendly.health) or 0))
    if (kind == "damage" or kind == "builder" or kind == "dot")
        and not targetMatches then
        power, known = 0, false
    elseif (kind == "heal" or kind == "hot" or kind == "petHeal")
        and not friendly then
        power, known = 0, false
    end
    local healthTransferData = match and tooltip
        and tooltip.healthTransfer and tooltip.healthTransfer.exact
        and match.facts.healthFundedChannel and tooltip.healthTransfer or nil
    local healthTransferPlan = healthTransferData and HealthTransfer
        and HealthTransfer:ContinuationPlan(
            state, healthTransferData, remaining, total) or nil
    local leechEvidence = LeechChannel and LeechChannel:Evidence(
        state, match, tooltip, cadence, targetMatches) or nil
    local damageEvidence = Breakpoint and Breakpoint:DamageEvidence(
        state, match, tooltip, cadence, targetMatches) or nil
    local value = continuationValue(
        state, kind, power, remaining, known, friendlyMissing)
    if healthTransferData then
        known, estimated = true, false
        power = healthTransferPlan and healthTransferPlan.rawHealing or 0
        value = healthTransferPlan
            and HealthTransfer:Value(state, healthTransferPlan) or 0
    end
    state.channelCommitment = {
        name = state.playerCastName or match and match.name or "current channel",
        spellId = state.playerCastSpellId,
        targetGUID = state.playerCastTargetGUID or friendly and friendly.guid,
        targetMatches = targetMatches, selfChannel = selfChannel,
        friendlyKey = friendly and (friendly.key or friendly.guid),
        friendlyUnit = friendly and friendly.unit
            or match and match.facts.fixedTarget,
        remaining = remaining, total = total, power = power,
        kind = kind, known = known, estimated = estimated,
        cadence = cadence,
        value = value, healthTransferData = healthTransferData,
        healthTransferPlan = healthTransferPlan,
        leechEvidence = leechEvidence,
        damageEvidence = damageEvidence,
        damageActor = match and (match.facts.damageActor
            or match.facts.effectActor or match.actor or "player"),
        threatFactor = match and math.max(0,
            tonumber(match.facts.threat) or 1) or 1,
    }
end

function C:CanClip(state, action)
    local facts = action and action.facts or {}
    return state and state.playerChanneling == true
        and (tonumber(state.castRemaining) or 0) > 0
        and action and (action.actor or "player") == "player"
        and not (facts.channelContinuation
            or facts.autoRepeat and not facts.wandRepeat
            or facts.playerAttack or facts.onNextSwing or facts.onSwing)
end

function C:Preserves(state, action)
    local facts = action and action.facts or {}
    return state and state.playerChanneling == true
        and (tonumber(state.castRemaining) or 0) > 0
        and action and (action.actor or "player") == "player"
        and (facts.autoRepeat and not facts.wandRepeat or facts.playerAttack
            or facts.onNextSwing or facts.onSwing) and true or false
end

function C:CurrentValue(state)
    local commitment = state and state.channelCommitment
    if not commitment then return 0 end
    local current = math.max(0, tonumber(state.castRemaining) or 0)
    if commitment.healthTransferData and HealthTransfer then
        local plan = HealthTransfer:ContinuationPlan(state,
            commitment.healthTransferData, current, commitment.total)
        return plan and HealthTransfer:Value(state, plan) or 0
    end
    local cadence = commitment.known and commitment.cadence or nil
    local timing = cadence and remainingCadence(cadence, current) or nil
    if not timing then return current > 0 and 500 or 0 end
    local power = math.max(0, tonumber(cadence.tickPower) or 0)
        * timing.remainingTicks
    local leech = LeechChannel and LeechChannel:Plan(
        state, commitment, timing) or nil
    if leech then power = leech.damage end
    local friendly = commitment.friendlyKey
        and XelAssist.Graph.State:FriendlyByKey(
            state, commitment.friendlyKey) or nil
    local missing = friendly and math.max(0,
        (tonumber(friendly.healthMax) or 0)
            - (tonumber(friendly.health) or 0)) or nil
    local value = continuationValue(state, commitment.kind, power,
        current, true, missing)
    return leech and LeechChannel:Value(leech, current, value) or value
end

function C:Adjust(context)
    if self:Preserves(context.state, context.action) then
        context.value = context.value + self:CurrentValue(context.state)
        context.preservesChannel = true
        context.reason = context.reason .. " while preserving the active channel"
    elseif self:CanClip(context.state, context.action) then
        context.clipsChannel = true
        context.channelOpportunityValue = self:CurrentValue(context.state)
        if context.state.channelCommitmentClaimed then
            context.value = context.value - context.channelOpportunityValue
        end
        local name = context.state.channelCommitment
            and context.state.channelCommitment.name or "the active channel"
        context.reason = context.reason .. "; worth clipping " .. tostring(name)
    end
end

function C:Candidate(state)
    local commitment = state and state.channelCommitment
    if not commitment then return nil end
    local current = math.max(0, tonumber(state.castRemaining) or 0)
    if current <= 0 then return nil end
    local transferPlan = commitment.healthTransferData and HealthTransfer
        and HealthTransfer:ContinuationPlan(state,
            commitment.healthTransferData, current, commitment.total) or nil
    if commitment.healthTransferData and not transferPlan then return nil end
    local cadence = commitment.known and commitment.cadence or nil
    if cadence and not commitment.healthTransferData and Breakpoint then
        return Breakpoint:Candidate(state, commitment, ACTION)
    end
    local timing = cadence and remainingCadence(cadence, current) or nil
    local projectedPower = timing and math.max(0,
        tonumber(cadence.tickPower) or 0) * timing.remainingTicks or 0
    local leech = LeechChannel and LeechChannel:Plan(
        state, commitment, timing) or nil
    if leech then projectedPower = leech.damage end
    local action = {}
    local key, value
    for key, value in pairs(ACTION) do action[key] = value end
    action.name = "Continue " .. tostring(commitment.name)
    local friendly = commitment.friendlyUnit ~= nil
    local planned = transferPlan and transferPlan.plannedDuration
        or leech and math.max(0.05, leech.duration) or current
    return { action = action, value = transferPlan
            and math.max(1, HealthTransfer:Value(state, transferPlan))
            or state.channelCommitmentClaimed
                and 1 or math.max(1, self:CurrentValue(state)),
        reason = commitment.known
            and "preserves the remaining channel value"
            or "preserves an unpriced active channel",
        target = commitment.targetMatches and "target"
            or friendly and commitment.friendlyUnit or "player",
        targetKey = commitment.targetMatches and state.targetGUID
            or friendly and (commitment.friendlyKey
                or commitment.friendlyUnit) or "player",
        targetGUID = commitment.targetMatches and state.targetGUID
            or friendly and commitment.targetGUID or nil,
        targetRelation = commitment.targetMatches and "hostile"
            or friendly and commitment.friendlyUnit == "pet" and "pet"
            or friendly and "ally" or "self",
        targetSource = "active channel", cost = 0, costKnown = true,
        cast = transferPlan and planned or 0, wait = 0, occupancy = planned,
        downtime = planned, valueDowntime = planned,
        gcd = 0, normalGcd = false,
        tooltip = { cost = 0, cast = 0, gcd = 0,
            source = "active channel" },
        power = transferPlan and transferPlan.rawHealing
            or projectedPower,
        rawPower = transferPlan and transferPlan.rawHealing
            or leech and leech.rawDamage
            or projectedPower,
        effectivePower = transferPlan and transferPlan.effectiveHealing
            or leech and leech.effectiveDamage
            or commitment.targetMatches and state.targetHealthExact
                and math.min(projectedPower,
                    math.max(0, tonumber(state.targetHealth) or 0))
            or projectedPower, effectDelivery = leech
                and leech.applicationDelivery or 1,
        estimated = commitment.estimated, channelCommitment = commitment,
        channelCadence = timing,
        healthTransfer = transferPlan, leechChannel = leech }
end

local function clearChannel(out)
    out.playerCasting, out.playerChanneling = false, false
    out.playerCastName, out.playerCastSpellId = nil, nil
    out.playerCastTargetGUID, out.castRemaining = nil, 0
    out.channelCommitment, out.channelCommitmentClaimed = nil, nil
    if out.actorReadyAt then
        out.actorReadyAt.player = tonumber(out.time) or 0
    end
end

function C:Apply(out, candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    if facts.channelContinuation then
        if candidate.channelBreakpoint and Breakpoint then
            return Breakpoint:Apply(out, candidate)
        end
        if candidate.healthTransfer and HealthTransfer then
            HealthTransfer:Finish(out, candidate)
            if out.playerChanneling then
                out.channelCommitmentClaimed = nil
            end
            return true
        end
        if candidate.leechChannel and LeechChannel then return true end
        local commitment = candidate.channelCommitment or {}
        if commitment.targetMatches and (commitment.kind == "damage"
            or commitment.kind == "builder" or commitment.kind == "dot")
            and XelAssist.Graph.HostileEffects then
            XelAssist.Graph.HostileEffects:ApplySelectedDamage(
                out, math.max(0, tonumber(candidate.power) or 0))
        elseif commitment.kind == "resource" then
            out.resource = math.min(out.resourceMax or 0,
                (out.resource or 0) + math.max(0, tonumber(candidate.power) or 0))
        elseif commitment.kind == "petHeal" and out.actors
            and out.actors.pet then
            local amount = math.max(0, tonumber(candidate.power) or 0)
            out.actors.pet.health = math.min(out.actors.pet.healthMax,
                out.actors.pet.health + amount)
            XelAssist.Graph.CompanionCommandPolicy:UpdateRecovery(
                out.actors.pet)
            local target = commitment.friendlyKey
                and XelAssist.Graph.State:FriendlyByKey(
                    out, commitment.friendlyKey) or nil
            if target then target.health = out.actors.pet.health end
        elseif commitment.kind == "heal" or commitment.kind == "hot" then
            local target = commitment.friendlyKey
                and XelAssist.Graph.State:FriendlyByKey(
                    out, commitment.friendlyKey) or nil
            if target then
                target.health = math.min(target.healthMax,
                    target.health + math.max(0, tonumber(candidate.power) or 0))
            end
        end
        clearChannel(out)
        return true
    end
    if facts.movementSetup and out.playerChanneling then
        clearChannel(out)
    end
    -- HealthTransfer started its replacement channel at the causal start event;
    -- a clip marker describes the old channel and must not clear the new one.
    if candidate and candidate.healthTransfer then return false end
    if candidate and candidate.clipsChannel then
        clearChannel(out)
    elseif candidate and candidate.preservesChannel then
        out.channelCommitmentClaimed = true
    end
    return false
end
