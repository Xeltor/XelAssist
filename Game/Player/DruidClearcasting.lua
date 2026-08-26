-- Exact Druid Omen of Clarity / Clearcasting evidence. Mutable DBC, aura and
-- engine-cost reads happen only while sealing a root observation; graph search
-- receives an immutable, form-specific cost contract.
XelAssist.Game.Player.DruidClearcasting = {}
local C = XelAssist.Game.Player.DruidClearcasting

C.TALENT_ID = 16864
C.AURA_ID = 16870
C.DRUID_FAMILY = 7
C.APPLY_AURA = 6
C.PROC_TRIGGER_AURA = 42
C.ADD_PCT_MODIFIER = 108
C.COST_MODIFIER = 14
C.MANA, C.RAGE, C.ENERGY = 0, 1, 3
C.MAX_CACHE = 256

local PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
local BASELINES = {}

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

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and finite(milliseconds) or nil
    if not milliseconds or milliseconds <= 0 then return nil end
    return milliseconds / 1000
end

local function talentTopology()
    return scalar(C.TALENT_ID, "spellFamilyName") == 0
        and scalar(C.TALENT_ID, "attributes") == 66000
        and scalar(C.TALENT_ID, "procChance") == 100
        and scalar(C.TALENT_ID, "procCharges") == 0
        and equal(triple(C.TALENT_ID, "effect"), C.APPLY_AURA, 0, 0)
        and equal(triple(C.TALENT_ID, "effectApplyAuraName"),
            C.PROC_TRIGGER_AURA, 0, 0)
        and equal(triple(C.TALENT_ID, "effectTriggerSpell"),
            C.AURA_ID, 0, 0)
        and equal(triple(C.TALENT_ID, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(C.TALENT_ID, "effectImplicitTargetB"), 0, 0, 0)
end

local function auraTopology()
    local points = triple(C.AURA_ID, "effectBasePoints", true)
    local dice = triple(C.AURA_ID, "effectBaseDice")
    local amount = points and dice and points[1] + dice[1] or nil
    local lifetime = duration(C.AURA_ID)
    local valid = scalar(C.AURA_ID, "spellFamilyName") == C.DRUID_FAMILY
        and scalar(C.AURA_ID, "attributes") == 262144
        and scalar(C.AURA_ID, "durationIndex") == 8
        and scalar(C.AURA_ID, "procFlags") == 87376
        and scalar(C.AURA_ID, "procChance") == 100
        and scalar(C.AURA_ID, "procCharges") == 1
        and scalar(C.AURA_ID, "powerType", true) == C.MANA
        and scalar(C.AURA_ID, "manaCost") == 0
        and scalar(C.AURA_ID, "manaCostPerlevel") == 0
        and scalar(C.AURA_ID, "manaCostPercentage") == 0
        and equal(triple(C.AURA_ID, "effect"), C.APPLY_AURA, 0, 0)
        and equal(triple(C.AURA_ID, "effectApplyAuraName"),
            C.ADD_PCT_MODIFIER, 0, 0)
        and equal(triple(C.AURA_ID, "effectMiscValue", true),
            C.COST_MODIFIER, 0, 0)
        and equal(points, -101, 0, 0) and equal(dice, 1, 0, 0)
        and equal(triple(C.AURA_ID, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(C.AURA_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(C.AURA_ID, "effectTriggerSpell"), 0, 0, 0)
        and amount == -100 and lifetime ~= nil
    return valid and { modifierAmount = amount, duration = lifetime } or nil
end

local function installedProfile()
    if PROFILE then
        return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason
    end
    local aura = talentTopology() and auraTopology() or nil
    if aura then
        PROFILE = { valid = true, exact = true,
            talentSpellId = C.TALENT_ID, spellId = C.AURA_ID,
            family = C.DRUID_FAMILY, modifier = C.COST_MODIFIER,
            modifierAmount = aura.modifierAmount, charges = 1,
            duration = aura.duration,
            source = "installed build-5875 Omen/Clearcasting DBC topology" }
        return copy(PROFILE)
    end
    PROFILE = { valid = false, exact = false,
        reason = "Druid Clearcasting DBC topology is incomplete" }
    return nil, PROFILE.reason
end

local function talentLearned()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Omen of Clarity talent evidence unavailable"
    end
    local ok, learned = pcall(IsPlayerSpell, C.TALENT_ID)
    if not ok or type(learned) ~= "boolean" then
        return nil, "Omen of Clarity talent evidence unavailable"
    end
    return learned
end

local function actionProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil end
    local cached = ACTIONS[spellId]
    if cached then return cached.recognized and cached or nil end
    local family = scalar(spellId, "spellFamilyName")
    local powerType = scalar(spellId, "powerType", true)
    local base, perLevel = scalar(spellId, "manaCost"),
        scalar(spellId, "manaCostPerlevel")
    local percent = scalar(spellId, "manaCostPercentage")
    local perSecond, perSecondLevel = scalar(spellId, "manaPerSecond"),
        scalar(spellId, "manaPerSecondPerLevel")
    local recognized = family == C.DRUID_FAMILY
    local supported = powerType == C.MANA or powerType == C.RAGE
        or powerType == C.ENERGY
    local complete = family ~= nil and powerType ~= nil and base ~= nil
        and perLevel ~= nil and percent ~= nil and perSecond ~= nil
        and perSecondLevel ~= nil
    local valid = complete and recognized and supported and percent == 0
        and perSecond == 0 and perSecondLevel == 0
    cached = { valid = valid and true or false,
        recognized = recognized and true or false, spellId = spellId,
        powerType = powerType, zeroCost = valid
            and base == 0 and perLevel == 0 or false }
    if recognized and not valid then
        cached.reason = complete
            and "Druid Clearcasting action cost shape is unsupported"
            or "Druid Clearcasting action DBC is incomplete"
    end
    if ACTION_COUNT < C.MAX_CACHE then
        ACTIONS[spellId], ACTION_COUNT = cached, ACTION_COUNT + 1
    end
    return recognized and cached or nil
end

local function modifierSnapshot(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return nil, "Druid spell cost modifier evidence unavailable"
    end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, C.COST_MODIFIER)
    flat, percent = signed32(flat), signed32(percent)
    changed = integer(changed, 0, 4294967295)
    if not ok or flat == nil or percent == nil or changed == nil then
        return nil, "Druid spell cost modifier evidence unavailable"
    end
    return { flat = flat, percent = percent, changed = changed }
end

local function normalized(powerType, cost)
    local owner = XelAssist.Game and XelAssist.Game.ResourceCost
    if owner and type(owner.Normalize) == "function" then
        local ok, value = pcall(owner.Normalize, owner, powerType, cost)
        return ok and finite(value) or nil
    end
    if powerType == C.RAGE then return nil end
    return finite(cost)
end

local function exactPowerCost(spellId, powerType, zeroAllowed)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "effective Druid resource cost evidence unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok then return nil, "effective Druid resource cost evidence unavailable" end
    if costs == nil and zeroAllowed then return 0 end
    if type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "effective Druid resource cost evidence unavailable"
    end
    local row = costs[1]
    local raw, minimum = finite(row.cost), finite(row.minCost)
    if integer(row.type, 0, 4) ~= powerType or not raw or raw < 0
        or minimum ~= raw or finite(row.costPercent) ~= 0
        or finite(row.costPerSec) ~= 0 or finite(row.requiredAuraID) ~= 0
        or row.hasRequiredAura ~= false then
        return nil, "effective Druid resource cost is not exact"
    end
    local cost = normalized(powerType, raw)
    if cost == nil or not zeroAllowed and cost <= 0 then
        return nil, "positive baseline Druid resource cost unavailable"
    end
    return cost
end

local function regime(state)
    return integer(state and state.druidFormState
        and state.druidFormState.formID, 0, 32)
end

local function playerLevel(state)
    return integer(state and state.actors and state.actors.player
        and state.actors.player.level, 1, 255)
end

local function baselineSlot(spellId, formID)
    local byForm = BASELINES[spellId]
    return byForm and byForm[formID] or nil
end

local function learnBaseline(spellId, powerType, level, formID, zeroCost)
    local found = baselineSlot(spellId, formID)
    if found and found.level == level and found.powerType == powerType then
        return found
    end
    local modifier, reason = modifierSnapshot(spellId)
    if not modifier then return nil, reason end
    local cost
    cost, reason = exactPowerCost(spellId, powerType, zeroCost == true)
    if cost == nil then return nil, reason end
    found = { exact = true, spellId = spellId, powerType = powerType,
        level = level, formID = formID, cost = cost,
        flat = modifier.flat, percent = modifier.percent }
    BASELINES[spellId] = BASELINES[spellId] or {}
    BASELINES[spellId][formID] = found
    return found
end

local function activeContract(spellId, powerType, level, formID, evidence)
    -- Aura expiration identifies the charge, not every other live cost
    -- modifier. Cache only inside this root evaluation so a later root with
    -- the same aura epoch revalidates the engine delta.
    evidence.rootContracts = evidence.rootContracts or {}
    local contracts = evidence.rootContracts
    contracts[spellId] = contracts[spellId] or {}
    local cached = contracts[spellId][formID]
    if cached and cached.level == level then return copy(cached) end
    local baseline = baselineSlot(spellId, formID)
    local out = { claimed = true, exact = false, spellId = spellId,
        powerType = powerType, level = level, formID = formID,
        epoch = evidence.epoch, reason = "Druid Clearcasting baseline unavailable" }
    if baseline and baseline.level == level
        and baseline.powerType == powerType then
        local modifier, reason = modifierSnapshot(spellId)
        local cost
        if modifier then cost, reason = exactPowerCost(spellId, powerType, true) end
        if not modifier or cost == nil then out.reason = reason
        else
            local flatDelta = modifier.flat - baseline.flat
            local percentDelta = modifier.percent - baseline.percent
            if flatDelta == 0
                and percentDelta == evidence.profile.modifierAmount
                and cost == 0 then
                out.exact, out.eligible, out.activeCost = true, true, 0
                out.baselineCost, out.reason = baseline.cost, nil
                out.source = "exact engine cost delta from Druid Clearcasting"
            elseif flatDelta == 0 and percentDelta == 0
                and cost == baseline.cost then
                out.exact, out.eligible, out.activeCost = true, false, cost
                out.baselineCost, out.reason = baseline.cost, nil
                out.source = "engine reports action unaffected by Clearcasting"
            else out.reason = "Druid Clearcasting cost regime is ambiguous" end
        end
    end
    contracts[spellId][formID] = copy(out)
    return out
end

local function observeAura(state, profile)
    local out = { available = false, exact = false, learned = true,
        source = "ClassicAPI numeric Druid Clearcasting aura identity" }
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function")
        or type(GetTime) ~= "function" then
        out.reason = "Druid Clearcasting aura evidence unavailable"
        return out
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, C.AURA_ID)
    local timeOK, now = pcall(GetTime)
    now = timeOK and finite(now) or nil
    if not ok or not now then
        out.reason = "Druid Clearcasting aura evidence unavailable"
        return out
    end
    out.available, out.exact = true, true
    if aura == nil then out.active = false; return out end
    local spellId = type(aura) == "table"
        and integer(aura.spellId, 1, 4294967295) or nil
    local applications = type(aura) == "table"
        and integer(aura.applications, 1, 1) or nil
    local lifetime = type(aura) == "table" and finite(aura.duration) or nil
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime) or nil
    if spellId ~= C.AURA_ID or aura.isHelpful ~= true or applications ~= 1
        or not lifetime or lifetime <= 0 or lifetime > profile.duration + 0.001
        or not expiration or expiration <= now
        or expiration - now > lifetime + 0.001 then
        out.available, out.exact = false, false
        out.reason = "active Druid Clearcasting aura is incomplete"
        return out
    end
    local remaining = expiration - now
    out.active, out.remaining, out.remainingCharges = true, remaining, 1
    out.expiresAt = (finite(state and state.time) or 0) + remaining
    out.epoch, out.profile, out.rootContracts = expiration, copy(profile), {}
    return out
end

function C:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.druidClearcasting = nil
    if (knownClass or classToken()) ~= "DRUID" then return false end
    local profile, reason = installedProfile()
    if not profile then
        state.druidClearcasting = { available = false, exact = false,
            reason = reason, source = "installed build-5875 Druid DBC" }
        return false
    end
    local learned
    learned, reason = talentLearned()
    if learned == nil then
        state.druidClearcasting = { available = false, exact = false,
            reason = reason, source = "ClassicAPI known-spell bitmap" }
        return false
    elseif not learned then
        state.druidClearcasting = { available = true, exact = true,
            learned = false, active = false, profile = profile,
            source = "exact unlearned Omen of Clarity talent" }
        return true
    end
    state.druidClearcasting = observeAura(state, profile)
    return state.druidClearcasting.exact == true
end

function C:CaptureFacts(action, facts, state)
    local evidence = state and state.druidClearcasting
    if not (evidence and evidence.available == true and evidence.exact == true
        and evidence.learned == true and action
        and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return facts end
    local profile = actionProfile(action.spellId)
    if not profile then return facts end
    local level, formID = playerLevel(state), regime(state)
    if not level or formID == nil then return facts end
    if evidence.active ~= true then
        if profile.valid then learnBaseline(action.spellId,
            profile.powerType, level, formID, profile.zeroCost) end
        return facts
    end
    if not profile.valid then
        local out = copy(facts)
        out.druidClearcastingCost = { claimed = true, exact = false,
            spellId = action.spellId, powerType = profile.powerType,
            level = level, formID = formID, epoch = evidence.epoch,
            reason = profile.reason }
        return out
    end
    if not (evidence.profile and evidence.profile.valid == true
        and evidence.profile.exact == true
        and evidence.profile.spellId == C.AURA_ID) then return facts end
    local out = copy(facts)
    out.druidClearcastingCost = activeContract(action.spellId,
        profile.powerType, level, formID, evidence)
    return out
end

function C:InvalidateCosts()
    BASELINES = {}
end

function C:Invalidate()
    PROFILE, ACTIONS, ACTION_COUNT = nil, {}, 0
    self:InvalidateCosts()
end
