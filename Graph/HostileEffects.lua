-- Per-hostile valuation and transition for recipient sets whose DBC topology
-- is strong enough to prove each hit. Cost and occupancy remain action-local;
-- this module owns only the additional hostile-local consequences.
XelAssist.Graph.HostileEffects = {}
local H = XelAssist.Graph.HostileEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Recipients = XelAssist.Graph.AreaRecipients
local PlayerThreat = XelAssist.Graph.PlayerThreat
local PrimaryThreat = XelAssist.Graph.PrimaryThreatEffects
local WarriorThreat = XelAssist.Graph.WarriorThreatPackets
local ShamanEarthShock = XelAssist.Graph.ShamanEarthShock

local function activeTarget(state)
    if State.ActiveHostile then return State:ActiveHostile(state) end
    return State.SelectedHostile and State:SelectedHostile(state) or nil
end

local function syncActive(state)
    if State.SyncActiveHostile then return State:SyncActiveHostile(state) end
    if State.SyncSelectedHostile then return State:SyncSelectedHostile(state) end
    return state
end

local function appendUnique(list, seen, value)
    if not value or seen[value] then return end
    seen[value] = true
    table.insert(list, value)
end

local function topologyFor(context)
    local tooltip = context.effectTooltip or context.tooltip or {}
    return tooltip.topology
end

local function directArea(context, resolution)
    if not (context.targetEffect and context.damageKind
        and (context.kind == "damage" or context.kind == "builder")) then
        return nil, "per-recipient effect timing is unresolved"
    end
    if table.getn(resolution.groups or {}) ~= 1 then
        return nil, "mixed hostile effect topology is unresolved"
    end
    local group = resolution.groups[1]
    local topology = group and group.topology or {}
    if topology.relation ~= "hostile" or topology.shape ~= "area"
        or (topology.center ~= "caster" and topology.center ~= "target") then
        return nil, "hostile area effect topology is unresolved"
    end
    return group, nil
end

local function localState(state, key)
    if not (State and State.HostileContext) then return nil end
    return State:HostileContext(state, key)
end

local function resistanceFor(context, key, primary)
    if primary then
        return context.resistance, context.expectedPower,
            context.effectDelivery or 1
    end
    local projected = localState(context.state, key)
    if not projected then return nil, nil, nil end
    local offset = math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    if Effects and Effects.StateAtImpact then
        projected = Effects:StateAtImpact(projected, offset)
    end
    local resistance, decision, delivery
    if XelAssist.Combat.Resistance then
        resistance = XelAssist.Combat.Resistance:Estimate(
            context.effectAction or context.action, "target",
            context.effectTooltip or context.tooltip or {}, projected)
    end
    if Effects and Effects.Decision then
        decision, delivery = Effects:Decision(
            resistance, projected, true)
    else decision, delivery = 1, 1 end
    return resistance, math.max(0, tonumber(context.power) or 0)
        * (decision or 1), delivery or 1
end

local function recipientEffect(context, key, record, primary, collateral)
    local resistance, expected, delivery = resistanceFor(
        context, key, primary)
    if expected == nil then return nil end
    local health = primary and (context.targetHealthAtImpact
        or context.state.targetHealth) or record.health
    local exact = primary and context.state.targetHealthExact
        or record.healthExact == true
    local effective = expected
    if exact and tonumber(health) and health > 0 then
        effective = math.min(expected, health)
    end
    local factor = context.facts.threat or 1
    local actor = context.facts.damageActor or context.facts.effectActor
        or context.action.actor or "player"
    local threatMultiplier, playerThreatExact = factor, true
    if actor == "pet" then
        local pet = context.state.actors and context.state.actors.pet
        local multiplier = XelAssist.Game.Pets and XelAssist.Game.Pets.Effects
            and XelAssist.Game.Pets.Effects:ThreatMultiplier(pet) or 1
        threatMultiplier = threatMultiplier * 0.9 * multiplier
    else
        local _, exact, multiplier = PlayerThreat:Scale(
            context.state, actor, 1, context.threatSchool)
        threatMultiplier = threatMultiplier * multiplier
        playerThreatExact = exact
    end
    local threat = effective * threatMultiplier
    return { key = key, guid = record.guid, unit = record.unit,
        primary = primary and true or false,
        collateral = collateral and true or false,
        rawPower = math.max(0, tonumber(context.power) or 0),
        expectedPower = expected, effectivePower = effective,
        resistance = resistance, delivery = delivery, threat = threat,
        threatMultiplier = threatMultiplier,
        playerThreatExact = playerThreatExact,
        healthAtImpact = health, healthExact = exact,
        defeated = exact and tonumber(health) and health > 0
            and expected >= health or false }
end

local function withholdArea(context, reason)
    context.areaRecipientsUnknown = true
    context.areaDirectResolved = true
    context.areaSelectedIncluded = false
    context.expectedPower, context.effectivePower = 0, 0
    context.effectDelivery = 0
    context.recipientEffects = { order = {}, byKey = {} }
    context.totalExpectedPower, context.totalEffectivePower = 0, 0
    context.collateralExpectedPower = 0
    context.value, context.reason = -100000, reason
end

local function addEffect(context, effects, key, record, primary, collateral)
    if not (key and record) or effects.byKey[key] then return nil end
    local effect = recipientEffect(context, key, record, primary, collateral)
    if not effect then return nil end
    effects.byKey[key] = effect
    table.insert(effects.order, key)
    return effect
end

local function secondaryThreatValue(context, effect, record)
    if effect.primary then return 0 end
    local state, actor, threat = context.state,
        context.facts.damageActor or context.facts.effectActor
            or context.action.actor or "player", effect.threat or 0
    if actor == "pet" then
        local policy = XelAssist.Graph.CompanionThreat
            and XelAssist.Graph.CompanionThreat:ResolvePolicy(state) or "avoid"
        if policy == "tank" then return threat * 0.4 end
        if state.groupSize and state.groupSize > 0 then return -threat * 0.25 end
        return 0
    end
    if state.tank and threat > (effect.effectivePower or 0) then
        return (threat - (effect.effectivePower or 0)) * 0.5
    end
    if (state.groupSize or 0) > 0 or state.pet then
        if not state.tank then
            local uncertain = record.threat
                and record.threat.playerDeltaExact == false
            return -threat * ((record.hasPlayerAggro or uncertain) and 3 or 0.25)
        end
    end
    return 0
end

local function collectRecipientEffects(context, resolution, group,
    selectedKey, unknownSet)
    local effects = { order = {}, byKey = {}, effectIndex = group.effectIndex }
    local totals = { expected = 0, effective = 0, collateral = 0,
        credited = 0, defeated = 0 }
    local i
    for i = 1, table.getn(group.order or {}) do
        local key, record = group.order[i], nil
        record = group.byKey[key]
        local effect = addEffect(context, effects, key, record,
            key == selectedKey, false)
        if effect then
            totals.expected = totals.expected + effect.expectedPower
            totals.effective = totals.effective + effect.effectivePower
            totals.credited = totals.credited + 1
            if effect.defeated then totals.defeated = totals.defeated + 1 end
            context.value = context.value
                + secondaryThreatValue(context, effect, record)
        else
            appendUnique(context.areaUnknowns, unknownSet,
                "per-hostile resistance context is unavailable")
        end
    end
    for i = 1, table.getn(resolution.collateral or {}) do
        local row = resolution.collateral[i]
        if row.effectIndex == group.effectIndex then
            local effect = addEffect(context, effects, row.key, row.record,
                row.key == selectedKey, true)
            if effect then
                totals.collateral = totals.collateral + effect.effectivePower
            else
                appendUnique(context.areaUnknowns, unknownSet,
                    "collateral resistance context is unavailable")
            end
        end
    end
    for i = 1, table.getn(resolution.withheld or {}) do
        local row = resolution.withheld[i]
        if row.effectIndex == group.effectIndex then
            local effect = addEffect(context, effects, row.key, row.record,
                row.key == selectedKey, false)
            if effect then
                effect.creditWithheld = true
                context.value = context.value
                    + secondaryThreatValue(context, effect, row.record)
            else
                appendUnique(context.areaUnknowns, unknownSet,
                    "withheld resistance context is unavailable")
            end
        end
    end
    return effects, totals
end

-- Returns true only when it replaces the ordinary single-target damage score.
function H:Score(context)
    local topology = topologyFor(context)
    if not topology or not (topology.area or context.facts.aoe) then
        return false
    end
    local resolution = Recipients:Resolve(
        context.state, context.action, topology)
    context.areaRecipientGroups = resolution.groups
    context.areaUnknowns = {}
    local unknownSet, i = {}, nil
    for i = 1, table.getn(resolution.unknowns or {}) do
        appendUnique(context.areaUnknowns, unknownSet,
            resolution.unknowns[i])
    end
    if WarriorThreat then
        local reason, handled = WarriorThreat:AreaBlocker(context, resolution)
        if handled and reason then
            appendUnique(context.areaUnknowns, unknownSet, reason)
            withholdArea(context, reason)
            return true
        end
    end
    local group, unsupported = directArea(context, resolution)
    if not group then
        appendUnique(context.areaUnknowns, unknownSet, unsupported)
        withholdArea(context, "area recipients are unresolved")
        return true
    end

    local selectedKey = context.descriptor and context.descriptor.key
        or context.state.hostiles and context.state.hostiles.selectedKey
    local effects, totals = collectRecipientEffects(
        context, resolution, group, selectedKey, unknownSet)

    local selected = effects.byKey[selectedKey]
    context.expectedPower = selected and selected.expectedPower or 0
    context.effectivePower = selected and selected.effectivePower or 0
    context.effectDelivery = selected and selected.delivery or 0
    context.resistance = selected and selected.resistance or context.resistance
    context.recipientEffects = effects
    context.totalExpectedPower = totals.expected
    context.totalEffectivePower = totals.effective
    context.collateralExpectedPower = totals.collateral
    context.areaDirectResolved = true
    context.areaSelectedIncluded = selected ~= nil
    context.areaRecipientsUnknown = resolution.additionalUnknown
        or table.getn(context.areaUnknowns) > 0

    if totals.credited == 0 then
        withholdArea(context, "no proven engaged area recipient")
        return true
    end
    local downtime = math.max(0.5, tonumber(context.downtime) or 0.5)
    context.value = context.value + 250 + totals.effective * 4 / downtime
        + totals.defeated * 350
    if totals.collateral > 0 then
        context.value = context.value - 900 - totals.collateral * 2 / downtime
    end
    if context.state.role == "damage" then context.value = context.value * 1.15
    elseif context.state.role == "healer" then context.value = context.value * 0.85 end
    if totals.collateral > 0 then
        context.reason = "risks pulling an additional enemy"
    elseif totals.credited > 1 then
        context.reason = "hits " .. tostring(totals.credited)
            .. " proven engaged enemies"
    elseif totals.defeated > 0 then context.reason = "finishes the target"
    elseif totals.credited == 1 then context.reason = "hits one proven enemy"
    else context.reason = "no proven area recipient" end
    return true
end

function H:Apply(out, candidate)
    if not (candidate.areaDirectResolved and candidate.recipientEffects) then
        return false
    end
    local selectedKey = candidate.targetKey
    local i
    for i = 1, table.getn(candidate.recipientEffects.order or {}) do
        local key = candidate.recipientEffects.order[i]
        local effect = candidate.recipientEffects.byKey[key]
        if effect and key ~= selectedKey then
            local record = State:HostileByKey(out, key)
            local living = record and record.guid == effect.guid
                and record.dead ~= true and record.projectedDefeated ~= true
                and not (record.healthExact == true
                    and (tonumber(record.health) or 0) <= 0)
            if living then
                local projectedThreat = tonumber(effect.threat) or 0
                if record.healthExact and tonumber(record.health) then
                    local beforeHealth = tonumber(record.health)
                    record.health = math.max(0, record.health
                        - math.max(0, tonumber(effect.expectedPower) or 0))
                    projectedThreat = (beforeHealth - record.health)
                        * (tonumber(effect.threatMultiplier) or 0)
                    if record.health <= 0 then
                        record.dead, record.projectedDefeated = true, true
                    end
                else
                    record.projectedThreatTimingUnknown = true
                end
                local actor = candidate.action.facts.damageActor
                    or candidate.action.facts.effectActor
                    or candidate.action.actor or "player"
                PlayerThreat:AddScaled(record, actor, projectedThreat,
                    effect.playerThreatExact)
                if effect.collateral then record.projectedCollateralHit = true end
            end
        end
    end
    syncActive(out)
    return true
end

function H:ApplySelectedDamage(out, amount)
    local target = activeTarget(out)
    if target then
        if not target.healthExact then return false, nil end
        local beforeHealth = tonumber(target.health) or 0
        target.health = math.max(0, (tonumber(target.health) or 0)
            - math.max(0, tonumber(amount) or 0))
        if target.health <= 0 then
            target.dead, target.projectedDefeated = true, true
        end
        syncActive(out)
        return true, beforeHealth - target.health
    end
    if not out.targetHealthExact then return false, nil end
    local beforeHealth = tonumber(out.targetHealth) or 0
    out.targetHealth = math.max(0, out.targetHealth
        - math.max(0, tonumber(amount) or 0))
    return true, beforeHealth - out.targetHealth
end

function H:ApplyPrimaryThreat(out, candidate, context)
    return PrimaryThreat and PrimaryThreat:Apply(out, candidate, context) or false
end

function H:ProjectPetTaunt(out, candidate, action)
    local record = activeTarget(out)
    local pet = out and out.actors and out.actors.pet
    if not (record and record.threat and pet) then return end
    local delivery = math.max(0, math.min(1,
        tonumber(candidate.effectDelivery) or 1))
    record.threat.tauntDelivery = delivery
    record.threat.projectedSource = action and action.name
    if delivery >= 0.999 then
        record.tauntFocusUntil, record.tauntFocusExpired = nil, nil
        record.projectedTauntedByPlayer = nil
        record.threat.projectedOwnershipUnknown = nil
        record.threat.projectedPlayerHasAggro = false
        record.threat.projectedPetHasAggro = true
        record.threat.projectedVictimGuid = pet.guid
        record.projectedTauntedByPet = true
    else
        record.threat.projectedTauntUncertain = delivery > 0
    end
end

function H:FinalizeSelected(out, candidate, facts)
    local target = activeTarget(out)
    local castEvents = XelAssist.Graph.HostileCastEvents
    local earthShockHandled = false
    if ShamanEarthShock then
        local _, handled = ShamanEarthShock:Apply(out, candidate)
        earthShockHandled = handled == true
    end
    local exactInterrupt = not earthShockHandled and castEvents
        and castEvents:Interrupt(out, candidate, facts) or false
    if not earthShockHandled and not exactInterrupt
        and (facts.kind == "interrupt" or facts.interrupt)
        and out.targetCasting then
        local prior = out.targetCastProbability
        if prior == nil then prior = 1 end
        local probability = prior * (1 - math.max(0, math.min(1,
            candidate.effectDelivery or 1)))
        out.targetCastProbability = probability
        out.targetCasting = probability > 0.05
        if target then
            target.castProbability, target.casting = probability,
                out.targetCasting
        end
    end
    local exactCast = XelAssist.Graph.HostileCastState
        and XelAssist.Graph.HostileCastState:Find(out, out.targetGUID)
    if not exactCast and out.targetCasting and out.targetCastRemaining
        and out.time >= out.targetCastRemaining then
        out.targetCasting, out.targetCastProbability = false, 0
        if target then target.casting, target.castProbability = false, 0 end
    end
    if target and target.healthExact and target.health <= 0 then
        target.dead, target.projectedDefeated = true, true
    end
    if target then syncActive(out) end
    if out.targetHealthExact and out.targetHealth <= 0 then
        out.hostile = false
        if target and State.RefreshHostileRecord then
            State:RefreshHostileRecord(out, target.key)
        end
    end
end
