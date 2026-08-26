-- Exact hard-control discovery for the caster spellbooks.  Classification is
-- deliberately narrower than "anything with a control aura": area controls,
-- damage/control hybrids, scripted recipients and immunity effects need graph
-- models of their own.  Names are never used as mechanics.
XelAssist.Game.CrowdControl = {}
local C = XelAssist.Game.CrowdControl

local function hunterControl()
    return XelAssist.Game.Pets and XelAssist.Game.Pets.HunterControl
end

C.MAX_CACHE = 64
C.SUPPORTED_FAMILIES = { [3] = "MAGE", [5] = "WARLOCK", [6] = "PRIEST" }
C.CONTROL_AURAS = {
    [2] = "possess", [5] = "confuse", [6] = "charm", [7] = "fear",
    [12] = "stun", [26] = "root", [56] = "transform",
}
C.ANY_DAMAGE_INTERRUPT = 2
C.DIRECT_DAMAGE_INTERRUPT = 16777216
C.CHANNELED_ATTRIBUTES_EX_1 = 4
C.CHANNELED_ATTRIBUTES_EX_2 = 64

local CACHE, CACHE_COUNT = {}, 0

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
    return value
end

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    if type(source and source.controlAuras) == "table" then
        out.controlAuras = {}
        local index
        for index = 1, table.getn(source.controlAuras) do
            out.controlAuras[index] = source.controlAuras[index]
        end
    end
    return out
end

local function flagSet(value, flag)
    value = integer(value, 0, 4294967295)
    if not value then return nil end
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and integer(value, 0, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key = {}, 0, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    local index
    for index = 1, 3 do
        out[index] = integer(values[index], 0, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function store(spellId, evidence)
    -- Misses are cheap during the infrequent spellbook rebuild and must not
    -- evict the small set of recognized actions needed by every root capture.
    if evidence and evidence.recognized == true
        and CACHE_COUNT < C.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = shallow(evidence), CACHE_COUNT + 1
    end
    return shallow(evidence)
end

local function fail(spellId, recognized, reason, evidence)
    evidence = evidence or {}
    evidence.spellId, evidence.valid = spellId, false
    evidence.recognized, evidence.reason = recognized and true or false, reason
    return store(spellId, evidence), reason, recognized and true or false
end

local function primaryType(found)
    if found[56] or found[5] then return "polymorph" end
    if found[7] then return "fear" end
    if found[6] then return "charm" end
    if found[2] then return "possess" end
    if found[26] then return "root" end
    if found[12] then return "stun" end
    return nil
end

-- Supported spells have one exact hostile unit recipient for every active
-- effect.  Opcode 108 is Polymorph's mechanic dispel; aura 31 is the movement
-- component paired with Fear.  Neither is treated as control on its own.
function C:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "spell ID unavailable", false end
    if CACHE[spellId] then
        local cached = shallow(CACHE[spellId])
        return cached, cached.reason, cached.recognized == true
    end
    local effects = triple(spellId, "effect")
    local auras = triple(spellId, "effectApplyAuraName")
    local targetsA = triple(spellId, "effectImplicitTargetA")
    local targetsB = triple(spellId, "effectImplicitTargetB")
    if not (effects and auras and targetsA and targetsB) then
        return fail(spellId, false, "crowd-control DBC arrays unavailable")
    end
    local found, auxiliaries, dispelMechanic = {}, {}, false
    local recognized, invalid, index = false, nil, nil
    for index = 1, 3 do
        local opcode, aura = effects[index], auras[index]
        if opcode == 6 and self.CONTROL_AURAS[aura] then
            recognized, found[aura] = true, true
        end
        if opcode ~= 0 and (targetsA[index] ~= 6 or targetsB[index] ~= 0) then
            invalid = "control recipient is not one exact hostile unit"
        elseif opcode == 6 then
            if self.CONTROL_AURAS[aura] then
                found[aura] = true
            elseif aura == 31 then auxiliaries[aura] = true
            else invalid = "control spell has an unresolved aura effect" end
        elseif opcode == 108 then
            dispelMechanic = true
        elseif opcode ~= 0 then
            invalid = "control spell has an unsupported additional effect"
        elseif aura ~= 0 or targetsA[index] ~= 0 or targetsB[index] ~= 0 then
            invalid = "inactive control effect contains semantic data"
        end
    end
    if not recognized then
        return fail(spellId, false, "spell has no supported hard-control aura")
    end
    local family = scalar(spellId, "spellFamilyName")
    if not self.SUPPORTED_FAMILIES[family] then
        return fail(spellId, false, "control belongs to another spell family")
    end
    if auxiliaries[31] and not found[7] then
        invalid = "unpaired Fear movement aura"
    end
    if dispelMechanic and not (found[5] and found[56]) then
        invalid = "unpaired mechanic-dispel effect"
    end
    local maximum = scalar(spellId, "maxAffectedTargets")
    if maximum == nil or maximum > 1 then
        invalid = "area crowd control requires recipient-set projection"
    end
    local mechanic = scalar(spellId, "mechanic")
    local interruptFlags = scalar(spellId, "auraInterruptFlags")
    local creatureMask = scalar(spellId, "targetCreatureType")
    local attributesEx = scalar(spellId, "attributesEx")
    if mechanic == nil or mechanic == 0 or interruptFlags == nil
        or creatureMask == nil or attributesEx == nil then
        invalid = "control scalar evidence is incomplete"
    end
    if flagSet(attributesEx, self.CHANNELED_ATTRIBUTES_EX_1) == true
        or flagSet(attributesEx, self.CHANNELED_ATTRIBUTES_EX_2) == true then
        invalid = "channeled control requires maintained-aura projection"
    end
    local list, aura = {}, nil
    for aura = 1, 255 do
        if found[aura] then table.insert(list, aura) end
    end
    local evidence = { spellId = spellId, recognized = true,
        valid = invalid == nil, family = family, mechanic = mechanic,
        controlType = primaryType(found), controlAuras = list,
        targetCreatureMask = creatureMask, maxAffectedTargets = maximum,
        auraInterruptFlags = interruptFlags,
        attributesEx = attributesEx,
        breaksOnAnyDamage = flagSet(interruptFlags,
            self.ANY_DAMAGE_INTERRUPT) == true,
        breaksOnDirectDamage = flagSet(interruptFlags,
            self.DIRECT_DAMAGE_INTERRUPT) == true,
        damageBreakSpecified = interruptFlags ~= nil
            and (flagSet(interruptFlags, self.ANY_DAMAGE_INTERRUPT) == true
                or flagSet(interruptFlags,
                    self.DIRECT_DAMAGE_INTERRUPT) == true),
        source = "installed-client single-target crowd-control DBC topology" }
    if invalid then return fail(spellId, true, invalid, evidence) end
    return store(spellId, evidence), nil, true
end

function C:InferKnowledge(spellId)
    local evidence, reason, recognized = self:Classify(spellId)
    if not (evidence and evidence.valid == true) then
        return nil, reason, recognized
    end
    return { inferred = true, kind = "crowdControl", kindExact = true,
        submissionGuarded = true, requiresExactUsability = true,
        targetCreatureMask = evidence.targetCreatureMask,
        controlType = evidence.controlType,
        crowdControlEvidence = shallow(evidence),
        source = evidence.source }, nil, true
end

-- Root capture may classify explicit catalogue entries (for example Seduction)
-- but graph nodes consume only the copied evidence attached here.
function C:CaptureFacts(action, facts)
    local out = shallow(facts)
    local hunter = hunterControl()
    if hunter then
        local captured = hunter:CaptureFacts(action, out)
        if captured and captured.hunterControlEvidence then return captured end
    end
    if not (action and action.facts
        and action.facts.kind == "crowdControl") then return out end
    local evidence = action.facts.crowdControlEvidence
    if type(evidence) == "table" then evidence = shallow(evidence)
    else evidence = self:Classify(action.spellId) end
    if not (evidence and evidence.valid == true) then return out end
    out.crowdControlEvidence = shallow(evidence)
    out.targetCreatureMask = evidence.targetCreatureMask
    out.controlType = evidence.controlType
    return out
end

function C:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
    local hunter = hunterControl()
    if hunter then hunter:Invalidate() end
end
