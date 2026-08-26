-- Exact Paladin exclusive-aura ownership and Judgement lifecycle evidence.
-- This module describes mechanics only: it assigns no utility, spell order,
-- threat value, or preferred seal/blessing. Central graph integration must
-- retain the recipient descriptor used for Observe before applying a prepared
-- projection.
XelAssist.Game.Player.PaladinAuraState = {}
local A = XelAssist.Game.Player.PaladinAuraState

A.PALADIN_FAMILY = 10
A.MAX_AURAS = 40
A.MAX_LOW_FLAGS = 4294967295
A.MAX_EXACT_FLAGS = 9007199254740991
A.SEAL_BITS = { 9, 25, 27 }
A.BLESSING_BITS = { 8, 28 }
A.JUDGEMENT_BIT = 23
A.RIGHTEOUS_FURY_BIT = 0

local FRIENDLY_RELATION = { self = true, pet = true, party = true,
    raid = true, friendly = true }

local function integer(value, low, high)
    value = tonumber(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function bit(value, index)
    value = integer(value, 0, A.MAX_LOW_FLAGS)
    index = integer(index, 0, 31)
    if value == nil or index == nil then return nil end
    local divisor = 2 ^ index
    return math.floor(value / divisor)
        - math.floor(value / (divisor * 2)) * 2 == 1
end

local function anyBit(value, bits)
    local index
    for index = 1, table.getn(bits) do
        local present = bit(value, bits[index])
        if present == nil then return nil end
        if present then return true end
    end
    return false
end

local function dbc(spellId, field)
    spellId = integer(spellId, 1, A.MAX_LOW_FLAGS)
    if spellId == nil or type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    if not ok then return nil end
    return tonumber(value)
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function identity(unit)
    if type(UnitExists) ~= "function" or type(unit) ~= "string" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not (exists == true or exists == 1) then return nil end
    if not validGUID(guid) and type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, unit)
        if not ok then guid = nil end
    end
    return validGUID(guid) and guid or nil
end

local function assistable(unit)
    if unit == "player" then return true end
    if type(UnitCanAssist) ~= "function" then return nil end
    local ok, value = pcall(UnitCanAssist, "player", unit)
    if not ok then return nil end
    if value == true or value == 1 then return true end
    if value == false or value == 0 or value == nil then return false end
    return nil
end

local function relation(unit)
    if unit == "player" then return "self" end
    if assistable(unit) ~= true then return nil end
    if unit == "pet" then return "pet" end
    if string.sub(unit, 1, 5) == "party" then return "party" end
    if string.sub(unit, 1, 4) == "raid" then return "raid" end
    return "friendly"
end

function A:Classify(spellId)
    spellId = integer(spellId, 1, self.MAX_LOW_FLAGS)
    local family = spellId and dbc(spellId, "spellFamilyName") or nil
    local fullFlags = spellId and dbc(spellId, "spellFamilyFlags") or nil
    family = family and integer(family, 0, self.MAX_LOW_FLAGS) or nil
    fullFlags = fullFlags
        and integer(fullFlags, 0, self.MAX_EXACT_FLAGS) or nil
    if family == nil or fullFlags == nil then
        return nil, "Paladin DBC family evidence unavailable", false
    end
    local flags = fullFlags
        - math.floor(fullFlags / 4294967296) * 4294967296
    if family ~= self.PALADIN_FAMILY then
        return { kind = "other", spellId = spellId, family = family,
            flags = flags, lowFlags = flags, fullFlags = fullFlags,
            exact = true }, nil, false
    end

    local seal, blessing = anyBit(flags, self.SEAL_BITS),
        anyBit(flags, self.BLESSING_BITS)
    local judgement, righteousFury = bit(flags, self.JUDGEMENT_BIT),
        bit(flags, self.RIGHTEOUS_FURY_BIT)
    if seal == nil or blessing == nil or judgement == nil
        or righteousFury == nil then
        return nil, "Paladin DBC family flags are not exactly representable",
            true
    end
    local count = (seal and 1 or 0) + (blessing and 1 or 0)
        + (judgement and 1 or 0) + (righteousFury and 1 or 0)
    if count > 1 then
        return nil, "Paladin DBC exclusive families conflict", true
    end

    local kind = seal and "seal" or blessing and "blessing"
        or judgement and "judgement"
        or righteousFury and "righteousFury" or "other"
    local exclusiveFamily = seal and "paladinSeal"
        or blessing and "paladinBlessingByCaster" or nil
    local recipientRelation = seal and "self"
        or blessing and "friendly" or judgement and "hostile"
        or righteousFury and "self" or nil
    return { kind = kind, spellId = spellId, family = family, flags = flags,
        lowFlags = flags, fullFlags = fullFlags,
        exclusiveFamily = exclusiveFamily,
        recipientRelation = recipientRelation, exact = true,
        source = "build-5875 exact Paladin SpellFamily flags" }, nil,
        kind ~= "other"
end

local function exactSource(aura, playerGUID)
    if type(aura) ~= "table" then
        return nil, "Paladin aura caster identity unavailable"
    end
    local sourceUnit, sourceGUID = aura.sourceUnit, aura.sourceGUID
    if validGUID(sourceGUID) then
        if type(sourceUnit) == "string" then
            local unitGUID = identity(sourceUnit)
            if unitGUID and unitGUID ~= sourceGUID then
                return nil, "Paladin aura caster identity is incoherent"
            end
            if sourceUnit == "player" and sourceGUID ~= playerGUID then
                return nil, "Paladin aura caster identity is incoherent"
            end
        end
        return sourceGUID, nil
    end
    if sourceUnit == "player" then return playerGUID, nil end
    if type(sourceUnit) == "string" then
        local unitGUID = identity(sourceUnit)
        if unitGUID then return unitGUID, nil end
    end
    return nil, "Paladin aura caster identity unavailable"
end

local function auraCopy(aura, classification, casterGUID, recipientGUID,
    recipientRelation)
    return { spellId = tonumber(aura.spellId), name = aura.name,
        sourceGUID = casterGUID, recipientGUID = recipientGUID,
        recipientRelation = recipientRelation,
        duration = tonumber(aura.duration),
        expirationTime = tonumber(aura.expirationTime),
        classification = classification,
        exclusiveFamily = classification.exclusiveFamily, exact = true }
end

function A:Observe(unit, expectedGUID)
    local out = { available = false, unit = unit,
        source = "ClassicAPI aura identity plus build-5875 family flags" }
    if classToken() ~= "PALADIN" then
        out.reason = "player is not an exactly identified Paladin"
        return out
    end
    local playerGUID, before = identity("player"), identity(unit)
    local beforeRelation = type(unit) == "string" and relation(unit) or nil
    if not validGUID(expectedGUID) or playerGUID == nil or before == nil
        or before ~= expectedGUID or not FRIENDLY_RELATION[beforeRelation] then
        out.reason = "Paladin aura recipient identity unavailable"
        return out
    end
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        out.reason = "Paladin aura observation unavailable"
        return out
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    local after, afterRelation = identity(unit), relation(unit)
    local playerAfter = identity("player")
    if not ok or type(list) ~= "table" then
        out.reason = "Paladin aura observation unavailable"
        return out
    end
    if after ~= before or afterRelation ~= beforeRelation
        or playerAfter ~= playerGUID then
        out.reason = "Paladin aura recipient changed during observation"
        return out
    end
    if table.getn(list) > self.MAX_AURAS then
        out.reason = "Paladin aura observation budget exceeded"
        return out
    end

    local blessings, activeSeal, righteousFury = {}, nil, nil
    local index
    for index = 1, table.getn(list) do
        local aura = list[index]
        if type(aura) == "table" and tonumber(aura.spellId) then
            local classification, reasonText = self:Classify(aura.spellId)
            if not classification then out.reason = reasonText; return out end
            local kind = classification.kind
            if kind == "seal" or kind == "blessing"
                or kind == "righteousFury" then
                local casterGUID, sourceReason = exactSource(aura, playerGUID)
                if not casterGUID then out.reason = sourceReason; return out end
                local copy = auraCopy(aura, classification, casterGUID,
                    before, beforeRelation)
                if kind == "seal" then
                    if beforeRelation ~= "self" or casterGUID ~= playerGUID then
                        out.reason = "active seal ownership is incoherent"
                        return out
                    end
                    if activeSeal then
                        out.reason = "multiple active seals are incoherent"
                        return out
                    end
                    activeSeal = copy
                elseif kind == "blessing" then
                    if blessings[casterGUID] then
                        out.reason = "multiple blessings from one Paladin are incoherent"
                        return out
                    end
                    blessings[casterGUID] = copy
                elseif beforeRelation == "self" and casterGUID == playerGUID then
                    if righteousFury then
                        out.reason = "multiple Righteous Fury auras are incoherent"
                        return out
                    end
                    righteousFury = copy
                end
            end
        end
    end
    out.available, out.guid, out.playerGUID = true, before, playerGUID
    out.recipientRelation, out.activeSeal = beforeRelation, activeSeal
    out.blessingsByCaster, out.righteousFury = blessings, righteousFury
    return out
end

local function currentMatches(current, projection)
    if projection.replacedSpellId == nil then return current == nil end
    return current and current.spellId == projection.replacedSpellId
        and current.sourceGUID == projection.replacedSourceGUID
end

local function actionClassification(owner, action, supplied)
    if supplied ~= nil then
        if type(supplied) ~= "table" or supplied.exact ~= true
            or integer(supplied.spellId, 1, owner.MAX_LOW_FLAGS)
                ~= integer(action and action.spellId, 1, owner.MAX_LOW_FLAGS)
            or supplied.family ~= owner.PALADIN_FAMILY
            or type(supplied.kind) ~= "string" then
            return nil, "captured Paladin action classification unavailable"
        end
        return supplied, nil
    end
    return owner:Classify(action and action.spellId)
end

function A:PrepareSeal(action, playerState, captured)
    if not (playerState and playerState.available == true
        and playerState.guid == playerState.playerGUID
        and playerState.recipientRelation == "self") then
        return nil, "Paladin self-aura state unavailable"
    end
    local classification, reason = actionClassification(self, action, captured)
    if not classification then return nil, reason end
    if classification.kind ~= "seal"
        or classification.exclusiveFamily ~= "paladinSeal" then
        return nil, "spell is not an exact Paladin seal"
    end
    local current = playerState.activeSeal
    if current and current.spellId == tonumber(action.spellId) then
        return nil, "same seal already active"
    end
    return { kind = "seal", action = action,
        recipientGUID = playerState.guid, casterGUID = playerState.playerGUID,
        exclusiveFamily = classification.exclusiveFamily,
        replacement = current, replacedSpellId = current and current.spellId,
        replacedSourceGUID = current and current.sourceGUID,
        classification = classification,
        source = "exact per-player seal family" }, nil
end

function A:ApplySeal(playerState, projection)
    if not (playerState and playerState.available == true and projection
        and projection.kind == "seal"
        and projection.exclusiveFamily == "paladinSeal"
        and playerState.guid == projection.recipientGUID
        and playerState.playerGUID == projection.casterGUID
        and projection.action and tonumber(projection.action.spellId)
        and currentMatches(playerState.activeSeal, projection)) then
        return false
    end
    playerState.activeSeal = { spellId = tonumber(projection.action.spellId),
        name = projection.action.name, sourceGUID = projection.casterGUID,
        recipientGUID = projection.recipientGUID,
        recipientRelation = "self", classification = projection.classification,
        exclusiveFamily = projection.exclusiveFamily,
        projected = true, exact = true }
    return true
end

function A:PrepareBlessing(action, recipientState, captured)
    if not (recipientState and recipientState.available == true
        and validGUID(recipientState.guid)
        and validGUID(recipientState.playerGUID)
        and FRIENDLY_RELATION[recipientState.recipientRelation]) then
        return nil, "Paladin blessing recipient state unavailable"
    end
    local classification, reason = actionClassification(self, action, captured)
    if not classification then return nil, reason end
    if classification.kind ~= "blessing"
        or classification.exclusiveFamily ~= "paladinBlessingByCaster" then
        return nil, "spell is not an exact Paladin blessing"
    end
    local current = recipientState.blessingsByCaster
        and recipientState.blessingsByCaster[recipientState.playerGUID]
    if current and current.spellId == tonumber(action.spellId) then
        return nil, "same own blessing already active"
    end
    return { kind = "blessing", action = action,
        recipientGUID = recipientState.guid,
        recipientRelation = recipientState.recipientRelation,
        casterGUID = recipientState.playerGUID,
        exclusiveFamily = classification.exclusiveFamily,
        replacement = current, replacedSpellId = current and current.spellId,
        replacedSourceGUID = current and current.sourceGUID,
        classification = classification,
        source = "exact per-caster blessing family" }, nil
end

function A:ApplyBlessing(recipientState, projection)
    local current = recipientState and recipientState.blessingsByCaster
        and recipientState.blessingsByCaster[projection and projection.casterGUID]
    if not (recipientState and recipientState.available == true and projection
        and projection.kind == "blessing"
        and projection.exclusiveFamily == "paladinBlessingByCaster"
        and recipientState.guid == projection.recipientGUID
        and recipientState.recipientRelation == projection.recipientRelation
        and recipientState.playerGUID == projection.casterGUID
        and projection.action and tonumber(projection.action.spellId)
        and currentMatches(current, projection)) then return false end
    recipientState.blessingsByCaster = recipientState.blessingsByCaster or {}
    recipientState.blessingsByCaster[projection.casterGUID] = {
        spellId = tonumber(projection.action.spellId),
        name = projection.action.name, sourceGUID = projection.casterGUID,
        recipientGUID = projection.recipientGUID,
        recipientRelation = projection.recipientRelation,
        classification = projection.classification,
        exclusiveFamily = projection.exclusiveFamily,
        projected = true, exact = true }
    return true
end

-- Hook contract: a Judgement caller must provide a frozen seal-specific
-- outcome with exact=true, representable=true, the active source seal, the
-- exact hostile recipient, and an exact effect descriptor. This module only
-- consumes the seal and transports that descriptor; the graph hook applying
-- outcome.effect must reject every kind it cannot represent.
local function exactOutcome(outcome, seal, target)
    return outcome and outcome.exact == true
        and outcome.representable == true
        and tonumber(outcome.sourceSealSpellId) == seal.spellId
        and outcome.recipientGUID == target.guid
        and outcome.recipientRelation == "hostile"
        and type(outcome.effect) == "table"
        and outcome.effect.exact == true
        and type(outcome.effect.kind) == "string"
        and outcome.effect.kind ~= ""
end

function A:PrepareJudgement(action, playerState, target, outcome, captured)
    local classification, reason = actionClassification(self, action, captured)
    if not classification then return nil, reason end
    if classification.kind ~= "judgement" then
        return nil, "spell is not exact Paladin Judgement"
    end
    if not (playerState and playerState.available == true
        and playerState.guid == playerState.playerGUID
        and playerState.activeSeal
        and playerState.activeSeal.sourceGUID == playerState.playerGUID) then
        return nil, "Judgement requires an exact active own seal"
    end
    if not (target and target.exact == true and validGUID(target.guid)
        and target.relation == "hostile") then
        return nil, "Judgement target identity unavailable"
    end
    if not exactOutcome(outcome, playerState.activeSeal, target) then
        return nil, "seal-specific Judgement outcome unavailable"
    end
    return { kind = "judgement", action = action,
        casterGUID = playerState.playerGUID, targetGUID = target.guid,
        sourceSeal = playerState.activeSeal, outcome = outcome,
        consumesSeal = true, classification = classification,
        source = "exact active seal plus represented seal-specific outcome" }, nil
end

function A:ApplyJudgement(playerState, projection)
    if not (playerState and playerState.available == true and projection
        and projection.kind == "judgement" and projection.consumesSeal == true
        and playerState.playerGUID == projection.casterGUID
        and playerState.activeSeal
        and playerState.activeSeal.spellId == projection.sourceSeal.spellId
        and playerState.activeSeal.sourceGUID == projection.casterGUID
        and exactOutcome(projection.outcome, playerState.activeSeal,
            { guid = projection.targetGUID })) then
        return false
    end
    playerState.activeSeal = nil
    playerState.lastJudgement = { targetGUID = projection.targetGUID,
        sourceSealSpellId = projection.sourceSeal.spellId,
        outcome = projection.outcome, downstreamPending = true, exact = true }
    return true
end
