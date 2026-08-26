-- Exact Octo patch-5 Spirit Tap ownership and active-aura evidence. The client
-- proves proc rank and aura shape; it does not prove Priest mana arithmetic.
XelAssist.Game.Player.PriestSpiritTap = {}
local S = XelAssist.Game.Player.PriestSpiritTap

S.AURA_ID = 15271
S.DURATION = 15
S.RANKS = {
    { id = 15270, chance = 0.20 }, { id = 15335, chance = 0.40 },
    { id = 15336, chance = 0.60 }, { id = 15337, chance = 0.80 },
    { id = 15338, chance = 1.00 },
}

local PROFILE
local function number(spell, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spell, field)
    return ok and tonumber(value) or nil
end
local function values(spell, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spell, field, 1)
    return ok and type(value) == "table" and value or nil
end
local function triple(value, a, b, c)
    return value and tonumber(value[1]) == a and tonumber(value[2]) == b
        and tonumber(value[3]) == c
end
local function installedProfile()
    if PROFILE ~= nil then return PROFILE.valid and PROFILE or nil,
        PROFILE.reason end
    local effect, aura = values(S.AURA_ID, "effect"),
        values(S.AURA_ID, "effectApplyAuraName")
    local points, misc = values(S.AURA_ID, "effectBasePoints"),
        values(S.AURA_ID, "effectMiscValue")
    local target = values(S.AURA_ID, "effectImplicitTargetA")
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, milliseconds = pcall(GetSpellDuration, S.AURA_ID, 1)
        duration = ok and tonumber(milliseconds) and milliseconds / 1000 or nil
    end
    local valid = triple(effect, 6, 6, 0) and triple(aura, 137, 134, 0)
        and triple(points, 99, 49, 0) and triple(misc, 4, 0, 0)
        and triple(target, 1, 1, 0) and duration == S.DURATION
    local index
    for index = 1, 5 do
        local rank = S.RANKS[index]
        valid = valid and number(rank.id, "attributes") == 464
            and number(rank.id, "procFlags") == 65538
            and number(rank.id, "procChance") == rank.chance * 100
            and triple(values(rank.id, "effect"), 6, 0, 0)
            and triple(values(rank.id, "effectApplyAuraName"), 42, 0, 0)
            and triple(values(rank.id, "effectTriggerSpell"), S.AURA_ID, 0, 0)
    end
    PROFILE = valid and { valid = true, exact = true, duration = duration,
        auraId = S.AURA_ID, source = "installed Octo patch-5 Spirit Tap topology" }
        or { valid = false, reason = "Spirit Tap DBC topology is incomplete" }
    return PROFILE.valid and PROFILE or nil, PROFILE.reason
end
local function ownedRank()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local index
    for index = 5, 1, -1 do
        local ok, known = pcall(IsPlayerSpell, S.RANKS[index].id)
        if ok and (known == true or known == 1) then return S.RANKS[index], index end
    end
    return false
end
local function activeAura(state, profile)
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
        and type(GetTime) == "function") then
        return nil, "Spirit Tap aura evidence unavailable"
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, S.AURA_ID)
    local okTime, now = pcall(GetTime)
    if not ok or not okTime or tonumber(now) == nil then
        return nil, "Spirit Tap aura evidence unavailable"
    end
    if aura == nil then return { active = false, exact = true } end
    local spellId = type(aura) == "table" and tonumber(aura.spellId)
    local expiration = type(aura) == "table" and tonumber(aura.expirationTime)
    local duration = type(aura) == "table" and tonumber(aura.duration)
    if spellId ~= S.AURA_ID or aura.isHelpful ~= true or not expiration
        or expiration <= now or not duration or duration <= 0
        or duration > profile.duration + 0.001 then
        return nil, "active Spirit Tap timing is incomplete"
    end
    local remaining = expiration - now
    return { active = true, exact = true, remaining = remaining,
        expiresAt = (tonumber(state and state.time) or 0) + remaining,
        epoch = expiration }
end

function S:Snapshot(state, knownClass)
    if knownClass ~= "PRIEST" then return nil end
    local profile, reason = installedProfile()
    if not profile then return { available = false, exact = false,
        reason = reason, source = "installed Octo patch-5 Spirit Tap DBC" } end
    local rank, rankIndex = ownedRank()
    if rank == false then return { available = true, exact = true,
        learned = false, active = false, profile = profile } end
    if not rank then return { available = false, exact = false,
        reason = "Spirit Tap rank ownership unavailable", profile = profile } end
    local active, auraReason = activeAura(state, profile)
    if not active then return { available = false, exact = false,
        learned = true, reason = auraReason, profile = profile } end
    active.available, active.learned, active.rank = true, true, rankIndex
    active.procChance, active.rootSpellId = rank.chance, rank.id
    active.duration, active.profile = profile.duration, profile
    active.source = active.active and "exact active Spirit Tap aura"
        or "exact absent Spirit Tap aura"
    return active
end

function S:Invalidate() PROFILE = nil end
