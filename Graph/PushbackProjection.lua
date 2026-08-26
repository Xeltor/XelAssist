-- Expected normal-cast extension from phase-known hostile white rounds and a
-- character's observed Octo pushback delays. This changes time, never spell
-- power, and deliberately excludes channels and exact immunity windows.
XelAssist.Graph.PushbackProjection = {}
local P = XelAssist.Graph.PushbackProjection

P.MAX_EVENTS = 8

local function immune(state)
    local barkskin = state and state.druidBarkskin
    return type(barkskin) == "table" and barkskin.available == true
        and barkskin.exact == true and barkskin.active == true
        and tonumber(barkskin.remaining) and barkskin.remaining > 0
        and barkskin.pushbackImmune == true
end

local function events(context, upper)
    local out, lanes = {}, context.state.hostileSwings
        and context.state.hostileSwings.lanes or {}
    local i
    for i = 1, table.getn(lanes) do
        local lane = lanes[i]
        local interval = tonumber(lane.interval)
        local at = tonumber(lane.nextSwingIn)
        local probability = tonumber(lane.damageProbability)
        if lane.phaseKnown == true and lane.victimKind == "player"
            and interval and interval > 0.1 and at and at > 0
            and probability and probability > 0 and probability <= 1
            and (tonumber(lane.expectedDamage) or 0) > 0 then
            local count = 0
            while at <= upper and count < P.MAX_EVENTS do
                table.insert(out, { at = at, probability = probability })
                at, count = at + interval, count + 1
            end
        end
    end
    table.sort(out, function(left, right) return left.at < right.at end)
    return out
end

function P:Adjust(context)
    local profile = context and context.state and context.state.hostileSwings
        and context.state.hostileSwings.playerPushback
    local cast = context and tonumber(context.cast)
    if not (context and context.action.actor ~= "pet" and cast and cast > 0
        and not context.facts.channel and context.state.inCombat
        and type(profile) == "table" and profile.available == true
        and tonumber(profile.meanDelay) and profile.meanDelay > 0
        and not immune(context.state)) then return false end
    local wait = math.max(0, tonumber(context.wait) or 0)
    local maximum = math.max(profile.meanDelay, tonumber(profile.maximumDelay) or 0)
    local timeline = events(context, wait + cast + maximum * self.MAX_EVENTS)
    local completion, extension, used, i = wait + cast, 0, 0, nil
    for i = 1, table.getn(timeline) do
        local entry = timeline[i]
        if used >= self.MAX_EVENTS then break end
        if entry.at > wait and entry.at <= completion + 0.0001 then
            local delay = profile.meanDelay * entry.probability
            extension, completion, used = extension + delay,
                completion + delay, used + 1
        end
    end
    if extension <= 0 then return false end
    context.cast = cast + extension
    context.occupancy = math.max(context.occupancy or 0, context.cast)
    context.downtime = math.max(context.downtime or 0, context.cast)
    context.advanceDowntime = wait + context.occupancy
    context.pushbackProjection = { estimated = true, extension = extension,
        events = used, baseCast = cast, projectedCast = context.cast,
        samples = profile.samples, meanDelay = profile.meanDelay,
        source = "observed delay envelope and phase-known hostile rounds" }
    context.estimated = true
    return true
end
