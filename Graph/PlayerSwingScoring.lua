-- Marginal utility for player on-next-swing actions. The state transition
-- applies the full yellow hit; scoring values only its improvement over the
-- ordinary white main-hand result that it replaces.
XelAssist.Graph.PlayerSwingScoring = {}
local P = XelAssist.Graph.PlayerSwingScoring
local Effects = XelAssist.Graph.Effects

local WHITE_ACTION = { name = "Attack", actor = "player", facts = {
    kind = "damage", school = 0, melee = true, whiteAttack = true,
    weaponHand = "main", deliveryModel = "physical",
    deliverySubtype = "melee", usesWeaponSkill = true,
} }
local WHITE_TOOLTIP = { school = 0 }

function P:Project(context)
    if not context.onNextSwing then return end
    local round = context.state.playerAttack
        and context.state.playerAttack.attackRound
    local raw = round and tonumber(round.power)
    if not raw then
        context.displacedWhitePower, context.marginalPower = 0,
            context.expectedPower
        return
    end
    local delivery = 1
    if XelAssist.Combat.Resistance then
        local state = Effects:StateAtImpact(context.state,
            context.impactDelay or 0)
        local estimate = XelAssist.Combat.Resistance:Estimate(
            WHITE_ACTION, context.target, WHITE_TOOLTIP, state)
        delivery = Effects:Decision(estimate, state, true)
    end
    context.displacedWhitePower = math.max(0,
        raw * (tonumber(delivery) or 1))
    context.marginalPower = math.max(0,
        context.expectedPower - context.displacedWhitePower)
end

function P:Effective(context, targetHealth, healthExact)
    local expected = context.expectedPower
    local full = healthExact and targetHealth > 0
        and math.min(expected, targetHealth) or expected
    local displaced = context.onNextSwing
        and (healthExact and targetHealth > 0
            and math.min(context.displacedWhitePower or 0, targetHealth)
            or context.displacedWhitePower or 0) or 0
    local effective = context.onNextSwing
        and math.max(0, full - displaced) or full
    context.fullEffectivePower = full
    context.marginalEffectivePower = context.onNextSwing and effective or nil
    return effective
end

function P:Timing(context)
    return context.onNextSwing and context.impactDelay or context.downtime
end

function P:DamageValue(context, effective)
    local base = context.onNextSwing and 0 or 250
    return base + effective * 4 / math.max(0.5, self:Timing(context) or 0)
end

function P:Finishes(context, targetHealth, healthExact)
    return healthExact and targetHealth > 0
        and context.expectedPower >= targetHealth
        and (not context.onNextSwing
            or (context.displacedWhitePower or 0) < targetHealth)
end
