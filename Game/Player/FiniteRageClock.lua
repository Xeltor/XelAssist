-- Shared search-pure clock for finite, spell-owned rage streams. Action
-- modules create sealed clocks; this module advances them without knowing why
-- a Warrior or Druid chose the action.
XelAssist.Game.Player.FiniteRageClock = {}
local F = XelAssist.Game.Player.FiniteRageClock

F.KINDS = {
    warriorBloodrage = { spellId = 2687, auraSpellId = 29131,
        duration = 10, maximumTicks = 10 },
    druidEnrage = { spellId = 5229, duration = 10, maximumTicks = 10 },
}

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end
local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function F:ClockFor(state)
    local clock = state and state.playerResourceClock
    local profile = clock and self.KINDS[clock.kind]
    if tonumber(state and state.resourceType) ~= 1
        or not (profile and clock.verified == true and clock.active == true
            and tonumber(clock.resourceType) == 1
            and clock.spellId == profile.spellId
            and (not profile.auraSpellId
                or clock.auraSpellId == profile.auraSpellId)) then return nil end
    local amount = finite(clock.amount, 0.000001, 100)
    local interval = finite(clock.interval, 0.000001, 60)
    local nextIn = finite(clock.nextIn, 0, interval or 0)
    local remaining = finite(clock.remaining, 0, profile.duration + 0.25)
    local ticks = integer(clock.ticksRemaining, 0, profile.maximumTicks)
    if not (amount and interval and nextIn and remaining and ticks) then return nil end
    return clock, amount, interval, nextIn, remaining, ticks
end

function F:Active(state)
    return self:ClockFor(state) ~= nil
end

local function sync(state)
    local actor = state.actors and state.actors.player
    if actor then actor.resource = state.resource end
end

function F:Advance(state, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    local clock, amount, interval, nextIn, remaining, ticks =
        self:ClockFor(state)
    if elapsed <= 0 or not clock then return 0 end
    local due = 0
    if ticks > 0 and elapsed >= nextIn then
        due = 1 + math.floor((elapsed - nextIn) / interval)
        due = math.min(ticks, due)
    end
    clock.remaining = math.max(0, remaining - elapsed)
    clock.ticksRemaining = ticks - due
    if due > 0 then
        local afterFirst = elapsed - nextIn
        local residual = afterFirst
            - math.floor(afterFirst / interval) * interval
        clock.nextIn = interval - residual
    else clock.nextIn = math.max(0, nextIn - elapsed) end
    local prior = tonumber(state.resource) or 0
    local maximum = math.max(prior, tonumber(state.resourceMax) or prior)
    state.resource = math.min(maximum, prior + due * amount)
    sync(state)
    if due > 0 then
        state.playerResourceProjected = true
        state.playerRageProjection = { exact = clock.exact == true,
            lowerBound = clock.lowerBound == true,
            gained = state.resource - prior, source = clock.source }
    end
    if clock.remaining <= 0 or clock.ticksRemaining <= 0 then
        state.playerResourceClock = nil
    end
    return state.resource - prior
end

local function probe(owner, state, at)
    local out = { time = state.time, resource = tonumber(state.resource),
        resourceMax = tonumber(state.resourceMax),
        resourceType = state.resourceType,
        playerResourceReserved = tonumber(state.playerResourceReserved) or 0,
        playerResourceClock = copy(state.playerResourceClock), actors = {} }
    owner:Advance(out, math.max(0, (tonumber(at) or 0)
        - (tonumber(state.time) or 0)))
    return out
end

function F:ResourceAt(state, at)
    local out = probe(self, state, at)
    return out.resource and out.resource - out.playerResourceReserved or nil
end

function F:Earliest(state, cost, readyAt)
    cost, readyAt = math.max(0, tonumber(cost) or 0),
        math.max(tonumber(state.time) or 0, tonumber(readyAt) or 0)
    local out = probe(self, state, readyAt)
    local available = (tonumber(out.resource) or 0)
        - out.playerResourceReserved
    if available >= cost then return readyAt end
    if (tonumber(out.resourceMax) or 0) - out.playerResourceReserved < cost then
        return nil
    end
    local _, amount, interval, nextIn, _, ticks = self:ClockFor(out)
    if not amount then return nil end
    local needed = math.ceil((cost - available) / amount)
    if needed > ticks then return nil end
    return readyAt + nextIn + math.max(0, needed - 1) * interval
end
