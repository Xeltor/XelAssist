-- Search-pure Demoralizing Shout recipient contract. Exact server flat threat
-- is attributed once per successfully affected observed hostile. The aura is
-- projected for duplicate guards, while its dynamic attack-power reduction
-- deliberately earns no defensive value until incoming melee is modelled.
XelAssist.Graph.WarriorDemoralizingShout = {}
local D = XelAssist.Graph.WarriorDemoralizingShout
local State = XelAssist.Graph.State

local MAX_HOSTILES = 5

local function recipients()
    return XelAssist.Graph and XelAssist.Graph.AreaRecipients
end

local function effects()
    return XelAssist.Graph and XelAssist.Graph.Effects
end

local function playerThreat()
    return XelAssist.Graph and XelAssist.Graph.PlayerThreat
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorDemoralizingShout
end

local function evidence(action, tooltip)
    local owner = runtime()
    if not (owner and owner.CapturedEvidence) then return nil, nil end
    return owner:CapturedEvidence(action, tooltip)
end

local function clamp(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then return nil end
    return math.max(0, math.min(1, value))
end

local function selectedRecord(state, descriptor)
    if not (descriptor and descriptor.unit == "target"
        and descriptor.relation == "hostile"
        and descriptor.source == "selected"
        and descriptor.key ~= nil and descriptor.guid ~= nil) then return nil end
    local hostiles = state and state.hostiles
    local record = hostiles and hostiles.byKey
        and hostiles.byKey[descriptor.key] or nil
    if not (record and record.dead ~= true and record.guid == descriptor.guid
        and (hostiles.selectedKey == descriptor.key
            or record.selected == true)) then return nil end
    local supplied = descriptor.record
    if supplied and (supplied ~= record and (supplied.key ~= descriptor.key
        or supplied.guid ~= descriptor.guid)) then return nil end
    return record
end

local function topologyGroup(resolution, found, profile)
    local groups = resolution and resolution.groups
    local group = type(groups) == "table" and groups[1] or nil
    local shape = group and group.topology
    if not (group and table.getn(groups) == 1 and shape
        and shape.effect == 6 and shape.aura == found.attackPowerAura
        and shape.relation == "hostile" and shape.shape == "area"
        and shape.center == "caster" and shape.radiusKnown == true
        and shape.radius == profile.radius and shape.maxTargets == nil) then
        return nil
    end
    return group
end

local function append(rows, seen, key, record, primary, withheld)
    if seen[key] then return true end
    if not (key ~= nil and record and record.guid ~= nil
        and record.dead ~= true) then return false end
    seen[key] = true
    rows.byKey[key] = { key = key, guid = record.guid,
        primary = primary == true, creditWithheld = withheld == true }
    table.insert(rows.order, key)
    return true
end

local function recipientPlan(state, action, descriptor, tooltip)
    local found, profile = evidence(action, tooltip)
    if not (found and profile) then
        return nil, "Demoralizing Shout root evidence unavailable"
    end
    local selected = selectedRecord(state, descriptor)
    if not selected then
        return nil, "Demoralizing Shout requires the selected hostile"
    end
    local owner = recipients()
    if not (owner and owner.Resolve) then
        return nil, "Demoralizing Shout recipient resolver unavailable"
    end
    local resolution = owner:Resolve(state, action, tooltip.topology)
    local group = topologyGroup(resolution, found, profile)
    if not group or group.byKey[descriptor.key] ~= selected then
        return nil, "selected hostile is not proven inside Shout radius"
    end
    local index, row
    for index = 1, table.getn(resolution.collateral or {}) do
        row = resolution.collateral[index]
        if row.effectIndex == group.effectIndex then
            return nil, "Demoralizing Shout would affect an unengaged hostile"
        end
    end
    local rows, seen = { order = {}, byKey = {},
        additionalUnknown = resolution.additionalUnknown == true }, {}
    for index = 1, table.getn(group.order or {}) do
        local key = group.order[index]
        if not append(rows, seen, key, group.byKey[key],
            key == descriptor.key, false) then
            return nil, "Demoralizing Shout recipient identity unavailable"
        end
    end
    for index = 1, table.getn(resolution.withheld or {}) do
        row = resolution.withheld[index]
        if row.effectIndex == group.effectIndex
            and not append(rows, seen, row.key, row.record,
                row.key == descriptor.key, true) then
            return nil, "Demoralizing Shout recipient identity unavailable"
        end
    end
    if table.getn(rows.order) == 0
        or table.getn(rows.order) > MAX_HOSTILES then
        return nil, "Demoralizing Shout recipient set unavailable"
    end
    return rows, nil, found, profile
end

local function localState(state, key)
    if State and State.HostileContext then return State:HostileContext(state, key) end
    return nil
end

local function recipientDelivery(context, row)
    if row.primary then return clamp(context.effectDelivery) end
    local projected = localState(context.state, row.key)
    if not projected then return nil end
    local elapsed = math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    local effectOwner = effects()
    if effectOwner and effectOwner.StateAtImpact then
        projected = effectOwner:StateAtImpact(projected, elapsed)
    end
    local resistanceOwner = XelAssist.Combat and XelAssist.Combat.Resistance
    if not (resistanceOwner and resistanceOwner.Estimate
        and effectOwner and effectOwner.Decision) then return nil end
    local resistance = resistanceOwner:Estimate(
        context.effectAction or context.action, "target",
        context.effectTooltip or context.tooltip, projected)
    if not resistance then return nil end
    local _, delivery = effectOwner:Decision(resistance, projected, false)
    return clamp(delivery)
end

local function threatPolicy(state, record, threat)
    if state.tank then return threat * 0.5 end
    if (tonumber(state.groupSize) or 0) > 0 or state.pet then
        local uncertain = record.threat
            and record.threat.playerDeltaExact == false
        return -threat * ((record.hasPlayerAggro or uncertain) and 3 or 0.25)
    end
    return 0
end

local function buildPackets(context, plan, found)
    local threatOwner = playerThreat()
    if not (threatOwner and threatOwner.Scale) then
        return nil, nil, "player threat scaling unavailable"
    end
    local packets = { order = {}, byKey = {},
        additionalUnknown = plan.additionalUnknown }
    local secondaryValue, index = 0, nil
    for index = 1, table.getn(plan.order) do
        local key, planned = plan.order[index], nil
        planned = plan.byKey[key]
        local record = context.state.hostiles.byKey[key]
        if not (record and record.guid == planned.guid) then
            return nil, nil, "Demoralizing Shout recipient changed"
        end
        local delivery = recipientDelivery(context, planned)
        if delivery == nil then
            return nil, nil, "Demoralizing Shout delivery evidence unavailable"
        end
        local raw = found.flatThreat * delivery
        local scaled, exact, multiplier = threatOwner:Scale(
            context.state, "player", raw, found.school)
        local packet = { key = key, guid = planned.guid,
            primary = planned.primary, creditWithheld = planned.creditWithheld,
            delivery = delivery, flatThreat = found.flatThreat,
            scaledThreat = scaled, threatMultiplier = multiplier,
            playerThreatExact = exact == true and found.runtimeVerified == true }
        packets.byKey[key] = packet
        table.insert(packets.order, key)
        if not packet.primary then
            secondaryValue = secondaryValue
                + threatPolicy(context.state, record, scaled)
        end
    end
    return packets, secondaryValue, nil
end

function D:Is(action)
    return action and action.facts
        and action.facts.warriorDemoralizingShout == true
end

function D:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

function D:Blocker(action, state, descriptor, tooltip)
    if not self:Is(action) then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Demoralizing Shout must be player-owned", true
    end
    local _, reason = recipientPlan(state, action, descriptor, tooltip)
    return reason, true
end

-- Hook before generic debuff utility. ThreatScoring still owns the selected
-- hostile; Finalize adds only the already delivery-weighted secondary lanes.
function D:Score(context)
    if not self:Is(context and context.action) then return false end
    local plan, reason, found = recipientPlan(context.state, context.action,
        context.descriptor, context.tooltip)
    if not plan then
        context.value, context.reason, context.estimated = -100000, reason, true
        return true
    end
    local packets, value
    packets, value, reason = buildPackets(context, plan, found)
    if not packets then
        context.value, context.reason, context.estimated = -100000, reason, true
        return true
    end
    context.power, context.expectedPower = 0, 0
    context.effectivePower, context.fullEffectivePower = 0, 0
    context.value, context.estimated = 0, true
    context.warriorDemoralizingShoutPackets = packets
    context.warriorDemoralizingShoutSecondaryValue = value
    context.reason = "creates recipient-local flat threat"
    return true
end

-- Hook immediately after ThreatScoring. Its confidence factor has already
-- been applied to the selected packet, so apply the same factor exactly once.
function D:Finalize(context)
    local packets = context and context.warriorDemoralizingShoutPackets
    if not packets then return false end
    local value = tonumber(context.warriorDemoralizingShoutSecondaryValue) or 0
    context.value = context.value + value * (context.estimated and 0.88 or 1)
    if value > 0 then
        context.reason = table.getn(packets.order) > 1
            and "builds threat on observed enemies" or context.reason
    elseif value < 0 then
        context.reason = "limits area threat for the group"
    end
    return true
end

-- WarriorThreatPackets can include this leaf without special branches. The
-- selected flat packet deliberately stays generic; only exactness is claimed.
function D:Augment(context, threat, valueThreat)
    return threat, valueThreat, false, nil
end

function D:AppliedThreat(context, candidate, appliedDamage)
    return nil, nil, false, nil
end

local function hostileByKey(state, key)
    if State and State.HostileByKey then return State:HostileByKey(state, key) end
    return state and state.hostiles and state.hostiles.byKey
        and state.hostiles.byKey[key] or nil
end

local function auraEntry(candidate, found, profile, row, prior)
    local delivery = clamp(row.delivery)
    if delivery == nil or delivery <= 0 then return nil end
    local priorProbability = type(prior) == "table"
        and clamp(prior.applicationProbability) or nil
    -- The selected aura was already written by generic ActionEffects for this
    -- same cast. Preserve that probability instead of unioning it twice.
    local probability
    if row.primary and type(prior) == "table" then
        probability = priorProbability or delivery
    else
        local base = priorProbability or 0
        probability = base + (1 - base) * delivery
    end
    local elapsed = math.max(0, (tonumber(candidate.occupancy) or 0)
        - math.max(0, tonumber(candidate.cast) or 0))
    return { warriorDemoralizingShout = true, spellId = found.spellId,
        remaining = row.primary and type(prior) == "table"
            and tonumber(prior.remaining)
            or math.max(0, profile.duration - elapsed),
        duration = profile.duration, applicationProbability = probability,
        mine = true, target = row.primary and "target" or "engaged",
        targetKey = row.key, targetGUID = row.guid,
        attackPowerReductionModeled = false,
        flatThreat = found.flatThreat }
end

-- Hook after generic selected aura/threat application. The primary packet is
-- annotated but never added again; only observed off-targets receive threat.
function D:Apply(state, candidate)
    if not self:Is(candidate and candidate.action) then return false end
    local found, profile = evidence(candidate.action, candidate.tooltip)
    local packets = candidate.warriorDemoralizingShoutPackets
    local name = candidate.action.name
    if not (found and profile and type(packets) == "table"
        and type(packets.order) == "table" and type(packets.byKey) == "table"
        and table.getn(packets.order) <= MAX_HOSTILES
        and type(name) == "string" and name ~= "") then return false end
    local threatOwner = playerThreat()
    if not (threatOwner and threatOwner.Scale
        and threatOwner.AddScaled) then return false end
    local seen, prepared, primaryCount, index = {}, {}, 0, nil
    for index = 1, table.getn(packets.order) do
        local key, row = packets.order[index], nil
        row = packets.byKey[key]
        local record = hostileByKey(state, key)
        if seen[key] or not (row and row.key == key and row.guid ~= nil
            and row.flatThreat == found.flatThreat
            and record and record.guid == row.guid and record.dead ~= true) then
            return false
        end
        seen[key] = true
        local delivery = clamp(row.delivery)
        if delivery == nil then return false end
        if row.primary then
            primaryCount = primaryCount + 1
            if key ~= candidate.targetKey or row.guid ~= candidate.targetGUID then
                return false
            end
        end
        prepared[index] = { row = row, record = record, delivery = delivery }
    end
    if primaryCount ~= 1 then return false end
    for index = 1, table.getn(prepared) do
        local row, record, delivery = prepared[index].row,
            prepared[index].record, prepared[index].delivery
        if not row.primary and delivery > 0 then
            local scaled = threatOwner:Scale(state, "player",
                found.flatThreat * delivery, found.school)
            threatOwner:AddScaled(record, "player", scaled, false)
            record.threat = record.threat or {}
            record.threat.playerDeltaExact = false
            record.threat.containsEstimatedBaseThreat = true
            record.threat.projectedSource = found.source
        end
        record.projectedAuras = record.projectedAuras or {}
        local aura = auraEntry(candidate, found, profile, row,
            record.projectedAuras[name])
        if aura then record.projectedAuras[name] = aura end
        if State and State.RefreshHostileRecord then
            State:RefreshHostileRecord(state, key)
        end
    end
    if State and State.SyncActiveHostile then State:SyncActiveHostile(state) end
    return true
end

function D:Exactness(context, current)
    if not self:Is(context and context.action) then return current end
    local found = evidence(context.action, context.tooltip)
    return found and found.runtimeVerified == true and current ~= false or false
end
