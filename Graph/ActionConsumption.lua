-- Atomic chosen-action payment. Effects and inventory mutation happen only
-- after the actor's resource payment is proven and committed.
XelAssist.Graph.ActionConsumption = {}
local C = XelAssist.Graph.ActionConsumption

local function spendPlayer(out, candidate)
    local resources = XelAssist.Game.Player
        and XelAssist.Game.Player.Resources
    if resources then return resources:Spend(out, candidate.cost) end
    local resource, cost = tonumber(out.resource),
        math.max(0, tonumber(candidate.cost) or 0)
    if not resource or resource < cost then return false end
    out.resource = resource - cost
    return true
end

local function spendsAmmunition(action)
    local facts = action and action.facts or {}
    local actor = action and (action.actor or "player") or "player"
    -- Starting Auto Shot arms the ambient repeat; the server takes its round
    -- only when a launch occurs. Chosen special ranged attacks pay here.
    return actor == "player" and facts.ammunition == true
        and facts.autoRepeat ~= true and facts.kind ~= "autoRepeat"
end

local function sharedAmmunition(out)
    local inventoryAmmo = out.inventory and out.inventory.ammo
    local autoShot = out.autoShot
    local count
    if inventoryAmmo and inventoryAmmo.known then
        count = tonumber(inventoryAmmo.count) or 0
    end
    if autoShot and autoShot.ammoKnown then
        local autoCount = tonumber(autoShot.ammoCount) or 0
        if count == nil or autoCount < count then
            count = autoCount
        end
    end
    return count, inventoryAmmo, autoShot
end

local function spendAmmunition(out, count)
    if count == nil then return end
    local remaining = math.max(0, count - 1)
    local _, inventoryAmmo, autoShot = sharedAmmunition(out)
    if inventoryAmmo then
        inventoryAmmo.known, inventoryAmmo.count = true, remaining
    end
    if autoShot then
        autoShot.ammoKnown, autoShot.ammoCount = true, remaining
        if remaining <= 0 then autoShot.active = false end
    end
end

function C:SpendsAmmunition(action)
    return spendsAmmunition(action)
end

function C:Ammunition(state)
    local count = sharedAmmunition(state or {})
    return count, count ~= nil
end

function C:ApplicationAmmunition(state, action)
    if not spendsAmmunition(action) then return nil, false end
    return self:Ammunition(state)
end

function C:Consume(out, candidate, context)
    local action, facts = candidate.action, candidate.action.facts
    local usesAmmo, ammoCount = spendsAmmunition(action), nil
    if usesAmmo then
        ammoCount = sharedAmmunition(out)
        -- An earlier ambient launch can spend the last round between scoring
        -- and this action event. Reject before any other payment in that case.
        if ammoCount ~= nil and ammoCount <= 0 then return false end
    end
    local forms = XelAssist.Graph.DruidForms
    local formPayment = forms and forms:Consume(out, candidate, context)
    if formPayment == false then return false end
    if formPayment == nil then
        local swings = XelAssist.Graph.PlayerSwings
        if swings and swings:Is(action, candidate.tooltip) then
            return swings:Reserve(out, candidate)
        elseif action.actor == "pet" and out.actors and out.actors.pet then
            if not (context and context.petCostPaid) then
                local resources = XelAssist.Graph.CompanionResources
                if not (resources and resources:BeginChosen(
                    out, candidate, context or {})) then return false end
            end
        elseif not spendPlayer(out, candidate) then return false end
    end
    if action.executor == "item" and action.itemId and out.inventory
        and out.inventory.itemCounts then
        out.inventory.itemCounts[action.itemId] = math.max(0,
            (out.inventory.itemCounts[action.itemId] or 0) - 1)
    end
    if facts.reagentName and out.inventory
        and out.inventory.reagentCounts then
        out.inventory.reagentCounts[facts.reagentName] = math.max(0,
            (out.inventory.reagentCounts[facts.reagentName] or 0) - 1)
    end
    -- VMaNGOS TakeAmmo runs after power and reagent payment. Use one shared
    -- count so the chosen shot and ambient Auto Shot cannot spend it twice.
    if usesAmmo then spendAmmunition(out, ammoCount) end
    return true
end
