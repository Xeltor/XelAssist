-- Turns a live player channel into a weighted graph commitment. Continuing the
-- remaining ticks and clipping them with a newly chosen action are competing
-- branches; neither is a hardcoded priority rule.
XelAssist.Graph.ChannelCommitment = {}
local C = XelAssist.Graph.ChannelCommitment

local ACTION = { name = "Continue channel", rank = 0, actor = "player",
    executor = "instruction", facts = { kind = "channelContinuation",
        channelContinuation = true, gcd = 0 } }

local function sameSpell(state, action)
    if not action or (action.actor or "player") ~= "player" then return false end
    if state.playerCastSpellId and action.spellId then
        return state.playerCastSpellId == action.spellId
    end
    return state.playerCastName ~= nil and action.name == state.playerCastName
end

local function duration(action, tooltip, remaining)
    local facts = action and action.facts or {}
    return math.max(remaining, tonumber(tooltip and tooltip.duration) or 0,
        tonumber(facts.cast) or tonumber(tooltip and tooltip.cast) or 0,
        facts.channel and 3 or 0)
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
    elseif kind == "heal" or kind == "hot" then
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

function C:Prepare(state, actions)
    state.channelCommitment = nil
    local remaining = math.max(0, tonumber(state.castRemaining) or 0)
    if not state.playerChanneling or remaining <= 0 then return end

    local match, tooltip, i
    for i = 1, table.getn(actions or {}) do
        if sameSpell(state, actions[i]) then
            match = actions[i]
            tooltip = XelAssist.Game.Actors:Facts(match) or {}
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
    local power = math.max(0, tonumber(raw) or 0)
        * math.min(1, remaining / math.max(remaining, total))
    local kind = match and match.facts.kind or "unknown"
    local selfChannel = match and match.facts.self and true or false
    local targetMatches = state.playerCastTargetGUID ~= nil
        and state.playerCastTargetGUID == state.targetGUID
    local friendly = state.playerCastTargetGUID
        and XelAssist.Graph.State:FriendlyByKey(
            state, state.playerCastTargetGUID) or nil
    local friendlyMissing = friendly and math.max(0,
        (tonumber(friendly.healthMax) or 0) - (tonumber(friendly.health) or 0))
    if (kind == "damage" or kind == "builder" or kind == "dot")
        and not targetMatches then
        power, known = 0, false
    elseif (kind == "heal" or kind == "hot") and not friendly then
        power, known = 0, false
    end
    state.channelCommitment = {
        name = state.playerCastName or match and match.name or "current channel",
        spellId = state.playerCastSpellId,
        targetGUID = state.playerCastTargetGUID,
        targetMatches = targetMatches, selfChannel = selfChannel,
        friendlyKey = friendly and friendly.key,
        friendlyUnit = friendly and friendly.unit,
        remaining = remaining, total = total, power = power,
        kind = kind, known = known, estimated = estimated,
        value = continuationValue(
            state, kind, power, remaining, known, friendlyMissing),
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
    local root = math.max(0.001, tonumber(commitment.remaining) or current)
    return math.max(0, tonumber(commitment.value) or 0)
        * math.min(1, current / root)
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
    local fraction = math.min(1, current
        / math.max(0.001, tonumber(commitment.remaining) or current))
    local action = {}
    local key, value
    for key, value in pairs(ACTION) do action[key] = value end
    action.name = "Continue " .. tostring(commitment.name)
    local friendly = commitment.friendlyKey ~= nil
    return { action = action, value = state.channelCommitmentClaimed
            and 1 or math.max(1, self:CurrentValue(state)),
        reason = commitment.known
            and "preserves the remaining channel value"
            or "preserves an unpriced active channel",
        target = commitment.targetMatches and "target"
            or friendly and commitment.friendlyUnit or "player",
        targetKey = commitment.targetMatches and state.targetGUID
            or friendly and commitment.friendlyKey or "player",
        targetGUID = commitment.targetMatches and state.targetGUID
            or friendly and commitment.targetGUID or nil,
        targetRelation = commitment.targetMatches and "hostile"
            or friendly and "ally" or "self",
        targetSource = "active channel", cost = 0, costKnown = true,
        cast = 0, wait = 0, occupancy = current,
        downtime = current, valueDowntime = current,
        gcd = 0, normalGcd = false,
        tooltip = { cost = 0, cast = 0, gcd = 0,
            source = "active channel" },
        power = (commitment.power or 0) * fraction,
        rawPower = (commitment.power or 0) * fraction,
        effectivePower = (commitment.power or 0) * fraction, effectDelivery = 1,
        estimated = commitment.estimated, channelCommitment = commitment }
end

function C:Apply(out, candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    if facts.channelContinuation then
        local commitment = candidate.channelCommitment or {}
        if commitment.targetMatches and (commitment.kind == "damage"
            or commitment.kind == "builder" or commitment.kind == "dot")
            and XelAssist.Graph.HostileEffects then
            XelAssist.Graph.HostileEffects:ApplySelectedDamage(
                out, math.max(0, tonumber(candidate.power) or 0))
        elseif commitment.kind == "resource" then
            out.resource = math.min(out.resourceMax or 0,
                (out.resource or 0) + math.max(0, tonumber(candidate.power) or 0))
        elseif commitment.kind == "heal" or commitment.kind == "hot" then
            local target = commitment.friendlyKey
                and XelAssist.Graph.State:FriendlyByKey(
                    out, commitment.friendlyKey) or nil
            if target then
                target.health = math.min(target.healthMax,
                    target.health + math.max(0, tonumber(candidate.power) or 0))
            end
        end
        out.playerCasting, out.playerChanneling = false, false
        out.playerCastName, out.playerCastSpellId = nil, nil
        out.playerCastTargetGUID, out.castRemaining = nil, 0
        return true
    end
    if candidate and candidate.clipsChannel then
        out.playerCasting, out.playerChanneling = false, false
        out.playerCastName, out.playerCastSpellId = nil, nil
        out.playerCastTargetGUID, out.castRemaining = nil, 0
    elseif candidate and candidate.preservesChannel then
        out.channelCommitmentClaimed = true
    end
    return false
end
