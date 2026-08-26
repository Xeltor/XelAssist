-- Exact runtime bridge for session-learned player mana evidence. Dedicated GUID
-- power events are preferred; installed Spell.dbc proves owned mana-funded cast
-- boundaries. Graph search never calls this module or any live API it owns.
XelAssist.Game.Player.ManaEvents = {}
local E = XelAssist.Game.Player.ManaEvents
local Evidence = XelAssist.Game.Player.ManaEvidence

local MANA = 0
local COST_FIELDS = { "manaCost", "manaCostPerlevel", "manaCostPercentage",
    "manaPerSecond", "manaPerSecondPerLevel" }

local function numeric(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

local function clockNow()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    return ok and numeric(value) or nil
end

local function playerIdentity()
    if type(XelAssist.PlayerGUID) == "function" then
        local ok, guid = pcall(XelAssist.PlayerGUID, XelAssist)
        if ok and guid ~= nil then return guid end
    end
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, "player")
    return ok and exists and guid or nil
end

local function register(frame, name)
    if not (frame and type(frame.RegisterEvent) == "function") then return false end
    local ok, result = pcall(frame.RegisterEvent, frame, name)
    return ok and result ~= false
end

local function readSpell(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and numeric(value) or nil
end

local function signed32(value)
    value = numeric(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

function E:ClearSpellCostCache()
    self.manaFundedBySpell = {}
end

-- The result is sealed after the first installed-DBC read for a spell and is
-- invalidated with spell/talent/aura/equipment boundaries. A positive exact
-- cost component proves funding; zero or unavailable evidence fails closed.
function E:ManaFunded(spellId)
    spellId = numeric(spellId)
    if not spellId or spellId <= 0 or math.floor(spellId) ~= spellId then
        return false
    end
    self.manaFundedBySpell = self.manaFundedBySpell or {}
    local cached = self.manaFundedBySpell[spellId]
    if cached ~= nil then return cached end
    local funded = false
    if signed32(readSpell(spellId, "powerType")) == MANA then
        local i
        for i = 1, table.getn(COST_FIELDS) do
            local value = readSpell(spellId, COST_FIELDS[i])
            if value and value > 0 then funded = true; break end
        end
    end
    self.manaFundedBySpell[spellId] = funded
    return funded
end

function E:EnergizeRegistrationSupported()
    if type(GetNampowerVersion) ~= "function" then return false end
    local ok, major, minor = pcall(GetNampowerVersion)
    major, minor = tonumber(major), tonumber(minor)
    return ok and major and minor
        and (major > 4 or major == 4 and minor >= 5) or false
end

function E:ResetObservationDedupe()
    self.lastGuid, self.lastMana, self.lastMaximum = nil, nil, nil
    self.lastPowerType = nil
end

local function playerPower()
    if type(UnitMana) ~= "function" or type(UnitManaMax) ~= "function" then
        return nil
    end
    local okMana, mana = pcall(UnitMana, "player")
    local okMaximum, maximum = pcall(UnitManaMax, "player")
    local okType, powerType = true, MANA
    if type(UnitPowerType) == "function" then
        okType, powerType = pcall(UnitPowerType, "player")
    end
    if not okMana or not okMaximum or not okType then return nil end
    return numeric(mana), numeric(maximum), tonumber(powerType)
end

function E:ObservePower()
    local guid, at = playerIdentity(), clockNow()
    local mana, maximum, powerType = playerPower()
    if guid == nil or not at or not mana or not maximum then return false end
    if self.lastGuid == guid and self.lastMana == mana
        and self.lastMaximum == maximum and self.lastPowerType == powerType then
        return false
    end
    self.lastGuid, self.lastMana, self.lastMaximum, self.lastPowerType =
        guid, mana, maximum, powerType
    Evidence:Observe(guid, mana, maximum, at, true, powerType)
    return true
end

function E:RouteSpendBoundary(eventName, spellId, casterGuid)
    if casterGuid == nil or casterGuid ~= playerIdentity()
        or not self:ManaFunded(spellId) then return false end
    local at = clockNow()
    if not at then return false end
    local stage = eventName == "SPELL_START_SELF" and "start"
        or eventName == "SPELL_GO_SELF" and "go" or nil
    return stage and Evidence:ObserveSpendBoundary(spellId, stage, at) or false
end

local INVALIDATIONS = {
    CHARACTER_POINTS_CHANGED = "player talents changed",
    SPELLS_CHANGED = "player spellbook changed",
    PLAYER_LEVEL_UP = "player level changed",
    UPDATE_SHAPESHIFT_FORM = "player power form changed",
    ZONE_CHANGED_NEW_AREA = "player world regime changed",
}

local CLEAR_BOUNDARY = {
    SPELL_FAILED_SELF = true, SPELLCAST_FAILED = true,
    -- The legacy interrupted event is also the authoritative client-side
    -- cancellation path. Normal STOP events are successful completion and
    -- must not erase a GO marker before its exact mana delta arrives.
    SPELLCAST_INTERRUPTED = true,
}

function E:OnEvent(eventName, a1, a2, a3, a4)
    if eventName == "UNIT_MANA_GUID" then
        if self.powerEventMode ~= "guid" or tonumber(a2) ~= 1
            or a1 ~= playerIdentity() then return false end
        return self:ObservePower()
    elseif eventName == "UNIT_MANA" then
        if self.powerEventMode ~= "token" or a1 ~= "player" then return false end
        return self:ObservePower()
    elseif eventName == "SPELL_ENERGIZE_ON_SELF" then
        return Evidence:ObserveEnergize(a1, a4, clockNow())
    elseif eventName == "SPELL_START_SELF" or eventName == "SPELL_GO_SELF" then
        -- Nampower ABI: arg1=item ID, arg2=spell ID, arg3=caster GUID.
        return self:RouteSpendBoundary(eventName, a2, a3)
    elseif CLEAR_BOUNDARY[eventName]
        or eventName == "SPELL_CAST_RESULT_SELF" and tonumber(a1) == 0 then
        Evidence:ClearSpendBoundary()
        return true
    elseif eventName == "PLAYER_ENTERING_WORLD"
        or eventName == "PLAYER_LEAVING_WORLD" then
        Evidence:ResetSession()
        self:ResetObservationDedupe()
        self:ClearSpellCostCache()
        return true
    elseif eventName == "UNIT_AURA" then
        if a1 ~= "player" and a1 ~= playerIdentity() then return false end
        Evidence:ModifierChanged("player aura regime changed")
    elseif eventName == "UNIT_INVENTORY_CHANGED" then
        if a1 ~= "player" and a1 ~= playerIdentity() then return false end
        Evidence:ModifierChanged("player equipment changed")
    elseif eventName == "UNIT_MAXMANA" then
        if a1 ~= "player" and a1 ~= playerIdentity() then return false end
        Evidence:ModifierChanged("maximum mana changed")
    elseif INVALIDATIONS[eventName] then
        Evidence:ModifierChanged(INVALIDATIONS[eventName])
    else return false end
    self:ResetObservationDedupe()
    self:ClearSpellCostCache()
    return true
end

function E:RegisterEvents()
    if self.frame then
        return self.powerEventMode ~= nil and self.attributionAvailable == true
    end
    if type(CreateFrame) ~= "function" then
        Evidence:SetEnergizeEvidenceAvailable(false)
        return false
    end
    local ok, frame = pcall(CreateFrame, "Frame")
    if not ok or not frame then
        Evidence:SetEnergizeEvidenceAvailable(false)
        return false
    end
    self:ResetObservationDedupe()
    self:ClearSpellCostCache()
    local powerRegistered = register(frame, "UNIT_MANA_GUID")
    if powerRegistered then self.powerEventMode = "guid"
    elseif register(frame, "UNIT_MANA") then
        powerRegistered, self.powerEventMode = true, "token"
    else self.powerEventMode = nil end

    local energizeRegistered, startRegistered, goRegistered = false, false, false
    if self:EnergizeRegistrationSupported() then
        energizeRegistered = register(frame, "SPELL_ENERGIZE_ON_SELF")
        startRegistered = register(frame, "SPELL_START_SELF")
        goRegistered = register(frame, "SPELL_GO_SELF")
    end
    local attributed = energizeRegistered and startRegistered and goRegistered
    Evidence:SetEnergizeEvidenceAvailable(attributed)

    local names = { "SPELL_FAILED_SELF", "SPELL_CAST_RESULT_SELF",
        "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
        "UPDATE_SHAPESHIFT_FORM", "ZONE_CHANGED_NEW_AREA", "UNIT_AURA",
        "UNIT_INVENTORY_CHANGED", "UNIT_MAXMANA" }
    local i
    for i = 1, table.getn(names) do register(frame, names[i]) end
    if type(frame.SetScript) == "function" then
        frame:SetScript("OnEvent", function()
            E:OnEvent(event, arg1, arg2, arg3, arg4)
        end)
    end
    self.frame, self.attributionAvailable = frame, attributed
    return powerRegistered and attributed
end

E:RegisterEvents()
