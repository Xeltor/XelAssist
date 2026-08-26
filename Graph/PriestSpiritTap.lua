-- Branch-local Spirit Tap lifecycle. Proc value emerges only through proven
-- future mana; no fixed kill bonus or Priest regeneration formula is invented.
XelAssist.Graph.PriestSpiritTap = {}
local S = XelAssist.Graph.PriestSpiritTap
local Eligibility = XelAssist.Game.SoulShards
local State = XelAssist.Graph.State

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    if source and source.profile then
        out.profile = {}; for key, value in pairs(source.profile) do out.profile[key] = value end
    end
    if source and source.procKills then
        out.procKills = {}
        for key, value in pairs(source.procKills) do out.procKills[key] = value end
    end
    return out
end
local function clamp(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end
function S:Attach(state, evidence)
    state.priestSpiritTap = evidence and copy(evidence) or nil
    return state.priestSpiritTap ~= nil
end
function S:Copy(source, target)
    target.priestSpiritTap = source.priestSpiritTap
        and copy(source.priestSpiritTap) or nil
    return target.priestSpiritTap ~= nil
end
function S:TagResourceClock(state, clock)
    local tap = state and state.priestSpiritTap
    if clock and tap and tap.available == true and tap.exact == true
        and tap.active == true and tonumber(tap.expiresAt) then
        clock.spiritTapEpoch = tap.epoch
        clock.spiritTapExpiresAt = tap.expiresAt
    end
end
function S:ManaAdvance(state, elapsed)
    local clock, tap = state and state.playerResourceClock,
        state and state.priestSpiritTap
    if not (clock and clock.spiritTapEpoch and tap
        and tap.active == true and clock.spiritTapEpoch == tap.epoch) then
        return elapsed, false
    end
    local now, expiry = tonumber(state.time) or 0, tonumber(tap.expiresAt)
    if not expiry or expiry <= now then return 0, true end
    if now + elapsed > expiry then return expiry - now, true end
    return elapsed, false
end
function S:FinishManaAdvance(state, expired)
    if not expired then return end
    local clock = state and state.playerResourceClock
    if clock then
        clock.phaseKnown, clock.nextIn = false, nil
        clock.phaseSource = "Spirit Tap mana regime expired"
        clock.spiritTapEpoch, clock.spiritTapExpiresAt = nil, nil
    end
end
function S:Advance(state)
    local tap = state and state.priestSpiritTap
    if not (tap and tap.active == true and tonumber(tap.expiresAt)) then return end
    if (tonumber(state.time) or 0) >= tap.expiresAt then
        tap.active, tap.remaining, tap.expiresAt = false, nil, nil
        tap.applicationProbability = nil
        tap.source = "projected Spirit Tap expiry"
    else tap.remaining = tap.expiresAt - (tonumber(state.time) or 0) end
end
local function eligible(state, before)
    local record = before.key ~= nil and State:HostileByKey(state, before.key) or nil
    local descriptor = { relation = "hostile", key = before.key,
        guid = before.guid, record = record }
    local root = XelAssist.Graph.RootObservation
    local observed, status
    if root then observed, status = root:Target(state, descriptor) end
    if status ~= "known" then return false end
    return Eligibility:TargetEligibility(state, descriptor, observed)
end
function S:OnExactPlayerKill(state, before)
    self:Advance(state)
    local tap = state and state.priestSpiritTap
    if not (before and tap and tap.available == true and tap.exact == true
        and tap.learned == true) then return false end
    local record = before.key ~= nil and State:HostileByKey(state, before.key) or nil
    if before.key ~= nil and (not record or record.healthExact ~= true
        or not tonumber(record.health) or record.health > 0)
        or before.key == nil and (state.targetHealthExact ~= true
            or not tonumber(state.targetHealth) or state.targetHealth > 0)
        or not eligible(state, before) then return false end
    tap.procKills = tap.procKills or {}
    local identity = before.key or before.guid or "selected"
    if tap.procKills[identity] then return false end
    tap.procKills[identity] = true
    local now = tonumber(state.time) or 0
    local chance = clamp(tap.procChance)
    if chance <= 0 then return false end
    local prior = tap.active and clamp(tap.applicationProbability or 1) or 0
    tap.active, tap.projected = true, true
    tap.applicationProbability = 1 - (1 - prior) * (1 - chance)
    tap.expiresAt, tap.remaining = now + tap.duration, tap.duration
    tap.epoch = "projected:" .. tostring(now) .. ":" .. tostring(before.guid)
    tap.source = "projected XP-yielding player killing blow"
    self:FinishManaAdvance(state, true)
    -- A projected proc never upgrades an inactive mana clock. The Octo Priest
    -- formula remains unknown until an active regime is learned live.
    return true
end
