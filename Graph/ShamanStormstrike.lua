-- Search-pure two-charge Stormstrike Nature amplifier. Branches hold a
-- probability distribution because the applying melee strike and consuming
-- direct Nature hits can miss. Periodic/ambient consumption is not invented.
XelAssist.Graph.ShamanStormstrike = {}
local S = XelAssist.Graph.ShamanStormstrike
local function length(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function owner() return XelAssist.Game.Player.ShamanStormstrike end
local function clamp(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(0, math.min(1, value))
end
local function copy(value, depth)
    if type(value) ~= "table" or depth <= 0 then return value end
    local out, key, entry = {}, nil, nil
    for key, entry in pairs(value) do out[key] = copy(entry, depth - 1) end
    return out
end
local function sync(found)
    found.p0, found.p1, found.p2 = 0, 0, 0
    local index, lane
    for index = 1, length(found.lanes) do
        lane = found.lanes[index]
        if lane.charges == 0 or (tonumber(lane.remaining) or 0) <= 0 then
            found.p0 = found.p0 + lane.probability
        elseif lane.charges == 1 then found.p1 = found.p1 + lane.probability
        elseif lane.charges == 2 then found.p2 = found.p2 + lane.probability end
    end
end
local function validLanes(found)
    local total, index, lane = 0, nil, nil
    if type(found and found.lanes) ~= "table" then return false end
    for index = 1, length(found.lanes) do
        lane = found.lanes[index]
        if not (clamp(lane.probability) and (lane.charges == 0
            or lane.charges == 1 or lane.charges == 2)
            and tonumber(lane.remaining) and lane.remaining >= 0
            and lane.remaining <= 12) then return false end
        total = total + lane.probability
    end
    return math.abs(total - 1) <= 0.00001
end
local function exact(state)
    local found, runtime = state and state.shamanStormstrike, owner()
    local profile = found and found.profile
    if not (runtime and found and found.available == true and found.exact == true
        and profile and profile.valid == true and profile.exact == true
        and profile.spellId == runtime.SPELL_ID
        and profile.auraSpellId == runtime.AURA_ID
        and profile.charges == 2 and profile.duration == 12
        and profile.schoolMask == 8 and profile.damageTakenMultiplier == 1.25
        and validLanes(found)
        and clamp(found.p0) and clamp(found.p1) and clamp(found.p2)) then return nil end
    local total = found.p0 + found.p1 + found.p2
    return math.abs(total - 1) <= 0.00001 and found or nil
end

function S:Attach(state, snapshot)
    if type(state) ~= "table" or type(snapshot) ~= "table" then return false end
    local found = copy(snapshot, 4)
    if found.available == true and found.exact == true then
        if found.active == true and (found.charges == 1 or found.charges == 2) then
            found.lanes = {{ probability = 1, charges = found.charges,
                remaining = tonumber(found.remaining) or 0 }}
        elseif found.active == false and found.charges == 0 then
            found.lanes = {{ probability = 1, charges = 0, remaining = 0 }}
        end
        sync(found)
    end
    state.shamanStormstrike = found
    return exact(state) ~= nil
end
function S:Copy(source, target)
    if not (source and target) then return false end
    target.shamanStormstrike = copy(source.shamanStormstrike, 4)
    return target.shamanStormstrike ~= nil
end
function S:Is(action, tooltip)
    local runtime = owner()
    return runtime and (runtime:Evidence(tooltip) or runtime:Evidence(action)) ~= nil
end

-- Applying Stormstrike lands with the already projected direct-hit delivery.
-- On failure an existing aura remains; on success it is refreshed to 2 charges.
function S:Apply(state, candidate)
    local found = exact(state)
    local delivery = clamp(candidate and (candidate.effectDelivery
        or candidate.resistance and candidate.resistance.landChance))
    if not (found and self:Is(candidate and candidate.action,
        candidate and candidate.tooltip) and delivery) then return false end
    local lanes, index, lane = {}, nil, nil
    for index = 1, length(found.lanes) do
        lane = copy(found.lanes[index], 2)
        lane.probability = lane.probability * (1 - delivery)
        if lane.probability > 0 then table.insert(lanes, lane) end
    end
    if delivery > 0 then table.insert(lanes, { probability = delivery,
        charges = 2, remaining = owner().DURATION }) end
    found.lanes, found.projected = lanes, true
    sync(found)
    found.periodicConsumptionUnknown = true
    found.source = "projected Stormstrike hit distribution"
    return true
end

function S:Eligible(action, tooltip)
    local facts = tooltip or action and action.facts or {}
    if not (action and (action.actor == nil or action.actor == "player")
        and (facts.kind == "damage" or facts.kind == "builder")
        and (tonumber(facts.schoolMask) == owner().NATURE_MASK
            or (facts.schoolMask == nil and tonumber(facts.school) == 3))) then
        return false
    end
    -- Never consume or amplify periodic, channel-tick, pet, reflected, or
    -- ambient packets without a verified Octo proc event contract.
    return facts.periodic ~= true and facts.damagePhase ~= "periodic"
        and facts.channel ~= true and facts.ambient ~= true
end

function S:PrepareDamage(state, action, tooltip, elapsed)
    local found = exact(state)
    if not (found and self:Eligible(action, tooltip)) then return 1, nil, false end
    elapsed = math.max(0, tonumber(elapsed) or 0)
    local activeProbability, index, lane = 0, nil, nil
    for index = 1, length(found.lanes) do
        lane = found.lanes[index]
        if lane.charges > 0 and lane.remaining > elapsed then
            activeProbability = activeProbability + lane.probability
        end
    end
    return 1 + owner().AMPLIFIER * activeProbability,
        { exact = true, activeProbability = activeProbability,
            epoch = found.epoch, auraSpellId = owner().AURA_ID,
            source = "projected Stormstrike Nature charge distribution" }, true
end

-- Scoring hook after resistance/delivery has produced expectedPower. It
-- adjusts only the direct Nature packet and seals its consumption marker.
function S:Adjust(context)
    local multiplier, marker, handled = self:PrepareDamage(
        context and context.state, context and context.action,
        context and context.tooltip, context and (context.impactDelay
            or (tonumber(context.wait) or 0) + (tonumber(context.cast) or 0)))
    if not handled then return false, nil end
    local base = tonumber(context and context.expectedPower)
    if not base or base < 0 then
        return false, "Stormstrike Nature base damage unavailable"
    end
    context.shamanStormstrikeExpectedDamage = base * (multiplier - 1)
    context.expectedPower = base * multiplier
    context.shamanStormstrikeConsumption = marker
    return true, nil
end

-- A direct Nature packet consumes one charge only when its delivery succeeds.
function S:Consume(state, candidate)
    local found = exact(state)
    local marker = candidate and candidate.shamanStormstrikeConsumption
        or candidate and candidate.tooltip
            and candidate.tooltip.shamanStormstrikeConsumption
    local delivery = clamp(candidate and (candidate.effectDelivery
        or candidate.resistance and candidate.resistance.landChance))
    if not (found and marker and marker.exact == true and delivery
        and marker.auraSpellId == owner().AURA_ID
        and marker.activeProbability == found.p1 + found.p2) then return false end
    local lanes, index, lane = {}, nil, nil
    for index = 1, length(found.lanes) do
        lane = found.lanes[index]
        if lane.charges > 0 and delivery > 0 then
            table.insert(lanes, { probability = lane.probability * delivery,
                charges = lane.charges - 1, remaining = lane.remaining })
        end
        if delivery < 1 or lane.charges == 0 then
            table.insert(lanes, { probability = lane.probability
                * (lane.charges > 0 and (1 - delivery) or 1),
                charges = lane.charges, remaining = lane.remaining })
        end
    end
    found.lanes = lanes; sync(found)
    found.source = "projected direct Nature Stormstrike charge consumption"
    return true
end

function S:Advance(state, elapsed)
    local found = exact(state)
    elapsed = tonumber(elapsed)
    if not (found and elapsed and elapsed >= 0) then return false end
    local index, lane, expired = nil, nil, false
    for index = 1, length(found.lanes) do
        lane = found.lanes[index]
        lane.remaining = math.max(0, lane.remaining - elapsed)
        if lane.remaining == 0 and lane.charges > 0 then
            lane.charges, expired = 0, true
        end
    end
    sync(found)
    if expired then found.source = "projected Stormstrike aura expiry" end
    return true
end
