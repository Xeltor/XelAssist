XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"

local spellCalls, petCalls = {}, {}
GetTime = function() return 100 end
GetSpellCooldown = function(slot, book)
    assert(book == BOOKTYPE_SPELL, "player ranks must use their exact book")
    spellCalls[slot] = (spellCalls[slot] or 0) + 1
    if slot == 10 then return 95, 10, 1 end
    return 0, 0, 1
end
GetPetActionCooldown = function(slot)
    petCalls[slot] = (petCalls[slot] or 0) + 1
    if slot == 4 then return 99, 5, 1 end
    return 99, 5, 0
end

dofile("Graph/CooldownLedger.lua")
local L = XelAssist.Graph.CooldownLedger

local shadowOne = { name = "Shadow Bolt", rankText = "Rank 1", rank = 1,
    spellId = 686, slot = 10, bookType = BOOKTYPE_SPELL,
    actor = "player", executor = "playerSpell" }
local shadowOneDuplicate = { name = "Shadow Bolt", rankText = "Rank 1", rank = 1,
    spellId = 686, slot = 10, bookType = BOOKTYPE_SPELL,
    actor = "player", executor = "playerSpell" }
local shadowTwo = { name = "Shadow Bolt", rankText = "Rank 2", rank = 2,
    spellId = 695, slot = 11, bookType = BOOKTYPE_SPELL,
    actor = "player", executor = "playerSpell" }
local firebolt = { name = "Firebolt", rankText = "Rank 1", rank = 1,
    spellId = 3110, slot = 1, actionSlot = 4, bookType = BOOKTYPE_PET,
    actor = "pet", executor = "petAbility" }
local fireboltDuplicate = { name = "Firebolt", rankText = "Rank 1", rank = 1,
    spellId = 3110, slot = 1, actionSlot = 4, bookType = BOOKTYPE_PET,
    actor = "pet", executor = "petAbility" }
local phaseShift = { name = "Phase Shift", rankText = "Rank 1", rank = 1,
    spellId = 4511, slot = 2, actionSlot = 5, bookType = BOOKTYPE_PET,
    actor = "pet", executor = "petAbility" }
local petAttack = { name = "Pet Attack", actor = "pet",
    executor = "petCommand" }
local actions = { shadowOne, shadowOneDuplicate, shadowTwo,
    firebolt, fireboltDuplicate, phaseShift, petAttack }
local state = { time = 0, readyAt = {}, actors = { pet = { autocasts = {
    { name = "Firebolt", spellId = 3110, readyIn = 4 },
} } } }

local first = L:Prepare(state, actions)
assert(spellCalls[10] == 1 and spellCalls[11] == 1,
    "each exact player rank must read its live cooldown once")
assert(petCalls[4] == nil and petCalls[5] == 1,
    "exact pet evidence captured by the root snapshot must be reused")
assert(table.getn(first.order) == 4,
    "duplicate graph nodes and pet commands must not add live reads")
assert(L:ActionKey(shadowOne) ~= L:ActionKey(shadowTwo),
    "different ranks of one spell must have distinct cooldown identities")
assert(L:ReadyAt(state, shadowOne) == 5
    and L:ReadyAt(state, shadowTwo) == nil,
    "captured root readiness must be stored on the exact rank only")
assert(L:ReadyAt(state, firebolt) == 4
    and L:ReadyAt(state, phaseShift) == nil,
    "disabled pet cooldown evidence must preserve the old non-blocking unknown")

local blocker, handled = L:Blocker(state, shadowOne, 0)
assert(blocker == "cooldown" and handled,
    "a captured player cooldown must retain the current cooldown blocker")
blocker, handled = L:Blocker(state, firebolt, 0)
assert(blocker == "pet cooldown" and handled,
    "a captured pet cooldown must retain the pet cooldown blocker")
blocker, handled = L:Blocker(state, shadowOne, 5)
assert(blocker == nil and handled,
    "captured cooldowns must admit actions at their projected ready time")

L:Project(state, shadowOne, 15)
blocker = L:Blocker(state, shadowOne, 5)
assert(blocker == "future cooldown",
    "future states must use a projected exact-rank cooldown")
assert(L:ReadyAt(state, shadowTwo) == nil,
    "projecting one rank must never put a sibling rank on cooldown")
L:ProjectGroup(state, 44, 12)
assert(state.readyAt[L:GroupKey(44)] == 12
    and L:GroupKey(44) ~= L:ActionKey(shadowOne),
    "explicit shared cooldown groups must remain separate from rank clocks")

local secondState = { time = 0, readyAt = {}, actors = { pet = { autocasts = {
    { name = "Firebolt", spellId = 3110, readyIn = 4 },
} } } }
local second = L:Prepare(secondState, actions)
assert(second ~= first and spellCalls[10] == 2 and spellCalls[11] == 2
    and petCalls[4] == nil and petCalls[5] == 2,
    "a new evaluation must create a new ledger and fresh root observations")

-- Twenty graph admissions formerly caused one API read per edge. Once the
-- ledger is prepared, all root and future checks are pure table reads.
local callsBefore = spellCalls[10]
local i
for i = 1, 20 do
    L:Blocker(secondState, shadowOne, i / 2)
end
assert(spellCalls[10] == callsBefore,
    "graph expansion must not perform any additional live cooldown reads")

print("ok: evaluation-local exact-rank cooldown ledger")
