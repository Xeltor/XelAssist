-- Search-pure Righteous Fury lifecycle and Holy-threat consequence. The edge
-- receives no role bonus: its value can emerge only through later projected
-- Holy threat under the graph's existing tank/non-tank policy.
XelAssist.Graph.PaladinRighteousFury = {}
local R = XelAssist.Graph.PaladinRighteousFury

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PaladinRighteousFury
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function exactProfile(value)
    local owner = runtime()
    local flat, percent = value and finite(value.modifierFlat, -10000, 10000),
        value and finite(value.modifierPercent, -100, 10000)
    local expected = flat and percent
        and (owner.BASE_PERCENT + flat) * (100 + percent) / 100 or nil
    return owner and type(value) == "table" and value.available == true
        and value.valid == true and value.exact == true
        and value.portfolio == "paladinRighteousFury"
        and value.spellId == owner.SPELL_ID
        and value.family == owner.PALADIN_FAMILY
        and value.familyFlag == owner.FAMILY_FLAG
        and value.school == owner.HOLY_SCHOOL
        and value.schoolMask == owner.HOLY_MASK
        and value.basePercent == owner.BASE_PERCENT
        and expected and value.effectivePercent == expected
        and value.multiplier == (100 + expected) / 100 and value or nil
end

local function exactEffect(value)
    local owner = runtime()
    local multiplier = value and finite(value.multiplier, 1.000001, 101)
    return owner and type(value) == "table" and value.exact == true
        and value.kind == "schoolThreatMultiplier"
        and value.actor == "player" and value.sourceSpellId == owner.SPELL_ID
        and value.school == owner.HOLY_SCHOOL
        and value.schoolMask == owner.HOLY_MASK
        and value.recipient == "self"
        and finite(value.percent, 0.0001, 10000)
        and multiplier == (100 + value.percent) / 100 and value or nil
end

local function rootPlayer(state)
    local root = state and state.paladinAuraState
    local player = root and root.player
    if not (root and root.available == true and player
        and player.available == true and player == root.byKey[root.playerKey]
        and validGUID(root.playerGUID) and player.guid == root.playerGUID
        and player.playerGUID == root.playerGUID
        and player.recipientRelation == "self") then return nil, nil end
    return root, player
end

local function exactComponent(state)
    local component = state and state.paladinRighteousFury
    local profile = component and exactProfile(component.profile)
    if not (component and component.available == true
        and component.exact == true and profile
        and (component.active == true or component.active == false)) then
        return nil
    end
    local expected = component.active and profile.multiplier or 1
    if component.multiplier ~= expected then return nil end
    return component
end

function R:Attach(state)
    if type(state) ~= "table" then return false end
    local owner, root, player = runtime(), rootPlayer(state)
    local profile = owner and owner:Snapshot() or nil
    local out = { available = false, exact = false, active = false,
        multiplier = 1, profile = profile and copy(profile) or nil,
        source = "exact Paladin self aura plus root-captured threat profile" }
    state.paladinRighteousFury = out
    if not root then
        out.reason = "Paladin self-aura state unavailable"
        return false
    end
    if not exactProfile(profile) then
        out.reason = profile and profile.reason
            or "Righteous Fury threat profile unavailable"
        return false
    end
    local aura = player.righteousFury
    if aura and not (tonumber(aura.spellId) == owner.SPELL_ID
        and aura.exact == true and type(aura.classification) == "table"
        and aura.classification.exact == true
        and aura.classification.kind == "righteousFury"
        and aura.sourceGUID == root.playerGUID
        and aura.recipientGUID == root.playerGUID) then
        out.reason = "active Righteous Fury identity is incoherent"
        return false
    end
    out.available, out.exact, out.active = true, true, aura ~= nil
    out.multiplier = out.active and profile.multiplier or 1
    out.activeSpellId = out.active and aura.spellId or nil
    return true
end

function R:Copy(source, target)
    if not (source and target and source.paladinRighteousFury) then return false end
    target.paladinRighteousFury = copy(source.paladinRighteousFury)
    return exactComponent(target) ~= nil
end

local function exactSelf(state, descriptor)
    local root, player = rootPlayer(state)
    local friendlies = state and state.friendlies
    local record = root and friendlies and friendlies.byKey
        and friendlies.byKey[root.playerKey]
    if not (root and descriptor and descriptor.unit == "player"
        and descriptor.relation == "self"
        and descriptor.key == root.playerKey
        and descriptor.guid == root.playerGUID
        and record and record.unit == "player" and record.relation == "self"
        and record.guid == root.playerGUID
        and (descriptor.record == nil or descriptor.record == record)) then
        return nil, nil
    end
    return root, player
end

function R:Prepare(action, state, descriptor, suppliedEffect)
    local owner = runtime()
    local facts = action and action.facts or {}
    if not (owner and facts.paladinRighteousFury == true) then
        return nil, nil, false
    end
    local root, player = exactSelf(state, descriptor)
    if not root then
        return nil, "Righteous Fury requires exact self recipient", true
    end
    local component = exactComponent(state)
    if not component then
        return nil, state and state.paladinRighteousFury
            and state.paladinRighteousFury.reason
            or "Righteous Fury threat component unavailable", true
    end
    if component.active or player.righteousFury then
        return nil, "Righteous Fury is already active", true
    end
    local effect = exactEffect(suppliedEffect)
        or exactEffect(owner:CapturedEffect(facts))
    local profile = exactProfile(facts.paladinRighteousFuryProfile)
    if not (effect and profile and effect.multiplier == profile.multiplier
        and profile.multiplier == component.profile.multiplier
        and facts.paladinEffectRepresented == true
        and facts.paladinLifecycleRepresented == true) then
        return nil, "captured Righteous Fury consequence unavailable", true
    end
    return { kind = "righteousFury", classMechanic = "paladin",
        action = action, actionSpellId = owner.SPELL_ID,
        recipientKey = root.playerKey, recipientGUID = root.playerGUID,
        casterGUID = root.playerGUID, classification = facts.paladinClassification,
        effect = copy(effect), profile = copy(profile),
        paladinRighteousFury = true,
        source = "exact self Righteous Fury Holy-threat projection" }, nil, true
end

function R:Blocker(action, state, descriptor, suppliedEffect)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, suppliedEffect)
    if not handled then return nil, false end
    if not projection then return reason, true, nil end
    return nil, true, projection
end

function R:Score(context, projection)
    local effect = projection and exactEffect(projection.effect)
    local component = exactComponent(context and context.state)
    if not (projection and projection.paladinRighteousFury == true
        and effect and component and component.active == false) then
        return false, "Righteous Fury projection unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.reason = "changes projected Holy threat"
    return true
end

function R:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
        or candidate and candidate.paladinRighteousFuryProjection or candidate
    if not (projection and projection.paladinRighteousFury == true) then
        return false
    end
    local root, player = rootPlayer(state)
    local component = exactComponent(state)
    local effect, profile = exactEffect(projection.effect),
        exactProfile(projection.profile)
    if not (root and player and component and component.active == false
        and player.righteousFury == nil and effect and profile
        and effect.multiplier == profile.multiplier
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID
        and projection.casterGUID == root.playerGUID
        and projection.actionSpellId == runtime().SPELL_ID
        and projection.action and tonumber(projection.action.spellId)
            == runtime().SPELL_ID) then return false end
    player.righteousFury = { spellId = runtime().SPELL_ID,
        name = projection.action.name, sourceGUID = root.playerGUID,
        recipientGUID = root.playerGUID, recipientRelation = "self",
        classification = copy(projection.classification),
        projected = true, exact = true }
    component.active, component.projected = true, true
    component.activeSpellId = runtime().SPELL_ID
    component.multiplier, component.profile = profile.multiplier, copy(profile)
    return true
end

-- PlayerThreat should pass the exact 0..6 school index. Unknown school does
-- not receive the bonus and marks the composed result inexact.
function R:Resolve(state, actor, school, baseMultiplier, baseExact)
    baseMultiplier = finite(baseMultiplier, 0, 1000000)
    if actor ~= "player" or not baseMultiplier then
        return baseMultiplier, baseExact ~= false
    end
    local component = state and state.paladinRighteousFury
    if component == nil then return baseMultiplier, baseExact ~= false end
    component = exactComponent(state)
    if not component then return baseMultiplier, false,
        state.paladinRighteousFury end
    if component.active ~= true then
        return baseMultiplier, baseExact ~= false, component
    end
    school = integer(school, 0, 6)
    if school == nil then return baseMultiplier, false, component end
    local owner = runtime()
    local multiplier = school == owner.HOLY_SCHOOL
        and component.multiplier or 1
    return baseMultiplier * multiplier, baseExact ~= false, component
end
