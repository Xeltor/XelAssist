-- Search-pure Shadowform transition and consequences. The action has no typed
-- priority or fabricated immediate utility: a branch earns value only through
-- later exact Shadow damage, form legality, or physical incoming damage.
XelAssist.Graph.PriestShadowform = {}
local S = XelAssist.Graph.PriestShadowform

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

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PriestShadowform
end

local function clearProfile(state)
    state.playerShadowformProfileExact = false
    state.playerShadowformFormID = nil
    state.playerShadowDamageMultiplier = nil
    state.playerPhysicalDamageTakenMultiplier = nil
    state.playerShadowformProfileSource = nil
end

local function attachProfile(state, found, formID, projected)
    if not (state and found and found.exact == true
        and integer(formID, 0, 32) ~= nil) then return false end
    local active = formID == found.formID
    state.playerShadowformProfileExact = true
    state.playerShadowformFormID = formID
    state.playerShadowDamageMultiplier = active
        and found.shadowDamageMultiplier or 1
    state.playerPhysicalDamageTakenMultiplier = active
        and found.physicalDamageTakenMultiplier or 1
    state.playerShadowformProfileSource = projected
        and "projected exact Shadowform transition" or found.source
    return true
end

local function profile(state, activeOnly)
    local form = state and state.playerForm
    local formID = form and integer(form.formID, 0, 32)
    local shadow = finite(state and state.playerShadowDamageMultiplier)
    local physical = finite(state and state.playerPhysicalDamageTakenMultiplier)
    if not (form and form.available == true
        and state.playerShadowformProfileExact == true
        and state.playerShadowformFormID == formID
        and shadow and physical and shadow > 0 and physical > 0) then
        return nil
    end
    local owner = runtime()
    if activeOnly and (not owner or formID ~= owner.FORM_ID) then return nil end
    return { formID = formID, shadow = shadow, physical = physical }
end

function S:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    clearProfile(state)
    local owner = runtime()
    local found = owner and owner:Snapshot(knownClass) or nil
    local form = state.playerForm
    if not (found and found.valid == true and found.exact == true
        and form and form.available == true) then return false end
    return attachProfile(state, found, form.formID, false)
end

function S:Copy(source, target)
    if not (source and target) then return false end
    target.playerShadowformProfileExact = source.playerShadowformProfileExact
    target.playerShadowformFormID = source.playerShadowformFormID
    target.playerShadowDamageMultiplier = source.playerShadowDamageMultiplier
    target.playerPhysicalDamageTakenMultiplier =
        source.playerPhysicalDamageTakenMultiplier
    target.playerShadowformProfileSource = source.playerShadowformProfileSource
    return source.playerShadowformProfileExact == true
end

function S:Is(action, tooltip)
    local owner = runtime()
    return owner and (owner:Is(action) or owner:Is(tooltip)) or false
end

function S:Prepare(action, state, tooltip)
    if not self:Is(action, tooltip) then return tooltip, nil, false end
    local owner = runtime()
    local found, reason = owner:CapturedEvidence(tooltip)
    if not found then
        return nil, reason or "Shadowform root evidence unavailable", true
    end
    local current = profile(state, false)
    if not current then return nil, "Priest form profile unavailable", true end
    if current.formID == owner.FORM_ID then
        return nil, "Shadowform already active", true
    end
    if current.formID ~= 0 then
        return nil, "another Priest form is active", true
    end
    local mana = finite(state.resource)
    if tonumber(state.resourceType) ~= owner.MANA
        or state.playerResourceExact ~= true
        or mana == nil then
        return nil, "Priest mana state unavailable", true
    end
    local cost = finite(found.effectiveCost)
    if not cost or cost < 0 then
        return nil, "Shadowform effective mana cost unavailable", true
    end
    if mana < cost then return nil, "resource", true end
    local prepared = copy(tooltip)
    prepared.cost, prepared.powerType = cost, owner.MANA
    prepared.priestShadowformTransition = {
        kind = "priestShadowform", sourceForm = current.formID,
        targetForm = found.formID, targetMask = found.formMask,
        shadowSchool = found.shadowSchool,
        shadowDamageMultiplier = found.shadowDamageMultiplier,
        physicalSchool = found.physicalSchool,
        physicalDamageTakenMultiplier = found.physicalDamageTakenMultiplier,
        evidenceExact = true, source = found.source }
    return prepared, nil, true
end

function S:PrepareLegal(action, state, tooltip)
    local prepared, reason, handled = self:Prepare(action, state, tooltip)
    if handled then return prepared, reason end
    return tooltip, nil
end

function S:Score(context)
    local transition = context and context.tooltip
        and context.tooltip.priestShadowformTransition
    if not (transition and transition.kind == "priestShadowform"
        and transition.evidenceExact == true) then return false end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "changes player form"
    return true
end

function S:Apply(state, candidate)
    local transition = candidate and candidate.priestShadowformTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.priestShadowformTransition
    local owner = runtime()
    if not (owner and transition
        and transition.kind == "priestShadowform"
        and transition.evidenceExact == true
        and transition.sourceForm == 0
        and transition.targetForm == owner.FORM_ID
        and transition.targetMask == owner.FORM_MASK
        and transition.shadowSchool == owner.SHADOW_SCHOOL
        and transition.shadowDamageMultiplier == 1.15
        and transition.physicalSchool == owner.PHYSICAL_SCHOOL
        and transition.physicalDamageTakenMultiplier == 0.85
        and state and state.playerForm
        and state.playerForm.available == true
        and state.playerForm.formID == transition.sourceForm
        and profile(state, false)) then return false end
    state.playerForm.formID = transition.targetForm
    state.playerForm.projected = true
    state.playerForm.source = "projected exact Shadowform transition"
    local found = { exact = true, formID = transition.targetForm,
        shadowDamageMultiplier = transition.shadowDamageMultiplier,
        physicalDamageTakenMultiplier =
            transition.physicalDamageTakenMultiplier,
        source = transition.source }
    return attachProfile(state, found, transition.targetForm, true)
end

-- Call before target resistance and periodic splitting so every direct,
-- periodic, and channeled Shadow component receives the same exact aura factor.
function S:AdjustDamage(context)
    local current = profile(context and context.state, true)
    if not current then return false end
    local action = context.effectAction or context.action or {}
    if action.actor ~= nil and action.actor ~= "player" then return false end
    local kind = context.kind
    if kind ~= "damage" and kind ~= "dot" and kind ~= "builder" then
        return false
    end
    local tooltip = context.effectTooltip or context.tooltip or {}
    local owner = runtime()
    if not owner or integer(tooltip.school, 0, 6) ~= owner.SHADOW_SCHOOL then
        return false
    end
    local power, expected = finite(context.power), finite(context.expectedPower)
    if not power or not expected then return false end
    context.power = power * current.shadow
    context.expectedPower = expected * current.shadow
    context.shadowformDamageMultiplier = current.shadow
    return true
end

-- Returns multiplier, whether active Shadowform owned the question, and a
-- reason when the school was too incomplete to claim mitigation.
function S:IncomingMultiplier(state, recipient, school)
    local current = profile(state, true)
    if not current or not (recipient and recipient.kind == "player") then
        return nil, false
    end
    local owner = runtime()
    school = integer(school, 0, 6)
    if not owner or school == nil then
        return nil, true, "incoming damage school unavailable"
    end
    if school == owner.PHYSICAL_SCHOOL then return current.physical, true end
    return 1, true
end

function S:AdjustIncoming(state, recipient, amount, school)
    amount = finite(amount)
    if not amount or amount < 0 then
        return nil, "incoming damage amount unavailable", true
    end
    local multiplier, handled, reason = self:IncomingMultiplier(
        state, recipient, school)
    if not handled then return amount, nil, false end
    if not multiplier then return nil, reason, true end
    return amount * multiplier, nil, true
end
