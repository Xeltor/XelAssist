-- Target-effect delivery and projected hostile modifier state. Kept separate
-- from action scoring and beam search so resistance mechanics have one owner.
XelAssist.Graph.Effects = {}
local C = XelAssist.Graph.Effects
local State = XelAssist.Graph.State
local Stacks = XelAssist.Graph.StackedModifiers

local function commitHostile(state)
    if State and State.CommitActiveHostile then
        State:CommitActiveHostile(state)
    end
    return state
end

local function modifierReductions(effects)
    return XelAssist.Combat.TargetModifiers:AggregateReductions(effects)
end

local function damageTakenModifiers(effects, base)
    return XelAssist.Combat.TargetModifiers:AggregateDamageTaken(effects, base)
end

function C:Decision(resistance, state, damageKind)
    if not resistance then return 1, 1 end
    if not damageKind then
        resistance.uncertaintyMultiplier = resistance.unknown and 0.90 or 1
        local delivery = (resistance.landChance or 1)
            * resistance.uncertaintyMultiplier
        resistance.damageTakenMultiplier = 1
        resistance.decisionMultiplier = delivery
        return delivery, delivery
    end

    local damageTakenMultiplier, decisionMultiplier = 1, nil
    if resistance.components then
        local expectedWeighted, decisionWeighted, baseWeighted, totalWeight, i =
            0, 0, 0, 0, nil
        for i = 1, table.getn(resistance.components) do
            local component = resistance.components[i]
            local weight = tonumber(component.componentWeight) or 0
            local base = weight * (component.multiplier or 1)
            local vulnerability = 1 + (state.targetDamageTaken
                and state.targetDamageTaken[component.school] or 0)
            local reserve = component.unknown and 0.90 or 1
            component.uncertaintyMultiplier = reserve
            component.expectedWeight = base * vulnerability
            component.decisionWeight = component.expectedWeight * reserve
            baseWeighted = baseWeighted + base
            expectedWeighted = expectedWeighted + component.expectedWeight
            decisionWeighted = decisionWeighted + component.decisionWeight
            totalWeight = totalWeight + weight
        end
        if totalWeight > 0 then
            local baseMultiplier = baseWeighted / totalWeight
            local expectedMultiplier = expectedWeighted / totalWeight
            decisionMultiplier = decisionWeighted / totalWeight
            damageTakenMultiplier = baseMultiplier > 0
                and expectedMultiplier / baseMultiplier or 1
            resistance.uncertaintyMultiplier = expectedMultiplier > 0
                and decisionMultiplier / expectedMultiplier or 1
            if decisionWeighted > 0 then
                for i = 1, table.getn(resistance.components) do
                    local component = resistance.components[i]
                    component.decisionShare = component.decisionWeight / decisionWeighted
                end
            end
        end
    elseif state.targetDamageTaken and resistance.school then
        damageTakenMultiplier = 1 + (state.targetDamageTaken[resistance.school] or 0)
    end
    if not resistance.uncertaintyMultiplier then
        resistance.uncertaintyMultiplier = resistance.unknown and 0.90 or 1
    end
    resistance.damageTakenMultiplier = damageTakenMultiplier
    resistance.decisionMultiplier = decisionMultiplier or (resistance.multiplier or 1)
        * resistance.uncertaintyMultiplier * damageTakenMultiplier
    local delivery = (resistance.landChance or 1)
        * (resistance.uncertaintyMultiplier or 1)
    return resistance.decisionMultiplier, delivery
end

function C:PhaseFactor(resistance, phase, conditionalOnApplication)
    local weighted, total, i = 0, 0, nil
    for i = 1, table.getn(resistance and resistance.components or {}) do
        local component = resistance.components[i]
        if component.componentPhase == phase then
            local weight = tonumber(component.componentWeight) or 0
            local decision = weight > 0 and (component.decisionWeight or 0) / weight or 0
            if conditionalOnApplication then
                local delivery = (component.landChance or resistance.landChance or 1)
                    * (component.uncertaintyMultiplier or 1)
                decision = delivery > 0 and decision / delivery or 0
            end
            weighted, total = weighted + decision * weight, total + weight
        end
    end
    if total > 0 then return weighted / total end
    local decision = resistance and resistance.decisionMultiplier or 1
    if conditionalOnApplication then
        local delivery = (resistance and resistance.landChance or 1)
            * (resistance and resistance.uncertaintyMultiplier or 1)
        return delivery > 0 and decision / delivery or 0
    end
    return decision
end

local function copyNumbers(values)
    if type(values) ~= "table" then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(values) do out[key] = value end
    return out
end

local function rebuildDamageTaken(state)
    state.targetDamageTaken = damageTakenModifiers(
        state.targetModifierEffects, state.baseTargetDamageTaken)
end

local function rebuildProjectedResistance(state)
    local targetResistance = state.targetResistance
    if not targetResistance then return end
    if targetResistance.baseProjectedReduction == nil then
        targetResistance.baseProjectedReduction = copyNumbers(
            targetResistance.projectedReduction) or {}
    end
    if targetResistance.live and targetResistance.rootModifierReduction == nil then
        local rootEffects, name, effect = {}, nil, nil
        for name, effect in pairs(state.targetModifierEffects or {}) do
            if effect.activeRoot then rootEffects[name] = effect end
        end
        targetResistance.rootModifierReduction = modifierReductions(rootEffects) or {}
        targetResistance.baseProjectedReduction = {}
    end
    local current = modifierReductions(state.targetModifierEffects) or {}
    local root = targetResistance.rootModifierReduction or {}
    local projected, schools, school = {}, {}, nil
    for school in pairs(targetResistance.baseProjectedReduction or {}) do schools[school] = true end
    for school in pairs(current) do schools[school] = true end
    for school in pairs(root) do schools[school] = true end
    local count = 0
    for school in pairs(schools) do
        local value = (targetResistance.baseProjectedReduction[school] or 0)
        if targetResistance.live then
            value = value + (current[school] or 0) - (root[school] or 0)
        else value = value + (current[school] or 0) end
        if math.abs(value) >= 0.0001 then projected[school], count = value, count + 1 end
    end
    targetResistance.projectedReduction = count > 0 and projected or nil
    local names, name = {}, nil
    for name in pairs(state.targetModifierEffects or {}) do table.insert(names, name) end
    targetResistance.projectedBy = table.getn(names) > 0 and table.concat(names, ", ") or nil
end

function C:RemoveTargetModifier(state, name)
    local effects = state.targetModifierEffects
    local effect = effects and effects[name]
    if not effect then return end
    if state.targetResistance and state.targetResistance.live
        and state.targetResistance.rootModifierReduction == nil then
        local rootEffects, rootName, rootEffect = {}, nil, nil
        for rootName, rootEffect in pairs(effects) do
            if rootEffect.activeRoot then rootEffects[rootName] = rootEffect end
        end
        state.targetResistance.rootModifierReduction = modifierReductions(rootEffects) or {}
        state.targetResistance.baseProjectedReduction = {}
    end
    effects[name] = nil
    rebuildDamageTaken(state)
    rebuildProjectedResistance(state)
    commitHostile(state)
end

local function blendModifierValues(success, failure, probability)
    local out, keys, school = {}, {}, nil
    for school in pairs(success or {}) do keys[school] = true end
    for school in pairs(failure or {}) do keys[school] = true end
    for school in pairs(keys) do
        local amount = probability * ((success and success[school]) or 0)
            + (1 - probability) * ((failure and failure[school]) or 0)
        if math.abs(amount) >= 0.0001 then out[school] = amount end
    end
    return out
end

local function refreshExpectedModifier(effect, keepFailure)
    local probability = math.max(0, math.min(1,
        tonumber(effect.deliveryProbability) or 1))
    local failureReduction = keepFailure and effect.failureResistanceReduction or nil
    local failureTaken = keepFailure and effect.failureDamageTaken or nil
    effect.resistanceReduction = blendModifierValues(
        effect.successResistanceReduction, failureReduction, probability)
    effect.damageTaken = blendModifierValues(
        effect.successDamageTaken, failureTaken, probability)
    if Stacks then Stacks:Refresh(effect, keepFailure) end
    if not keepFailure then
        effect.failureResistanceReduction = nil
        effect.failureDamageTaken = nil
        effect.failureStackMass = nil
        effect.fallbackRemaining = nil
        effect.activeRoot = nil
    end
end

function C:AdvanceModifierFallbacks(state, elapsed)
    if not state.targetModifierEffects or not elapsed or elapsed <= 0 then return end
    local changed, name, effect = false, nil, nil
    for name, effect in pairs(state.targetModifierEffects) do
        if effect.fallbackRemaining then
            if effect.fallbackRemaining <= elapsed then
                refreshExpectedModifier(effect, false)
                if Stacks then Stacks:SyncAura(
                    state.auras and state.auras[name], effect) end
                changed = true
            else effect.fallbackRemaining = effect.fallbackRemaining - elapsed end
        end
    end
    if changed then
        rebuildDamageTaken(state)
        rebuildProjectedResistance(state)
    end
    commitHostile(state)
end

function C:StateAtImpact(state, elapsed)
    if not elapsed or elapsed <= 0 or not state.targetModifierEffects then return state end
    local out = XelAssist.Graph.State:Copy(state)
    local expired, name, aura = {}, nil, nil
    for name, aura in pairs(out.auras or {}) do
        if type(aura) == "table" and aura.targetModifier and aura.remaining then
            if aura.remaining <= elapsed then table.insert(expired, name)
            else aura.remaining = aura.remaining - elapsed end
        end
    end
    local i
    for i = 1, table.getn(expired) do
        self:RemoveTargetModifier(out, expired[i])
        out.auras[expired[i]] = nil
    end
    self:AdvanceModifierFallbacks(out, elapsed)
    return commitHostile(out)
end

function C:ApplyTargetModifier(state, action, targetFacts, sourceState, delivery,
    priorEffect, fallbackRemaining, targetGUID)
    if not state.targetModifierEffects then state.targetModifierEffects = {} end
    if state.baseTargetDamageTaken == nil then
        state.baseTargetDamageTaken = copyNumbers(state.targetDamageTaken) or {}
    end
    priorEffect = priorEffect or state.targetModifierEffects[action.name]
    delivery = math.max(0, math.min(1, tonumber(delivery) or 1))
    local cap = tonumber(action.facts.stackable)
    local stackProjection = cap and Stacks:Application(priorEffect, cap) or nil
    local priorStacks = stackProjection
        and Stacks:Expected(stackProjection.prior, cap) or 0
    local successStacks = stackProjection
        and Stacks:Expected(stackProjection.success, cap) or nil
    local effect = { name = action.name,
        group = action.facts.modifierGroup or action.name,
        exclusiveFamily = action.facts.exclusiveFamily, mine = true,
        resistanceReduction = {}, damageTaken = {},
        successResistanceReduction = {}, successDamageTaken = {},
        failureResistanceReduction = copyNumbers(
            priorEffect and priorEffect.resistanceReduction) or {},
        failureDamageTaken = copyNumbers(priorEffect and priorEffect.damageTaken) or {},
        stackCap = cap,
        successStackMass = stackProjection and stackProjection.success or nil,
        failureStackMass = stackProjection and stackProjection.failure or nil,
        deliveryProbability = delivery,
        fallbackRemaining = priorEffect and (fallbackRemaining or math.huge) or nil,
        activeRoot = priorEffect and priorEffect.activeRoot or nil }
    if not state.targetResistance then state.targetResistance = {} end
    local armor = tonumber(targetFacts.targetArmorReduction)
    if armor then
        if targetFacts.targetArmorPerCombo then
            local points = XelAssist.Graph.ComboState
                and XelAssist.Graph.ComboState:ConditionalExpected(
                    sourceState, targetGUID)
                or sourceState.combo or 0
            armor = armor * points
        end
        if cap then
            local prior = priorEffect and priorEffect.resistanceReduction[0] or 0
            local perStack = priorStacks > 0 and prior / priorStacks or 0
            armor = math.max(armor, perStack) * successStacks
        end
        effect.successResistanceReduction[0] = armor
    end
    local school, amount
    for school, amount in pairs(targetFacts.targetResistanceReduction or {}) do
        local value = tonumber(amount) or 0
        if cap then
            local prior = priorEffect and priorEffect.resistanceReduction[school] or 0
            local perStack = priorStacks > 0 and prior / priorStacks or 0
            value = math.max(value, perStack) * successStacks
        end
        effect.successResistanceReduction[school] = value
    end
    for school, amount in pairs(targetFacts.targetDamageTaken or {}) do
        local value = tonumber(amount) or 0
        if cap then
            local prior = priorEffect and priorEffect.damageTaken[school] or 0
            local perStack = priorStacks > 0 and prior / priorStacks or 0
            value = math.max(value, perStack) * successStacks
        end
        effect.successDamageTaken[school] = value
    end
    refreshExpectedModifier(effect, effect.fallbackRemaining and delivery < 1)
    state.targetModifierEffects[action.name] = effect
    rebuildDamageTaken(state)
    rebuildProjectedResistance(state)
    commitHostile(state)
end

local function scaleModifierBranch(effect, probability)
    local fields = { "resistanceReduction", "damageTaken",
        "successResistanceReduction", "successDamageTaken",
        "failureResistanceReduction", "failureDamageTaken" }
    local i, field, school, amount
    for i = 1, table.getn(fields) do
        field = fields[i]
        for school, amount in pairs(effect[field] or {}) do
            effect[field][school] = amount * probability
        end
    end
    if Stacks then Stacks:Scale(effect, probability) end
end

function C:ApplyExclusiveFamily(state, action, delivery)
    local family = action.facts and action.facts.exclusiveFamily
    if not family then return end
    delivery = math.max(0, math.min(1, tonumber(delivery) or 1))
    local affected, name, aura = {}, nil, nil
    for name, aura in pairs(state.auras or {}) do
        if name ~= action.name and type(aura) == "table"
            and aura.exclusiveFamily == family and aura.mine == true then
            affected[name] = true
        end
    end
    for name, aura in pairs(state.targetAuras or {}) do
        if name ~= action.name and type(aura) == "table"
            and aura.exclusiveFamily == family and aura.mine == true then
            affected[name] = true
        end
    end
    local effect
    for name, effect in pairs(state.targetModifierEffects or {}) do
        if name ~= action.name and effect.exclusiveFamily == family
            and effect.mine == true then affected[name] = true end
    end
    local changed = false
    for name in pairs(affected) do
        local oldAura = state.auras and state.auras[name]
        local liveAura = state.targetAuras and state.targetAuras[name]
        local oldEffect = state.targetModifierEffects and state.targetModifierEffects[name]
        if delivery >= 1 then
            if XelAssist.Graph.EventAuras
                and XelAssist.Graph.EventAuras.InvalidateStateAura then
                XelAssist.Graph.EventAuras:InvalidateStateAura(state, name)
            end
            if oldEffect then self:RemoveTargetModifier(state, name) end
            if state.auras then state.auras[name] = nil end
            if liveAura and liveAura.mine == true then state.targetAuras[name] = nil end
        else
            local failureProbability = 1 - delivery
            if XelAssist.Graph.EventAuras
                and XelAssist.Graph.EventAuras.ScaleStateAura then
                XelAssist.Graph.EventAuras:ScaleStateAura(
                    state, name, failureProbability)
            end
            if oldAura then
                XelAssist.Graph.EventAuras:ScaleAuraTree(
                    oldAura, failureProbability)
            end
            if liveAura and liveAura.mine == true then
                liveAura.applicationProbability = (tonumber(
                    liveAura.applicationProbability) or 1) * failureProbability
            end
            if oldEffect then
                scaleModifierBranch(oldEffect, failureProbability)
                changed = true
            end
        end
    end
    if changed then
        rebuildDamageTaken(state)
        rebuildProjectedResistance(state)
    end
    commitHostile(state)
end

local function phaseAction(action, phase)
    local copy, key, value = {}, nil, nil
    for key, value in pairs(action) do copy[key] = value end
    copy.facts = {}
    for key, value in pairs(action.facts or {}) do copy.facts[key] = value end
    copy.facts.resistancePhase = phase
    return copy
end

local function modifierBreakpoints(state, startAt, duration)
    local points, seen = { 0, duration }, { [0] = true, [duration] = true }
    local function add(remaining)
        remaining = tonumber(remaining)
        if not remaining then return end
        local offset = remaining - startAt
        if offset > 0 and offset < duration then
            local key = math.floor(offset * 10000 + 0.5)
            if not seen[key] then seen[key] = true; table.insert(points, offset) end
        end
    end
    local _, aura, effect
    for _, aura in pairs(state.auras or {}) do
        if type(aura) == "table" and aura.targetModifier then add(aura.remaining) end
    end
    for _, effect in pairs(state.targetModifierEffects or {}) do add(effect.fallbackRemaining) end
    table.sort(points)
    return points
end

function C:OverWindow(action, target, tooltip, state, startAt, duration,
    phase, conditionalOnApplication)
    if not XelAssist.Combat.Resistance or not duration or duration <= 0 then return nil end
    startAt = math.max(0, tonumber(startAt) or 0)
    local projectedAction = phaseAction(action, phase or "periodic")
    local projectedTooltip = { school = tooltip and tooltip.school }
    local initialState = self:StateAtImpact(state, startAt)
    local initial = XelAssist.Combat.Resistance:Estimate(
        projectedAction, target, projectedTooltip, initialState)
    local _, initialDelivery = self:Decision(initial, initialState, true)
    local points = modifierBreakpoints(state, startAt, duration)
    local weighted, total, representative, i = 0, 0, initial, nil
    for i = 1, table.getn(points) - 1 do
        local left, right = points[i], points[i + 1]
        local span = right - left
        if span > 0 then
            local sampleState = self:StateAtImpact(state, startAt + left + span / 2)
            local estimate = XelAssist.Combat.Resistance:Estimate(
                projectedAction, target, projectedTooltip, sampleState)
            self:Decision(estimate, sampleState, true)
            local factor = self:PhaseFactor(
                estimate, phase, conditionalOnApplication)
            weighted, total = weighted + factor * span, total + span
            representative = estimate
        end
    end
    return total > 0 and weighted / total or 0, initialDelivery, representative
end
