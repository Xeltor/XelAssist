-- Search-pure projection of the root-captured Alone Against the World state.
-- This mechanic adjusts consequences only and never creates a strategy edge.
XelAssist.Graph.HunterAloneAgainstWorld = {}
local A = XelAssist.Graph.HunterAloneAgainstWorld

local function finite(value)
    value = tonumber(value)
    return value and value == value and value or nil
end

function A:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.hunterAloneAgainstWorld = nil
    local owner = XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.HunterAloneAgainstWorld
    local found = owner and owner:Snapshot(knownClass) or nil
    if not (found and found.available == true and found.exact == true
        and found.learned == true) then return false end
    state.hunterAloneAgainstWorld = {
        spellId = found.spellId, active = found.active == true,
        noControlledPet = found.noControlledPet == true,
        auraExact = found.auraExact == true, activeAura = found.activeAura,
        damageMultiplier = found.damageMultiplier, source = found.source }
    return true
end

function A:Copy(source, target)
    local found = source and source.hunterAloneAgainstWorld
    if not (target and type(found) == "table") then return false end
    local copy, key, value = {}, nil, nil
    for key, value in pairs(found) do copy[key] = value end
    target.hunterAloneAgainstWorld = copy
    return true
end

function A:AdjustDamage(context)
    local found = context and context.state
        and context.state.hunterAloneAgainstWorld
    if not (found and found.active == true
        and found.noControlledPet == true and found.auraExact == true
        and found.activeAura == found.spellId) then return false end
    local multiplier = finite(found.damageMultiplier)
    if not multiplier or (multiplier ~= 1.03 and multiplier ~= 1.06) then
        return false
    end
    local action = context.effectAction or context.action or {}
    if action.actor ~= nil and action.actor ~= "player" then return false end
    local kind = context.kind
    if kind ~= "damage" and kind ~= "dot" and kind ~= "builder" then
        return false
    end
    local power, expected = finite(context.power), finite(context.expectedPower)
    if not power or not expected then return false end
    context.power, context.expectedPower = power * multiplier,
        expected * multiplier
    context.hunterAloneAgainstWorldMultiplier = multiplier
    return true
end
