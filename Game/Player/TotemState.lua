-- Exact Shaman totem-slot lifecycle evidence. The installed spell semantic
-- proves the element slot and ClassicAPI proves the player's four live slots;
-- neither source proves what a summoned creature pulses, its effect radius,
-- or its eligible recipients. Those fields therefore remain explicitly
-- unknown until BindDownstream receives exact external evidence.
--
-- Integration contract: recommendation admission must call Prepare, not only
-- PrepareLifecycle. The downstream hook must bind an exact effect descriptor,
-- a totem-centered range, and a totem-centered recipient topology. A central
-- graph consumer must still implement every supplied effect kind and fail
-- closed on unknown kinds. This module assigns no utility or element ordering.
XelAssist.Game.Player.TotemState = {}
local T = XelAssist.Game.Player.TotemState

T.SLOT_COUNT = 4
T.MAX_SEMANTIC_ATOMS = 16
T.ELEMENT_BY_SLOT = { [1] = "fire", [2] = "earth",
    [3] = "water", [4] = "air" }

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function exactBoolean(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function playerGUID()
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, "player")
    if not ok or not (exists == true or exists == 1) then return nil end
    if not validGUID(guid) and type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, "player")
        if not ok then guid = nil end
    end
    return validGUID(guid) and guid or nil
end

local function slotFromType(value)
    if type(value) ~= "string" then return nil end
    local _, _, digit = string.find(value, "^totemSlot([1-4])$")
    return tonumber(digit)
end

function T:Semantic(action)
    local semantics = XelAssist.Game and XelAssist.Game.SpellSemantics
    local spellId = action and integer(action.spellId, 1, 4294967295)
    if not (spellId and semantics and type(semantics.Resolve) == "function") then
        return nil, "totem spell semantics unavailable"
    end
    local ok, descriptor = pcall(semantics.Resolve, semantics, spellId)
    if not ok or type(descriptor) ~= "table" then
        return nil, "totem spell semantics unavailable"
    end
    if descriptor.complete ~= true or descriptor.admissible == false then
        return nil, descriptor.reasons and descriptor.reasons[1]
            or "totem spell semantics incomplete"
    end
    local atoms = descriptor.atoms or {}
    if table.getn(atoms) > self.MAX_SEMANTIC_ATOMS then
        return nil, "totem semantic budget exceeded"
    end
    local found, index = nil, nil
    for index = 1, table.getn(atoms) do
        local atom = atoms[index]
        if type(atom) == "table" and atom.kind == "summon" then
            local slot = slotFromType(atom.summonType)
            if slot then
                if found and found ~= slot then
                    return nil, "totem spell has conflicting elements"
                end
                found = slot
            end
        end
    end
    if not found then return nil, "spell is not a slotted totem summon" end
    return { slot = found, element = self.ELEMENT_BY_SLOT[found],
        descriptor = descriptor, exact = true,
        source = "installed-client slotted totem summon effect" }, nil
end

local function readSlot(slot)
    local ok, haveTool, name, startTime, duration, icon,
        modRate, spellId = pcall(GetTotemInfo, slot)
    if not ok then return nil, "totem slot observation unavailable" end
    haveTool = exactBoolean(haveTool)
    startTime, duration, modRate = finite(startTime), finite(duration),
        finite(modRate)
    spellId = integer(spellId, 0, 4294967295)
    if haveTool == nil or type(name) ~= "string" or startTime == nil
        or duration == nil or modRate ~= 1 or spellId == nil then
        return nil, "totem slot fields are not exact"
    end
    local active = name ~= ""
    if active then
        if spellId <= 0 or startTime < 0 or duration <= 0 then
            return nil, "totem slot identity is incoherent"
        end
    elseif spellId ~= 0 or startTime ~= 0 or duration ~= 0 or icon ~= nil then
        return nil, "totem empty-slot identity is incoherent"
    end
    return { slot = slot, element = T.ELEMENT_BY_SLOT[slot],
        haveTool = haveTool, active = active,
        name = active and name or nil, spellId = active and spellId or nil,
        startTime = active and startTime or nil,
        duration = active and duration or nil,
        icon = active and icon or nil, modRate = modRate,
        exact = true, source = "ClassicAPI four-slot totem tracker" }, nil
end

local function remainingFor(row)
    if not row.active then return 0, "empty slot" end
    if type(GetTotemTimeLeft) == "function" then
        local ok, remaining = pcall(GetTotemTimeLeft, row.slot)
        if ok then
            remaining = finite(remaining)
            if remaining == nil or remaining < 0
                or remaining > row.duration then
                return nil, "totem remaining lifetime unavailable"
            end
            return remaining, "ClassicAPI GetTotemTimeLeft"
        end
    end
    if type(GetTime) ~= "function" then
        return nil, "totem remaining lifetime unavailable"
    end
    local ok, now = pcall(GetTime)
    now = ok and finite(now) or nil
    if now == nil or now < row.startTime then
        return nil, "totem remaining lifetime unavailable"
    end
    return math.max(0, row.duration - (now - row.startTime)),
        "GetTotemInfo start and duration"
end

local function sameObservation(first, second)
    return first and second and first.haveTool == second.haveTool
        and first.active == second.active and first.name == second.name
        and first.spellId == second.spellId
        and first.startTime == second.startTime
        and first.duration == second.duration and first.icon == second.icon
        and first.modRate == second.modRate
end

local function unknown(reason)
    return { exact = false, reason = reason }
end

function T:Snapshot()
    local out = { available = false, bySlot = {},
        source = "ClassicAPI exact four-slot totem tracker" }
    if classToken() ~= "SHAMAN" then
        out.reason = "player is not an exactly identified Shaman"
        return out
    end
    local guid = playerGUID()
    if not guid or type(GetTotemInfo) ~= "function" then
        out.reason = "totem tracker unavailable"
        return out
    end
    local slot
    for slot = 1, self.SLOT_COUNT do
        local row, reason = readSlot(slot)
        if not row then out.reason = reason; return out end
        row.remaining, row.timingSource = remainingFor(row)
        if row.remaining == nil then
            out.reason = row.timingSource
            return out
        end
        if row.active and row.remaining <= 0 then
            out.reason = "totem slot lifetime elapsed while active"
            return out
        end
        row.lifetimeExact = true
        row.effect = unknown("totem downstream effect unavailable")
        row.range = unknown("totem effect range unavailable")
        row.recipients = unknown("totem effect recipients unavailable")
        out.bySlot[slot] = row
    end
    for slot = 1, self.SLOT_COUNT do
        local check, reason = readSlot(slot)
        if not check then out.reason = reason; return out end
        if not sameObservation(out.bySlot[slot], check) then
            out.reason = "totem slots changed during observation"
            return out
        end
    end
    if playerGUID() ~= guid or classToken() ~= "SHAMAN" then
        out.reason = "totem owner changed during observation"
        return out
    end
    out.available, out.playerGUID = true, guid
    return out
end

function T:Lifetime(action)
    local spellId = action and integer(action.spellId, 1, 4294967295)
    if not spellId or type(GetSpellDuration) ~= "function" then
        return nil, "totem duration unavailable"
    end
    local ok, durationMs = pcall(GetSpellDuration, spellId)
    durationMs = ok and integer(durationMs, 1, 4294967295) or nil
    if not durationMs then return nil, "totem duration unavailable" end
    return { duration = durationMs / 1000, exact = true,
        source = "installed-client SpellDuration" }, nil
end

local function activeCopy(row)
    if not (row and row.active) then return nil end
    return { slot = row.slot, element = row.element, name = row.name,
        spellId = row.spellId, startTime = row.startTime,
        duration = row.duration, remaining = row.remaining,
        lifetimeExact = row.lifetimeExact, exact = true, source = row.source }
end

local function prepareLifecycle(owner, action, state, semantic, lifetime)
    local snapshot = state and state.totems
    local current = snapshot and snapshot.bySlot
        and snapshot.bySlot[semantic.slot]
    if not (snapshot and snapshot.available == true
        and validGUID(snapshot.playerGUID) and current and current.exact == true
        and current.element == semantic.element) then
        return nil, "totem slot state unavailable"
    end
    if state.playerGUID and state.playerGUID ~= snapshot.playerGUID then
        return nil, "totem owner identity changed"
    end
    if current.haveTool ~= true then return nil, "totem tool unavailable" end
    if current.active and current.spellId == tonumber(action.spellId) then
        return nil, "same totem already active"
    end
    return { kind = "totemPlacement", action = action,
        playerGUID = snapshot.playerGUID, slot = semantic.slot,
        element = semantic.element, semantic = semantic,
        duration = lifetime.duration, lifetime = lifetime,
        replacement = current.active == true,
        displaced = activeCopy(current),
        replacedSpellId = current.active and current.spellId or nil,
        replacedStartTime = current.active and current.startTime or nil,
        effect = unknown("totem downstream effect unavailable"),
        range = unknown("totem effect range unavailable"),
        recipients = unknown("totem effect recipients unavailable"),
        admissible = false,
        blockedReason = "totem downstream effect unavailable",
        source = "exact totem element, lifetime, and replacement" }, nil
end

function T:PrepareLifecycle(action, state)
    local semantic, semanticReason = self:Semantic(action)
    if not semantic then return nil, semanticReason end
    local lifetime, durationReason = self:Lifetime(action)
    if not lifetime then return nil, durationReason end
    return prepareLifecycle(self, action, state, semantic, lifetime)
end

-- Graph descendants use only the lifecycle sealed into RootObservation's
-- copied action facts. This path performs no spell-semantic or duration reads.
function T:PrepareCaptured(action, state, lifecycle, downstreamEvidence)
    local slot = lifecycle and integer(lifecycle.slot, 1, self.SLOT_COUNT)
    local duration = lifecycle and finite(lifecycle.duration)
    local element = slot and self.ELEMENT_BY_SLOT[slot]
    if not (lifecycle and lifecycle.exact == true and slot and duration
        and duration > 0 and lifecycle.element == element
        and lifecycle.replacementSlot == slot
        and lifecycle.replacementFamily == "shamanTotemSlot" .. tostring(slot)) then
        return nil, "captured Shaman totem lifecycle unavailable"
    end
    local projection, reason = prepareLifecycle(self, action, state,
        { slot = slot, element = element, exact = true,
            source = lifecycle.source },
        { duration = duration, exact = true, source = lifecycle.source })
    if not projection then return nil, reason end
    return self:BindDownstream(projection, downstreamEvidence)
end

local function exactRange(value)
    local minimum = value and finite(value.minimum)
    local maximum = value and finite(value.maximum)
    return value and value.exact == true and value.center == "totem"
        and minimum and maximum and minimum >= 0 and maximum >= minimum
end

local function exactRecipients(value)
    return value and value.exact == true and value.center == "totem"
        and type(value.relation) == "string" and value.relation ~= ""
        and type(value.shape) == "string" and value.shape ~= ""
end

local function exactEffect(value)
    return value and value.exact == true
        and type(value.kind) == "string" and value.kind ~= ""
end

function T:BindDownstream(projection, evidence)
    if not (projection and projection.kind == "totemPlacement"
        and evidence and evidence.exact == true
        and tonumber(evidence.sourceSpellId)
            == tonumber(projection.action and projection.action.spellId)
        and evidence.element == projection.element
        and exactEffect(evidence.effect) and exactRange(evidence.range)
        and exactRecipients(evidence.recipients)) then
        return nil, "totem downstream effect, range, or recipients unavailable"
    end
    projection.effect, projection.range = evidence.effect, evidence.range
    projection.recipients, projection.downstreamSource = evidence.recipients,
        evidence.source
    projection.downstreamSpellId = tonumber(evidence.sourceSpellId)
    projection.downstreamElement = evidence.element
    projection.admissible, projection.blockedReason = true, nil
    return projection, nil
end

function T:Prepare(action, state, downstreamEvidence)
    local projection, reason = self:PrepareLifecycle(action, state)
    if not projection then return nil, reason end
    return self:BindDownstream(projection, downstreamEvidence)
end

local function currentMatches(current, projection)
    if projection.replacedSpellId == nil then return current and not current.active end
    return current and current.active
        and current.spellId == projection.replacedSpellId
        and current.startTime == projection.replacedStartTime
end

function T:Apply(state, projection)
    local snapshot = state and state.totems
    local slot = projection and integer(projection.slot, 1, self.SLOT_COUNT)
    local now = state and finite(state.time)
    local current = slot and snapshot and snapshot.bySlot
        and snapshot.bySlot[slot]
    if not (snapshot and snapshot.available == true and slot and now
        and now >= 0 and projection.admissible == true
        and projection.playerGUID == snapshot.playerGUID
        and projection.element == self.ELEMENT_BY_SLOT[slot]
        and projection.action and tonumber(projection.action.spellId)
        and projection.downstreamSpellId
            == tonumber(projection.action.spellId)
        and projection.downstreamElement == projection.element
        and projection.lifetime and projection.lifetime.exact == true
        and projection.duration and projection.duration > 0
        and exactEffect(projection.effect) and exactRange(projection.range)
        and exactRecipients(projection.recipients)
        and currentMatches(current, projection)) then return false end
    snapshot.bySlot[slot] = { slot = slot, element = projection.element,
        haveTool = current.haveTool, active = true,
        name = projection.action.name,
        spellId = tonumber(projection.action.spellId), startTime = now,
        duration = projection.duration, remaining = projection.duration,
        lifetimeExact = true, timingSource = "graph projection",
        effect = projection.effect, range = projection.range,
        recipients = projection.recipients, projected = true, exact = true,
        source = projection.source }
    return true
end

local function clearActive(row)
    row.active, row.name, row.spellId, row.startTime = false, nil, nil, nil
    row.duration, row.icon, row.projected = nil, nil, nil
    row.remaining, row.lifetimeExact = 0, true
    row.timingSource = "graph expiration"
    row.effect = unknown("no active totem")
    row.range = unknown("no active totem")
    row.recipients = unknown("no active totem")
end

function T:Advance(state, elapsed)
    local snapshot = state and state.totems
    elapsed = finite(elapsed)
    if not (snapshot and snapshot.available == true and snapshot.bySlot)
        or not elapsed or elapsed <= 0 then return 0 end
    local expired, slot = 0, nil
    for slot = 1, self.SLOT_COUNT do
        local row = snapshot.bySlot[slot]
        if row and row.active and row.lifetimeExact == true
            and finite(row.remaining) then
            row.remaining = math.max(0, row.remaining - elapsed)
            if row.remaining <= 0 then
                clearActive(row)
                expired = expired + 1
            end
        end
    end
    return expired
end
