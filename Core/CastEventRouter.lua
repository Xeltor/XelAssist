-- Cast-event routing keeps transport argument shapes out of the runtime
-- dispatcher. Hostile identities remain opaque, session-only GUIDs owned by
-- Game.HostileCasts; this module never resolves or stores names.
XelAssist.Core.CastEventRouter = {}
local R = XelAssist.Core.CastEventRouter

local function at()
    return GetTime and GetTime() or 0
end

local function owned(casterGuid)
    local resistance = XelAssist.Combat.Resistance
    if not resistance or not resistance.IsOwnedCaster then return nil end
    if resistance:IsOwnedCaster(casterGuid) then return true end
    local hostiles = XelAssist.Game and XelAssist.Game.Hostiles
    if hostiles and hostiles.ProvesGuid
        and hostiles:ProvesGuid(casterGuid) then
        return false
    end
    return nil
end

local function hostileCasts()
    return XelAssist.Game and XelAssist.Game.HostileCasts
end

function R:Reset()
    local casts = hostileCasts()
    if casts and casts.Reset then casts:Reset() end
    local hostiles = XelAssist.Game and XelAssist.Game.Hostiles
    if hostiles and hostiles.ResetObserved then hostiles:ResetObserved() end
    XelAssist.targetCastUntil, XelAssist.targetCastGUID = nil, nil
    XelAssist.petCastGuid, XelAssist.petCastSpellId = nil, nil
    XelAssist.petCastUntil, XelAssist.petCastChannel = nil, nil
end

-- Nampower OTHER events carry exact raw GUIDs. Route that evidence before the
-- player/pet lane tests ownership so hostile casts cannot be discarded there.
function R:RouteHostileNampower(eventName, a1, a2, a3, a4, a5, a6, a7, a8)
    local casts = hostileCasts()
    if not casts then return end
    if eventName == "SPELL_START_OTHER" and casts.ObserveStartOther then
        casts:ObserveStartOther(a3, a4, a2, a6, a7, a8, owned(a3), at())
    elseif eventName == "SPELL_GO_OTHER" and casts.ObserveGoOther then
        casts:ObserveGoOther(a3, a4, a2, owned(a3), at())
    elseif eventName == "SPELL_FAILED_OTHER" and casts.ObserveFailedOther then
        -- Nampower supplies no target for this event. The game ledger matches
        -- only the active caster+spell generation; no target is fabricated.
        casts:ObserveFailedOther(a1, a2, owned(a1), at())
    end
end

function R:RouteOwnedStart(XA, spellId, casterGuid, targetGuid,
    castTimeMs, channelDurationMs, spellType)
    if owned(casterGuid) ~= true then return end
    local normalQueue = XelAssist.Core.PlayerNormalQueue
    local queueEvents = XelAssist.Core.PlayerQueueEvents
    local routeEvidence = true
    if casterGuid == XA:PlayerGUID() then
        routeEvidence = queueEvents:Allows(spellId,
            normalQueue:ServerAccepted(spellId, targetGuid))
    end
    local castSeconds = math.max(0, tonumber(castTimeMs) or 0) / 1000
    local channelSeconds = math.max(0, tonumber(channelDurationMs) or 0) / 1000
    local duration = castSeconds + channelSeconds
    if routeEvidence then
        XA:TouchPendingSpell(spellId, "started", duration + 2,
            casterGuid, targetGuid)
    end
    local _, petGuid = UnitExists("pet")
    if casterGuid == petGuid then
        XA.petCastGuid, XA.petCastSpellId = casterGuid, spellId
        XA.petCastUntil = at() + math.max(0.05, duration)
        XA.petCastChannel = tonumber(spellType) == 1 and true or false
    end
end

function R:RouteOwnedGo(XA, spellId, casterGuid, targetGuid)
    if owned(casterGuid) ~= true then return end
    local normalQueue = XelAssist.Core.PlayerNormalQueue
    local queueEvents = XelAssist.Core.PlayerQueueEvents
    local routeEvidence = true
    if casterGuid == XA:PlayerGUID() then
        routeEvidence = queueEvents:Allows(spellId,
            normalQueue:ServerAccepted(spellId, targetGuid))
    end
    if routeEvidence then
        XA:TouchPendingSpell(spellId, "go", 2, casterGuid, targetGuid)
    end
    if XA.petCastGuid == casterGuid
        and tonumber(XA.petCastSpellId) == tonumber(spellId)
        and not XA.petCastChannel then
        XA:ClearPetCast(spellId, casterGuid)
    end
end

function R:RouteOwnedFailure(XA, casterGuid, spellId)
    if owned(casterGuid) ~= true then return end
    local current = XA.currentPendingAuras and XA.currentPendingAuras[casterGuid]
    if current and tonumber(current.spellId) == tonumber(spellId) then
        XA:ClearAuraPending(current.name, current.target, casterGuid)
    end
    XA:ClearPetCast(spellId, casterGuid)
end

function R:HandleNampower(XA, eventName, a1, a2, a3, a4, a5, a6, a7, a8)
    self:RouteHostileNampower(eventName, a1, a2, a3, a4, a5, a6, a7, a8)
    if eventName == "SPELL_START_SELF" or eventName == "SPELL_START_OTHER" then
        self:RouteOwnedStart(XA, a2, a3, a4, a6, a7, a8)
    elseif eventName == "SPELL_GO_SELF" or eventName == "SPELL_GO_OTHER" then
        self:RouteOwnedGo(XA, a2, a3, a4)
    elseif eventName == "SPELL_FAILED_OTHER" then
        self:RouteOwnedFailure(XA, a1, a2)
    end
end

function R:RouteHostileUnitCast(casterGuid, targetGuid, status,
    spellId, durationMs)
    local casts = hostileCasts()
    if casts and casts.ObserveUnitCast then
        -- SuperWoW is fallback/corroboration only. arg2 is its observed target
        -- GUID; nil remains nil and is never replaced with the selected target.
        casts:ObserveUnitCast(casterGuid, targetGuid, status, spellId,
            durationMs, owned(casterGuid), at())
    end
end

function R:TrackSelectedTarget(XA, casterGuid, status, durationMs)
    local _, targetGuid = UnitExists("target")
    if not targetGuid or casterGuid ~= targetGuid then return end
    if status == "START" or status == "CHANNEL" then
        XA.targetCastUntil = at() + ((durationMs or 1500) / 1000)
        XA.targetCastGUID = targetGuid
    elseif status == "CAST" or status == "FAIL" then
        XA.targetCastUntil, XA.targetCastGUID = nil, nil
    end
end

function R:TrackPlayer(XA, casterGuid, targetGuid, status, spellId, durationMs)
    local _, playerGuid = UnitExists("player")
    if not playerGuid or casterGuid ~= playerGuid then return end
    local castSpell = SpellInfo and SpellInfo(spellId) or nil
    local normalQueue = XelAssist.Core.PlayerNormalQueue
    local queueEvents = XelAssist.Core.PlayerQueueEvents
    local matched
    if status == "START" or status == "CHANNEL" or status == "CAST" then
        matched = normalQueue:ServerAccepted(spellId, targetGuid)
    elseif status == "FAIL" then
        matched = normalQueue:ServerFailure(spellId, targetGuid)
    end
    local routeEvidence = queueEvents:Allows(spellId, matched)
    if castSpell and routeEvidence then
        XA:UpdateDecisionStatus(spellId, "player", status)
    end
    if status == "START" or status == "CHANNEL" then
        XA.Game.Player.ChannelRuntime:Start(
            spellId, targetGuid, durationMs, status == "CHANNEL")
    elseif status == "CAST" or status == "FAIL" then
        XA.Game.Player.ChannelRuntime:Clear()
    end
    if castSpell and routeEvidence and status == "CAST" then
        XA:TouchPendingSpell(spellId, "go", 2, playerGuid, targetGuid)
    elseif castSpell and routeEvidence and status == "FAIL" then
        XA:MarkPendingFailure(spellId, playerGuid, targetGuid)
    end
end

function R:TrackPet(XA, casterGuid, targetGuid, status, spellId, durationMs)
    local _, petGuid = UnitExists("pet")
    if not petGuid or casterGuid ~= petGuid then return end
    XA:UpdateDecisionStatus(spellId, "pet", status)
    if status == "START" or status == "CHANNEL" then
        XA.petCastGuid, XA.petCastSpellId = petGuid, spellId
        XA.petCastUntil = at() + ((durationMs or 1500) / 1000)
        XA.petCastChannel = status == "CHANNEL"
        XA:TouchPendingSpell(spellId, "started",
            (durationMs or 1500) / 1000 + 2, petGuid, targetGuid)
    elseif status == "CAST" then
        XA:ClearPetCast(spellId, petGuid)
        XA:TouchPendingSpell(spellId, "go", 2, petGuid, targetGuid)
    elseif status == "FAIL" then
        XA:ClearPetCast(spellId, petGuid)
        XA:ClearPendingBySpell(spellId, petGuid, targetGuid)
    end
end

function R:HandleUnitCast(XA, casterGuid, targetGuid, status,
    spellId, durationMs)
    if status ~= "START" and status ~= "CHANNEL"
        and status ~= "CAST" and status ~= "FAIL" then
        return
    end
    self:RouteHostileUnitCast(casterGuid, targetGuid, status,
        spellId, durationMs)
    self:TrackSelectedTarget(XA, casterGuid, status, durationMs)
    self:TrackPlayer(XA, casterGuid, targetGuid, status, spellId, durationMs)
    self:TrackPet(XA, casterGuid, targetGuid, status, spellId, durationMs)
end
