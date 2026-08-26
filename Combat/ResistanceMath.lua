-- Pure Vanilla resistance and delivery-prior math. Keeping these transforms
-- separate makes the observation/cache owner reviewable and lets graph search
-- supply a sealed evidence epoch without hidden clock reads.
XelAssist.Combat.ResistanceMath = {}
local M = XelAssist.Combat.ResistanceMath

M.PROFILE_PRIOR = 3
M.LAND_PRIOR = 4
M.PROFILE_HALF_LIFE = 30 * 24 * 60 * 60

local function clamp(value, low, high)
    if type(value) ~= "number" then return low end
    return math.max(low, math.min(high, value))
end

local function truncate(value)
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

-- Expected damage removed by the server's discrete 0/25/50/75% resistance
-- outcomes. The nominal full-resist bucket is capped to 75% for damage.
local PARTIAL_TABLE = {
    { 0.00, 0.0000 }, { 0.03, 0.0250 }, { 0.05, 0.0575 },
    { 0.08, 0.0775 }, { 0.10, 0.1000 }, { 0.13, 0.1300 },
    { 0.15, 0.1525 }, { 0.18, 0.1725 }, { 0.20, 0.2000 },
    { 0.23, 0.2300 }, { 0.25, 0.2500 }, { 0.28, 0.2700 },
    { 0.30, 0.2950 }, { 0.33, 0.3250 }, { 0.35, 0.3475 },
    { 0.38, 0.3725 }, { 0.40, 0.3975 }, { 0.43, 0.4275 },
    { 0.45, 0.4475 }, { 0.48, 0.4650 }, { 0.50, 0.4950 },
    { 0.53, 0.5075 }, { 0.55, 0.5300 }, { 0.58, 0.5550 },
    { 0.60, 0.5725 }, { 0.62, 0.5900 }, { 0.65, 0.6100 },
    { 0.68, 0.6300 }, { 0.70, 0.6525 }, { 0.73, 0.6675 },
    { 0.75, 0.6875 },
}

function M:AgeWeight(lastSeen, observedEpoch)
    if not lastSeen then return 0 end
    local at = tonumber(observedEpoch)
    if at == nil then return 0 end
    local age = math.max(0, at - lastSeen)
    return 0.5 ^ (age / self.PROFILE_HALF_LIFE)
end

function M:ExpectedPartial(chance)
    chance = clamp(chance, 0, 0.75)
    local i
    for i = 2, table.getn(PARTIAL_TABLE) do
        local high, low = PARTIAL_TABLE[i], PARTIAL_TABLE[i - 1]
        if chance <= high[1] then
            local span = high[1] - low[1]
            local ratio = span > 0 and (chance - low[1]) / span or 0
            return low[2] + (high[2] - low[2]) * ratio
        end
    end
    return PARTIAL_TABLE[table.getn(PARTIAL_TABLE)][2]
end

function M:InverseExpectedPartial(resisted)
    resisted = tonumber(resisted)
    if not resisted or resisted < 0 then return nil end
    local maximum = PARTIAL_TABLE[table.getn(PARTIAL_TABLE)][2]
    if resisted >= maximum then return 0.75 end
    local i
    for i = 2, table.getn(PARTIAL_TABLE) do
        local high, low = PARTIAL_TABLE[i], PARTIAL_TABLE[i - 1]
        if resisted <= high[2] then
            local span = high[2] - low[2]
            local ratio = span > 0 and (resisted - low[2]) / span or 0
            return low[1] + (high[1] - low[1]) * ratio
        end
    end
    return 0.75
end

function M:InnateResistancePoints(level, targetLevel)
    if type(level) ~= "number" or level <= 0
        or type(targetLevel) ~= "number" then return 0 end
    return truncate((8 * (targetLevel - level)) * level / 63)
end

function M:ProjectedLearnedMitigation(multiplier, reduction, level,
    periodic, school)
    multiplier, reduction, level = tonumber(multiplier),
        tonumber(reduction), tonumber(level)
    if not multiplier or not reduction or reduction <= 0
        or not level or level <= 0 then return multiplier end
    if school == 0 then
        if multiplier >= 1 then return multiplier end
        local constant = 400 + 85 * level
        local inferredArmor = constant
            * (1 / math.max(0.05, multiplier) - 1)
        local projectedArmor = math.max(0, inferredArmor - reduction)
        return constant / (constant + projectedArmor)
    end
    local delta = reduction * 0.15 / level
    if periodic then delta = delta * 0.1 end
    if multiplier < 1 then
        local chance = self:InverseExpectedPartial(1 - multiplier)
        if not chance then return multiplier end
        return 1 - self:ExpectedPartial(math.max(0, chance - delta))
    elseif multiplier > 1 then
        local chance = self:InverseExpectedPartial(multiplier - 1)
        if not chance then return multiplier end
        return 1 + self:ExpectedPartial(math.min(0.75, chance + delta))
    end
    return multiplier
end

-- Live Turtle fields and outcomes remain authoritative; these are Vanilla
-- priors for discrete magical mitigation and physical armor reduction.
function M:MagicMultiplier(raw, level, penetration, targetLevel, school,
    innate, periodic)
    if type(raw) ~= "number" or type(level) ~= "number"
        or level <= 0 then return nil end
    local effective = raw - math.max(0, tonumber(penetration) or 0)
    if raw >= 0 then effective = math.max(0, effective) end
    if effective < 0 then
        local vulnerabilityCap = math.max(20, level) * 5
        local chance = clamp(-effective / vulnerabilityCap, 0, 0.75)
        if periodic then chance = chance * 0.1 end
        local vulnerability = self:ExpectedPartial(chance)
        return 1 + vulnerability, effective, -vulnerability, -chance
    end
    local modeled = effective
    if innate and type(targetLevel) == "number" then
        modeled = modeled + self:InnateResistancePoints(level, targetLevel)
    end
    local chance = clamp(modeled * 0.15 / level, 0, 0.75)
    if periodic then chance = chance * 0.1 end
    local resisted = self:ExpectedPartial(chance)
    return 1 - resisted, effective, resisted, chance
end

function M:BinaryResistance(raw, level, penetration)
    if type(raw) ~= "number" or type(level) ~= "number"
        or level <= 0 then return nil end
    local effective = raw - math.max(0, tonumber(penetration) or 0)
    if raw >= 0 then effective = math.max(0, effective) end
    if effective < 0 then
        local cap = math.max(20, level) * 5
        local chance = -clamp(-effective / cap, 0, 0.75)
        return chance, 1 + self:ExpectedPartial(-chance), effective
    end
    return clamp(effective * 0.15 / level, 0, 0.75), 1, effective
end

function M:ArmorMultiplier(raw, level, penetration)
    if type(raw) ~= "number" or type(level) ~= "number"
        or level <= 0 then return nil end
    local effective = math.max(0,
        raw - math.max(0, tonumber(penetration) or 0))
    local constant = 400 + 85 * level
    local mitigated = math.min(0.75, effective / (effective + constant))
    return 1 - mitigated, effective, mitigated
end

function M:LearnedValues(record, observedEpoch)
    if not record then return nil, nil, 0 end
    local recency = self:AgeWeight(record.lastSeen, observedEpoch)
    local samples = (record.samples or 0) * recency
    local mitigation
    if samples > 0 then
        mitigation = ((record.delivered or 0) + self.PROFILE_PRIOR)
            / ((record.samples or 0) + self.PROFILE_PRIOR)
        mitigation = 1 - (1 - mitigation) * recency
    end
    local landSamples = (record.landSamples or 0) * recency
    local landing
    if landSamples > 0 then
        landing = ((record.landHits or 0) + self.LAND_PRIOR)
            / ((record.landSamples or 0) + self.LAND_PRIOR)
        landing = 1 + (landing - 1) * recency
    end
    return mitigation, landing, math.max(samples, landSamples)
end

function M:LearnedDelivery(record, prior, observedEpoch)
    local age = function(lastSeen, at) return self:AgeWeight(lastSeen, at) end
    return XelAssist.Combat.Delivery:Learned(record, prior, age,
        self.LAND_PRIOR, observedEpoch)
end
