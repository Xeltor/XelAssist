-- One causal player melee clock. Main- and off-hand phases are independently
-- observed, but a resolved hand delays the other's near-simultaneous round by
-- the server display guard. Keeping that rule here prevents double damage,
-- rage and threat when the two exact clocks converge.
XelAssist.Graph.PlayerSwingTimeline = {}
local T = XelAssist.Graph.PlayerSwingTimeline
local Main = XelAssist.Graph.PlayerSwings
local Offhand = XelAssist.Graph.PlayerOffhandSwings

local CROSS_HAND_DELAY = 0.20
local READY_DELAY = 0.05
local EPSILON = 0.000001

local function append(into, values)
    local i
    for i = 1, table.getn(values or {}) do
        table.insert(into, values[i])
    end
end

local function split(values, kind)
    local swings, other, i = {}, {}, nil
    for i = 1, table.getn(values or {}) do
        local entry = values[i]
        if entry.kind == kind then table.insert(swings, entry)
        else table.insert(other, entry) end
    end
    return swings, other
end

local function lane(round, values, kind, hand)
    local swings, other = split(values, kind)
    return { hand = hand, round = round, swings = swings, other = other,
        index = 1, shift = 0 }
end

local function futureDue(item, window)
    local entry = item.swings[item.index]
    if entry then return (tonumber(entry.offset) or 0) + item.shift end
    local round = item.round
    if not (round and round.projectable == true
        and round.readyHeld ~= true
        and tonumber(round.nextSwingIn)) then return nil end
    return window + math.max(0, tonumber(round.nextSwingIn)) + item.shift
end

local function selected(main, mainDue, offhand, offhandDue)
    if mainDue == nil then return offhand, offhandDue, main end
    if offhandDue == nil or mainDue <= offhandDue then
        return main, mainDue, offhand
    end
    return offhand, offhandDue, main
end

local function adjustOther(other, otherDue, firedAt)
    if otherDue == nil then return end
    local minimum = firedAt + CROSS_HAND_DELAY
    if otherDue < minimum - EPSILON then
        other.shift = other.shift + minimum - otherDue
    end
end

local function updateClock(item, window)
    local due = futureDue(item, window)
    if not (due and item.round and item.round.projectable == true) then return end
    item.round.nextSwingIn = math.max(READY_DELAY, due - window)
end

local function sameTarget(main, offhand)
    return main and offhand and main.targetGuid ~= nil
        and main.targetGuid == offhand.targetGuid
end

local function capDue(item)
    local i
    for i = 1, table.getn(item.other) do
        local kind = item.other[i].kind
        if kind == "playerSwingTimelineCap"
            or kind == "playerOffhandTimelineCap" then
            return (tonumber(item.other[i].offset) or 0) + item.shift
        end
    end
    return nil
end

local function nextCap(main, offhand)
    local left, right = capDue(main), capDue(offhand)
    if left == nil then return right end
    if right == nil then return left end
    return math.min(left, right)
end

local function appendNonCaps(out, item)
    local i
    for i = 1, table.getn(item.other) do
        local entry = item.other[i]
        if entry.kind ~= "playerSwingTimelineCap"
            and entry.kind ~= "playerOffhandTimelineCap" then
            table.insert(out, entry)
        end
    end
end

function T:Events(state, candidate)
    local attack = state and state.playerAttack
    local mainRound, offhandRound = attack and attack.attackRound,
        attack and attack.offhandAttackRound
    local mainWasProjectable = mainRound and mainRound.projectable == true
    local offhandWasProjectable = offhandRound
        and offhandRound.projectable == true
    local mainValues = Main and Main:Events(state, candidate) or {}
    local offhandValues = Offhand and Offhand:Events(state, candidate) or {}
    if not (Main and Offhand) then
        append(mainValues, offhandValues)
        return mainValues
    end
    local main = lane(mainRound, mainValues,
        "playerMainSwing", "main")
    local offhand = lane(offhandRound, offhandValues,
        "playerOffhandSwing", "off")
    local hasDue = table.getn(main.swings) > 0
        or table.getn(offhand.swings) > 0
    if not hasDue or not sameTarget(main.round, offhand.round)
        or not mainWasProjectable or not offhandWasProjectable then
        append(mainValues, offhandValues)
        return mainValues
    end

    local out, window = {}, math.max(0,
        tonumber(candidate and candidate.downtime) or 0)
    while true do
        local mainDue, offhandDue = futureDue(main, window),
            futureDue(offhand, window)
        local chosen, due, other = selected(
            main, mainDue, offhand, offhandDue)
        local cap = nextCap(main, offhand)
        if due == nil or due > window + EPSILON
            or cap and due >= cap - EPSILON then break end
        local entry = chosen.swings[chosen.index]
        if not entry then break end
        entry.offset = due
        entry.applicationAt = (tonumber(state.time) or 0) + due
        table.insert(out, entry)
        chosen.index = chosen.index + 1
        adjustOther(other, futureDue(other, window), due)
    end
    local cap = nextCap(main, offhand)
    if cap and cap <= window + EPSILON then
        main.round.projectable, main.round.phaseKnown = false, false
        offhand.round.projectable, offhand.round.phaseKnown = false, false
        table.insert(out, { owner = "ongoing",
            kind = "playerSwingTimelineCap", priority = 55,
            offset = cap, windowEnd = window, combined = true,
            applicationAt = (tonumber(state.time) or 0) + cap })
    else
        updateClock(main, window)
        updateClock(offhand, window)
    end
    appendNonCaps(out, main)
    appendNonCaps(out, offhand)
    return out
end

function T:Delay()
    return CROSS_HAND_DELAY
end
