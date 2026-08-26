-- Name-independent Paladin action discovery from exact SpellFamily evidence.
-- These facts describe recipients and lifecycle mechanics only. Classification
-- never assigns damage, healing, threat, utility, or a preferred action order.
XelAssist.Game.Player.PaladinActions = {}
local P = XelAssist.Game.Player.PaladinActions
local AuraState = XelAssist.Game.Player.PaladinAuraState

P.LIFECYCLE_ONLY = "lifecycleOnly"
P.REQUIRES_EXACT_DOWNSTREAM = "requiresExactDownstream"
P.UNREPRESENTED = "unrepresented"
P.MAX_CACHE = 256

local CACHE, CACHE_COUNT = {}, 0

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function exactSpellId(value)
    value = tonumber(value)
    if value == nil or value < 1 or value > 4294967295
        or math.floor(value) ~= value then return nil end
    return value
end

local function classification(spellId)
    spellId = exactSpellId(spellId)
    if not spellId or not (AuraState
        and type(AuraState.Classify) == "function") then
        return nil, "Paladin action family evidence unavailable"
    end
    if CACHE[spellId] then
        local found = CACHE[spellId]
        return found, nil, found.family == AuraState.PALADIN_FAMILY
            and found.kind ~= "other"
    end
    local ok, found, reason, recognized = pcall(
        AuraState.Classify, AuraState, spellId)
    if not ok or type(found) ~= "table" then
        return nil, reason or "Paladin action family evidence unavailable",
            ok and recognized == true
    end
    if CACHE_COUNT < P.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = found, CACHE_COUNT + 1
    end
    return found, nil, recognized == true
end

local function sealedClassification(found)
    return { kind = found.kind, spellId = found.spellId,
        family = found.family, flags = found.flags,
        lowFlags = found.lowFlags, fullFlags = found.fullFlags,
        exclusiveFamily = found.exclusiveFamily,
        recipientRelation = found.recipientRelation,
        exact = found.exact, source = found.source }
end

local function base(found, representation, lifecycle)
    return { inferred = true, kindExact = true,
        recipientRelationExact = true, exclusiveFamilyExact = true,
        paladinAction = true, paladinAuraKind = found.kind,
        recipientRelation = found.recipientRelation,
        exclusiveFamily = found.exclusiveFamily,
        paladinRepresentationExact = true,
        paladinRepresentation = representation,
        paladinLifecycleRepresented = lifecycle and true or false,
        paladinEffectRepresented = false,
        paladinClassification = sealedClassification(found),
        requiresPaladinAuraProjection = true,
        source = "exact Paladin SpellFamily action classification" }
end

local function sealFacts(found)
    local facts = base(found, P.LIFECYCLE_ONLY, true)
    facts.kind, facts.self, facts.fixedTarget = "buff", true, "player"
    facts.paladinAura, facts.paladinSeal = true, true
    facts.paladinLifecycleOnly = true
    return facts
end

local function blessingFacts(found)
    local facts = base(found, P.LIFECYCLE_ONLY, true)
    facts.kind, facts.paladinAura = "buff", true
    facts.paladinBlessing, facts.paladinLifecycleOnly = true, true
    return facts
end

local function judgementFacts(found)
    local facts = base(found, P.REQUIRES_EXACT_DOWNSTREAM, false)
    facts.kind, facts.hostile = "judgement", true
    facts.paladinJudgement = true
    facts.requiresExactPaladinDownstreamOutcome = true
    return facts
end

local function righteousFuryFacts(found)
    local facts = base(found, P.UNREPRESENTED, false)
    facts.kind, facts.self, facts.fixedTarget = "buff", true, "player"
    facts.paladinAura, facts.paladinRighteousFury = true, true
    return facts
end

-- Third return only claims an exact exclusive-aura/Judgement/Righteous Fury
-- identity, including conflicting flags that must fail closed. Other Paladin
-- family members remain available to normal typed or tooltip discovery.
function P:InferKnowledge(spellId)
    if classToken() ~= "PALADIN" then
        return nil, "player is not an exactly identified Paladin", false
    end
    local found, reason, recognized = classification(spellId)
    if not found then return nil, reason, recognized == true end
    if found.kind == "seal" then return sealFacts(found), nil, true end
    if found.kind == "blessing" then
        return blessingFacts(found), nil, true
    end
    if found.kind == "judgement" then
        return judgementFacts(found), nil, true
    end
    if found.kind == "righteousFury" then
        return righteousFuryFacts(found), nil, true
    end
    return nil, "spell is not an exact Paladin action", false
end

-- Missing or false is deliberately equivalent: only a later exact downstream
-- resolver may promote an action or candidate to represented=true.
function P:EffectsRepresented(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    return type(facts) == "table"
        and facts.paladinEffectRepresented == true or false
end

function P:Representation(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    if not (type(facts) == "table"
        and facts.paladinRepresentationExact == true) then
        return nil, false
    end
    return facts.paladinRepresentation, self:EffectsRepresented(facts)
end

function P:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
