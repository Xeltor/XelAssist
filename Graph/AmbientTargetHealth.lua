-- Exact gate for target-health scoring probes. A deep causal timeline copy is
-- necessary only when an already-running combat lane can alter hostile health
-- before the candidate lands; uncertainty stays on the conservative full path.
XelAssist.Graph.AmbientTargetHealth = {}
local A = XelAssist.Graph.AmbientTargetHealth
local AutoShot = XelAssist.Graph.AutoShotEffects

local function damagingAura(auras)
    local _, aura
    for _, aura in pairs(auras or {}) do
        if type(aura) == "table" then
            local periodic = aura.remaining ~= nil
                and aura.periodicRate ~= nil and aura.target == "target"
            if periodic or damagingAura(aura.periodicBranches) then
                return true
            end
        end
    end
    return false
end

function A:CanChange(source)
    if not source then return true end
    local auto = source.autoShot
    if AutoShot and AutoShot.Eligible and auto
        and AutoShot:Eligible(source, auto) then return true end
    if source.targetCasting or source.wand and source.wand.active then
        return true
    end
    local attack, pet = source.playerAttack,
        source.actors and source.actors.pet
    local round = attack and attack.attackRound
    if attack and attack.active == true and round and round.projectable
        and round.targetGuid ~= nil then return true end
    if pet and (pet.targetExists == true or pet.pendingAutocast) then return true end
    if table.getn(source.hostileCasts and source.hostileCasts.order or {}) > 0
        or damagingAura(source.auras) then return true end
    local hostiles, i = source.hostiles, nil
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        local record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        if record and damagingAura(record.projectedAuras) then return true end
    end
    return false
end
