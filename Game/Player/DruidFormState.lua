-- Exact local-player Druid form and explicit power-slot evidence.  Mana stays
-- observable while Cat or Bear power is primary; projected form changes never
-- invent Furor, retained rage, retained energy, or another server-side result.
XelAssist.Game.Player.DruidFormState = {}
local F = XelAssist.Game.Player.DruidFormState

F.MANA = 0
F.RAGE = 1
F.ENERGY = 3
F.MAX_SEMANTIC_ATOMS = 16

-- Stable SpellShapeshiftForm.dbc IDs exposed by ClassicAPI.  IDs 9 and 11 are
-- Turtle/Octo extensions; all other rows are the vanilla build-5875 meanings.
F.FORMS = {
    [0] = { name = "Caster", primary = 0 },
    [1] = { name = "Cat", primary = 3 },
    [2] = { name = "Tree", primary = 0 },
    [3] = { name = "Travel", primary = 0 },
    [4] = { name = "Aquatic", primary = 0 },
    [5] = { name = "Bear", primary = 1, tank = true },
    [8] = { name = "Dire Bear", primary = 1, tank = true },
    [9] = { name = "Tree of Life", primary = 0 },
    [11] = { name = "Swift Travel", primary = 0 },
    [31] = { name = "Moonkin", primary = 0 },
}

local POWER_SLOTS = { 0, 1, 3 }

local function nonnegative(value)
    value = tonumber(value)
    if value == nil or value < 0 then return nil end
    return value
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok then return nil end
    return token
end

local function playerExists()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    return ok and (exists == true or exists == 1)
end

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function F:Snapshot()
    local out = { available = false,
        source = "ClassicAPI explicit power slots and stable form ID" }
    if classToken() ~= "DRUID" then
        out.reason = "player is not an exactly identified Druid"
        return out
    end
    if not playerExists() or type(GetShapeshiftFormID) ~= "function"
        or type(UnitPowerType) ~= "function"
        or type(UnitPower) ~= "function"
        or type(UnitPowerMax) ~= "function" then
        out.reason = "Druid form resource observation unavailable"
        return out
    end

    local okForm, formID = pcall(GetShapeshiftFormID)
    local okPrimary, primary = pcall(UnitPowerType, "player")
    formID, primary = okForm and tonumber(formID) or nil,
        okPrimary and tonumber(primary) or nil
    local form = formID and self.FORMS[formID] or nil
    if not form then
        out.reason = "Druid form ID is unresolved"
        return out
    end
    if primary ~= form.primary then
        out.reason = "Druid form and primary power disagree"
        return out
    end

    local powers, i = {}, nil
    for i = 1, table.getn(POWER_SLOTS) do
        local powerType = POWER_SLOTS[i]
        local okCurrent, current = pcall(UnitPower, "player", powerType)
        local okMax, maximum = pcall(UnitPowerMax, "player", powerType)
        current = okCurrent and nonnegative(current) or nil
        maximum = okMax and nonnegative(maximum) or nil
        if current == nil or maximum == nil or current > maximum then
            out.reason = "Druid power slot observation unavailable"
            return out
        end
        powers[powerType] = { type = powerType, current = current,
            maximum = maximum, currentKnown = true, maximumKnown = true,
            source = "ClassicAPI UnitPower explicit slot" }
    end
    if powers[self.MANA].maximum <= 0
        or powers[primary].maximum <= 0 then
        out.reason = "Druid active or hidden mana capacity unavailable"
        return out
    end

    out.available, out.formID, out.formName = true, formID, form.name
    out.primaryType, out.powers = primary, powers
    return out
end

local function shapeshiftAtom(descriptor)
    local atoms = descriptor and descriptor.atoms or {}
    local found, saw, i = nil, false, nil
    for i = 1, table.getn(atoms) do
        local atom = atoms[i]
        if atom and atom.kind == "shapeshift" then
            saw = true
            local formID = tonumber(atom.form)
            if not formID or not F.FORMS[formID] then
                return nil, "shapeshift destination form is unresolved", true
            end
            if found and found ~= formID then
                return nil, "shapeshift spell has conflicting forms", true
            end
            found = formID
        end
    end
    if not found then return nil, "spell is not an exact shapeshift", saw end
    return found, nil, true
end

function F:Semantic(action)
    local semantics = XelAssist.Game and XelAssist.Game.SpellSemantics
    if not (action and tonumber(action.spellId) and semantics
        and type(semantics.Resolve) == "function") then
        return nil, "shapeshift spell semantics unavailable", nil
    end
    local ok, descriptor = pcall(
        semantics.Resolve, semantics, tonumber(action.spellId))
    if not ok or type(descriptor) ~= "table" then
        return nil, "shapeshift spell semantics unavailable", nil
    end
    local atoms = descriptor.atoms or {}
    if table.getn(atoms) > self.MAX_SEMANTIC_ATOMS then
        return nil, "shapeshift semantic budget exceeded", descriptor
    end
    local formID, reason = shapeshiftAtom(descriptor)
    if not formID then return nil, reason, descriptor end
    if descriptor.complete ~= true or descriptor.admissible == false then
        return nil, "shapeshift semantics are incomplete", descriptor
    end
    return formID, nil, descriptor
end

-- Action discovery is driven only by an exact installed-client shapeshift
-- atom. The localized spell name never participates in classification.
function F:InferKnowledge(spellId)
    if classToken() ~= "DRUID" then return nil end
    local formID = self:Semantic({ spellId = spellId })
    if not formID then return nil end
    return { inferred = true, kind = "form", self = true,
        resourceType = "mana", druidShapeshift = true }
end

function F:AddSyntheticActions(actions)
    if type(actions) ~= "table" or classToken() ~= "DRUID"
        or type(CancelShapeshiftForm) ~= "function" then return false end
    table.insert(actions, { name = "Cancel Form", rank = 1, rankText = "",
        actor = "player", executor = "playerFormCancel",
        facts = { kind = "form", self = true, gcd = 0,
            druidFormCancel = true, requiresExactUsability = true } })
    return true
end

function F:EffectiveCost(action)
    if not (action and tonumber(action.spellId) and C_Spell
        and type(C_Spell.GetSpellPowerCost) == "function") then
        return nil, "effective shapeshift cost unavailable"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost,
        tonumber(action.spellId))
    if not ok or type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then
        return nil, "effective shapeshift cost unavailable"
    end
    local entry, cost = costs[1], nonnegative(costs[1].cost)
    if tonumber(entry.type) ~= self.MANA then
        return nil, "shapeshift is not exactly mana funded"
    end
    if cost == nil then return nil, "effective shapeshift cost unavailable" end
    return { type = self.MANA, cost = cost,
        source = "ClassicAPI effective engine spell cost" }, nil
end

-- Captured once at the mutable root boundary and copied into sealed tooltip
-- facts.  Unknown non-form spells remain untouched; a malformed spell that did
-- expose a shapeshift atom remains recognized but invalid so it fails closed.
function F:CaptureFacts(action, facts)
    local out = shallow(facts)
    local targetForm, semanticReason, descriptor = self:Semantic(action)
    local _, atomReason, sawShapeshift
    if not targetForm and descriptor then
        _, atomReason, sawShapeshift = shapeshiftAtom(descriptor)
    end
    if not targetForm and not sawShapeshift then return out end
    local evidence = { recognized = true, valid = false,
        targetForm = targetForm,
        semanticsComplete = descriptor and descriptor.complete == true
            and descriptor.admissible ~= false or false,
        source = "installed-client shapeshift atom" }
    if not targetForm then
        evidence.reason = semanticReason or atomReason
        out.druidFormEvidence = evidence
        return out
    end
    local cost, reason = self:EffectiveCost(action)
    if not cost then
        evidence.reason = reason
        out.druidFormEvidence = evidence
        return out
    end
    evidence.valid, evidence.cost = true, cost
    out.druidFormEvidence = evidence
    return out
end

function F:CancelFacts()
    return { cost = 0, cast = 0, gcd = 0, normalGcd = false,
        source = "ClassicAPI exact shapeshift cancellation" }
end

function F:CancelUsable()
    if type(CancelShapeshiftForm) ~= "function" then
        return false, "shapeshift cancellation unavailable"
    end
    local snapshot = self:Snapshot()
    if not (snapshot and snapshot.available == true) then
        return nil, "Druid form state unavailable"
    end
    if snapshot.formID == 0 then return false, "already in caster form" end
    return true, nil
end

local function exactMana(snapshot)
    return snapshot and snapshot.available == true and snapshot.powers
        and snapshot.powers[F.MANA]
        and snapshot.powers[F.MANA].currentKnown == true
        and snapshot.powers[F.MANA].maximumKnown == true
end

function F:PrepareShift(action, snapshot, evidence)
    if not exactMana(snapshot) then
        return nil, "Druid form state unavailable"
    end
    if evidence == nil then
        local facts = self:CaptureFacts(action, {})
        evidence = facts.druidFormEvidence
    end
    if not (evidence and evidence.recognized) then
        return nil, "spell is not an exact shapeshift"
    end
    if evidence.valid ~= true then
        return nil, evidence.reason or "shapeshift evidence unavailable"
    end
    local targetForm = tonumber(evidence.targetForm)
    if not targetForm or not self.FORMS[targetForm] then
        return nil, "shapeshift destination form is unresolved"
    end
    if targetForm == snapshot.formID then return nil, "form already active" end
    local cost = evidence.cost
    if not (cost and cost.type == self.MANA
        and nonnegative(cost.cost)) then
        return nil, "effective shapeshift cost unavailable"
    end
    if snapshot.powers[self.MANA].current < cost.cost then
        return nil, "hidden mana insufficient"
    end
    local primary = self.FORMS[targetForm].primary
    return { kind = "shift", spellId = action and action.spellId,
        sourceForm = snapshot.formID, targetForm = targetForm,
        targetPrimary = primary, cost = shallow(cost),
        semanticsComplete = evidence.semanticsComplete == true,
        destinationPowerKnown = primary == self.MANA,
        destinationPowerReason = primary ~= self.MANA
            and "server transition and Furor outcome require observation" or nil,
        source = "exact form atom plus live effective mana cost" }, nil
end

function F:PrepareCancel(snapshot)
    if not exactMana(snapshot) then
        return nil, "Druid form state unavailable"
    end
    if snapshot.formID == 0 then return nil, "already in caster form" end
    if type(CancelShapeshiftForm) ~= "function" then
        return nil, "shapeshift cancellation unavailable"
    end
    return { kind = "cancel", sourceForm = snapshot.formID,
        targetForm = 0, targetPrimary = self.MANA, cost = {
            type = self.MANA, cost = 0,
            source = "ClassicAPI cancellation has no spell cost" },
        semanticsComplete = true, destinationPowerKnown = true,
        source = "ClassicAPI exact shapeshift cancellation" }, nil
end

local function projectionValid(snapshot, projection)
    return exactMana(snapshot) and projection
        and snapshot.formID == projection.sourceForm
        and F.FORMS[projection.targetForm]
        and projection.targetPrimary == F.FORMS[projection.targetForm].primary
        and projection.cost and projection.cost.type == F.MANA
        and nonnegative(projection.cost.cost) ~= nil
end

function F:Spend(snapshot, projection)
    if not projectionValid(snapshot, projection) then return false end
    local mana = snapshot.powers[self.MANA]
    if mana.current < projection.cost.cost then return false end
    mana.current = mana.current - projection.cost.cost
    snapshot.lastFormCost = projection.cost.cost
    return true
end

function F:Apply(snapshot, projection, costPaid)
    if not projectionValid(snapshot, projection) then return false end
    if not costPaid and not self:Spend(snapshot, projection) then return false end
    snapshot.formID = projection.targetForm
    snapshot.formName = self.FORMS[projection.targetForm].name
    snapshot.primaryType = projection.targetPrimary
    local destination = snapshot.powers[projection.targetPrimary]
    if projection.destinationPowerKnown == true then
        destination.currentKnown, destination.maximumKnown = true, true
        destination.reason = nil
    else
        destination.priorObservedCurrent = destination.current
        destination.priorObservedMaximum = destination.maximum
        destination.current, destination.maximum = nil, nil
        destination.currentKnown, destination.maximumKnown = false, false
        destination.reason = projection.destinationPowerReason
    end
    snapshot.projected = true
    return true
end

-- Dispatch re-observes the exact stable form immediately before the client
-- mutation, so an old recommendation cannot cancel a newly changed form.
function F:DispatchCancel(plan)
    local action = plan and plan.action
    local projection = plan and plan.druidFormTransition
    if not (action and action.facts and action.facts.druidFormCancel
        and projection and projection.kind == "cancel"
        and projection.targetForm == 0) then
        return false, "cancel-form plan evidence unavailable"
    end
    local snapshot = self:Snapshot()
    if not (snapshot and snapshot.available == true) then
        return false, "Druid form state unavailable"
    end
    if snapshot.formID ~= projection.sourceForm or snapshot.formID == 0 then
        return false, "Druid form changed"
    end
    if type(CancelShapeshiftForm) ~= "function" then
        return false, "shapeshift cancellation unavailable"
    end
    local ok = pcall(CancelShapeshiftForm)
    if not ok then return false, "shapeshift cancellation failed" end
    return true, nil
end
