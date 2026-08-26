-- Sealed DBC stance/form masks gate every search depth. Root usability alone
-- is insufficient because later graph nodes must not make an unchanged stance
-- requirement disappear merely by advancing time.
XelAssist.Graph.FormRequirements = {}
local F = XelAssist.Graph.FormRequirements
local ALLOW_WHILE_NEUTRAL = 524288

local function flagSet(value, flag)
    value, flag = math.max(0, tonumber(value) or 0), tonumber(flag)
    if not flag or flag <= 0 then return false end
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function maskFor(formID)
    formID = tonumber(formID)
    if not formID or formID <= 0 or formID > 32
        or math.floor(formID) ~= formID then return 0 end
    return 2 ^ (formID - 1)
end

function F:Blocker(state, tooltip)
    local allowed = math.max(0, tonumber(tooltip and tooltip.stances) or 0)
    local excluded = math.max(0,
        tonumber(tooltip and tooltip.stancesNot) or 0)
    if allowed <= 0 and excluded <= 0 then return nil end
    local evidence = state and state.playerForm
    if not (evidence and evidence.available == true
        and tonumber(evidence.formID) ~= nil) then
        return "player form state unavailable"
    end
    local current = maskFor(evidence.formID)
    local neutralAllowed = current == 0 and flagSet(
        tooltip and tooltip.attributesEx2, ALLOW_WHILE_NEUTRAL)
    if allowed > 0 and not neutralAllowed
        and (current == 0 or not flagSet(allowed, current)) then
        return "required player form inactive"
    end
    if excluded > 0 and current > 0 and flagSet(excluded, current) then
        return "current player form excluded"
    end
    return nil
end
