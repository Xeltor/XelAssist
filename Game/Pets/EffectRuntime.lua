-- Session-only reconstruction of Hunter pet effects between graph snapshots.
-- A confirmed cast is retained as an explicitly projected fact when the live
-- client exposes no aura for a hidden next-melee proc; exact aura and outcome
-- events supersede that projection without persisting opaque GUIDs to disk.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.EffectRuntime = {}
local R = XelAssist.Game.Pets.EffectRuntime

local SUBMISSION_GRACE = 2
local OBSERVED_EFFECTS = {
    [19574] = { name = "Bestial Wrath", key = "control-immunity",
        duration = 18, crowdControlImmune = true },
    [52995] = { name = "Bestial Wrath", key = "damage-enrage",
        duration = 8, damageMultiplier = 1.4 },
    [51556] = { name = "Intimidation", key = "threat", duration = 8,
        threatMultiplier = 1.5, runtimeUnverified = true },
}

local function now()
    if not GetTime then return 0 end
    local ok, value = pcall(GetTime)
    return ok and type(value) == "number" and value or 0
end

local function unitGuid(unit)
    if not (UnitExists and unit) then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    return ok and exists and guid or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function effectKey(name, effect)
    return name .. ":" .. tostring(effect.key or effect.sourceSpellId or "effect")
end

local function bucketFor(owner, petGuid, create)
    if petGuid == nil then return nil end
    owner.runtime = owner.runtime or { byPet = {} }
    local bucket = owner.runtime.byPet[petGuid]
    if not bucket and create then
        bucket = { records = {}, observedEffects = {} }
        owner.runtime.byPet[petGuid] = bucket
    end
    return bucket
end

local function trackedAction(spellId)
    local name = tonumber(spellId) == 19574 and "Bestial Wrath"
        or tonumber(spellId) == 19577 and "Intimidation" or nil
    local facts = name and XelAssist.Combat
        and XelAssist.Combat.Knowledge and XelAssist.Combat.Knowledge[name] or nil
    return facts and { name = name, spellId = tonumber(spellId), facts = facts } or nil
end

function R:Reset()
    self.runtime = { byPet = {} }
end

function R:Submitted(action, petGuid, targetGuid, casterGuid)
    local facts = action and action.facts or {}
    if not (petGuid and (facts.petCombatBuff or facts.petCombatEffects
        or facts.deferredUntilPetMelee)) then return false end
    local bucket, at = bucketFor(self, petGuid, true), now()
    local key = action.spellId or action.name
    local effects, i = {}, nil
    for i = 1, table.getn(facts.petCombatEffects or {}) do
        effects[i] = copy(facts.petCombatEffects[i])
    end
    bucket.records[key] = { actionName = action.name, spellId = action.spellId,
        petGuid = petGuid, targetGuid = targetGuid, casterGuid = casterGuid,
        submittedAt = at, state = "submitted", effects = effects,
        deferred = facts.deferredUntilPetMelee and {
            duration = tonumber(facts.triggerWindow) or 15,
            stunDuration = tonumber(facts.stunDuration),
            resultSpellIds = facts.triggeredSpellIds,
            resultSpellId = facts.deferredResultSpellId,
            threatBase = tonumber(facts.deferredThreatBase),
            threatLevel = tonumber(facts.deferredThreatLevel),
            threatPerLevel = tonumber(facts.deferredThreatPerLevel),
            runtimeUnverified = facts.runtimeUnverified and true or false,
        } or nil }
    return true
end

local function matching(record, spellId, casterGuid, targetGuid)
    return tonumber(record.spellId) == tonumber(spellId)
        and (casterGuid == nil or record.casterGuid == nil
            or record.casterGuid == casterGuid)
        and (targetGuid == nil or record.petGuid == targetGuid
            or record.targetGuid == targetGuid)
end

function R:ObserveCast(spellId, casterGuid, targetGuid, state)
    if not spellId then return false end
    local changed, petGuid, bucket, key, record, at = false, nil, nil, nil, nil, now()
    for petGuid, bucket in pairs(self.runtime and self.runtime.byPet or {}) do
        for key, record in pairs(bucket.records) do
            if matching(record, spellId, casterGuid, targetGuid) then
                if state == "failed" or state == "fail" then
                    bucket.records[key], changed = nil, true
                else
                    record.state, record.lastEvidenceAt = state, at
                    if state == "go" or state == "cast" then
                        record.confirmedAt = record.confirmedAt or at
                        record.state = "confirmed"
                    end
                    changed = true
                end
            end
        end
    end
    petGuid = unitGuid("pet")
    if not changed and petGuid and (targetGuid == nil or targetGuid == petGuid)
        and (state == "go" or state == "cast") then
        local action = trackedAction(spellId)
        if action then
            self:Submitted(action, petGuid, nil, casterGuid)
            bucket = bucketFor(self, petGuid, false)
            record = bucket and bucket.records[action.spellId or action.name]
            if record then
                record.state, record.lastEvidenceAt = "confirmed", at
                record.confirmedAt, changed = at, true
            end
        end
    end
    return changed
end

local function recordUntil(record)
    if not record.confirmedAt then return record.submittedAt + SUBMISSION_GRACE end
    local untilAt, i = record.confirmedAt, nil
    for i = 1, table.getn(record.effects or {}) do
        untilAt = math.max(untilAt,
            record.confirmedAt + (tonumber(record.effects[i].duration) or 0))
    end
    if record.deferred and not record.consumedAt then
        untilAt = math.max(untilAt, record.confirmedAt + record.deferred.duration)
    end
    return untilAt
end

function R:Prune(at)
    at = tonumber(at) or now()
    local petGuid, bucket, key, record = nil, nil, nil, nil
    for petGuid, bucket in pairs(self.runtime and self.runtime.byPet or {}) do
        for key, record in pairs(bucket.records or {}) do
            if recordUntil(record) <= at then bucket.records[key] = nil end
        end
        for key, record in pairs(bucket.observedEffects or {}) do
            if record.expiresAt and record.expiresAt <= at then
                bucket.observedEffects[key] = nil
            end
        end
        if not next(bucket.records or {}) and not next(bucket.observedEffects or {}) then
            self.runtime.byPet[petGuid] = nil
        end
    end
end

local function install(pet, name, effect, remaining, source, observed)
    pet.combatEffects = pet.combatEffects or {}
    pet.combatEffects[effectKey(name, effect)] = {
        remaining = remaining, duration = tonumber(effect.duration),
        damageMultiplier = tonumber(effect.damageMultiplier) or 1,
        threatMultiplier = tonumber(effect.threatMultiplier) or 1,
        crowdControlImmune = effect.crowdControlImmune and true or false,
        sourceSpellId = effect.sourceSpellId,
        source = source, observed = observed and true or false,
        runtimeProjected = not observed and true or false,
        runtimeUnverified = effect.runtimeUnverified and true or false }
end

local function mergeConfirmed(pet, record, at)
    if not record.confirmedAt then return end
    local i, effect, remaining
    for i = 1, table.getn(record.effects or {}) do
        effect = record.effects[i]
        remaining = record.confirmedAt + (tonumber(effect.duration) or 0) - at
        if remaining > 0 then install(pet, record.actionName, effect,
            remaining, "confirmed cast projection", false) end
    end
    if not record.deferred or record.consumedAt then return end
    remaining = record.confirmedAt + record.deferred.duration - at
    if remaining <= 0 then return end
    pet.pendingMeleeEffects = pet.pendingMeleeEffects or {}
    effect = record.deferred
    pet.pendingMeleeEffects[record.actionName] = {
        remaining = remaining, duration = effect.duration,
        targetGuid = record.targetGuid, stunDuration = effect.stunDuration,
        resultSpellIds = effect.resultSpellIds, resultSpellId = effect.resultSpellId,
        threatBase = effect.threatBase, threatLevel = effect.threatLevel,
        threatPerLevel = effect.threatPerLevel,
        source = "confirmed cast projection", confirmedCast = true,
        liveAuraKnown = false, runtimeProjected = true,
        runtimeUnverified = effect.runtimeUnverified }
end

local function mergeLiveAuras(pet)
    local encounter = XelAssist.Game and XelAssist.Game.Encounter
    local auras = encounter and encounter.Auras
        and encounter:Auras("pet", "HELPFUL") or nil
    local i, aura, spec, effect, remaining
    for i = 1, table.getn(auras and auras.list or {}) do
        aura, spec = auras.list[i], OBSERVED_EFFECTS[tonumber(auras.list[i].spellId)]
        if spec then
            effect = copy(spec)
            effect.sourceSpellId = tonumber(aura.spellId)
            remaining = tonumber(aura.remaining)
            if remaining ~= nil then remaining = math.max(0, remaining) end
            install(pet, spec.name, effect, remaining, "live pet aura", true)
        end
    end
end

function R:Merge(pet)
    if not (pet and pet.guid) then return pet end
    local at = now()
    self:Prune(at)
    local bucket = bucketFor(self, pet.guid, false)
    local _, record, remaining = nil, nil, nil
    for _, record in pairs(bucket and bucket.records or {}) do
        mergeConfirmed(pet, record, at)
    end
    for _, record in pairs(bucket and bucket.observedEffects or {}) do
        remaining = record.expiresAt and record.expiresAt - at or nil
        if remaining == nil or remaining > 0 then install(pet,
            record.name, record.effect, remaining, record.source, true) end
    end
    mergeLiveAuras(pet)
    local effects = XelAssist.Game.Pets.Effects
    if effects then
        pet.damageMultiplier = effects:DamageMultiplier(pet)
        pet.threatMultiplier = effects:ThreatMultiplier(pet)
    end
    return pet
end

function R:ObserveAura(spellId, casterGuid, targetGuid, durationMs, capped)
    spellId = tonumber(spellId)
    if capped then return false end
    if spellId == 24394 then
        return self:ConsumeMelee(casterGuid, targetGuid,
            "observed Intimidation result")
    end
    local spec, petGuid = OBSERVED_EFFECTS[spellId], unitGuid("pet")
    if not (spec and petGuid and targetGuid == petGuid) then return false end
    local duration = tonumber(durationMs)
    duration = duration and duration > 0 and duration / 1000 or spec.duration
    local bucket, effect = bucketFor(self, petGuid, true), copy(spec)
    effect.sourceSpellId = spellId
    bucket.observedEffects[effectKey(spec.name, effect)] = {
        name = spec.name, effect = effect, observedAt = now(),
        expiresAt = duration and now() + duration or nil,
        source = "live pet aura event", casterGuid = casterGuid }
    return true
end

function R:ConsumeMelee(petGuid, targetGuid, source)
    local bucket = bucketFor(self, petGuid, false)
    if not bucket then return false end
    local at, _, record, chosen = now(), nil, nil, nil
    for _, record in pairs(bucket.records or {}) do
        if record.confirmedAt and record.deferred and not record.consumedAt
            and record.targetGuid == targetGuid
            and record.confirmedAt + record.deferred.duration > at
            and (not chosen or record.confirmedAt > chosen.confirmedAt) then
            chosen = record
        end
    end
    if not chosen then return false end
    chosen.consumedAt, chosen.consumptionSource = at, source
    return true
end

function R:ObserveAutoAttack(petGuid, targetGuid, result)
    if not (result and result.actor == "pet" and result.evidence == "hit") then
        return false
    end
    return self:ConsumeMelee(petGuid, targetGuid,
        "observed successful pet auto attack")
end

function R:ObserveSpellDamage(targetGuid, casterGuid, spellId, observed, amount)
    if not (casterGuid and casterGuid == unitGuid("pet") and observed
        and not observed.periodic and not observed.phaseUnknown) then return false end
    local name = SpellInfo and SpellInfo(spellId) or nil
    local facts = XelAssist.Combat.PetKnowledge
        and XelAssist.Combat.PetKnowledge:Facts(spellId, name, "HUNTER") or nil
    local melee = tonumber(spellId) == 41828 or tonumber(spellId) == 24394
        or facts and facts.melee
    if not melee or math.max(0, tonumber(amount) or 0,
        tonumber(observed.basis) or 0) <= 0 then return false end
    return self:ConsumeMelee(casterGuid, targetGuid,
        "observed successful pet melee ability")
end

function R:IdentityChanged(previousGuid, currentGuid)
    if previousGuid == nil or previousGuid == currentGuid
        or not (self.runtime and self.runtime.byPet) then return end
    self.runtime.byPet[previousGuid] = nil
end

R:Reset()
