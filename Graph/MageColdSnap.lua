-- Search-pure Cold Snap cooldown reset. The setup has no standalone score:
-- value can emerge only when an exact root-catalogue Frost spell whose
-- readiness changed is subsequently chosen.
XelAssist.Graph.MageColdSnap = {}
local C = XelAssist.Graph.MageColdSnap

C.CONSUMER_KEY = "mageColdSnap:resetCooldown"
C.EPSILON = 0.0001
C.MAX_ACTIONS = 384

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
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

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.MageColdSnap
end

local function rootActions(state)
    local root = XelAssist.Graph.RootObservation
    if not (root and type(root.Actions) == "function"
        and type(root.Facts) == "function") then
        return nil, nil, "sealed root action catalogue unavailable"
    end
    local actions, status = root:Actions(state)
    if status ~= "known" or type(actions) ~= "table"
        or table.getn(actions) > C.MAX_ACTIONS then
        return nil, nil, "sealed root action catalogue unavailable"
    end
    return root, actions, nil
end

local function exactSetup(action, tooltip)
    local owner = runtime()
    local evidence = owner and (owner:Evidence(tooltip)
        or owner:Evidence(action)) or nil
    if not evidence then return nil end
    if not (tooltip and finite(tooltip.cost, 0, 0) == 0
        and finite(tooltip.cast, 0, 0) == 0
        and finite(tooltip.gcd, 0, 0) == 0
        and finite(tooltip.cooldown, evidence.cooldown,
            evidence.cooldown) == evidence.cooldown) then return nil end
    return evidence
end

local function applicationTime(state, actionStart)
    actionStart = finite(actionStart, 0, 1000000000)
    if actionStart then return actionStart end
    local now = finite(state and state.time, 0, 1000000000) or 0
    local ready = finite(state and state.actorReadyAt
        and state.actorReadyAt.player, 0, 1000000000) or now
    if state and state.playerChanneling == true then return now end
    return math.max(now, ready)
end

local function catalogue(state, applicationAt)
    local owner, ledger = runtime(), XelAssist.Graph.CooldownLedger
    local root, actions, reason = rootActions(state)
    if not root then return nil, reason end
    if not (owner and ledger and ledger:IsPrepared(state)) then
        return nil, "sealed Cold Snap cooldown ledger unavailable"
    end
    local all, changed, byId, i = {}, {}, {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if (action.actor or "player") == "player"
            and action.executor == "playerSpell" then
            local facts, status = root:Facts(state, action)
            local contract = status == "known"
                and owner:CooldownContract(facts) or nil
            if not contract or contract.spellId ~= action.spellId then
                return nil, "root Cold Snap reset classification unavailable"
            end
            if contract.eligible then
                local key = ledger:ActionKey(action)
                local record = ledger:Record(state, action)
                local readyAt = ledger:ReadyAt(state, action)
                if readyAt == nil and record then
                    readyAt = finite(record.readyAt, 0, 1000000000)
                end
                if not (record and record.known == true and readyAt ~= nil) then
                    return nil, "resettable Frost cooldown evidence unavailable"
                end
                if not byId[contract.spellId] then
                    byId[contract.spellId] = true
                    table.insert(all, contract.spellId)
                end
                if readyAt > applicationAt + C.EPSILON then
                    table.insert(changed, { spellId = contract.spellId,
                        key = key, readyAt = readyAt })
                end
            end
        end
    end
    table.sort(all)
    table.sort(changed, function(left, right)
        if left.spellId ~= right.spellId then
            return left.spellId < right.spellId
        end
        return left.key < right.key
    end)
    return { all = all, changed = changed }, nil
end

local function transition(projection)
    local found = projection and projection.mageColdSnapTransition
        or projection and projection.tooltip
            and projection.tooltip.mageColdSnapTransition
        or projection and projection.classMechanicProjection
            and projection.classMechanicProjection.mageColdSnapTransition
    local owner = runtime()
    if not (owner and type(found) == "table" and found.exact == true
        and found.kind == "mageColdSnap" and found.spellId == owner.SPELL_ID
        and type(found.changed) == "table" and table.getn(found.changed) > 0
        and type(found.catalogueSpellIds) == "table") then return nil end
    return found
end

function C:Prepare(action, state, tooltip, actionStart)
    local owner = runtime()
    if not (owner and (owner:Evidence(action) or owner:Evidence(tooltip))) then
        return nil, nil, false
    end
    local evidence = exactSetup(action, tooltip)
    if not evidence then
        return nil, "Cold Snap root timing evidence unavailable", true
    end
    local at = applicationTime(state, actionStart)
    local reset, reason = catalogue(state, at)
    if not reset then return nil, reason, true end
    if table.getn(reset.changed) == 0 then
        return nil, "no resettable Frost cooldown is delayed", true
    end
    local ids, i = {}, nil
    for i = 1, table.getn(reset.changed) do
        table.insert(ids, tostring(reset.changed[i].spellId))
    end
    local out = copy(tooltip)
    out.mageColdSnapTransition = { exact = true, kind = "mageColdSnap",
        spellId = owner.SPELL_ID, applicationAt = at,
        changed = reset.changed, catalogueSpellIds = reset.all,
        consumerKey = self.CONSUMER_KEY,
        source = evidence.source }
    out.classMechanic = "mageColdSnap"
    out.mageColdSnapSetupKey = "mageColdSnap:" .. table.concat(ids, ",")
    return out, nil, true
end

function C:Score(context, projection)
    if not (context and transition(projection)) then
        return false, "Cold Snap transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "resets exact delayed Frost spell cooldowns"
    return true
end

function C:Apply(state, candidate)
    local found = transition(candidate)
    local ledger, now = XelAssist.Graph.CooldownLedger,
        finite(state and state.time, 0, 1000000000)
    if not (found and ledger and ledger:IsPrepared(state) and now
        and math.abs(now - found.applicationAt) <= C.EPSILON) then return false end
    local keys, spellIds, i = {}, {}, nil
    for i = 1, table.getn(found.changed) do
        local entry = found.changed[i]
        if not (integer(entry.spellId, 1, 4294967295)
            and type(entry.key) == "string" and entry.key ~= ""
            and finite(entry.readyAt, now + C.EPSILON, 1000000000)
            and finite(state.readyAt and state.readyAt[entry.key],
                now + C.EPSILON, 1000000000)) then return false end
        keys[entry.key], spellIds[entry.spellId] = true, true
    end
    for i = 1, table.getn(found.changed) do
        state.readyAt[found.changed[i].key] = now
    end
    state.mageColdSnapReset = { exact = true, at = now,
        sourceSpellId = found.spellId, keys = keys, spellIds = spellIds,
        catalogueSpellIds = found.catalogueSpellIds,
        source = found.source }
    return true
end

local function resetMarker(state, action, facts)
    local owner, marker = runtime(), state and state.mageColdSnapReset
    local contract = owner and owner:CooldownContract(facts) or nil
    local ledger = XelAssist.Graph.CooldownLedger
    local key = ledger and action and ledger:ActionKey(action) or nil
    if not (marker and marker.exact == true and contract
        and contract.eligible == true and contract.spellId == action.spellId
        and marker.sourceSpellId == owner.SPELL_ID
        and marker.spellIds and marker.spellIds[action.spellId] == true
        and marker.keys and marker.keys[key] == true) then return nil end
    return marker
end

-- ActionAdmission calls this before reusing immutable root cooldown evidence.
function C:RootCooldownCleared(state, action, facts)
    return resetMarker(state, action, facts) ~= nil
end

-- Only a spell made ready by this exact reset may close the zero-value lane.
function C:ConsumerKey(state, action, facts)
    return resetMarker(state, action, facts) and self.CONSUMER_KEY or nil
end

function C:PotentialConsumer(path, action, facts)
    return path and path.state
        and self:ConsumerKey(path.state, action, facts) == self.CONSUMER_KEY
        or false
end

function C:StrategicSetup(tooltip)
    local found = transition(tooltip)
    if not found or tooltip.mageColdSnapSetupKey == nil then return nil end
    return { key = tooltip.mageColdSnapSetupKey,
        consumerKey = self.CONSUMER_KEY }
end

function C:Copy(source, target)
    if not (source and target) then return false end
    local found = source.mageColdSnapReset
    if not found then target.mageColdSnapReset = nil; return false end
    target.mageColdSnapReset = copy(found)
    target.mageColdSnapReset.keys = copy(found.keys)
    target.mageColdSnapReset.spellIds = copy(found.spellIds)
    target.mageColdSnapReset.catalogueSpellIds = {}
    local i
    for i = 1, table.getn(found.catalogueSpellIds or {}) do
        target.mageColdSnapReset.catalogueSpellIds[i] =
            found.catalogueSpellIds[i]
    end
    return true
end
