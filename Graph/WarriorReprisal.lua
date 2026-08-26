-- Search-pure Revenge damage adjustment from captured Reprisal evidence.
XelAssist.Graph.WarriorReprisal = {}
local R = XelAssist.Graph.WarriorReprisal

function R:AdjustPower(action, tooltip, power)
    local found = tooltip and tooltip.warriorReprisalEvidence
    if not (action and action.facts and action.facts.warriorRevengeThreat == true
        and type(found) == "table" and found.available == true
        and found.exact == true and found.learned == true
        and found.portfolio == "warriorReprisal"
        and (found.rank == 1 and found.passiveSpellId == 51593
            and found.damagePercent == 25 and found.refundChance == 0.5
          or found.rank == 2 and found.passiveSpellId == 51594
            and found.damagePercent == 50 and found.refundChance == 1)
        and found.refundMode == "withheld-private-success-trigger"
        and type(found.damageModifier) == "table"
        and found.damageModifier.exact == true
        and found.damageModifier.operation == 0
        and found.damageModifier.flat == 0
        and found.damageModifier.percent == found.damagePercent
        and tonumber(found.damageModifier.changed) ~= 0
        and tonumber(power) and power >= 0) then return power, false end
    return power * (1 + found.damagePercent / 100), true
end
