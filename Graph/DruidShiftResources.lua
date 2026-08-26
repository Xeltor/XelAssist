-- Conservative resource floors for Druid form changes. Root capture proves
-- the installed Furor talent row and its energize payloads without using a
-- localized name. Graph search consumes only the sealed scalar evidence.
--
-- A floor is intentional: Cat Form resets energy before Furor, while other
-- equipment or server additions may grant more. Bear rage is excluded because
-- its decay phase is not modeled. The graph may spend Cat's proven floor but
-- must not call it the exact post-shift resource value.
XelAssist.Graph.DruidShiftResources = {}
local D = XelAssist.Graph.DruidShiftResources

D.DRUID_CLASS_ID = 11
D.DRUID_FAMILY = 7
D.RESTORATION_TAB = 3
D.FUROR_INDEX = 2
D.FUROR_TALENT_ID = 286
D.FUROR_MAX_RANK = 5
D.FUROR_ICON_ID = 238
D.FUROR_RANK_FIVE_ID = 17061
D.ENERGY_TRIGGER_ID = 17099
D.ENERGY = 3
D.CAT_FORM = 1
D.MAX_DBC_CACHE = 8

local DBC_CACHE, DBC_CACHE_COUNT = {}, 0

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
    return value
end

local function nonnegative(value)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value < 0 then return nil end
    return value
end

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function playerExists()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    return ok and (exists == true or exists == 1)
end

local function dbcScalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and integer(value, 0, 4294967295) or nil
end

local function dbcTriple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key = {}, 0, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    local index
    for index = 1, 3 do
        out[index] = integer(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function topology(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    if DBC_CACHE[spellId] then return shallow(DBC_CACHE[spellId]) end
    local found = { spellId = spellId,
        family = dbcScalar(spellId, "spellFamilyName"),
        icon = dbcScalar(spellId, "spellIconID"),
        effect = dbcTriple(spellId, "effect"),
        aura = dbcTriple(spellId, "effectApplyAuraName"),
        target = dbcTriple(spellId, "effectImplicitTargetA"),
        base = dbcTriple(spellId, "effectBasePoints"),
        misc = dbcTriple(spellId, "effectMiscValue") }
    if found.family == nil or found.icon == nil or not found.effect
        or not found.aura or not found.target or not found.base
        or not found.misc then return nil end
    if DBC_CACHE_COUNT < D.MAX_DBC_CACHE then
        DBC_CACHE[spellId], DBC_CACHE_COUNT = shallow(found),
            DBC_CACHE_COUNT + 1
    end
    return found
end

local function emptyTail(values)
    return values and values[2] == 0 and values[3] == 0
end

local function talentTopology(spellId, rank)
    local found = topology(spellId)
    local chance = integer(rank, 1, D.FUROR_MAX_RANK)
        and rank * 20 or nil
    if not found or not chance or found.family ~= D.DRUID_FAMILY
        or found.icon ~= D.FUROR_ICON_ID
        or found.effect[1] ~= 6 or not emptyTail(found.effect)
        or found.aura[1] ~= 4 or not emptyTail(found.aura)
        or found.target[1] ~= 1 or not emptyTail(found.target)
        or found.base[1] + 1 ~= chance or not emptyTail(found.base)
        or found.misc[1] ~= 0 or not emptyTail(found.misc) then return nil end
    return chance
end

local function energizeTopology(spellId, powerType, amount, allowSecond)
    local found = topology(spellId)
    if not found or found.effect[1] ~= 30
        or found.target[1] ~= 1 or found.misc[1] ~= powerType
        or found.base[1] + 1 ~= amount
        or found.effect[3] ~= 0 or found.target[3] ~= 0
        or found.misc[3] ~= 0 or found.base[3] ~= 0 then return false end
    if allowSecond then
        return found.effect[2] == 6 and found.aura[2] == 94
            and found.target[2] == 1 and found.base[2] == 0
            and found.misc[2] == 0
    end
    return found.effect[2] == 0 and found.aura[2] == 0
        and found.target[2] == 0 and found.base[2] == 0
        and found.misc[2] == 0
end

function D:Snapshot()
    local out = { available = false, exact = false,
        talentID = self.FUROR_TALENT_ID,
        source = "exact Talent.dbc identity and installed Furor payloads" }
    if classToken() ~= "DRUID" or not playerExists() then
        out.reason = "Druid player evidence unavailable"
        return out
    end
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function"
        or type(GetTalentSpellID) ~= "function" then
        out.reason = "Druid talent evidence unavailable"
        return out
    end
    local okID, talentID = pcall(GetTalentIDByIndex,
        self.RESTORATION_TAB, self.FUROR_INDEX)
    talentID = okID and integer(talentID, 1, 4294967295) or nil
    if talentID ~= self.FUROR_TALENT_ID then
        out.reason = "Furor talent identity mismatch"
        return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        self.RESTORATION_TAB, self.FUROR_INDEX)
    rank = ok and integer(rank, 0, self.FUROR_MAX_RANK) or nil
    maximum = ok and integer(maximum, 1, self.FUROR_MAX_RANK) or nil
    if rank == nil or maximum ~= self.FUROR_MAX_RANK then
        out.reason = "Furor rank evidence unavailable"
        return out
    end
    if rank == 0 then
        out.available, out.exact, out.rank = true, true, 0
        out.chance, out.guaranteed = 0, false
        return out
    end
    local okSpell, spellId = pcall(GetTalentSpellID,
        self.RESTORATION_TAB, self.FUROR_INDEX, rank)
    spellId = okSpell and integer(spellId, 1, 4294967295) or nil
    local chance = spellId and talentTopology(spellId, rank) or nil
    if not chance then
        out.reason = "Furor spell topology unavailable"
        return out
    end
    out.available, out.exact, out.rank = true, true, rank
    out.spellId, out.chance = spellId, chance
    out.guaranteed = chance == 100
    if not out.guaranteed then return out end
    if not energizeTopology(self.ENERGY_TRIGGER_ID,
        self.ENERGY, 40, false) then
        out.available, out.exact, out.guaranteed = false, false, false
        out.reason = "Furor energize payload unavailable"
        return out
    end
    out.catEnergy = 40
    out.energyTriggerSpellId = self.ENERGY_TRIGGER_ID
    return out
end

function D:Attach(state)
    local snapshot = state and state.druidFormState
    if not (snapshot and snapshot.available == true) then return false end
    snapshot.shiftResourceEvidence = self:Snapshot()
    return snapshot.shiftResourceEvidence.available == true
end

local function powerSlot(snapshot, powerType)
    local slot = snapshot and snapshot.powers
        and snapshot.powers[powerType]
    local current, maximum = nonnegative(slot and slot.current),
        nonnegative(slot and slot.maximum)
    if not (slot and slot.currentKnown == true
        and slot.maximumKnown == true and current and maximum
        and current <= maximum) then return nil end
    return current, maximum
end

-- Returns a copied transition, whether an exact floor was attached, and an
-- optional non-blocking reason. Missing Furor evidence never blocks shifting.
function D:Bind(snapshot, transition)
    local out = shallow(transition)
    local target = integer(transition and transition.targetForm, 0, 32)
    -- Bear rage cannot be a persistent graph floor until rage decay timing is
    -- modeled. Cat energy is stable and therefore the only admissible floor.
    local powerType = target == self.CAT_FORM and self.ENERGY or nil
    if not powerType then return out, false, nil end
    if not (snapshot and snapshot.available == true
        and transition.kind == "shift"
        and transition.sourceForm == snapshot.formID
        and transition.targetPrimary == powerType
        and transition.destinationPowerKnown ~= true) then
        return out, false, "Druid form transition evidence unavailable"
    end
    local evidence = snapshot and snapshot.shiftResourceEvidence
    if not (evidence and evidence.available == true
        and evidence.exact == true and evidence.guaranteed == true
        and evidence.talentID == self.FUROR_TALENT_ID
        and evidence.rank == self.FUROR_MAX_RANK
        and evidence.spellId == self.FUROR_RANK_FIVE_ID
        and evidence.chance == 100 and evidence.catEnergy == 40
        and evidence.energyTriggerSpellId == self.ENERGY_TRIGGER_ID) then
        return out, false, "guaranteed Furor evidence unavailable"
    end
    local current, maximum = powerSlot(snapshot, powerType)
    if current == nil then
        return out, false, "destination power floor unavailable"
    end
    local floor = evidence.catEnergy
    floor = nonnegative(floor)
    if not floor or floor > maximum then floor = maximum end
    out.druidShiftResourceFloor = { exact = true, lowerBound = true,
        talentID = evidence.talentID, talentRank = evidence.rank,
        talentSpellId = evidence.spellId, chance = evidence.chance,
        sourceForm = transition.sourceForm, targetForm = target,
        powerType = powerType, observedSourcePower = current,
        observedMaximum = maximum, minimum = floor,
        triggerSpellId = evidence.energyTriggerSpellId,
        source = "guaranteed Furor plus observed destination capacity" }
    out.destinationPowerMinimum = floor
    out.destinationPowerMinimumKnown = true
    return out, true, nil
end

function D:Apply(snapshot, transition)
    local floor = transition and transition.druidShiftResourceFloor
    local slot = floor and snapshot and snapshot.powers
        and snapshot.powers[floor.powerType]
    local sourcePower, observedMaximum = nonnegative(floor
        and floor.observedSourcePower),
        nonnegative(floor and floor.observedMaximum)
    local expected = floor and floor.powerType == self.ENERGY
        and math.min(observedMaximum or 0, 40) or nil
    local trigger = self.ENERGY_TRIGGER_ID
    local evidence = snapshot and snapshot.shiftResourceEvidence
    if not (floor and floor.exact == true and floor.lowerBound == true
        and floor.powerType == self.ENERGY
        and snapshot.formID == floor.targetForm
        and snapshot.primaryType == floor.powerType
        and transition.targetForm == floor.targetForm
        and transition.sourceForm == floor.sourceForm
        and floor.talentID == self.FUROR_TALENT_ID
        and floor.talentRank == self.FUROR_MAX_RANK
        and floor.talentSpellId == self.FUROR_RANK_FIVE_ID
        and floor.chance == 100 and floor.triggerSpellId == trigger
        and floor.minimum == expected and slot
        and slot.priorObservedCurrent == sourcePower
        and slot.priorObservedMaximum == observedMaximum
        and evidence and evidence.available == true
        and evidence.exact == true and evidence.guaranteed == true
        and evidence.talentID == floor.talentID
        and evidence.rank == floor.talentRank
        and evidence.spellId == floor.talentSpellId) then return false end
    slot.minimumCurrent, slot.minimumCurrentKnown = floor.minimum, true
    slot.minimumCurrentSource = floor.source
    slot.minimumTransition = { sourceForm = floor.sourceForm,
        targetForm = floor.targetForm, powerType = floor.powerType,
        talentSpellId = floor.talentSpellId, exact = true }
    slot.currentKnown = false
    return true
end

function D:ResourceFloor(snapshot)
    local slot = snapshot and snapshot.powers
        and snapshot.powers[snapshot.primaryType]
    local minimum = nonnegative(slot and slot.minimumCurrent)
    local transition = slot and slot.minimumTransition
    if not (slot and slot.minimumCurrentKnown == true and minimum
        and snapshot.primaryType == self.ENERGY
        and transition and transition.exact == true
        and transition.targetForm == snapshot.formID
        and transition.powerType == snapshot.primaryType
        and transition.talentSpellId == self.FUROR_RANK_FIVE_ID
        and snapshot.shiftResourceEvidence
        and snapshot.shiftResourceEvidence.available == true
        and snapshot.shiftResourceEvidence.exact == true
        and snapshot.shiftResourceEvidence.guaranteed == true) then
        return nil, false
    end
    return minimum, true
end

function D:Invalidate()
    DBC_CACHE, DBC_CACHE_COUNT = {}, 0
end
