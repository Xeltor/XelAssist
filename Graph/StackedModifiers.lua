-- Bounded probability mass for stackable target modifiers. Expected stacks
-- alone cannot distinguish, for example, 50% at five stacks from a certain
-- 2.5 stacks; subsequent capped applications therefore keep all 0..cap mass.
XelAssist.Graph.StackedModifiers = {}
local S = XelAssist.Graph.StackedModifiers

local function bound(value, low, high)
    return math.max(low, math.min(high, tonumber(value) or low))
end

local function copyMass(source, cap)
    local out, total, stack = {}, 0, nil
    for stack = 0, cap do
        local value = math.max(0, tonumber(source and source[stack]) or 0)
        out[stack], total = value, total + value
    end
    if total <= 0 then out[0], total = 1, 1 end
    if math.abs(total - 1) > 0.000001 then
        for stack = 0, cap do out[stack] = out[stack] / total end
    end
    return out
end

function S:Expected(mass, cap)
    local value, stack = 0, nil
    for stack = 1, cap do
        value = value + stack * (tonumber(mass and mass[stack]) or 0)
    end
    return value
end

function S:Mass(effect, cap)
    if effect and type(effect.stackMass) == "table" then
        return copyMass(effect.stackMass, cap)
    end
    local expected = bound(effect and (effect.expectedStacks
        or effect.stacks), 0, cap)
    local lower, upper = math.floor(expected), math.ceil(expected)
    local mass = {}
    if lower == upper then mass[lower] = 1
    else
        mass[lower], mass[upper] = upper - expected, expected - lower
    end
    return copyMass(mass, cap)
end

function S:Application(effect, cap)
    local prior, success, stack = self:Mass(effect, cap), {}, nil
    for stack = 0, cap do
        local destination = math.min(cap, stack + 1)
        success[destination] = (success[destination] or 0) + prior[stack]
    end
    return { prior = prior, success = copyMass(success, cap),
        failure = copyMass(prior, cap) }
end

function S:Blend(success, failure, delivery, keepFailure, cap)
    delivery = bound(delivery, 0, 1)
    local out, stack = {}, nil
    for stack = 0, cap do
        out[stack] = delivery * (tonumber(success and success[stack]) or 0)
            + (keepFailure and (1 - delivery)
                * (tonumber(failure and failure[stack]) or 0) or 0)
    end
    if not keepFailure then out[0] = (out[0] or 0) + 1 - delivery end
    return copyMass(out, cap)
end

function S:Refresh(effect, keepFailure)
    local cap = tonumber(effect and effect.stackCap)
    if not cap then return end
    effect.stackMass = self:Blend(effect.successStackMass,
        effect.failureStackMass, effect.deliveryProbability,
        keepFailure, cap)
    effect.expectedStacks = self:Expected(effect.stackMass, cap)
    effect.stacks = effect.expectedStacks
end

function S:Scale(effect, probability)
    local cap = tonumber(effect and effect.stackCap)
    if not cap then return end
    probability = bound(probability, 0, 1)
    local mass, stack = self:Mass(effect, cap), nil
    for stack = 1, cap do mass[stack] = mass[stack] * probability end
    mass[0] = 1
    for stack = 1, cap do mass[0] = mass[0] - mass[stack] end
    effect.stackMass = copyMass(mass, cap)
    effect.expectedStacks = self:Expected(effect.stackMass, cap)
    effect.stacks = effect.expectedStacks
end

function S:SyncAura(aura, effect)
    local cap = tonumber(effect and effect.stackCap)
    if type(aura) ~= "table" or not cap then return end
    aura.stackMass = copyMass(effect.stackMass, cap)
    aura.expectedStacks = self:Expected(aura.stackMass, cap)
    aura.stacks = aura.expectedStacks
    aura.applicationProbability = 1 - (aura.stackMass[0] or 0)
end
