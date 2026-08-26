-- The mana event bridge must select one exact power lane, route Nampower's
-- argument ABI correctly, and fail closed when attribution is unavailable.
XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local now, mana, maximum, powerType = 0, 100, 200, 0
local playerGuid = "player-guid"
GetTime = function() return now end
UnitExists = function(unit)
    return unit == "player", unit == "player" and playerGuid or nil
end
UnitMana = function() return mana end
UnitManaMax = function() return maximum end
UnitPowerType = function() return powerType end
GetNampowerVersion = function() return 4, 7, 1 end

local records = {
    [1001] = { powerType = 0, manaCost = 35 },
    [1002] = { powerType = 0, manaCost = 0 },
    [1003] = { powerType = 1, manaCost = 100 },
}
local dbcReads = {}
GetSpellRecField = function(spellId, field)
    dbcReads[spellId] = (dbcReads[spellId] or 0) + 1
    local record = records[spellId] or {}
    local value = record[field]
    if value ~= nil then return value end
    if field == "manaCostPerlevel" or field == "manaCostPercentage"
        or field == "manaPerSecond" or field == "manaPerSecondPerLevel" then
        return 0
    end
    return nil
end

local calls = { observe = {}, boundary = {}, energize = {}, modifier = {},
    clear = 0, reset = 0, availability = {} }
local Evidence = {}
XelAssist.Game.Player.ManaEvidence = Evidence
function Evidence:SetEnergizeEvidenceAvailable(value)
    table.insert(calls.availability, value and true or false)
end
function Evidence:Observe(...)
    table.insert(calls.observe, { ... })
end
function Evidence:ObserveSpendBoundary(...)
    table.insert(calls.boundary, { ... })
    return true
end
function Evidence:ObserveEnergize(...)
    table.insert(calls.energize, { ... })
    return true
end
function Evidence:ClearSpendBoundary()
    calls.clear = calls.clear + 1
end
function Evidence:ModifierChanged(reason)
    table.insert(calls.modifier, reason)
end
function Evidence:ResetSession()
    calls.reset = calls.reset + 1
end

local unsupported, registered, callback = {}, {}, nil
CreateFrame = function()
    return {
        RegisterEvent = function(_, name)
            if unsupported[name] then error("unsupported " .. name) end
            registered[name] = true
        end,
        SetScript = function(_, _, fn) callback = fn end,
    }
end

dofile("Game/Player/ManaEvents.lua")
local Events = XelAssist.Game.Player.ManaEvents
assert(Events.powerEventMode == "guid" and registered.UNIT_MANA_GUID
    and not registered.UNIT_MANA and registered.SPELL_ENERGIZE_ON_SELF
    and registered.SPELL_START_SELF and registered.SPELL_GO_SELF
    and calls.availability[1] == true and callback,
    "registration must prefer the dedicated GUID lane and enable attribution")
local availabilityCalls = table.getn(calls.availability)
assert(Events:RegisterEvents()
    and table.getn(calls.availability) == availabilityCalls,
    "registration must be idempotent without disabling established evidence")

-- GUID/token duplicates and repeated identical state must train only once.
now = 1
assert(Events:OnEvent("UNIT_MANA_GUID", playerGuid, 1))
assert(not Events:OnEvent("UNIT_MANA", "player"))
assert(not Events:OnEvent("UNIT_MANA_GUID", playerGuid, 1))
assert(not Events:OnEvent("UNIT_MANA_GUID", "other-guid", 1))
mana, now = 110, 2
assert(Events:OnEvent("UNIT_MANA_GUID", playerGuid, 1))
assert(table.getn(calls.observe) == 2
    and calls.observe[1][1] == playerGuid and calls.observe[2][2] == 110
    and calls.observe[2][5] == true and calls.observe[2][6] == 0,
    "one GUID state change must produce one exact observation")

-- START/GO use arg2 for spell ID, require exact player ownership, and seal DBC
-- cost facts. Free and non-mana spells never arm evidence.
now = 3
assert(Events:OnEvent("SPELL_START_SELF", 9000, 1001, playerGuid))
assert(calls.boundary[1][1] == 1001 and calls.boundary[1][2] == "start"
    and calls.boundary[1][3] == 3,
    "SPELL_START_SELF must route its arg2 spell ID")
local reads = dbcReads[1001]
now = 4
assert(Events:OnEvent("SPELL_GO_SELF", 9000, 1001, playerGuid))
assert(calls.boundary[2][1] == 1001 and calls.boundary[2][2] == "go"
    and dbcReads[1001] == reads,
    "the GO boundary must reuse sealed installed-DBC funding evidence")
assert(not Events:OnEvent("SPELL_START_SELF", 1001, 1002, playerGuid)
    and not Events:OnEvent("SPELL_START_SELF", 1001, 1003, playerGuid)
    and not Events:OnEvent("SPELL_START_SELF", 1001, 1001, "other-guid")
    and table.getn(calls.boundary) == 2,
    "free, non-mana, and non-player casts must not arm spend evidence")

-- Failure, interruption/cancellation, and rejected cast-result paths all clear
-- an armed boundary; successful server acceptance does not.
local cleared = calls.clear
assert(Events:OnEvent("SPELL_FAILED_SELF", 1001, 77, 1))
assert(Events:OnEvent("SPELLCAST_FAILED"))
assert(Events:OnEvent("SPELLCAST_INTERRUPTED"))
assert(Events:OnEvent("SPELL_CAST_RESULT_SELF", 0, 1001))
assert(not Events:OnEvent("SPELL_CAST_RESULT_SELF", 1, 1001)
    and not Events:OnEvent("SPELLCAST_STOP")
    and calls.clear == cleared + 4,
    "failure/cancel paths, but not normal completion, must clear the boundary")

now = 5
assert(Events:OnEvent("SPELL_ENERGIZE_ON_SELF",
    playerGuid, "caster-guid", 2001, 0))
assert(calls.energize[1][1] == playerGuid
    and calls.energize[1][2] == 0 and calls.energize[1][3] == 5,
    "energize routing must preserve target and power-type ABI fields")

-- Every modifier boundary retires observation dedupe and DBC classification;
-- unrelated unit events are ignored.
assert(not Events:OnEvent("UNIT_AURA", "party1"))
assert(Events:OnEvent("UNIT_AURA", "player"))
assert(Events:OnEvent("UNIT_INVENTORY_CHANGED", playerGuid))
assert(Events:OnEvent("CHARACTER_POINTS_CHANGED"))
assert(Events:OnEvent("SPELLS_CHANGED"))
assert(table.getn(calls.modifier) == 4
    and next(Events.manaFundedBySpell) == nil,
    "aura, equipment, talent, and spellbook changes must invalidate evidence")
assert(Events:OnEvent("PLAYER_ENTERING_WORLD") and calls.reset == 1
    and Events.lastMana == nil,
    "world entry must reset session evidence and bridge dedupe")

-- Re-registration with unsupported GUID events must select only the standard
-- player token fallback and ignore any manually delivered GUID duplicate.
Events.frame, Events.powerEventMode = nil, nil
unsupported, registered, callback = { UNIT_MANA_GUID = true }, {}, nil
calls.availability = {}
assert(Events:RegisterEvents() and Events.powerEventMode == "token"
    and registered.UNIT_MANA and not registered.UNIT_MANA_GUID,
    "unsupported GUID registration must fall back to standard UNIT_MANA")
local observed = table.getn(calls.observe)
mana, now = 120, 6
assert(not Events:OnEvent("UNIT_MANA_GUID", playerGuid, 1))
assert(Events:OnEvent("UNIT_MANA", "player")
    and table.getn(calls.observe) == observed + 1,
    "fallback mode must accept only the player token lane")

-- Nampower without registration-enabled energize events cannot safely support
-- passive mana attribution even when the standard power event exists.
Events.frame, Events.powerEventMode = nil, nil
GetNampowerVersion = function() return 4, 4, 9 end
unsupported, registered = { UNIT_MANA_GUID = true }, {}
calls.availability = {}
assert(not Events:RegisterEvents() and Events.powerEventMode == "token"
    and calls.availability[1] == false
    and not registered.SPELL_ENERGIZE_ON_SELF,
    "missing energize attribution support must fail registration closed")

-- External-gain attribution alone is insufficient: if either exact owned-cast
-- boundary cannot be enabled, passive/post-spend training remains disabled.
Events.frame, Events.powerEventMode = nil, nil
GetNampowerVersion = function() return 4, 7, 1 end
unsupported, registered = { SPELL_START_SELF = true }, {}
calls.availability = {}
assert(not Events:RegisterEvents() and registered.SPELL_ENERGIZE_ON_SELF
    and registered.SPELL_GO_SELF and not registered.SPELL_START_SELF
    and calls.availability[1] == false,
    "missing spend attribution must fail registration closed")

print("ok: mana event bridge selects one exact attributed runtime lane")
