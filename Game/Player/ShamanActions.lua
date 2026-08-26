-- Name-independent Shaman totem discovery from installed spell semantics.
-- Discovery seals immutable slot and lifetime facts before graph search. It
-- deliberately does not infer a totem's pulse/effect, radius, recipients,
-- damage, healing, threat, utility, or preferred ordering.
--
-- Integration contract:
--   * Call InferKnowledge while building the root spell index, never during
--     graph search. Search may consume Lifecycle, which reads sealed facts only.
--   * Use TotemState to project exact current-slot replacement and expiry.
--   * Do not admit or score the action until an exact downstream resolver has
--     set effect, range, and recipient representation to true and the central
--     graph implements the resolved effect kind. Missing evidence fails closed.
XelAssist.Game.Player.ShamanActions = {}
local S = XelAssist.Game.Player.ShamanActions
local TotemState = XelAssist.Game.Player.TotemState

S.LIFECYCLE_ONLY = "lifecycleOnly"
S.MAX_CACHE = 256

local CACHE, CACHE_COUNT = {}, 0

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function integer(value, low, high)
    value = tonumber(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function finitePositive(value)
    value = tonumber(value)
    if value == nil or value ~= value or value <= 0
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function slotFromType(value)
    if type(value) ~= "string" then return nil end
    local _, _, digit = string.find(value, "^totemSlot([1-4])$")
    return tonumber(digit)
end

-- This recognition pass is used only after exact admission failed. It lets an
-- incomplete/conflicting slotted summon stop unsafe fallback without treating
-- every unrelated Shaman spell with missing DBC evidence as a totem.
local function potentialTotem(spellId)
    local semantics = XelAssist.Game and XelAssist.Game.SpellSemantics
    if not (semantics and type(semantics.Resolve) == "function") then
        return false
    end
    local ok, descriptor = pcall(semantics.Resolve, semantics, spellId)
    if not ok or type(descriptor) ~= "table" then return false end
    local atoms = descriptor.atoms or {}
    local count = table.getn(atoms)
    local limit = math.min(count, TotemState.MAX_SEMANTIC_ATOMS or 16)
    local index
    for index = 1, limit do
        local atom = atoms[index]
        if type(atom) == "table" and atom.kind == "summon"
            and slotFromType(atom.summonType) then return true end
    end
    return count > limit
end

local function discover(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or not (TotemState
        and type(TotemState.Semantic) == "function"
        and type(TotemState.Lifetime) == "function") then
        return nil, "Shaman totem discovery unavailable", false
    end
    if CACHE[spellId] then return CACHE[spellId], nil, true end
    local semantic, reason = TotemState:Semantic({ spellId = spellId })
    if not semantic then
        local recognized = reason == "totem spell has conflicting elements"
            or reason == "totem semantic budget exceeded"
            or potentialTotem(spellId)
        return nil, reason or "Shaman totem semantics unavailable", recognized
    end
    local lifetime, lifetimeReason = TotemState:Lifetime({ spellId = spellId })
    if not lifetime then return nil, lifetimeReason, true end
    local slot = integer(semantic.slot, 1, TotemState.SLOT_COUNT or 4)
    local duration = finitePositive(lifetime.duration)
    local element = slot and TotemState.ELEMENT_BY_SLOT
        and TotemState.ELEMENT_BY_SLOT[slot]
    if semantic.exact ~= true or lifetime.exact ~= true or not slot
        or type(element) ~= "string" or semantic.element ~= element
        or not duration then
        return nil, "Shaman totem lifecycle evidence is not exact", true
    end
    local found = { spellId = spellId, slot = slot, element = element,
        duration = duration, exact = true,
        semanticSource = semantic.source, lifetimeSource = lifetime.source }
    if CACHE_COUNT < S.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = found, CACHE_COUNT + 1
    end
    return found, nil, true
end

local function family(slot)
    return "shamanTotemSlot" .. tostring(slot)
end

local function factsFor(found)
    return { inferred = true, kind = "totem", kindExact = true,
        self = true, fixedTarget = "player",
        shamanAction = true, shamanTotem = true,
        totemPlacementOrigin = "player", totemPlacementOriginExact = true,
        totemSlot = found.slot, totemElement = found.element,
        totemElementExact = true,
        totemReplacementSlot = found.slot, totemReplacementExact = true,
        totemReplacementFamily = family(found.slot),
        totemReplacementFamilyExact = true,
        totemLifetime = found.duration, totemLifetimeExact = true,
        shamanRepresentation = S.LIFECYCLE_ONLY,
        shamanRepresentationExact = true,
        shamanLifecycleRepresented = true,
        shamanEffectRepresented = false,
        shamanRangeRepresented = false,
        shamanRecipientsRepresented = false,
        requiresShamanTotemState = true,
        requiresExactTotemDownstream = true,
        source = "exact installed-client slotted summon and lifetime" }
end

-- Third return means exact evidence recognized a totem-shaped spell, including
-- a recognized spell that is blocked because its lifetime/semantics is unsafe.
function S:InferKnowledge(spellId)
    if classToken() ~= "SHAMAN" then
        return nil, "player is not an exactly identified Shaman", false
    end
    local found, reason, recognized = discover(spellId)
    if not found then return nil, reason, recognized end
    return factsFor(found), nil, true
end

local function subjectFacts(subject)
    if type(subject) ~= "table" then return nil end
    if type(subject.facts) == "table" then return subject.facts end
    return subject
end

-- Search-safe accessor: this validates only root-captured immutable facts and
-- intentionally performs no Unit*, DBC, SpellSemantics, or duration API reads.
function S:Lifecycle(subject)
    local facts = subjectFacts(subject)
    local slot = facts and integer(facts.totemSlot, 1,
        TotemState and TotemState.SLOT_COUNT or 4)
    local element = slot and TotemState and TotemState.ELEMENT_BY_SLOT
        and TotemState.ELEMENT_BY_SLOT[slot]
    local duration = facts and finitePositive(facts.totemLifetime)
    if not (facts and facts.shamanAction == true
        and facts.shamanTotem == true
        and facts.totemElementExact == true
        and facts.totemReplacementExact == true
        and facts.totemLifetimeExact == true
        and facts.shamanLifecycleRepresented == true
        and slot and facts.totemElement == element
        and facts.totemReplacementSlot == slot and duration
        and facts.totemReplacementFamilyExact == true
        and facts.totemReplacementFamily == family(slot)) then
        return nil, "exact Shaman totem lifecycle facts unavailable"
    end
    return { slot = slot, element = element, duration = duration,
        replacementSlot = slot, replacementFamily = family(slot),
        exact = true, source = facts.source }, nil
end

-- All three downstream dimensions are independent exact gates. The lifecycle
-- alone is never a proxy for combat value.
function S:DownstreamRepresented(subject)
    local facts = subjectFacts(subject)
    local lifecycle = facts and self:Lifecycle(facts)
    return lifecycle ~= nil
        and facts.shamanRepresentationExact == true
        and facts.shamanEffectRepresented == true
        and facts.shamanRangeRepresented == true
        and facts.shamanRecipientsRepresented == true or false
end

function S:Representation(subject)
    local facts = subjectFacts(subject)
    if not (facts and facts.shamanRepresentationExact == true) then
        return nil, false
    end
    return facts.shamanRepresentation, self:DownstreamRepresented(facts)
end

function S:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
