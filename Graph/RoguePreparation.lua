-- Search-pure Preparation cooldown reset. The setup has no standalone score:
-- value emerges only if an exact delayed Rogue spell is subsequently chosen.
XelAssist.Graph.RoguePreparation = {}
local P = XelAssist.Graph.RoguePreparation

P.CONSUMER_KEY = "roguePreparation:resetCooldown"
P.EPSILON = 0.0001
P.MAX_ACTIONS = 384

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
        and XelAssist.Game.Player.RoguePreparation
end

local function rootActions(state)
    local root = XelAssist.Graph.RootObservation
    if not (root and type(root.Actions) == "function"
        and type(root.Facts) == "function") then
        return nil, nil, "sealed root action catalogue unavailable"
    end
    local actions, status = root:Actions(state)
    if status ~= "known" or type(actions) ~= "table"
        or table.getn(actions) > P.MAX_ACTIONS then
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
        and finite(tooltip.gcd, evidence.gcd, evidence.gcd) == evidence.gcd
        and finite(tooltip.cooldown, evidence.cooldown,
            evidence.cooldown) == evidence.cooldown) then return nil end
    return evidence
end

local function applicationTime(state, actionStart)
    local now = finite(state and state.time, 0, 1000000000)
    actionStart = finite(actionStart, 0, 1000000000)
    if not (now and actionStart and actionStart + P.EPSILON >= now) then
        return nil
    end
    return actionStart
end

local function catalogue(state, applicationAt)
    local owner, ledger = runtime(), XelAssist.Graph.CooldownLedger
    local root, actions, reason = rootActions(state)
    if not root then return nil, reason end
    if not (owner and ledger and ledger:IsPrepared(state)) then
        return nil, "sealed Preparation cooldown ledger unavailable"
    end
    local all, changed, byId, byKey, i = {}, {}, {}, {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if (action.actor or "player") == "player"
            and action.executor == "playerSpell" then
            local facts, status = root:Facts(state, action)
            local contract = status == "known"
                and owner:CooldownContract(facts) or nil
            if not contract or contract.spellId ~= action.spellId then
                return nil, "root Preparation reset classification unavailable"
            end
            if contract.eligible then
                local key = ledger:ActionKey(action)
                local record = ledger:Record(state, action)
                local readyAt = ledger:ReadyAt(state, action)
                if readyAt == nil and record then
                    readyAt = finite(record.readyAt, 0, 1000000000)
                end
                if not (record and record.known == true and readyAt ~= nil) then
                    return nil, "resettable Rogue cooldown evidence unavailable"
                end
                if not byId[contract.spellId] then
                    byId[contract.spellId] = true
                    table.insert(all, contract.spellId)
                end
                if readyAt > applicationAt + P.EPSILON and not byKey[key] then
                    byKey[key] = true
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
    local found = projection and projection.roguePreparationTransition
        or projection and projection.tooltip
            and projection.tooltip.roguePreparationTransition
        or projection and projection.classMechanicProjection
            and projection.classMechanicProjection.roguePreparationTransition
    local owner = runtime()
    if not (owner and type(found) == "table" and found.exact == true
        and found.kind == "roguePreparation" and found.spellId == owner.SPELL_ID
        and finite(found.applicationAt, 0, 1000000000)
        and type(found.changed) == "table" and table.getn(found.changed) > 0
        and table.getn(found.changed) <= P.MAX_ACTIONS
        and type(found.catalogueSpellIds) == "table"
        and table.getn(found.catalogueSpellIds) <= P.MAX_ACTIONS) then return nil end
    return found
end

function P:Prepare(action, state, tooltip, actionStart)
    local owner = runtime()
    if not (owner and (owner:Evidence(action) or owner:Evidence(tooltip))) then
        return nil, nil, false
    end
    local evidence = exactSetup(action, tooltip)
    if not evidence then
        return nil, "Preparation root timing evidence unavailable", true
    end
    local at = applicationTime(state, actionStart)
    if not at then
        return nil, "Preparation exact application time unavailable", true
    end
    local reset, reason = catalogue(state, at)
    if not reset then return nil, reason, true end
    if table.getn(reset.changed) == 0 then
        return nil, "no resettable Rogue cooldown is delayed", true
    end
    local ids, i = {}, nil
    for i = 1, table.getn(reset.changed) do
        table.insert(ids, tostring(reset.changed[i].spellId))
    end
    local out = copy(tooltip)
    out.roguePreparationTransition = { exact = true,
        kind = "roguePreparation", spellId = owner.SPELL_ID,
        applicationAt = at, changed = reset.changed,
        catalogueSpellIds = reset.all, consumerKey = self.CONSUMER_KEY,
        source = evidence.source }
    out.classMechanic = "roguePreparation"
    out.roguePreparationSetupKey =
        "roguePreparation:" .. table.concat(ids, ",")
    return out, nil, true
end

function P:Score(context, projection)
    if not (context and transition(projection)) then
        return false, "Preparation transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "resets exact delayed Rogue spell cooldowns"
    return true
end

function P:Apply(state, candidate)
    local found = transition(candidate)
    local ledger, now = XelAssist.Graph.CooldownLedger,
        finite(state and state.time, 0, 1000000000)
    if not (found and ledger and ledger:IsPrepared(state) and now
        and math.abs(now - found.applicationAt) <= P.EPSILON) then return false end
    local keys, spellIds, i = {}, {}, nil
    for i = 1, table.getn(found.changed) do
        local entry = found.changed[i]
        if not (integer(entry.spellId, 1, 4294967295)
            and type(entry.key) == "string" and entry.key ~= ""
            and finite(entry.readyAt, now + P.EPSILON, 1000000000)
            and finite(state.readyAt and state.readyAt[entry.key],
                now + P.EPSILON, 1000000000)) then return false end
        keys[entry.key], spellIds[entry.spellId] = true, true
    end
    for i = 1, table.getn(found.changed) do
        state.readyAt[found.changed[i].key] = now
    end
    state.roguePreparationReset = { exact = true, at = now,
        sourceSpellId = found.spellId, keys = keys, spellIds = spellIds,
        catalogueSpellIds = found.catalogueSpellIds, source = found.source }
    return true
end

local function resetMarker(state, action, facts)
    local owner, marker = runtime(), state and state.roguePreparationReset
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

function P:RootCooldownCleared(state, action, facts)
    return resetMarker(state, action, facts) ~= nil
end

function P:ConsumerKey(state, action, facts)
    return resetMarker(state, action, facts) and self.CONSUMER_KEY or nil
end

function P:PotentialConsumer(path, action, facts)
    return path and path.state
        and self:ConsumerKey(path.state, action, facts) == self.CONSUMER_KEY
        or false
end

function P:StrategicSetup(tooltip)
    local found = transition(tooltip)
    if not found or tooltip.roguePreparationSetupKey == nil then return nil end
    return { key = tooltip.roguePreparationSetupKey,
        consumerKey = self.CONSUMER_KEY }
end

function P:Copy(source, target)
    if not (source and target) then return false end
    local found = source.roguePreparationReset
    if not found then target.roguePreparationReset = nil; return false end
    target.roguePreparationReset = copy(found)
    target.roguePreparationReset.keys = copy(found.keys)
    target.roguePreparationReset.spellIds = copy(found.spellIds)
    target.roguePreparationReset.catalogueSpellIds = {}
    local i
    for i = 1, table.getn(found.catalogueSpellIds or {}) do
        target.roguePreparationReset.catalogueSpellIds[i] =
            found.catalogueSpellIds[i]
    end
    return true
end
