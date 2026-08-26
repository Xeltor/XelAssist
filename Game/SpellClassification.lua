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
    out.stancesNot = dbc("stancesNot")
    out.spellFamilyName = dbc("spellFamilyName")
    out.spellFamilyFlags = dbc("spellFamilyFlags")
    out.equippedItemClass = dbc("equippedItemClass")
    out.equippedItemSubClassMask = dbc("equippedItemSubClassMask")
    out.equippedItemInventoryTypeMask =
        dbc("equippedItemInventoryTypeMask")
    if out.stances ~= nil and flagSet(out.stances, 536870912) then
        out.requiresStealth = true
    end

    if dbcArray then
        local effects = dbcArray("effect")
        local auras = dbcArray("effectApplyAuraName")
        local points = dbcArray("effectBasePoints")
        local dice = dbcArray("effectBaseDice")
        local sides = dbcArray("effectDieSides")
        local diceLevel = dbcArray("effectDicePerLevel")
        local pointsLevel = dbcArray("effectRealPointsPerLevel")
        local targets = dbcArray("effectImplicitTargetA")
        local feign, vanish, fadeAmount = false, false, nil
        local rogueVanish = out.spellFamilyName == 8
            and out.spellFamilyFlags ~= nil
            and flagSet(out.spellFamilyFlags, 2048)
        local priestFade = out.spellFamilyName == 6
            and out.spellFamilyFlags ~= nil
            and flagSet(out.spellFamilyFlags, 16384)
        local playerLevel = UnitLevel and tonumber(UnitLevel("player"))
        local baseLevel, maxLevel, spellLevel = tonumber(dbc("baseLevel")),
            tonumber(dbc("maxLevel")), tonumber(dbc("spellLevel"))
        local i, gain, gainUnknown = nil, 0, false
        for i = 1, table.getn(effects or {}) do
            local effect, aura = tonumber(effects[i]),
                tonumber(auras and auras[i])
            if tonumber(effects[i]) == 6
                and tonumber(auras and auras[i]) == 16 then
                out.appliesStealth = true
            end
            -- Spell.dbc distinguishes the three player threat-drop shapes.
            -- The action kind remains explicit knowledge; these installed-
            -- client fields only select its causal projection.
            if action.facts and action.facts.kind == "threatDrop"
                and tonumber(targets and targets[i]) == 1 then
                if effect == 6 and aura == 66 then feign = true
                elseif effect == 79 and rogueVanish then vanish = true
                elseif effect == 6 and aura == 4 and priestFade
                    and playerLevel and baseLevel and maxLevel and spellLevel then
                    local base = tonumber(points and points[i])
                    local die = tonumber(dice and dice[i])
                    local side = tonumber(sides and sides[i])
                    local dieScale = tonumber(diceLevel and diceLevel[i])
                    local scale = tonumber(pointsLevel and pointsLevel[i])
                    if base and die and dieScale == 0 and scale
                        and (side == 0 or side == 1) then
                        local level = math.max(baseLevel, playerLevel)
                        if maxLevel > 0 then level = math.min(level, maxLevel) end
                        local value = base + die
                            + (level - spellLevel) * scale
                        if value < 0 and (not fadeAmount
                            or -value > fadeAmount) then fadeAmount = -value end
                    end
                end
            end
            if effect == 80 then
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
        if feign then
            out.threatDropModel = "resistible-all-or-nothing"
        elseif vanish then
            out.threatDropModel = "reference-clear"
        elseif priestFade then
            out.threatDropModel = "temporary-flat"
            out.threatDropAmount = fadeAmount
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
