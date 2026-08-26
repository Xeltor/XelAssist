table.getn = table.getn or function(value) return #value end

XelAssist = { Game = { Player = {} }, Graph = {} }

local capacityCalls, incomingCalls = 0, 0
XelAssist.Game.Player.MageManaShield = {
    Is = function(_, action)
        return action and action.facts and action.facts.mageManaShield == true
    end,
    EffectiveCapacity = function(_, context, state)
        capacityCalls = capacityCalls + 1
        assert(context.tooltip.manaPerAbsorbedDamageExact == true,
            "capacity must consume captured ratio evidence")
        local available = state.resource - (state.playerResourceReserved or 0)
            - context.cost
        return math.min(context.power,
            math.floor(available / context.tooltip.manaPerAbsorbedDamage))
    end,
}
XelAssist.Graph.IncomingConsequences = {
    RecipientGuid = function(_, cast)
        if cast.consequence.targetMode == "self" then return cast.casterGuid end
        return cast.consequence.targetGuid or cast.targetGuid
    end,
    ExpectedAmount = function(_, cast)
        incomingCalls = incomingCalls + 1
        return cast.consequence.amount * (cast.probability or 1)
    end,
}

GetSpellName = function()
    error("scoring must not inspect localized spell names")
end
GetSpellRecField = function()
    error("scoring must not read mutable DBC data")
end
UnitGUID = function()
    error("scoring must not read live recipient identity")
end

dofile("Graph/MageManaShieldScoring.lua")
local Scoring = XelAssist.Graph.MageManaShieldScoring

local function cast(guid, remaining, amount, school, target, extra)
    local value = { casterGuid = guid, targetGuid = target or "player-guid",
        remaining = remaining, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = target or "player-guid", amount = amount,
            school = school } }
    local key, entry
    for key, entry in pairs(extra or {}) do
        if key == "consequence" then
            local factKey, factValue
            for factKey, factValue in pairs(entry) do
                value.consequence[factKey] = factValue
            end
        else value[key] = entry end
    end
    return value
end

local casts = {
    physical = cast("physical", 2, 30, 0),
    fire = cast("fire", 3, 80, 2),
    probabilistic = cast("probabilistic", 4, 40, 0, nil,
        { probability = 0.5 }),
    unknownSchool = cast("unknown-school", 5, 50, nil),
    estimated = cast("estimated", 6, 10, 0, nil,
        { consequence = { estimated = true } }),
    before = cast("before", 1, 90, 0),
    atApplication = cast("at-application", 1.5, 90, 0),
    after = cast("after", 9.1, 90, 0),
    ally = cast("ally", 4, 90, 0, "ally-guid"),
    dead = cast("dead", 7, 90, 0),
    hostileHeal = cast("heal", 4, 90, 1, nil,
        { consequence = { kind = "heal" } }),
    unknownConsequence = { casterGuid = "unknown", targetGuid = "player-guid",
        remaining = 7.5, probability = 1 },
}
local order = { "physical", "fire", "probabilistic", "unknownSchool",
    "estimated", "before", "atApplication", "after", "ally", "dead",
    "hostileHeal", "unknownConsequence" }
local state = { resourceType = 0, resource = 140,
    playerResourceReserved = 0, playerResourceExact = true,
    actors = { player = { guid = "player-guid" } },
    hostiles = { order = { "dead-key" }, byKey = {
        ["dead-key"] = { guid = "dead", health = 0,
            healthExact = true } } },
    hostileCasts = { order = order, byCaster = casts } }
local action = { facts = { mageManaShield = true } }
local context = { action = action, state = state,
    descriptor = { unit = "player", relation = "self",
        guid = "player-guid" },
    target = "player", power = 100, cost = 40,
    tooltip = { manaPerAbsorbedDamage = 2,
        manaPerAbsorbedDamageExact = true,
        mageManaShieldSchoolMask = 1 } }

local evidence, reason, handled = Scoring:Evidence(context, 9, 1.5)
assert(handled and reason == nil and evidence
    and evidence.incoming == 60 and not evidence.incomingExact
    and evidence.unknownIncomingEvents == 2
    and evidence.countedPhysicalEvents == 3
    and evidence.capacity == 50 and evidence.schoolMask == 1
    and evidence.allowAggroHeuristic == false,
    "only physical impacts after application must contribute to shield value")
assert(capacityCalls == 1 and incomingCalls == 3,
    "scoring must price capacity once and magnitude only matching impacts")

casts.physical.consequence.amount = 999
state.resource = 1
assert(evidence.incoming == 60 and evidence.capacity == 50,
    "returned scalar evidence must be immutable from later branch mutation")
state.resource = 140

local magicState = { resourceType = 0, resource = 140,
    playerResourceExact = true,
    hasAggro = true,
    actors = { player = { guid = "player-guid" } },
    hostiles = { order = {}, byKey = {} },
    hostileCasts = { order = { "magic" }, byCaster = {
        magic = cast("magic", 2, 500, 5) } } }
local magic = { action = action, state = magicState,
    descriptor = context.descriptor, target = "player",
    power = 100, cost = 40, tooltip = context.tooltip }
local magicEvidence = Scoring:Evidence(magic, 9, 1.5)
assert(magicEvidence and magicEvidence.incoming == 0
    and magicEvidence.incomingExact
    and magicEvidence.allowAggroHeuristic == false,
    "known magic-only danger must add no physical absorb expectation")

dofile("Graph/IncomingScoring.lua")
magic.wait, magic.cast, magic.downtime = 0, 0, 1.5
magic.absorbEffectivePower = 50
magic.tooltip.duration = 10
local value, explanation = XelAssist.Graph.IncomingScoring:AbsorbValue(magic)
assert(value == 100 and explanation == "adds a protective buffer"
    and magic.incomingDuringAbsorb == 0
    and magic.incomingDuringAbsorbExact == true
    and magic.estimated ~= true,
    "production absorb scoring must not value physical-only Mana Shield from magic aggro")

local other = { action = { facts = { kind = "absorb" } },
    state = state, target = "player", tooltip = {} }
local beforeCapacity = capacityCalls
evidence, reason, handled = Scoring:Evidence(other, 9, 0)
assert(evidence == nil and reason == nil and not handled
    and capacityCalls == beforeCapacity,
    "ordinary absorbs must remain available to generic scoring")

local badSchool = { action = action, state = state,
    descriptor = context.descriptor, target = "player", power = 100, cost = 40,
    tooltip = { manaPerAbsorbedDamage = 2,
        manaPerAbsorbedDamageExact = true } }
evidence, reason, handled = Scoring:Evidence(badSchool, 9, 0)
assert(handled and evidence == nil
    and reason == "Mana Shield school evidence unavailable",
    "an exact spell claim without captured school evidence must fail closed")

local raced = { action = action, state = state,
    descriptor = { guid = "different-player" }, target = "player",
    power = 100, cost = 40, tooltip = context.tooltip }
evidence, reason, handled = Scoring:Evidence(raced, 9, 0)
assert(handled and evidence == nil
    and reason == "Mana Shield recipient identity unavailable",
    "a changed self-recipient identity must fail closed")

print("ok: Mana Shield scoring values only physical mana-backed capacity")
