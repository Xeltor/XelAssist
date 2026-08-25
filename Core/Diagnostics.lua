-- Durable capability audit and privacy-safe live evidence summary.
XelAssist.Core.Diagnostics = {}
local D = XelAssist.Core.Diagnostics
local XA = XelAssist

local function msg(text, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. text, r or 0.35, g or 0.85, b or 1)
end

local function versionOfNampower()
    if not GetNampowerVersion then return nil end
    local ok, major, minor, patch = pcall(GetNampowerVersion)
    if not ok or not major then return nil end
    if minor == nil then return tostring(major) end
    return tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch or 0)
end

local function discoveredActions()
    local found = XelAssist.Game.Actors and XelAssist.Game.Actors:Actions()
        or XelAssist.Game.Capabilities:Actions()
    if XelAssist.Game.Inventory then
        local items, i = XelAssist.Game.Inventory:Actions(), nil
        for i = 1, table.getn(items) do table.insert(found, items[i]) end
    end
    return found
end

function D:Audit(owner)
    if type(XelAssistCharDB.runtime) ~= "table" then XelAssistCharDB.runtime = {} end
    local runtime = XelAssistCharDB.runtime
    runtime.version, runtime.schema = owner.version, XelAssistCharDB.schema
    runtime.loadedAt = time and time() or 0
    runtime.superWoW = SUPERWOW_VERSION and tostring(SUPERWOW_VERSION) or nil
    runtime.nampower = versionOfNampower()
    runtime.apis = { queue = QueueSpellByName and true or false,
        spellRecords = GetSpellRecField and true or false,
        exactUnits = GetUnitField and true or false,
        castInfo = GetCastInfo and true or false,
        onSwingInfo = GetOnSwingInfo and true or false,
        rangeData = GetSpellRangeData and true or false,
        movement = PlayerIsMoving and true or false,
        comboOwner = C_PlayerInfo
            and type(C_PlayerInfo.GetComboPointState) == "function" or false,
        comboDuration = C_Spell
            and type(C_Spell.GetSpellDurationRange) == "function" or false,
        equippedHit = C_PlayerInfo
            and type(C_PlayerInfo.GetEquippedHitBonuses) == "function" or false,
        targetResistances = (UnitResistance or GetUnitField) and true or false }
    local evidence = owner:EnableEvidenceEvents()
    runtime.evidenceEvents = { damage = evidence.damage, miss = evidence.miss,
        autoAttack = evidence.autoAttack, aura = evidence.aura,
        start = evidence.start, go = evidence.go,
        castResult = evidence.castResult,
        onSwingExact = evidence.onSwingExact }
    local focus = XelAssist.Game.Pets and XelAssist.Game.Pets.FocusEvidence
    runtime.hunterFocus = focus and focus:Status() or nil
    local rounds = XelAssist.Game.AttackRounds
    runtime.companionSwings = rounds and rounds:Status() or nil
    local playerRounds = XelAssist.Game.Player
        and XelAssist.Game.Player.AttackRounds
    runtime.playerSwings = playerRounds and playerRounds:Status() or nil
    local owner = XelAssist.Game.Player and XelAssist.Game.Player.OnSwing
    local onSwing = owner and owner:Snapshot() or nil
    runtime.playerOnSwing = onSwing and { supported = onSwing.supported,
        exact = onSwing.exact, occupied = onSwing.occupied } or nil
    runtime.hitBonuses = XelAssist.Game.HitBonuses
        and XelAssist.Game.HitBonuses:Snapshot()
        or { melee = 0, ranged = 0, spell = 0, equipmentKnown = false }
    local ok, actions = pcall(discoveredActions)
    if ok and type(actions) == "table" then
        local inferred, petActions, i = 0, 0, nil
        for i = 1, table.getn(actions) do
            if actions[i].facts and actions[i].facts.inferred then inferred = inferred + 1 end
            if actions[i].actor == "pet" then petActions = petActions + 1 end
        end
        runtime.actions, runtime.petActions = table.getn(actions), petActions
        runtime.petPresent = UnitExists("pet") and not UnitIsDead("pet") and true or false
        runtime.petSpellbook = GetSpellName and BOOKTYPE_PET and true or false
        runtime.petActionBar = GetPetActionInfo and true or false
        runtime.petCooldowns = GetPetActionCooldown and true or false
        runtime.inferred, runtime.auditError = inferred, nil
    else
        runtime.actions, runtime.inferred = nil, nil
        runtime.auditError = tostring(actions or "action discovery failed")
    end
    return runtime
end

local function seconds(value)
    if not tonumber(value) then return "?" end
    return string.format("%.2f", tonumber(value))
end

function D:Print(owner)
    local runtime = self:Audit(owner)
    msg("mode=" .. owner.mode .. ", execution=" .. (owner.executionEnabled and "ready" or "disabled")
        .. ", graph=utility, horizon=auto, shown="
        .. (XelAssistCharDB.visibleSteps or 3)
        .. ", nodes=" .. (runtime.actions or 0) .. ", inferred=" .. (runtime.inferred or 0)
        .. ", fallback=conservative hold, schema=" .. (runtime.schema or 4) .. ".")
    msg("SuperWoW=" .. (runtime.superWoW or "missing") .. ", Nampower="
        .. (runtime.nampower or (runtime.apis.queue and "present" or "missing"))
        .. ", DBC=" .. (runtime.apis.spellRecords and "yes" or "no")
        .. ", exact-units=" .. (runtime.apis.exactUnits and "yes" or "no") .. ".")
    msg("ClassicAPI combo owner=" .. (runtime.apis.comboOwner and "yes" or "fallback")
        .. ", combo duration=" .. (runtime.apis.comboDuration and "yes" or "fallback")
        .. ", equipped hit=" .. (runtime.apis.equippedHit and "yes" or "fallback") .. ".")
    local hit = runtime.hitBonuses
    msg("Hit evidence: melee=" .. tostring(hit.melee or 0)
        .. "%, ranged=" .. tostring(hit.ranged or 0)
        .. "%, spell=" .. tostring(hit.spell or 0) .. "% ("
        .. tostring(hit.source or "unavailable") .. "); remaining gap="
        .. tostring(hit.gap or "none") .. ".")
    msg("resistance outcomes: damage=" .. (runtime.evidenceEvents.damage and "on" or "off")
        .. ", miss=" .. (runtime.evidenceEvents.miss and "on" or "off")
        .. ", white swings=" .. (runtime.evidenceEvents.autoAttack and "on" or "off")
        .. ", aura=" .. (runtime.evidenceEvents.aura and "on" or "off")
        .. ", cast lifecycle=" .. (runtime.evidenceEvents.start
            and runtime.evidenceEvents.go and "on" or "off")
        .. ", exact cast results="
        .. (runtime.evidenceEvents.castResult and "on" or "off")
        .. ", exact next-swing="
        .. (runtime.evidenceEvents.onSwingExact and "on" or "off") .. ".")
    local focus = runtime.hunterFocus
    if focus then
        local state = focus.executable and "executable"
            or focus.verified and "verified-dormant" or "learning"
        msg("Hunter focus: " .. state .. ", clean samples=" .. tostring(focus.samples or 0)
            .. ", gain=" .. tostring(focus.amount or "?")
            .. ", observed=" .. seconds(focus.observedInterval) .. "s"
            .. ", conservative=" .. seconds(focus.interval) .. "s"
            .. ", energize attribution=" .. (focus.energizeAttribution and "on" or "off")
            .. ", phase=" .. (focus.phaseKnown and "known" or "unknown")
            .. ", last reset=" .. tostring(focus.lastResetReason or "none") .. ".")
    end
    local swings = runtime.companionSwings
    if swings then
        local state = swings.verified and swings.phaseKnown and "phase-known"
            or swings.verified and "verified-dormant" or "awaiting-round"
        msg("Companion swings: " .. state
            .. ", cadence samples=" .. tostring(swings.samples or 0)
            .. ", speed=" .. seconds(swings.speed) .. "s"
            .. ", conservative=" .. seconds(swings.interval) .. "s"
            .. ", magnitude=" .. (swings.outcomeMagnitudeKnown
                and "known" or "withheld")
            .. ", last reset=" .. tostring(swings.lastResetReason or "none") .. ".")
    end
    if runtime.lastError then msg("last graph error: " .. runtime.lastError, 1, 0.4, 0.25) end
    return runtime
end

function XA:RuntimeAudit() return D:Audit(self) end
