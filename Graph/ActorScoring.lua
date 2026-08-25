-- Utility scoring for controlled actors, combat control, and sustained attack
-- setup. Core damage/healing/resource scoring stays in Scoring.lua.
XelAssist.Graph.ActorScoring = {}
local A = XelAssist.Graph.ActorScoring

function A:Score(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if XelAssist.Graph.CompanionThreat then
        local value, reason = XelAssist.Graph.CompanionThreat:Score(
            state, context.action)
        if reason then
            context.value, context.reason = value, reason
            return true
        end
    end
    if kind == "interrupt" then
        local probability = state.targetCastProbability
        if probability == nil then probability = state.targetCasting and 1 or 0 end
        context.value = state.targetCasting and 5000 * probability or -1000
        context.reason = context.action.actor == "pet"
            and "companion stops the current cast" or "stops the current cast"
    elseif kind == "taunt" then
        context.value, context.reason = state.hasAggro and not state.tank
            and 3800 or 900, "companion takes unwanted aggro"
    elseif kind == "petHeal" then
        local pet = state.actors and state.actors.pet
        local missing = pet and math.max(0, pet.healthMax - pet.health) or 0
        local effective = math.min(context.power, missing)
        context.effectivePower = effective
        context.value, context.reason = effective * 4
            / math.max(0.5, context.downtime)
            + effective / math.max(1, context.cost) * 60,
            "restores the companion efficiently"
        if missing <= 0 then context.value = -1000 end
    elseif facts.petCombatBuff then
        local pet = state.actors and state.actors.pet
        local engaged = pet and pet.targetExists and pet.targetsCurrent
        context.value = engaged and 1450 or 700
        context.reason = engaged and "empowers the active companion"
            or "protects the companion from control"
    elseif kind == "crowdControl" then
        if facts.deferredUntilPetMelee then
            context.value = state.hasAggro and not state.tank and 2050 or 600
            context.reason = "arms the companion's next successful melee control"
        else
            context.value, context.reason = state.hasAggro and not state.tank
                and 2200 or 650, "controls a dangerous target"
        end
    elseif kind == "dispel" then
        context.value, context.reason = 700, "removes a harmful combat effect"
    elseif kind == "summon" then
        context.value, context.reason = 850, "restores a missing companion"
        if facts.summonRole == "tank" and state.groupSize == 0 then
            context.value, context.reason = 1250,
                "brings a companion that can hold solo threat"
        elseif facts.summonRole == "interrupt" and state.targetCasting then
            context.value, context.reason = 1800,
                "brings a companion with an interrupt"
        elseif facts.summonRole == "control"
            and XelAssistCharDB.toggles.petControl then
            context.value, context.reason = 1050,
                "brings a companion with crowd control"
        elseif facts.summonRole == "support" and state.groupSize > 0 then
            context.value, context.reason = 1100, "brings group support"
        end
    elseif kind == "command" then
        local pet = state.actors and state.actors.pet
        if context.action.command == "attack" then
            context.value, context.reason = 850,
                "sends the companion to the current target"
        elseif context.action.command == "passive" then
            context.value, context.reason = 2900,
                "stops the endangered companion from re-engaging"
        else
            local low = pet and pet.healthMax > 0
                and pet.health / pet.healthMax < 0.25
            context.value = low and 2600 or 1000
            context.reason = low and "retreats the endangered companion"
                or "recalls the companion from another target"
        end
    elseif kind == "autoRepeat" then
        local auto = state.autoShot or {}
        local speed = math.max(0.5, tonumber(auto.rangedSpeed) or 2.8)
        local shot = tonumber(auto.shotDamage) or context.power or 0
        context.value = 800 + shot * 4 / speed
        context.reason = "starts sustained ranged attacks"
    else return false end
    return true
end
