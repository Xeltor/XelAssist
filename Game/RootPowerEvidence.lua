-- Evaluation-local sharing for mutable player power inputs. Rank actions keep
-- separate immutable records while identical live weapon and spell-power lanes
-- are queried only once during a root observation.
XelAssist.Game.RootPowerEvidence = {}
local E = XelAssist.Game.RootPowerEvidence

local function copy(value, depth, seen)
    if type(value) ~= "table" or depth <= 0 then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, child = {}, nil, nil
    seen[value] = out
    for key, child in pairs(value) do
        out[key] = copy(child, depth - 1, seen)
    end
    return out
end

local function cacheFor(observed)
    if not observed.rootPowerEvidence then
        observed.rootPowerEvidence = { basis = {}, weapon = {}, bonus = {} }
    end
    return observed.rootPowerEvidence
end

local function basis(cache, action, facts)
    local actionFacts = action.facts or {}
    local ranged = actionFacts.ranged and facts.school == 0
    local key = (ranged and "ranged" or "melee")
        .. (facts.weaponNormalized and ":normalized" or ":ordinary")
    local record = cache.basis[key]
    if record then return record end
    local weapon = XelAssist.Game.WeaponPower
    local ok, value, evidence
    if weapon and weapon.Basis then
        ok, value, evidence = pcall(weapon.Basis, weapon, action, facts)
    else
        local capabilities = XelAssist.Game.Capabilities or {}
        local fn = ranged and capabilities.RangedDamage
            or capabilities.WeaponDamage
        ok, value = pcall(fn, capabilities)
        evidence = { exact = false, gap = "weapon power model" }
    end
    record = { ok = ok, value = ok and value or nil,
        evidence = ok and copy(evidence or {}, 5)
            or { exact = false, gap = "weapon power query failed" } }
    cache.basis[key] = record
    return record
end

local function weaponDamage(cache, lane)
    local record = cache.weapon[lane]
    if record then return record end
    local capabilities = XelAssist.Game.Capabilities or {}
    local fn = lane == "ranged" and capabilities.RangedDamage
        or capabilities.WeaponDamage
    local ok, value = pcall(fn, capabilities)
    record = { ok = ok, value = ok and value or nil }
    cache.weapon[lane] = record
    return record
end

local function bonusDamage(cache, school)
    local key = type(school) .. ":" .. tostring(school)
    local record = cache.bonus[key]
    if record then return record end
    local capabilities = XelAssist.Game.Capabilities or {}
    local ok, value = pcall(capabilities.BonusDamage, capabilities, school)
    record = { ok = ok, value = ok and value or nil }
    cache.bonus[key] = record
    return record
end

function E:Capture(observed, action, facts, actionKey)
    local out, cache = { captured = true }, cacheFor(observed)
    local actionFacts = action.facts or {}
    if tonumber(facts.weaponCoefficient) ~= nil then
        local record = basis(cache, action, facts)
        out.weaponBasisCaptured, out.weaponBasis = true, record.value
        out.weaponEvidence = copy(record.evidence, 5)
    end
    if facts.dbcAverage then
        local value = 0
        if actionFacts.melee and actionFacts.noWeaponDamageFallback ~= true then
            local record = weaponDamage(cache, "melee")
            value = record.ok and tonumber(record.value) or 0
        end
        if actionFacts.ranged and facts.school == 0 then
            local record = weaponDamage(cache, "ranged")
            if record.ok and record.value ~= nil then value = record.value end
        end
        out.dbcWeaponCaptured, out.dbcWeapon = true, tonumber(value) or 0
    end
    local kind = actionFacts.kind
    if (kind == "damage" or kind == "dot") and action.actor ~= "pet" then
        local record = bonusDamage(cache, facts.school)
        out.bonusCaptured, out.bonusDamage = true,
            record.ok and math.max(0, tonumber(record.value) or 0) or 0
        out.bonusKnown = record.ok
    end
    observed.powerRecords[actionKey] = out
    return out
end
