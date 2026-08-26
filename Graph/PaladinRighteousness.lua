-- Search-pure Seal of Righteousness Judgement consequence. The generic
-- Paladin aura projection owns exact seal consumption; this leaf supplies the
-- linked hidden Holy hit and commits its damage/threat exactly once.
XelAssist.Graph.PaladinRighteousness = {}
local R = XelAssist.Graph.PaladinRighteousness

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
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
        and XelAssist.Game.Player.PaladinRighteousness
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function profile(subject, sourceSealSpellId)
    local owner = runtime()
    return owner and owner:Profile(subject, sourceSealSpellId) or nil
end

local function exactEffect(value, found)
    local owner = runtime()
    return owner and found and type(value) == "table" and value.exact == true
        and value.kind == "paladinRighteousnessDirectHolyDamage"
        and value.actor == "player"
        and value.sourceSealSpellId == found.sourceSealSpellId
        and value.resultSpellId == found.resultSpellId
        and value.school == owner.HOLY_SCHOOL
        and value.meanDamage == found.meanDamage
        and value.deliveryModel == "physical"
        and value.deliverySubtype == "melee"
        and value.usesWeaponSkill == false and value.alwaysHit == true
        and value or nil
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

local function activeSeal(state)
    local root, player = rootPlayer(state)
    local aura = player and player.activeSeal
    if not (root and aura and tonumber(aura.spellId)
        and aura.sourceGUID == root.playerGUID
        and aura.recipientGUID == root.playerGUID
        and aura.recipientRelation == "self" and aura.exact == true) then
        return nil, nil, nil
    end
    return aura, root, player
end

local function exactHostile(state, descriptor)
    if not (descriptor and descriptor.relation == "hostile"
        and validGUID(descriptor.guid)) then return nil end
    local hostiles = state and state.hostiles
    if not (hostiles and hostiles.byKey) then
        return descriptor.exact == true and descriptor or nil
    end
    local record = descriptor.key ~= nil and hostiles.byKey[descriptor.key]
        or nil
    if not (record and record.relation == "hostile"
        and record.guid == descriptor.guid and record.dead ~= true
        and (descriptor.record == nil or descriptor.record == record)
        and (descriptor.unit == nil or record.unit == descriptor.unit)) then
        return nil
    end
    return descriptor
end

function R:Is(action, facts)
    facts = facts or action and action.facts or {}
    return tonumber(action and action.spellId) == 20271
        and facts.paladinRighteousness == true
end

-- Called before PaladinAuraProjection:Prepare. The exact hostile recipient is
-- attached here because root action facts deliberately remain target-neutral.
function R:Outcome(action, state, descriptor, facts)
    if not self:Is(action, facts) then return nil, nil, false end
    local target = exactHostile(state, descriptor)
    if not target then
        return nil, "Righteousness Judgement target identity unavailable", true
    end
    local seal = activeSeal(state)
    if not seal then
        return nil, "Righteousness Judgement requires an exact active seal", true
    end
    local found = profile(facts, seal.spellId)
    local owner = runtime()
    local effect = found and owner:CapturedEffect(facts, seal.spellId) or nil
    effect = exactEffect(effect, found)
    if not effect then
        return nil, "active seal has no exact Righteousness outcome", true
    end
    return { exact = true, representable = true,
        sourceSealSpellId = seal.spellId,
        recipientGUID = target.guid, recipientRelation = "hostile",
        effect = copy(effect), source = effect.source }, nil, true
end

local function exactProjection(state, projection, facts)
    local outcome = projection and projection.outcome
    local sourceId = outcome and tonumber(outcome.sourceSealSpellId)
    local found = sourceId and profile(facts, sourceId) or nil
    local effect = found and exactEffect(outcome.effect, found) or nil
    local seal = activeSeal(state)
    if not (projection and projection.kind == "judgement"
        and projection.paladinAuraProjection == true
        and projection.consumesSeal == true and seal
        and seal.spellId == sourceId and effect
        and projection.targetGUID == outcome.recipientGUID
        and outcome.recipientRelation == "hostile") then return nil end
    return found, effect
end

-- Called after PaladinAuraProjection:Prepare. It freezes the damage transition
-- into the projection transported by Candidate and later graph branches.
function R:Prepare(state, projection, facts)
    if not (projection and projection.kind == "judgement") then
        return projection, nil, false
    end
    local found, effect = exactProjection(state, projection, facts)
    if not found then
        return nil, "Righteousness Judgement transition unavailable", true
    end
    projection.paladinRighteousnessTransition = {
        exact = true, sourceSealSpellId = found.sourceSealSpellId,
        resultSpellId = found.resultSpellId,
        targetGUID = projection.targetGUID, meanDamage = found.meanDamage,
        effect = copy(effect), profile = copy(found),
        source = "exact active seal to hidden Judgement result" }
    return projection, nil, true
end

local function transition(value)
    local found = value and value.paladinRighteousnessTransition
    local sealed = found and profile(
        { paladinRighteousnessProfiles = {
            [found.sourceSealSpellId] = found.profile } },
        found.sourceSealSpellId) or nil
    local effect = sealed and exactEffect(found.effect, sealed) or nil
    if not (found and found.exact == true and sealed and effect
        and found.resultSpellId == sealed.resultSpellId
        and found.meanDamage == sealed.meanDamage
        and validGUID(found.targetGUID)) then return nil end
    return found, sealed
end

local function resultAction(context, found)
    return { name = context.action and context.action.name,
        rank = context.action and context.action.rank,
        spellId = found.resultSpellId, actor = "player",
        resistanceMetadataCaptured = true,
        resistanceMetadata = { school = 1, dmgClass = 2,
            attributesEx3 = 262656, rangeIndex = 6,
            equippedItemClass = -1, alwaysHit = true,
            alwaysHitKnown = true, usesWeaponSkill = false,
            deliveryModel = "physical", deliveryModelKnown = true,
            deliveryModelSource = "client DBC DmgClass",
            deliverySubtype = "melee" },
        facts = { kind = "damage", kindExact = true, hostile = true,
            school = 1, melee = true, deliveryModel = "physical",
            deliverySubtype = "melee", usesWeaponSkill = false,
            damageActor = "player" } }
end

-- This initializes a normal damage context. Shared scoring must allow its
-- generic damage utility pass after resistance projection; the lifecycle edge
-- itself contributes no fixed utility.
function R:Score(context, projection)
    local found, sealed = transition(projection)
    local seal = activeSeal(context and context.state)
    if not (found and sealed and seal
        and seal.spellId == found.sourceSealSpellId
        and context.descriptor and context.descriptor.guid == found.targetGUID) then
        return false, "Righteousness Judgement scoring evidence unavailable"
    end
    context.effectAction = resultAction(context, found)
    context.effectTooltip = copy(context.tooltip or {})
    context.effectTooltip.school = 1
    context.kind, context.targetEffect, context.damageKind = "damage", true, true
    context.threatSchool = 1
    context.power, context.expectedPower = sealed.meanDamage, sealed.meanDamage
    context.effectivePower = sealed.meanDamage
    context.powerEvidence = { exact = true, kind = "sealedHiddenResultMean",
        spellId = found.resultSpellId, source = found.source }
    context.value, context.estimated = 0, false
    context.reason = "delivers the exact active-seal Judgement result"
    return true
end

local function selectedHostile(state, projection)
    local owner = XelAssist.Graph.State
    local record = owner and owner.ActiveHostile and owner:ActiveHostile(state)
        or owner and owner.SelectedHostile and owner:SelectedHostile(state)
        or nil
    if not record and state and state.hostiles and state.hostiles.byKey
        and projection.recipientKey ~= nil then
        record = state.hostiles.byKey[projection.recipientKey]
    end
    return record
end

-- Called after PaladinAuraProjection:Apply has consumed the seal. Generic
-- ActionEffects skips class-mechanic damage, so health and already-scaled
-- candidate threat are committed here exactly once.
function R:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
        or candidate
    local found = transition(projection)
    local root, player = rootPlayer(state)
    local last = player and player.lastJudgement
    local record = selectedHostile(state, projection or {})
    if not (found and root and last and last.exact == true
        and last.downstreamPending == true
        and last.sourceSealSpellId == found.sourceSealSpellId
        and last.targetGUID == found.targetGUID
        and record and record.guid == found.targetGUID
        and candidate.targetGUID == found.targetGUID) then return false end
    local amount = finite(candidate.power, 0, 100000000)
    local threat = finite(candidate.threat or 0, 0, 100000000)
    local hostile = XelAssist.Graph.HostileEffects
    local threatOwner = XelAssist.Graph.PlayerThreat
    if not (amount and threat and hostile and hostile.ApplySelectedDamage
        and (threat == 0 or threatOwner and threatOwner.AddScaled)) then
        return false
    end
    local applied = hostile:ApplySelectedDamage(state, amount)
    if threat > 0 then
        threatOwner:AddScaled(record, "player", threat,
            candidate.playerThreatExact ~= false)
        if not applied then record.projectedThreatTimingUnknown = true end
    end
    last.downstreamPending, last.downstreamApplied = false, true
    last.downstreamResultSpellId = found.resultSpellId
    return true
end
