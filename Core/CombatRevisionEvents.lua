-- Maps client evidence into the single combat-revision owner. Hard topology
-- changes invalidate sliced work; ordinary combat traffic remains soft so a
-- busy fight cannot starve the graph producer.
XelAssist.Core.CombatRevisionEvents = {}
local E = XelAssist.Core.CombatRevisionEvents
local R = XelAssist.Core.CombatRevision

local unitDomains = {
    UNIT_HEALTH = "health",
    UNIT_MANA = "resource",
    UNIT_RAGE = "resource",
    UNIT_ENERGY = "resource",
    UNIT_FOCUS = "resource",
    UNIT_AURA = "aura",
    UNIT_TARGET = "threat",
}

local eventDomains = {
    BAG_UPDATE = "inventory",
    PET_BAR_UPDATE = "pet",
    PET_UI_UPDATE = "pet",
    SPELL_UPDATE_COOLDOWN = "readiness",
    PET_BAR_UPDATE_COOLDOWN = "readiness",
    ACTIONBAR_UPDATE_USABLE = "readiness",
    PLAYER_REGEN_DISABLED = "engaged",
    PLAYER_REGEN_ENABLED = "engaged",
    CHAT_MSG_SPELL_SELF_DAMAGE = "health",
    SPELLCAST_FAILED = "cast",
    SPELLCAST_INTERRUPTED = "cast",
    UI_ERROR_MESSAGE = "readiness",
    SPELL_QUEUE_EVENT = "cast",
    SPELL_CAST_EVENT = "cast",
    SPELL_CAST_RESULT_SELF = "cast",
    SPELL_ON_SWING_STATE = "cast",
    SPELL_START_SELF = "cast",
    SPELL_START_OTHER = "cast",
    SPELL_DELAYED_SELF = "cast",
    SPELL_GO_SELF = "cast",
    SPELL_GO_OTHER = "cast",
    SPELL_FAILED_SELF = "cast",
    SPELL_FAILED_OTHER = "cast",
    SPELL_MISS_SELF = "cast",
    SPELL_MISS_OTHER = "cast",
    SPELL_DAMAGE_EVENT_SELF = "health",
    SPELL_DAMAGE_EVENT_OTHER = "health",
    AUTO_ATTACK_SELF = "health",
    AUTO_ATTACK_OTHER = "health",
    AURA_CAST_ON_SELF = "aura",
    AURA_CAST_ON_OTHER = "aura",
    DEBUFF_ADDED_OTHER = "aura",
    UNIT_CASTEVENT = "cast",
}

local registered = {
    "PLAYER_TARGET_CHANGED",
    "UNIT_HEALTH",
    "UNIT_MANA",
    "UNIT_RAGE",
    "UNIT_ENERGY",
    "UNIT_FOCUS",
    "UNIT_AURA",
    "UNIT_TARGET",
    "SPELL_UPDATE_COOLDOWN",
    "PET_BAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_USABLE",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}

local function relevantUnit(unit)
    if type(unit) ~= "string" then return false end
    if unit == "player" or unit == "target" or unit == "targettarget"
        or unit == "pet" or unit == "pettarget" then return true end
    return string.find(unit, "^party%d+$") ~= nil
        or string.find(unit, "^raid%d+$") ~= nil
end

function E:Register(frame)
    if not (frame and frame.RegisterEvent) then return false end
    local index
    for index = 1, table.getn(registered) do
        frame:RegisterEvent(registered[index])
    end
    return true
end

function E:Observe(name, first)
    if not R then return false end
    if name == "PLAYER_TARGET_CHANGED" then
        R:Hard("selected target changed")
        return true
    end
    if name == "PLAYER_ENTERING_WORLD" then
        R:Hard("world transition")
        return true
    end
    if name == "SPELLS_CHANGED" or name == "CHARACTER_POINTS_CHANGED" then
        R:Hard("player action catalog changed")
        return true
    end
    if name == "UNIT_PET" and (first == nil or first == "player") then
        R:Hard("companion identity changed")
        return true
    end
    if name == "UNIT_INVENTORY_CHANGED" and first == "player" then
        R:Hard("player equipment changed")
        R:Touch("inventory", name)
        return true
    end
    local domain = unitDomains[name]
    if domain then
        if not relevantUnit(first) then return false end
        R:Touch(domain, name)
        if name == "UNIT_TARGET" and first == "pet" then
            R:Touch("pet", name)
            R:Touch("engaged", name)
        end
        return true
    end
    domain = eventDomains[name]
    if not domain then return false end
    R:Touch(domain, name)
    if name == "PET_BAR_UPDATE" or name == "PET_UI_UPDATE" then
        R:Touch("readiness", name)
    elseif name == "SPELL_DAMAGE_EVENT_SELF"
        or name == "SPELL_DAMAGE_EVENT_OTHER"
        or name == "AUTO_ATTACK_SELF" or name == "AUTO_ATTACK_OTHER" then
        R:Touch("threat", name)
        R:Touch("engaged", name)
    end
    return true
end
