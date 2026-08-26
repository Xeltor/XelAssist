-- Search-pure Rapid Fire projection. Aura 9 changes only attack timers reset
-- while it is active; an already-running melee or ranged timer is never
-- rescaled. Aura 108 changes only DBC-mask-proven cast starts.
XelAssist.Graph.HunterRapidFire = {}
local R = XelAssist.Graph.HunterRapidFire
R.CONSUMER_KEY = "hunterRapidFire:affectedCast"

local EPSILON, MELEE_GUARD = 0.000001, 0.05

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.HunterRapidFire
end

local function copy(value, depth, seen)
    if type(value) ~= "table" or depth <= 0 then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        out[key] = copy(entry, depth - 1, seen)
    end
    return out
end

local function exactState(state)
    local found, owner = state and state.hunterRapidFire, runtime()
    local profile = found and found.profile
    if not (owner and found and found.available == true and found.exact == true
        and type(profile) == "table" and profile.valid == true
        and profile.exact == true and profile.spellId == owner.SPELL_ID
        and profile.family == owner.HUNTER_FAMILY
        and profile.affectMask == owner.AFFECT_MASK
        and profile.hastePercent == owner.HASTE_PERCENT
        and profile.castPercent == owner.CAST_PERCENT
        and profile.duration == owner.DURATION
        and profile.attackAura == owner.ATTACK_SPEED_AURA
        and profile.castAura == owner.CAST_MOD_AURA
        and profile.castOperation == owner.CAST_MOD_OPERATION
        and profile.runtimeUnverified == true) then return nil end
    return found
end

local function meleeRound(state, hand)
    local attack = state and state.playerAttack
    return attack and (hand == "off" and attack.offhandAttackRound
        or attack.attackRound) or nil
end

local function meleeLane(round, active, multiplier)
    local speed, interval = round and finite(round.speed, 0.01, 20),
        round and finite(round.interval, 0.01, 21)
    if not (speed and interval and round.speedTrusted == true
        and round.verified == true and round.projectable == true
        and math.abs(interval - speed - MELEE_GUARD) <= 0.001) then return nil end
    return { exact = true, baseSpeed = speed * (active and multiplier or 1),
        guard = MELEE_GUARD, targetGuid = round.targetGuid }
end

local function rangedLane(auto, active, multiplier)
    local speed = auto and finite(auto.rangedSpeed, 0.01, 20)
    if not (speed and auto.rangedSpeedSource == "live ranged speed") then return nil end
    return { exact = true, baseSpeed = speed * (active and multiplier or 1),
        guard = 0, targetGuid = auto.targetGuid }
end

function R:Attach(state, snapshot)
    if type(state) ~= "table" then return false end
    state.hunterRapidFire = copy(snapshot, 4)
    local model = exactState(state)
    if not model then return false end
    local multiplier = 1 + model.profile.hastePercent / 100
    model.lanes = {
        main = meleeLane(meleeRound(state, "main"), model.active, multiplier),
        off = meleeLane(meleeRound(state, "off"), model.active, multiplier),
        ranged = rangedLane(state.autoShot, model.active, multiplier),
    }
    return true
end

function R:Copy(source, target)
    if not (source and target) then return false end
    target.hunterRapidFire = copy(source.hunterRapidFire, 5)
    return target.hunterRapidFire ~= nil
end

local function setupEvidence(action, tooltip)
    local owner = runtime()
    return owner and (owner:Evidence(tooltip) or owner:Evidence(action)) or nil
end

local function selfDescriptor(state, descriptor)
    if not (descriptor and descriptor.unit == "player"
        and descriptor.relation == "self") then return false end
    local player = state and state.actors and state.actors.player
    return descriptor.guid == nil or not player or player.guid == nil
        or descriptor.guid == player.guid
end

function R:PrepareSetup(action, state, descriptor, tooltip)
    local found = setupEvidence(action, tooltip)
    if not found then return nil, nil, false end
    local current = exactState(state)
    if not current then
        return nil, "exact Rapid Fire aura state unavailable", true
    elseif not selfDescriptor(state, descriptor) then
        return nil, "Rapid Fire requires the player recipient", true
    elseif current.active == true
        and (tonumber(current.remaining) or 0) > EPSILON then
        return nil, "Rapid Fire already active", true
    end
    local cost = tooltip and finite(tooltip.cost, 0, 1000000000)
    if cost == nil then return nil, "Rapid Fire cost is not exact", true end
    local out = copy(tooltip, 2)
    out.hunterRapidFireTransition = { exact = true,
        spellId = found.spellId, duration = found.duration,
        hastePercent = found.hastePercent,
        castPercent = found.castPercent, source = found.source }
    out.classMechanic = "hunterRapidFire"
    return out, nil, true
end

-- Called after ActionAdmission has fixed the start boundary. This is necessary
-- because a currently active 15-second aura can expire while waiting on mana,
-- actor occupancy, or the GCD; cast time is fixed only at the eventual start.
function R:SettleAdmission(action, state, tooltip, actionStart)
    local contract = tooltip and tooltip.hunterRapidFireCast
    if not contract then return tooltip, nil, false end
    if contract.spellId ~= action.spellId then
        return nil, "Rapid Fire cast contract changed", true
    end
    if contract.claimed ~= true then return tooltip, nil, false end
    local current = exactState(state)
    if not current then return nil, "exact Rapid Fire aura state unavailable", true end
    local offset = math.max(0, (tonumber(actionStart)
        or tonumber(state.time) or 0) - (tonumber(state.time) or 0))
    local active = current.active == true
        and (tonumber(current.remaining) or 0) > offset + EPSILON
    if contract.exact ~= true then
        if active then
            return nil, contract.reason
                or "active Rapid Fire cast consequence unavailable", true
        end
        return tooltip, nil, true
    elseif contract.eligible ~= true then return tooltip, nil, true end
    local cast = active and finite(contract.activeCast, 0.001, 60)
        or finite(contract.baselineCast, 0.001, 60)
    if not cast then return nil, "Rapid Fire cast timing unavailable", true end
    local out = copy(tooltip, 2)
    out.cast, out.hunterRapidFireCastApplied = cast, active and true or false
    return out, nil, true
end

function R:Score(context, projection)
    local transition = projection and projection.hunterRapidFireTransition
        or context and context.tooltip
            and context.tooltip.hunterRapidFireTransition
    local owner = runtime()
    if not (owner and transition and transition.exact == true
        and transition.spellId == owner.SPELL_ID
        and transition.duration == owner.DURATION
        and transition.hastePercent == owner.HASTE_PERCENT
        and transition.castPercent == owner.CAST_PERCENT) then
        return false, "Rapid Fire transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "arms exact attack-reset and cast-time consequences"
    return true
end

function R:Apply(state, candidate)
    local transition = candidate and candidate.hunterRapidFireTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.hunterRapidFireTransition
        or candidate and candidate.classMechanicProjection
            and candidate.classMechanicProjection.hunterRapidFireTransition
    local current, owner = exactState(state), runtime()
    if not (current and owner and transition and transition.exact == true
        and transition.spellId == owner.SPELL_ID
        and transition.duration == owner.DURATION
        and transition.hastePercent == owner.HASTE_PERCENT
        and transition.castPercent == owner.CAST_PERCENT) then return false end
    current.active, current.remaining, current.projected = true,
        transition.duration, true
    current.source = "projected exact Rapid Fire activation"
    return true
end

function R:Advance(state, elapsed)
    local current = exactState(state)
    if not (current and current.active == true) then return false end
    current.remaining = math.max(0, (tonumber(current.remaining) or 0)
        - math.max(0, tonumber(elapsed) or 0))
    if current.remaining <= EPSILON then current.active = false end
    return true
end

local function interval(state, lane, offset, fallback)
    local current = exactState(state)
    lane = current and current.lanes and current.lanes[lane]
    if not (current and lane and lane.exact == true) then return fallback end
    local active = current.active == true
        and (tonumber(current.remaining) or 0)
            > math.max(0, tonumber(offset) or 0) + EPSILON
    local multiplier = active and 1 + current.profile.hastePercent / 100 or 1
    return lane.baseSpeed / multiplier + lane.guard
end

function R:MeleeIntervalAfter(state, hand, swingOffset, fallback)
    return interval(state, hand, swingOffset, fallback)
end

function R:RangedIntervalAfter(state, launchOffset, fallback)
    return interval(state, "ranged", launchOffset, fallback)
end

function R:PotentialConsumer(facts)
    local found = facts and facts.hunterRapidFireCast
    return found and found.claimed == true and found.exact == true
        and found.eligible == true
        and finite(found.baselineCast, 0.001, 60)
        and finite(found.activeCast, 0.001, 60) or false
end

function R:ConsumerKey(facts)
    return self:PotentialConsumer(facts) and self.CONSUMER_KEY or nil
end

function R:StrategicSetup(tooltip)
    local transition = tooltip and tooltip.hunterRapidFireTransition
    local owner = runtime()
    if not (owner and transition and transition.exact == true
        and transition.spellId == owner.SPELL_ID
        and transition.duration == owner.DURATION
        and transition.hastePercent == owner.HASTE_PERCENT
        and transition.castPercent == owner.CAST_PERCENT) then return nil end
    return { key = "hunterRapidFire:" .. tostring(transition.spellId),
        consumerKey = self.CONSUMER_KEY }
end
