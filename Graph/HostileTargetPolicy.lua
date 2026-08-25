-- Character policy and client-boundary exclusions for GUID-directed hostile
-- spells. This is recipient enumeration, never a rotation or priority list.
XelAssist.Graph.HostileTargetPolicy = {}
local P = XelAssist.Graph.HostileTargetPolicy

local HOSTILE_KINDS = { damage = true, dot = true, debuff = true,
    crowdControl = true, interrupt = true }

function P:Enabled()
    return XelAssistCharDB and XelAssistCharDB.toggles
        and XelAssistCharDB.toggles.engagedTargets == true
        and QueueSpellByName ~= nil
end
function P:SelectedOnly(action)
    local facts = action and action.facts or {}
    if not action or action.actor == "pet" or action.executor ~= "playerSpell"
        or not HOSTILE_KINDS[facts.kind] then return true end
    if facts.self or facts.ground or facts.aoe or facts.effectTarget
        or facts.fixedTarget or facts.petLifecycle or facts.playerAttack
        or facts.autoRepeat or facts.onNextSwing or facts.onSwing
        or facts.melee or facts.combo or facts.comboBuilder or facts.reactive
        or facts.kind == "builder" then
        return true
    end
    local ok, tooltip = pcall(
        XelAssist.Game.Actors.Facts, XelAssist.Game.Actors, action)
    if not ok or type(tooltip) ~= "table" then return true end
    if tooltip.onNextSwing or tooltip.onSwing
        or tooltip.topology and tooltip.topology.area then return true end
    return false
end

function P:Eligible(action, state, record)
    if not self:Enabled() or self:SelectedOnly(action) then return false end
    if not (record and record.guid ~= nil and record.dead == false
        and record.engagedAddressable == true
        and record.engagement and record.engagement.engaged == true
        and record.engagement.unit ~= nil) then return false end
    return true
end

function P:Describe()
    return self:Enabled() and "engaged GUID casts" or "selected enemy only"
end
