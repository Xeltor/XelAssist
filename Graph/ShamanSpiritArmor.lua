-- Search-pure composition of root-sealed Spirit Armor all-threat evidence.
XelAssist.Graph.ShamanSpiritArmor = {}
local S = XelAssist.Graph.ShamanSpiritArmor

local function factor(value)
    value = tonumber(value)
    if not value or value < 0 or value > 2 then return nil end
    return value
end

function S:Resolve(state, actor, multiplier, exact)
    if actor ~= "player" then return multiplier, exact, nil end
    local profile = state and state.shamanSpiritArmor
    if profile == nil then return multiplier, exact, nil end
    if profile.kind ~= "shamanSpiritArmor" or profile.actor ~= "player"
        or profile.playerOnly ~= true then
        return multiplier, false, profile
    end
    local own
    if profile.exact == true then own = factor(profile.multiplier)
    else
        own = state and state.tank and factor(profile.minimum)
            or factor(profile.maximum)
    end
    if not own then return multiplier, false, profile end
    return multiplier * own, exact and profile.exact == true, profile
end
