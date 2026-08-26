-- Branch-local Dark Pact consequence.  Equal mana is moved from the active
-- demon to the player; no rotation value is assigned.  ResourceInvestment
-- keeps the edge only when a later player action proves the transfer useful.
XelAssist.Graph.WarlockDarkPact = {}
local D = XelAssist.Graph.WarlockDarkPact
local State = XelAssist.Graph.State

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
end

local function facts(action)
    return action and action.facts or {}
end

function D:Is(action)
    local found = facts(action)
    return found.warlockDarkPact == true
        and found.petManaConversion == true
end

local function transfer(action, tooltip)
    if not (D:Is(action) and tooltip
        and tooltip.warlockDarkPactTransferExact == true) then return nil end
    local amount = finite(tooltip.warlockDarkPactTransfer, 0.0001, 10000000)
    return amount
end

local function actorState(state)
    local pet = state and state.actors and state.actors.pet
    if not (pet and pet.ownerClass == "WARLOCK" and not pet.dead
        and finite(pet.health, 0, 1000000000)
        and finite(pet.healthMax, 0.0001, 1000000000)
        and pet.health > 0 and pet.resourceExact ~= false) then return nil end
    local resource = finite(pet.resource, 0, 10000000)
    local maximum = finite(pet.resourceMax, 0.0001, 10000000)
    if not resource or not maximum or resource > maximum then return nil end
    return pet, resource, maximum
end

function D:Projection(action, state, tooltip)
    local amount = transfer(action, tooltip)
    local pet, petMana = actorState(state)
    local playerMana = finite(state and state.resource, 0, 10000000)
    local playerMax = finite(state and state.resourceMax, 0.0001, 10000000)
    if tonumber(state and state.resourceType) ~= 0
        or state.playerResourceExact ~= true
        or not amount or not pet or not playerMana or not playerMax
        or playerMana > playerMax then return nil end
    local drained = math.min(amount, petMana)
    local missing = math.max(0, playerMax - playerMana)
    return { amount = amount, drained = drained,
        gained = math.min(drained, missing), wasted = math.max(0, drained - missing),
        playerBefore = playerMana, playerMaximum = playerMax,
        petBefore = petMana, petMaximum = pet.resourceMax }
end

function D:Blocker(action, state, descriptor, tooltip)
    if not self:Is(action) then return nil, false end
    if not (descriptor and descriptor.unit == "player"
        and descriptor.relation ~= "hostile") then
        return "Dark Pact requires the player", true
    end
    if tonumber(state and state.resourceType) ~= 0
        or state.playerResourceExact ~= true then
        return "player mana evidence unavailable", true
    end
    local pet = actorState(state)
    if not pet then return "controlled demon mana evidence unavailable", true end
    local projection = self:Projection(action, state, tooltip)
    if not projection then return tooltip and tooltip.warlockDarkPactCaptureReason
        or "Dark Pact transfer evidence unavailable", true end
    if projection.drained <= 0 then return "controlled demon has no mana", true end
    if projection.gained <= 0 then return "player mana already full", true end
    return nil, true, projection
end

function D:Score(context)
    if not (context and self:Is(context.action)) then return false end
    local projection = self:Projection(
        context.action, context.state, context.tooltip)
    if not projection or projection.gained <= 0 then return false end
    context.power, context.expectedPower, context.effectivePower =
        projection.drained, projection.drained, projection.gained
    context.resourceGain = projection.gained
    context.resourceGainSource = context.tooltip.warlockDarkPactTransferSource
    context.petResourceSpent = projection.drained
    context.resourceTransfer = projection
    -- Equal player/pet mana is recommendation-neutral. Only cap waste is an
    -- immediate loss; future player and demon actions price the two pools.
    context.value = -projection.wasted
    context.estimated = false
    context.reason = projection.wasted > 0
        and "avoids wasting controlled demon mana at the player cap"
        or "moves controlled demon mana to the player"
    return true
end

local function closeCapPhase(state)
    local clock = state.playerResourceClock
    if not clock then return end
    clock.phaseKnown, clock.nextIn = false, nil
    clock.phaseSource = "projected Dark Pact cap erased passive mana phase"
    clock.pendingSpendSpellId = nil
end

function D:Apply(state, candidate)
    local action = candidate and candidate.action
    if not self:Is(action) then return false end
    local projection = self:Projection(action, state, candidate.tooltip)
    if not projection or projection.drained <= 0 or projection.gained <= 0 then
        return false
    end
    local pet = state.actors.pet
    pet.resource = math.max(0, projection.petBefore - projection.drained)
    state.resource = math.min(projection.playerMaximum,
        projection.playerBefore + projection.gained)
    local player = state.actors and state.actors.player
    if player then player.resource = state.resource end
    local friendly = State and State.FriendlyByUnit
        and State:FriendlyByUnit(state, "player") or nil
    if friendly and friendly.resource ~= nil then friendly.resource = state.resource end
    if state.resource >= projection.playerMaximum then closeCapPhase(state) end
    return true
end
