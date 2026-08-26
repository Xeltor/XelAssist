-- Exact boundary for area-shaped on-next-swing attacks. A target-centered DBC
-- chain proves the selected origin, but not the server-selected secondary.
-- Credit the former and invalidate possible secondary records at impact.
XelAssist.Graph.PlayerSwingArea = {}
local A = XelAssist.Graph.PlayerSwingArea

function A:SelectedOrigin(tooltip)
    local topology = tooltip and tooltip.topology
    local hostile = topology and topology.hostile
    if not (topology and topology.available == true
        and type(hostile) == "table" and table.getn(hostile) == 1) then
        return false
    end
    local effect = hostile[1]
    return effect and effect.relation == "hostile"
        and effect.shape == "chain" and effect.center == "target"
        and tonumber(effect.maxTargets) and effect.maxTargets >= 2
end

function A:MarkSecondariesUnknown(state, primaryGuid)
    local hostiles, index = state and state.hostiles, nil
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        local record = hostiles.byKey and hostiles.byKey[hostiles.order[index]]
        if record and record.guid ~= primaryGuid and record.dead ~= true
            and record.projectedDefeated ~= true then
            record.healthExact = false
            record.playerSwingDamageUnknown = true
            record.threat = record.threat or {}
            record.threat.playerDeltaExact = false
            record.playerSwingUnknownReason =
                "next-swing secondary recipient unresolved"
        end
    end
end
