-- Recommendation-neutral spell mechanics copied from the installed client.
-- Descriptors are cached evidence, not rotation facts: explicit Combat.Knowledge
-- remains authoritative and graph consumers must opt in separately.
XelAssist.Game.SpellSemantics = {}
local S = XelAssist.Game.SpellSemantics
S.MAX_TRIGGER_DEPTH = 4
S.MAX_TRIGGER_NODES = 16
local ARRAY_FIELDS = { "effect", "effectDieSides", "effectBaseDice", "effectDicePerLevel",
    "effectRealPointsPerLevel", "effectBasePoints", "effectMechanic",
    "effectImplicitTargetA", "effectImplicitTargetB", "effectRadiusIndex",
    "effectApplyAuraName", "effectAmplitude", "effectMultipleValue",
    "effectChainTarget", "effectItemType", "effectMiscValue",
    "effectTriggerSpell", "effectPointsPerComboPoint",
}
local SCALAR_FIELDS = { "school", "powerType", "attributes", "attributesEx" }
local RESOURCE = { [0] = "mana", [1] = "rage", [2] = "focus",
    [3] = "energy", [4] = "happiness" }
local DISPEL = { [1] = "magic", [2] = "curse", [3] = "disease",
    [4] = "poison", [9] = "enrage" }
local AURA_CARRIER = { [6] = "unit", [27] = "persistentArea", [35] = "partyArea",
    [119] = "petArea", [128] = "friendlyArea",
    [129] = "hostileArea", [132] = "raidArea", [133] = "ownerArea" }
local WEAPON_DAMAGE = { [17] = "noSchool", [31] = "percent", [58] = "ordinary",
    [121] = "normalized" }
local SUMMON = { [28] = "generic", [41] = "wild", [42] = "guardian",
    [56] = "pet", [74] = "totem", [87] = "totemSlot1",
    [88] = "totemSlot2", [89] = "totemSlot3", [90] = "totemSlot4",
    [102] = "dismissPet", [104] = "objectSlot1", [105] = "objectSlot2",
    [106] = "objectSlot3", [107] = "objectSlot4", [109] = "deadPet",
    [112] = "demon" }
local CONTROL_AURA = { [2] = "possess", [5] = "confuse", [6] = "charm", [7] = "fear",
    [12] = "stun", [25] = "pacify", [26] = "root",
    [27] = "silence", [33] = "slow", [60] = "pacifySilence",
    [67] = "disarm" }
local MODIFIER_AURA = { [13] = "damageDone", [22] = "resistance",
    [29] = "stat", [30] = "skill", [34] = "health", [35] = "power",
    [47] = "parry", [49] = "dodge", [51] = "block", [52] = "critical",
    [54] = "hit", [55] = "spellHit", [57] = "spellCritical",
    [71] = "spellCriticalSchool", [85] = "powerRegen",
    [99] = "attackPower", [124] = "rangedAttackPower", [135] = "healing" }
local RAW_AURA_FIXTURE = { [13750] = { [110] = true },
    [12051] = { [110] = true, [134] = true } }
local function copyThree(value)
    if type(value) ~= "table" then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        if value[index] == nil then return nil end
        out[index] = value[index]
    end
    return out
end
local function readArray(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if not ok then return nil end
    return copyThree(value)
end
local function readScalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if ok then return value end
    return nil
end
local function flagSet(value, flag)
    value = tonumber(value)
    return value and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end
local function rawDescriptor(owner, spellId)
    owner._rawCache = owner._rawCache or {}
    if owner._rawCache[spellId] then return owner._rawCache[spellId] end
    local raw = { spellId = spellId, arrays = {}, scalars = {},
        available = type(GetSpellRecField) == "function", complete = true }
    local index, field = nil, nil
    for index = 1, table.getn(ARRAY_FIELDS) do
        field = ARRAY_FIELDS[index]
        raw.arrays[field] = readArray(spellId, field)
        if not raw.arrays[field] then raw.complete = false end
    end
    for index = 1, table.getn(SCALAR_FIELDS) do
        field = SCALAR_FIELDS[index]
        raw.scalars[field] = readScalar(spellId, field)
        if raw.scalars[field] == nil then raw.complete = false end
    end
    if not raw.arrays.effect then raw.available = false end
    owner._rawCache[spellId] = raw
    return raw
end
local function target(code, resolution, effectIndex)
    code = tonumber(code) or 0
    local topology = XelAssist.Game.SpellTopology
    local out = topology and topology.Describe and topology:Describe(code)
        or { code = code, kind = "unknown", relation = "unknown",
            shape = "unknown", center = "unknown", resolved = false }
    if out.resolved == false and out.relation == "polymorphic" and resolution then
        local relations = resolution.effectRelations
        local relation = relations and relations[effectIndex]
            or resolution.targetRelation
        if relation == "self" or relation == "friendly" or relation == "hostile"
            or relation == "pet" or relation == "party" or relation == "raid" then
            out.relation, out.resolved = relation, true
        end
    end
    out.exact = out.resolved ~= false
    return out
end
local function effectRecipient(record, resolution)
    local first = target(record.implicitTargetA, resolution, record.index)
    local second = target(record.implicitTargetB, resolution, record.index)
    local exact = first.exact and second.exact
    if first.code == 0 and second.code == 0 then
        return { exact = true, present = false, primary = first,
            first = first, second = second }
    end
    local primary = first.code ~= 0 and first or second
    return { exact = exact, present = true, primary = primary,
        first = first, second = second }
end
local function reject(out, record, reason)
    out.complete, out.admissible, record.complete = false, false, false
    table.insert(out.reasons, reason)
    table.insert(record.reasons, reason)
end
local function atom(out, record, kind, extra)
    local value = { kind = kind, spellId = out.spellId,
        effectIndex = record.index, opcode = record.opcode,
        recipient = record.recipient }
    local key, item = nil, nil
    for key, item in pairs(extra or {}) do value[key] = item end
    table.insert(record.atoms, value)
    table.insert(out.atoms, value)
    return value
end
local function appendTriggeredAtoms(out, child, triggerSpellId)
    local index, key, item
    for index = 1, table.getn(child.atoms or {}) do
        local projected = { triggeredBySpellId = triggerSpellId }
        for key, item in pairs(child.atoms[index]) do
            if key ~= "child" then projected[key] = item end
        end
        table.insert(out.atoms, projected)
    end
end
local function selfRecipient()
    local value = target(1)
    return { exact = true, present = true, primary = value,
        first = value, second = target(0) }
end
local function requireRecipient(out, record, allowLocation)
    local recipient = record.recipient
    if not recipient.exact then
        reject(out, record, "effect " .. record.index .. " recipient is unresolved")
        return false
    end
    if not recipient.present then
        reject(out, record, "effect " .. record.index .. " has no recipient")
        return false
    end
    if not allowLocation and recipient.primary.kind == "location" then
        reject(out, record, "effect " .. record.index .. " has only a location recipient")
        return false
    end
    return true
end
local function auraAtom(out, record)
    local aura = record.aura
    if aura == 3 or aura == 89 then
        atom(out, record, "damage", { delivery = "periodic",
            percent = aura == 89, aura = aura })
    elseif aura == 8 then
        atom(out, record, "healing", { delivery = "periodic", aura = aura })
    elseif aura == 20 then
        atom(out, record, "observedHealthModifier", { delivery = "periodic", aura = aura })
    elseif aura == 21 or aura == 24 then
        atom(out, record, "resourceGain", { delivery = "periodic", aura = aura,
            resource = aura == 21 and "mana" or RESOURCE[record.miscValue] })
        if aura == 24 and not RESOURCE[record.miscValue] then
            reject(out, record, "effect " .. record.index .. " has an unknown periodic resource")
        end
    elseif aura == 64 then
        atom(out, record, "resourceLoss", { delivery = "periodic", aura = aura,
            resource = "mana" })
        atom(out, record, "resourceGain", { delivery = "periodic", aura = aura,
            resource = "mana", recipient = selfRecipient() })
    elseif aura == 11 then
        atom(out, record, "taunt", { delivery = "aura", aura = aura })
    elseif aura == 16 then atom(out, record, "stealth", { aura = aura })
    elseif aura == 36 then atom(out, record, "shapeshift", {
        aura = aura, form = record.miscValue })
    elseif aura == 78 then atom(out, record, "mounted", { aura = aura })
    elseif CONTROL_AURA[aura] then atom(out, record, "control", {
        aura = aura, control = CONTROL_AURA[aura] })
    elseif MODIFIER_AURA[aura] then atom(out, record, "modifier", {
        aura = aura, modifier = MODIFIER_AURA[aura] })
    elseif RAW_AURA_FIXTURE[out.spellId] and RAW_AURA_FIXTURE[out.spellId][aura] then
        atom(out, record, "aura", { aura = aura,
            semantic = "fixtureWhitelistedRaw" })
    else
        reject(out, record, "effect " .. record.index .. " aura "
            .. tostring(aura) .. " is unresolved")
    end
end
local function effectRecord(raw, index, resolution)
    local arrays = raw.arrays
    local function value(field) return arrays[field] and arrays[field][index] end
    local record = { index = index, opcode = tonumber(value("effect")) or 0,
        aura = tonumber(value("effectApplyAuraName")) or 0,
        mechanic = tonumber(value("effectMechanic")) or 0,
        implicitTargetA = tonumber(value("effectImplicitTargetA")) or 0,
        implicitTargetB = tonumber(value("effectImplicitTargetB")) or 0,
        radiusIndex = tonumber(value("effectRadiusIndex")) or 0,
        amplitude = tonumber(value("effectAmplitude")) or 0,
        multipleValue = tonumber(value("effectMultipleValue")) or 0,
        chainTargets = tonumber(value("effectChainTarget")) or 0,
        itemType = tonumber(value("effectItemType")) or 0,
        miscValue = tonumber(value("effectMiscValue")) or 0,
        triggerSpell = tonumber(value("effectTriggerSpell")) or 0,
        basePoints = tonumber(value("effectBasePoints")) or 0,
        baseDice = tonumber(value("effectBaseDice")) or 0,
        dieSides = tonumber(value("effectDieSides")) or 0,
        dicePerLevel = tonumber(value("effectDicePerLevel")) or 0,
        realPointsPerLevel = tonumber(value("effectRealPointsPerLevel")) or 0,
        pointsPerComboPoint = tonumber(value("effectPointsPerComboPoint")) or 0,
        complete = true, reasons = {}, atoms = {} }
    record.recipient = effectRecipient(record, resolution)
    return record
end
local function handlePotency(out, record)
    local opcode, index = record.opcode, record.index
    if opcode == 2 or opcode == 7 then
        requireRecipient(out, record, false)
        atom(out, record, "damage", { delivery = "direct",
            environmental = opcode == 7, school = out.school })
    elseif WEAPON_DAMAGE[opcode] then
        requireRecipient(out, record, false)
        atom(out, record, "weaponDamage", { mode = WEAPON_DAMAGE[opcode] })
    elseif opcode == 9 then
        requireRecipient(out, record, false)
        atom(out, record, "damage", { delivery = "direct", school = out.school,
            leech = true })
        atom(out, record, "healing", { delivery = "leech",
            multiplier = record.multipleValue, recipient = selfRecipient() })
    elseif opcode == 10 or opcode == 67 or opcode == 75 then
        requireRecipient(out, record, false)
        atom(out, record, "healing", { delivery = "direct",
            maximumHealth = opcode == 67, mechanical = opcode == 75 })
    elseif opcode == 8 or opcode == 62 or opcode == 66 then
        requireRecipient(out, record, false)
        local resource = RESOURCE[record.miscValue]
        if not resource then reject(out, record,
            "effect " .. index .. " has an unknown resource") end
        if opcode == 8 or opcode == 62 then
            atom(out, record, "resourceLoss", { resource = resource })
        else atom(out, record, "resourceLoss", { resource = resource,
            recipient = selfRecipient() }) end
        if opcode == 8 or opcode == 66 then
            atom(out, record, "resourceGain", { resource = resource,
                recipient = opcode == 8 and selfRecipient() or record.recipient,
                multiplier = record.multipleValue })
        else atom(out, record, "damage", { delivery = "powerBurn",
            resource = resource, multiplier = record.multipleValue,
            school = out.school }) end
    elseif opcode == 30 then
        requireRecipient(out, record, false)
        atom(out, record, "resourceGain", { resource = RESOURCE[record.miscValue] })
        if not RESOURCE[record.miscValue] then reject(out, record,
            "effect " .. index .. " has an unknown resource") end
    elseif opcode == 65 then
        requireRecipient(out, record, false)
        atom(out, record, "healthLoss", { recipient = selfRecipient() })
        atom(out, record, "healing", { delivery = "healthFunnel" })
    else return false end
    return true
end
local function handleSupport(out, record)
    local opcode, index = record.opcode, record.index
    if opcode == 38 then
        requireRecipient(out, record, false)
        atom(out, record, "dispel", { dispelType = DISPEL[record.miscValue],
            dispelCode = record.miscValue })
        if not DISPEL[record.miscValue] then reject(out, record,
            "effect " .. index .. " has an unknown dispel type") end
    elseif opcode == 108 then
        requireRecipient(out, record, false)
        atom(out, record, "dispelMechanic", { mechanic = record.miscValue })
        if record.miscValue <= 0 then reject(out, record,
            "effect " .. index .. " has no dispel mechanic") end
    elseif opcode == 63 or opcode == 91 then
        requireRecipient(out, record, false)
        atom(out, record, "threat", { allTargets = opcode == 91 })
    elseif opcode == 114 then
        requireRecipient(out, record, false)
        atom(out, record, "taunt", { delivery = "direct" })
    elseif SUMMON[opcode] then
        if opcode ~= 102 then requireRecipient(out, record, true) end
        atom(out, record, opcode == 102 and "dismiss" or "summon",
            { summonType = SUMMON[opcode], entry = record.miscValue })
    elseif AURA_CARRIER[opcode] then
        requireRecipient(out, record, false)
        atom(out, record, "auraCarrier", { carrier = AURA_CARRIER[opcode],
            aura = record.aura })
        auraAtom(out, record)
    else return false end
    return true
end
local describe
local function handleOther(owner, out, record, context, depth)
    local opcode, index = record.opcode, record.index
    if opcode == 32 or opcode == 64 then
        if record.triggerSpell <= 0 then
            reject(out, record, "effect " .. index .. " has no trigger child")
        elseif depth >= owner.MAX_TRIGGER_DEPTH then
            reject(out, record, "trigger depth exceeded")
        else
            local child = describe(owner, record.triggerSpell, context, depth + 1)
            atom(out, record, "trigger", { immediate = true,
                childSpellId = record.triggerSpell, childComplete = child.complete })
            appendTriggeredAtoms(out, child, record.triggerSpell)
            if not child.complete then reject(out, record, "trigger child "
                .. tostring(record.triggerSpell) .. " is incomplete: "
                .. tostring(child.reasons[1])) end
        end
    elseif opcode == 3 then reject(out, record, "dummy effect requires server script")
    elseif opcode == 77 then reject(out, record, "script effect requires server script")
    else reject(out, record, "effect opcode " .. tostring(opcode)
        .. " is unresolved") end
end
local function handleEffect(owner, out, record, context, depth)
    local opcode = record.opcode
    if opcode == 0 then
        if record.aura ~= 0 or record.triggerSpell ~= 0 then reject(out, record,
            "inactive effect " .. record.index .. " contains semantic data") end
    elseif not handlePotency(out, record) and not handleSupport(out, record) then
        handleOther(owner, out, record, context, depth)
    end
    if record.triggerSpell ~= 0 and opcode ~= 32 and opcode ~= 64 then
        reject(out, record, "non-immediate trigger reference is unresolved")
    end
    if not record.recipient.exact and opcode ~= 0 then
        reject(out, record, "effect " .. record.index .. " recipient metadata is unknown")
    end
end
describe = function(owner, spellId, context, depth)
    context.nodes = context.nodes + 1
    local out = { spellId = spellId, available = false, complete = true,
        admissible = true, atoms = {}, effects = {}, reasons = {},
        source = "installed-client Spell.dbc semantic descriptor" }
    if context.nodes > owner.MAX_TRIGGER_NODES then
        out.complete, out.admissible = false, false
        table.insert(out.reasons, "trigger node budget exceeded")
        return out
    end
    if context.visiting[spellId] then
        out.complete, out.admissible = false, false
        table.insert(out.reasons, "trigger cycle at spell " .. tostring(spellId))
        return out
    end
    local raw = rawDescriptor(owner, spellId)
    out.available = raw.available
    if not raw.available then
        out.complete, out.admissible = false, false
        table.insert(out.reasons, "spell record unavailable")
        return out
    end
    if not raw.complete then
        out.complete, out.admissible = false, false
        table.insert(out.reasons, "spell DBC fields are incomplete")
    end
    out.school, out.powerType = raw.scalars.school, raw.scalars.powerType
    local attributes, attributesEx = raw.scalars.attributes, raw.scalars.attributesEx
    if attributes ~= nil then out.passive = flagSet(attributes, 64) end
    if attributesEx ~= nil then out.channel = flagSet(attributesEx, 4)
        or flagSet(attributesEx, 64) end
    context.visiting[spellId] = true
    local index
    for index = 1, 3 do
        local record = effectRecord(raw, index, context.resolution)
        table.insert(out.effects, record)
        handleEffect(owner, out, record, context, depth)
    end
    context.visiting[spellId] = nil
    return out
end
local function copyTree(value)
    if type(value) ~= "table" then return value end
    local out, key, item = {}, nil, nil
    for key, item in pairs(value) do out[key] = copyTree(item) end
    return out
end
local function cachedDescriptor(owner, spellId)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then return { spellId = spellId,
        available = false, complete = false, admissible = false, atoms = {},
        effects = {}, reasons = { "spell identity unavailable" } }
    end
    owner._cache = owner._cache or {}
    if owner._cache[spellId] then return owner._cache[spellId] end
    local out = describe(owner, spellId, { nodes = 0, visiting = {} }, 0)
    owner._cache[spellId] = out
    return out
end
function S:Decode(spellId) return copyTree(cachedDescriptor(self, spellId)) end

-- Only recipient context is resolved here; magnitude, duration and cadence
-- remain deliberately unavailable to consumers in this load-only checkpoint.
function S:Resolve(spellId, resolution)
    spellId = type(spellId) == "table" and spellId.spellId or spellId
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then return self:Decode(spellId) end
    return describe(self, spellId,
        { nodes = 0, visiting = {}, resolution = resolution }, 0)
end

local function hasExplicitFacts(action)
    if not (action and type(action.facts) == "table") then return false end
    if action.facts.inferred == true then return false end
    local key
    for key in pairs(action.facts) do return true end
    return false
end

function S:InferAction(action, resolution)
    if hasExplicitFacts(action) then
        return nil, "explicit Combat.Knowledge is authoritative", nil
    end
    local descriptor = self:Resolve(action and action.spellId, resolution)
    if not descriptor.complete then
        return nil, descriptor.reasons[1] or "spell semantics incomplete", descriptor
    end
    if descriptor.passive then return nil, "passive spell", descriptor end
    local index
    for index = 1, table.getn(descriptor.atoms) do
        return nil, "no registered consumer for semantic atom "
            .. tostring(descriptor.atoms[index].kind), descriptor
    end
    return nil, "spell has no consumable semantic atoms", descriptor
end

-- No consumer is wired in this checkpoint. Keep Apply as a non-mutating
-- boundary so loading semantic evidence cannot alter recommendations.
function S:Apply(action, out, resolution)
    local inferred, reason, descriptor = self:InferAction(action, resolution)
    return false, reason, descriptor
end

function S:Invalidate()
    self._cache, self._rawCache = nil, nil
end
