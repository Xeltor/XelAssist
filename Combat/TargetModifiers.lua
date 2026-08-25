-- Target modifier discovery and stacking rules are shared combat knowledge,
-- not graph-search machinery. Keeping them here lets observation code recover
-- the live resistance-reduction context without depending back on the graph.
XelAssist.Combat.TargetModifiers = {}
local M = XelAssist.Combat.TargetModifiers

function M:AggregateReductions(effects)
    local groups, _, effect = {}, nil, nil
    for _, effect in pairs(effects or {}) do
        local group = tostring(effect.group or effect.name or "independent")
        if not groups[group] then groups[group] = {} end
        local school, amount
        for school, amount in pairs(effect.resistanceReduction or {}) do
            groups[group][school] = math.max(groups[group][school] or 0,
                tonumber(amount) or 0)
        end
    end
    local out, count, _, values = {}, 0, nil, nil
    for _, values in pairs(groups) do
        local school, amount
        for school, amount in pairs(values) do
            out[school] = (out[school] or 0) + amount
        end
    end
    for _ in pairs(out) do count = count + 1 end
    return count > 0 and out or nil
end

function M:AggregateDamageTaken(effects, base)
    local groups, _, effect = {}, nil, nil
    for _, effect in pairs(effects or {}) do
        local group = tostring(effect.group or effect.name or "independent")
        if not groups[group] then groups[group] = {} end
        local school, amount
        for school, amount in pairs(effect.damageTaken or {}) do
            amount = tonumber(amount) or 0
            if groups[group][school] == nil or amount > groups[group][school] then
                groups[group][school] = amount
            end
        end
    end
    local out, schools, school, amount = {}, {}, nil, nil
    for school, amount in pairs(base or {}) do
        out[school] = tonumber(amount) or 0
        schools[school] = true
    end
    local _, values
    for _, values in pairs(groups) do
        for school, amount in pairs(values) do
            if out[school] == nil then out[school] = amount
            else out[school] = (1 + out[school]) * (1 + amount) - 1 end
            schools[school] = true
        end
    end
    local count = 0
    for _ in pairs(schools) do count = count + 1 end
    return count > 0 and out or nil
end

local function auraPoint(aura)
    if not aura or type(aura.points) ~= "table" then return nil end
    local best, _, value = nil, nil, nil
    for _, value in pairs(aura.points) do
        value = math.abs(tonumber(value) or 0)
        if value > 0 and (not best or value > best) then best = value end
    end
    return best
end

local function mergeFacts(out, incoming)
    if type(incoming) ~= "table" then return out end
    if out.targetArmorReduction == nil then
        out.targetArmorReduction = incoming.targetArmorReduction
        out.targetArmorPerCombo = incoming.targetArmorPerCombo
    end
    local fields = { "targetResistanceReduction", "targetDamageTaken" }
    local fieldIndex
    for fieldIndex = 1, table.getn(fields) do
        local field = fields[fieldIndex]
        if type(incoming[field]) == "table" then
            if type(out[field]) ~= "table" then out[field] = {} end
            local school, amount
            for school, amount in pairs(incoming[field]) do
                if out[field][school] == nil then out[field][school] = amount end
            end
        end
    end
    return out
end

-- Translate active, attributable debuffs into the same target-state shape used
-- by future graph transitions. A trusted live UnitResistance vector is already
-- effective and must not have resistance reductions subtracted a second time;
-- school-specific damage-taken modifiers are separate and still apply.
function M:Active(encounter, targetResistance)
    local harmful = encounter and encounter.targetHarmful
    if not (harmful and type(harmful.list) == "table") then
        return nil, nil, nil
    end
    local actions = XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or {}
    local byName, i = {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts
            and (action.facts.armorDebuff or action.facts.resistanceDebuff) then
            byName[action.name] = action
        end
    end
    local knowledgeName, semantics
    for knowledgeName, semantics in pairs(XelAssist.Combat.Knowledge or {}) do
        if (semantics.armorDebuff or semantics.resistanceDebuff)
            and not byName[knowledgeName] then
            byName[knowledgeName] = { name = knowledgeName, facts = semantics }
        end
    end
    local sources, effects, rootAuras = {}, {}, {}
    for i = 1, table.getn(harmful.list) do
        local aura = harmful.list[i]
        local action = aura and aura.name and byName[aura.name]
        local exact = aura and aura.spellId and XelAssist.Game.Capabilities
            and XelAssist.Game.Capabilities.TargetModifierFacts
            and XelAssist.Game.Capabilities:TargetModifierFacts(aura.spellId,
                action and action.facts or nil) or nil
        if (action or exact and exact.recognized) and aura.remaining ~= 0 then
            local tooltip = {}
            if exact and exact.recognized then mergeFacts(tooltip, exact) end
            -- A spellbook tooltip may include live talent adjustments, but it
            -- is rank-safe only when it describes this exact aura spell ID.
            if action and action.slot and (not aura.spellId
                or tonumber(action.spellId) == tonumber(aura.spellId)) then
                mergeFacts(tooltip, XelAssist.Game.Actors:Facts(action))
            end
            local facts = action and action.facts or {
                armorDebuff = tooltip.targetArmorReduction ~= nil,
                resistanceDebuff = tooltip.targetResistanceReduction ~= nil,
            }
            local name = action and action.name or aura.name
                or SpellInfo and SpellInfo(aura.spellId) or "Target modifier"
            local stacks = math.max(1, tonumber(aura.stacks) or 1)
            if facts.stackable then stacks = math.min(facts.stackable, stacks) end
            local owned = aura.mine
            if owned == nil and aura.playerOrPet then owned = true end
            local effect = { resistanceReduction = {}, damageTaken = {},
                name = name, group = facts.modifierGroup
                    or exact and exact.modifierGroup or name,
                remaining = aura.remaining, activeRoot = true,
                stackCap = facts.stackable,
                stackMass = facts.stackable and { [stacks] = 1 } or nil,
                stacks = facts.stackable and stacks or nil,
                expectedStacks = facts.stackable and stacks or nil,
                exclusiveFamily = facts.exclusiveFamily,
                mine = owned,
                liveIncluded = targetResistance and targetResistance.live and true or false }
            local armor = tonumber(tooltip.targetArmorReduction)
            if tooltip.targetArmorPerCombo then armor = auraPoint(aura) end
            if armor and facts.stackable then armor = armor * stacks end
            if armor then effect.resistanceReduction[0] = armor end
            local school, amount
            for school, amount in pairs(tooltip.targetResistanceReduction or {}) do
                effect.resistanceReduction[school] = tonumber(amount) or 0
            end
            for school, amount in pairs(tooltip.targetDamageTaken or {}) do
                effect.damageTaken[school] = tonumber(amount) or 0
            end
            effects[name] = effect
            rootAuras[name] = { remaining = aura.remaining, duration = aura.duration,
                mine = owned, target = "target", targetModifier = true,
                exclusiveFamily = facts.exclusiveFamily,
                stacks = aura.stacks, points = aura.points }
            table.insert(sources, name)
        end
    end
    return self:AggregateReductions(effects),
        self:AggregateDamageTaken(effects),
        table.getn(sources) > 0 and table.concat(sources, ", ") or nil,
        table.getn(sources) > 0 and effects or nil,
        table.getn(sources) > 0 and rootAuras or nil
end
