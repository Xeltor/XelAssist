-- Search-pure Windfury Totem consequence.  Placement itself has no invented
-- duration utility; descendants earn value only from exact main-hand attacks.
-- Group roots fail closed until recipient attribution and fanout are modeled.
XelAssist.Graph.ShamanWindfuryTotem = {}
local W = XelAssist.Graph.ShamanWindfuryTotem

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
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

local function owner()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.ShamanWindfuryTotem
end

local function exactEffect(value)
    local runtime = owner()
    local chance = value and finite(value.procChance)
    return runtime and type(value) == "table" and value.exact == true
        and value.kind == "playerMainHandExtraAttackProc"
        and value.auraSpellId == runtime.AURA_ID
        and value.triggerSpellId == runtime.TRIGGER_ID
        and value.procFlags == runtime.PROC_FLAGS
        and chance == runtime.PROC_CHANCE
        and value.extraAttacks == runtime.EXTRA_ATTACKS
        and value.weaponHand == "main"
        and value.mainHandWhite == true
        and value.mainHandMeleeAbility == true
        and value.resetsMainHandTimer == true
        and value.recursive == false and value or nil
end

local function airRow(state)
    local runtime = owner()
    local snapshot = state and state.totems
    local row = runtime and snapshot and snapshot.bySlot
        and snapshot.bySlot[runtime.SLOT]
    if not (snapshot and snapshot.available == true and row
        and row.exact == true and row.slot == runtime.SLOT
        and row.element == runtime.ELEMENT) then return nil end
    return row
end

function W:Attach(state)
    if type(state) ~= "table" then return false end
    local runtime = owner()
    local observed = runtime and runtime:ObserveRoot() or nil
    local out = { available = false, exact = false, active = false,
        source = "exact solo Windfury aura and air-slot identity" }
    state.shamanWindfuryTotem = out
    if not (observed and observed.available == true
        and observed.exact == true) then
        out.reason = observed and observed.reason
            or "Windfury Totem root evidence unavailable"
        return false
    end
    out.solo, out.grouped = observed.solo, observed.grouped
    out.raidMembers, out.partyMembers = observed.raidMembers,
        observed.partyMembers
    if observed.grouped then
        out.reason = observed.reason
            or "Windfury Totem party fanout is unresolved"
        out.fanoutUnresolved = true
        return false
    end
    local row = airRow(state)
    if not row then
        out.reason = "exact Shaman air-totem slot unavailable"
        return false
    end
    if observed.auraActive == true
        and (row.active ~= true or row.spellId ~= runtime.ACTION_ID) then
        out.reason = "Windfury aura and air-totem identity are incoherent"
        return false
    end
    out.available, out.exact = true, true
    out.active = observed.auraActive == true
        and row.active == true and row.spellId == runtime.ACTION_ID
    out.rootAuraActive = observed.auraActive == true
    out.sourceSpellId = out.active and runtime.ACTION_ID or nil
    return true
end

function W:Copy(source, target)
    if not (source and target and source.shamanWindfuryTotem) then return false end
    target.shamanWindfuryTotem = copy(source.shamanWindfuryTotem)
    return true
end

local function active(state)
    local runtime = owner()
    local component, row = state and state.shamanWindfuryTotem,
        airRow(state)
    if not (runtime and component and component.available == true
        and component.exact == true and component.solo == true
        and component.grouped == false and component.active == true
        and row and row.active == true
        and row.spellId == runtime.ACTION_ID) then return nil end
    if component.projected == true then
        if row.projected ~= true or not exactEffect(row.effect) then return nil end
    elseif component.rootAuraActive ~= true then return nil end
    return component
end

function W:IsActive(state)
    return active(state) ~= nil
end

local function projectionEvidence(projection)
    local runtime = owner()
    local found = runtime and projection and projection.action
        and runtime:Evidence(projection.action) or nil
    local effect = exactEffect(projection and projection.effect)
    if not (found and effect and projection.kind == "totemPlacement"
        and projection.slot == runtime.SLOT
        and projection.element == runtime.ELEMENT
        and projection.downstreamSpellId == runtime.ACTION_ID
        and projection.downstreamElement == runtime.ELEMENT
        and projection.range and projection.range.exact == true
        and projection.range.center == "totem"
        and projection.range.minimum == 0
        and projection.range.maximum == runtime.RADIUS
        and projection.recipients and projection.recipients.exact == true
        and projection.recipients.center == "totem"
        and projection.recipients.relation == "party"
        and projection.recipients.shape == "area"
        and projection.recipients.graphScope == "soloSelf") then return nil end
    return found, effect
end

function W:Prepare(state, projection)
    local found, effect = projectionEvidence(projection)
    if not found then return nil, nil, false end
    local component = state and state.shamanWindfuryTotem
    if not (component and component.available == true
        and component.exact == true and component.solo == true
        and component.grouped == false) then
        return nil, component and component.reason
            or "Windfury Totem solo recipient evidence unavailable", true
    end
    projection.shamanWindfuryTotem = copy(effect)
    return projection, nil, true
end

function W:Score(context, projection)
    local prepared, reason, handled = self:Prepare(
        context and context.state, projection)
    if not handled or not prepared then return false, reason end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.reason = "enables main-hand extra attacks"
    return true
end

-- TotemState must apply first, proving replacement and lifetime atomically.
function W:Apply(state, projection)
    local prepared, _, handled = self:Prepare(state, projection)
    local runtime = owner()
    local row, component = airRow(state), state and state.shamanWindfuryTotem
    if not (handled and prepared and runtime and row and component
        and row.active == true and row.projected == true
        and row.spellId == runtime.ACTION_ID
        and exactEffect(row.effect)) then return false end
    component.active, component.projected = true, true
    component.rootAuraActive = nil
    component.sourceSpellId = runtime.ACTION_ID
    component.source = "projected exact solo Windfury Totem placement"
    return true
end

local function qualifying(state, action, kind, resistance, delivery,
    targetRelation, targetGUID)
    if not active(state) or targetRelation ~= "hostile" or targetGUID == nil
        or (action and action.actor and action.actor ~= "player")
        or kind ~= "damage" and kind ~= "builder" then return nil end
    delivery = finite(delivery)
    local round = state.playerAttack and state.playerAttack.attackRound
    if not (delivery and delivery >= 0 and delivery <= 1
        and resistance and resistance.deliveryModel == "physical"
        and resistance.deliverySubtype == "melee"
        and resistance.weaponHand == "main"
        and round and round.normalDamageKnown == true
        and finite(round.power) and round.power >= 0
        and round.targetGuid == targetGUID) then return nil end
    return delivery, round
end

-- Call after resistance projection and before ordinary damage scoring.
function W:Adjust(context)
    if context and context.onNextSwing then return false end
    local action = context and (context.effectAction or context.action)
    local descriptor = context and context.descriptor
    local delivery = qualifying(context and context.state, action,
        context and context.kind, context and context.resistance,
        context and context.effectDelivery,
        descriptor and descriptor.relation, descriptor and descriptor.guid)
    if not delivery then return false end
    local swings = XelAssist.Graph.PlayerSwings
    local expected = swings and swings:ExpectedWhite(
        context.state, descriptor.guid) or nil
    expected = finite(expected)
    local current = finite(context.expectedPower)
    local runtime = owner()
    if not (expected and expected >= 0 and current and current >= 0
        and runtime) then return false end
    local bonus = expected * runtime.PROC_CHANCE * delivery
    context.expectedPower = current + bonus
    context.windfuryExpectedExtraAttackPower = bonus
    context.windfuryProcChance = runtime.PROC_CHANCE
    context.estimated = true
    return true
end

local WHITE_ACTION = { name = "Attack", actor = "player", facts = {
    kind = "damage", school = 0, melee = true, whiteAttack = true,
    weaponHand = "main", deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
} }
local WHITE_TOOLTIP = { school = 0 }

-- The caller still applies the initiating swing's delivery probability.  This
-- helper adds only the conditional extra attack's own delivery probability.
function W:WhiteSwingRawPower(state, targetGUID, rawPower)
    if not active(state) then return rawPower, nil, false, nil end
    rawPower = finite(rawPower)
    local round = state.playerAttack and state.playerAttack.attackRound
    if not (rawPower and rawPower >= 0 and round
        and round.normalDamageKnown == true
        and round.targetGuid == targetGUID) then
        return nil, "Windfury white-swing magnitude unavailable", true, nil
    end
    local resistance, effects = XelAssist.Combat
        and XelAssist.Combat.Resistance, XelAssist.Graph.Effects
    if not (resistance and effects and type(resistance.Estimate) == "function"
        and type(effects.Decision) == "function") then
        return nil, "Windfury extra-attack delivery unavailable", true, nil
    end
    local estimate = resistance:Estimate(
        WHITE_ACTION, "target", WHITE_TOOLTIP, state)
    local decision = finite(effects:Decision(estimate, state, true))
    if not decision or decision < 0 or decision > 1 then
        return nil, "Windfury extra-attack delivery unavailable", true, nil
    end
    local runtime = owner()
    return rawPower * (1 + runtime.PROC_CHANCE * decision), nil, true,
        decision
end

local function invalidateRound(state)
    local round = state and state.playerAttack and state.playerAttack.attackRound
    if not round then return false end
    round.projectable, round.phaseKnown = false, false
    round.reason = "Windfury proc makes main-hand timer stochastic"
    return true
end

function W:AfterCandidate(state, candidate)
    if candidate and candidate.onNextSwing then return false end
    local action = candidate and (candidate.effectAction or candidate.action)
    local facts = action and action.facts or {}
    local delivery = qualifying(state, action, facts.kind,
        candidate and candidate.resistance,
        candidate and candidate.effectDelivery,
        candidate and candidate.targetRelation,
        candidate and candidate.targetGUID)
    return delivery and delivery > 0 and invalidateRound(state) or false
end

function W:AfterWhiteSwing(state, targetGUID, initiatingDelivery)
    initiatingDelivery = finite(initiatingDelivery)
    if not active(state) or not initiatingDelivery
        or initiatingDelivery <= 0 then return false end
    local round = state.playerAttack and state.playerAttack.attackRound
    if not (round and round.targetGuid == targetGUID) then return false end
    return invalidateRound(state)
end
