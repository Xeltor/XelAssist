-- Projected Hunter companion buffs and next-melee effects. These records stay
-- on the companion actor so a player-cast pet buff is never confused with an
-- immediate hostile aura.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.Effects = {}
local E = XelAssist.Game.Pets.Effects

local function petOf(state)
    return state and state.actors and state.actors.pet or nil
end

function E:DamageMultiplier(pet)
    if not pet then return 1 end
    local value = tonumber(pet.happinessDamageMultiplier)
        or tonumber(pet.baseDamageMultiplier)
        or (not next(pet.combatEffects or {})
            and tonumber(pet.damageMultiplier)) or 1
    local _, effect
    for _, effect in pairs(pet.combatEffects or {}) do
        if not effect.remaining or effect.remaining > 0 then
            value = value * (tonumber(effect.damageMultiplier) or 1)
        end
    end
    return value
end

function E:ThreatMultiplier(pet)
    if not pet then return 1 end
    local value, _, effect = 1, nil, nil
    for _, effect in pairs(pet.combatEffects or {}) do
        if not effect.remaining or effect.remaining > 0 then
            value = value * (tonumber(effect.threatMultiplier) or 1)
        end
    end
    return value
end

function E:CrowdControlImmune(pet)
    if not pet then return false end
    local _, effect
    for _, effect in pairs(pet.combatEffects or {}) do
        if effect.crowdControlImmune
            and (not effect.remaining or effect.remaining > 0) then return true end
    end
    return false
end

function E:Active(pet, sourceName)
    if not (pet and sourceName) then return false end
    local name, effect
    for name, effect in pairs(pet.combatEffects or {}) do
        if string.find(name, sourceName .. ":", 1, true) == 1
            and (not effect.remaining or effect.remaining > 0) then return true end
    end
    return false
end

function E:Advance(state, elapsed)
    local pet = petOf(state)
    if not pet or not elapsed or elapsed <= 0 then return end
    if XelAssist.Game.Pets.Resources then
        XelAssist.Game.Pets.Resources:AdvanceActor(pet, elapsed)
    end
    local function advanceStore(store)
        local name, effect
        for name, effect in pairs(store or {}) do
            if effect.remaining then
                effect.remaining = math.max(0, effect.remaining - elapsed)
                if effect.remaining <= 0 then store[name] = nil end
            end
        end
    end
    advanceStore(pet.combatEffects)
    advanceStore(pet.pendingMeleeEffects)
    pet.damageMultiplier = self:DamageMultiplier(pet)
    pet.threatMultiplier = self:ThreatMultiplier(pet)
end

function E:Apply(state, candidate, context)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    local pet = petOf(state)
    if not pet then return false end
    local elapsed = context and context.petEventContext
        and context.petEventContext.applicationElapsed
        or context and context.applicationElapsed or 0
    local applied = false
    if facts.petCombatBuff or facts.petCombatEffects then
        pet.combatEffects = pet.combatEffects or {}
        local effects = facts.petCombatEffects
        if not effects then
            effects = { { duration = tonumber(candidate.tooltip
                    and candidate.tooltip.duration) or tonumber(facts.duration),
                damageMultiplier = tonumber(facts.petDamageMultiplier) or 1,
                crowdControlImmune = facts.petCrowdControlImmune and true or false,
                sourceSpellId = candidate.action.spellId } }
        end
        local i, effect
        for i = 1, table.getn(effects) do
            effect = effects[i]
            local duration = tonumber(effect.duration)
            local key = candidate.action.name .. ":" .. (effect.key or tostring(i))
            pet.combatEffects[key] = {
                remaining = duration and math.max(0, duration - elapsed),
                duration = duration,
                damageMultiplier = tonumber(effect.damageMultiplier) or 1,
                threatMultiplier = tonumber(effect.threatMultiplier) or 1,
                crowdControlImmune = effect.crowdControlImmune and true or false,
                sourceSpellId = effect.sourceSpellId or candidate.action.spellId,
                runtimeUnverified = effect.runtimeUnverified and true or false,
            }
        end
        pet.damageMultiplier = self:DamageMultiplier(pet)
        pet.threatMultiplier = self:ThreatMultiplier(pet)
        applied = true
    end
    if facts.deferredUntilPetMelee then
        pet.pendingMeleeEffects = pet.pendingMeleeEffects or {}
        local duration = tonumber(facts.triggerWindow) or 15
        pet.pendingMeleeEffects[candidate.action.name] = {
            remaining = math.max(0, duration - elapsed), duration = duration,
            targetGuid = candidate.targetGUID,
            stunDuration = tonumber(facts.stunDuration),
            resultSpellIds = facts.triggeredSpellIds,
            resultSpellId = facts.deferredResultSpellId,
            threatBase = tonumber(facts.deferredThreatBase),
            threatLevel = tonumber(facts.deferredThreatLevel),
            threatPerLevel = tonumber(facts.deferredThreatPerLevel),
        }
        applied = true
    end
    return applied
end

local function deferredThreat(effect, pet)
    local base = tonumber(effect and effect.threatBase)
    if not base then return nil end
    local level = tonumber(pet and pet.level) or tonumber(effect.threatLevel) or 0
    local start = tonumber(effect.threatLevel) or level
    local perLevel = tonumber(effect.threatPerLevel) or 0
    return math.max(0, base + math.max(0, level - start) * perLevel)
end

function E:ConsumeMelee(state, action, targetGuid, delivery)
    local facts = action and action.facts or {}
    local actor = facts.damageActor or facts.effectActor or action and action.actor
    if actor ~= "pet" or not facts.melee then return nil end
    local pet = petOf(state)
    local effects = pet and pet.pendingMeleeEffects
    if not effects then return nil end
    local name, effect
    for name, effect in pairs(effects) do
        if (not effect.remaining or effect.remaining > 0)
            and effect.targetGuid == targetGuid then
            if effect.outcomeUnknown then
                state.deferredControlTimingUnknown = true
                return nil
            end
            local probability = tonumber(delivery)
            if probability == nil then probability = 1 end
            probability = math.max(0, math.min(1, probability))
            local charge = tonumber(effect.chargeProbability) or 1
            local proc = charge * probability
            effect.chargeProbability = charge * (1 - probability)
            if effect.chargeProbability <= 0.05 then effects[name] = nil end
            if effect.stunDuration and effect.stunDuration > 0 then
                state.auras = state.auras or {}
                local prior = state.auras[name]
                local priorProbability = tonumber(
                    prior and prior.applicationProbability) or 0
                if not prior or (tonumber(prior.remaining) or 0) <= 0
                    or proc > priorProbability then
                    state.auras[name] = { remaining = effect.stunDuration,
                        duration = effect.stunDuration, mine = true,
                        target = "target", applicationProbability = proc,
                        sourceActor = "pet", deferred = true }
                else
                    -- Distinct possible proc times are mutually exclusive
                    -- branches. Keep the strongest single active lower bound;
                    -- summing them and refreshing duration would invent control.
                    prior.alternateProcTimingWithheld = true
                    state.deferredControlTimingUnknown = true
                end
            end
            effect.threat = deferredThreat(effect, pet)
            effect.threatMultiplier = self:ThreatMultiplier(pet)
            effect.projectedThreat = effect.threat
                and effect.threat * effect.threatMultiplier * proc or nil
            if effect.threat and XelAssist.Graph
                and XelAssist.Graph.CompanionThreat then
                XelAssist.Graph.CompanionThreat:Apply(state,
                    { facts = { kind = "petThreat",
                        petThreatGain = effect.threat } }, nil, proc)
            end
            return effect
        end
    end
    return nil
end
