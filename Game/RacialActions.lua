-- Racial combat optimization is explicitly deferred for 1.0. Unknown actions
-- in the spellbook's General tab may not inherit DBC/tooltip utility; actions
-- with an independently modeled shared consequence are resolved before here.
XelAssist.Game.RacialActions = {}
local R = XelAssist.Game.RacialActions

local function integer(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

function R:GeneralRange()
    if type(GetNumSpellTabs) ~= "function"
        or type(GetSpellTabInfo) ~= "function" then
        return nil, nil, "spellbook tab provenance unavailable"
    end
    local okCount, tabs = pcall(GetNumSpellTabs)
    tabs = okCount and integer(tabs, 1, 64) or nil
    if not tabs then return nil, nil, "spellbook tab count unavailable" end
    local ok, _, _, offset, count = pcall(GetSpellTabInfo, 1)
    offset = ok and integer(offset, 0, 10000) or nil
    count = ok and integer(count, 0, 10000) or nil
    if not (offset and count) then
        return nil, nil, "General spellbook range unavailable"
    end
    return offset + 1, offset + count, nil
end

function R:CanInfer(slot)
    slot = integer(slot, 1, 10000)
    if not slot then return false, "spellbook slot unavailable" end
    local first, last, reason = self:GeneralRange()
    if not first then return false, reason end
    if slot >= first and slot <= last then
        return false, "unmodeled General or racial action"
    end
    return true, nil
end
