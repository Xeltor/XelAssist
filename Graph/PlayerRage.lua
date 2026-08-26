-- Expected Warrior rage earned by an ordinary player weapon hit. The graph
-- keeps this separate from the swing clock: PlayerSwings owns whether a white
-- round actually occurs, while this module owns only its resource consequence.
XelAssist.Graph.PlayerRage = {}
local R = XelAssist.Graph.PlayerRage

local RAGE = 1
R.SERVER_PROFILE = "VMaNGOS e5f3fd0 RewardRage baseline"

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

function R:FromIncomingDamage(state, damage)
    if not self:Is(state) then return 0 end
    damage = math.max(0, tonumber(damage) or 0)
    if damage <= 0 then return 0 end
    -- VMaNGOS RewardRage uses the final delivered damage at 2.5/conversion.
    -- The server's configurable income rate remains unknown. Patch-5 does
    -- expose Berserker Rage's exact modifier, which composes with this
    -- conservative baseline only while its finite aura is active.
    local multiplier = 1
    local berserker = XelAssist.Graph.WarriorBerserkerRage
    if berserker then
        local exact
        multiplier, exact = berserker:IncomingRageMultiplier(state)
        if exact ~= true then return 0 end
    end
    return math.floor(damage * 2.5 * multiplier
        / self:Conversion(state.playerLevel))
end

local function gain(state, amount, source, berserkerMultiplier)
    if state.playerResourceExact == false then return 0 end
    local current, maximum = tonumber(state.resource), tonumber(state.resourceMax)
    if not current or not maximum or amount <= 0 then return 0 end
    state.resource = math.min(maximum, current + amount)
    local gained = state.resource - current
    state.playerResourceProjected = true
    state.playerRageProjection = { estimated = true,
        source = source .. "; " .. R.SERVER_PROFILE, gained = gained,
        incomeRateKnown = false, berserkerRageMultiplierKnown = true,
        berserkerRageMultiplier = berserkerMultiplier or 1 }
    return gained
end

function R:GainFromWhite(state, damage)
    if not self:Is(state) then return 0 end
    local amount = self:FromOutgoingDamage(state, damage)
    return gain(state, amount, "projected ordinary weapon damage", 1)
end

function R:GainFromIncomingDamage(state, damage)
    if not self:Is(state) then return 0 end
    local amount = self:FromIncomingDamage(state, damage)
    local multiplier, berserker = 1, XelAssist.Graph.WarriorBerserkerRage
    if berserker then multiplier = berserker:IncomingRageMultiplier(state) end
    return gain(state, amount, "projected delivered incoming damage", multiplier)
end
