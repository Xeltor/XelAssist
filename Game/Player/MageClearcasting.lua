-- Exact Mage Clearcasting cost evidence. Mutable aura, DBC and effective-cost
-- APIs are confined to root attachment/capture; the separate graph leaf
-- consumes only the sealed contract and never infers a spell order or formula.
XelAssist.Game.Player.MageClearcasting = {}
local C = XelAssist.Game.Player.MageClearcasting

C.AURA_ID = 12536
C.MAGE_FAMILY = 3
C.MANA = 0
C.APPLY_AURA = 6
C.ADD_PCT_MODIFIER = 108
C.COST_MODIFIER = 14
C.MAX_CACHE = 256

local PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
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
    for key, value in pairs(source or {}) do out[key] = value end
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

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and finite(milliseconds) or nil
    if not milliseconds or milliseconds <= 0 then return nil end
    return milliseconds / 1000
end

local function installedProfile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    local effects = triple(C.AURA_ID, "effect")
    local auras = triple(C.AURA_ID, "effectApplyAuraName")
    local points = triple(C.AURA_ID, "effectBasePoints", true)
    local misc = triple(C.AURA_ID, "effectMiscValue", true)
    local targetA = triple(C.AURA_ID, "effectImplicitTargetA")
    local targetB = triple(C.AURA_ID, "effectImplicitTargetB")
    local triggers = triple(C.AURA_ID, "effectTriggerSpell")
    local lifetime = duration(C.AURA_ID)
    local amount = points and points[1] + 1 or nil
    local valid = scalar(C.AURA_ID, "spellFamilyName") == C.MAGE_FAMILY
        and scalar(C.AURA_ID, "powerType", true) == C.MANA
        and scalar(C.AURA_ID, "procCharges") == 1
        and equal(effects, C.APPLY_AURA, 0, 0)
        and equal(auras, C.ADD_PCT_MODIFIER, 0, 0)
        and equal(misc, C.COST_MODIFIER, 0, 0)
        and equal(targetA, 1, 0, 0) and equal(targetB, 0, 0, 0)
        and equal(triggers, 0, 0, 0) and amount == -1000
        and lifetime ~= nil
    if valid then
        PROFILE = { valid = true, exact = true, spellId = C.AURA_ID,
            family = C.MAGE_FAMILY, auraType = C.ADD_PCT_MODIFIER,
            modifier = C.COST_MODIFIER, modifierAmount = amount,
            charges = 1, duration = lifetime,
            source = "installed build-5875 Clearcasting DBC topology" }
        return copy(PROFILE)
    end
    PROFILE = { valid = false, exact = false,
        reason = "Clearcasting DBC topology is incomplete" }
    return nil, PROFILE.reason
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return cached.valid and cached or nil end
    local family = scalar(spellId, "spellFamilyName")
    local powerType = scalar(spellId, "powerType", true)
    local base = scalar(spellId, "manaCost")
    local perLevel = scalar(spellId, "manaCostPerlevel")
    local percent = scalar(spellId, "manaCostPercentage")
    local perSecond = scalar(spellId, "manaPerSecond")
    local perSecondLevel = scalar(spellId, "manaPerSecondPerLevel")
    local complete = family ~= nil and powerType ~= nil and base ~= nil
        and perLevel ~= nil and percent ~= nil and perSecond ~= nil
        and perSecondLevel ~= nil
    local valid = complete and family == C.MAGE_FAMILY
        and powerType == C.MANA and (base > 0 or perLevel > 0)
        and percent == 0 and perSecond == 0 and perSecondLevel == 0
    cached = { valid = valid and true or false, complete = complete,
        spellId = spellId, family = family, powerType = powerType }
    if ACTION_COUNT < C.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = cached, ACTION_COUNT + 1
    end
    return valid and cached or nil
end

local function modifierSnapshot(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "spell cost modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, C.COST_MODIFIER)
    flat, percent, changed = signed32(flat), signed32(percent), finite(changed)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "spell cost modifier evidence unavailable"
    end
    return { flat = flat, percent = percent, changed = changed }
end

local function exactPowerCost(spellId, zeroAllowed)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "effective spell cost evidence unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok then return nil, "effective spell cost evidence unavailable" end
    -- ClassicAPI returns nil when the engine's exact effective cost is zero.
    -- Installed DBC actionProfile has already proven a positive mana cost.
    if costs == nil and zeroAllowed then return 0 end
    if type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "effective spell cost evidence unavailable"
    end
    local entry = costs[1]
    local cost, minimum = finite(entry.cost), finite(entry.minCost)
    if integer(entry.type, 0, 4) ~= C.MANA or not cost or cost < 0
        or minimum ~= cost or finite(entry.costPercent) ~= 0
        or finite(entry.costPerSec) ~= 0
        or finite(entry.requiredAuraID) ~= 0
        or entry.hasRequiredAura ~= false then
        return nil, "effective Mage mana cost is not exact"
    end
    if not zeroAllowed and cost <= 0 then
        return nil, "positive baseline Mage mana cost unavailable"
    end
    return cost
end

local function playerLevel(state)
    return integer(state and state.actors and state.actors.player
        and state.actors.player.level, 1, 255)
end

local function learnBaseline(spellId, level)
    local existing = BASELINES[spellId]
    if existing and existing.level == level then return existing end
    local modifier, reason = modifierSnapshot(spellId)
    if not modifier then return nil, reason end
    local cost
    cost, reason = exactPowerCost(spellId, false)
    if not cost then return nil, reason end
    existing = { exact = true, spellId = spellId, level = level,
        cost = cost, flat = modifier.flat, percent = modifier.percent,
        source = "engine cost captured without Clearcasting" }
    BASELINES[spellId] = existing
    return existing
end

local function activeContract(spellId, level, evidence, profile)
    ACTIVE_EPOCH = ACTIVE_EPOCH or { key = evidence.epoch, contracts = {} }
    if ACTIVE_EPOCH.key ~= evidence.epoch then
        ACTIVE_EPOCH = { key = evidence.epoch, contracts = {} }
    end
    local cached = ACTIVE_EPOCH.contracts[spellId]
    if cached and cached.level == level then return copy(cached) end
    local baseline = BASELINES[spellId]
    local out = { claimed = true, exact = false, spellId = spellId,
        level = level, epoch = evidence.epoch,
        reason = "Clearcasting baseline cost unavailable" }
    if baseline and baseline.level == level then
        local modifier, reason = modifierSnapshot(spellId)
        local cost
        if modifier then cost, reason = exactPowerCost(spellId, true) end
        if not modifier or cost == nil then
            out.reason = reason
        else
            local flatDelta = modifier.flat - baseline.flat
            local percentDelta = modifier.percent - baseline.percent
            if flatDelta == 0 and percentDelta == profile.modifierAmount
                and cost == 0 then
                out.exact, out.eligible = true, true
                out.baselineCost = baseline.cost
                out.source = "exact engine cost delta from installed Clearcasting"
                out.reason = nil
            elseif flatDelta == 0 and percentDelta == 0 then
                out.exact, out.eligible = true, false
                out.baselineCost = baseline.cost
                out.source = "engine reports spell unaffected by Clearcasting"
                out.reason = nil
            else
                out.reason = "spell cost modifier regime changed with Clearcasting"
            end
        end
    end
    ACTIVE_EPOCH.contracts[spellId] = copy(out)
    return out
end

local function observeAura(state, profile)
    local out = { available = false, exact = false,
        source = "ClassicAPI numeric player aura identity" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        out.reason = "Clearcasting aura evidence unavailable"
        return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, C.AURA_ID)
    if not ok then
        out.reason = "Clearcasting aura evidence unavailable"
        return out
    end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local okTime, clock = false, nil
    if type(GetTime) == "function" then okTime, clock = pcall(GetTime) end
    local now = okTime and finite(clock) or nil
    local spellId = type(aura) == "table" and integer(
        aura.spellId, 1, 4294967295) or nil
    local expiration, lifetime = type(aura) == "table"
        and finite(aura.expirationTime) or nil,
        type(aura) == "table" and finite(aura.duration) or nil
    local applications = type(aura) == "table"
        and integer(aura.applications, 1, 255) or nil
    if spellId ~= C.AURA_ID or aura.isHelpful ~= true
        or applications ~= 1 or not now or not expiration
        or expiration <= now or not lifetime or lifetime <= 0
        or lifetime > profile.duration + 0.001 then
        out.available, out.exact = false, false
        out.reason = "active Clearcasting aura timing is incomplete"
        return out
    end
    local remaining = expiration - now
    out.active, out.remaining = true, remaining
    out.expiresAt = (finite(state and state.time) or 0) + remaining
    out.epoch = expiration
    out.profile = copy(profile)
    return out
end

function C:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.mageClearcasting = nil
    local token = knownClass
    if token == nil then token = classToken() end
    if token ~= "MAGE" then return false end
    local profile, reason = installedProfile()
    if not profile then
        state.mageClearcasting = { available = false, exact = false,
            reason = reason, source = "installed build-5875 Clearcasting DBC" }
        return false
    end
    state.mageClearcasting = observeAura(state, profile)
    if state.mageClearcasting.active ~= true then ACTIVE_EPOCH = nil end
    return state.mageClearcasting.exact == true
end

function C:CaptureFacts(action, facts, state)
    local evidence = state and state.mageClearcasting
    local spellId = action and action.spellId
    if not (evidence and evidence.available == true and evidence.exact == true
        and action and (action.actor or "player") == "player"
        and action.executor == "playerSpell" and actionProfile(spellId)) then
        return facts
    end
    local level = playerLevel(state)
    if not level then return facts end
    if evidence.active ~= true then
        learnBaseline(spellId, level)
        return facts
    end
    local profile = evidence.profile
    if not (profile and profile.valid == true and profile.exact == true
        and profile.spellId == C.AURA_ID) then return facts end
    local out = copy(facts)
    out.mageClearcastingCost = activeContract(
        spellId, level, evidence, profile)
    return out
end

function C:InvalidateCosts()
    BASELINES, ACTIVE_EPOCH = {}, nil
end

function C:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
    self:InvalidateCosts()
end
