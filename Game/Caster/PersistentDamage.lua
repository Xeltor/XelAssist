-- Exact direct-plus-periodic spell shapes for Mage, Warlock and Priest.
-- Classification runs while the spell catalogue is built; graph search only
-- consumes the copied facts and never reads the live DBC or duration API.
XelAssist.Game.Caster = XelAssist.Game.Caster or {}
XelAssist.Game.Caster.PersistentDamage = {}
local P = XelAssist.Game.Caster.PersistentDamage

local FAMILY = { [3] = true, [5] = true, [6] = true }
local MAGE = 3
local DIRECT_DAMAGE = 2
local APPLY_AURA = 6
local PERIODIC_DAMAGE = 3
local SELECTED_HOSTILE = 6
local PASSIVE = 64
local CHANNELED_1 = 4
local CHANNELED_2 = 64
-- Audited low SpellFamilyFlags from the installed player ranks. These prove
-- one spell lifecycle, unlike SpellFamilyName, which proves only class
-- ownership. Extra rank/talent bits are allowed around the required atoms.
local MAGE_FIRE_GROUP = 1073741824
local MAGE_FIREBALL_GROUP = 1
local MAGE_PYROBLAST_GROUP = 4194304
local WARLOCK_IMMOLATE_GROUP = 4
local PRIEST_HOLY_FIRE_GROUP = 1048576

local function flagSet(value, flag)
    value = tonumber(value)
    return value and value >= 0 and math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1 or false
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if ok then return tonumber(value) end
    return nil
end

local function array(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(value) ~= "table" then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        if value[index] == nil then return nil end
        out[index] = tonumber(value[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function durationMilliseconds(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, spellId)
    value = ok and tonumber(value) or nil
    if not value or value <= 0 then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function copiedShape(source)
    return source and copy(source) or nil
end

function P:Invalidate()
    self.recognized = nil
end

local function exactSelectedHostile(targetA, targetB, chains, index)
    return targetA[index] == SELECTED_HOSTILE and targetB[index] == 0
        and (chains[index] == 0 or chains[index] == 1)
end

local function lifecycle(family, flags)
    if not flags or flags < 0 or flags > 4294967295
        or math.floor(flags) ~= flags then return nil end
    if family == MAGE and flagSet(flags, MAGE_FIRE_GROUP)
        and (flagSet(flags, MAGE_FIREBALL_GROUP)
            or flagSet(flags, MAGE_PYROBLAST_GROUP)) then
        return "damage"
    elseif family == 5 and flagSet(flags, WARLOCK_IMMOLATE_GROUP) then
        return "dot"
    elseif family == 6 and flagSet(flags, PRIEST_HOLY_FIRE_GROUP) then
        return "dot"
    end
    return nil
end

function P:Inspect(spellId)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then return nil, "spell identity unavailable" end
    local cached = self.recognized and self.recognized[spellId]
    if cached then return copiedShape(cached) end
    if type(GetSpellRecField) ~= "function" then
        return nil, "installed spell data unavailable"
    end

    local family, school = scalar(spellId, "spellFamilyName"),
        scalar(spellId, "school")
    if not FAMILY[family] then return nil, "unsupported caster family" end
    if not school or school < 1 or school > 6 then
        return nil, "non-magical damage school"
    end
    local attributes, attributesEx = scalar(spellId, "attributes"),
        scalar(spellId, "attributesEx")
    local familyFlags = scalar(spellId, "spellFamilyFlags")
    if attributes == nil or attributesEx == nil or familyFlags == nil then
        return nil, "spell attributes unavailable"
    end
    if flagSet(attributes, PASSIVE) then return nil, "passive spell" end
    if flagSet(attributesEx, CHANNELED_1)
        or flagSet(attributesEx, CHANNELED_2) then
        return nil, "channeled delivery"
    end

    local effects = array(spellId, "effect")
    local auras = array(spellId, "effectApplyAuraName")
    local targetA = array(spellId, "effectImplicitTargetA")
    local targetB = array(spellId, "effectImplicitTargetB")
    local amplitudes = array(spellId, "effectAmplitude")
    local chains = array(spellId, "effectChainTarget")
    if not (effects and auras and targetA and targetB
        and amplitudes and chains) then
        return nil, "effect shape unavailable"
    end
    local durationMs = durationMilliseconds(spellId)
    if not durationMs then return nil, "persistent duration unavailable" end

    local direct, periodic, interval, index = 0, 0, nil, nil
    for index = 1, 3 do
        local effect, aura = effects[index], auras[index]
        if effect == DIRECT_DAMAGE then
            if aura ~= 0 or not exactSelectedHostile(
                targetA, targetB, chains, index) then
                return nil, "direct recipient is not one selected hostile"
            end
            direct = direct + 1
        elseif effect == APPLY_AURA and aura == PERIODIC_DAMAGE then
            if not exactSelectedHostile(targetA, targetB, chains, index) then
                return nil, "periodic recipient is not one selected hostile"
            end
            local cadence = amplitudes[index]
            if not cadence or cadence <= 0 then
                return nil, "periodic cadence unavailable"
            end
            if interval and interval ~= cadence then
                return nil, "conflicting periodic cadences"
            end
            interval, periodic = cadence, periodic + 1
        elseif effect == 0 then
            if aura ~= 0 or targetA[index] ~= 0 or targetB[index] ~= 0
                or amplitudes[index] ~= 0 or chains[index] ~= 0 then
                return nil, "unused effect slot contains unsupported metadata"
            end
        else
            return nil, "additional effect shape unsupported"
        end
    end
    if direct <= 0 or periodic <= 0 then
        return nil, "not direct plus persistent damage"
    end
    local ticks = durationMs / interval
    if ticks < 1 or math.abs(ticks - math.floor(ticks + 0.5)) > 0.0001 then
        return nil, "duration does not contain exact periodic ticks"
    end

    local shape = { exact = true, spellId = spellId, family = family,
        familyFlags = familyFlags, lifecycle = lifecycle(family, familyFlags),
        school = school, directEffects = direct, periodicEffects = periodic,
        duration = durationMs / 1000, interval = interval / 1000,
        ticks = math.floor(ticks + 0.5),
        source = "installed-client Spell.dbc direct and periodic effects" }
    self.recognized = self.recognized or {}
    self.recognized[spellId] = shape
    return copiedShape(shape)
end

-- Existing explicit facts remain authoritative. Mage impact spells stay
-- repeatable damage actions; already-known Warlock/Priest DoTs keep their
-- application guard. A localized unknown requires an audited family-flag
-- lifecycle; class family ownership alone is deliberately insufficient.
function P:Refine(spellId, prior)
    if prior ~= nil and type(prior) ~= "table" then
        return nil, "existing spell facts invalid"
    end
    if prior and prior.kind ~= "damage" and prior.kind ~= "dot" then
        return nil, "existing spell kind owns another mechanic"
    end
    local shape, reason = self:Inspect(spellId)
    if not shape then return nil, reason end
    local out = copy(prior)
    if not out.kind then
        if not shape.lifecycle then
            return nil, "persistent damage lifecycle unavailable"
        end
        out.kind = shape.lifecycle
        out.inferred = true
    end
    out.dbcDirectPeriodic = true
    out.persistentDamageSource = shape.source
    out.persistentDamageDuration = shape.duration
    out.persistentDamageInterval = shape.interval
    out.persistentDamageTicks = shape.ticks
    out.repeatablePersistentDamage = out.kind == "damage" and true or nil
    return out
end

-- SpellEffectPower has already decoded both magnitudes when this runs. Seal
-- them into one root-captured contract so ActionPower and the graph need no
-- DBC access and localized tooltip prose cannot drop the periodic tail.
function P:ApplyPower(action, out)
    local facts = action and action.facts or {}
    if not facts.dbcDirectPeriodic
        or facts.repeatablePersistentDamage ~= true
        or type(out) ~= "table" then return false end
    local direct = tonumber(out.dbcEffectDirectDamage)
    local periodic = tonumber(out.dbcEffectPeriodicDamage)
    local duration = tonumber(out.duration)
    local interval = tonumber(facts.persistentDamageInterval)
    local ticks = tonumber(facts.persistentDamageTicks)
    if not (direct and direct > 0 and periodic and periodic > 0
        and duration and duration > 0 and interval and interval > 0
        and ticks and ticks >= 1 and math.floor(ticks) == ticks
        and math.abs(duration / interval - ticks) < 0.0001
        and math.abs(duration - (tonumber(
            facts.persistentDamageDuration) or -1)) < 0.0001) then
        return false
    end
    out.directDamage, out.periodicDamage = direct, periodic
    out.average, out.dbcEffectAverage = direct + periodic, direct + periodic
    out.dbcEffectComplete = true
    out.damageTotalSource = facts.persistentDamageSource
    out.periodicInterval = interval
    out.periodicIntervalSource = "client DBC effectAmplitude"
    out.persistentDamage = { exact = true, direct = direct,
        periodic = periodic, duration = duration, interval = interval,
        ticks = ticks,
        source = facts.persistentDamageSource }
    return true
end
