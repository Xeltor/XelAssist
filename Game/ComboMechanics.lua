-- Live combo ownership and combo-duration facts. ClassicAPI provides the
-- hidden target GUID and SpellDuration endpoints; stock APIs remain a
-- conservative selected-target fallback when that bridge is unavailable.
XelAssist.Game.ComboMechanics = {}
local C = XelAssist.Game.ComboMechanics

local function clampPoints(points)
    return math.max(0, math.min(5, tonumber(points) or 0))
end

function C:Observe(selectedGUID, selectedHostile)
    if C_PlayerInfo and type(C_PlayerInfo.GetComboPointState) == "function" then
        local ok, points, owner = pcall(C_PlayerInfo.GetComboPointState)
        if ok and type(points) == "number" then
            points = clampPoints(points)
            if points == 0 then owner = nil end
            return { points = points, ownerGUID = owner,
                selectedExact = true, globalExact = owner ~= nil or points == 0,
                source = "ClassicAPI combo owner" }
        end
    end
    local points = 0
    if GetComboPoints then
        local ok, value = pcall(GetComboPoints)
        if ok then points = clampPoints(value) end
    end
    -- Stock GetComboPoints only reports non-zero when the selected target is
    -- the hidden combo owner. Zero therefore proves the selected target has no
    -- points, but cannot prove that some previously selected unit has none.
    local owner = points > 0 and selectedHostile and selectedGUID or nil
    return { points = points, ownerGUID = owner,
        selectedExact = selectedHostile and true or false,
        globalExact = points > 0 and owner ~= nil,
        source = "stock selected-target combo state" }
end

function C:ApplyDurationFacts(action, out)
    if not (action and action.spellId and C_Spell
        and type(C_Spell.GetSpellDurationRange) == "function") then return false end
    local ok, base, maximum, scaled = pcall(
        C_Spell.GetSpellDurationRange, action.spellId)
    base, maximum = tonumber(base), tonumber(maximum)
    if not ok or base == nil or maximum == nil or base < 0
        or maximum < base then return false end
    out.durationBase, out.durationMax = base, maximum
    out.durationComboScaled = scaled and maximum ~= base and true or false
    out.durationRangeSource = "ClassicAPI SpellDuration"
    return true
end
