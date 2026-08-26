-- Exact Shaman Clearcasting evidence. The active numeric aura's installed DBC
-- topology supplies its cost modifier and charge ceiling; engine cost reads
-- prove each affected action. Graph search consumes only the sealed snapshot.
XelAssist.Game.Player.ShamanClearcasting = {}
local C = XelAssist.Game.Player.ShamanClearcasting

C.SHAMAN_FAMILY = 11
C.MANA = 0
C.APPLY_AURA = 6
C.ADD_PCT_MODIFIER = 108
C.COST_MODIFIER = 14
C.PROC_FLAGS = 87376
C.MAX_AURAS = 48
C.MAX_CACHE = 256

local PROFILES, PROFILE_COUNT = {}, 0
local ACTIONS, ACTION_COUNT = {}, 0
local BASELINES, ACTIVE_EPOCH = {}, nil

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function signed32(value)
    value = integer(value, -2147483648, 4294967295)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function scalar(spellId, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    return signed and signed32(value) or finite(value)
end

local function triple(spellId, field, signed)
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
        out[index] = signed and signed32(values[index]) or finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function cacheProfile(spellId, value)
    if PROFILE_COUNT >= C.MAX_CACHE then
        PROFILES, PROFILE_COUNT = {}, 0
    end
    PROFILES[spellId], PROFILE_COUNT = copy(value), PROFILE_COUNT + 1
end

-- Nil recognition means DBC evidence was unreadable. False means a complete
-- discriminator proved this aura unrelated. True claims the mechanic and then
-- requires the entire installed topology below.
local function classifyAura(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "numeric aura identity unavailable", nil end
    local cached = PROFILES[spellId]
    if cached then
        return cached.valid and copy(cached) or nil, cached.reason,
            cached.recognized == true
    end
    local family = scalar(spellId, "spellFamilyName")
    if family == nil then return nil, "aura DBC family unavailable", nil end
    if family ~= C.SHAMAN_FAMILY then
        cacheProfile(spellId, { valid = false, recognized = false })
        return nil, nil, false
    end
    local effects = triple(spellId, "effect")
    local auras = triple(spellId, "effectApplyAuraName")
    local misc = triple(spellId, "effectMiscValue", true)
    if not effects or not auras or not misc then
        return nil, "Shaman aura topology unavailable", nil
    end
    local recognized = effects[1] == C.APPLY_AURA
        and auras[1] == C.ADD_PCT_MODIFIER and misc[1] == C.COST_MODIFIER
    if not recognized then
        cacheProfile(spellId, { valid = false, recognized = false })
        return nil, nil, false
    end
    local points = triple(spellId, "effectBasePoints", true)
    local dice = triple(spellId, "effectBaseDice")
    local amount = points and dice and points[1] + dice[1] or nil
    local charges = scalar(spellId, "procCharges")
    local chance = scalar(spellId, "procChance")
    local stacks = scalar(spellId, "stackAmount")
    local valid = scalar(spellId, "school") == 6
        and scalar(spellId, "attributes") == 327680
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "procFlags") == C.PROC_FLAGS
        and (chance == 0 or chance == 100)
        and integer(charges, 1, 16) ~= nil
        and (stacks == 0 or stacks == 1)
        and scalar(spellId, "durationIndex") == 8
        and scalar(spellId, "powerType", true) == C.MANA
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and equal(effects, C.APPLY_AURA, 0, 0)
        and equal(auras, C.ADD_PCT_MODIFIER, 0, 0)
        and equal(misc, C.COST_MODIFIER, 0, 0)
        and equal(dice, 1, 0, 0)
        and equal(triple(spellId, "effectDieSides", true), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"), 0, 0, 0)
        and points and points[2] == 0 and points[3] == 0
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 0, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
        and amount and amount < 0 and amount >= -1000
    local out = { valid = valid and true or false, exact = valid and true or false,
        recognized = true, spellId = spellId, family = family,
        modifier = C.COST_MODIFIER, modifierAmount = amount,
        maxCharges = charges, source = "installed Shaman cost-proc DBC topology" }
    if not valid then out.reason = "Shaman Clearcasting DBC topology is incomplete" end
    cacheProfile(spellId, out)
    return valid and copy(out) or nil, out.reason, true
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return cached.valid and cached or nil end
    local family = scalar(spellId, "spellFamilyName")
    local powerType = scalar(spellId, "powerType", true)
    local base, perLevel = scalar(spellId, "manaCost"),
        scalar(spellId, "manaCostPerlevel")
    local percent = scalar(spellId, "manaCostPercentage")
    local perSecond, perSecondLevel = scalar(spellId, "manaPerSecond"),
        scalar(spellId, "manaPerSecondPerLevel")
    local complete = family ~= nil and powerType ~= nil and base ~= nil
        and perLevel ~= nil and percent ~= nil and perSecond ~= nil
        and perSecondLevel ~= nil
    local valid = complete and family == C.SHAMAN_FAMILY
        and powerType == C.MANA and (base > 0 or perLevel > 0)
        and percent == 0 and perSecond == 0 and perSecondLevel == 0
    cached = { valid = valid and true or false, spellId = spellId }
    if ACTION_COUNT < C.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = cached, ACTION_COUNT + 1
    end
    return valid and cached or nil
end

local function modifierSnapshot(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Shaman spell cost modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, C.COST_MODIFIER)
    flat, percent = signed32(flat), signed32(percent)
    changed = integer(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "Shaman spell cost modifier evidence unavailable"
    end
    return { flat = flat, percent = percent, changed = changed }
end

local function exactPowerCost(spellId, zeroAllowed)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "effective Shaman mana cost evidence unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok then return nil, "effective Shaman mana cost evidence unavailable" end
    if costs == nil and zeroAllowed then return 0 end
    if type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "effective Shaman mana cost evidence unavailable"
    end
    local row = costs[1]
    local cost, minimum = finite(row.cost), finite(row.minCost)
    if integer(row.type, 0, 4) ~= C.MANA or not cost or cost < 0
        or minimum ~= cost or finite(row.costPercent) ~= 0
        or finite(row.costPerSec) ~= 0 or finite(row.requiredAuraID) ~= 0
        or row.hasRequiredAura ~= false then
        return nil, "effective Shaman mana cost is not exact"
    end
    if not zeroAllowed and cost <= 0 then
        return nil, "positive baseline Shaman mana cost unavailable"
    end
    return cost
end

local function playerLevel(state)
    return integer(state and state.actors and state.actors.player
        and state.actors.player.level, 1, 255)
end

local function learnBaseline(spellId, level)
    local found = BASELINES[spellId]
    if found and found.level == level then return found end
    local modifier, reason = modifierSnapshot(spellId)
    if not modifier then return nil, reason end
    local cost
    cost, reason = exactPowerCost(spellId, false)
    if not cost then return nil, reason end
    found = { exact = true, spellId = spellId, level = level,
        cost = cost, flat = modifier.flat, percent = modifier.percent }
    BASELINES[spellId] = found
    return found
end

local function activeContract(spellId, level, evidence)
    ACTIVE_EPOCH = ACTIVE_EPOCH or { key = evidence.epoch, contracts = {} }
    if ACTIVE_EPOCH.key ~= evidence.epoch then
        ACTIVE_EPOCH = { key = evidence.epoch, contracts = {} }
    end
    local cached = ACTIVE_EPOCH.contracts[spellId]
    if cached and cached.level == level then return copy(cached) end
    local baseline = BASELINES[spellId]
    local profile = evidence.profile
    local out = { claimed = true, exact = false, spellId = spellId,
        level = level, epoch = evidence.epoch,
        auraSpellId = profile and profile.spellId,
        reason = "Shaman Clearcasting baseline cost unavailable" }
    if baseline and baseline.level == level and profile
        and profile.valid == true and profile.exact == true then
        local modifier, reason = modifierSnapshot(spellId)
        local cost
        if modifier then cost, reason = exactPowerCost(spellId, true) end
        if not modifier or cost == nil then out.reason = reason
        else
            local flatDelta = modifier.flat - baseline.flat
            local percentDelta = modifier.percent - baseline.percent
            if flatDelta == 0 and percentDelta == profile.modifierAmount
                and cost <= baseline.cost then
                out.exact, out.eligible, out.activeCost = true, true, cost
                out.baselineCost, out.reason = baseline.cost, nil
                out.source = "exact engine cost delta from Shaman Clearcasting"
            elseif flatDelta == 0 and percentDelta == 0
                and cost == baseline.cost then
                out.exact, out.eligible = true, false
                out.baselineCost, out.activeCost, out.reason =
                    baseline.cost, baseline.cost, nil
                out.source = "engine reports action unaffected by Clearcasting"
            else out.reason = "Shaman Clearcasting cost regime is ambiguous" end
        end
    end
    ACTIVE_EPOCH.contracts[spellId] = copy(out)
    return out
end

local function identity()
    local guid
    if type(UnitExists) == "function" then
        local ok, exists, found = pcall(UnitExists, "player")
        if ok and (exists == true or exists == 1) then guid = found end
    end
    if (guid == nil or guid == "") and type(UnitGUID) == "function" then
        local ok, found = pcall(UnitGUID, "player")
        if ok then guid = found end
    end
    return guid ~= nil and guid ~= "" and guid or nil
end

local function activeAura(aura, profile, state, now)
    local applications = type(aura) == "table"
        and integer(aura.applications, 1, profile.maxCharges) or nil
    local duration = type(aura) == "table" and finite(aura.duration) or nil
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime) or nil
    if aura.isHelpful ~= true or not applications or not duration
        or duration <= 0 or not expiration or expiration <= now
        or expiration - now > duration + 0.001 then return nil end
    local remaining = expiration - now
    return { available = true, exact = true, active = true,
        remaining = remaining, expiresAt = (finite(state.time) or 0) + remaining,
        remainingCharges = applications, epoch = tostring(profile.spellId)
            .. ":" .. tostring(expiration), profile = copy(profile),
        source = "numeric active aura plus installed Shaman cost-proc DBC" }
end

function C:Observe(state)
    local out = { available = false, exact = false,
        source = "numeric Shaman self-aura scan" }
    local before = identity()
    if classToken() ~= "SHAMAN" or before == nil
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function")
        or type(GetTime) ~= "function" then
        out.reason = "Shaman Clearcasting aura evidence unavailable"
        return out
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    local clockOK, now = pcall(GetTime)
    now = clockOK and finite(now) or nil
    if not ok or type(list) ~= "table" or table.getn(list) > self.MAX_AURAS
        or identity() ~= before or not now then
        out.reason = "Shaman Clearcasting aura evidence unavailable"
        return out
    end
    local found, index
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table"
            and integer(aura.spellId, 1, 4294967295) or nil
        if not spellId then
            out.reason = "numeric Shaman self-aura evidence unavailable"
            return out
        end
        local profile, reason, recognized = classifyAura(spellId)
        if recognized == nil then out.reason = reason; return out end
        if recognized then
            if not profile or found then
                out.reason = profile and "multiple Shaman Clearcasting auras"
                    or reason
                return out
            end
            found = activeAura(aura, profile, state, now)
            if not found then
                out.reason = "active Shaman Clearcasting aura is incomplete"
                return out
            end
        end
    end
    if found then found.guid = before; return found end
    out.available, out.exact, out.active, out.guid = true, true, false, before
    return out
end

function C:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.shamanClearcasting = nil
    local token = knownClass or classToken()
    if token ~= "SHAMAN" then return false end
    state.shamanClearcasting = self:Observe(state)
    if state.shamanClearcasting.active ~= true then ACTIVE_EPOCH = nil end
    return state.shamanClearcasting.exact == true
end

function C:CaptureFacts(action, facts, state)
    local evidence = state and state.shamanClearcasting
    local spellId = action and action.spellId
    if not (evidence and evidence.available == true and evidence.exact == true
        and action and (action.actor or "player") == "player"
        and action.executor == "playerSpell" and actionProfile(spellId)) then
        return facts
    end
    local level = playerLevel(state)
    if not level then return facts end
    if evidence.active ~= true then learnBaseline(spellId, level); return facts end
    local out = copy(facts)
    out.shamanClearcastingCost = activeContract(spellId, level, evidence)
    return out
end

function C:InvalidateCosts()
    BASELINES, ACTIVE_EPOCH = {}, nil
end

function C:Invalidate()
    PROFILES, PROFILE_COUNT, ACTIONS, ACTION_COUNT = {}, 0, {}, 0
    self:InvalidateCosts()
end
