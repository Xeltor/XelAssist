-- Central player-owned threat scaling and attribution. Live class evidence is
-- attached to the root state once, then treated as immutable by graph branches.
-- Pet threat deliberately bypasses player stance and talent components.
XelAssist.Graph.PlayerThreat = {}
local P = XelAssist.Graph.PlayerThreat
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local DruidBearThreat = XelAssist.Graph.DruidBearThreat

local function nonNegative(value)
    value = tonumber(value)
    if not value or value < 0 then return nil end
    return value
end

local function compose(state, actor, school, multiplier, exact, profile)
    local component
    if PaladinBlessingThreat then
        multiplier, exact, component = PaladinBlessingThreat:Resolve(
            state, actor, multiplier, exact)
        profile = component or profile
    end
    if DruidBearThreat then
        multiplier, exact, component = DruidBearThreat:Resolve(
            state, actor, multiplier, exact)
        profile = component or profile
    end
    if PaladinRighteousFury then
        multiplier, exact, component = PaladinRighteousFury:Resolve(
            state, actor, school, multiplier, exact)
        profile = component or profile
    end
    return multiplier, exact, profile
end

-- Conservative graph policy for bounded live evidence: a tank must not be
-- credited with threat it may not produce, while a non-tank must not have
-- threat risk understated. Exact observations use their exact multiplier.
function P:Resolve(state, actor, school)
    if actor ~= "player" then return compose(state, actor, school, 1, true, nil) end
    local profile = state and state.playerThreat
    if profile == nil then return compose(state, actor, school, 1, true, nil) end
    if profile.actor ~= "player" or profile.playerOnly ~= true then
        return compose(state, actor, school, 1, false, profile)
    end
    local exact = profile.exact == true
        and nonNegative(profile.multiplier) or nil
    if exact then return compose(state, actor, school, exact, true, profile) end
    local minimum = nonNegative(profile.minimum)
    local maximum = nonNegative(profile.maximum)
    if minimum and maximum and maximum < minimum then
        minimum, maximum = nil, nil
    end
    local multiplier = state and state.tank and minimum or maximum
    return compose(state, actor, school, multiplier or 1, false, profile)
end

function P:Scale(state, actor, amount, school)
    local multiplier, exact, profile = self:Resolve(state, actor, school)
    return math.max(0, tonumber(amount) or 0) * multiplier,
        exact, multiplier, profile
end

local function attribute(record, actor, amount, exact)
    if not record or amount <= 0 then return amount end
    record.projectedThreat = record.projectedThreat or {}
    record.projectedThreat[actor] =
        (tonumber(record.projectedThreat[actor]) or 0) + amount
    record.threat = record.threat or {}
    local field = actor == "pet" and "petDelta" or "playerDelta"
    record.threat[field] = (tonumber(record.threat[field]) or 0) + amount
    if actor == "player" and record.threat.projectedPlayerReferenceKnown
        and record.threat.projectedPlayerReference == false then
        -- New positive player threat recreates a reference after Vanish. It
        -- does not by itself prove which actor now owns the hostile victim.
        record.threat.projectedPlayerReferenceKnown = true
        record.threat.projectedPlayerReference = true
        record.threat.projectedPlayerOwnershipUnknown = true
        record.threat.projectedPlayerHasAggro = nil
    end
    if actor == "player" and exact == false then
        record.threat.playerDeltaExact = false
        record.threat.containsBoundedPlayerThreat = true
    end
    return amount
end

function P:Add(record, state, actor, amount, school)
    local scaled, exact, multiplier, profile =
        self:Scale(state, actor, amount, school)
    attribute(record, actor, scaled, exact)
    return scaled, exact, multiplier, profile
end

function P:AddScaled(record, actor, amount, exact)
    return attribute(record, actor,
        math.max(0, tonumber(amount) or 0), exact ~= false)
end
