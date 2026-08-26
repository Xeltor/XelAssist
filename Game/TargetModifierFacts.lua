-- Exact installed-DBC target-modifier consequences. This owns array-shape
-- validation and lets both learned actions and already-active auras use the
-- same rank-safe facts without locale or spell-name strategy.
XelAssist.Game.TargetModifierFacts = {}
local M = XelAssist.Game.TargetModifierFacts

local function maskContains(mask, school)
    mask = math.max(0, tonumber(mask) or 0)
    local divisor = 2 ^ school
    return math.floor(mask / divisor)
        - math.floor(mask / (divisor * 2)) * 2 == 1
end

local function array(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    return ok and type(value) == "table" and value or nil
end

local function cacheKey(spellId, semantics)
    return table.concat({ tostring(spellId),
        tostring(semantics and semantics.modifierGroup or ""),
        semantics and semantics.armorDebuff and "armor" or "",
        semantics and semantics.resistanceDebuff and "resistance" or "" }, ":")
end

local function armorAmount(signed, combo)
    if combo and combo ~= 0 then
        -- The graph's per-combo shape is multiplicative. Mixed base-plus-combo
        -- rows need a different equation and therefore remain unresolved.
        if signed ~= 0 then return nil, nil end
        return math.abs(combo), true
    end
    return signed and signed ~= 0 and math.abs(signed) or nil, nil
end

function M:Get(spellId, semantics)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 or not GetSpellRecField then return {} end
    self.cache = self.cache or {}
    local key = cacheKey(spellId, semantics)
    if self.cache[key] then return self.cache[key] end
    local effects, auras = array(spellId, "effect"),
        array(spellId, "effectApplyAuraName")
    local base, misc = array(spellId, "effectBasePoints"),
        array(spellId, "effectMiscValue")
    local perCombo = array(spellId, "effectPointsPerComboPoint")
    local out = { targetResistanceReduction = {}, targetDamageTaken = {},
        source = "installed client DBC target modifier" }
    local i
    for i = 1, math.max(table.getn(effects or {}), table.getn(auras or {})) do
        if effects and tonumber(effects[i]) == 6 then
            local aura = auras and tonumber(auras[i])
            local rawBase = tonumber(base and base[i])
            local signed = rawBase and rawBase + 1 or nil
            local combo = tonumber(perCombo and perCombo[i])
            local amount = math.abs(signed or 0)
            local mask = tonumber(misc and misc[i]) or 0
            if aura == 22 or aura == 123 or aura == 143 then
                local school
                for school = 0, 6 do
                    if maskContains(mask, school) then
                        local reducing = semantics and (school == 0
                            and semantics.armorDebuff or school > 0
                            and semantics.resistanceDebuff)
                            or not semantics and (signed and signed < 0
                                or combo and combo < 0)
                        if school == 0 and reducing then
                            local armor, scaled = armorAmount(signed, combo)
                            if armor then
                                out.targetArmorReduction = math.max(
                                    out.targetArmorReduction or 0, armor)
                                if scaled then out.targetArmorPerCombo = true end
                            end
                        elseif school > 0 and reducing and amount > 0 then
                            out.targetResistanceReduction[school] = math.max(
                                out.targetResistanceReduction[school] or 0, amount)
                        end
                    end
                end
            elseif aura == 87 and signed and signed > 0 then
                local school
                for school = 0, 6 do
                    if maskContains(mask, school) then
                        out.targetDamageTaken[school] = math.max(
                            out.targetDamageTaken[school] or 0, amount / 100)
                    end
                end
            end
        end
    end
    if not next(out.targetResistanceReduction) then out.targetResistanceReduction = nil end
    if not next(out.targetDamageTaken) then out.targetDamageTaken = nil end
    out.recognized = out.targetArmorReduction ~= nil
        or out.targetResistanceReduction ~= nil or out.targetDamageTaken ~= nil
    if out.recognized then out.modifierGroup = semantics and semantics.modifierGroup
        or "dbc:" .. tostring(spellId) end
    self.cache[key] = out
    return out
end

local function mergeMap(out, field, incoming)
    if type(incoming) ~= "table" then return end
    if type(out[field]) ~= "table" then out[field] = {} end
    local school, amount
    for school, amount in pairs(incoming) do out[field][school] = amount end
end

function M:Apply(action, out)
    local exact = self:Get(action and action.spellId, action and action.facts)
    if not exact.recognized then return false end
    if exact.targetArmorReduction ~= nil then
        out.targetArmorReduction = exact.targetArmorReduction
        out.targetArmorPerCombo = exact.targetArmorPerCombo
    end
    mergeMap(out, "targetResistanceReduction", exact.targetResistanceReduction)
    mergeMap(out, "targetDamageTaken", exact.targetDamageTaken)
    out.targetModifierSource = exact.source
    return true
end
