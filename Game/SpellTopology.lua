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

-- Complete SpellTarget enum exposed by the locally installed Nampower fork.
-- These descriptors preserve what each implicit target field says without
-- forcing two fields into one recipient.  `resolved = false` means the enum
-- does not prove enough relation/shape information for graph decisions.
local function descriptor(name, kind, relation, shape, center, extra)
    local out = { name = name, kind = kind, relation = relation,
        shape = shape, center = center, resolved = true }
    local key, value
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end

local function legacyDescriptor(name, kind, relation, shape, center, extra)
    local out = descriptor(name, kind, relation, shape, center, extra)
    out.legacy = true
    return out
end

local TARGET = {
    [0] = descriptor("TARGET_NONE", "none", "none", "none", "none"),
    [1] = legacyDescriptor("TARGET_UNIT_CASTER", "unit", "self", "single", "caster"),
    [2] = legacyDescriptor("TARGET_UNIT_ENEMY_NEAR_CASTER", "unit", "hostile", "single", "caster"),
    [3] = legacyDescriptor("TARGET_UNIT_FRIEND_NEAR_CASTER", "unit", "friendly", "single", "caster"),
    [4] = descriptor("TARGET_UNIT_NEAR_CASTER", "unit", "polymorphic", "single", "caster",
        { resolved = false }),
    [5] = legacyDescriptor("TARGET_UNIT_CASTER_PET", "unit", "pet", "single", "caster"),
    [6] = legacyDescriptor("TARGET_UNIT_ENEMY", "unit", "hostile", "single", "target"),
    [7] = legacyDescriptor("TARGET_ENUM_UNITS_SCRIPT_AOE_AT_SRC_LOC", "unit", "unknown", "area", "source",
        { scripted = true, resolved = false, destination = "source",
            legacyCenter = "caster" }),
    [8] = legacyDescriptor("TARGET_ENUM_UNITS_SCRIPT_AOE_AT_DEST_LOC", "unit", "unknown", "area", "destination",
        { scripted = true, resolved = false, destination = "destination",
            legacyCenter = "target" }),
    [9] = descriptor("TARGET_LOCATION_CASTER_HOME_BIND", "location", "none", "location", "homeBind",
        { destination = "homeBind" }),
    [10] = descriptor("TARGET_LOCATION_CASTER_DIVINE_BIND_NYI", "location", "none", "location", "divineBind",
        { destination = "divineBind", nyi = true, resolved = false }),
    [11] = descriptor("TARGET_PLAYER_NYI", "unit", "unknown", "single", "unknown",
        { nyi = true, resolved = false }),
    [12] = descriptor("TARGET_PLAYER_NEAR_CASTER_NYI", "unit", "unknown", "single", "caster",
        { nyi = true, resolved = false }),
    [13] = descriptor("TARGET_PLAYER_ENEMY_NYI", "unit", "hostile", "single", "target",
        { nyi = true, resolved = false }),
    [14] = descriptor("TARGET_PLAYER_FRIEND_NYI", "unit", "friendly", "single", "target",
        { nyi = true, resolved = false }),
    [15] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_AOE_AT_SRC_LOC", "unit", "hostile", "area", "source",
        { destination = "source", legacyCenter = "caster" }),
    [16] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_AOE_AT_DEST_LOC", "unit", "hostile", "area", "destination",
        { destination = "destination", legacyCenter = "target" }),
    [17] = descriptor("TARGET_LOCATION_DATABASE", "location", "none", "location", "database",
        { destination = "database" }),
    [18] = descriptor("TARGET_LOCATION_CASTER_DEST", "location", "none", "location", "destination",
        { destination = "destination" }),
    [19] = descriptor("TARGET_UNK_19", "unknown", "unknown", "unknown", "unknown",
        { resolved = false }),
    [20] = legacyDescriptor("TARGET_ENUM_UNITS_PARTY_WITHIN_CASTER_RANGE", "unit", "party", "area", "caster"),
    [21] = legacyDescriptor("TARGET_UNIT_FRIEND", "unit", "friendly", "single", "target"),
    [22] = descriptor("TARGET_LOCATION_CASTER_SRC", "location", "none", "location", "source",
        { destination = "source" }),
    [23] = descriptor("TARGET_GAMEOBJECT", "object", "none", "single", "target"),
    [24] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_IN_CONE_24", "unit", "hostile", "cone", "caster"),
    [25] = legacyDescriptor("TARGET_UNIT", "unit", "polymorphic", "single", "target",
        { resolved = false, legacyRelation = "unknown" }),
    [26] = descriptor("TARGET_LOCKED", "locked", "unknown", "unknown", "target",
        { resolved = false }),
    [27] = legacyDescriptor("TARGET_UNIT_CASTER_MASTER", "unit", "friendly", "single", "caster"),
    [28] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_AOE_AT_DYNOBJ_LOC", "unit", "hostile", "area", "dynamicObject",
        { destination = "dynamicObject", deployable = true,
            legacyShape = "ground" }),
    [29] = legacyDescriptor("TARGET_ENUM_UNITS_FRIEND_AOE_AT_DYNOBJ_LOC", "unit", "friendly", "area", "dynamicObject",
        { destination = "dynamicObject", deployable = true,
            legacyShape = "ground" }),
    [30] = legacyDescriptor("TARGET_ENUM_UNITS_FRIEND_AOE_AT_SRC_LOC", "unit", "friendly", "area", "source",
        { destination = "source", legacyCenter = "caster" }),
    [31] = legacyDescriptor("TARGET_ENUM_UNITS_FRIEND_AOE_AT_DEST_LOC", "unit", "friendly", "area", "destination",
        { destination = "destination", legacyCenter = "target" }),
    [32] = descriptor("TARGET_LOCATION_UNIT_MINION_POSITION", "location", "none", "location", "minion",
        { destination = "minionPosition", deployable = true }),
    [33] = legacyDescriptor("TARGET_ENUM_UNITS_PARTY_AOE_AT_SRC_LOC", "unit", "party", "area", "source",
        { destination = "source", legacyCenter = "caster" }),
    [34] = legacyDescriptor("TARGET_ENUM_UNITS_PARTY_AOE_AT_DEST_LOC", "unit", "party", "area", "destination",
        { destination = "destination", legacyCenter = "target" }),
    [35] = legacyDescriptor("TARGET_UNIT_PARTY", "unit", "party", "single", "target"),
    [36] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_WITHIN_CASTER_RANGE", "unit", "hostile", "area", "caster"),
    [37] = legacyDescriptor("TARGET_UNIT_FRIEND_AND_PARTY", "unit", "friendly", "area", "target"),
    [38] = descriptor("TARGET_UNIT_SCRIPT_NEAR_CASTER", "unit", "unknown", "single", "caster",
        { scripted = true, resolved = false }),
    [39] = descriptor("TARGET_LOCATION_CASTER_FISHING_SPOT", "location", "none", "location", "fishingSpot",
        { destination = "fishingSpot", deployable = true }),
    [40] = descriptor("TARGET_GAMEOBJECT_SCRIPT_NEAR_CASTER", "object", "none", "single", "caster",
        { scripted = true, resolved = false }),
    [41] = descriptor("TARGET_LOCATION_CASTER_FRONT_RIGHT", "location", "none", "location", "casterFrontRight",
        { destination = "casterFrontRight" }),
    [42] = descriptor("TARGET_LOCATION_CASTER_BACK_RIGHT", "location", "none", "location", "casterBackRight",
        { destination = "casterBackRight" }),
    [43] = descriptor("TARGET_LOCATION_CASTER_BACK_LEFT", "location", "none", "location", "casterBackLeft",
        { destination = "casterBackLeft" }),
    [44] = descriptor("TARGET_LOCATION_CASTER_FRONT_LEFT", "location", "none", "location", "casterFrontLeft",
        { destination = "casterFrontLeft" }),
    [45] = legacyDescriptor("TARGET_UNIT_FRIEND_CHAIN_HEAL", "unit", "friendly", "chain", "target"),
    [46] = descriptor("TARGET_LOCATION_SCRIPT_NEAR_CASTER", "location", "none", "location", "caster",
        { destination = "caster", scripted = true, resolved = false }),
    [47] = descriptor("TARGET_LOCATION_CASTER_FRONT", "location", "none", "location", "casterFront",
        { destination = "casterFront" }),
    [48] = descriptor("TARGET_LOCATION_CASTER_BACK", "location", "none", "location", "casterBack",
        { destination = "casterBack" }),
    [49] = descriptor("TARGET_LOCATION_CASTER_LEFT", "location", "none", "location", "casterLeft",
        { destination = "casterLeft" }),
    [50] = descriptor("TARGET_LOCATION_CASTER_RIGHT", "location", "none", "location", "casterRight",
        { destination = "casterRight" }),
    [51] = descriptor("TARGET_ENUM_GAMEOBJECTS_SCRIPT_AOE_AT_SRC_LOC", "object", "none", "area", "source",
        { destination = "source", scripted = true, resolved = false }),
    [52] = descriptor("TARGET_ENUM_GAMEOBJECTS_SCRIPT_AOE_AT_DEST_LOC", "object", "none", "area", "destination",
        { destination = "destination", scripted = true, resolved = false }),
    [53] = descriptor("TARGET_LOCATION_CASTER_TARGET_POSITION", "location", "none", "location", "target",
        { destination = "targetPosition" }),
    [54] = legacyDescriptor("TARGET_ENUM_UNITS_ENEMY_IN_CONE_54", "unit", "hostile", "cone", "caster"),
    [55] = descriptor("TARGET_LOCATION_CASTER_FRONT_LEAP", "location", "none", "location", "casterFront",
        { destination = "casterFrontLeap" }),
    [56] = legacyDescriptor("TARGET_ENUM_UNITS_RAID_WITHIN_CASTER_RANGE", "unit", "raid", "area", "caster"),
    [57] = legacyDescriptor("TARGET_UNIT_RAID", "unit", "raid", "single", "target"),
    [58] = legacyDescriptor("TARGET_UNIT_RAID_NEAR_CASTER", "unit", "raid", "single", "caster"),
    [59] = legacyDescriptor("TARGET_ENUM_UNITS_FRIEND_IN_CONE", "unit", "friendly", "cone", "caster"),
    [60] = descriptor("TARGET_ENUM_UNITS_SCRIPT_IN_CONE_60", "unit", "unknown", "cone", "caster",
        { scripted = true, resolved = false }),
    [61] = descriptor("TARGET_UNIT_RAID_AND_CLASS", "unit", "raid", "unknown", "target",
        { resolved = false }),
    [62] = descriptor("TARGET_PLAYER_RAID_NYI", "unit", "raid", "unknown", "unknown",
        { nyi = true, resolved = false }),
    [63] = descriptor("TARGET_LOCATION_UNIT_POSITION", "location", "none", "location", "target",
        { destination = "unitPosition" }),
}

local function dbcArray(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if ok and type(value) == "table" then return value end
    return nil
end

local function copyDescriptor(code)
    local number = tonumber(code) or 0
    local known = TARGET[number]
    if not known then
        return { code = number, name = "TARGET_UNKNOWN", kind = "unknown",
            relation = "unknown", shape = "unknown", center = "unknown",
            resolved = false, scripted = false }
    end
    local out = { code = number, name = known.name, kind = known.kind,
        relation = known.relation, shape = known.shape, center = known.center,
        resolved = known.resolved, scripted = known.scripted == true }
    if known.destination then out.destination = known.destination end
    if known.deployable then out.deployable = true end
    if known.nyi then out.nyi = true end
    return out
end

local function copyLegacyTarget(code)
    local number = tonumber(code) or 0
    local known = TARGET[number]
    if not (known and known.legacy) then
        return { code = number, relation = "unknown",
            shape = "unknown", center = "unknown" }
    end
    return { code = number, relation = known.legacyRelation or known.relation,
        shape = known.legacyShape or known.shape,
        center = known.legacyCenter or known.center }
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
    local implicitA = tonumber(targetsA and targetsA[index]) or 0
    local implicitB = tonumber(targetsB and targetsB[index]) or 0
    local first = copyLegacyTarget(implicitA)
    local second = copyLegacyTarget(implicitB)
    local target = chooseTarget(first, second)
    local radiusIndex = tonumber(radii and radii[index])
    local chainTargets = tonumber(chains and chains[index])
    if chainTargets and chainTargets > 1 and target.shape == "single" then
        target.shape, target.center = "chain", "target"
    end
    return { index = index, effect = tonumber(effects and effects[index]) or 0,
        implicitA = implicitA, implicitB = implicitB,
        relation = target.relation, shape = target.shape, center = target.center,
        radiusIndex = radiusIndex, radius = RADIUS[radiusIndex],
        -- An area effect without a positive, mapped radius is unknown. A zero
        -- radius on a single-target effect merely means radius is inapplicable.
        radiusKnown = not isArea(target) or radiusIndex ~= nil
            and radiusIndex > 0 and RADIUS[radiusIndex] ~= nil,
        maxTargets = chainTargets and chainTargets > 0 and chainTargets or nil }
end

-- Return a fresh rich enum descriptor only to callers that need semantic
-- target detail.  These tables intentionally do not enter Facts(), which is
-- embedded in every action and deep-copied during root observation.
function T:Describe(code)
    return copyDescriptor(code)
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
