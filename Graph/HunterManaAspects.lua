-- Search-pure Aspect of the Viper mana clock. An observed existing aura uses
-- one full period as a conservative next-tick bound; a projected fresh cast
-- starts the exact installed five-second phase. Snake procs are not projected.
XelAssist.Graph.HunterManaAspects = {}
local H = XelAssist.Graph.HunterManaAspects
local Runtime = XelAssist.Game.Player.HunterManaAspects
local Aspects = XelAssist.Graph.HunterAspects

H.CONSUMER_KEY = "hunterViper:manaSpend"

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function active(state)
    local found = state and state.hunterManaAspect
    return found and found.exact == true and found.active == true
        and found.spellId == Runtime.VIPER_ID and found.period == 5
        and found.maximumManaPercent == 5 and found.nextIn
        and found.nextIn > 0 and found.nextIn <= found.period and found or nil
end
local function sync(state)
    local actor = state.actors and state.actors.player
    if actor then actor.resource = state.resource end
    local friends = state.friendlies
    if friends and type(friends.player) == "table" then
        friends.player.resource = state.resource
    end
    local key = friends and friends.byUnit and friends.byUnit.player
    local record = key ~= nil and friends.byKey and friends.byKey[key]
    if record then record.resource = state.resource end
end

function H:Attach(state)
    if not state then return false end
    state.hunterManaAspect = nil
    local name, exact
    if Aspects then name, exact = Aspects:Current(state) end
    if not exact or name ~= "Aspect of the Viper" then return exact == true end
    state.hunterManaAspect = { exact = true, active = true,
        spellId = Runtime.VIPER_ID, period = 5, nextIn = 5,
        maximumManaPercent = 5, phase = "conservative-observed-bound",
        source = "observed exact Viper aura; next tick bounded by one period" }
    return true
end
function H:Copy(source, target)
    target.hunterManaAspect = source.hunterManaAspect
        and copy(source.hunterManaAspect) or nil
    return target.hunterManaAspect ~= nil
end
function H:Apply(state, action)
    if not state or not action then return false end
    local found = Runtime:Profile(action)
    if found and found.kind == "viper" then
        state.hunterManaAspect = { exact = true, active = true,
            spellId = found.spellId, period = found.period,
            nextIn = found.period, maximumManaPercent = found.maximumManaPercent,
            phase = "projected-fresh-cast", source = found.source }
        return true
    end
    state.hunterManaAspect = nil
    return found ~= nil
end
function H:Advance(state, elapsed)
    local found = active(state)
    elapsed = tonumber(elapsed)
    if not found or not elapsed or elapsed <= 0 then return 0 end
    local ticks = 0
    if elapsed >= found.nextIn then
        ticks = 1 + math.floor((elapsed - found.nextIn) / found.period)
        found.nextIn = found.period
            - ((elapsed - found.nextIn) - (ticks - 1) * found.period)
    else found.nextIn = found.nextIn - elapsed end
    local current, maximum = tonumber(state.resource), tonumber(state.resourceMax)
    if state.playerResourceExact ~= true or tonumber(state.resourceType) ~= 0
        or not current or not maximum or maximum < current then return 0 end
    local gain = ticks * maximum * found.maximumManaPercent / 100
    state.resource = math.min(maximum, current + gain)
    sync(state)
    return state.resource - current
end
function H:Earliest(state, cost, readyAt)
    if not active(state) then return nil, false end
    local now = tonumber(state.time) or 0
    readyAt = math.max(now, tonumber(readyAt) or now)
    cost = math.max(0, tonumber(cost) or 0)
    local probe = XelAssist.Game.Player.Resources:Probe(state, readyAt)
    local available = (tonumber(probe.resource) or 0)
        - (tonumber(probe.playerResourceReserved) or 0)
    if available >= cost then return readyAt, true end
    local maximum = (tonumber(probe.resourceMax) or 0)
        - (tonumber(probe.playerResourceReserved) or 0)
    if maximum < cost then return nil, true end
    local component = active(probe)
    local amount = component and probe.resourceMax
        * component.maximumManaPercent / 100 or 0
    if amount <= 0 then return nil, true end
    local ticks = math.ceil((cost - available) / amount)
    return readyAt + component.nextIn + math.max(0, ticks - 1) * component.period, true
end
function H:ConsumerKey(facts)
    local cost = facts and tonumber(facts.cost)
    return facts and facts.hunterManaAspect ~= true
        and tonumber(facts.powerType) == 0 and cost and cost > 0
        and self.CONSUMER_KEY or nil
end
function H:StrategicSetup(tooltip)
    local found = Runtime:Profile(tooltip)
    if not (found and found.kind == "viper"
        and tooltip.hunterAspectEffectRepresented == true) then return nil end
    return { key = "hunterViper:" .. tostring(found.spellId),
        consumerKey = self.CONSUMER_KEY }
end
