-- Sliced, evaluation-owned capture of mutable root evidence.
XelAssist.Graph.RootObservation = {}
local R = XelAssist.Graph.RootObservation
local function part(value)
    if value == nil then return "" end
    return tostring(value)
end
local function copy(value, depth, seen)
    if type(value) ~= "table" or depth <= 0 then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        out[key] = copy(entry, depth - 1, seen)
    end
    return out
end
local function copyRef(ref)
    if type(ref) ~= "table" then return ref end
    local out, key, value = {}, nil, nil
    for key, value in pairs(ref) do out[key] = value end
    return out
end
local function copyAction(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        if key == "actorRef" then out[key] = copyRef(value)
        elseif type(value) == "table" then out[key] = copy(value, 8)
        else out[key] = value end
    end
    out.facts = copy(source and source.facts or {}, 8)
    return out
end
function R:ActionKey(action)
    local actor = action and action.actor or "player"
    return "observation:action:" .. part(actor) .. "\001"
        .. part(action and action.executor) .. "\001"
        .. part(action and action.bookType) .. "\001"
        .. part(action and action.slot) .. "\001"
        .. part(action and action.actionSlot) .. "\001"
        .. part(action and action.spellId) .. "\001"
        .. part(action and action.name) .. "\001"
        .. part(action and action.rankText) .. "\001"
        .. part(action and action.rank)
end
function R:RecipientKey(descriptor)
    if type(descriptor) ~= "table" then return descriptor end
    if descriptor.key ~= nil then return descriptor.key end
    if descriptor.guid ~= nil then return descriptor.guid end
    return descriptor.unit
end
local function context(owner, state)
    local observed = type(state) == "table" and state.rootObservation or nil
    if type(observed) ~= "table" or not observed.xelRootObservation then
        return nil, "absent"
    end
    if not observed.sealed then return observed, "unknown" end
    return observed, "known"
end
function R:ActionRecord(state, action)
    local observed, status = context(self, state)
    if status ~= "known" then return nil, status end
    local record = observed.actionRecords[self:ActionKey(action)]
    if not record then return nil, "unknown" end
    return record, "known"
end
function R:Recipient(state, action, descriptor)
    local record, status = self:ActionRecord(state, action)
    if status ~= "known" then return nil, status end
    local key = self:RecipientKey(descriptor)
    local recipient = key ~= nil and record.recipients[key] or nil
    if not recipient then return nil, "unknown" end
    return recipient, "known"
end
function R:Target(state, descriptor)
    local observed, status = context(self, state)
    if status ~= "known" then return nil, status end
    local key = self:RecipientKey(descriptor)
    local record = key ~= nil and observed.targetRecords[key] or nil
    if not record then return nil, "unknown" end
    return record, "known"
end
function R:Facts(state, action)
    local record, status = self:ActionRecord(state, action)
    if status ~= "known" then return nil, status end
    if not record.factsKnown then return nil, "unknown" end
    return record.facts, "known"
end
function R:Power(state, action)
    local observed, status = context(self, state)
    if status ~= "known" then return nil, status end
    local record = observed.powerRecords[self:ActionKey(action)]
    if not record then return nil, "unknown" end
    return record, "known"
end
function R:Config(state)
    local observed, status = context(self, state)
    if status ~= "known" then return nil, status end
    return observed.config, "known"
end
function R:ConfigOrLive(state)
    local config, status = self:Config(state)
    if status == "absent" then return XelAssistCharDB or {}, "known" end
    return config, status
end
function R:Actions(state)
    local observed, status = context(self, state)
    if status ~= "known" then return nil, status end
    return observed.actions, "known"
end
local function recipientField(owner, state, action, descriptor, known, value)
    local record, status = owner:Recipient(state, action, descriptor)
    if status ~= "known" then return nil, status end
    if not record[known] then return nil, "unknown" end
    return record[value], "known"
end
function R:Aura(state, action, descriptor)
    return recipientField(self, state, action, descriptor,
        "auraKnown", "auraActive")
end
function R:Pending(state, action, descriptor)
    return recipientField(self, state, action, descriptor,
        "pendingKnown", "pending")
end
function R:ObservedBlocker(state, action, descriptor)
    return recipientField(self, state, action, descriptor,
        "observationKnown", "observationBlocker")
end
function R:Usability(state, action)
    local record, status = self:ActionRecord(state, action)
    if status ~= "known" then return nil, status end
    if not record.usability then return nil, "unknown" end
    return record.usability, "known"
end
function R:Reagent(state, action)
    local record, status = self:ActionRecord(state, action)
    if status ~= "known" then return nil, status end
    if not record.reagent then return nil, "unknown" end
    return record.reagent, "known"
end
local function remaining(start, duration, observedAt)
    start, duration = tonumber(start), tonumber(duration)
    if not start or not duration then return nil end
    if start == 0 or duration <= 0 then return 0 end
    return math.max(0, start + duration - observedAt)
end
local function captureCooldown(observed, action)
    local out = { applicable = false, known = true, remaining = 0 }
    if action.executor == "item" then
        out.applicable = true
        local inventory = XelAssist.Game.Inventory
        if not (inventory and inventory.Cooldown) then
            out.known, out.reason = false, "item cooldown API unavailable"
            return out
        end
        local ok, value = pcall(inventory.Cooldown, inventory, action)
        out.known, out.remaining = ok and value ~= nil, tonumber(value)
        if not out.known then out.reason = "item cooldown unknown" end
        return out
    end
    if action.actor == "pet" and action.executor == "petAbility" then
        out.applicable = true
        if not (GetPetActionCooldown and action.actionSlot) then
            out.known, out.reason = false, "pet cooldown API unavailable"
            return out
        end
        local ok, start, duration, enabled = pcall(
            GetPetActionCooldown, action.actionSlot)
        out.remaining = ok and enabled ~= 0
            and remaining(start, duration, observed.observedAt) or nil
        out.known = out.remaining ~= nil
        if not out.known then out.reason = "pet cooldown unknown" end
        return out
    end
    if action.actor ~= "pet" and action.executor == "playerSpell" then
        out.applicable = true
        if not (GetSpellCooldown and action.slot) then
            out.known, out.reason = false, "spell cooldown API unavailable"
            return out
        end
        local ok, start, duration = pcall(GetSpellCooldown, action.slot,
            action.bookType or BOOKTYPE_SPELL)
        out.remaining = ok and remaining(
            start, duration, observed.observedAt) or nil
        out.known = out.remaining ~= nil
        if not out.known then out.reason = "cooldown unknown" end
    end
    return out
end
local function captureUsability(observed, action)
    local out = { applicable = action.executor ~= "item" }
    if action.actor == "pet" then
        out.known, out.usable, out.reason = observed.petUsabilityKnown,
            observed.petUsable, observed.petUsabilityReason
        return out
    end
    if action.executor == "item" then
        out.known, out.usable = true, true
        return out
    end
    local capabilities = XelAssist.Game.Capabilities
    if not (capabilities and capabilities.Usable) then return out end
    local ok, usable, reason = pcall(capabilities.Usable, capabilities, action)
    out.known, out.usable, out.reason = ok and usable ~= nil,
        ok and usable or nil, ok and reason or "usability query failed"
    return out
end
local function capturePower(observed, action, facts)
    local owner = XelAssist.Game.RootPowerEvidence
    if owner then return owner:Capture(observed, action, facts, R:ActionKey(action)) end
    local out = { captured = true }
    if tonumber(facts.weaponCoefficient) ~= nil then
        local weapon = XelAssist.Game.WeaponPower
        local ok, basis, evidence
        if weapon and weapon.Basis then
            ok, basis, evidence = pcall(weapon.Basis, weapon, action, facts)
        else
            local capabilities = XelAssist.Game.Capabilities
            local fn = action.facts.ranged and facts.school == 0
                and capabilities.RangedDamage or capabilities.WeaponDamage
            ok, basis = pcall(fn, capabilities)
            evidence = { exact = false, gap = "weapon power model" }
        end
        out.weaponBasisCaptured, out.weaponBasis = true, ok and basis or nil
        out.weaponEvidence = ok and copy(evidence or {}, 5)
            or { exact = false, gap = "weapon power query failed" }
    end
    if facts.dbcAverage then
        local capabilities, value = XelAssist.Game.Capabilities, 0
        if action.facts.melee then
            local ok, found = pcall(capabilities.WeaponDamage, capabilities)
            value = ok and tonumber(found) or 0
        end
        if action.facts.ranged and facts.school == 0 then
            local ok, found = pcall(capabilities.RangedDamage, capabilities)
            if ok and found ~= nil then value = found end
        end
        out.dbcWeaponCaptured, out.dbcWeapon = true, tonumber(value) or 0
    end
    local kind = action.facts.kind
    if (kind == "damage" or kind == "dot") and action.actor ~= "pet" then
        local capabilities = XelAssist.Game.Capabilities
        local ok, value = pcall(capabilities.BonusDamage, capabilities, facts.school)
        out.bonusCaptured, out.bonusDamage = true,
            ok and math.max(0, tonumber(value) or 0) or 0
        out.bonusKnown = ok
    end
    observed.powerRecords[R:ActionKey(action)] = out
end
local function captureSetup(observed)
    observed.petUsabilityKnown = false
    if type(GetPetActionsUsable) == "function" then
        local ok, value = pcall(GetPetActionsUsable)
        if ok and (value == true or value == 1
            or value == false or value == 0) then
            observed.petUsabilityKnown = true
            observed.petUsable = value == true or value == 1
            if not observed.petUsable then observed.petUsabilityReason = "pet state" end
        end
    end
    observed.pendingKnown = XelAssist and XelAssist.IsAuraPending and true or false
    if observed.pendingKnown and XelAssist.SweepPendingAuras then
        local ok = pcall(XelAssist.SweepPendingAuras, XelAssist)
        if not ok then observed.pendingKnown = false end
    end
    observed.phase = "action"
end
local function captureFacts(action)
    local forms, actors, facts, known = XelAssist.Graph.DruidForms, XelAssist.Game.Actors, nil, nil
    if forms then facts, known = forms:CaptureFacts(action, actors)
    elseif actors and actors.Facts then
        known, facts = pcall(actors.Facts, actors, action)
        known = known and type(facts) == "table"
    end
    local stances = XelAssist.Graph.WarriorStances
    if facts and stances then facts = stances:CaptureFacts(action, facts) end
    if facts and XelAssist.Game.CrowdControl then facts = XelAssist.Game.CrowdControl:CaptureFacts(action, facts) end
    if facts and XelAssist.Graph.ClassMechanics then facts = XelAssist.Graph.ClassMechanics:CaptureFacts(action, facts) end
    return facts and copy(facts, 9) or nil, known
end
local function captureAction(observed, source)
    local action = copyAction(source)
    if XelAssist.Graph.ResistanceEvidence then XelAssist.Graph.ResistanceEvidence:Attach(action) end
    local key = R:ActionKey(action)
    local record = { key = key, action = action, recipients = {} }
    record.facts, record.factsKnown = captureFacts(action)
    record.usability = captureUsability(observed, action)
    record.cooldown = captureCooldown(observed, action)
    local reagent = action.facts and action.facts.reagentName
    if reagent then
        local counts = observed.state.inventory
            and observed.state.inventory.reagentCounts
        local count = counts and counts[reagent]
        record.reagent = { known = count ~= nil,
            available = count ~= nil and count > 0 or false }
        if count == nil and XelAssist.Game.Actors.HasReagent then
            local ok, available = pcall(XelAssist.Game.Actors.HasReagent,
                XelAssist.Game.Actors, reagent)
            record.reagent.known = ok and available ~= nil
            record.reagent.available = ok and available and true or false
        end
    end
    observed.actionRecords[key] = record
    table.insert(observed.actions, action)
    capturePower(observed, action, record.facts or {})
    local triggered = XelAssist.Combat and XelAssist.Combat.TriggeredActions
    if triggered and triggered.ResultAction and triggered.EffectFacts then
        local result = triggered:ResultAction(action)
        if result ~= action then
            local resistance = XelAssist.Graph.ResistanceEvidence
            if resistance then resistance:AttachResult(action, result) end
            if triggered.SealResultFacts then triggered:SealResultFacts(action, result) end
            local effectFacts = triggered:EffectFacts(action, record.facts or {})
            capturePower(observed, result, effectFacts or {})
        end
    end
    local selection = XelAssist.Graph.TargetSelection
    local ok, recipients = pcall(selection.Targets, selection, action, observed.state)
    observed.currentRecord, observed.currentAction = record, action
    observed.recipients = ok and recipients or {}
    observed.recipientIndex, observed.phase = 1, "recipient"
end
local function targetState(state, descriptor)
    if descriptor.relation ~= "hostile" or not state.hostiles then return state end
    local graphState = XelAssist.Graph.State
    if descriptor.source == "engaged" and descriptor.key ~= nil
        and graphState.HostileContext then
        return graphState:HostileContext(state, descriptor.key) or state
    end
    if state.targetContextKey ~= nil and graphState.SelectedHostileContext then
        return graphState:SelectedHostileContext(state) or state
    end
    return state
end
local function auraEvidence(observed, action, descriptor) local rootAuras = XelAssist.Game.RootAuraEvidence
    if rootAuras then return rootAuras:Capture(observed, action, descriptor) end
    local capabilities, fn, argument = XelAssist.Game.Capabilities, nil, nil
    if descriptor.relation ~= "hostile" then
        fn, argument = capabilities and capabilities.UnitHasBuff, descriptor.unit
    elseif descriptor.unit == "target" then
        fn, argument = capabilities and capabilities.TargetHasDebuff, action.name
    else return true, false end
    if not fn then return false, false end
    local ok, active
    if descriptor.relation ~= "hostile" then
        ok, active = pcall(fn, capabilities, argument, action.name)
    else ok, active = pcall(fn, capabilities, argument) end
    return ok, ok and active and true or false
end
local function pendingEvidence(observed, action, descriptor)
    if not observed.pendingKnown then return false, false end
    local facts = action.facts or {}
    local target = (facts.deferredUntilPetMelee or facts.petCombatBuff
        or facts.petCombatEffects) and (descriptor.castGuid or descriptor.guid)
        or descriptor.guid or descriptor.unit
    local ok, active = pcall(XelAssist.IsAuraPending, XelAssist,
        action.name, action.actor, target)
    return ok, ok and active and true or false
end
local function targetEvidence(observed, descriptor)
    local key = R:RecipientKey(descriptor)
    if key == nil then return nil end
    if observed.targetRecords[key] then return observed.targetRecords[key] end
    local out = { key = key, tapKnown = false, tapOwnerKnown = false }
    if descriptor.relation == "hostile" and type(UnitIsTapped) == "function" then
        local ok, tapped = pcall(UnitIsTapped, descriptor.unit)
        out.tapKnown, out.tapped = ok, ok and (tapped == true or tapped == 1)
        if ok and not out.tapped then
            out.tapOwnerKnown, out.tappedByPlayer = true, false
        elseif ok and type(UnitIsTappedByPlayer) == "function" then
            local ownerOk, ours = pcall(UnitIsTappedByPlayer, descriptor.unit)
            out.tapOwnerKnown = ownerOk
            out.tappedByPlayer = ownerOk and (ours == true or ours == 1)
        end
    end
    observed.targetRecords[key] = out
    return out
end
local function captureRecipient(observed, descriptor)
    local action, state = observed.currentAction,
        targetState(observed.state, descriptor)
    local record = { key = R:RecipientKey(descriptor) }
    record.targetEvidence = targetEvidence(observed, descriptor)
    record.auraKnown, record.auraActive = auraEvidence(observed, action, descriptor)
    record.pendingKnown, record.pending = pendingEvidence(observed, action, descriptor)
    if XelAssist.Graph.ClassMechanics then XelAssist.Graph.ClassMechanics:CaptureRecipient(observed, action, descriptor) end
    record.observationKnown = true
    if descriptor.relation == "hostile" and XelAssist.Combat.Observations
        and XelAssist.Combat.Observations.Blocker then
        local ok, blocker = pcall(XelAssist.Combat.Observations.Blocker,
            XelAssist.Combat.Observations, action, descriptor.unit)
        record.observationKnown, record.observationBlocker = ok, ok and blocker or nil
    end
    local spatial = XelAssist.Graph.SpatialRequirements
    if spatial and spatial.CaptureRoot then
        local ok, blocker = pcall(spatial.CaptureRoot, spatial, action, state,
            descriptor, descriptor.unit, observed.currentRecord.facts or {})
        record.rangeKnown, record.rangeBlocker = ok, ok and blocker or nil
    else record.rangeKnown = false end
    observed.currentRecord.recipients[record.key] = record
end
function R:Begin(state, actions, observedAt)
    if type(state) ~= "table" or type(actions) ~= "table" then return nil end
    local observed = { xelRootObservation = true, state = state,
        observedAt = tonumber(observedAt) or (type(GetTime) == "function"
            and tonumber(GetTime()) or 0) or 0,
        config = copy(XelAssistCharDB or {}, 9), actions = {},
        actionRecords = {}, powerRecords = {}, targetRecords = {},
        sourceActions = actions,
        actionIndex = 1, phase = "setup", sealed = false, complete = false }
    state.rootObservation = observed
    return observed
end
local function finishAction(observed)
    observed.actionIndex = observed.actionIndex + 1
    observed.currentRecord, observed.currentAction = nil, nil
    observed.recipients, observed.recipientIndex, observed.phase = nil, nil, "action"
end
function R:Step(observed)
    if type(observed) ~= "table" or not observed.xelRootObservation then
        return true, "invalid root observation"
    end
    if observed.sealed or observed.complete then return true end
    if observed.phase == "setup" then captureSetup(observed)
    elseif observed.phase == "action" then
        local source = observed.sourceActions[observed.actionIndex]
        if source then captureAction(observed, source)
        else observed.phase, observed.complete = "complete", true end
    elseif observed.phase == "recipient" then
        local descriptor = observed.recipients[observed.recipientIndex]
        if descriptor then
            captureRecipient(observed, descriptor)
            observed.recipientIndex = observed.recipientIndex + 1
        else finishAction(observed) end
    end
    return observed.complete and true or false
end
function R:Seal(observed)
    if type(observed) ~= "table" or not observed.xelRootObservation then
        return nil, "invalid root observation"
    end
    if not observed.complete then return nil, "root observation incomplete" end
    observed.sealed, observed.phase = true, "sealed"
    observed.sourceActions, observed.recipients = nil, nil
    observed.currentRecord, observed.currentAction = nil, nil
    observed.actionIndex, observed.recipientIndex = nil, nil
    observed.state.rootObservation = observed; observed.state = nil
    return observed
end
