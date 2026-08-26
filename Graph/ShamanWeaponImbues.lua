-- Main-hand Shaman temporary-enchant lifecycle and ordinary white-hit
-- consequences. No imbue order is encoded: each supported edge earns value
-- only from the exact attacks it changes before the selected target dies.
XelAssist.Graph.ShamanWeaponImbues = {}
local W = XelAssist.Graph.ShamanWeaponImbues
W.WHITE_ACTION = { name = "Attack", actor = "player", facts = {
    kind = "damage", school = 0, melee = true, whiteAttack = true,
    weaponHand = "main", deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true } }
W.WHITE_TOOLTIP = { school = 0 }
W.FLAME_ACTION = { name = "Flametongue Weapon", actor = "player", facts = {
    kind = "damage", school = 2, deliveryModel = "spell",
    deliverySubtype = "magic", spell = true } }
W.FLAME_TOOLTIP = { school = 2 }

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.ShamanWeaponImbues
end
local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end
local function evidence(subject)
    local owner = runtime()
    return owner and owner.Evidence and owner:Evidence(subject) or nil
end
local function component(state)
    local value = state and state.shamanWeaponImbue
    if not (type(value) == "table" and value.available == true
        and value.exact == true and value.hand == "main"
        and value.replacementFamily == "mainHandTemporaryEnchant"
        and (value.active == true or value.active == false)) then return nil end
    return value
end

function W:Attach(state, classToken)
    local owner = runtime()
    local root = owner and owner:Snapshot()
    if not (state and classToken == "SHAMAN" and root
        and root.available == true and root.exact == true) then return false end
    state.shamanWeaponImbue = copy(root)
    return component(state) ~= nil
end

function W:Copy(source, target)
    target.shamanWeaponImbue = source and source.shamanWeaponImbue
        and copy(source.shamanWeaponImbue) or nil
    return component(target) ~= nil
end

local function exactPlayer(state, descriptor)
    local player = state and state.actors and state.actors.player
    return descriptor and descriptor.relation == "self"
        and (descriptor.unit == "player" or descriptor.guid
            and player and descriptor.guid == player.guid)
end
local function exactMainRound(state)
    local attack = state and state.playerAttack
    local round = attack and attack.attackRound
    if not (round and round.verified == true and round.projectable == true
        and round.speedTrusted == true and round.normalDamageKnown == true
        and finite(round.speed, 0.01, 20)
        and finite(round.interval, 0.01, 21)
        and finite(round.power, 0, 10000000)) then return nil end
    return round
end

function W:Prepare(action, state, descriptor, facts)
    local found = evidence(facts) or evidence(action)
    if not found then return nil, "exact weapon imbue evidence unavailable", true end
    if found.effectKnown ~= true then
        return nil, found.reason or "weapon imbue consequence unavailable", true
    end
    local current = component(state)
    if not current then return nil, "main-hand enchant state unavailable", true end
    if not exactPlayer(state, descriptor) then
        return nil, "weapon imbue requires the exact player", true
    end
    if not exactMainRound(state) then
        return nil, "exact main-hand weapon evidence unavailable", true
    end
    if current.active and current.enchantId == found.enchantId
        and (tonumber(current.remaining) or 0) > 30 then
        return nil, "same weapon imbue is already active", true
    end
    return { classMechanic = "shamanWeaponImbue",
        shamanWeaponImbueTransition = {
            kind = "shamanWeaponImbue", exact = true,
            spellId = found.spellId, enchantId = found.enchantId,
            childSpellId = found.childSpellId, family = found.family,
            duration = found.duration, effectKnown = true,
            attackPower = found.attackPower,
            threatMultiplier = found.threatMultiplier,
            school = found.school, speedScalar = found.speedScalar,
            procChance = found.procChance, source = found.source } }, nil, true
end

local function transition(projection)
    local value = projection and projection.shamanWeaponImbueTransition
    local owner = runtime()
    local spec = value and owner and owner.RANKS[value.spellId]
    if not (type(value) == "table" and value.exact == true
        and value.kind == "shamanWeaponImbue" and value.effectKnown == true
        and spec and value.family == spec.family
        and value.enchantId == spec.enchantId
        and value.childSpellId == spec.child and value.duration == 3600) then
        return nil
    end
    if value.family == "rockbiter" then
        if not (finite(value.attackPower, 0.0001, 100000)
            and value.threatMultiplier == 1.35) then return nil end
    elseif value.family == "flametongue" then
        if value.school ~= 2 or value.procChance ~= 1
            or not finite(value.speedScalar, 0.0001, 100000) then return nil end
    else return nil end
    return value
end

local function survival(state)
    local learned = state and state.targetSurvival
    if not (learned and learned.available == true
        and state.targetHealthExact == true
        and finite(state.targetHealth, 0, 100000000)) then return nil end
    local lower = finite(learned.lowerTimeToDie, 0, 3600)
    local upper = finite(learned.upperTimeToDie or learned.timeToDie, 0, 3600)
    if not lower or not upper or upper < lower then return nil end
    return (lower + upper) / 2
end

local function benefitPerSwing(state, value, round)
    if value.family == "rockbiter" then
        return value.attackPower / 14 * round.speed
    end
    local raw = value.speedScalar * round.speed
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    local effects = XelAssist.Graph and XelAssist.Graph.Effects
    if not (resistance and effects) then return nil end
    local action = { name = "Flametongue Weapon", actor = "player",
        facts = { kind = "damage", school = 2, deliveryModel = "spell",
            deliverySubtype = "magic", spell = true } }
    local estimate = resistance:Estimate(action, "target", { school = 2 }, state)
    local decision = finite(effects:Decision(estimate, state, true), 0, 1)
    return decision and raw * decision or nil
end

function W:Score(context, projection)
    local value = transition(projection)
    local round = exactMainRound(context and context.state)
    if not (value and round) then
        return false, "weapon imbue transition unavailable"
    end
    local perSwing = benefitPerSwing(context.state, value, round)
    local seconds = survival(context.state)
    if not (perSwing and seconds) then
        context.value, context.reason = 0,
            "weapon imbue awaits exact target survival"
        context.power, context.expectedPower, context.effectivePower = 0, 0, 0
        context.estimated = true
        return true
    end
    local swings = math.max(0, seconds / round.interval)
    local bonus = math.min(context.state.targetHealth, perSwing * swings)
    context.power, context.expectedPower, context.effectivePower = 0, bonus, bonus
    context.value = bonus * 4
        / math.max(0.5, tonumber(context.downtime) or 0)
    context.reason = value.family == "rockbiter"
        and "adds main-hand damage and threat before target death"
        or "adds Fire damage to main-hand hits before target death"
    context.estimated = true
    return true
end

function W:Apply(state, candidate)
    local value = transition(candidate and candidate.classMechanicProjection)
    local current = component(state)
    if not (value and current) then return false end
    current.active, current.remaining = true, value.duration
    current.enchantId, current.spellId = value.enchantId, value.spellId
    current.childSpellId, current.family = value.childSpellId, value.family
    current.attackPower, current.threatMultiplier =
        value.attackPower, value.threatMultiplier
    current.school, current.speedScalar, current.procChance =
        value.school, value.speedScalar, value.procChance
    current.source = value.source
    return true
end

function W:Advance(state, elapsed)
    local current = component(state)
    elapsed = tonumber(elapsed)
    if not (current and current.active and elapsed and elapsed > 0) then
        return false
    end
    current.remaining = math.max(0,
        (tonumber(current.remaining) or 0) - elapsed)
    if current.remaining <= 0 then
        current.active, current.enchantId, current.family = false, nil, nil
    end
    return true
end

function W:MainHandConsequences(state, targetGuid)
    local current = component(state)
    local round = exactMainRound(state)
    if not (current and current.active == true and round
        and round.targetGuid == targetGuid) then return nil end
    if current.family == "rockbiter"
        and finite(current.attackPower, 0.0001, 100000)
        and current.threatMultiplier == 1.35 then
        return { exact = true,
            physicalBonus = current.attackPower / 14 * round.speed,
            threatMultiplier = current.threatMultiplier }
    elseif current.family == "flametongue" and current.school == 2
        and current.procChance == 1
        and finite(current.speedScalar, 0.0001, 100000) then
        return { exact = true, elementalSchool = 2,
            elementalRaw = current.speedScalar * round.speed,
            threatMultiplier = 1 }
    end
    return nil
end

local function whiteDelivery(state)
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    local effects = XelAssist.Graph and XelAssist.Graph.Effects
    if not (resistance and effects) then return nil end
    local estimate = resistance:Estimate(
        W.WHITE_ACTION, "target", W.WHITE_TOOLTIP, state)
    return finite(effects:Decision(estimate, state, true), 0, 1)
end

function W:ResolveMainHand(state, targetGuid, raw, apply)
    local consequence = self:MainHandConsequences(state, targetGuid)
    if not consequence then return nil, nil, false end
    raw = finite(raw, 0, 10000000)
    if not (raw and type(apply) == "function") then
        return nil, "weapon imbue swing input unavailable", true
    end
    local dealt = apply(self.WHITE_ACTION, self.WHITE_TOOLTIP,
        raw + (consequence.physicalBonus or 0),
        consequence.threatMultiplier or 1)
    if dealt == nil then return nil, "imbued physical hit unavailable", true end
    if consequence.elementalRaw then
        local delivery = whiteDelivery(state)
        if not delivery then
            return dealt, "Flametongue joint delivery unavailable", true
        end
        local flame = apply(self.FLAME_ACTION, self.FLAME_TOOLTIP,
            consequence.elementalRaw * delivery,
            consequence.threatMultiplier or 1)
        if flame == nil then
            return dealt, "Flametongue damage unavailable", true
        end
    end
    return dealt, nil, true
end
