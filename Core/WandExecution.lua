-- Idempotent final boundary for the client-owned Shoot toggle.
XelAssist.Core.WandExecution = {}
local W = XelAssist.Core.WandExecution

function W:Validate(expectedGuid)
    local wand = XelAssist.Combat.Wand
    if not wand then return nil, "wand repeat state unavailable" end
    local snapshot = wand:Snapshot()
    if snapshot.currentTargetGuid ~= expectedGuid then
        return nil, "target changed"
    end
    local allowed, reason = wand:CanStart(snapshot)
    if not allowed then return nil, reason or "wand repeat state uncertain" end
    return snapshot.currentTargetGuid, nil
end

function W:Dispatch(castName, expectedGuid)
    local guid, reason = self:Validate(expectedGuid)
    if not guid then return false, reason end
    if not CastSpellByName then return false, "wand cast API unavailable" end
    CastSpellByName(castName)
    return true, nil, guid
end

function W:Submitted(targetGuid, action, tooltip)
    local wand = XelAssist.Combat.Wand
    if not wand then return false end
    local submitted, reason = wand:Submitted(targetGuid)
    if not submitted then return false, reason end

    -- Shoot bypasses generic Observations because its client-owned repeat
    -- toggle must not inherit cast/UI-error correlation.  Preserve only the
    -- exact resistance submission needed to bind a damage packet's observed
    -- school to the currently equipped wand.
    local resistance = XelAssist.Combat.Resistance
    if action and resistance and resistance.Submitted then
        if resistance.RememberUnit and type(UnitExists) == "function" then
            local ok, exists, selectedGuid = pcall(UnitExists, "target")
            if ok and exists and selectedGuid == targetGuid then
                resistance:RememberUnit("target")
            end
        end
        resistance:Submitted(action, targetGuid, tooltip, false)
    end
    return true, reason
end
