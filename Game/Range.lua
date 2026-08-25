-- Pure range verdicts shared by live capability checks and graph projection.
-- This module does not read graph state or perform execution-side mutations.
XelAssist.Game.Range = {}
local R = XelAssist.Game.Range

local function normalize(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function query(api, spell, unit)
    if type(api) ~= "function" or spell == nil or unit == nil then return nil end
    local ok, value = pcall(api, spell, unit)
    if not ok then return nil end
    return normalize(value)
end

function R:SpellVerdict(spellId, castName, unit)
    if unit == nil then return nil end
    local modern = C_Spell and C_Spell.IsSpellInRange
    if type(modern) == "function" then
        local numeric = tonumber(spellId)
        if numeric and numeric > 0 then
            local verdict = query(modern, numeric, unit)
            if verdict ~= nil then return verdict end
        end
        if castName ~= nil and castName ~= "" then
            local verdict = query(modern, castName, unit)
            if verdict ~= nil then return verdict end
        end
    end
    if castName == nil or castName == "" then return nil end
    return query(IsSpellInRange, castName, unit)
end

local function number(value)
    if value == nil then return nil, true end
    local converted = tonumber(value)
    if converted == nil then return nil, false end
    return converted, true
end

local function hitboxKind(kind)
    return kind == "hitbox" or kind == "combat reach"
end

function R:BandVerdict(minimum, maximum, distance, distanceKind,
    requiresHitbox)
    if minimum == nil and maximum == nil then return nil, "range unknown" end
    local minValue, minValid = number(minimum)
    local maxValue, maxValid = number(maximum)
    if not minValid or not maxValid then return nil, "range unknown" end
    minValue = math.max(0, minValue or 0)
    if maxValue ~= nil then maxValue = math.max(0, maxValue) end
    if maxValue and maxValue > 0 and minValue > maxValue then
        return nil, "range unknown"
    end
    local measured = tonumber(distance)
    if measured == nil or measured < 0 then return nil, "range unknown" end
    if requiresHitbox and not hitboxKind(distanceKind) then
        return nil, "effect range unknown"
    end
    if measured < minValue then return false, "minimum range" end
    if maxValue and maxValue > 0 and measured > maxValue then
        return false, "range"
    end
    return true, nil
end

function R:EffectBand(action)
    local facts = action and action.facts or {}
    local explicit = facts.effectMinRange ~= nil
        or facts.effectMaxRange ~= nil
    return facts.effectMinRange, facts.effectMaxRange,
        facts.effectRangeHitbox == true, explicit
end

function R:EffectVerdict(action, distance, distanceKind)
    local minimum, maximum, requiresHitbox, explicit = self:EffectBand(action)
    if not explicit then return nil, nil, false end
    local verdict, reason = self:BandVerdict(minimum, maximum,
        distance, distanceKind, requiresHitbox)
    return verdict, reason, true
end

function R:TooltipVerdict(tooltip, distance, distanceKind)
    tooltip = tooltip or {}
    return self:BandVerdict(tooltip.minRange, tooltip.maxRange,
        distance, distanceKind, false)
end
