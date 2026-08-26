-- Installed-client Warrior stance consequences. Mutable DBC/talent APIs are
-- read only while sealing a root snapshot; graph transitions consume copied
-- numeric form profiles and never infer a preferred stance or action order.
XelAssist.Game.Player.WarriorStanceEffects = {}
local W = XelAssist.Game.Player.WarriorStanceEffects

W.WARRIOR_CLASS = "WARRIOR"
W.ALL_SCHOOLS = 127
W.DEFIANCE_TALENT_ID = 144
W.DEFIANCE_TAB = 3
W.DEFIANCE_INDEX = 9
W.DEFIANCE_MAX_RANK = 5

W.FORMS = {
    [17] = { key = "battle", passiveSpellId = 21156,
        auras = { 10 } },
    [18] = { key = "defensive", passiveSpellId = 7376,
        auras = { 87, 79, 10 } },
    [19] = { key = "berserker", passiveSpellId = 7381,
        auras = { 52, 87, 10 } },
}

W.DEFIANCE_SPELL_IDS = {
    [1] = 12303, [2] = 12788, [3] = 12789,
    [4] = 12791, [5] = 12792,
}

local PASSIVE_CACHE, DISCOVERY_CACHE, TALENT_CACHE, SNAPSHOT_CACHE = {}, nil, nil, nil

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
    return value
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out, key, child = {}, nil, nil
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = integer(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function spellRecord(spellId)
    local out = { spellId = spellId }
    local fields = { "effect", "effectApplyAuraName", "effectBasePoints",
        "effectBaseDice", "effectDieSides", "effectImplicitTargetA",
        "effectImplicitTargetB", "effectMiscValue" }
    local index
    for index = 1, table.getn(fields) do
        out[fields[index]] = triple(spellId, fields[index])
        if not out[fields[index]] then
            return nil, "installed stance DBC field unavailable"
        end
    end
    return out
end

local function inactive(record, index)
    return record.effect[index] == 0
        and record.effectApplyAuraName[index] == 0
        and record.effectBasePoints[index] == 0
        and record.effectBaseDice[index] == 0
        and record.effectDieSides[index] == 0
        and record.effectImplicitTargetA[index] == 0
        and record.effectImplicitTargetB[index] == 0
        and record.effectMiscValue[index] == 0
end

local function amount(record, index, expectedAura, expectedMisc)
    if record.effect[index] ~= 6
        or record.effectApplyAuraName[index] ~= expectedAura
        or record.effectImplicitTargetA[index] ~= 1
        or record.effectImplicitTargetB[index] ~= 0
        or record.effectMiscValue[index] ~= expectedMisc
        or record.effectBaseDice[index] ~= 1
        or record.effectDieSides[index] ~= 1 then return nil end
    return record.effectBasePoints[index] + record.effectBaseDice[index]
end

local function multiplier(percent)
    return (100 + percent) / 100
end

local function classifyPassive(formID)
    if PASSIVE_CACHE[formID] then return copy(PASSIVE_CACHE[formID]) end
    local definition = W.FORMS[formID]
    if not definition then return nil, "unknown Warrior form" end
    local record, reason = spellRecord(definition.passiveSpellId)
    if not record then return nil, reason end
    local values, index = {}, nil
    for index = 1, 3 do
        local aura = definition.auras[index]
        if aura then
            local misc = aura == 52 and 0 or W.ALL_SCHOOLS
            values[aura] = amount(record, index, aura, misc)
            if values[aura] == nil then
                return nil, "Warrior stance passive topology mismatch"
            end
        elseif not inactive(record, index) then
            return nil, "Warrior stance passive has an extra effect"
        end
    end
    local threat, done, taken, critical = values[10] or 0,
        values[79] or 0, values[87] or 0, values[52] or 0
    local signsExact = formID == 17 and threat < 0 and done == 0
            and taken == 0 and critical == 0
        or formID == 18 and threat > 0 and done < 0
            and taken < 0 and critical == 0
        or formID == 19 and threat < 0 and done == 0
            and taken > 0 and critical > 0
    if not signsExact then return nil, "Warrior stance passive signs mismatch" end
    local out = { formID = formID, key = definition.key,
        passiveSpellId = definition.passiveSpellId,
        threatPercent = threat, damageDonePercent = done,
        damageTakenPercent = taken, meleeCriticalPercent = critical,
        threatMultiplier = multiplier(threat),
        damageDoneMultiplier = multiplier(done),
        damageTakenMultiplier = multiplier(taken),
        exact = true,
        source = "installed build-5875 stance passive DBC topology" }
    PASSIVE_CACHE[formID] = copy(out)
    return copy(out)
end

local function classifyDefiance(rank)
    local spellId = W.DEFIANCE_SPELL_IDS[rank]
    local record, reason = spellRecord(spellId)
    if not record then return nil, reason end
    local value = amount(record, 1, 10, W.ALL_SCHOOLS)
    if value == nil or value <= 0 or not inactive(record, 2)
        or not inactive(record, 3) then
        return nil, "Defiance DBC topology mismatch"
    end
    return { rank = rank, spellId = spellId, threatPercent = value,
        threatMultiplier = multiplier(value), exact = true,
        source = "installed build-5875 Defiance DBC topology" }
end

local function discovery()
    if DISCOVERY_CACHE then return copy(DISCOVERY_CACHE) end
    local out = { passives = {}, defiance = {}, exact = false,
        source = "installed build-5875 Warrior stance DBC evidence" }
    local formID
    for formID = 17, 19 do
        local found, reason = classifyPassive(formID)
        if not found then out.reason = reason; return out end
        out.passives[formID] = found
    end
    local rank
    for rank = 1, W.DEFIANCE_MAX_RANK do
        local found, reason = classifyDefiance(rank)
        if not found then out.reason = reason; return out end
        out.defiance[rank] = found
    end
    out.exact = true
    DISCOVERY_CACHE = copy(out)
    return copy(out)
end

local function talentEvidence()
    if TALENT_CACHE then return copy(TALENT_CACHE) end
    local out = { exact = false, talentId = W.DEFIANCE_TALENT_ID,
        source = "ClassicAPI exact talent identity and allocated rank" }
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function" then
        out.reason = "Defiance talent evidence unavailable"
        return out
    end
    local okID, talentId = pcall(GetTalentIDByIndex,
        W.DEFIANCE_TAB, W.DEFIANCE_INDEX)
    talentId = okID and integer(talentId, 1, 4294967295) or nil
    if talentId ~= W.DEFIANCE_TALENT_ID then
        out.reason = "Defiance talent identity mismatch"
        return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        W.DEFIANCE_TAB, W.DEFIANCE_INDEX)
    rank = ok and integer(rank, 0, W.DEFIANCE_MAX_RANK) or nil
    maximum = ok and integer(maximum, 1, W.DEFIANCE_MAX_RANK) or nil
    if rank == nil or maximum ~= W.DEFIANCE_MAX_RANK then
        out.reason = "Defiance allocated rank unavailable"
        return out
    end
    out.exact, out.rank, out.maximum = true, rank, maximum
    TALENT_CACHE = copy(out)
    return copy(out)
end

local function profile(passive, talent, defiance, maximumDefiance)
    local out = copy(passive)
    out.threatMinimum, out.threatMaximum = passive.threatMultiplier,
        passive.threatMultiplier
    out.threatExact = true
    if passive.formID == 18 then
        if talent.exact == true then
            local extra = talent.rank > 0 and defiance[talent.rank] or nil
            local factor = extra and extra.threatMultiplier or 1
            out.threatMultiplier = passive.threatMultiplier * factor
            out.threatMinimum, out.threatMaximum = out.threatMultiplier,
                out.threatMultiplier
            out.defianceRank, out.defianceSpellId = talent.rank,
                extra and extra.spellId or nil
            out.defianceThreatPercent = extra and extra.threatPercent or 0
        else
            out.threatMultiplier, out.threatExact = nil, false
            out.threatMaximum = passive.threatMultiplier * maximumDefiance
            out.reason = talent.reason
        end
    end
    out.talentId, out.talentExact = talent.talentId, talent.exact == true
    out.source = passive.source .. "; " .. talent.source
    return out
end

function W:Snapshot()
    if classToken() ~= self.WARRIOR_CLASS then return nil end
    if SNAPSHOT_CACHE then return copy(SNAPSHOT_CACHE) end
    local installed = discovery()
    if installed.exact ~= true then
        return { kind = "warriorStanceEffects", available = false,
            exact = false, reason = installed.reason, source = installed.source }
    end
    local talent = talentEvidence()
    local maximumDefiance = 1
    local rank
    for rank = 1, self.DEFIANCE_MAX_RANK do
        maximumDefiance = math.max(maximumDefiance,
            installed.defiance[rank].threatMultiplier)
    end
    local out = { kind = "warriorStanceEffects", available = true,
        exact = talent.exact == true, byForm = {},
        talent = copy(talent), source = installed.source }
    local formID
    for formID = 17, 19 do
        out.byForm[formID] = profile(installed.passives[formID], talent,
            installed.defiance, maximumDefiance)
    end
    if talent.exact then SNAPSHOT_CACHE = copy(out) end
    return copy(out)
end

function W:StanceProfile(snapshot, formID)
    formID = integer(formID, 17, 19)
    local found = snapshot and snapshot.kind == "warriorStanceEffects"
        and snapshot.available == true and formID
        and snapshot.byForm and snapshot.byForm[formID] or nil
    return found and copy(found) or nil
end

function W:ThreatProfile(snapshot, formID)
    local found = self:StanceProfile(snapshot, formID)
    if not found then return nil end
    return { actor = "player", playerOnly = true,
        component = "warriorStanceDefiance", formID = found.formID,
        stance = found.key, stancePassiveSpellID = found.passiveSpellId,
        defianceTalentID = found.talentId,
        defianceRank = found.defianceRank,
        defianceSpellID = found.defianceSpellId,
        multiplier = found.threatMultiplier,
        minimum = found.threatMinimum, maximum = found.threatMaximum,
        exact = found.threatExact == true, projected = true,
        source = found.source }
end

function W:BoundedThreatProfile(snapshot)
    if not (snapshot and snapshot.available == true and snapshot.byForm) then
        return nil
    end
    local minimum, maximum, formID, found = nil, nil, nil, nil
    for formID = 17, 19 do
        found = snapshot.byForm[formID]
        if not (found and found.threatMinimum and found.threatMaximum) then
            return nil
        end
        minimum = minimum and math.min(minimum, found.threatMinimum)
            or found.threatMinimum
        maximum = maximum and math.max(maximum, found.threatMaximum)
            or found.threatMaximum
    end
    return { actor = "player", playerOnly = true,
        component = "warriorStanceDefiance", multiplier = nil,
        minimum = minimum, maximum = maximum, exact = false,
        projected = false, source = snapshot.source
            .. "; current Warrior stance unavailable" }
end

-- Search-pure projection hook for WarriorStances:Apply. Besides replacing the
-- stale threat component it exposes exact DBC multipliers for later damage and
-- incoming-consequence consumers without applying either one twice here.
function W:Project(state, formID)
    local found = self:StanceProfile(state and state.warriorStanceEffects, formID)
    if not (state and found) then return false end
    state.warriorStanceProfile = found
    state.playerThreat = self:ThreatProfile(state.warriorStanceEffects, formID)
    state.playerStanceDamageDoneMultiplier = found.damageDoneMultiplier
    state.playerStanceDamageTakenMultiplier = found.damageTakenMultiplier
    state.playerStanceMeleeCriticalPercent = found.meleeCriticalPercent
    return true
end

function W:Attach(state)
    if type(state) ~= "table" then return false end
    local snapshot = self:Snapshot()
    if not snapshot then return false end
    state.warriorStanceEffects = snapshot
    local formID = state.playerForm and state.playerForm.formID
    if snapshot.available ~= true then return false end
    if self:Project(state, formID) then return true end
    state.playerThreat = self:BoundedThreatProfile(snapshot)
    return false
end

function W:Invalidate()
    PASSIVE_CACHE, DISCOVERY_CACHE, TALENT_CACHE, SNAPSHOT_CACHE = {}, nil, nil, nil
end
