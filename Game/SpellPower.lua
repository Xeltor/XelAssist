-- OctoWoW's VMaNGOS Spell.dbc weapon-effect semantics. This describes a
-- spell's raw formula; live weapon damage and combat delivery are graph work.
XelAssist.Game.SpellPower = {}
local P = XelAssist.Game.SpellPower

local FIXED_WEAPON_EFFECT = { [17] = true, [58] = true, [121] = true }
local PERCENT_WEAPON_EFFECT = 31
local DIRECT_DAMAGE_EFFECT = 2

local function scaledLevel(action, dbc)
    local unit = action and action.actor == "pet" and "pet" or "player"
    local actor = UnitLevel and tonumber(UnitLevel(unit)) or nil
    local spell = tonumber(dbc("spellLevel")) or actor or 0
    local base = tonumber(dbc("baseLevel")) or 0
    local maximum = tonumber(dbc("maxLevel")) or 0
    local level = math.max(base, actor or spell)
    if maximum > 0 then level = math.min(level, maximum) end
    return level - spell
end

local function meanMagnitude(index, arrays, levels)
    local points = tonumber(arrays.points and arrays.points[index]) or 0
    local dice = tonumber(arrays.dice and arrays.dice[index]) or 0
    local sides = tonumber(arrays.sides and arrays.sides[index]) or 0
    local diceLevel = tonumber(arrays.diceLevel and arrays.diceLevel[index]) or 0
    local pointsLevel = tonumber(arrays.pointsLevel
        and arrays.pointsLevel[index]) or 0
    sides = sides + diceLevel * levels
    local roll = sides > 1 and (dice + sides) / 2 or dice
    return points + pointsLevel * levels + roll
end

function P:Apply(action, out, dbc, dbcArray)
    if not dbcArray then return end
    local arrays = {
        effects = dbcArray("effect"),
        points = dbcArray("effectBasePoints"),
        dice = dbcArray("effectBaseDice"),
        sides = dbcArray("effectDieSides"),
        diceLevel = dbcArray("effectDicePerLevel"),
        pointsLevel = dbcArray("effectRealPointsPerLevel"),
        combo = dbcArray("effectPointsPerComboPoint"),
    }
    if not arrays.effects then return end
    local coefficient, flat, comboFlat, direct = 1, 0, 0, 0
    local weapon, normalized = false, false
    local levels = scaledLevel(action, dbc)
    local index
    for index = 1, table.getn(arrays.effects) do
        local effect = tonumber(arrays.effects[index]) or 0
        if FIXED_WEAPON_EFFECT[effect] then
            flat = flat + meanMagnitude(index, arrays, levels)
            comboFlat = comboFlat
                + (tonumber(arrays.combo and arrays.combo[index]) or 0)
            weapon = true
            if effect == 121 then normalized = true end
        elseif effect == PERCENT_WEAPON_EFFECT then
            local multiplier = meanMagnitude(index, arrays, levels) / 100
            if multiplier > 0 then
                coefficient = coefficient * multiplier
                weapon = true
            end
        elseif effect == DIRECT_DAMAGE_EFFECT then
            direct = direct + math.max(0,
                meanMagnitude(index, arrays, levels))
        end
    end
    if not weapon then return end
    out.weaponCoefficient = coefficient
    out.weaponFlat = flat * coefficient
    if comboFlat ~= 0 then out.weaponComboFlat = comboFlat * coefficient end
    if direct > 0 then out.weaponDirectFlat = direct end
    out.weaponNormalized = normalized
    out.weaponFormulaSource = "OctoWoW VMaNGOS weapon effects"
end
