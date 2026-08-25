-- Expected Warrior rage earned by an ordinary player weapon hit. The graph
-- keeps this separate from the swing clock: PlayerSwings owns whether a white
-- round actually occurs, while this module owns only its resource consequence.
XelAssist.Graph.PlayerRage = {}
local R = XelAssist.Graph.PlayerRage

local RAGE = 1

function R:Is(state)
    return tonumber(state and state.resourceType) == RAGE
end

function R:Conversion(level)
    level = math.max(1, tonumber(level) or 1)
    return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911
end

function R:FromOutgoingDamage(state, damage)
    if not self:Is(state) then return 0 end
    damage = math.max(0, tonumber(damage) or 0)
    if damage <= 0 then return 0 end
    -- Use the vanilla VMaNGOS weapon-damage conversion as an estimated server
    -- baseline. Keep a conservative whole displayed-rage projection because
    -- UnitMana cannot expose the server's hidden tenths remainder.
    return math.floor(damage * 7.5 / self:Conversion(state.playerLevel))
end

function R:GainFromWhite(state, damage)
    if not self:Is(state) or state.playerResourceExact == false then return 0 end
    local current, maximum = tonumber(state.resource), tonumber(state.resourceMax)
    if not current or not maximum then return 0 end
    local amount = self:FromOutgoingDamage(state, damage)
    if amount <= 0 then return 0 end
    state.resource = math.min(maximum, current + amount)
    local gained = state.resource - current
    state.playerResourceProjected = true
    state.playerRageProjection = { estimated = true,
        source = "projected ordinary weapon damage", gained = gained }
    return gained
end
