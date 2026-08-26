-- Learned hostile white-hit magnitudes are already downstream of server
-- mitigation. Preserve that root regime and apply only exact branch-local
-- multiplier changes; never feed these packets through the raw damage path.
XelAssist.Graph.HostileWhiteMitigation = {}
local M = XelAssist.Graph.HostileWhiteMitigation

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value <= 0 or value > 10 then return nil end
    return value
end

local function damage(value)
    value = tonumber(value)
    if not value or value ~= value or value < 0 or value > 1000000000 then
        return nil
    end
    return value
end

local function formID(state)
    local form = state and state.playerForm
    local value = form and tonumber(form.formID)
    if not (form and form.available == true and value
        and value >= 0 and value <= 32 and math.floor(value) == value) then
        return nil
    end
    return value
end

local function warrior(state)
    local owner = XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorStanceEffects
    local stance = owner and owner:IncomingMultiplier(state)
    if not finite(stance) then return nil end
    local wall, multiplier = state.warriorShieldWall, 1
    if type(wall) ~= "table" or wall.available ~= true
        or wall.exact ~= true then return nil end
    if wall.active == true then multiplier = wall.damageTakenMultiplier end
    return finite(stance * (finite(multiplier) or 0))
end

local function priest(state)
    if state.playerShadowformProfileExact ~= true then return nil end
    return finite(state.playerPhysicalDamageTakenMultiplier)
end

local function druid(state)
    local bark = state.druidBarkskin
    if type(bark) ~= "table" or bark.available ~= true
        or bark.exact ~= true then return nil end
    return bark.active == true and finite(bark.physicalDamageMultiplier) or 1
end

local function playerMultiplier(state)
    local token = state and state.classMechanicClass
    if token == "WARRIOR" then return warrior(state) end
    if token == "PRIEST" then return priest(state) end
    if token == "DRUID" then return druid(state) end
    if token then return 1 end
    return nil
end

local function petMultiplier(state)
    local effects = XelAssist.Game and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects
    local pet = state and state.actors and state.actors.pet
    return pet and effects and finite(effects:IncomingDamageMultiplier(pet))
        or nil
end

local function soulLink(state)
    local owner = XelAssist.Graph and XelAssist.Graph.WarlockSoulLink
    if not owner or state.classMechanicClass ~= "WARLOCK" then
        return false, true, nil
    end
    local active, known, _, found = owner:Active(state)
    return active and true or false, known == true,
        found and finite(found.splitFraction) or nil
end

function M:Attach(state)
    if not (state and state.hostileSwings) then return false end
    local player = playerMultiplier(state)
    local pet = state.actors and state.actors.pet
    local linked, linkKnown, split = soulLink(state)
    state.hostileWhiteMitigationRoot = {
        playerMultiplier = player, playerFormID = formID(state),
        petMultiplier = petMultiplier(state), petGuid = pet and pet.guid,
        soulLinkActive = linked, soulLinkKnown = linkKnown,
        soulLinkSplitFraction = split,
        exact = player ~= nil and linkKnown == true,
    }
    return true
end

local function soulLinkRatio(state, root)
    local active, known, current = soulLink(state)
    if not (known and root.soulLinkKnown == true) then return nil end
    if active == root.soulLinkActive then return 1 end
    if root.soulLinkActive then
        local split = finite(root.soulLinkSplitFraction)
        if split and split < 1 then return 1 / (1 - split) end
    elseif active and current and current < 1 then return 1 - current end
    return nil
end

function M:Adjust(state, entry, amount)
    amount = damage(amount)
    local root = state and state.hostileWhiteMitigationRoot
    if not (amount and entry and type(root) == "table") then return amount end
    if entry.victimKind == "player" then
        local current = playerMultiplier(state)
        local linkRatio = soulLinkRatio(state, root)
        local stableForm = state.classMechanicClass ~= "DRUID"
            or formID(state) == root.playerFormID
        if current and finite(root.playerMultiplier) and stableForm
            and linkRatio then
            return amount * current / root.playerMultiplier * linkRatio
        end
        state.incomingProjectionPartial = true
        return amount
    end
    if entry.victimKind == "pet" then
        local pet = state.actors and state.actors.pet
        if pet and (not entry.victimGuid or pet.guid == entry.victimGuid)
            and pet.guid == root.petGuid and finite(root.petMultiplier) then
            local current = petMultiplier(state)
            if current then return amount * current / root.petMultiplier end
        end
        state.incomingProjectionPartial = true
    end
    return amount
end
