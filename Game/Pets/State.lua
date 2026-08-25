-- Hunter pet lifecycle and maintenance evidence. This module deliberately
-- observes state only: it never chooses, casts, dismisses, or abandons a pet.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.State = {}
local S = XelAssist.Game.Pets.State

local DISMISS_EVIDENCE_SECONDS = 8
local PET_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_PET_CHANGED",
    "PET_UI_UPDATE",
    "PET_UI_CLOSE",
    "PET_DISMISS_START",
    "PET_BAR_UPDATE",
    "PET_BAR_UPDATE_COOLDOWN",
    "PET_ATTACK_START",
    "PET_ATTACK_STOP",
    "UNIT_PET",
    "UNIT_FOCUS",
    "UNIT_MAXFOCUS",
    "UNIT_HAPPINESS",
    "UNIT_MAXHAPPINESS",
    "UNIT_LOYALTY",
    "UNIT_PET_EXPERIENCE",
    "UNIT_PET_TRAINING_POINTS"
}

local PET_UNIT_EVENTS = {
    UNIT_FOCUS = true,
    UNIT_MAXFOCUS = true,
    UNIT_HAPPINESS = true,
    UNIT_MAXHAPPINESS = true,
    UNIT_LOYALTY = true,
    UNIT_PET_EXPERIENCE = true,
    UNIT_PET_TRAINING_POINTS = true
}

local function now()
    if not GetTime then return nil end
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
    return nil
end

local function callUnit(api, unit)
    if type(api) ~= "function" then return nil, false end
    local ok, value = pcall(api, unit)
    if not ok then return nil, false end
    return value, true
end

local function unitEvidence(unit)
    if type(UnitExists) ~= "function" then return false, nil, false end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok then return false, nil, false end
    if exists and guid == nil and type(UnitGUID) == "function" then
        local guidOk, fallback = pcall(UnitGUID, unit)
        if guidOk then guid = fallback end
    end
    return exists and true or false, guid, true
end

local function uiEvidence()
    if type(HasPetUI) ~= "function" then return nil, nil, false end
    local ok, hasUI, petType = pcall(HasPetUI)
    if not ok then return nil, nil, false end
    return (hasUI == true or hasUI == 1), petType, true
end

local function foodEvidence()
    local foods = {}
    if type(GetPetFoodTypes) ~= "function" then return foods, false end
    local values = { pcall(GetPetFoodTypes) }
    if not values[1] then return foods, false end
    local i
    for i = 2, table.getn(values) do
        if values[i] ~= nil then table.insert(foods, values[i]) end
    end
    return foods, true
end

local function attackBarEvidence()
    if type(GetPetActionInfo) ~= "function" then return nil end
    local slots = NUM_PET_ACTION_SLOTS or 10
    local i
    for i = 1, slots do
        local ok, name, _, _, isToken, active = pcall(GetPetActionInfo, i)
        local upper = ok and type(name) == "string" and string.upper(name) or ""
        if ok and isToken and string.find(upper, "ATTACK", 1, true) then
            return active and true or false
        end
    end
    return nil
end

local function copyArray(source)
    local out, i = {}, nil
    for i = 1, table.getn(source or {}) do out[i] = source[i] end
    return out
end

local function copyLastKnown(source)
    if not source then return nil end
    return { guid = source.guid, name = source.name, family = source.family }
end

local function emptyState(supported, observedAt)
    return { supported = supported, lifecycle = "unknown", present = false,
        dead = false, hasPetUIKnown = false, foodTypes = {}, foodTypesKnown = false,
        targetExists = false, observedAt = observedAt }
end

function S:IsHunter()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, classToken = pcall(UnitClass, "player")
    return ok and classToken == "HUNTER"
end

function S:ResetSession()
    self.live = emptyState(self:IsHunter(), now())
    self.currentGuid = nil
    self.lastKnown = nil
    self.attackGuid = nil
    self.attackActive = nil
    self.dismissalPending = false
    self.dismissalPendingGuid = nil
    self.dismissalPendingAt = nil
end

function S:ClearDismissalEvidence()
    self.dismissalPending = false
    self.dismissalPendingGuid = nil
    self.dismissalPendingAt = nil
end

function S:DismissalEvidenceExpired(observationTime)
    if not (self.dismissalPending and self.dismissalPendingAt and observationTime) then
        return false
    end
    local age = observationTime - self.dismissalPendingAt
    return age < 0 or age > DISMISS_EVIDENCE_SECONDS
end

function S:Remember(guid, name, family, identityReset)
    if identityReset or not self.lastKnown
        or (guid ~= nil and self.lastKnown.guid ~= guid) then
        self.lastKnown = { guid = guid, name = name, family = family }
        return
    end
    if guid ~= nil then self.lastKnown.guid = guid end
    if name ~= nil then self.lastKnown.name = name end
    if family ~= nil then self.lastKnown.family = family end
end

function S:ReadPresent(guid, observedAt)
    local state = emptyState(true, observedAt)
    state.present, state.guid = true, guid
    state.guidKnown = guid ~= nil
    state.name = callUnit(UnitName, "pet")
    state.family = callUnit(UnitCreatureFamily, "pet")
    state.health, state.healthKnown = callUnit(UnitHealth, "pet")
    state.healthMax, state.healthMaxKnown = callUnit(UnitHealthMax, "pet")
    state.focus, state.focusKnown = callUnit(UnitMana, "pet")
    state.focusMax, state.focusMaxKnown = callUnit(UnitManaMax, "pet")

    local dead, deadKnown = callUnit(UnitIsDead, "pet")
    state.deadKnown = deadKnown or state.healthKnown
    state.dead = dead == true or dead == 1
        or (state.healthKnown and state.health <= 0) or false
    state.lifecycle = state.dead and "dead" or "alive"

    if type(GetPetHappiness) == "function" then
        local ok, happiness, damagePercentage, loyaltyRate = pcall(GetPetHappiness)
        if ok then
            state.happinessKnown = true
            state.happiness = happiness
            state.damagePercentage = damagePercentage
            state.loyaltyRate = loyaltyRate
        end
    end
    if type(GetPetLoyalty) == "function" then
        local ok, loyaltyText = pcall(GetPetLoyalty)
        if ok then state.loyaltyKnown, state.loyaltyText = true, loyaltyText end
    end
    if type(GetPetExperience) == "function" then
        local ok, experience, experienceNext = pcall(GetPetExperience)
        if ok then
            state.experienceKnown = true
            state.experience, state.experienceNext = experience, experienceNext
        end
    end
    if type(GetPetTrainingPoints) == "function" then
        local ok, total, spent = pcall(GetPetTrainingPoints)
        if ok then
            state.trainingKnown = true
            state.trainingTotal, state.trainingSpent = total, spent
            if type(total) == "number" and type(spent) == "number" then
                state.trainingAvailable = total - spent
            end
        end
    end
    state.foodTypes, state.foodTypesKnown = foodEvidence()

    state.hasPetUI, state.petUIType, state.hasPetUIKnown = uiEvidence()
    local targetExists, targetGuid, targetKnown = unitEvidence("pettarget")
    state.targetKnown, state.targetExists = targetKnown, targetExists
    state.targetGuid = targetExists and targetGuid or nil
    state.targetGuidKnown = targetExists and targetGuid ~= nil or false

    local barActive = attackBarEvidence()
    if (self.attackGuid ~= guid or self.attackActive == nil) and barActive ~= nil then
        self.attackActive, self.attackGuid = barActive, guid
    end
    if self.attackGuid == guid then state.attackActive = self.attackActive end
    state.attackActiveKnown = state.attackActive ~= nil
    state.dismissalPending = self.dismissalPending
        and (self.dismissalPendingGuid == nil or self.dismissalPendingGuid == guid) or false
    return state
end

function S:Refresh(reason)
    local observedAt = now()
    if not self:IsHunter() then
        self.live = emptyState(false, observedAt)
        self.currentGuid = nil
        self.attackGuid, self.attackActive = nil, nil
        self:ClearDismissalEvidence()
        return self.live
    end
    if self:DismissalEvidenceExpired(observedAt) then self:ClearDismissalEvidence() end

    local exists, guid = unitEvidence("pet")
    local previousGuid, previousPresent = self.currentGuid,
        self.live and self.live.present or false
    if exists then
        local replacement = previousPresent and previousGuid ~= nil and guid ~= nil
            and previousGuid ~= guid
        if replacement or not previousPresent then
            self.attackGuid, self.attackActive = nil, nil
        end
        if replacement and XelAssist.Game.Pets.EffectRuntime then
            XelAssist.Game.Pets.EffectRuntime:IdentityChanged(previousGuid, guid)
        end
        if self.dismissalPending and self.dismissalPendingGuid ~= nil and guid ~= nil
            and self.dismissalPendingGuid ~= guid then
            self:ClearDismissalEvidence()
        end
        self.currentGuid = guid
        self.live = self:ReadPresent(guid, observedAt)
        self.live.reason = reason
        self:Remember(guid, self.live.name, self.live.family,
            replacement or not previousPresent)
        self.live.lastKnown = copyLastKnown(self.lastKnown)
        return self.live
    end

    local explicitDismissal = self.dismissalPending
        and (self.dismissalPendingGuid == nil or previousGuid == nil
            or self.dismissalPendingGuid == previousGuid)
    local previousLifecycle = self.live and self.live.lifecycle or "unknown"
    if previousPresent and XelAssist.Game.Pets.EffectRuntime then
        XelAssist.Game.Pets.EffectRuntime:IdentityChanged(previousGuid, nil)
    end
    self.currentGuid = nil
    self.attackGuid, self.attackActive = nil, nil
    self.live = emptyState(true, observedAt)
    self.live.hasPetUI, self.live.petUIType, self.live.hasPetUIKnown = uiEvidence()
    self.live.reason = reason
    if explicitDismissal or previousLifecycle == "dismissed" then
        self.live.lifecycle = "dismissed"
    end
    if explicitDismissal then self:ClearDismissalEvidence() end
    self.live.lastKnown = copyLastKnown(self.lastKnown)
    return self.live
end

function S:Snapshot()
    local source = self:Refresh("snapshot")
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do
        if key ~= "foodTypes" and key ~= "lastKnown" then out[key] = value end
    end
    out.foodTypes = copyArray(source.foodTypes)
    out.lastKnown = copyLastKnown(self.lastKnown)
    return out
end

function S:IdentityMatches(evidenceGuid)
    if evidenceGuid == nil then return true end
    return self.currentGuid ~= nil and self.currentGuid == evidenceGuid
end

function S:OnEvent(eventName, unit, evidenceGuid)
    if not self:IsHunter() then return false end
    if PET_UNIT_EVENTS[eventName] and unit ~= nil and unit ~= "pet" then return false end
    if eventName == "UNIT_PET" and unit ~= nil and unit ~= "player" then return false end

    self:Refresh(eventName)
    if not self:IdentityMatches(evidenceGuid) then return false end
    if eventName == "PET_DISMISS_START" then
        if not self.live.present then return false end
        self.dismissalPending = true
        self.dismissalPendingGuid = self.currentGuid
        self.dismissalPendingAt = now()
        self.live.dismissalPending = true
    elseif eventName == "PET_ATTACK_START" then
        if self.live.lifecycle ~= "alive" then return false end
        self.attackGuid, self.attackActive = self.currentGuid, true
        self.live.attackActive, self.live.attackActiveKnown = true, true
    elseif eventName == "PET_ATTACK_STOP" then
        if evidenceGuid ~= nil or self.attackGuid == self.currentGuid then
            self.attackGuid, self.attackActive = self.currentGuid, false
            self.live.attackActive, self.live.attackActiveKnown = false, true
        else
            return false
        end
    end
    return true
end

function S:RegisterEvents()
    if self.eventFrame or not self:IsHunter() or type(CreateFrame) ~= "function" then return end
    local frame = CreateFrame("Frame")
    local i
    for i = 1, table.getn(PET_EVENTS) do
        pcall(frame.RegisterEvent, frame, PET_EVENTS[i])
    end
    frame:SetScript("OnEvent", function() S:OnEvent(event, arg1, nil) end)
    self.eventFrame = frame
end

S:ResetSession()
S:Refresh("load")
S:RegisterEvents()
