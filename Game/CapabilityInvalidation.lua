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
    capabilities:InvalidateEquipment()
end
