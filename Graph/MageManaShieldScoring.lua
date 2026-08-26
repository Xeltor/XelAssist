-- Consequence evidence for exact build-5875 Mana Shield actions. Mana Shield
-- absorbs only its installed DBC school mask, so generic all-school incoming
-- damage and aggro heuristics cannot safely value it. This module reads only
-- frozen graph state and returns scalar evidence for the shared absorb scorer.
XelAssist.Graph.MageManaShieldScoring = {}
local S = XelAssist.Graph.MageManaShieldScoring

local EPSILON = 0.0001

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.MageManaShield
end

local function incomingOwner()
    return XelAssist.Graph and XelAssist.Graph.IncomingConsequences
end

local function validGuid(guid)
    if guid == nil then return nil end
    if type(guid) == "string" and (guid == ""
        or string.find(guid, "^0+$")
        or string.find(guid, "^0[xX]0+$")) then return nil end
    return guid
end

local function exactPlayerGuid(context)
    local state = context and context.state
    local actor = state and state.actors and state.actors.player
    local actorGuid = validGuid(actor and actor.guid)
    local descriptorGuid = context and context.descriptor
        and validGuid(context.descriptor.guid)
    if context and context.target ~= "player" then return nil end
    if actorGuid ~= nil and descriptorGuid ~= nil
        and actorGuid ~= descriptorGuid then return nil end
    return descriptorGuid or actorGuid
end

local function deadCasters(state)
    local out, hostiles = {}, state and state.hostiles
    local i, key, record, guid, health
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey and hostiles.byKey[key]
        guid = record and (record.guid or key)
        health = record and finite(record.health)
        if guid ~= nil and (record.dead == true
            or record.projectedDefeated == true
            or record.healthExact == true and health and health <= 0) then
            out[guid] = true
        end
    end
    return out
end

local function inWindow(cast, within, strictlyAfter)
    local remaining = finite(cast and cast.remaining)
    if not remaining then return false end
    remaining = math.max(0, remaining)
    return remaining <= within + EPSILON
        and (strictlyAfter == nil or remaining > strictlyAfter + EPSILON)
end

local function schoolMatches(mask, school)
    school = integer(school, 0, 6)
    if school == nil then return nil end
    local bit = 2 ^ school
    return math.floor(mask / bit)
        - math.floor(mask / (bit * 2)) * 2 == 1
end

local function exactShield(context)
    local owner = runtime()
    local action = context and context.action
    if not (owner and owner.Is and owner:Is(action)) then
        return nil, nil, false
    end
    local tooltip = context.tooltip or {}
    local mask = integer(tooltip.mageManaShieldSchoolMask, 1, 127)
    if mask ~= 1 then
        return nil, "Mana Shield school evidence unavailable", true
    end
    if not owner.EffectiveCapacity then
        return nil, "Mana Shield capacity model unavailable", true
    end
    local capacity, reason = owner:EffectiveCapacity(context, context.state)
    capacity = finite(capacity)
    if capacity == nil or capacity < 0 then
        return nil, reason or "Mana Shield capacity evidence unavailable", true
    end
    local guid = exactPlayerGuid(context)
    if guid == nil then
        return nil, "Mana Shield recipient identity unavailable", true
    end
    return { owner = owner, schoolMask = mask,
        capacity = capacity, recipientGuid = guid }, nil, true
end

-- Returns immutable scalar evidence, a blocker, and whether the action was an
-- exact Mana Shield claim. Unknown-school events never fabricate absorption;
-- they only make the known physical subtotal explicitly partial.
function S:Evidence(context, within, strictlyAfter)
    local shield, reason, handled = exactShield(context)
    if not handled or not shield then return nil, reason, handled end
    within = finite(within)
    if within == nil or within < 0 then
        return nil, "Mana Shield scoring window unavailable", true
    end
    if strictlyAfter ~= nil then
        strictlyAfter = finite(strictlyAfter)
        if strictlyAfter == nil or strictlyAfter < 0 then
            return nil, "Mana Shield application timing unavailable", true
        end
    end

    local incoming = incomingOwner()
    if not (incoming and incoming.RecipientGuid
        and incoming.ExpectedAmount) then
        return nil, "incoming consequence evidence unavailable", true
    end
    local state = context.state
    local collection = state and state.hostileCasts
    if type(collection) ~= "table" or type(collection.order) ~= "table"
        or type(collection.byCaster) ~= "table" then
        return nil, "hostile cast evidence unavailable", true
    end
    local dead = deadCasters(state)
    local amount, exact, unknowns, counted = 0, true, 0, 0
    local i, cast, facts, recipient, matches, expected
    for i = 1, table.getn(collection.order or {}) do
        cast = collection.byCaster[collection.order[i]]
        if cast and inWindow(cast, within, strictlyAfter)
            and not dead[cast.casterGuid] then
            facts = cast.consequence
            recipient = facts and incoming:RecipientGuid(cast)
                or cast.targetGuid
            if recipient == shield.recipientGuid then
                if not facts then
                    exact, unknowns = false, unknowns + 1
                elseif facts.kind == "damage" then
                    matches = schoolMatches(shield.schoolMask, facts.school)
                    if matches == nil then
                        exact, unknowns = false, unknowns + 1
                    elseif matches then
                        expected = finite(incoming:ExpectedAmount(cast))
                        if expected == nil or expected < 0 then
                            exact, unknowns = false, unknowns + 1
                        else
                            amount, counted = amount + expected, counted + 1
                            if facts.estimated == true then exact = false end
                        end
                    end
                end
            end
        end
    end
    return { incoming = amount, incomingExact = exact,
        unknownIncomingEvents = unknowns, countedPhysicalEvents = counted,
        capacity = shield.capacity, schoolMask = shield.schoolMask,
        allowAggroHeuristic = false,
        source = "exact physical hostile-cast and mana-capacity evidence" },
        nil, true
end
