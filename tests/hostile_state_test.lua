XelAssist = { Game = {}, Combat = {}, Graph = {} }
XelAssistCharDB = { role = "damage", toggles = {
    petActions = true, consumables = true, cooldowns = true,
    reagents = true, petControl = true } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local selectedGuid = { value = "opaque-selected" }
local otherGuid = { value = "opaque-other" }
local playerGuid = { value = "opaque-player" }
local petGuid = { value = "opaque-pet" }
local selectedCurse = { name = "Curse of Elements", remaining = 18,
    duration = 30, sourceGUID = playerGuid, mine = true, points = { 75 } }
local otherCurse = { name = "Curse of Elements", remaining = 7,
    duration = 30, sourceGUID = playerGuid, mine = true }
local otherFear = { name = "Fear", remaining = 5, duration = 10,
    sourceGUID = playerGuid, mine = true }

local function auraWrapper(list)
    local byName, i = {}, nil
    for i = 1, table.getn(list) do byName[list[i].name] = list[i] end
    return { available = true, list = list, byName = byName }
end

local selectedHarmful = auraWrapper({ selectedCurse })
local otherHarmful = auraWrapper({ otherCurse, otherFear })
local selectedHelpful = auraWrapper({})
local otherHelpful = auraWrapper({})
local selectedRecord = {
    key = selectedGuid, guid = selectedGuid, unit = "target", source = "selected",
    selected = true, executable = true, dead = false,
    health = 700, healthMax = 1000, healthExact = true,
    survival = { available = true, incomingDps = 100, timeToDie = 7,
        lowerTimeToDie = 5.25, upperTimeToDie = 9.45,
        observedFor = 3, samples = 7, confidence = "observed" },
    distance = 18, distanceKind = "exact", lineOfSight = true, behind = false,
    geometry = { pet = { distance = 2, distanceKind = "exact",
        lineOfSight = true, behind = false } },
    casting = true, castRemaining = 1.75,
    harmfulAuras = selectedHarmful, helpfulAuras = selectedHelpful,
    victim = { available = true, guid = playerGuid },
    hasPlayerAggro = true, hasPetAggro = false,
    encounter = { guid = selectedGuid, level = 42, creatureType = "Demon" },
    targetRef = { unit = "target", guid = selectedGuid,
        relation = "hostile", source = "selected" },
}
local otherRecord = {
    key = otherGuid, guid = otherGuid, unit = "mouseover", source = "mouseover",
    selected = false, executable = false, dead = false,
    health = 320, healthMax = 800, healthExact = false,
    survival = { available = false, reason = "exact hostile health unavailable" },
    distance = 9, distanceKind = "estimated", lineOfSight = nil, behind = nil,
    geometry = { pet = { distance = 4, distanceKind = "exact",
        lineOfSight = true, behind = true } },
    casting = false, castRemaining = nil,
    harmfulAuras = otherHarmful, helpfulAuras = otherHelpful,
    victim = { available = true, guid = petGuid },
    hasPlayerAggro = false, hasPetAggro = true,
    encounter = { guid = otherGuid, level = 40, creatureType = "Beast" },
    targetRef = { unit = "mouseover", guid = otherGuid,
        relation = "hostile", source = "mouseover" },
}
local observedHostiles = {
    order = { selectedGuid, otherGuid },
    byKey = { [selectedGuid] = selectedRecord, [otherGuid] = otherRecord },
    byUnit = { target = selectedGuid, mouseover = otherGuid },
    selectedKey = selectedGuid, total = 2, capped = false,
    location = { zone = "Test Zone", subZone = "Test Cave",
        minimapZone = "Test Map", inInstance = true, instanceType = "party" },
}

local actions = {
    { name = "Curse of Elements", facts = {
        kind = "debuff", exclusiveFamily = "warlock:curse" } },
    { name = "Fear", facts = { kind = "crowdControl" } },
}
XelAssist.Game.Actors = {
    Snapshot = function() return { player = {}, pet = { guid = petGuid,
        distance = 2, distanceKind = "exact", lineOfSight = true,
        behind = false, hasAggro = false } } end,
    Actions = function() return actions end,
    Facts = function(_, action) return action.tooltip or {} end,
}
XelAssist.Game.Encounter = {
    Snapshot = function()
        return { zone = "Test Zone", target = selectedRecord.encounter,
            targetHarmful = selectedHarmful, targetHelpful = selectedHelpful }
    end,
}
XelAssist.Game.Hostiles = {
    Snapshot = function() return observedHostiles end,
}
XelAssist.Game.Inventory = {
    Snapshot = function() return { itemCounts = {} } end,
    Blocker = function() return nil end,
}
XelAssist.Game.Friendlies = { Snapshot = function() return nil end }
XelAssist.Game.Capabilities = {
    CurrentCast = function() return nil, 0, false, 0, false end,
    Distance = function(_, unit)
        if unit == "player" then return 0, "self" end
        return nil, nil
    end,
    Geometry = function() return { lineOfSight = nil, behind = nil } end,
    Health = function() return 0, 0, false end,
    TalentPoints = function() return {} end,
    UnitHasBuff = function() return false end,
    GCDRemaining = function() return 0 end,
    Usable = function() return true end,
    CastName = function(_, action) return action.name end,
    InRange = function() return true end,
}

local resistanceCalls = {}
XelAssist.Combat.Resistance = {
    Snapshot = function(_, unit, encounter)
        assert(encounter.target and encounter.target.guid,
            "per-hostile resistance context must include target identity")
        assert(encounter.targetHarmful == (unit == "target"
                and selectedHarmful or otherHarmful),
            "per-hostile resistance context must use that hostile's observed auras")
        table.insert(resistanceCalls, { unit = unit, encounter = encounter })
        return { identity = { guid = encounter.target.guid,
                level = encounter.target.level },
            live = { [3] = unit == "target" and 50 or 20 },
            nested = { marker = unit } }
    end,
}
XelAssist.Combat.TargetModifiers = {
    AggregateReductions = function(_, effects)
        local out, count, _, effect = {}, 0, nil, nil
        for _, effect in pairs(effects or {}) do
            local school, amount
            for school, amount in pairs(effect.resistanceReduction or {}) do
                out[school] = (out[school] or 0) + amount
            end
        end
        for _ in pairs(out) do count = count + 1 end
        return count > 0 and out or nil
    end,
    AggregateDamageTaken = function(_, effects, base)
        local out, count, school, amount = {}, 0, nil, nil
        for school, amount in pairs(base or {}) do out[school] = amount end
        local _, effect
        for _, effect in pairs(effects or {}) do
            for school, amount in pairs(effect.damageTaken or {}) do
                out[school] = (1 + (out[school] or 0)) * (1 + amount) - 1
            end
        end
        for _ in pairs(out) do count = count + 1 end
        return count > 0 and out or nil
    end,
    Active = function(_, encounter, resistance)
        local unit = encounter.target.unit or encounter.target.id
            or (encounter.target.guid == selectedGuid and "target" or "mouseover")
        local amount = encounter.target.guid == selectedGuid and 0.11 or 0.04
        local effect = { name = "Curse of Elements", remaining = unit == "target" and 18 or 7,
            resistanceReduction = { [3] = unit == "target" and 75 or 30 },
            damageTaken = { [3] = amount },
            sourceGUID = encounter.target.guid }
        return { [3] = effect.resistanceReduction[3] }, { [3] = amount },
            "Curse of Elements", { ["Curse of Elements"] = effect },
            { ["Curse of Elements"] = { remaining = effect.remaining,
                targetModifier = true, nested = { unit = unit },
                points = encounter.targetHarmful.byName["Curse of Elements"].points } }
    end,
}

local now = 100
GetTime = function() return now end
PlayerIsMoving = function() return false end
UnitExists = function(unit)
    if unit == "target" then return true, selectedGuid end
    if unit == "player" then return true, playerGuid end
    return false, nil
end
UnitHealth = function(unit) return unit == "player" and 900 or 0 end
UnitHealthMax = function(unit) return unit == "player" and 1000 or 0 end
UnitMana = function() return 600 end
UnitManaMax = function() return 1000 end
UnitPowerType = function() return 0 end
UnitLevel = function() return 40 end
UnitAffectingCombat = function() return true end
GetComboPoints = function() return 0 end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
UnitClass = function() return "Warlock", "WARLOCK" end
GetShapeshiftForm = function() return 0 end
UnitCreatureType = function() return "Demon" end

dofile("Game/SpatialEvidence.lua")
dofile("Graph/HostileState.lua")
dofile("Graph/State.lua")

local state = XelAssist.Graph.State:Snapshot("smart")
local selected = XelAssist.Graph.State:SelectedHostile(state)
local other = XelAssist.Graph.State:HostileByUnit(state, "mouseover")
assert(state.hostiles == observedHostiles and selected == selectedRecord
    and other == otherRecord,
    "graph snapshot must retain and enrich the bounded hostile snapshot")
assert(XelAssist.Graph.State:HostileByKey(state, selectedGuid) == selected
    and XelAssist.Graph.State:HostileByUnit(state, "target") == selected,
    "opaque hostile key and unit lookups must resolve the same record")
assert(table.getn(resistanceCalls) == 2
    and resistanceCalls[1].unit == "target"
    and resistanceCalls[2].unit == "mouseover",
    "resistance evidence must be sampled for each retained hostile token")

assert(state.targetGUID == selectedGuid and state.targetHealth == 700
    and state.targetMax == 1000 and state.targetHealthExact
    and state.targetSurvival == selected.survival
    and state.targetSurvival.timeToDie == 7
    and state.targetCreatureType == "Demon"
    and state.targetDistance == 18 and state.targetDistanceKind == "exact"
    and state.targetLineOfSight == true and state.playerBehindTarget == false,
    "selected hostile scalars must populate the legacy execution view")

assert(state.targetCasting and state.targetCastRemaining == 1.75
    and state.targetCastProbability == 1 and state.hasAggro,
    "cast and threat evidence must stay local to the selected hostile")
assert(other.castProbability == 0 and other.threat.playerHasAggro == false
    and other.threat.petHasAggro == true and other.threat.victimGuid == petGuid,
    "off-target cast and threat evidence must not inherit selected facts")
assert(selected.resistance.identity.guid == selectedGuid
    and selected.resistances[3] == 50 and other.resistances[3] == 20
    and selected.damageTaken[3] == 0.11 and other.damageTaken[3] == 0.04,
    "health-independent resistance and modifier state must be per hostile")

assert(selected.targetAuras["Curse of Elements"] ~= selectedCurse
    and selected.targetAuras["Curse of Elements"].exclusiveFamily == "warlock:curse"
    and selected.targetAuras["Curse of Elements"].points ~= selectedCurse.points
    and selected.projectedAuras["Curse of Elements"].points ~= selectedCurse.points
    and selected.targetAuras["Curse of Elements"].sourceGUID == playerGuid
    and selectedCurse.exclusiveFamily == nil,
    "mutable observed aura state must be graph-owned, not the raw aura wrapper")
assert(other.control.active and other.control.remaining == 5
    and other.control.byName.Fear == other.targetAuras.Fear
    and not selected.control.active,
    "crowd-control state must refer to each record's graph-owned observed auras")
assert(selected.projectedAuras["Curse of Elements"].target == "target"
    and selected.projectedAuras["Curse of Elements"].targetKey == selectedGuid
    and other.projectedAuras["Curse of Elements"].target == "mouseover"
    and other.projectedAuras["Curse of Elements"].targetKey == otherGuid,
    "projected target modifiers must carry their actual recipient identity")

assert(state.targetAuras == selected.targetAuras
    and state.auras == selected.projectedAuras
    and state.targetResistance == selected.resistance
    and state.targetResistances == selected.resistances
    and state.targetDamageTaken == selected.damageTaken
    and state.baseTargetDamageTaken == selected.baseDamageTaken
    and state.targetModifierEffects == selected.modifierEffects,
    "selected legacy table mirrors must alias authoritative record tables")
state.auras.Projected = { remaining = 3 }
state.targetAuras.Observed = { remaining = 2 }
state.targetDamageTaken[4] = 0.25
assert(selected.projectedAuras.Projected and selected.targetAuras.Observed
    and selected.damageTaken[4] == 0.25,
    "existing graph table mutations must update the selected record immediately")

local otherContext = XelAssist.Graph.State:HostileContext(state, otherGuid)
assert(otherContext and otherContext ~= state and otherContext.targetContextKey == otherGuid
    and otherContext.targetGUID == otherGuid and otherContext.targetHealth == 320
    and otherContext.targetSurvival == other.survival
    and otherContext.hostile and state.targetGUID == selectedGuid
    and state.targetContextKey == nil,
    "off-target contexts must be detached scalar views without changing selection")
assert(otherContext.targetAuras == other.targetAuras
    and otherContext.auras == other.projectedAuras
    and otherContext.targetResistance == other.resistance
    and otherContext.targetDamageTaken == other.damageTaken
    and otherContext.baseTargetDamageTaken == other.baseDamageTaken
    and otherContext.targetModifierEffects == other.modifierEffects
    and otherContext.encounter == other.context,
    "off-target compatibility contexts must mirror only that hostile's tables")
assert(otherContext.actors ~= state.actors
    and otherContext.actors.pet ~= state.actors.pet
    and otherContext.actors.pet.distance == 4
    and otherContext.actors.pet.behind == true
    and state.actors.pet.distance == 2 and state.actors.pet.behind == false,
    "off-target pet delivery must use a detached recipient-local geometry view")
assert(XelAssist.Graph.State:HostileContext(state, {}) == nil,
    "an unknown opaque identity must not manufacture a hostile context")

local copiedContext = XelAssist.Graph.State:Copy(otherContext)
local copiedContextRecord = XelAssist.Graph.State:HostileByKey(
    copiedContext, otherGuid)
assert(copiedContext.targetContextKey == otherGuid
    and copiedContext.targetGUID == otherGuid
    and copiedContext.targetHealth == other.health
    and copiedContext.hostiles.selectedKey == selectedGuid,
    "copying an off-target context must preserve its recipient without reselection")
assert(copiedContext.targetAuras == copiedContextRecord.targetAuras
    and copiedContext.auras == copiedContextRecord.projectedAuras
    and copiedContext.targetResistance == copiedContextRecord.resistance
    and copiedContext.targetDamageTaken == copiedContextRecord.damageTaken
    and copiedContext.baseTargetDamageTaken == copiedContextRecord.baseDamageTaken
    and copiedContext.targetModifierEffects == copiedContextRecord.modifierEffects
    and copiedContext.encounter == copiedContextRecord.context,
    "copied impact contexts must mirror the copied off-target record tables")

copiedContextRecord.casting = nil
copiedContextRecord.castProbability = nil
copiedContextRecord.threat.playerHasAggro = nil
copiedContextRecord.hasPlayerAggro = nil
XelAssist.Graph.HostileState:SyncContext(copiedContext, otherGuid)
assert(copiedContext.targetCasting == nil
    and copiedContext.targetCastProbability == nil
    and copiedContext.hasAggro == nil,
    "unavailable cast and victim facts must stay unknown in a hostile context")

selected.health = 612
assert(state.targetHealth == 700,
    "legacy scalar mirrors must be one-way until explicitly synchronized")
XelAssist.Graph.State:SyncSelectedHostile(state)
assert(state.targetHealth == 612 and state.targetGUID == selectedGuid,
    "selected scalar synchronization must refresh from the authoritative record")

local threatProjection = XelAssist.Graph.State:Copy(state)
local threatRecord = XelAssist.Graph.State:SelectedHostile(threatProjection)
threatProjection.actors.pet = { guid = petGuid, hasAggro = false }
threatProjection.hasAggro = false
threatProjection.actors.pet.hasAggro = true
XelAssist.Graph.State:CommitActiveHostile(threatProjection)
XelAssist.Graph.State:SyncSelectedHostile(threatProjection)
assert(selectedRecord.hasPlayerAggro == true
    and threatRecord.threat.playerHasAggro == true
    and threatRecord.threat.petHasAggro == false
    and threatRecord.threat.projectedPlayerHasAggro == false
    and threatProjection.hasAggro == false,
    "projected victim changes must survive sync without rewriting live evidence")
threatRecord.threat.projectedPetHasAggro = true
XelAssist.Graph.State:SyncSelectedHostile(threatProjection)
assert(threatProjection.actors.pet.hasAggro == true,
    "selected companion aggro projections must survive compatibility sync")

local copy = XelAssist.Graph.State:Copy(state)
local copiedSelected = XelAssist.Graph.State:SelectedHostile(copy)
local copiedOther = XelAssist.Graph.State:HostileByKey(copy, otherGuid)
assert(copy ~= state and copy.hostiles ~= state.hostiles
    and copiedSelected ~= selected and copiedOther ~= other,
    "graph copies must isolate hostile records and their collection")
assert(copy.hostiles.selectedKey == selectedGuid
    and copy.hostiles.order[1] == selectedGuid
    and copiedSelected.guid == selectedGuid and copiedOther.guid == otherGuid
    and copy.hostiles.byKey[selectedGuid] == copiedSelected,
    "graph copies must preserve opaque table identity in values and table keys")
assert(copiedSelected.resistance ~= selected.resistance
    and copiedSelected.resistance.identity.guid == selectedGuid
    and copiedSelected.harmfulAuras ~= selected.harmfulAuras
    and copiedSelected.harmfulAuras.byName["Curse of Elements"].sourceGUID == playerGuid,
    "nested hostile evidence must be isolated without cloning opaque GUID values")
assert(copy.targetAuras == copiedSelected.targetAuras
    and copy.auras == copiedSelected.projectedAuras
    and copy.targetResistance == copiedSelected.resistance
    and copy.targetResistances == copiedSelected.resistances
    and copy.targetDamageTaken == copiedSelected.damageTaken
    and copy.baseTargetDamageTaken == copiedSelected.baseDamageTaken
    and copy.targetModifierEffects == copiedSelected.modifierEffects
    and copy.targetSurvival == copiedSelected.survival
    and copy.targetSurvival ~= selected.survival,
    "copied selected mirrors must alias the copied record, never the source record")

copiedSelected.health = 111
copy.targetAuras.CopyOnly = { remaining = 1 }
copiedOther.resistance.live[3] = 999
copiedOther.control.byName.Fear.remaining = 1
assert(selected.health == 612 and selected.targetAuras.CopyOnly == nil
    and other.resistance.live[3] == 20 and other.control.byName.Fear.remaining == 5,
    "mutating a projected graph copy must not alter source hostile state")

copy.hostiles.selectedKey = nil
copiedSelected.selected = false
copiedOther.selected = false
XelAssist.Graph.State:SyncSelectedHostile(copy)
assert(not copy.hostile and copy.targetGUID == nil and copy.targetHealth == 0
    and copy.targetResistance == nil and copy.targetDamageTaken == nil
    and copy.targetCasting == nil and copy.hasAggro == nil,
    "synchronizing without a selection must clear stale legacy target state")

local stringSelected = { key = "target-guid", guid = "target-guid",
    unit = "target", selected = true, dead = false, health = 500,
    healthMax = 500, healthExact = true, targetAuras = {}, projectedAuras = {},
    resistance = { identity = { guid = "target-guid" }, live = {} },
    resistances = {}, damageTaken = {}, baseDamageTaken = {},
    modifierEffects = {}, threat = { playerHasAggro = false },
    targetRef = { unit = "target", guid = "target-guid",
        relation = "hostile", source = "selected" } }
stringSelected.resistance.live = stringSelected.resistances
local stringAlly = { key = "g:ally-guid", guid = "ally-guid",
    unit = "party1", health = 400, healthMax = 500,
    auras = {}, absorbs = {} }
local stringState = { hostiles = { order = { "target-guid" },
        byKey = { ["target-guid"] = stringSelected },
        byUnit = { target = "target-guid" }, selectedKey = "target-guid" },
    friendlies = { order = { "g:ally-guid" },
        byKey = { ["g:ally-guid"] = stringAlly },
        byUnit = { party1 = "g:ally-guid" }, primaryKey = "g:ally-guid" },
    targetContextKey = nil, auras = stringSelected.projectedAuras,
    targetAuras = stringSelected.targetAuras,
    targetResistance = stringSelected.resistance,
    targetResistances = stringSelected.resistances,
    targetDamageTaken = stringSelected.damageTaken,
    baseTargetDamageTaken = stringSelected.baseDamageTaken,
    targetModifierEffects = stringSelected.modifierEffects,
    absorbs = {}, readyAt = {}, actorReadyAt = {} }
local stringCopy = XelAssist.Graph.State:Copy(stringState)
local stringCopiedHostile = stringCopy.hostiles.byKey["target-guid"]
local stringCopiedAlly = stringCopy.friendlies.byKey["g:ally-guid"]
stringCopiedHostile.health = 100
stringCopiedHostile.targetAuras.Dot = { remaining = 4 }
stringCopiedAlly.health = 50
assert(stringCopiedHostile ~= stringSelected and stringCopiedAlly ~= stringAlly
    and stringSelected.health == 500 and stringSelected.targetAuras.Dot == nil
    and stringAlly.health == 400,
    "identity-map keys ending in guid must not make transition records atomic")

XelAssist.Graph.HostileEffects = {
    ApplySelectedDamage = function(_, value, amount)
        if not value.targetHealthExact then return false end
        value.targetHealth = math.max(0,
            value.targetHealth - math.max(0, tonumber(amount) or 0))
        return true
    end,
    Apply = function() return false end,
    FinalizeSelected = function() end,
}
dofile("Graph/Effects.lua")
dofile("Graph/EventAuras.lua")
dofile("Graph/ReadinessEffects.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/DotProjection.lua")
dofile("Graph/ComboEffects.lua")
dofile("Graph/ActionEffects.lua")

local modifierName = "Shadow Vulnerability"
local modifierAction = { name = modifierName, actor = "player",
    facts = { kind = "debuff", modifierGroup = modifierName } }
local modifierFacts = { duration = 5, targetDamageTaken = { [3] = 0.20 } }
local function transitionCandidate(action, tooltip, power)
    return { action = action, tooltip = tooltip, target = "target",
        targetGUID = selectedGuid, targetKey = selectedGuid,
        targetRelation = "hostile", effectDelivery = 1,
        power = power or 0, cost = 0, occupancy = 0, cast = 0,
        wait = 0, downtime = 0, actionStart = 0 }
end

local modifierSource = XelAssist.Graph.State:Copy(state)
local modifierOut = XelAssist.Graph.State:Copy(modifierSource)
local modifierCandidate = transitionCandidate(
    modifierAction, modifierFacts, 0)
local modifierContext = XelAssist.Graph.ActionEffects:Context(
    modifierSource, modifierCandidate)
XelAssist.Graph.ActionEffects:Apply(
    modifierOut, modifierSource, modifierCandidate, modifierContext)
local modifierRecord = XelAssist.Graph.State:SelectedHostile(modifierOut)
local sourceModifierRecord = XelAssist.Graph.State:SelectedHostile(modifierSource)
local otherModifierRecord = XelAssist.Graph.State:HostileByKey(
    modifierOut, otherGuid)
assert(modifierRecord.modifierEffects[modifierName]
    and modifierRecord.projectedAuras[modifierName]
    and modifierOut.targetModifierEffects == modifierRecord.modifierEffects
    and modifierOut.targetDamageTaken == modifierRecord.damageTaken
    and modifierOut.auras == modifierRecord.projectedAuras
    and math.abs(modifierOut.targetDamageTaken[3] - 0.332) < 0.0001,
    "a projected hostile debuff must commit reassigned modifier roots to its record")
assert(not sourceModifierRecord.modifierEffects[modifierName]
    and not sourceModifierRecord.projectedAuras[modifierName]
    and not otherModifierRecord.modifierEffects[modifierName],
    "a selected debuff transition must isolate its source and every other hostile")

local damageDecision = XelAssist.Graph.Effects:Decision(
    { school = 3, multiplier = 1, landChance = 1 }, modifierOut, true)
local damageAction = { name = "Shadow Damage", actor = "player",
    facts = { kind = "damage" } }
local damageCandidate = transitionCandidate(
    damageAction, { school = 3 }, 100 * damageDecision)
local afterDamage = XelAssist.Graph.State:Copy(modifierOut)
local damageContext = XelAssist.Graph.ActionEffects:Context(
    modifierOut, damageCandidate)
XelAssist.Graph.ActionEffects:Apply(
    afterDamage, modifierOut, damageCandidate, damageContext)
local damagedRecord = XelAssist.Graph.State:SelectedHostile(afterDamage)
assert(math.abs(damageDecision - 1.332) < 0.0001
    and math.abs(damagedRecord.health
        - (modifierRecord.health - 100 * damageDecision)) < 0.0001
    and afterDamage.targetHealth == damagedRecord.health
    and damagedRecord.modifierEffects[modifierName],
    "damage after a debuff must consume the retained recipient-local modifier")
assert(sourceModifierRecord.health == 612
    and not sourceModifierRecord.modifierEffects[modifierName]
    and not otherModifierRecord.modifierEffects[modifierName],
    "debuff and damage transitions must not mutate their source or off-target record")

local expired = XelAssist.Graph.Effects:StateAtImpact(afterDamage, 6)
local expiredRecord = XelAssist.Graph.State:SelectedHostile(expired)
local expiredDecision = XelAssist.Graph.Effects:Decision(
    { school = 3, multiplier = 1, landChance = 1 }, expired, true)
assert(not expired.targetModifierEffects[modifierName]
    and not expired.auras[modifierName]
    and not expiredRecord.modifierEffects[modifierName]
    and not expiredRecord.projectedAuras[modifierName]
    and expired.targetModifierEffects == expiredRecord.modifierEffects
    and expired.targetDamageTaken == expiredRecord.damageTaken
    and math.abs(expired.targetDamageTaken[3] - 0.11) < 0.0001
    and math.abs(expiredDecision - 1.11) < 0.0001,
    "modifier expiration must commit removal and restore the prior damage model")
assert(afterDamage.targetModifierEffects[modifierName]
    and afterDamage.auras[modifierName],
    "impact-time expiration must remain isolated from its source transition")

local canonicalRef = modifierRecord.targetRef
modifierOut.targetRef = { unit = "mouseover", guid = selectedGuid,
    relation = "hostile", source = "forged" }
XelAssist.Graph.State:CommitActiveHostile(modifierOut)
assert(modifierRecord.targetRef == canonicalRef
    and modifierOut.targetRef == canonicalRef,
    "committing mutable roots must rebind the canonical observation target reference")
local guarded = XelAssist.Graph.State:Copy(modifierSource)
local guardedRecord = XelAssist.Graph.State:SelectedHostile(guarded)
guarded.targetGUID = otherGuid
guarded.targetDamageTaken = { [3] = 9 }
XelAssist.Graph.State:CommitActiveHostile(guarded)
assert(guardedRecord.damageTaken[3] == 0.11,
    "a selected key and root GUID mismatch must refuse an authoritative commit")

local offSource = XelAssist.Graph.State:HostileContext(
    modifierSource, otherGuid)
local offOut = XelAssist.Graph.State:Copy(offSource)
XelAssist.Graph.Effects:ApplyTargetModifier(
    offOut, modifierAction, modifierFacts, offSource, 1)
offOut.auras[modifierName] = { remaining = 5, duration = 5,
    mine = true, target = "mouseover", targetKey = otherGuid,
    targetModifier = true }
XelAssist.Graph.State:CommitActiveHostile(offOut)
local offRecord = XelAssist.Graph.State:HostileByKey(offOut, otherGuid)
local offSelected = XelAssist.Graph.State:SelectedHostile(offOut)
assert(offOut.targetContextKey == otherGuid and offOut.targetGUID == otherGuid
    and offRecord.modifierEffects[modifierName]
    and offRecord.projectedAuras[modifierName]
    and math.abs(offRecord.damageTaken[3] - 0.248) < 0.0001
    and not offSelected.modifierEffects[modifierName]
    and not XelAssist.Graph.State:HostileByKey(
        modifierSource, otherGuid).modifierEffects[modifierName],
    "an off-target commit must persist only in its explicit hostile context")
local offExpired = XelAssist.Graph.Effects:StateAtImpact(offOut, 6)
local offExpiredRecord = XelAssist.Graph.State:HostileByKey(
    offExpired, otherGuid)
assert(offExpired.targetContextKey == otherGuid
    and not offExpiredRecord.modifierEffects[modifierName]
    and not offExpiredRecord.projectedAuras[modifierName]
    and math.abs(offExpiredRecord.damageTaken[3] - 0.04) < 0.0001,
    "off-target expiration must commit back to the same hostile and nowhere else")

selectedRecord.lineOfSight = false
XelAssist.Graph.State:Snapshot("smart")
now = 100.05
selectedRecord.lineOfSight, selectedRecord.behind = true, true
local spatialState = XelAssist.Graph.State:Snapshot("smart")
XelAssist.Graph.State:SyncSelectedHostile(spatialState)
assert(spatialState.targetLineOfSight == false
    and spatialState.playerBehindTarget == false,
    "selected-hostile synchronization must preserve settled LOS and behind evidence")

XelAssist.Graph.TargetSelection = {
    VariableFriendlyAction = function() return false end,
    Targets = function() return {} end,
}
XelAssist.Graph.ActionAdmission = {
    Start = function() return 0, nil end,
    Readiness = function() return nil end,
}
dofile("Game/Range.lua")
dofile("Graph/SpatialRequirements.lua")
dofile("Graph/Targets.lua")
local spatialAction = { name = "Backstab", actor = "player", executor = "spell",
    rank = 1, facts = { kind = "damage", behind = true },
    tooltip = { minRange = 0, maxRange = 5 } }
local spatialDescriptor = XelAssist.Graph.State:Descriptor(
    "target", "hostile", "selected", selectedGuid, selectedGuid, selectedRecord)
local legal, reason = XelAssist.Graph.Targets:Legal(
    spatialAction, spatialState, spatialDescriptor)
assert(not legal and reason == "line of sight",
    "selected target legality must not replace settled LOS with its raw record")
spatialState.spatialTargetLineOfSight = true
XelAssist.Graph.State:SyncSelectedHostile(spatialState)
legal, reason = XelAssist.Graph.Targets:Legal(
    spatialAction, spatialState, spatialDescriptor)
assert(not legal and reason == "must be behind target",
    "selected target legality must retain settled behind evidence after sync")

print("ok: target-local hostile graph state, compatibility aliases and copy isolation")
