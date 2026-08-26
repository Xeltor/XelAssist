-- Exact Dark Pact identity plus session-learned transfer evidence.  The
-- installed DBC proves a fixed pet-mana drain topology, while two unclipped
-- SPELL_GO-correlated resource observations learn its live amount.  This
-- deliberately avoids reconstructing Turtle talents, spell power, or pet aura
-- modifiers inside graph search.
XelAssist.Game.Player.WarlockDarkPact = {}
local D = XelAssist.Game.Player.WarlockDarkPact

D.WARLOCK_FAMILY = 5
D.MANA = 0
D.POWER_DRAIN = 8
D.TARGET_PET = 5
D.ASSOCIATION_WINDOW = 0.5
D.REQUIRED_SAMPLES = 2
D.MAX_CACHE = 128

local CACHE, CACHE_SIZE = {}, 0

local function finite(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
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
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function zeroTail(values)
    return values and values[2] == 0 and values[3] == 0
end

local function exactShape(spellId, found)
    local points = triple(spellId, "effectBasePoints")
    local dice = triple(spellId, "effectBaseDice")
    local sides = triple(spellId, "effectDieSides")
    local diceLevel = triple(spellId, "effectDicePerLevel")
    local pointsLevel = triple(spellId, "effectRealPointsPerLevel")
    local combo = triple(spellId, "effectPointsPerComboPoint")
    local base = points and dice and points[1] + dice[1] or nil
    if not (equal(found.effects, D.POWER_DRAIN, 0, 0)
        and equal(found.targetsA, D.TARGET_PET, 0, 0)
        and equal(found.targetsB, 0, 0, 0)
        and equal(found.misc, D.MANA, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 1, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and points and dice and sides and diceLevel and pointsLevel and combo
        and zeroTail(points) and zeroTail(dice) and zeroTail(sides)
        and equal(diceLevel, 0, 0, 0) and equal(pointsLevel, 0, 0, 0)
        and equal(combo, 0, 0, 0)
        and (sides[1] == 0 or sides[1] == 1)
        and integer(dice[1], -1000000, 1000000) ~= nil
        and base and base > 0
        and scalar(spellId, "powerType") == D.MANA
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0) then return false end
    found.baseAmount, found.fixed = base, true
    return true
end

local function classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "spell identity unavailable", false end
    if CACHE[spellId] then
        local found = CACHE[spellId]
        return copy(found), found.reason, found.recognized == true
    end
    local family = scalar(spellId, "spellFamilyName")
    local found = { spellId = spellId, family = family,
        effects = triple(spellId, "effect"),
        targetsA = triple(spellId, "effectImplicitTargetA"),
        targetsB = triple(spellId, "effectImplicitTargetB"),
        misc = triple(spellId, "effectMiscValue"), valid = false }
    found.recognized = family == D.WARLOCK_FAMILY and found.effects
        and found.effects[1] == D.POWER_DRAIN and found.targetsA
        and found.targetsA[1] == D.TARGET_PET and found.misc
        and found.misc[1] == D.MANA or false
    if found.recognized then
        found.valid, found.exact = exactShape(spellId, found), false
        found.exact = found.valid
        if not found.valid then
            found.reason = "pet-mana drain DBC topology is incomplete"
        else
            found.source = "installed-client fixed pet-mana drain topology"
        end
    else found.reason = "spell is not a pet-mana drain" end
    if CACHE_SIZE >= D.MAX_CACHE then CACHE, CACHE_SIZE = {}, 0 end
    CACHE[spellId], CACHE_SIZE = copy(found), CACHE_SIZE + 1
    return copy(found), found.reason, found.recognized == true
end

local function staticEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warlockDarkPactEvidence
    if not (facts and facts.warlockDarkPact == true
        and facts.petManaConversion == true and type(found) == "table"
        and found.valid == true and found.exact == true
        and found.family == D.WARLOCK_FAMILY and found.fixed == true
        and integer(found.spellId, 1, 4294967295)
        and finite(found.baseAmount, 0.0001, 10000000)) then return nil end
    return found
end

function D:InferKnowledge(spellId)
    if classToken() ~= "WARLOCK" then
        return nil, "player is not an exactly identified Warlock", false
    end
    local found, reason, recognized = classify(spellId)
    if not (found and found.valid) then return nil, reason, recognized end
    return { inferred = true, kind = "resource", kindExact = true,
        self = true, fixedTarget = "player", transientResource = true,
        resourceType = "mana", powerType = self.MANA,
        warlockDarkPact = true, petManaConversion = true,
        requiresWarlockDarkPactEvidence = true, submissionGuarded = true,
        warlockDarkPactEvidence = copy(found), source = found.source }, nil, true
end

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    return ok and finite(value, 0, 1000000000) or nil
end

local function identity(unit)
    if unit == "player" and XelAssist
        and type(XelAssist.PlayerGUID) == "function" then
        local ok, guid = pcall(XelAssist.PlayerGUID, XelAssist)
        if ok and guid ~= nil then return guid end
    end
    if type(UnitExists) == "function" then
        local ok, exists, guid = pcall(UnitExists, unit)
        if ok and exists and guid ~= nil then return guid end
    end
    if type(UnitGUID) == "function" then
        local ok, guid = pcall(UnitGUID, unit)
        if ok then return guid end
    end
    return nil
end

local function unitPower(unit)
    if type(UnitMana) ~= "function" or type(UnitManaMax) ~= "function"
        or type(UnitPowerType) ~= "function" then return nil end
    local okValue, value = pcall(UnitMana, unit)
    local okMax, maximum = pcall(UnitManaMax, unit)
    local okType, powerType = pcall(UnitPowerType, unit)
    value, maximum = okValue and integer(value, 0, 10000000),
        okMax and integer(maximum, 0, 10000000)
    powerType = okType and integer(powerType, 0, 4) or nil
    if not value or not maximum or maximum <= 0 or powerType ~= D.MANA then
        return nil
    end
    return value, maximum
end

local function powerSnapshot()
    local playerGuid, petGuid = identity("player"), identity("pet")
    local player, playerMax = unitPower("player")
    local pet, petMax = unitPower("pet")
    if playerGuid == nil or petGuid == nil or not player or not pet then return nil end
    return { playerGuid = playerGuid, petGuid = petGuid,
        player = player, playerMax = playerMax, pet = pet, petMax = petMax }
end

function D:ResetEvidence(reason)
    self.models, self.pending = {}, nil
    self.lastPetGoAt, self.lastEvidenceReason = nil, reason
end

function D:Snapshot(spellId)
    local model = self.models and self.models[tonumber(spellId)]
    if not (model and model.verified == true
        and integer(model.amount, 1, 10000000)) then return nil end
    return { verified = true, exact = true, spellId = model.spellId,
        amount = model.amount, samples = model.samples,
        source = "session-learned exact Dark Pact resource deltas" }
end

function D:CaptureFacts(action, facts)
    local out, found = copy(facts), staticEvidence(action)
    if not found then return out end
    local live = self:Snapshot(found.spellId)
    out.warlockDarkPactTransferExact = live ~= nil
    out.warlockDarkPactTransfer = live and live.amount or nil
    out.warlockDarkPactTransferSource = live and live.source or nil
    out.warlockDarkPactCaptureReason = live and nil
        or self.lastEvidenceReason or "Dark Pact transfer not yet verified"
    out.cost, out.powerType, out.resourceType = 0, self.MANA, "mana"
    return out
end

function D:Begin(spellId, casterGuid, targetGuid, hits, misses)
    local found, _, recognized = classify(spellId)
    if not (recognized and found and found.valid) then return false end
    local at, observed = now(), powerSnapshot()
    if not at or not observed or casterGuid ~= observed.playerGuid
        or targetGuid ~= observed.petGuid or tonumber(misses) ~= 0
        or not tonumber(hits) or tonumber(hits) < 0 then return false end
    if self.lastPetGoAt and at - self.lastPetGoAt <= self.ASSOCIATION_WINDOW then
        self.pending = nil
        return false
    end
    observed.spellId, observed.at = found.spellId, at
    self.pending = observed
    return true
end

function D:Learn(spellId, amount)
    self.models = self.models or {}
    local model = self.models[spellId]
    if not model or model.amount ~= amount then
        model = { spellId = spellId, amount = amount, samples = 0 }
        self.models[spellId] = model
    end
    model.samples = model.samples + 1
    model.verified = model.samples >= self.REQUIRED_SAMPLES
    self.lastEvidenceReason = model.verified and nil
        or "Dark Pact transfer needs another matching sample"
    return model.verified
end

function D:ObservePower()
    local pending, at = self.pending, now()
    if not pending or not at then return false end
    if at < pending.at or at - pending.at > self.ASSOCIATION_WINDOW then
        self.pending = nil
        return false
    end
    local observed = powerSnapshot()
    if not observed or observed.playerGuid ~= pending.playerGuid
        or observed.petGuid ~= pending.petGuid
        or observed.playerMax ~= pending.playerMax
        or observed.petMax ~= pending.petMax then
        self.pending = nil
        return false
    end
    local petLoss = pending.pet - observed.pet
    local playerGain = observed.player - pending.player
    if petLoss < 0 or playerGain < 0 then self.pending = nil; return false end
    if petLoss <= 0 or playerGain <= 0 then return false end
    self.pending = nil
    if petLoss ~= playerGain or observed.pet <= 0
        or pending.player + playerGain > pending.playerMax
        or pending.loggedGain and pending.loggedGain ~= playerGain then
        return false
    end
    return self:Learn(pending.spellId, playerGain)
end

local function relevantUnit(unit)
    return unit == "player" or unit == "pet"
        or unit ~= nil and (unit == identity("player") or unit == identity("pet"))
end

local INVALIDATE = {
    CHARACTER_POINTS_CHANGED = "Warlock talents changed",
    SPELLS_CHANGED = "Warlock spellbook changed",
    PLAYER_LEVEL_UP = "player level changed",
    ZONE_CHANGED_NEW_AREA = "world regime changed",
    UNIT_PET = "controlled demon changed",
}

function D:OnEvent(eventName, a1, a2, a3, a4, a5, a6, a7)
    if eventName == "SPELL_GO_SELF" then
        if self.pending and tonumber(a2) ~= self.pending.spellId then
            self.pending = nil
        end
        return self:Begin(a2, a3, a4, a6, a7)
    elseif eventName == "SPELL_GO_OTHER" then
        if a3 ~= identity("pet") then return false end
        self.lastPetGoAt = now(); self.pending = nil
        return true
    elseif eventName == "UNIT_MANA_GUID" then
        if self.powerEventMode ~= "guid" or tonumber(a2) ~= 1
            or not relevantUnit(a1) then return false end
        return self:ObservePower()
    elseif eventName == "UNIT_MANA" then
        if self.powerEventMode ~= "token" or not relevantUnit(a1) then return false end
        return self:ObservePower()
    elseif eventName == "SPELL_ENERGIZE_BY_SELF"
        or eventName == "SPELL_ENERGIZE_BY_OTHER"
        or eventName == "SPELL_ENERGIZE_ON_SELF" then
        if not self.pending or tonumber(a4) ~= self.MANA then return false end
        if tonumber(a3) == self.pending.spellId
            and a1 == self.pending.playerGuid and a2 == self.pending.playerGuid then
            self.pending.loggedGain = integer(a5, 1, 10000000)
        else self.pending = nil end
        return true
    elseif eventName == "SPELL_FAILED_SELF" or eventName == "SPELLCAST_FAILED"
        or eventName == "SPELLCAST_INTERRUPTED"
        or eventName == "SPELL_CAST_RESULT_SELF" and tonumber(a1) == 0 then
        self.pending = nil
        return true
    elseif eventName == "PLAYER_ENTERING_WORLD"
        or eventName == "PLAYER_LEAVING_WORLD" then
        self:ResetEvidence("Dark Pact session changed")
        return true
    elseif eventName == "UNIT_AURA" and relevantUnit(a1) then
        self:ResetEvidence("player or demon aura regime changed")
        return true
    elseif eventName == "UNIT_INVENTORY_CHANGED" and relevantUnit(a1) then
        self:ResetEvidence("player equipment changed")
        return true
    elseif eventName == "UNIT_MAXMANA" and relevantUnit(a1) then
        self:ResetEvidence("player or demon maximum mana changed")
        return true
    elseif INVALIDATE[eventName] then
        self:ResetEvidence(INVALIDATE[eventName])
        return true
    end
    return false
end

local function register(frame, eventName)
    if not (frame and type(frame.RegisterEvent) == "function") then return false end
    local ok, result = pcall(frame.RegisterEvent, frame, eventName)
    return ok and result ~= false
end

function D:RegisterEvents()
    if self.frame then return self.runtimeSupported == true end
    if type(CreateFrame) ~= "function" then return false end
    local ok, frame = pcall(CreateFrame, "Frame")
    if not ok or not frame then return false end
    local guidPower = register(frame, "UNIT_MANA_GUID")
    if guidPower then self.powerEventMode = "guid"
    elseif register(frame, "UNIT_MANA") then self.powerEventMode = "token" end
    local versionOK = false
    if type(GetNampowerVersion) == "function" then
        local versionRead, major, minor = pcall(GetNampowerVersion)
        major, minor = tonumber(major), tonumber(minor)
        versionOK = versionRead and major and minor
            and (major > 4 or major == 4 and minor >= 5) or false
    end
    local goSelf = versionOK and register(frame, "SPELL_GO_SELF")
    local goOther = versionOK and register(frame, "SPELL_GO_OTHER")
    local names = { "SPELL_ENERGIZE_BY_SELF", "SPELL_ENERGIZE_BY_OTHER",
        "SPELL_ENERGIZE_ON_SELF", "SPELL_FAILED_SELF",
        "SPELL_CAST_RESULT_SELF", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "UNIT_AURA",
        "UNIT_INVENTORY_CHANGED", "UNIT_MAXMANA", "UNIT_PET",
        "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
        "ZONE_CHANGED_NEW_AREA" }
    local index
    for index = 1, table.getn(names) do register(frame, names[index]) end
    if type(frame.SetScript) == "function" then
        frame:SetScript("OnEvent", function()
            D:OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
        end)
    end
    self.frame = frame
    self.runtimeSupported = self.powerEventMode ~= nil and goSelf and goOther
        and true or false
    return self.runtimeSupported
end

function D:Invalidate()
    CACHE, CACHE_SIZE = {}, 0
    self:ResetEvidence("Dark Pact evidence invalidated")
end

D:RegisterEvents()
