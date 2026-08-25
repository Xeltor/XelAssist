-- Evaluation-local live cooldown evidence and exact-rank projection keys.
-- Prepare creates a fresh immutable observation ledger for each root state;
-- graph descendants read only state.readyAt and never call client APIs.
XelAssist.Graph.CooldownLedger = {}
local L = XelAssist.Graph.CooldownLedger

local function part(value)
    if value == nil then return "" end
    return tostring(value)
end

local function actor(action)
    return action.actor or "player"
end

function L:ActionKey(action)
    -- Slot and rank are deliberately retained even when a spell ID exists.
    -- This prevents two ranks, pet-bar replacements, or ID-less actions from
    -- ever sharing a projected cooldown accidentally.
    return "cooldown:action:" .. part(actor(action)) .. "\001"
        .. part(action.executor) .. "\001" .. part(action.bookType) .. "\001"
        .. part(action.slot) .. "\001" .. part(action.actionSlot) .. "\001"
        .. part(action.spellId) .. "\001" .. part(action.name) .. "\001"
        .. part(action.rankText) .. "\001" .. part(action.rank)
end

function L:GroupKey(group)
    if group == nil then return nil end
    return "group:" .. tostring(group)
end

function L:Supports(action)
    if type(action) ~= "table" then return false end
    if actor(action) == "pet" then
        return action.executor == "petAbility" and action.actionSlot ~= nil
    end
    return actor(action) == "player"
        and action.executor == "playerSpell" and action.slot ~= nil
end

local function remaining(start, duration, observedAt)
    start, duration = tonumber(start), tonumber(duration)
    if not start or not duration then return nil end
    if start == 0 or duration <= 0 then return 0 end
    return math.max(0, start + duration - observedAt)
end

function L:Capture(action, observedAt)
    if actor(action) == "pet" then
        if not GetPetActionCooldown then
            return { known = false, source = "pet cooldown API unavailable" }
        end
        local ok, start, duration, enabled = pcall(
            GetPetActionCooldown, action.actionSlot)
        if not ok or enabled == 0 then
            return { known = false, source = ok
                and "pet cooldown disabled" or "pet cooldown query failed" }
        end
        local value = remaining(start, duration, observedAt)
        return { known = value ~= nil, remaining = value,
            source = value ~= nil and "live pet cooldown" or "pet cooldown unknown" }
    end
    if not GetSpellCooldown then
        return { known = false, source = "spell cooldown API unavailable" }
    end
    local ok, start, duration = pcall(GetSpellCooldown,
        action.slot, action.bookType or BOOKTYPE_SPELL)
    if not ok then
        return { known = false, source = "spell cooldown query failed" }
    end
    local value = remaining(start, duration, observedAt)
    return { known = value ~= nil, remaining = value,
        source = value ~= nil and "live spell cooldown" or "spell cooldown unknown" }
end

local function sameObservedPetAction(ledger, action, observed)
    if type(observed) ~= "table" then return false end
    if type(observed.cooldownAction) == "table" then
        return ledger:ActionKey(action)
            == ledger:ActionKey(observed.cooldownAction)
    end
    if action.spellId ~= nil and observed.spellId ~= nil then
        return action.spellId == observed.spellId
    end
    -- Name-only matching would merge ranks. Older snapshots without an exact
    -- spell ID are intentionally queried once rather than guessed equivalent.
    return false
end

function L:PreobservedPet(state, action)
    local pet = state and state.actors and state.actors.pet
    local autocasts = pet and pet.autocasts
    if type(autocasts) ~= "table" then return nil end
    local found, i
    for i = 1, table.getn(autocasts) do
        if sameObservedPetAction(self, action, autocasts[i]) then
            if found then return nil end
            found = autocasts[i]
        end
    end
    if not found then return nil end
    local value = tonumber(found.cooldownReadyIn)
    if value == nil then value = tonumber(found.readyIn) end
    if value == nil then return nil end
    return { known = true, remaining = math.max(0, value),
        source = found.cooldownReadyIn ~= nil
            and "root pet cooldown observation"
            or "root pet autocast readiness" }
end

function L:Prepare(state, actions, observedAt)
    observedAt = tonumber(observedAt)
        or (type(GetTime) == "function" and tonumber(GetTime()) or 0) or 0
    local ledger = { observedAt = observedAt, records = {}, order = {} }
    state.cooldownLedger = ledger
    state.readyAt = state.readyAt or {}
    local i
    for i = 1, table.getn(actions or {}) do
        local action = actions[i]
        if self:Supports(action) then
            local key = self:ActionKey(action)
            if ledger.records[key] == nil then
                local record = actor(action) == "pet"
                    and self:PreobservedPet(state, action) or nil
                if not record then record = self:Capture(action, observedAt) end
                record.key, record.actor = key, actor(action)
                ledger.records[key] = record
                table.insert(ledger.order, key)
                if record.known and (record.remaining or 0) > 0 then
                    state.readyAt[key] = math.max(
                        tonumber(state.readyAt[key]) or 0,
                        (tonumber(state.time) or 0) + record.remaining)
                    record.readyAt = state.readyAt[key]
                else
                    record.readyAt = tonumber(state.readyAt[key]) or 0
                end
            end
        end
    end
    return ledger
end

function L:IsPrepared(state)
    return type(state) == "table"
        and type(state.cooldownLedger) == "table"
        and type(state.cooldownLedger.records) == "table"
end

function L:Record(state, action)
    if not self:IsPrepared(state) or not self:Supports(action) then return nil end
    return state.cooldownLedger.records[self:ActionKey(action)]
end

function L:ReadyAt(state, action)
    if type(state) ~= "table" or not state.readyAt then return nil end
    return tonumber(state.readyAt[self:ActionKey(action)])
end

function L:Blocker(state, action, actionStart)
    local record = self:Record(state, action)
    if not record then return nil, false end
    local readyAt = self:ReadyAt(state, action) or 0
    if readyAt <= (tonumber(actionStart) or 0) then return nil, true end
    if readyAt > (tonumber(record.readyAt) or 0) then
        return "future cooldown", true
    end
    return actor(action) == "pet" and "pet cooldown" or "cooldown", true
end

function L:Project(state, action, readyAt)
    state.readyAt = state.readyAt or {}
    local key = self:ActionKey(action)
    state.readyAt[key] = math.max(
        tonumber(state.readyAt[key]) or 0, tonumber(readyAt) or 0)
    return state.readyAt[key]
end

function L:ProjectGroup(state, group, readyAt)
    local key = self:GroupKey(group)
    if not key then return nil end
    state.readyAt = state.readyAt or {}
    state.readyAt[key] = math.max(
        tonumber(state.readyAt[key]) or 0, tonumber(readyAt) or 0)
    return state.readyAt[key]
end
