XelAssist = { Game = { Player = {}, Caster = {} }, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
UIParent = {}
XelAssistCharDB = { role = "damage", toggles = { cooldowns = true,
    petActions = true, consumables = true, reagents = true, petControl = true } }

local playerClass, learnedName, learnedSpellId = "PALADIN", "Judgement", 20271
local playerGUID, playerKey = {}, {}
local paladinRecords = {
    [20154] = { family = 10, flags = 134217728 },
    [20375] = { family = 10, flags = 33554432 },
    [20271] = { family = 10, flags = 8388608 },
    [5002] = { family = 10, flags = 402653184 },
    [879] = { family = 10, flags = 0 },
    [635] = { family = 10, flags = 0 },
}
UnitClass = function() return "Localized class", playerClass end
GetSpellRecField = function(spellId, field)
    local row = paladinRecords[spellId]
    if not row then return nil end
    if field == "spellFamilyName" then return row.family end
    if field == "spellFamilyFlags" then return row.flags end
    return nil
end
GetSpellName = function(slot)
    if slot == 1 then return learnedName, "Rank 1" end
    return nil
end
GetSpellSlotTypeIdForName = function() return 1, BOOKTYPE_SPELL, learnedSpellId end
IsPassiveSpell = function() return false end

XelAssist.Game.SpellSemantics = {}
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    if spellId == 9003 then
        return { complete = false, admissible = false,
            reasons = { "trigger unresolved" },
            atoms = { { kind = "summon", summonType = "totemSlot1" } } }
    end
    if spellId ~= 1535 then
        return { complete = false, admissible = false,
            reasons = { "spell record unavailable" }, atoms = {} }
    end
    return { complete = true, admissible = true, reasons = {},
        atoms = { { kind = "summon", summonType = "totemSlot1" } } }
end
GetSpellDuration = function(spellId)
    assert(spellId == 1535)
    return 5000
end

dofile("Combat/Knowledge.lua")
dofile("Game/Player/PaladinAuraState.lua")
dofile("Game/Player/PaladinActions.lua")
dofile("Game/Player/TotemState.lua")
dofile("Game/Player/ShamanActions.lua")
dofile("Game/ActionInference.lua")
dofile("Game/CapabilityInvalidation.lua")
dofile("Game/Capabilities.lua")

local paladinCatalogue = XelAssist.Game.Capabilities:Actions()
assert(table.getn(paladinCatalogue) == 1
    and XelAssist.Combat.Knowledge.Judgement.kind == "damage"
    and paladinCatalogue[1].facts.kind == "judgement"
    and paladinCatalogue[1].facts.paladinJudgement
    and paladinCatalogue[1].facts.paladinClassification.exact,
    "exact Paladin identity must replace the typed Judgement catalogue shape")
learnedSpellId = 5002
XelAssist.Game.Capabilities.actions = nil
assert(table.getn(XelAssist.Game.Capabilities:Actions()) == 0,
    "conflicting exact Paladin evidence must not fall through to typed Judgement")

learnedName, learnedSpellId = "Exorcism", 879
XelAssist.Game.Capabilities.actions = nil
local ordinaryPaladin = XelAssist.Game.Capabilities:Actions()
assert(table.getn(ordinaryPaladin) == 1
    and ordinaryPaladin[1].facts.kind == "damage"
    and ordinaryPaladin[1].facts.ranged
    and not ordinaryPaladin[1].facts.paladinAction,
    "ordinary Paladin-family damage must retain typed catalogue knowledge")
learnedName, learnedSpellId = "Holy Light", 635
XelAssist.Game.Capabilities.actions = nil
ordinaryPaladin = XelAssist.Game.Capabilities:Actions()
assert(table.getn(ordinaryPaladin) == 1
    and ordinaryPaladin[1].facts.kind == "heal"
    and not ordinaryPaladin[1].facts.paladinAction,
    "ordinary Paladin-family healing must retain typed catalogue knowledge")

playerClass, learnedName, learnedSpellId = "SHAMAN", "Fire Nova Totem", 1535
XelAssist.Game.Capabilities.actions = nil
XelAssist.Game.Capabilities.spellSlots = nil
XelAssist.Game.Capabilities.spellRanks = nil
local shamanCatalogue = XelAssist.Game.Capabilities:Actions()
assert(table.getn(shamanCatalogue) == 1
    and XelAssist.Combat.Knowledge["Fire Nova Totem"].kind == "damage"
    and shamanCatalogue[1].facts.kind == "totem"
    and shamanCatalogue[1].facts.shamanTotem
    and shamanCatalogue[1].facts.shamanEffectRepresented == false,
    "exact Shaman identity must replace the typed immediate-damage shape")
learnedSpellId = 9003
XelAssist.Game.Capabilities.actions = nil
assert(table.getn(XelAssist.Game.Capabilities:Actions()) == 0,
    "recognized incomplete Shaman evidence must not fall through to typed Fire Nova")

playerClass = "PALADIN"
local sealFacts = XelAssist.Game.Player.PaladinActions:InferKnowledge(20375)
playerClass = "SHAMAN"
local fireFacts = shamanCatalogue[1].facts
local originalDBC, originalSemantics, originalDuration = GetSpellRecField,
    XelAssist.Game.SpellSemantics.Resolve, GetSpellDuration

GetTime = function() return 100 end
UnitExists = function(unit)
    if unit == "player" then return true, playerGUID end
    return false, nil
end
UnitGUID = function(unit) return unit == "player" and playerGUID or nil end
UnitCanAssist = function(_, unit) return unit == "player" end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitMana = function() return 100 end
UnitManaMax = function() return 100 end
UnitPowerType = function() return 0 end
UnitLevel = function() return 10 end
UnitAffectingCombat = function() return false end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
GetShapeshiftForm = function() return 0 end
PlayerIsMoving = function() return false end

local function friendlySnapshot()
    local record = { key = playerKey, unit = "player", relation = "self",
        guid = playerGUID, health = 100, healthMax = 100,
        healthExact = true, exact = true, auras = {}, absorbs = {} }
    return { order = { playerKey }, byKey = { [playerKey] = record },
        byUnit = { player = playerKey }, primaryKey = playerKey }
end
XelAssist.Game.Actors = {
    Snapshot = function() return { player = { unit = "player", guid = playerGUID,
        health = 100, healthMax = 100 }, allies = {}, controlled = {} } end,
    Facts = function(_, action) return { cost = 0, cast = 0, gcd = 1.5,
        duration = action.facts.totemLifetime or 30 } end,
}
XelAssist.Game.Friendlies = { Snapshot = friendlySnapshot }
XelAssist.Graph.HostileState = {
    Observe = function() return { hostile = false, guid = nil, ref = nil,
        geometry = {}, health = 0, healthMax = 0, healthExact = true,
        projectedAuras = {}, targetAuras = {}, casting = false,
        hasAggro = false } end,
    ByKey = function() return nil end, ByUnit = function() return nil end,
    Selected = function() return nil end, Active = function() return nil end,
    SyncSelected = function() end, SyncContext = function() end,
    SyncActive = function() end, RefreshRecord = function() end,
    CommitSelected = function() end, CommitContext = function() end,
    CommitActive = function() end, Context = function() return nil end,
    SelectedContext = function() return nil end,
}
local Capabilities = XelAssist.Game.Capabilities
Capabilities.CurrentCast = function() return nil, 0, false, 0, false, nil end
Capabilities.Distance = function() return nil, nil end
Capabilities.WeaponSkills = function() return nil end
Capabilities.TalentPoints = function() return 0 end
Capabilities.UnitHasBuff = function() return false end
Capabilities.GCDRemaining = function() return 0 end
Capabilities.Usable = function() return true end

dofile("Graph/PaladinAuraProjection.lua")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassMechanics.lua")
dofile("Graph/State.lua")

local activeSealAuras = { { name = "Opaque active seal", spellId = 20154,
    sourceUnit = "player", sourceGUID = playerGUID, duration = 30,
    expirationTime = 130 } }
C_UnitAuras = { GetUnitAuras = function() return activeSealAuras end }
playerClass = "PALADIN"
local paladinState = XelAssist.Graph.State:Snapshot("smart")
assert(paladinState.paladinAuraState
    and paladinState.paladinAuraState.available
    and paladinState.paladinAuraState.player.activeSeal.spellId == 20154,
    "State:Snapshot must attach exact Paladin root aura state")

XelAssist.Graph.TargetSelection = {
    VariableFriendlyAction = function() return false end,
    Targets = function() return {} end,
}
XelAssist.Graph.ActionAdmission = {
    Start = function(_, _, state) return state.time or 0, nil end,
    Readiness = function() return nil end,
    Timing = function() return 0, false, 1.5, true, 1.5, 1.5 end,
}
XelAssist.Graph.ActionContextPolicy = { Blocker = function() return nil end }
XelAssist.Graph.SpatialRequirements = { Blocker = function() return nil end }
XelAssist.Graph.ActionPower = {
    Estimate = function() return 0, false, { exact = true } end,
}
dofile("Graph/TargetAuras.lua")
dofile("Graph/Targets.lua")
dofile("Graph/StateUtilityScoring.lua")
dofile("Graph/Scoring.lua")

local function selfDescriptor(state)
    local record = state.friendlies.byKey[playerKey]
    return { key = playerKey, unit = "player", relation = "self",
        guid = playerGUID, record = record, exact = true }
end
local sealAction = { name = "Localized new seal", spellId = 20375,
    actor = "player", executor = "playerSpell", facts = sealFacts }

local function forbidMutableReads()
    UnitClass = function() error("class API read after root attachment") end
    GetSpellRecField = function() error("DBC read after root attachment") end
    C_UnitAuras.GetUnitAuras = function() error("aura API read after root attachment") end
    XelAssist.Game.SpellSemantics.Resolve = function()
        error("spell semantics read after root attachment")
    end
    GetSpellDuration = function() error("duration API read after root attachment") end
    GetTotemInfo = function() error("totem API read after root attachment") end
    GetTotemTimeLeft = function() error("totem timer read after root attachment") end
    Capabilities.UnitHasBuff = function() error("live aura fallback after root attachment") end
end
forbidMutableReads()
local legal, blocker = XelAssist.Graph.Targets:Legal(
    sealAction, paladinState, selfDescriptor(paladinState))
assert(not legal and blocker == "Paladin downstream combat effect unavailable",
    "Legal must fail closed before generic Paladin buff handling")
local legacyBlocker = XelAssist.Graph.ClassMechanics:Blocker(
    { spellId = 20375, actor = "player",
        facts = { paladinAura = true } },
    paladinState, selfDescriptor(paladinState))
assert(legacyBlocker == "captured Paladin action classification unavailable",
    "claimed Paladin mechanics without sealed identity must not re-read DBC")
local scored, scoreReason = XelAssist.Graph.Scoring:Evaluate(
    sealAction, paladinState, selfDescriptor(paladinState))
assert(scored == nil and scoreReason == blocker,
    "Scoring must preserve the exact Paladin blocker without generic utility")

local function shallow(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local promotedSeal = shallow(sealFacts)
promotedSeal.paladinEffectRepresented = true
promotedSeal.paladinDownstreamEffect = {
    exact = true, kind = "exclusiveAuraLifecycle" }
local promotedSealAction = shallow(sealAction)
promotedSealAction.facts = promotedSeal
local paladinBranch = XelAssist.Graph.State:Copy(paladinState)
assert(paladinBranch.paladinAuraState.playerGUID
    == paladinState.paladinAuraState.playerGUID,
    "Paladin branch copying must preserve opaque root identity")
local sealProjection, sealReason = XelAssist.Graph.ClassMechanics:Prepare(
    promotedSealAction, paladinBranch, selfDescriptor(paladinBranch))
assert(sealProjection and sealReason == nil
    and sealProjection.classMechanic == "paladin",
    "captured Paladin facts must prepare without mutable API reads")
scored, scoreReason = XelAssist.Graph.Scoring:Evaluate(
    promotedSealAction, paladinBranch, selfDescriptor(paladinBranch))
assert(scored == nil
    and scoreReason == "exact class mechanic consequence scoring unavailable",
    "even promoted lifecycle evidence must bypass generic buff utility")

XelAssist.Graph.Effects = {
    ApplyExclusiveFamily = function() end, StateAtImpact = function(state) return state end,
    ApplyTargetModifier = function() end,
}
XelAssist.Graph.HostileEffects = {
    ApplySelectedDamage = function() return true, 0 end,
    FinalizeSelected = function() end, Apply = function() end,
    ApplyPrimaryThreat = function() end,
}
XelAssist.Graph.ReadinessEffects = { Apply = function() end }
XelAssist.Graph.EventAuras = {
    ReplaceStateAura = function() return nil end,
    PriorStacks = function() return 0 end,
}
XelAssist.Graph.DotProjection = { Candidate = function() return 0, 0, 1, 0 end }
XelAssist.Graph.ResourceExchange = { Apply = function() return false end }
XelAssist.Graph.HealthTransfer = { Finish = function() return false end }
XelAssist.Graph.WandCommitment = { Apply = function() return false end,
    AfterAction = function() end }
XelAssist.Graph.PlayerTaunt = { Apply = function() return false end }
XelAssist.Graph.ComboEffects = { Apply = function() end }
dofile("Graph/FriendlyActionEffects.lua")
dofile("Graph/ActionEffects.lua")
local ProductionActionEffects = XelAssist.Graph.ActionEffects

local function mechanicCandidate(action, projection, state, duration)
    return { action = action, classMechanicProjection = projection,
        tooltip = { duration = duration }, target = "player",
        targetKey = playerKey, targetGUID = playerGUID,
        targetRelation = "self", cost = 0, costKnown = true,
        power = 0, effectDelivery = 1, cast = 0, wait = 0,
        occupancy = 0, downtime = 1, actionStart = state.time or 0 }
end
local sealCandidate = mechanicCandidate(
    promotedSealAction, sealProjection, paladinBranch, 30)
local sealContext = ProductionActionEffects:Context(
    paladinState, sealCandidate)
ProductionActionEffects:Apply(
    paladinBranch, paladinState, sealCandidate, sealContext)
assert(sealContext.classMechanicApplied
    and paladinBranch.paladinAuraState.player.activeSeal.spellId == 20375
    and paladinState.paladinAuraState.player.activeSeal.spellId == 20154
    and not paladinBranch.friendlies.byKey[playerKey].auras[sealAction.name],
    "Apply must update exact Paladin state without a generic name-keyed aura")

UnitClass = function() return "Localized class", "SHAMAN" end
GetSpellRecField = originalDBC
XelAssist.Game.SpellSemantics.Resolve = originalSemantics
GetSpellDuration = originalDuration
Capabilities.UnitHasBuff = function() return false end
C_UnitAuras.GetUnitAuras = function() return {} end
GetTotemInfo = function(slot)
    assert(slot >= 1 and slot <= 4)
    return true, "", 0, 0, nil, 1, 0
end
GetTotemTimeLeft = function() error("empty slots need no timer read") end
local shamanState = XelAssist.Graph.State:Snapshot("smart")
assert(shamanState.totems and shamanState.totems.available
    and not shamanState.totems.bySlot[1].active,
    "State:Snapshot must attach exact Shaman slot state")
forbidMutableReads()
local fireAction = { name = "Localized fire totem", spellId = 1535,
    actor = "player", executor = "playerSpell", facts = fireFacts }
legal, blocker = XelAssist.Graph.Targets:Legal(
    fireAction, shamanState, selfDescriptor(shamanState))
assert(not legal and blocker == "Shaman totem downstream consequence unavailable",
    "Legal must fail closed before typed immediate totem damage")
scored, scoreReason = XelAssist.Graph.Scoring:Evaluate(
    fireAction, shamanState, selfDescriptor(shamanState))
assert(scored == nil and scoreReason == blocker,
    "Scoring must not assign generic utility to lifecycle-only totems")

local promotedFire = shallow(fireFacts)
promotedFire.shamanEffectRepresented = true
promotedFire.shamanRangeRepresented = true
promotedFire.shamanRecipientsRepresented = true
promotedFire.shamanTotemDownstream = { exact = true, sourceSpellId = 1535,
    element = "fire", source = "frozen exact test evidence",
    effect = { exact = true, kind = "periodicDamage" },
    range = { exact = true, center = "totem", minimum = 0, maximum = 10 },
    recipients = { exact = true, center = "totem",
        relation = "hostile", shape = "area" } }
local promotedFireAction = shallow(fireAction)
promotedFireAction.facts = promotedFire
local shamanBranch = XelAssist.Graph.State:Copy(shamanState)
assert(shamanBranch.totems.playerGUID == shamanState.totems.playerGUID,
    "Shaman branch copying must preserve opaque root identity")
local fireProjection, fireReason = XelAssist.Graph.ClassMechanics:Prepare(
    promotedFireAction, shamanBranch, selfDescriptor(shamanBranch))
assert(fireProjection and fireReason == nil
    and fireProjection.classMechanic == "shaman",
    "captured Shaman lifecycle and downstream facts must prepare without live reads")
local fireCandidate = mechanicCandidate(
    promotedFireAction, fireProjection, shamanBranch, 5)
local fireContext = ProductionActionEffects:Context(shamanState, fireCandidate)
ProductionActionEffects:Apply(
    shamanBranch, shamanState, fireCandidate, fireContext)
assert(fireContext.classMechanicApplied
    and shamanBranch.totems.bySlot[1].active
    and shamanBranch.totems.bySlot[1].spellId == 1535
    and not shamanBranch.friendlies.byKey[playerKey].auras[fireAction.name],
    "Apply must replace the exact totem slot without a generic aura projection")

XelAssist.Graph.ActionEffects = {
    Context = function() return {} end,
    Consume = function() return true end,
    Apply = function() end,
}
XelAssist.Graph.OngoingEffects = {
    PersistentAuraSnapshot = function() return {} end,
    Prepare = function() return {} end,
    AdvanceState = function() end, AdvanceEventAuras = function() end,
    AuraSnapshot = function() return {} end, ApplyEvent = function() end,
    TrackEventAuras = function() end,
}
XelAssist.Graph.EventAuras.AgeBranches = function() end
XelAssist.Graph.HealthTransfer = nil
XelAssist.Graph.WandCommitment = nil
XelAssist.Graph.PlayerTaunt = nil
dofile("Graph/Timeline.lua")
local timelineOut = XelAssist.Graph.State:Copy(shamanBranch)
local waitCandidate = { action = { name = "Wait", actor = "player",
    facts = { kind = "command" } }, tooltip = {}, target = "player",
    targetRelation = "self", cast = 0, wait = 0, occupancy = 0,
    downtime = 6, actionStart = 0 }
local timelineContext = { applicationOffset = 0, applicationElapsed = 0 }
XelAssist.Graph.Timeline:Run(
    timelineOut, shamanBranch, waitCandidate, timelineContext)
assert(not timelineOut.totems.bySlot[1].active
    and shamanBranch.totems.bySlot[1].active,
    "the production timeline must expire only the copied Shaman branch slot")

print("ok: exact Paladin and Shaman production wiring is root-captured and fail closed")
