XelAssist = { Game = { Player = {} }, Graph = {} }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local row = { school = 0, category = 0, dispel = 0, mechanic = 0,
    attributes = 34930944, attributesEx = 394240, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    castingTimeIndex = 1, recoveryTime = 30000, categoryRecoveryTime = 0,
    interruptFlags = 15, auraInterruptFlags = 15420,
    channelInterruptFlags = 0, baseLevel = 30, spellLevel = 30,
    durationIndex = 41, powerType = 0, manaCost = 80,
    manaCostPerlevel = 0, manaCostPercentage = 0, rangeIndex = 1,
    spellFamilyName = 9, spellFamilyFlags = 256,
    effect = t(6), effectDieSides = t(1), effectBaseDice = t(1),
    effectBasePoints = t(-1), effectImplicitTargetA = t(1),
    effectImplicitTargetB = t(), effectApplyAuraName = t(66),
    effectTriggerSpell = t() }
function GetSpellRecField(id, field, copied)
    assert(id == 5384 and row[field] ~= nil, "unexpected DBC field " .. field)
    local value = row[field]
    if copied then return { value[1], value[2], value[3] } end
    return value
end
GetSpellDuration = function(id, base) assert(id == 5384 and base == 1); return 360000 end
local token, aura, now = "HUNTER", nil, 100
UnitClass = function() return "Hunter", token end
C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
    assert(id == 5384); return aura
end }
GetTime = function() return now end

dofile("Game/Player/HunterFeignDeath.lua")
local Runtime = XelAssist.Game.Player.HunterFeignDeath
local facts, reason, handled = Runtime:InferKnowledge(5384)
assert(handled and not reason and facts.hunterFeignDeath
    and facts.kind == "threatDrop" and facts.gcd == 0
    and facts.threatDropModel == "resistible-all-or-nothing",
    "numeric topology must infer exact Feign Death identity")
assert(Runtime:Evidence(facts).duration == 360,
    "static evidence must preserve the six-minute maximum")
local inactive = Runtime:Snapshot("HUNTER")
assert(inactive.available and inactive.exact and inactive.active == false,
    "absent numeric aura must be exact inactivity")
aura = { spellId = 5384, duration = 360, expirationTime = 130 }
local active = Runtime:Snapshot("HUNTER")
assert(active.active and active.remaining == 30 and not active.outcomeKnown,
    "an active aura must preserve unknown threat success")
token = "MAGE"
assert(not Runtime:InferKnowledge(5384), "another class must not infer Feign Death")
token = "HUNTER"
Runtime:Invalidate(); row.effectApplyAuraName = t(1)
local malformed, malformedReason, malformedHandled = Runtime:InferKnowledge(5384)
assert(not malformed and malformedHandled
    and malformedReason == "Feign Death DBC topology is incomplete",
    "recognized topology drift must fail closed")
row.effectApplyAuraName = t(66); Runtime:Invalidate()
facts = Runtime:InferKnowledge(5384)
aura = nil
inactive = Runtime:Snapshot("HUNTER")

local certainRisk, uncertainRisk = 1, 0
XelAssist.Graph.ThreatDrop = { Risk = function()
    return certainRisk, uncertainRisk, 1
end }
dofile("Graph/HunterFeignDeath.lua")
local Graph = XelAssist.Graph.HunterFeignDeath
local state = { inCombat = true, resource = 100, resourceMax = 200,
    playerResourceExact = true, playerAttack = { active = true },
    autoShot = { active = true, pending = true },
    wand = { active = true, pending = true }, playerCasting = true,
    playerChanneling = true, castRemaining = 2,
    actors = { player = {} } }
assert(Graph:Attach(state, inactive), "exact inactive root must attach")
GetSpellRecField = function() error("DBC read during graph search") end
local action = { name = "Feign Death", spellId = 5384,
    actor = "player", facts = facts }
local candidate = { action = action, tooltip = facts }
assert(not Graph:Blocker(action, state,
    { unit = "player", relation = "self" }, facts))
certainRisk, uncertainRisk = 0, 1
assert(not Graph:Blocker(action, state,
    { unit = "player", relation = "self" }, facts),
    "uncertain unwanted aggro must remain a bounded Feign opportunity")
certainRisk, uncertainRisk = 1, 0
assert(Graph:Apply(state, candidate) and state.hunterFeignDeath.active
    and state.hunterFeignDeath.remaining == 360
    and not state.playerAttack.active and not state.autoShot.active
    and not state.wand.active and not state.playerCasting
    and not state.playerChanneling,
    "application must interrupt player combat without touching pet state")
assert(Graph:Blocker(action, state,
    { unit = "player", relation = "self" }, facts)
    == "Feign Death already active", "repeat Feign must be blocked")
local copied = {}; Graph:Copy(state, copied)
assert(copied.hunterFeignDeath ~= state.hunterFeignDeath,
    "search branches must not alias Feign state")
local shot = { action = { spellId = 75, actor = "player", facts = {} } }
assert(Graph:Consume(state, shot) and not state.hunterFeignDeath.active,
    "the next player action must wake the Hunter")
state.hunterFeignDeath.active, state.hunterFeignDeath.remaining = true, 0.5
assert(Graph:Advance(state, 1) and not state.hunterFeignDeath.active
    and state.hunterFeignDeath.expirationOutcomeUnknown
    and state.playerSurvivalExact == false,
    "unverified maximum-duration outcome must fail closed")
print("ok: exact Feign Death identity has bounded threat and wake lifecycle")
