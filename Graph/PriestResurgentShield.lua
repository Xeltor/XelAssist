-- Search-pure carrier for Resurgent Shield. Observed Resurgence is recorded so
-- root engine spell power may represent it once, but private future break
-- amounts remain explicitly unresolved and are never manufactured in search.
XelAssist.Graph.PriestResurgentShield = {}
local R = XelAssist.Graph.PriestResurgentShield

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function R:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.priestResurgentShield = nil
    local owner = XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PriestResurgentShield
    local found = owner and owner:Snapshot(knownClass) or nil
    if not (found and found.available == true and found.exact == true) then
        return false
    end
    state.priestResurgentShield = copy(found)
    return true
end

function R:Copy(source, target)
    local found = source and source.priestResurgentShield
    if not (type(target) == "table" and type(found) == "table") then
        return false
    end
    target.priestResurgentShield = copy(found)
    return true
end

function R:ShieldBreakProjection(action, state)
    local facts = action and action.facts
    if not (facts and facts.priestShield == true) then return nil, nil, false end
    local found = state and state.priestResurgentShield
    if not (found and found.exact == true and found.learned == true) then
        return nil, nil, true
    end
    return nil, found.unresolved or
        "Resurgent Shield future consequences unavailable", true
end

function R:ObservedHolyModifier(state)
    local found = state and state.priestResurgentShield
    if not (found and found.exact == true and found.learned == true
        and found.active == true and found.resultId == 51477) then
        return false
    end
    return true, "root engine spell power already contains observed Resurgence"
end

