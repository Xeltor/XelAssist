-- Branch-local ordinary Rogue poison state and white-hit consequences. Live
-- weapon state is exact; proc generation remains probabilistic and charge use
-- is conservatively charged on the generated attempt before poison delivery.
XelAssist.Graph.RoguePoisons = {}
local P = XelAssist.Graph.RoguePoisons
local seedObserved

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.RoguePoisons
end

local function copy(value, depth)
    if type(value) ~= "table" or depth <= 0 then return value end
    local out, key, entry = {}, nil, nil
    for key, entry in pairs(value) do out[key] = copy(entry, depth - 1) end
    return out
end

local function validHand(hand, name)
    if not (type(hand) == "table" and hand.available == true
        and hand.exact == true and hand.hand == name
        and (hand.active == true or hand.active == false)) then return nil end
    if not hand.active then return hand end
    if not (tonumber(hand.remaining) and hand.remaining > 0
        and tonumber(hand.charges) and hand.charges >= 0
        and tonumber(hand.enchantId)) then return nil end
    if hand.isPoison == true and not (hand.profile
        and hand.profile.valid == true and hand.profile.exact == true
        and hand.profile.enchantId == hand.enchantId) then return nil end
    return hand
end

local function validRoot(root)
    return type(root) == "table" and root.available == true
        and root.exact == true and type(root.hands) == "table"
        and validHand(root.hands.main, "main")
        and validHand(root.hands.off, "off")
end

function P:Attach(state, token)
    local owner = runtime()
    local root = owner and owner:Snapshot()
    if not (state and token == "ROGUE" and validRoot(root)) then return false end
    state.roguePoisons = copy(root, 5)
    if seedObserved then seedObserved(state) end
    return true
end

function P:Copy(source, target)
    target.roguePoisons = source and source.roguePoisons
        and copy(source.roguePoisons, 6) or nil
    return validRoot(target.roguePoisons) ~= nil
end

function P:Advance(state, elapsed)
    local root = state and state.roguePoisons
    elapsed = tonumber(elapsed)
    if not (validRoot(root) and elapsed and elapsed > 0) then return false end
    local _, hand
    for _, hand in pairs(root.hands) do
        if hand.active then
            hand.remaining = math.max(0, hand.remaining - elapsed)
            if hand.remaining <= 0 then
                hand.active, hand.isPoison, hand.profile = false, nil, nil
                hand.charges, hand.enchantId = nil, nil
                hand.spellId, hand.childSpellId = nil, nil
            end
        end
    end
    return true
end

local function poisonAction(profile, kind)
    return { name = "Rogue Poison " .. tostring(profile.child),
        spellId = profile.child, actor = "player", facts = {
            kind = kind, school = 3, spellDelivery = true,
            damageActor = "player", deliveryModel = "spell",
            deliverySubtype = kind == "dot" and "periodic" or "direct",
        } }
end

local WHITE = {
    main = { name = "Attack", actor = "player", facts = {
        kind = "damage", school = 0, melee = true, whiteAttack = true,
        weaponHand = "main", deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true } },
    off = { name = "Attack", actor = "player", facts = {
        kind = "damage", school = 0, melee = true, whiteAttack = true,
        weaponHand = "off", deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = true } },
}

local function landing(action, tooltip, state)
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    if not resistance then return nil end
    local estimate = resistance:Estimate(action, "target", tooltip, state)
    local value = estimate and tonumber(estimate.landChance)
    local effects = XelAssist.Graph.Effects
    if value == nil and effects then
        local _, delivery = effects:Decision(estimate, state, true)
        value = tonumber(delivery)
    end
    if value == nil then return nil end
    return math.max(0, math.min(1, value))
end

local function observedAura(state, child)
    local name, aura
    for name, aura in pairs(state and state.targetAuras or {}) do
        if type(aura) == "table" and aura.spellId == child
            and aura.mine == true then return name, aura end
    end
    return nil, nil
end

local function poisonKey(profile)
    return "XelAssist:RoguePoison:" .. tostring(profile.child)
end

local function priorDeadly(state, profile)
    local key = poisonKey(profile)
    local current = state.auras and state.auras[key]
    if current then return key, current end
    local _, observed = observedAura(state, profile.child)
    if not observed then return key, nil end
    local stacks = math.max(1, math.min(profile.stackCap,
        tonumber(observed.stacks) or 1))
    local mass = {}; mass[stacks] = 1
    local action = poisonAction(profile, "dot")
    return key, { spellId = profile.child,
        remaining = tonumber(observed.remaining) or profile.duration,
        duration = profile.duration, mine = true, target = "target",
        stackMass = mass, expectedStacks = stacks, stacks = stacks,
        periodicRate = profile.damagePerStackTick * stacks / profile.interval,
        periodicRawRate = profile.damagePerStackTick * stacks / profile.interval,
        periodicAction = action, periodicTooltip = { school = 3 },
        periodicInterval = profile.interval,
        periodicNextIn = profile.interval,
        periodicThreatActor = "player", periodicThreatMultiplier = 1,
        applicationProbability = 1,
        source = "exact observed owned Deadly Poison" }
end


local function seedView(view, owner)
    if not (view and owner) then return false end
    view.auras = view.auras or {}
    local _, aura
    for _, aura in pairs(view.targetAuras or {}) do
        local profile = type(aura) == "table" and aura.mine == true
            and owner:ByChild(aura.spellId) or nil
        if profile and profile.family == "deadly" then
            local key, prior = priorDeadly(view, profile)
            if prior and not view.auras[key] then view.auras[key] = prior end
        end
    end
    return true
end

seedObserved = function(state)
    local owner = runtime()
    local hostiles = state and state.hostiles
    if hostiles and hostiles.byKey then
        local i, record
        for i = 1, table.getn(hostiles.order or {}) do
            record = hostiles.byKey[hostiles.order[i]]
            if record then
                record.projectedAuras = record.projectedAuras or {}
                seedView({ targetAuras = record.targetAuras,
                    auras = record.projectedAuras }, owner)
            end
        end
    else seedView(state, owner) end
end

local function addAuraMass(total, aura, cap)
    if type(aura) ~= "table" then return 0 end
    local probability = math.max(0, math.min(1,
        tonumber(aura.applicationProbability) or 1))
    local mass = XelAssist.Graph.StackedModifiers:Mass(aura, cap)
    local stack
    for stack = 0, cap do
        total[stack] = (total[stack] or 0)
            + probability * (mass[stack] or 0)
    end
    return probability
end

local function aggregateMass(prior, cap)
    local total, active = {}, 0
    if prior then
        active = active + addAuraMass(total, prior, cap)
        local i
        for i = 1, table.getn(prior.periodicBranches or {}) do
            active = active + addAuraMass(
                total, prior.periodicBranches[i], cap)
        end
    end
    total[0] = (total[0] or 0) + math.max(0, 1 - active)
    return XelAssist.Graph.StackedModifiers:Mass({ stackMass = total }, cap)
end

local function applyDeadly(state, profile, probability)
    local stacks = XelAssist.Graph.StackedModifiers
    local eventAuras = XelAssist.Graph.EventAuras
    if not (stacks and eventAuras and state
        and probability and probability > 0) then return false end
    state.auras = state.auras or {}
    local key, prior = priorDeadly(state, profile)
    local priorMass = aggregateMass(prior, profile.stackCap)
    local branch = stacks:Application(
        { stackMass = priorMass }, profile.stackCap)
    local successMass = branch.success
    local expected = stacks:Expected(successMass, profile.stackCap)
    local failures = eventAuras:ReplaceStateAura(
        state, key, probability, prior and copy(prior, 8) or nil)
    local action = poisonAction(profile, "dot")
    state.auras[key] = { spellId = profile.child,
        remaining = profile.duration,
        duration = profile.duration, mine = true, target = "target",
        stackMass = successMass, expectedStacks = expected, stacks = expected,
        periodicRate = profile.damagePerStackTick * expected / profile.interval,
        periodicRawRate = profile.damagePerStackTick * expected / profile.interval,
        periodicAction = action, periodicTooltip = { school = 3 },
        periodicInterval = profile.interval,
        periodicNextIn = profile.interval,
        periodicThreatActor = "player", periodicThreatMultiplier = 1,
        periodicBranches = failures,
        applicationProbability = probability,
        source = "probabilistic ordinary Deadly Poison white-hit consequence" }
    return true
end

local function consumeAttempt(hand, probability)
    local charges = tonumber(hand.charges)
    if not charges or charges <= 0 then return 0 end
    probability = math.min(probability, charges)
    hand.charges = math.max(0, charges - probability)
    return probability
end

function P:ResolveWhite(state, target, handName, applyDirect)
    local root = state and state.roguePoisons
    local hand = validRoot(root) and root.hands[handName]
    if not (hand and hand.active and hand.isPoison == true
        and hand.profile and hand.charges > 0) then return false end
    local whiteLanding = landing(WHITE[handName], { school = 0 }, target)
    if whiteLanding == nil then
        return true, "ordinary weapon landing probability unavailable"
    end
    local profile = hand.profile
    local attempt = consumeAttempt(hand,
        whiteLanding * profile.chance / 100)
    if attempt <= 0 then return true end
    if profile.family == "instant" then
        if type(applyDirect) ~= "function" then
            return true, "Instant Poison damage application unavailable"
        end
        local dealt = applyDirect(poisonAction(profile, "damage"),
            { school = 3 }, profile.damageAverage * attempt, 1)
        return true, dealt == nil and "Instant Poison target state unavailable" or nil
    elseif profile.family == "deadly" then
        local poisonLanding = landing(poisonAction(profile, "dot"),
            { school = 3, periodicInterval = profile.interval }, target)
        if poisonLanding == nil then
            return true, "Deadly Poison delivery probability unavailable"
        end
        applyDeadly(target, profile, attempt * poisonLanding)
        return true
    end
    return true, "ordinary utility poison consequence is explicitly uncredited"
end
