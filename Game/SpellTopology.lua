-- DBC-backed spell recipient topology. This describes where an effect can
-- resolve; it does not decide whether casting that effect is useful.
XelAssist.Game.SpellTopology = {}
local T = XelAssist.Game.SpellTopology

-- Exact SpellRadius.dbc values from the installed Octowow patch-4.mpq, the
-- newest client archive that contains this table (patch-5 does not override
-- it). The client spell record exposes only the radius index through Nampower.
local RADIUS = {
    [7] = 2, [8] = 5, [9] = 20, [10] = 30, [11] = 45, [12] = 100,
    [13] = 10, [14] = 8, [15] = 3, [16] = 1, [17] = 13, [18] = 15,
    [19] = 18, [20] = 25, [21] = 35, [22] = 200, [23] = 40,
    [24] = 65, [25] = 70, [26] = 4, [27] = 50, [28] = 50000,
    [29] = 6, [31] = 80,
}

local TARGET = {
    [1] = { relation = "self", shape = "single", center = "caster" },
    [2] = { relation = "hostile", shape = "single", center = "caster" },
    [3] = { relation = "friendly", shape = "single", center = "caster" },
    [5] = { relation = "pet", shape = "single", center = "caster" },
    [6] = { relation = "hostile", shape = "single", center = "target" },
    [7] = { relation = "unknown", shape = "area", center = "caster" },
    [8] = { relation = "unknown", shape = "area", center = "target" },
    [15] = { relation = "hostile", shape = "area", center = "caster" },
    [16] = { relation = "hostile", shape = "area", center = "target" },
    [20] = { relation = "party", shape = "area", center = "caster" },
    [21] = { relation = "friendly", shape = "single", center = "target" },
    [24] = { relation = "hostile", shape = "cone", center = "caster" },
    [25] = { relation = "unknown", shape = "single", center = "target" },
    [27] = { relation = "friendly", shape = "single", center = "caster" },
    -- Dynamic-object recipients are ground effects. A visible target does not
    -- prove the object's placement center, so the graph must not resolve them
    -- as ordinary target-centered circles.
    [28] = { relation = "hostile", shape = "ground", center = "dynamicObject" },
    [29] = { relation = "friendly", shape = "ground", center = "dynamicObject" },
    [30] = { relation = "friendly", shape = "area", center = "caster" },
    [31] = { relation = "friendly", shape = "area", center = "target" },
    [33] = { relation = "party", shape = "area", center = "caster" },
    [34] = { relation = "party", shape = "area", center = "target" },
    [35] = { relation = "party", shape = "single", center = "target" },
    [36] = { relation = "hostile", shape = "area", center = "caster" },
    [37] = { relation = "friendly", shape = "area", center = "target" },
    [45] = { relation = "friendly", shape = "chain", center = "target" },
    [54] = { relation = "hostile", shape = "cone", center = "caster" },
    [56] = { relation = "raid", shape = "area", center = "caster" },
    [57] = { relation = "raid", shape = "single", center = "target" },
    [58] = { relation = "raid", shape = "single", center = "caster" },
    [59] = { relation = "friendly", shape = "cone", center = "caster" },
}

local function dbcArray(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if ok and type(value) == "table" then return value end
    return nil
end

local function copyTarget(code)
    local known = TARGET[tonumber(code)]
    if not known then
        return { code = tonumber(code) or 0, relation = "unknown",
            shape = "unknown", center = "unknown" }
    end
    return { code = tonumber(code), relation = known.relation,
        shape = known.shape, center = known.center }
end

local function isArea(target)
    return target.shape == "area" or target.shape == "cone"
        or target.shape == "chain" or target.shape == "ground"
end

local function chooseTarget(first, second)
    if first.code == 0 then return second end
    if second.code == 0 then return first end
    if isArea(second) and not isArea(first) then return second end
    if first.relation == "unknown" and second.relation ~= "unknown" then
        return second
    end
    return first
end

local function effectRecord(index, effects, targetsA, targetsB, radii, chains)
    local first = copyTarget(targetsA and targetsA[index])
    local second = copyTarget(targetsB and targetsB[index])
    local target = chooseTarget(first, second)
    local radiusIndex = tonumber(radii and radii[index])
    local chainTargets = tonumber(chains and chains[index])
    if chainTargets and chainTargets > 1 and target.shape == "single" then
        target.shape, target.center = "chain", "target"
    end
    return { index = index, effect = tonumber(effects and effects[index]) or 0,
        implicitA = first.code, implicitB = second.code,
        relation = target.relation, shape = target.shape, center = target.center,
        radiusIndex = radiusIndex, radius = RADIUS[radiusIndex],
        -- An area effect without a positive, mapped radius is unknown. A zero
        -- radius on a single-target effect merely means radius is inapplicable.
        radiusKnown = not isArea(target) or radiusIndex ~= nil
            and radiusIndex > 0 and RADIUS[radiusIndex] ~= nil,
        maxTargets = chainTargets and chainTargets > 0 and chainTargets or nil }
end

function T:Radius(index)
    return RADIUS[tonumber(index)]
end

function T:Facts(spellId)
    spellId = tonumber(spellId)
    if not spellId then return { available = false, effects = {} } end
    if not self.cache then self.cache = {} end
    if self.cache[spellId] then return self.cache[spellId] end
    local effects = dbcArray(spellId, "effect")
    local targetsA = dbcArray(spellId, "effectImplicitTargetA")
    local targetsB = dbcArray(spellId, "effectImplicitTargetB")
    local radii = dbcArray(spellId, "effectRadiusIndex")
    local chains = dbcArray(spellId, "effectChainTarget")
    if not (effects or targetsA or targetsB or radii or chains) then
        local unavailable = { available = false, effects = {} }
        self.cache[spellId] = unavailable
        return unavailable
    end
    local out = { available = true, source = "Octowow Spell.dbc",
        effects = {}, hostile = {}, friendly = {} }
    local i
    for i = 1, 3 do
        local record = effectRecord(i, effects, targetsA, targetsB, radii, chains)
        if record.effect ~= 0 then
            table.insert(out.effects, record)
            if record.relation == "hostile" then
                table.insert(out.hostile, record)
            elseif record.relation == "friendly" or record.relation == "party"
                or record.relation == "raid" or record.relation == "pet"
                or record.relation == "self" then
                table.insert(out.friendly, record)
            end
            if isArea(record) then out.area = true end
            if record.shape == "chain" then out.chain = true end
            if record.shape == "cone" then out.cone = true end
            if record.radiusKnown == false then out.radiusUnknown = true end
        end
    end
    self.cache[spellId] = out
    return out
end

function T:Invalidate()
    self.cache = nil
end
