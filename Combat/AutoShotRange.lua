-- Identity-bound Auto Shot range and projectile evidence. Nampower owns the
-- dead zone; UnitDistanceSquared matches the server's center-distance flight.
XelAssist.Combat.AutoShotRange = {}
local R = XelAssist.Combat.AutoShotRange

local AUTO_SHOT_ID = 75
local CANONICAL = { [1583] = 75, [52637] = 52636 }

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function unitGuid(unit)
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if ok and exists and exists ~= 0 then return guid end
    return nil
end

function R:CanonicalSpellId(spellId)
    spellId = tonumber(spellId) or AUTO_SHOT_ID
    return CANONICAL[spellId] or spellId
end

function R:SpellSpeed(spellId)
    if type(GetSpellRecField) ~= "function" then return nil, nil end
    local canonical = self:CanonicalSpellId(spellId)
    local ok, value = pcall(GetSpellRecField, canonical, "speed")
    value = ok and tonumber(value) or nil
    if not value or value <= 0 then return nil, nil end
    return value, "Nampower Spell.dbc speed"
end

local function centerDistance()
    if type(UnitDistanceSquared) ~= "function" then return nil end
    local ok, squared, checked = pcall(UnitDistanceSquared, "target")
    if not ok or checked ~= true then return nil end
    squared = ok and tonumber(squared) or nil
    if not squared or squared < 0 then return nil end
    return math.sqrt(squared)
end

local function clearTargetEvidence(out)
    out.rangeVerdict = nil
    out.projectileDistance, out.projectileDistanceKind = nil, nil
    out.projectileSpeed, out.projectileSpeedSource = nil, nil
end

local function invalidateTargetEvidence(out)
    clearTargetEvidence(out)
    out.distance, out.distanceKind = nil, nil
end

-- `rangeChecked` prevents Snapshot from repeating a captured unknown outside
-- the state/executor identity boundary that produced it.
function R:Evidence(evidence, expectedGuid, spellId)
    local out = copy(evidence)
    local canonical = self:CanonicalSpellId(spellId)
    if out.rangeChecked then
        if expectedGuid ~= nil and out.rangeTargetGuid ~= expectedGuid
            or out.rangeSpellId ~= canonical then
            out.rangeIdentityVerified = false
            invalidateTargetEvidence(out)
        end
        return out
    end
    out.rangeChecked, out.rangeIdentityVerified = true, false
    clearTargetEvidence(out)
    local before = unitGuid("target")
    expectedGuid = expectedGuid or before
    out.rangeTargetGuid = expectedGuid
    out.rangeSpellId = canonical
    if before == nil or expectedGuid == nil or before ~= expectedGuid then return out end

    local capabilities = XelAssist.Game and XelAssist.Game.Capabilities
    if canonical > 0 and capabilities and capabilities.InRange then
        local ok, verdict = pcall(capabilities.InRange, capabilities,
            canonical, "target")
        if ok then out.rangeVerdict = verdict end
    end
    if out.distance == nil and capabilities and capabilities.Distance then
        local ok, distance, kind = pcall(
            capabilities.Distance, capabilities, "target")
        if ok then out.distance, out.distanceKind = distance, kind end
    end
    out.projectileDistance = centerDistance()
    if out.projectileDistance ~= nil then out.projectileDistanceKind = "center" end
    if canonical > 0 then
        out.projectileSpeed, out.projectileSpeedSource = self:SpellSpeed(canonical)
    end

    local after = unitGuid("target")
    if after ~= before or after ~= expectedGuid then
        invalidateTargetEvidence(out)
        return out
    end
    out.rangeIdentityVerified = true
    return out
end

function R:TargetEligible(evidence, expectedGuid, spellId)
    evidence = evidence or {}
    if evidence.hostile == false then return false, "hostile target" end
    if evidence.lineOfSight == false then return false, "line of sight" end
    if evidence.rangeIdentityVerified ~= true
        or expectedGuid ~= nil and evidence.rangeTargetGuid ~= expectedGuid
        or evidence.rangeSpellId ~= self:CanonicalSpellId(spellId) then
        return false, "Auto Shot target evidence changed"
    end
    if evidence.rangeVerdict == false then return false, "range" end
    if evidence.rangeVerdict ~= true then return false, "Auto Shot range unknown" end
    return true, nil
end

function R:StartEligible(evidence, expectedGuid, spellId)
    local eligible, reason = self:TargetEligible(evidence, expectedGuid, spellId)
    if not eligible then return false, reason end
    if evidence.casting then return false, "casting" end
    return true, nil
end

function R:Projectable(evidence, targetGuid, spellId)
    return evidence and evidence.rangeChecked == true
        and evidence.rangeIdentityVerified == true
        and targetGuid ~= nil and evidence.rangeTargetGuid == targetGuid
        and evidence.rangeSpellId == self:CanonicalSpellId(spellId)
        and evidence.rangeVerdict == true
        and tonumber(evidence.projectileDistance) ~= nil
        and evidence.projectileDistanceKind == "center"
        and tonumber(evidence.projectileSpeed) ~= nil
        and tonumber(evidence.projectileSpeed) > 0
end

function R:LaunchTiming(targetGuid, spellId)
    if targetGuid == nil or unitGuid("target") ~= targetGuid then return nil end
    local distance = centerDistance()
    local speed, source = self:SpellSpeed(spellId)
    if unitGuid("target") ~= targetGuid or distance == nil or speed == nil then
        return nil
    end
    return math.max(5, distance) / speed, distance, speed, source
end
