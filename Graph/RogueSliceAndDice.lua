-- Consequence-driven Slice and Dice projection.  Exact aura-138 evidence
-- changes the reset cadence of both verified melee clocks and values only the
-- extra white damage expected before this hostile dies.  No combo threshold,
-- action order or rank name is encoded here.
XelAssist.Graph.RogueSliceAndDice = {}
local S = XelAssist.Graph.RogueSliceAndDice

local ATTACK_GUARD = 0.05
local EPSILON = 0.000001

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.RogueSliceAndDice
end

local function evidence(action, tooltip)
    local owner = runtime()
    if not owner then return nil end
    return owner:Evidence(tooltip) or owner:Evidence(action)
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

local function sealedRoot(state)
    local root, owner = state and state.rogueSliceAndDiceRoot, runtime()
    if not (owner and type(root) == "table" and root.valid == true
        and root.exact == true and root.portfolio == "rogueSliceAndDice"
        and type(root.ranks) == "table" and type(root.aura) == "table"
        and root.aura.valid == true and root.aura.exact == true) then
        return nil, "exact Slice and Dice root evidence unavailable"
    end
    local count, spellId, found = 0, nil, nil
    for spellId, found in pairs(root.ranks) do
        if not owner:Evidence({ rogueSliceAndDiceEvidence = found }) then
            return nil, "Slice and Dice root rank evidence changed"
        end
        count = count + 1
    end
    if count ~= owner.RANK_COUNT then
        return nil, "Slice and Dice root rank set is incomplete"
    end
    return root, nil
end

local function roundFor(state, hand)
    local attack = state and state.playerAttack
    return attack and (hand == "off" and attack.offhandAttackRound
        or attack.attackRound) or nil
end

local function laneFromRound(round, activePercent)
    local speed = round and finite(round.speed, 0.01, 20)
    local interval = round and finite(round.interval, 0.01, 21)
    if not (speed and interval and round.speedTrusted == true
        and round.verified == true and round.projectable == true
        and round.normalDamageKnown == true
        and finite(round.power, 0, 10000000) and round.targetGuid ~= nil
        and math.abs(interval - speed - ATTACK_GUARD) <= 0.001) then return nil end
    local multiplier = activePercent and 1 + activePercent / 100 or 1
    return { exact = true, baseSpeed = speed * multiplier,
        guard = ATTACK_GUARD, targetGuid = round.targetGuid,
        power = round.power }
end

function S:Attach(state)
    local owner = runtime()
    if not (state and owner and owner.RootEvidence) then return nil end
    local root = owner:RootEvidence()
    state.rogueSliceAndDiceRoot = root
    if not (root and root.valid and root.aura and root.aura.valid) then
        state.rogueSliceAndDice = { exact = false,
            reason = root and root.reason or "Slice and Dice root unavailable" }
        return nil
    end
    local activePercent = root.aura.active and root.aura.percent or nil
    local model = { exact = true, active = root.aura.active == true,
        spellId = root.aura.spellId, percent = activePercent,
        remaining = root.aura.remaining, lanes = {} }
    model.lanes.main = laneFromRound(roundFor(state, "main"), activePercent)
    model.lanes.off = laneFromRound(roundFor(state, "off"), activePercent)
    state.rogueSliceAndDice = model
    return model
end

function S:Copy(source, target)
    if not (source and target) then return false end
    target.rogueSliceAndDiceRoot = source.rogueSliceAndDiceRoot
    target.rogueSliceAndDice = copy(source.rogueSliceAndDice, 4)
    return source.rogueSliceAndDice ~= nil
end

function S:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

local function selfDescriptor(state, descriptor)
    if not (descriptor and descriptor.unit == "player"
        and descriptor.relation == "self") then return false end
    local actors = state and state.actors
    local playerGuid = actors and actors.player and actors.player.guid
    return descriptor.guid == nil or playerGuid == nil
        or descriptor.guid == playerGuid
end

local function exactLane(state, hand)
    local model = state and state.rogueSliceAndDice
    local lane = model and model.lanes and model.lanes[hand]
    local round = roundFor(state, hand)
    if not (lane and lane.exact == true and round
        and round.verified == true and round.projectable == true
        and round.normalDamageKnown == true
        and round.targetGuid == lane.targetGuid
        and finite(round.power, 0, 10000000)) then return nil end
    return lane, round
end

function S:Blocker(action, state, descriptor, tooltip)
    local found = evidence(action, tooltip)
    if not found then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "melee haste is player-owned", true
    end
    local root, reason = sealedRoot(state)
    if not root then return reason, true end
    local rank = root.ranks[found.spellId]
    if not runtime():Evidence({ rogueSliceAndDiceEvidence = rank }) then
        return "Slice and Dice action evidence changed", true
    end
    if not selfDescriptor(state, descriptor) then
        return "melee haste requires the player recipient", true
    end
    local model = state.rogueSliceAndDice
    if not (model and model.exact == true) then
        return "exact player melee-haste state unavailable", true
    end
    if model.active == true and (tonumber(model.remaining) or 0) > EPSILON then
        return "player melee haste is already active", true
    end
    if state.hostile ~= true or state.targetGUID == nil then
        return "hostile survival target unavailable", true
    end
    local main, off = exactLane(state, "main"), exactLane(state, "off")
    if not main and not off then
        return "exact Rogue white-swing lane unavailable", true
    end
    return nil, true
end

local WHITE = {
    main = { name = "Attack", actor = "player", facts = {
        kind = "damage", school = 0, melee = true, whiteAttack = true,
        weaponHand = "main", deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true } },
    off = { name = "Attack", actor = "player", facts = {
        kind = "damage", school = 0, melee = true, whiteAttack = true,
        weaponHand = "off", deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true } },
}
local WHITE_TOOLTIP = { school = 0 }

local function expectedSwing(state, hand, round)
    local raw = finite(round and round.power, 0, 10000000)
    if not raw then return nil end
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    local effects = XelAssist.Graph and XelAssist.Graph.Effects
    if not (resistance and effects and type(resistance.Estimate) == "function"
        and type(effects.Decision) == "function") then return nil end
    local estimate = resistance:Estimate(
        WHITE[hand], "target", WHITE_TOOLTIP, state)
    local decision = finite(effects:Decision(estimate, state, true), 0, 1)
    return decision and raw * decision or nil
end

local function areaUntil(time, lower, upper)
    if time <= 0 then return 0 end
    if upper <= lower + EPSILON then return math.min(time, lower) end
    if time <= lower then return time end
    if time < upper then
        local width, x = upper - lower, time - lower
        return lower + x - x * x / (2 * width)
    end
    return lower + (upper - lower) / 2
end

local function survivalWindow(state, startAt, duration)
    local learned = state and state.targetSurvival
    if not (type(learned) == "table" and learned.available == true
        and state.targetHealthExact == true and finite(state.targetHealth, 0, 100000000)
        and finite(learned.incomingDps, 0.000001, 10000000)) then
        return nil, "target survival evidence unavailable"
    end
    local lower = finite(learned.lowerTimeToDie, 0, 3600)
    local upper = finite(learned.upperTimeToDie or learned.timeToDie, 0, 3600)
    if not lower or not upper or upper < lower then
        return nil, "target survival interval unavailable"
    end
    local finish = startAt + duration
    return math.max(0, areaUntil(finish, lower, upper)
        - areaUntil(startAt, lower, upper)), nil
end

local function bonusDps(state, found)
    local total, lanes, hand = 0, 0, nil
    for _, hand in ipairs({ "main", "off" }) do
        local lane, round = exactLane(state, hand)
        if lane then
            local expected = expectedSwing(state, hand, round)
            local interval = lane.baseSpeed + lane.guard
            if expected and interval > 0 then
                total, lanes = total + expected / interval
                    * found.hastePercent / 100, lanes + 1
            end
        end
    end
    return lanes > 0 and total or nil
end

function S:Score(context)
    local action, tooltip = context and context.action,
        context and context.tooltip
    local found = evidence(action, tooltip)
    if not found then return false end
    local blocker = self:Blocker(action, context.state,
        context.descriptor, tooltip)
    if blocker then
        context.value, context.reason = -100000, blocker
        return true
    end
    local duration = finite(tooltip.duration, 0.001, 3600)
    local dps = bonusDps(context.state, found)
    if not (duration and dps) then
        context.value, context.reason = -100000,
            "exact melee-haste damage consequence unavailable"
        return true
    end
    local startAt = (tonumber(context.state.time) or 0)
        + math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    local useful, reason = survivalWindow(context.state, startAt, duration)
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    if not useful then
        context.value, context.reason = 0, reason
        context.estimated = true
        return true
    end
    local bonus = math.min(context.state.targetHealth, dps * useful)
    context.rogueMeleeHasteBonusDps = dps
    context.rogueMeleeHasteUsefulSeconds = useful
    context.rogueMeleeHasteExpectedDamage = bonus
    context.value = bonus * 4
        / math.max(0.5, tonumber(context.downtime) or 0)
    context.reason = useful < duration - EPSILON
        and "adds white damage before the target dies"
        or "accelerates exact white-swing damage"
    context.estimated = true
    return true
end

local function candidateDescriptor(candidate)
    return { unit = candidate and candidate.target or "player",
        relation = candidate and candidate.targetRelation,
        source = candidate and candidate.targetSource,
        key = candidate and candidate.targetKey,
        guid = candidate and candidate.targetGUID }
end

local function playerRecord(state)
    local friendlies = state and state.friendlies
    local key = friendlies and friendlies.byUnit and friendlies.byUnit.player
    return key ~= nil and friendlies.byKey and friendlies.byKey[key] or nil
end

function S:Apply(state, candidate)
    local found = evidence(candidate and candidate.action,
        candidate and candidate.tooltip)
    if not found then return false end
    local blocker = self:Blocker(candidate.action, state,
        candidateDescriptor(candidate), candidate.tooltip)
    if blocker then return false end
    local duration = finite(candidate.tooltip.duration, 0.001, 3600)
    if not duration then return false end
    local model = state.rogueSliceAndDice
    model.active, model.spellId, model.percent = true,
        found.spellId, found.hastePercent
    model.remaining, model.source = duration,
        "projected exact Rogue melee haste"
    local record = playerRecord(state)
    if record then
        record.auras = record.auras or {}
        record.auras[candidate.action.name] = { duration = duration,
            remaining = duration, mine = true, spellId = found.spellId,
            applicationProbability = 1, rogueSliceAndDice = true,
            meleeHastePercent = found.hastePercent }
    end
    return true
end

function S:Advance(state, elapsed)
    local model = state and state.rogueSliceAndDice
    if not (model and model.exact == true and model.active == true) then
        return false
    end
    model.remaining = math.max(0,
        (tonumber(model.remaining) or 0) - math.max(0, tonumber(elapsed) or 0))
    if model.remaining <= EPSILON then model.active = false end
    return true
end

-- Called after a resolved hand is due. The current timer is intentionally not
-- rescaled: VMaNGOS applies aura 138 only to resets made after that boundary.
function S:IntervalAfter(state, hand, swingOffset, fallback)
    local model = state and state.rogueSliceAndDice
    local lane = model and model.lanes and model.lanes[hand]
    if not (model and model.exact == true and lane and lane.exact == true) then
        return fallback
    end
    local active = model.active == true
        and (tonumber(model.remaining) or 0)
            > math.max(0, tonumber(swingOffset) or 0) + EPSILON
    local percent = active and finite(model.percent, 0, 1000) or 0
    return lane.baseSpeed / (1 + (percent or 0) / 100) + lane.guard
end
