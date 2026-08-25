-- Queue and delivery class facts copied from the installed client's Spell.dbc.
-- These describe how Nampower treats a spell; they are not rotation metadata.
XelAssist.Game.SpellClassification = {}
local S = XelAssist.Game.SpellClassification

local function flagSet(value, flag)
    value = math.max(0, tonumber(value) or 0)
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

-- The installed DBC's start-recovery category is the authoritative shared-GCD
-- lane. Missing records stay conservative; ambient and on-swing actions own
-- independent client lanes even when their record has a recovery duration.
function S:NormalGcd(action, tooltip)
    local facts = action and action.facts or {}
    if facts.playerAttack or facts.autoRepeat or facts.onNextSwing or facts.onSwing
        or tooltip and (tooltip.onNextSwing or tooltip.onSwing) then return false end
    if tooltip and tooltip.normalGcd ~= nil then
        return tooltip.normalGcd and true or false
    end
    local gcd = facts.gcd
    if gcd == nil and tooltip then gcd = tooltip.gcd end
    return gcd == nil or (tonumber(gcd) or 0) > 0
end

function S:Apply(action, out, dbc, dbcArray)
    out.attributes = dbc("attributes")
    if out.attributes ~= nil then
        -- Classic data uses both the ordinary on-next-swing bit and the
        -- server-controlled replacement bit. Nampower accepts either.
        out.onNextSwing = flagSet(out.attributes, 4)
            or flagSet(out.attributes, 1024)
    end

    -- These flags distinguish an Attack start, a successful post-cast start,
    -- and actions such as Sap that stop Attack. Stop always wins.
    out.stopsPlayerAttack = out.attributes ~= nil
        and flagSet(out.attributes, 1048576) or false
    out.requiresStealth = out.attributes ~= nil
        and flagSet(out.attributes, 131072) or false
    out.attributesEx = dbc("attributesEx")
    out.attributesEx2 = dbc("attributesEx2")
    out.comboSpendAll = out.attributesEx ~= nil
        and (flagSet(out.attributesEx, 1048576)
            or flagSet(out.attributesEx, 4194304)) or false
    out.preservesStealth = out.attributesEx ~= nil
        and flagSet(out.attributesEx, 32) or false
    out.initiatesCombatPostCast = out.attributesEx2 ~= nil
        and flagSet(out.attributesEx2, 1048576)
        and not out.stopsPlayerAttack or false
    out.initiatesCombat = not out.stopsPlayerAttack
        and (out.attributesEx ~= nil and flagSet(out.attributesEx, 512)
            or out.initiatesCombatPostCast) or false

    -- Keep the stance mask as corroborating client evidence; the generic
    -- requires-stealth attribute above is authoritative across opener types.
    out.stances = dbc("stances")
    if out.stances ~= nil and flagSet(out.stances, 536870912) then
        out.requiresStealth = true
    end

    if dbcArray then
        local effects = dbcArray("effect")
        local points = dbcArray("effectBasePoints")
        local dice = dbcArray("effectBaseDice")
        local sides = dbcArray("effectDieSides")
        local diceLevel = dbcArray("effectDicePerLevel")
        local pointsLevel = dbcArray("effectRealPointsPerLevel")
        local i, gain, gainUnknown = nil, 0, false
        for i = 1, table.getn(effects or {}) do
            if tonumber(effects[i]) == 80 then
                local scaled = math.abs(tonumber(diceLevel and diceLevel[i]) or 0)
                    + math.abs(tonumber(pointsLevel and pointsLevel[i]) or 0)
                local deterministic = tonumber(sides and sides[i]) or 0
                if scaled == 0
                    and (deterministic == 0 or deterministic == 1) then
                    gain = gain + math.max(0,
                        (tonumber(points and points[i]) or 0)
                        + (tonumber(dice and dice[i]) or 0))
                else gainUnknown = true end
            end
        end
        if gainUnknown then out.comboGainUnknown = true
        elseif gain > 0 then out.comboGain = gain end
    end

    out.attributesEx4 = dbc("attributesEx4")
    if out.attributesEx4 ~= nil then
        out.ignoresResistances = flagSet(out.attributesEx4, 1)
    end

    local category = dbc("startRecoveryCategory")
    if category ~= nil then
        out.startRecoveryCategory = category
        -- Nampower has this one explicit exception because the server removed
        -- Power Overwhelming's GCD without changing the client record.
        out.normalGcd = category == 133 and action.spellId ~= 51714
    end
    return category
end
