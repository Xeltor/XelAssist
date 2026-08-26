-- Pure graph consequence for a freshly projected solo Mana Spring Totem.
-- Placement has no flat utility: later exact mana ticks must make a subsequent
-- mana-funded action possible.  Existing live totems have unknown pulse phase
-- and are intentionally not reconstructed here.
XelAssist.Graph.ShamanManaSpring = {}
local M = XelAssist.Graph.ShamanManaSpring

M.CONSUMER_KEY = "shamanManaSpring:manaSpend"

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        if type(value) == "table" then out[key] = copy(value)
        else out[key] = value end
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.ShamanManaSpring
end

local function exactEffect(value, evidence)
    local amount = value and finite(value.baseAmount, 0.0001, 1000000)
    local period = value and finite(value.period, 0.001, 3600)
    return evidence and type(value) == "table" and value.exact == true
        and value.kind == "playerPeriodicManaEnergize"
        and value.auraSpellId == evidence.auraSpellId
        and amount == evidence.baseAmount and period == evidence.basePeriod
        and value.powerType == evidence.powerType
        and value.zeroThreat == true and value.phase == "freshPlacement"
        and value or nil
end

local function exactContract(value, evidence)
    local amount = value and finite(value.amount, 0.0001, 1000000)
    local period = value and finite(value.period, 0.001, 3600)
    local amountFlat = value and finite(value.amountFlat, -1000000, 1000000)
    local amountPercent = value
        and finite(value.amountPercent, -1000000, 1000000)
    local periodFlat = value and finite(value.periodFlat, -3600000, 3600000)
    local periodPercent = value
        and finite(value.periodPercent, -1000000, 1000000)
    local recomputedAmount = amountFlat and amountPercent
        and (evidence.baseAmount + amountFlat)
            * (100 + amountPercent) / 100 or nil
    local recomputedPeriod = periodFlat and periodPercent
        and math.floor((evidence.basePeriod * 1000 + periodFlat)
            * (100 + periodPercent) / 100) / 1000 or nil
    return evidence and type(value) == "table" and value.valid == true
        and value.exact == true and value.deterministic == true
        and value.spellId == evidence.spellId
        and value.auraSpellId == evidence.auraSpellId
        and value.powerType == evidence.powerType
        and value.zeroThreat == true and amount and math.floor(amount) == amount
        and amount == recomputedAmount and period == recomputedPeriod
        and period and value or nil
end

local function component(state)
    local value = state and state.shamanManaSpring
    return value and value.available == true and value.exact == true
        and value.solo == true and value.grouped == false and value or nil
end

local function waterRow(state)
    local owner = runtime()
    local snapshot = state and state.totems
    local row = owner and snapshot and snapshot.bySlot
        and snapshot.bySlot[owner.SLOT]
    return snapshot and snapshot.available == true and row
        and row.exact == true and row.slot == owner.SLOT
        and row.element == owner.ELEMENT and row or nil
end

function M:Attach(state)
    if type(state) ~= "table" then return false end
    local owner = runtime()
    local observed = owner and owner:ObserveRoot() or nil
    state.shamanManaSpring = observed and copy(observed) or {
        available = false, exact = false,
        reason = "Mana Spring root evidence unavailable" }
    return observed and observed.available == true and observed.exact == true
        or false
end

function M:Copy(source, target)
    if not (source and target and source.shamanManaSpring) then return false end
    target.shamanManaSpring = copy(source.shamanManaSpring)
    return true
end

local function projectionEvidence(projection)
    local owner = runtime()
    local action = projection and projection.action
    local evidence = owner and owner:Evidence(action) or nil
    local effect = exactEffect(projection and projection.effect, evidence)
    local facts = action and action.facts or {}
    local contract = exactContract(facts.shamanManaSpringContract, evidence)
    if not (evidence and effect and contract
        and projection.kind == "totemPlacement"
        and projection.slot == owner.SLOT
        and projection.element == owner.ELEMENT
        and projection.downstreamSpellId == evidence.spellId
        and projection.downstreamElement == owner.ELEMENT
        and projection.range and projection.range.exact == true
        and projection.range.center == "totem"
        and projection.range.minimum == 0
        and projection.range.maximum == evidence.radius
        and projection.recipients and projection.recipients.exact == true
        and projection.recipients.center == "totem"
        and projection.recipients.relation == "party"
        and projection.recipients.shape == "area"
        and projection.recipients.graphScope == "soloSelf") then
        return nil, nil, nil
    end
    return evidence, effect, contract
end

function M:Prepare(state, projection)
    local evidence, effect, contract = projectionEvidence(projection)
    if not evidence then
        local action = projection and projection.action
        local claimed = runtime() and runtime():Evidence(action)
        if not claimed then return nil, nil, false end
        local facts = action and action.facts or {}
        return nil, facts.shamanManaSpringContract
            and facts.shamanManaSpringContract.reason
            or "Mana Spring captured consequence unavailable", true
    end
    local root = component(state)
    if not root then
        local observed = state and state.shamanManaSpring
        return nil, observed and observed.reason
            or "Mana Spring solo recipient evidence unavailable", true
    end
    projection.shamanManaSpring = { exact = true,
        evidence = copy(evidence), effect = copy(effect),
        contract = copy(contract), rangeExact = true }
    return projection, nil, true
end

function M:Score(context, projection)
    local prepared, reason, handled = self:Prepare(
        context and context.state, projection)
    if not handled or not prepared then return false, reason end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.reason = "starts exact periodic player mana"
    return true
end

function M:Apply(state, projection)
    local marker = projection and projection.shamanManaSpring
    local evidence = marker and marker.evidence
    local contract = exactContract(marker and marker.contract, evidence)
    local row, root = waterRow(state), component(state)
    if not (marker and marker.exact == true and contract and row and root
        and row.active == true and row.projected == true
        and row.spellId == evidence.spellId
        and exactEffect(row.effect, evidence)) then return false end
    row.manaSpring = { exact = true, projected = true,
        spellId = evidence.spellId, auraSpellId = evidence.auraSpellId,
        amount = contract.amount, period = contract.period,
        nextIn = contract.period, powerType = evidence.powerType,
        zeroThreat = true, rangeExact = true,
        source = "fresh projected solo Mana Spring Totem" }
    root.active, root.projected = true, true
    root.rangeExact, root.sourceSpellId = true, evidence.spellId
    return true
end

local function active(state)
    local owner = runtime()
    local root, row = component(state), waterRow(state)
    local spring = row and row.manaSpring
    if not (owner and root and root.active == true and root.projected == true
        and root.rangeExact == true and row.active == true
        and row.projected == true and row.spellId == root.sourceSpellId
        and spring and spring.exact == true and spring.projected == true
        and spring.rangeExact == true and spring.spellId == row.spellId
        and spring.powerType == owner.MANA and spring.zeroThreat == true) then
        return nil
    end
    local amount = finite(spring.amount, 0.0001, 1000000)
    local period = finite(spring.period, 0.001, 3600)
    local nextIn = finite(spring.nextIn, 0, period or 0)
    if not amount or math.floor(amount) ~= amount or not period
        or nextIn == nil then return nil end
    return row, spring, amount, period, nextIn
end

local function syncPlayer(state)
    local player = state.actors and state.actors.player
    if player then player.resource = state.resource end
    local friendlies = state.friendlies
    if friendlies and type(friendlies.player) == "table" then
        friendlies.player.resource = state.resource
    end
    local key = friendlies and friendlies.byUnit and friendlies.byUnit.player
    local record = key ~= nil and friendlies.byKey and friendlies.byKey[key]
    if record then record.resource = state.resource end
end

local function closePassiveAtCap(state)
    local clock = state.playerResourceClock
    if not clock then return end
    clock.phaseKnown, clock.nextIn = false, nil
    clock.pendingSpendSpellId = nil
    clock.phaseSource = "projected Mana Spring cap erased passive mana phase"
end

-- Must run before TotemState:Advance so the final tick at exact expiration is
-- retained, matching the server's final Creature::Update before unsummon.
function M:Advance(state, elapsed)
    local row, spring, amount, period, nextIn = active(state)
    elapsed = finite(elapsed, 0, 1000000)
    local current = finite(state and state.resource, 0, 1000000000)
    local maximum = finite(state and state.resourceMax, 0, 1000000000)
    local remaining = row and finite(row.remaining, 0, 1000000)
    if not (row and elapsed and elapsed > 0 and current and maximum
        and current <= maximum and remaining and remaining > 0
        and state.playerResourceExact == true
        and tonumber(state.resourceType) == spring.powerType) then return 0 end
    local window = math.min(elapsed, remaining)
    if window < nextIn then
        spring.nextIn = nextIn - window
        return 0
    end
    local ticks = 1 + math.floor((window - nextIn) / period)
    local afterFirst = window - nextIn
    local residual = afterFirst - (ticks - 1) * period
    if elapsed < remaining then spring.nextIn = period - residual end
    local prior = current
    state.resource = math.min(maximum, current + ticks * amount)
    syncPlayer(state)
    if state.resource >= maximum then closePassiveAtCap(state) end
    return state.resource - prior
end

local function playerMovement(candidate)
    local action = candidate and candidate.action
    local facts = action and action.facts or {}
    return action and (action.actor or "player") == "player"
        and (facts.movementSetup == true or facts.chargeMovement == true
            or facts.movesSourceToTarget == true or facts.kind == "movement")
end

-- Call after applying the chosen action. Its remaining timeline then sees the
-- conservative out-of-range state; no distance from a stationary totem is
-- fabricated.
function M:AfterCandidate(state, candidate)
    if not playerMovement(candidate) then return false end
    local root, row = state and state.shamanManaSpring, waterRow(state)
    if root then root.rangeExact = false end
    if row and row.manaSpring then row.manaSpring.rangeExact = false end
    return root ~= nil or row ~= nil
end

function M:ConsumerKey(facts)
    local cost = facts and finite(facts.cost, 0.0001, 1000000000)
    return facts and facts.shamanManaSpring ~= true
        and tonumber(facts.powerType) == 0 and cost and self.CONSUMER_KEY or nil
end

function M:AdjustConsumer(context)
    local key = self:ConsumerKey(context and context.tooltip)
        or self:ConsumerKey(context and context.facts)
    if not key then return false end
    context.setupConsumerKey = key
    return true
end

function M:StrategicSetup(tooltip)
    local owner = runtime()
    local evidence = owner and owner:Evidence(tooltip)
    local contract = evidence
        and exactContract(tooltip.shamanManaSpringContract, evidence)
    if not contract then return nil end
    return { key = "shamanManaSpring:" .. tostring(evidence.spellId),
        consumerKey = self.CONSUMER_KEY }
end
