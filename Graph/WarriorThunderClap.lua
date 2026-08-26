-- Search-pure Thunder Clap threat contract. Direct area damage and collateral
-- ownership stay generic; this leaf proves that delivered damage creates one
-- 2.5x packet on each resolved hostile and enforces the DBC four-target cap.
XelAssist.Graph.WarriorThunderClap = {}
local T = XelAssist.Graph.WarriorThunderClap

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorThunderClap
end

local function evidence(action, tooltip)
    local owner = runtime()
    return owner and owner.CapturedEvidence
        and owner:CapturedEvidence(action, tooltip) or nil
end

local function nonNegative(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < 0 then return nil end
    return value
end

local function deliveredDamage(context)
    if not context or context.onNextSwing == true then return nil end
    return nonNegative(context.fullEffectivePower
        or context.effectivePower or context.expectedPower)
end

function T:Is(action)
    return action and action.facts
        and action.facts.warriorThunderClap == true
end

function T:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

function T:Blocker(action, state, descriptor, tooltip)
    if not self:Is(action) then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Thunder Clap threat must be player-owned", true
    end
    if not evidence(action, tooltip) then
        return "Thunder Clap threat evidence unavailable", true
    end
    if not (descriptor and descriptor.relation == "hostile") then
        return "Thunder Clap requires a hostile recipient", true
    end
    return nil, true
end

-- Rebuild both policy lanes from delivered direct damage. This also prevents
-- generic threat utility from multiplying the profile a second time.
function T:Augment(context, threat, valueThreat)
    local action = context and context.action
    if not self:Is(action) then return threat, valueThreat, false, nil end
    local found = evidence(action, context and context.tooltip)
    threat, valueThreat = nonNegative(threat), nonNegative(valueThreat)
    local delivered = deliveredDamage(context)
    if not found or threat == nil or valueThreat == nil
        or delivered == nil
        or context.kind ~= "damage"
        or context.facts.threat ~= found.damageThreatMultiplier then
        return nil, nil, true, "Thunder Clap threat context unavailable"
    end
    local expected = delivered * found.damageThreatMultiplier
    if math.abs(threat - expected) > math.max(1, expected) * 0.000000001 then
        return nil, nil, true, "Thunder Clap delivered threat is incoherent"
    end
    context.warriorThunderClapDamageThreatMultiplier =
        found.damageThreatMultiplier
    context.warriorThunderClapThreatProfileExact =
        found.runtimeVerified == true
    context.estimated = context.estimated or found.runtimeVerified ~= true
    return expected, expected, true, nil
end

-- Applied damage is already delivery-, mitigation-, and health-capped. There
-- is no target-global flat packet and the slow never enters this calculation.
function T:AppliedThreat(context, candidate, appliedDamage)
    local action = context and context.action
    if not self:Is(action) then return nil, nil, false, nil end
    local tooltip = candidate and candidate.tooltip
        or context and context.targetFacts
    local found = evidence(action, tooltip)
    appliedDamage = nonNegative(appliedDamage)
    if not found or appliedDamage == nil then
        return nil, nil, true, "Thunder Clap threat transition unavailable"
    end
    return appliedDamage * found.damageThreatMultiplier,
        found.runtimeVerified == true, true, nil
end

local function alive(record)
    return record and record.dead ~= true and record.projectedDefeated ~= true
        and not (record.healthExact == true
            and (tonumber(record.health) or 0) <= 0)
end

local function observedSlow(record, action, at)
    local projected = record and record.meleeAttackTimeEffects
        and record.meleeAttackTimeEffects.thunderClap
    if projected and projected.exact == true
        and tonumber(projected.expiresAt)
        and projected.expiresAt > (tonumber(at) or 0) then return true end
    local auras = record and record.harmfulAuras
    if not (auras and auras.available == true
        and type(auras.byName) == "table") then return nil end
    local aura = auras.byName[action.name]
    if not aura then return false end
    if tonumber(aura.remaining) and aura.remaining > 0
        and (aura.spellId == nil or tonumber(aura.spellId)) then return true end
    return nil
end

-- VMaNGOS changes the interval used by the next ResetAttackTimer; it does not
-- rescale an attack timer already counting down. HostileSwings therefore owns
-- the actual future cadence while this portfolio only attaches the exact,
-- recipient-local slow window after a guaranteed delivered effect.
function T:ApplySlow(state, candidate)
    if not (state and candidate and candidate.areaDirectResolved
        and candidate.recipientEffects) or not self:Is(candidate.action) then
        return false
    end
    local owner = runtime()
    local slow = owner and owner.SlowEvidence
        and owner:SlowEvidence(candidate.action, candidate.tooltip) or nil
    if not slow then
        state.warriorThunderClapSlowUnknown = true
        return false
    end
    local applicationAt = tonumber(state.time) or 0
    local expiresAt = applicationAt + slow.duration
    local applied, i = 0, nil
    for i = 1, table.getn(candidate.recipientEffects.order or {}) do
        local key = candidate.recipientEffects.order[i]
        local effect = candidate.recipientEffects.byKey[key]
        local record = state.hostiles and state.hostiles.byKey
            and state.hostiles.byKey[key] or nil
        local existing = record and record.meleeAttackTimeEffects
            and record.meleeAttackTimeEffects.thunderClap
        local projectedActive = existing and existing.exact == true
            and tonumber(existing.expiresAt)
            and existing.expiresAt > applicationAt
        local alreadySlowed = observedSlow(
            record, candidate.action, applicationAt)
        if effect and record and record.guid == effect.guid and alive(record)
            and alreadySlowed ~= nil
            and tonumber(effect.delivery) and effect.delivery >= 0.999 then
            record.meleeAttackTimeEffects = record.meleeAttackTimeEffects or {}
            if projectedActive then
                existing.spellId, existing.appliedAt, existing.expiresAt =
                    slow.spellId, applicationAt, expiresAt
            else
                record.meleeAttackTimeEffects.thunderClap = {
                    spellId = slow.spellId, multiplier = slow.intervalMultiplier,
                    appliedAt = applicationAt, expiresAt = expiresAt,
                    observedMultiplier = alreadySlowed
                        and slow.intervalMultiplier or 1,
                    baseIntervals = {}, phaseAdjustment = slow.phaseAdjustment,
                    exact = true }
            end
            applied = applied + 1
        elseif effect and record and alive(record) and
            ((tonumber(effect.delivery) or 0) > 0 or alreadySlowed == nil) then
            record.meleeAttackTimeUnknown = true
            state.incomingProjectionPartial = true
        end
    end
    state.lastWarriorThunderClapSlowRecipients = applied
    return applied > 0
end

function T:Exactness(context, current)
    if not self:Is(context and context.action) then return current end
    local found = evidence(context.action, context.tooltip)
    return found and found.runtimeVerified == true and current ~= false or false
end

local function addKeys(seen, rows, effectIndex)
    local index, row
    for index = 1, table.getn(rows or {}) do
        row = rows[index]
        if (effectIndex == nil or row.effectIndex == effectIndex)
            and row.key ~= nil then seen[row.key] = true end
    end
end

-- Hook after AreaRecipients:Resolve and before any recipient receives value.
-- More in-range candidates than the server cap have an unknowable chosen
-- subset, so the whole direct-area projection must fail closed.
function T:AreaBlocker(context, resolution)
    local action = context and context.action
    if not self:Is(action) then return nil, false end
    local found = evidence(action, context and context.tooltip)
    local groups = resolution and resolution.groups
    local group = type(groups) == "table" and groups[1] or nil
    if not (found and group and table.getn(groups) == 1
        and group.topology and group.topology.maxTargets
            == found.maxAffectedTargets) then
        return "Thunder Clap area evidence unavailable", true
    end
    local seen, key = {}, nil
    for key in pairs(group.byKey or {}) do seen[key] = true end
    addKeys(seen, resolution.collateral, group.effectIndex)
    addKeys(seen, resolution.withheld, group.effectIndex)
    local count = 0
    for key in pairs(seen) do count = count + 1 end
    if count > found.maxAffectedTargets then
        return "Thunder Clap four-target recipient subset is unknown", true
    end
    return nil, true
end
