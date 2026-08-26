XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {
    [8017] = { powerType = 0, durationIndex = 0,
        effect = t(54), effectMiscValue = t(29) },
    [10400] = { spellFamilyName = 11, spellLevel = 1, baseLevel = 1,
        maxLevel = 0, effect = t(6, 6, 6), effectApplyAuraName = t(99, 10, 87),
        effectMiscValue = t(0, 127, 127), effectBasePoints = t(28, 34, -1),
        effectBaseDice = t(1, 1, 1), effectDieSides = t(1, 1, 1),
        effectRealPointsPerLevel = t(4.1), effectDicePerLevel = t() },
    [8024] = { powerType = 0, durationIndex = 0,
        effect = t(54), effectMiscValue = t(5) },
    [8026] = { school = 2, spellFamilyName = 11, spellLevel = 10,
        baseLevel = 10, maxLevel = 0, effect = t(3),
        effectBasePoints = t(325), effectBaseDice = t(1),
        effectDieSides = t(1), effectRealPointsPerLevel = t(19),
        effectDicePerLevel = t() },
    [8033] = { powerType = 0, durationIndex = 0,
        effect = t(54), effectMiscValue = t(2) },
    [8034] = {},
    [8232] = { powerType = 0, durationIndex = 0,
        effect = t(54), effectMiscValue = t(283) },
    [8233] = {},
}
function GetSpellRecField(id, field, copied)
    local row, value = rows[id], rows[id] and rows[id][field]
    if not row or value == nil then error("missing fixture " .. id .. ":" .. field) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
UnitClass = function() return "Shaman", "SHAMAN" end
UnitLevel = function() return 10 end
local enchants = {
    [29] = { enchantID = 29, effects = { { type = 3, amount = 0, arg = 10400 } } },
    [5] = { enchantID = 5, effects = { { type = 1, amount = 100, arg = 8026 } } },
    [2] = { enchantID = 2, effects = { { type = 1, amount = 0, arg = 8034 } } },
    [283] = { enchantID = 283, effects = { { type = 1, amount = 20, arg = 8233 } } },
}
C_Item = {
    GetEnchantInfo = function(id) return enchants[id] end,
    GetWeaponEnchantInfo = function() return false, 0, 0, 0 end,
}

dofile("Game/Player/ShamanWeaponImbues.lua")
local Runtime = XelAssist.Game.Player.ShamanWeaponImbues
local rock = assert(Runtime:InferKnowledge(8017))
assert(rock.shamanWeaponImbue and rock.immediateDispatch
    and rock.shamanWeaponImbueEvidence.effectKnown
    and math.abs(rock.shamanWeaponImbueEvidence.attackPower - 65.9) < 0.0001
    and rock.shamanWeaponImbueEvidence.threatMultiplier == 1.35,
    "Rockbiter must seal its scaled AP and weapon threat")
local flame = assert(Runtime:InferKnowledge(8024))
assert(flame.shamanWeaponImbueEvidence.effectKnown
    and flame.shamanWeaponImbueEvidence.school == 2
    and flame.shamanWeaponImbueEvidence.procChance == 1,
    "Flametongue must seal its every-landed-hit Fire packet")
local frost = assert(Runtime:InferKnowledge(8033))
assert(frost.requiresExactShamanWeaponImbue
    and not frost.shamanWeaponImbueEvidence.effectKnown,
    "Frostbrand must be recognized but fail closed on private proc chance")
local wind = assert(Runtime:InferKnowledge(8232))
assert(wind.requiresExactShamanWeaponImbue
    and not wind.shamanWeaponImbueEvidence.effectKnown,
    "Windfury must be recognized but fail closed on conflicting proc evidence")
local root = Runtime:Snapshot()
assert(root.available and root.exact and not root.active,
    "absent main-hand temporary enchant must be exact")

XelAssist.Graph.Effects = { Decision = function() return 1 end }
XelAssist.Combat.Resistance = { Estimate = function() return {} end }
dofile("Graph/ShamanWeaponImbues.lua")
local Graph = XelAssist.Graph.ShamanWeaponImbues
local state = { targetHealth = 100, targetHealthExact = true,
    targetSurvival = { available = true, lowerTimeToDie = 8,
        upperTimeToDie = 12 }, actors = { player = { guid = "player" } },
    playerAttack = { attackRound = { verified = true, projectable = true,
        speedTrusted = true, normalDamageKnown = true, speed = 2,
        interval = 2.05, power = 20, targetGuid = "target" } } }
assert(Graph:Attach(state, "SHAMAN"), "exact empty enchant state must attach")
local descriptor = { unit = "player", relation = "self", guid = "player" }
local projection = assert(Graph:Prepare({ spellId = 8017, facts = rock },
    state, descriptor, rock))
local context = { state = state, downtime = 1.5 }
assert(Graph:Score(context, projection) and context.value > 0,
    "Rockbiter must earn value only from projected main-hand hits")
assert(Graph:Apply(state, { classMechanicProjection = projection }))
local consequence = Graph:MainHandConsequences(state, "target")
assert(consequence and consequence.exact
    and consequence.threatMultiplier == 1.35
    and consequence.physicalBonus > 9,
    "active Rockbiter must alter exact main-hand damage and threat")
local calls = {}
local dealt, resolveReason, handled = Graph:ResolveMainHand(
    state, "target", 20, function(action, tooltip, power, threat)
        table.insert(calls, { action = action, power = power, threat = threat })
        return power
    end)
assert(handled and not resolveReason and dealt > 29 and calls[1] and not calls[2]
    and calls[1].threat == 1.35,
    "Rockbiter must compose with the ordinary white-hit resolver")
assert(not Graph:Prepare({ spellId = 8017, facts = rock },
    state, descriptor, rock), "an active same-rank imbue must not refresh early")
local blocked, reason = Graph:Prepare({ spellId = 8033, facts = frost },
    state, descriptor, frost)
assert(not blocked and reason == "Frostbrand proc chance is private",
    "unsupported imbues must retain their explicit blocker")
state.shamanWeaponImbue.active = false
projection = assert(Graph:Prepare({ spellId = 8024, facts = flame },
    state, descriptor, flame))
assert(Graph:Apply(state, { classMechanicProjection = projection }))
calls = {}
dealt, resolveReason, handled = Graph:ResolveMainHand(
    state, "target", 20, function(action, tooltip, power, threat)
        table.insert(calls, { action = action, power = power, threat = threat })
        return power
    end)
assert(handled and not resolveReason and dealt == 20
    and calls[1] and calls[2] and not calls[3]
    and calls[1].action.name == "Attack"
    and calls[2].action.name == "Flametongue Weapon"
    and calls[2].power > 17,
    "Flametongue must occur only through the joint white-hit resolver")
print("ok: exact Shaman weapon imbue lifecycle and supported hit effects")
