-- Branch-local five-second melee-haste clock from Octo Overpowering Rage.
-- The current swing is never rescaled; only resets after it can use the aura.
XelAssist.Graph.WarriorOverpoweringRage = {}
local O = XelAssist.Graph.WarriorOverpoweringRage

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value
        or value < low or value > high then return nil end
    return value
end
local function valid(found)
    local owner = XelAssist.Game.Player.WarriorOverpoweringRage
    return owner and type(found) == "table" and found.available == true
        and found.exact == true and found.portfolio == "warriorOverpoweringRage"
        and type(found.learned) == "boolean"
        and found.passiveSpellId == owner.PASSIVE_ID
        and found.hasteSpellId == owner.HASTE_ID
        and found.hastePercent == owner.HASTE_PERCENT
        and found.duration == owner.DURATION
end
local function roundFor(state, hand)
    local attack = state and state.playerAttack
    return attack and (hand == "off" and attack.offhandAttackRound
        or attack.attackRound) or nil
end
local function lane(round, activePercent)
    local speed, interval = finite(round and round.speed, 0.01, 20),
        finite(round and round.interval, 0.01, 20)
    if not (speed and interval and round.speedTrusted == true
        and round.verified == true and round.projectable == true) then return nil end
    local multiplier = 1 + (tonumber(activePercent) or 0) / 100
    return { exact = true, baseSpeed = speed * multiplier,
        guard = math.max(0, interval - speed), targetGuid = round.targetGuid }
end

function O:Attach(state, root)
    if not (state and valid(root)) then return false end
    local percent = root.active and root.hastePercent or nil
    state.warriorOverpoweringRage = { available = true, exact = true,
        learned = root.learned, active = root.active == true,
        remaining = root.remaining or 0, hastePercent = root.hastePercent,
        duration = root.duration, hasteSpellId = root.hasteSpellId,
        lanes = { main = lane(roundFor(state, "main"), percent),
            off = lane(roundFor(state, "off"), percent) } }
    return true
end

function O:Copy(source, target)
    local current = source and source.warriorOverpoweringRage
    if not current then target.warriorOverpoweringRage = nil; return false end
    local lanes, _, hand = {}, nil, nil
    for _, hand in ipairs({ "main", "off" }) do
        local found = current.lanes and current.lanes[hand]
        if found then lanes[hand] = { exact = found.exact,
            baseSpeed = found.baseSpeed, guard = found.guard,
            targetGuid = found.targetGuid } end
    end
    target.warriorOverpoweringRage = { available = current.available,
        exact = current.exact, learned = current.learned,
        active = current.active, remaining = current.remaining,
        hastePercent = current.hastePercent, duration = current.duration,
        hasteSpellId = current.hasteSpellId, lanes = lanes }
    return true
end

function O:Apply(state, candidate)
    local current = state and state.warriorOverpoweringRage
    local facts = candidate and candidate.action and candidate.action.facts or {}
    local evidence = candidate and candidate.tooltip
        and candidate.tooltip.warriorOverpoweringRageEvidence
        or facts.warriorOverpoweringRageEvidence
    if not (current and current.available == true and current.exact == true
        and current.learned == true and valid(evidence)
        and evidence.learned == true and facts.warriorOverpower == true
        and tonumber(candidate.effectDelivery) >= 0.999999) then return false end
    current.active, current.remaining = true, current.duration
    return true
end

function O:Advance(state, elapsed)
    local current = state and state.warriorOverpoweringRage
    elapsed = finite(elapsed, 0, 3600)
    if not (current and current.exact == true and current.active == true
        and elapsed) then return false end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= 0 then current.active = false end
    return true
end

function O:IntervalAfter(state, hand, swingOffset, fallback)
    local current = state and state.warriorOverpoweringRage
    local found = current and current.lanes and current.lanes[hand]
    if not (current and current.exact == true and current.learned == true
        and found and found.exact == true
        and finite(found.baseSpeed, 0.01, 20)
        and finite(found.guard, 0, 20)) then return fallback end
    local active = current.active == true
        and (tonumber(current.remaining) or 0)
            > math.max(0, tonumber(swingOffset) or 0) + 0.000001
    local percent = active and current.hastePercent or 0
    return found.baseSpeed / (1 + percent / 100) + found.guard
end
