-- Queue and delivery class facts copied from the installed client's Spell.dbc.
-- These describe how Nampower treats a spell; they are not rotation metadata.
XelAssist.Game.SpellClassification = {}
local S = XelAssist.Game.SpellClassification

local function flagSet(value, flag)
    value = math.max(0, tonumber(value) or 0)
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

function S:Apply(action, out, dbc)
    out.attributes = dbc("attributes")
    if out.attributes ~= nil then
        out.onNextSwing = flagSet(out.attributes, 4)
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
