XelAssist = { Core = {}, Game = { Capabilities = {} } }

local units, targetHostile = {}, true
local combat, form = true, 2
local usable, ready, inRange = true, true, true
local raidCount, partyCount = 0, 1
local hooks = {}
local calls = { selected = 0, usable = 0, ready = 0, range = 0 }

function UnitExists(unit)
    local guid = units[unit]
    if guid == nil then return false, nil end
    return true, guid
end
function UnitAffectingCombat() return combat end
function GetShapeshiftForm() return form end
function GetNumRaidMembers() return raidCount end
function GetNumPartyMembers() return partyCount end

XelAssist.Core.TargetGuard = {
    ValidateSelectedHostile = function(_, plan, unit, ref)
        calls.selected = calls.selected + 1
        if hooks.selected then hooks.selected(calls.selected) end
        if plan.target ~= "target" or unit ~= "target"
            or type(ref) ~= "table" or ref.unit ~= "target"
            or ref.relation ~= "hostile" or ref.guid == nil
            or plan.targetGUID ~= ref.guid or plan.targetRelation ~= "hostile"
            or plan.castTarget ~= "target" or plan.castTargetGUID ~= ref.guid
            or plan.castTargetRelation ~= "hostile" or not targetHostile then
            return nil, "selected hostile unavailable", true
        end
        local exists, guid = UnitExists("target")
        if not exists or guid ~= ref.guid then
            return nil, "selected hostile changed", true
        end
        return guid, nil, true
    end,
}

XelAssist.Game.Capabilities.Usable = function()
    calls.usable = calls.usable + 1
    if hooks.usable then hooks.usable() end
    return usable
end
XelAssist.Game.Capabilities.IsReady = function(_, name, projected)
    calls.ready = calls.ready + 1
    assert(name == "Taunt" and projected == 0,
        "the guard must query Taunt at the immediate dispatch boundary")
    if hooks.ready then hooks.ready() end
    return ready
end
XelAssist.Game.Capabilities.CastName = function(_, action)
    return action.name
end
XelAssist.Game.Capabilities.InRange = function(_, name, unit)
    calls.range = calls.range + 1
    assert(name == "Taunt" and unit == "target",
        "the guard must query exact selected-target Taunt range")
    if hooks.range then hooks.range() end
    return inRange
end

dofile("Core/WarriorTankGuard.lua")
local Guard = XelAssist.Core.WarriorTankGuard

local function plan(taunt)
    local guid = "enemy-a"
    return { action = { name = "Taunt", actor = "player",
            facts = taunt == false and { kind = "taunt" }
                or { kind = "taunt", playerTaunt = true } },
        target = "target", targetGUID = guid, targetRelation = "hostile",
        targetRef = { unit = "target", guid = guid, relation = "hostile" },
        castTarget = "target", castTargetGUID = guid,
        castTargetRelation = "hostile",
        castTargetRef = { unit = "target", guid = guid,
            relation = "hostile" } }
end

local function reset()
    units = { player = "player-guid", pet = "pet-guid",
        target = "enemy-a", targettarget = "ally-guid",
        party1 = "ally-guid" }
    targetHostile, combat, form = true, true, 2
    usable, ready, inRange = true, true, true
    raidCount, partyCount = 0, 1
    hooks = {}
    calls = { selected = 0, usable = 0, ready = 0, range = 0 }
end

local function rejected(message, expected)
    local valid, reason = Guard:Validate(plan())
    assert(not valid and (expected == nil or reason == expected),
        message .. ": " .. tostring(reason))
end

reset()
assert(Guard:Validate(plan(false)) and calls.selected == 0
    and calls.usable == 0 and calls.ready == 0 and calls.range == 0,
    "a non-player Taunt plan must bypass every live tank gate")
assert(Guard:Validate(nil), "a missing non-Taunt plan must remain unrelated")

reset()
assert(Guard:Validate(plan()) and calls.selected == 2 and calls.usable == 1
    and calls.ready == 1 and calls.range == 1,
    "Taunt must pass for a stable party victim in exact live conditions")

reset()
local delayed = plan(); delayed.wait = 0.1
local delayedValid, delayedReason = Guard:Validate(delayed)
assert(not delayedValid and delayedReason == "Taunt must be ready now"
    and calls.selected == 0,
    "Taunt must never enter a delayed client queue")

reset(); units.targettarget, units.party1 = "pet-guid", nil
partyCount = 0
assert(Guard:Validate(plan()), "Taunt must protect the player's current pet")

reset(); units.party1, units.raid1 = nil, "ally-guid"
partyCount, raidCount = 0, 1
assert(Guard:Validate(plan()), "Taunt must protect a current raid member")

reset(); targetHostile = false
rejected("a non-hostile selected target must fail closed",
    "selected hostile unavailable")
reset(); units.target = "enemy-b"
rejected("a selected hostile GUID mismatch must fail closed",
    "selected hostile changed")

reset(); combat = false
assert(Guard:Validate(plan()),
    "Taunt must rescue a group pull before the player's combat flag arrives")
reset(); UnitAffectingCombat = function() error("unavailable") end
assert(Guard:Validate(plan()),
    "Taunt victim ownership must not depend on the player's combat API")
UnitAffectingCombat = function() return combat end

reset(); form = 1
rejected("Taunt must require exact Defensive Stance",
    "Defensive Stance required")
reset(); form = "2"
rejected("a coerced stance value must not pass", "Defensive Stance required")
reset(); GetShapeshiftForm = function() error("unavailable") end
rejected("failed stance state must fail closed", "Defensive Stance required")
GetShapeshiftForm = function() return form end

reset(); usable = false
rejected("an explicitly unusable Taunt must be blocked", "Taunt unavailable")
reset(); usable = nil
rejected("unknown Taunt usability must be blocked", "Taunt unavailable")
reset(); usable = 1
rejected("only exact true Taunt usability may pass", "Taunt unavailable")
reset(); hooks.usable = function() error("unavailable") end
rejected("failed Taunt usability must be blocked", "Taunt unavailable")

reset(); ready = false
rejected("Taunt cooldown must be ready", "Taunt on cooldown")
reset(); ready = nil
rejected("unknown Taunt cooldown must fail closed", "Taunt on cooldown")
reset(); ready = 1
rejected("only exact true cooldown readiness may pass", "Taunt on cooldown")
reset(); hooks.ready = function() error("unavailable") end
rejected("failed cooldown state must fail closed", "Taunt on cooldown")

reset(); units.targettarget = nil
rejected("a missing current victim must block Taunt",
    "target victim unavailable")
reset(); units.targettarget = "player-guid"
rejected("Taunt must not fire when the player already has aggro",
    "target already attacks player")
reset(); units.targettarget = "outsider-guid"
rejected("Taunt must not steal from an outsider",
    "target victim is outside your group")
reset(); units.player = nil
rejected("unknown player identity must fail victim classification",
    "player identity unavailable")

reset(); inRange = false
rejected("Taunt outside exact melee range must be blocked",
    "Taunt melee range required")
reset(); inRange = nil
rejected("unknown Taunt range must fail closed", "Taunt melee range required")
reset(); inRange = 1
rejected("only exact true melee range may pass", "Taunt melee range required")
reset(); hooks.range = function() error("unavailable") end
rejected("failed Taunt range must fail closed", "Taunt melee range required")

reset(); hooks.range = function() units.target = "enemy-b" end
rejected("a selected-target race must be caught", "selected hostile changed")
reset(); hooks.range = function() units.targettarget = "other-ally" end
rejected("a target-victim race must be caught", "target victim changed")
reset(); hooks.range = function() units.party1 = "other-ally" end
rejected("a victim roster-slot race must be caught",
    "target victim group identity changed")

print("ok: exact live Warrior Taunt tank guard")
