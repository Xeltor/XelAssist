-- Passage-of-time projections that happen while a candidate occupies the
-- player: friendly periodic healing, pet autocasts, hostile periodic effects,
-- and expiration of observed or projected target state.
XelAssist.Graph.OngoingEffects = {}
local O = XelAssist.Graph.OngoingEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects

local function advanceFriendlies(state, elapsed)
    if not state.friendlies or elapsed <= 0 then return end
    local i, name, aura
    for i = 1, table.getn(state.friendlies.order or {}) do
        local record = State:FriendlyByKey(
            state, state.friendlies.order[i])
        if record then
            for name, aura in pairs(record.auras or {}) do
                if type(aura) == "table" then
                    local active = aura.remaining
                        and math.min(elapsed, aura.remaining) or elapsed
                    if aura.periodicHealRate and active > 0 then
                        record.health = math.min(record.healthMax,
                            record.health + aura.periodicHealRate * active)
                    end
                    if aura.remaining then
                        aura.remaining = math.max(0, aura.remaining - elapsed)
                        if aura.remaining <= 0 then record.auras[name] = nil end
                    end
                end
            end
            for name, aura in pairs(record.absorbs or {}) do
                if type(aura) == "table" and aura.remaining then
                    aura.remaining = math.max(0, aura.remaining - elapsed)
                    if aura.remaining <= 0 then record.absorbs[name] = nil end
                end
            end
        end
    end
end

local function advanceAmbientPet(out, source, candidate, context)
    local pet = out.actors and out.actors.pet
    if not (pet and pet.autocasts and pet.targetExists
        and pet.targetsCurrent) then return end
    local i
    for i = 1, table.getn(pet.autocasts) do
        local ambient = pet.autocasts[i]
        local offset = math.min(candidate.downtime,
            math.max(0, tonumber(ambient.readyIn) or 0))
        ambient.readyIn = math.max(0,
            (ambient.readyIn or 0) - candidate.downtime)
        if ambient.readyIn <= 0 and pet.resource >= (ambient.cost or 0) then
            pet.resource = pet.resource - (ambient.cost or 0)
            ambient.readyIn = math.max(0.1, ambient.cooldown or 1.5)
            if ambient.kind == "damage" and out.targetHealthExact then
                local power = ambient.power or 0
                if XelAssist.Combat.Resistance then
                    local eventState = Effects:StateAtImpact(source, offset)
                    if offset >= context.applicationOffset
                        and context:ChangesHostileTarget() then
                        eventState = State:Copy(eventState)
                        context:ProjectCurrentApplication(eventState,
                            offset - context.applicationOffset)
                    end
                    local estimate = XelAssist.Combat.Resistance:Estimate(
                        ambient, "target", ambient.tooltip or {}, eventState)
                    power = power * Effects:Decision(estimate, eventState, true)
                end
                out.targetHealth = math.max(0, out.targetHealth - power)
            elseif ambient.kind == "taunt" then
                local petTank = XelAssistCharDB.petThreat == "tank"
                    or (XelAssistCharDB.petThreat ~= "avoid"
                        and out.groupSize == 0)
                if petTank then
                    out.hasAggro = false
                    pet.hasAggro = true
                end
            end
        end
    end
end

local function periodicSegment(aura, state, span)
    if span <= 0 then return 0 end
    local conditional = Effects:OverWindow(aura.periodicAction, "target",
        aura.periodicTooltip or {}, state, 0, span, "periodic", true)
    if not conditional then
        return math.max(0, aura.periodicRate or 0) * span
    end
    return math.max(0, aura.periodicRawRate) * span
        * (tonumber(aura.applicationProbability) or 1) * conditional
end

local function periodicDamage(source, context, aura, elapsed, baseState)
    local fallback = math.max(0, aura.periodicRate or 0) * elapsed
    if not (aura.periodicRawRate and aura.periodicAction
        and XelAssist.Combat.Resistance and elapsed > 0) then
        return fallback
    end
    if context:ChangesHostileTarget()
        and context.applicationOffset < elapsed then
        local before = math.max(0, context.applicationOffset)
        local afterState = State:Copy(
            Effects:StateAtImpact(source, context.applicationOffset))
        context:ProjectCurrentApplication(afterState, 0)
        context:AddProjectedModifierAura(afterState)
        return periodicSegment(aura, baseState, before)
            + periodicSegment(aura, afterState, elapsed - before)
    end
    return periodicSegment(aura, baseState, elapsed)
end

local function advanceAuras(out, source, candidate, context)
    local baseState = State:Copy(source)
    local name, aura
    for name, aura in pairs(out.auras) do
        if type(aura) == "table" and aura.remaining then
            local elapsed = math.min(aura.remaining, candidate.downtime)
            if aura.periodicRate and aura.target == "target"
                and out.targetHealthExact then
                local damage = periodicDamage(
                    source, context, aura, elapsed, baseState)
                out.targetHealth = math.max(0, out.targetHealth - damage)
            end
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then
                if aura.targetModifier then
                    Effects:RemoveTargetModifier(out, name)
                end
                out.auras[name] = nil
            end
        end
    end
    Effects:AdvanceModifierFallbacks(out, candidate.downtime)
end

local function advanceObservedTargetAuras(state, elapsed)
    local name, aura
    for name, aura in pairs(state.targetAuras or {}) do
        if type(aura) == "table" and aura.remaining then
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then state.targetAuras[name] = nil end
        end
    end
end

function O:Advance(out, source, candidate, context)
    out.time = out.time + candidate.downtime
    advanceFriendlies(out, candidate.downtime)
    advanceAmbientPet(out, source, candidate, context)
    advanceAuras(out, source, candidate, context)
    advanceObservedTargetAuras(out, candidate.downtime)
end
