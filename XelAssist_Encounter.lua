-- Data-driven encounter and unit context. Creature IDs are join keys and
-- evidence, never names that dispatch a hand-authored priority list.
XelAssistEncounter = {}
local E = XelAssistEncounter

local function call(fn, value)
    if not fn then return nil end
    local ok, result = pcall(fn, value)
    if ok then return result end
    return nil
end

function E:Unit(unit, relation)
    if not unit or not UnitExists(unit) then return nil end
    local _, guid = UnitExists(unit)
    local record = { id = unit, unit = unit, guid = guid, relation = relation,
        health = UnitHealth(unit) or 0, healthMax = UnitHealthMax(unit) or 0,
        level = UnitLevel and UnitLevel(unit) or nil,
        classification = UnitClassification and UnitClassification(unit) or nil,
        creatureType = UnitCreatureType and UnitCreatureType(unit) or nil,
        reaction = UnitReaction and UnitReaction("player", unit) or nil,
        raidMarker = GetRaidTargetIndex and GetRaidTargetIndex(unit) or nil,
        inCombat = UnitAffectingCombat and UnitAffectingCombat(unit) and true or false,
        dead = UnitIsDead(unit) and true or false }
    record.creatureId = call(UnitCreatureID, unit)
    record.creatureTypeId = call(UnitCreatureTypeID, unit)
    record.creatureFamilyId = call(UnitCreatureFamilyID, unit)
    record.ownerGuid = call(UnitOwnerGUID, unit)
    record.isPlayer = UnitIsPlayer and UnitIsPlayer(unit) and true or false
    record.isPet = UnitIsPet and UnitIsPet(unit) and true or false
    record.isMinion = UnitIsMinion and UnitIsMinion(unit) and true or false
    record.isPossessed = UnitIsPossessed and UnitIsPossessed(unit) and true or false
    return record
end

function E:Auras(unit, filter)
    local out = { list = {}, byName = {}, available = false }
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras and UnitExists(unit)) then return out end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
    if not ok or type(list) ~= "table" then return out end
    out.available = true
    local _, playerGuid = UnitExists("player")
    local i
    for i = 1, table.getn(list) do
        local aura = list[i]
        if type(aura) == "table" and aura.name then
            local remaining
            if aura.expirationTime and aura.expirationTime > 0 then
                remaining = math.max(0, aura.expirationTime - GetTime())
            end
            local mine
            if aura.sourceUnit == "player" then mine = true
            elseif aura.sourceGUID and playerGuid then mine = aura.sourceGUID == playerGuid
            elseif aura.sourceUnit or aura.sourceGUID then mine = false end
            local normalized = { name = aura.name, spellId = aura.spellId,
                stacks = aura.applications, duration = aura.duration,
                remaining = remaining, sourceUnit = aura.sourceUnit,
                sourceGUID = aura.sourceGUID, mine = mine, dispelType = aura.dispelName,
                stealable = aura.isStealable, boss = aura.isBossAura,
                playerOrPet = aura.isFromPlayerOrPlayerPet, points = aura.points }
            table.insert(out.list, normalized)
            if not out.byName[normalized.name] or normalized.mine then
                out.byName[normalized.name] = normalized
            end
        end
    end
    return out
end

function E:Snapshot()
    local inInstance, instanceType
    if IsInInstance then inInstance, instanceType = IsInInstance() end
    return { zone = GetRealZoneText and GetRealZoneText() or nil,
        subZone = GetSubZoneText and GetSubZoneText() or nil,
        minimapZone = GetMinimapZoneText and GetMinimapZoneText() or nil,
        inInstance = inInstance and true or false, instanceType = instanceType,
        target = self:Unit("target", "enemy"),
        targetHarmful = self:Auras("target", "HARMFUL"),
        targetHelpful = self:Auras("target", "HELPFUL") }
end
