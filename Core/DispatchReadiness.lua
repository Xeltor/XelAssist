-- Final live usability checks immediately before a published recommendation
-- crosses into a player or companion dispatch API.
XelAssist.Core.DispatchReadiness = {}
local R = XelAssist.Core.DispatchReadiness

function R:Pet(action)
    if action.executor ~= "petAbility" then return nil end
    local remaining = XelAssist.Game.Actors:PetCooldown(action)
    if remaining and remaining > 0 then return "companion action on cooldown" end
    if GetPetActionsUsable then
        local ok, usable = pcall(GetPetActionsUsable)
        if ok and (usable == false or usable == 0) then
            return "companion action unavailable"
        end
    end
    return nil
end

function R:Player(action, usesNormalQueue)
    local facts = action.facts
    if facts.playerAttack or facts.autoRepeat then return nil end
    local usable, reason = XelAssist.Game.Capabilities:Usable(action)
    if usable == false then return reason or "action unavailable" end
    if facts.requiresExactUsability and usable ~= true then
        return reason or "action availability unknown"
    end
    if facts.outOfCombat and UnitAffectingCombat then
        local ok, inCombat = pcall(UnitAffectingCombat, "player")
        if not ok then return "combat state unknown" end
        if inCombat == true or inCombat == 1 then return "combat state" end
    end
    if action.slot and not usesNormalQueue
        and not XelAssist.Game.Capabilities:IsReady(action.name, 0) then
        return "action on cooldown"
    end
    return nil
end
