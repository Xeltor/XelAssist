-- Name-independent live evidence for reactive action requirements. Nampower
-- exposes the player's exact aura-state bitmask while Spell.dbc identifies the
-- state each action requires. This module observes only; graph lifetime and
-- chosen-action consumption belong to the graph layer.
XelAssist.Game.Player.ReactiveEvidence = {}
local R = XelAssist.Game.Player.ReactiveEvidence

local MAX_UINT32 = 4294967295
local MAX_AURA_STATE = 32
local CACHE = {}

local function integer(value, low, high)
    if type(value) ~= "number" or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function requirementRecord(spellId)
    spellId = integer(spellId, 1, MAX_UINT32)
    if not spellId then
        return { exact = false, source = "reactive spell identity unavailable" }
    end
    local cached = CACHE[spellId]
    if cached then return cached end
    local record
    if type(GetSpellRecField) ~= "function" then
        record = { exact = false,
            source = "client DBC caster aura state unavailable" }
    else
        local ok, value = pcall(
            GetSpellRecField, spellId, "casterAuraState")
        value = ok and integer(value, 0, MAX_AURA_STATE) or nil
        if value == nil then
            record = { exact = false,
                source = "client DBC caster aura state unreadable" }
        else
            record = { exact = true, stateID = value,
                source = "client DBC casterAuraState" }
        end
    end
    CACHE[spellId] = record
    return record
end

local function stateFlag(mask, stateID)
    if not (mask and stateID and stateID > 0) then return nil end
    local flag = 2 ^ (stateID - 1)
    return math.floor(mask / flag)
        - math.floor(mask / (flag * 2)) * 2 == 1
end

function R:Invalidate()
    CACHE = {}
end

function R:Requirement(action)
    local record = requirementRecord(action and action.spellId)
    return record.stateID, record.exact, record.source
end

function R:Snapshot()
    if type(GetUnitField) ~= "function" then
        return { exact = false, source = "player aura state API unavailable" }
    end
    local ok, value = pcall(GetUnitField, "player", "auraState")
    local mask = ok and integer(value, 0, MAX_UINT32) or nil
    if mask == nil then
        return { exact = false, source = "player aura state unreadable" }
    end
    return { mask = mask, exact = true,
        observedAt = type(GetTime) == "function" and GetTime() or nil,
        source = "Nampower player auraState" }
end

-- Returns true/false only when both the action requirement and live bitmask
-- are exact. A reactive action with DBC state 0 remains unknown: its reactive
-- classification and its installed-client requirement disagree.
function R:Available(snapshot, action)
    local stateID, requirementExact, requirementSource =
        self:Requirement(action)
    if not requirementExact or not stateID or stateID == 0 then
        return nil, stateID, requirementSource
    end
    if not (snapshot and snapshot.exact and snapshot.mask) then
        return nil, stateID, snapshot and snapshot.source
            or "player aura state unavailable"
    end
    return stateFlag(snapshot.mask, stateID), stateID,
        snapshot.source .. "; " .. requirementSource
end
