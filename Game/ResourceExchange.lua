-- Exact tooltip evidence for actions that exchange one player resource for
-- another. The parser recognizes mechanics, never class rotations or ranks.
XelAssist.Game.ResourceExchange = {}
local R = XelAssist.Game.ResourceExchange

local function dbc(spellId, field, array)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value
    if array then ok, value = pcall(GetSpellRecField, spellId, field, 1)
    else ok, value = pcall(GetSpellRecField, spellId, field) end
    if ok then return value end
    return nil
end

local function signed32(value)
    value = tonumber(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function containsFlag(value, flag)
    value = tonumber(value)
    return value and value >= 0
        and math.floor(value / flag) - math.floor(value / (flag * 2)) * 2 == 1
end

-- Life Tap ranks share a stable installed-client DBC signature. Recognition is
-- deliberately independent of the localized spell name and description; the
-- tooltip remains only the evidence source for rank-specific magnitudes.
function R:InferDBC(spellId)
    if tonumber(dbc(spellId, "spellFamilyName")) ~= 5
        or not containsFlag(dbc(spellId, "spellFamilyFlags"), 262144)
        or signed32(dbc(spellId, "powerType")) ~= -2 then return nil end
    local effects = dbc(spellId, "effect", true)
    local targets = dbc(spellId, "effectImplicitTargetA", true)
    if type(effects) ~= "table" or type(targets) ~= "table" then return nil end
    local i
    for i = 1, 3 do
        if tonumber(effects[i]) == 3 and tonumber(targets[i]) == 1 then
            return { kind = "resource", self = true, transientResource = true,
                healthConversion = true, resourceType = "mana", inferred = true,
                dbcResourceExchange = true }
        end
    end
    return nil
end

local function conversion(text)
    if type(text) ~= "string" then return nil, nil, nil end
    local _, _, health, resource, resourceType = string.find(text,
        "converts? (%d+) health into (%d+) (%a+)")
    health, resource = tonumber(health), tonumber(resource)
    if not (health and health > 0 and resource and resource > 0) then
        return nil, nil, nil
    end
    return health, resource, resourceType
end

function R:Infer(text)
    local health, resource, resourceType = conversion(text)
    if not health then return nil end
    return { kind = "resource", self = true, transientResource = true,
        healthConversion = true, resourceType = resourceType }
end

function R:Apply(action, tooltip, description)
    local facts = action and action.facts or {}
    if not facts.healthConversion then return false end
    local health, resource, resourceType = conversion(description)
    if not health then return false end
    tooltip.healthCost = health
    tooltip.resourceGain = resource
    tooltip.resourceType = resourceType
    return true
end
