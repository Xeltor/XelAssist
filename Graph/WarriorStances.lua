-- Exact Warrior stance transitions. Installed-client DBC identity discovers
-- actions without localized names; sealed root evidence makes future graph
-- nodes independent of mutable APIs and assigns no preferred stance.
XelAssist.Graph.WarriorStances = {}
local W = XelAssist.Graph.WarriorStances
local CLASSIFICATIONS = {}

W.RAGE = 1
W.WARRIOR_FAMILY = 4
W.STANCE_FAMILY_FLAG = 8388608
W.TACTICAL_MASTERY_TALENT_ID = 57
W.TACTICAL_MASTERY_TAB = 1
W.TACTICAL_MASTERY_INDEX = 2
W.TACTICAL_MASTERY_MAX_RANK = 5

W.FORMS = {
    [17] = { key = "battle", mask = 65536 },
    [18] = { key = "defensive", mask = 131072, tank = true },
    [19] = { key = "berserker", mask = 262144 },
}

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function integer(value, low, high)
    if type(value) ~= "number" or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function nonnegative(value)
    if type(value) ~= "number" or value < 0 then return nil end
    return value
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function playerExists()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    return ok and (exists == true or exists == 1)
end

local function dbcScalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and type(value) == "number" and value or nil
end

local function dbcArray(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(value) ~= "table" then return nil end
    local i
    for i = 1, 3 do
        if type(value[i]) ~= "number" then return nil end
    end
    return value
end

local function targetFormFrom(effects, auras, misc)
    if not (effects and auras and misc) then return nil end
    local found, i = nil, nil
    for i = 1, 3 do
        local formID = integer(misc[i], 17, 19)
        if effects[i] == 6 and auras[i] == 36 and W.FORMS[formID] then
            if found and found ~= formID then return nil, true end
            found = formID
        end
    end
    return found, found ~= nil
end

-- The three installed stance actions share this exact DBC topology:
-- Warrior SpellFamily flag, zero-cost rage power, and one self-targeted
-- SPELL_AURA_MOD_SHAPESHIFT effect to form 17, 18, or 19.
function W:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "stance spell ID unavailable", false end
    if CLASSIFICATIONS[spellId] then
        return shallow(CLASSIFICATIONS[spellId]), nil, true
    end
    local effects = dbcArray(spellId, "effect")
    local auras = dbcArray(spellId, "effectApplyAuraName")
    local misc = dbcArray(spellId, "effectMiscValue")
    local targetA = dbcArray(spellId, "effectImplicitTargetA")
    local targetB = dbcArray(spellId, "effectImplicitTargetB")
    local targetForm, recognized = targetFormFrom(effects, auras, misc)
    if not recognized then
        return nil, "spell is not an installed Warrior stance", false
    end
    local evidence = { recognized = true, valid = false,
        targetForm = targetForm,
        targetMask = targetForm and self.FORMS[targetForm].mask or nil,
        source = "installed-client Warrior stance DBC topology" }
    local valid = targetForm ~= nil
        and dbcScalar(spellId, "spellFamilyName") == self.WARRIOR_FAMILY
        and dbcScalar(spellId, "spellFamilyFlags")
            == self.STANCE_FAMILY_FLAG
        and dbcScalar(spellId, "powerType") == self.RAGE
        and dbcScalar(spellId, "manaCost") == 0
        and effects and effects[1] == 6
        and effects[2] == 0 and effects[3] == 0
        and auras and auras[1] == 36
        and auras[2] == 0 and auras[3] == 0
        and misc and misc[1] == targetForm
        and misc[2] == 0 and misc[3] == 0
        and targetA and targetA[1] == 1
        and targetA[2] == 0 and targetA[3] == 0
        and targetB and targetB[1] == 0
        and targetB[2] == 0 and targetB[3] == 0
    if not valid then
        evidence.reason = "Warrior stance DBC topology is incomplete"
        return evidence, evidence.reason, true
    end
    evidence.valid, evidence.cost, evidence.powerType = true, 0, self.RAGE
    CLASSIFICATIONS[spellId] = shallow(evidence)
    return shallow(evidence), nil, true
end

function W:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local evidence, reason, recognized = self:Classify(spellId)
    if not (evidence and evidence.valid == true) then
        return nil, reason, recognized
    end
    return { inferred = true, kind = "form", kindExact = true,
        self = true, fixedTarget = "player", resourceType = "rage",
        warriorStance = true, requiresExactUsability = true,
        warriorStanceEvidence = shallow(evidence),
        source = evidence.source }, nil, true
end

-- Capture occurs at the mutable root boundary. Later graph depths consume only
-- this copied evidence and never query DBC or talent APIs.
function W:CaptureFacts(action, facts)
    local out = shallow(facts)
    local evidence = facts and facts.warriorStanceEvidence
    if type(evidence) == "table" then
        evidence = shallow(evidence)
    elseif facts and facts.warriorStance == true then
        evidence = self:Classify(action and action.spellId)
    else
        -- RootObservation visits every known action. Ordinary actions must not
        -- pay five mutable DBC reads merely to prove that they are not stances.
        return out
    end
    if not evidence then return out end
    out.warriorStanceEvidence = shallow(evidence)
    if evidence.valid == true then
        out.cost, out.powerType = 0, self.RAGE
    end
    return out
end

function W:RetentionSnapshot()
    local out = { available = false, exact = false,
        talentID = self.TACTICAL_MASTERY_TALENT_ID,
        source = "ClassicAPI exact Talent.dbc identity and allocated rank" }
    if classToken() ~= "WARRIOR" or not playerExists() then
        out.reason = "Warrior player evidence unavailable"
        return out
    end
    if type(GetTalentIDByIndex) ~= "function"
        or type(GetTalentInfo) ~= "function" then
        out.reason = "Tactical Mastery identity or rank unavailable"
        return out
    end
    local okID, talentID = pcall(GetTalentIDByIndex,
        self.TACTICAL_MASTERY_TAB, self.TACTICAL_MASTERY_INDEX)
    talentID = okID and integer(talentID, 1, 4294967295) or nil
    if talentID ~= self.TACTICAL_MASTERY_TALENT_ID then
        out.reason = "Tactical Mastery identity mismatch"
        return out
    end
    local ok, _, _, _, _, rank, maximum = pcall(GetTalentInfo,
        self.TACTICAL_MASTERY_TAB, self.TACTICAL_MASTERY_INDEX)
    rank = ok and integer(rank, 0, self.TACTICAL_MASTERY_MAX_RANK) or nil
    maximum = ok and integer(maximum, 1,
        self.TACTICAL_MASTERY_MAX_RANK) or nil
    if rank == nil or maximum ~= self.TACTICAL_MASTERY_MAX_RANK then
        out.reason = "Tactical Mastery rank unavailable"
        return out
    end
    out.available, out.exact, out.rank = true, true, rank
    out.retainedRageCap, out.serverRawRageCap = rank * 5, rank * 50
    return out
end

function W:Attach(state)
    if classToken() ~= "WARRIOR" or not (state and state.playerForm
        and state.playerForm.available == true
        and self.FORMS[state.playerForm.formID]) then return false end
    state.playerForm.warriorRageRetention = self:RetentionSnapshot()
    return true
end

function W:Is(action, tooltip)
    local facts = action and action.facts or {}
    local evidence = tooltip and tooltip.warriorStanceEvidence
    return facts.warriorStance == true
        or evidence and evidence.recognized == true or false
end

local function exactState(state)
    if not (state and state.playerForm
        and state.playerForm.available == true
        and W.FORMS[state.playerForm.formID]) then
        return nil, nil, "Warrior stance state unavailable"
    end
    if state.resourceType ~= W.RAGE or state.playerResourceExact ~= true then
        return nil, nil, "Warrior rage state unavailable"
    end
    local current, maximum = nonnegative(state.resource),
        nonnegative(state.resourceMax)
    if current == nil or maximum == nil or current > maximum then
        return nil, nil, "Warrior rage state unavailable"
    end
    return current, maximum, nil
end

function W:Prepare(action, state, tooltip)
    if not self:Is(action, tooltip) then return tooltip, nil, false end
    local evidence = tooltip and tooltip.warriorStanceEvidence
    if not (evidence and evidence.recognized == true
        and evidence.valid == true and self.FORMS[evidence.targetForm]
        and evidence.targetMask == self.FORMS[evidence.targetForm].mask
        and evidence.cost == 0 and evidence.powerType == self.RAGE) then
        return nil, evidence and evidence.reason
            or "Warrior stance evidence unavailable", true
    end
    local current, _, reason = exactState(state)
    if current == nil then return nil, reason, true end
    local sourceForm, targetForm = state.playerForm.formID,
        evidence.targetForm
    if sourceForm == targetForm then
        return nil, "Warrior stance already active", true
    end
    local retention = state.playerForm.warriorRageRetention
    if not (retention and retention.available == true
        and retention.exact == true
        and retention.talentID == self.TACTICAL_MASTERY_TALENT_ID
        and integer(retention.rank, 0, self.TACTICAL_MASTERY_MAX_RANK)
        and retention.retainedRageCap == retention.rank * 5) then
        return nil, "Warrior stance rage retention unavailable", true
    end
    local cap = retention.retainedRageCap
    local prepared = shallow(tooltip)
    prepared.cost, prepared.powerType = 0, self.RAGE
    prepared.warriorStanceTransition = {
        kind = "warriorStance", sourceForm = sourceForm,
        targetForm = targetForm, targetMask = evidence.targetMask,
        retentionCap = cap, retentionExact = true,
        source = "exact DBC stance plus Tactical Mastery retention" }
    return prepared, nil, true
end

function W:PrepareLegal(action, state, tooltip)
    local prepared, reason, handled = self:Prepare(action, state, tooltip)
    if handled then return prepared, reason end
    return tooltip, nil
end

function W:Score(context)
    if not self:Is(context and context.action,
        context and context.tooltip) then return false end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "changes player stance"
    return true
end

local function invalidateThreat(state, targetForm)
    local prior = state and state.playerThreat
    if not (type(prior) == "table" and prior.formID ~= targetForm) then return end
    local projected = shallow(prior)
    projected.formID, projected.stance = targetForm, W.FORMS[targetForm].key
    projected.multiplier, projected.minimum, projected.maximum = nil, nil, nil
    projected.exact, projected.projected = false, true
    projected.source = "projected stance; threat profile requires recomputation"
    state.playerThreat = projected
end

function W:Apply(state, candidate)
    local transition = candidate and candidate.warriorStanceTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.warriorStanceTransition
    if not (transition and transition.kind == "warriorStance"
        and transition.retentionExact == true
        and self.FORMS[transition.sourceForm]
        and self.FORMS[transition.targetForm]
        and transition.sourceForm ~= transition.targetForm
        and transition.targetMask == self.FORMS[transition.targetForm].mask
        and integer(transition.retentionCap, 0,
            self.TACTICAL_MASTERY_MAX_RANK * 5)
        and state and state.playerForm
        and state.playerForm.available == true
        and state.playerForm.formID == transition.sourceForm) then return false end
    local current, maximum = exactState(state)
    if current == nil then return false end
    local retained = math.min(current, transition.retentionCap)
    state.resource, state.resourceMax = retained, maximum
    state.playerResourceExact = true
    state.playerResourceSource = "projected exact Warrior stance retention"
    state.playerForm.formID = transition.targetForm
    state.playerForm.projected = true
    state.playerForm.source = "projected exact Warrior stance transition"
    if state.role == "auto" then
        state.tank = self.FORMS[transition.targetForm].tank and true or false
    end
    local actor = state.actors and state.actors.player
    if actor then
        actor.resource, actor.resourceMax = retained, maximum
        actor.resourceType, actor.resourceExact = self.RAGE, true
    end
    invalidateThreat(state, transition.targetForm)
    local effects = XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorStanceEffects
    if effects then effects:Project(state, transition.targetForm) end
    return true
end
