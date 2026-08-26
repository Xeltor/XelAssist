-- Cache invalidation for player action and equipment evidence. The action
-- catalogue, tooltip facts and reactive spell evidence share one lifecycle;
-- equipment-derived hit and penetration facts retain their narrower hook.
XelAssist.Game.CapabilityInvalidation = {}
local I = XelAssist.Game.CapabilityInvalidation

function I:All(capabilities)
    capabilities.spellSlots = nil
    capabilities.spellRanks = nil
    capabilities.actions = nil
    capabilities.costs = nil
    capabilities.tooltipFacts = nil
    capabilities.talentPoints = nil
    local reactive = XelAssist.Game.Player
        and XelAssist.Game.Player.ReactiveEvidence
    if reactive then reactive:Invalidate() end
    local persistent = XelAssist.Game.Caster
        and XelAssist.Game.Caster.PersistentDamage
    if persistent then persistent:Invalidate() end
    local control = XelAssist.Game.CrowdControl
    if control then control:Invalidate() end
    local warriorRage = XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorRage
    if warriorRage then warriorRage:Invalidate() end
    local stanceEffects = XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorStanceEffects
    if stanceEffects then stanceEffects:Invalidate() end
    local inference = XelAssist.Game.ActionInference
    if inference then inference:InvalidateClass() end
    capabilities:InvalidateEquipment()
end
