-- Exact installed Hunter mana-aspect identity. Viper's deterministic periodic
-- gain is graph-owned; Snake remains recognized but fail-closed because its
-- attack proc chance and trigger attribution are server-private.
XelAssist.Game.Player.HunterManaAspects = {}
local H = XelAssist.Game.Player.HunterManaAspects

H.VIPER_ID, H.SNAKE_ID, H.SNAKE_TRIGGER_ID = 45651, 45652, 45664
H.HUNTER_FAMILY, H.MANA, H.PERIOD_MS = 9, 0, 5000
local CACHE = {}

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and tonumber(value) or nil
end
local function triple(spellId, field, a, b, c)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    return ok and type(values) == "table" and values[4] == nil
        and tonumber(values[1]) == a and tonumber(values[2]) == b
        and tonumber(values[3]) == c
end
local function viperTopology()
    local id = H.VIPER_ID
    return scalar(id, "school") == 3 and scalar(id, "attributes") == 0
        and scalar(id, "attributesEx2") == 329728
        and scalar(id, "attributesEx3") == 131072
        and scalar(id, "attributesEx4") == 16
        and scalar(id, "durationIndex") == 56
        and scalar(id, "powerType") == H.MANA and scalar(id, "manaCost") == 0
        and scalar(id, "spellFamilyName") == H.HUNTER_FAMILY
        and triple(id, "effect", 6, 0, 0)
        and triple(id, "effectApplyAuraName", 21, 0, 0)
        and triple(id, "effectBasePoints", 4, 0, 0)
        and triple(id, "effectAmplitude", H.PERIOD_MS, 0, 0)
        and triple(id, "effectImplicitTargetA", 4, 0, 0)
        and triple(id, "effectTriggerSpell", 0, 0, 0)
end
local function snakeTopology()
    local id = H.SNAKE_ID
    return scalar(id, "school") == 3 and scalar(id, "attributes") == 0
        and scalar(id, "attributesEx2") == 327680
        and scalar(id, "durationIndex") == 4
        and scalar(id, "procFlags") == 324
        and scalar(id, "spellFamilyName") == H.HUNTER_FAMILY
        and triple(id, "effect", 6, 0, 0)
        and triple(id, "effectTriggerSpell", H.SNAKE_TRIGGER_ID, 0, 0)
        and triple(H.SNAKE_TRIGGER_ID, "effect", 30, 0, 0)
        and triple(H.SNAKE_TRIGGER_ID, "effectBasePoints", 49, 0, 0)
end
local function profile(spellId)
    if CACHE[spellId] ~= nil then return CACHE[spellId] or nil end
    local valid = spellId == H.VIPER_ID and viperTopology()
        or spellId == H.SNAKE_ID and snakeTopology()
    if not valid then CACHE[spellId] = false; return nil end
    local out = { exact = true, valid = true, spellId = spellId,
        aspectFamily = "hunterAspect", period = H.PERIOD_MS / 1000,
        source = "installed patch-5 Hunter mana-aspect topology" }
    if spellId == H.VIPER_ID then
        out.kind, out.maximumManaPercent = "viper", 5
    else
        out.kind, out.triggerSpellId = "snake", H.SNAKE_TRIGGER_ID
        out.procGenerationProjectable = false
    end
    CACHE[spellId] = out
    return out
end

function H:InferKnowledge(spellId)
    spellId = tonumber(spellId)
    if spellId ~= self.VIPER_ID and spellId ~= self.SNAKE_ID then
        return nil, nil, false
    end
    local found = profile(spellId)
    if not found then return nil, "Hunter mana-aspect topology incomplete", true end
    return { inferred = true, kind = found.kind == "viper" and "resource" or "buff",
        self = true, fixedTarget = "player", hunterAspect = true,
        exclusiveFamily = "hunterAspect",
        aspectRole = found.kind == "viper" and "manaRecovery" or "reactiveUtility",
        hunterManaAspect = true, hunterManaAspectEvidence = found,
        hunterAspectEffectRepresented = found.kind == "viper",
        source = found.source }, nil, true
end

function H:CaptureFacts(action, facts)
    local spellId = action and tonumber(action.spellId)
    if spellId ~= self.VIPER_ID and spellId ~= self.SNAKE_ID then return facts end
    local found = profile(spellId)
    if not found then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.hunterManaAspect, out.hunterManaAspectEvidence = true, found
    out.hunterAspect, out.exclusiveFamily = true, "hunterAspect"
    out.aspectRole = found.kind == "viper" and "manaRecovery" or "reactiveUtility"
    out.hunterAspectEffectRepresented = found.kind == "viper"
    return out
end

function H:Profile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.hunterManaAspectEvidence
    return found and found.exact == true and profile(found.spellId) or nil
end
function H:Invalidate() CACHE = {} end
