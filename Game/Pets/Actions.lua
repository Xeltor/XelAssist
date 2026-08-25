-- Safe graph policy for Hunter pet maintenance actions. Observation remains in
-- State.lua; this module maps explicit lifecycle evidence into legal graph
-- transitions without guessing, consuming food, or abandoning a companion.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.Actions = {}
local A = XelAssist.Game.Pets.Actions

local COPIED_FIELDS = {
    "lifecycle", "focus", "focusMax", "happiness", "damagePercentage",
    "loyaltyRate", "loyaltyText", "experience", "experienceNext",
    "trainingTotal", "trainingSpent", "trainingAvailable", "foodTypes",
    "foodTypesKnown", "attackActive", "attackActiveKnown", "targetGuid"
}

function A:MergeLive(pet, lifecycle)
    if not pet then return nil end
    if not lifecycle then return pet end
    local i, field
    for i = 1, table.getn(COPIED_FIELDS) do
        field = COPIED_FIELDS[i]
        if lifecycle[field] ~= nil then pet[field] = lifecycle[field] end
    end
    pet.petState = lifecycle
    local percentage = tonumber(lifecycle.damagePercentage)
    if percentage then
        pet.happinessDamageMultiplier = percentage > 10
            and percentage / 100 or percentage
        pet.damageMultiplier = XelAssist.Game.Pets.Effects
            and XelAssist.Game.Pets.Effects:DamageMultiplier(pet)
            or pet.happinessDamageMultiplier
    end
    if lifecycle.focus ~= nil then pet.resource = lifecycle.focus end
    if lifecycle.focusMax ~= nil then pet.resourceMax = lifecycle.focusMax end
    if XelAssist.Game.Pets.Resources then
        XelAssist.Game.Pets.Resources:Attach(pet, lifecycle)
    end
    return pet
end

function A:FixedTarget(action)
    local target = action and action.facts and action.facts.fixedTarget
    if target == "pet" then return "pet", "pet", "companion" end
    if target == "player" then return "player", "self", "self" end
    return nil, nil, nil
end

function A:ImplicitTarget(action)
    local facts = action and action.facts
    return facts and (facts.petLifecycle ~= nil or facts.fixedTarget ~= nil)
        and true or false
end

local function lifecycle(state)
    return state and state.petLifecycle
        and state.petLifecycle.lifecycle or "unknown"
end

function A:Blocker(action, state)
    local facts = action and action.facts or {}
    if facts.effectTarget == "target" then
        local pet = state and state.actors and state.actors.pet
        if not (state and state.hostile and pet) then return "companion unavailable" end
        if not pet.targetExists then return "companion has no target" end
        if not pet.targetsCurrent then return "companion targets another enemy" end
    end
    if facts.itemTarget then
        return "compatible pet food not configured"
    end
    local operation = facts.petLifecycle
    if not operation then return nil end
    local status = lifecycle(state)
    if operation == "call" then
        if status == "dismissed" then return nil end
        if status == "alive" then return "companion already active" end
        if status == "dead" then return "companion must be revived" end
        return "companion lifecycle unknown"
    elseif operation == "revive" then
        if status == "dead" then return nil end
        if status == "alive" then return "companion is alive" end
        if status == "dismissed" then return "companion is dismissed" end
        return "companion lifecycle unknown"
    elseif operation == "dismiss" then
        return "manual companion dismissal"
    end
    return "unknown companion lifecycle action"
end

function A:UsabilityBlocker(action, usable, reason)
    local facts = action and action.facts or {}
    if facts.requiresHunterCritical and usable ~= true then
        return reason or "Hunter critical required"
    end
    if usable == false and (facts.pet or facts.petLifecycle) then
        return reason or "companion state"
    end
    return nil
end

function A:ApplyLifecycle(out, candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    local operation = facts.petLifecycle
    if operation ~= "call" and operation ~= "revive" then return false end
    local prior = out.petLifecycle or {}
    local last = prior.lastKnown or {}
    local healthMax = tonumber(prior.healthMax) or 1
    local health = operation == "revive"
        and math.max(1, healthMax * 0.15) or math.max(1, tonumber(prior.health) or 1)
    local pet = {
        id = "pet", unit = "pet", actorType = "controlled", ownerClass = "HUNTER",
        guid = prior.guid or last.guid, family = prior.family or last.family,
        health = health, healthMax = healthMax,
        resource = tonumber(prior.focus) or 0,
        resourceMax = tonumber(prior.focusMax) or 100, resourceType = 2,
        targetExists = false, targetsCurrent = false, hasAggro = false,
        lifecycle = "alive", projectedLifecycle = operation,
    }
    out.pet, out.actors.pet = true, pet
    out.petLifecycle = {
        supported = true, lifecycle = "alive", present = true,
        guid = pet.guid, family = pet.family, health = health,
        healthMax = healthMax, focus = pet.resource, focusMax = pet.resourceMax,
        lastKnown = last,
    }
    out.actors.petLifecycle = out.petLifecycle
    out.actorReadyAt.pet = out.time
    return true
end
