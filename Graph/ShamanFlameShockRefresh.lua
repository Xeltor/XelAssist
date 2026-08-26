-- Molten Blast refreshes only the caster's existing target-local Flame Shock.
-- SetAuraDuration preserves the periodic tick phase, so only remaining time is
-- reset; the graph must not restart or award a tick at the cast instant.
XelAssist.Graph.ShamanFlameShockRefresh = {}
local R = XelAssist.Graph.ShamanFlameShockRefresh
local IDs = XelAssist.Game.Player.ShamanMoltenBlast.FLAME

local function ownedFlame(aura)
    return type(aura) == "table" and aura.mine == true
        and (IDs[tonumber(aura.spellId)] == true
            or aura.periodicAction and aura.periodicAction.facts
                and aura.periodicAction.facts.shamanFlameShock == true)
end
function R:Apply(state, candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    if facts.shamanMoltenBlast ~= true then return false end
    if (tonumber(candidate.effectDelivery) or 0) < 0.999 then return true end
    local name, aura
    for name, aura in pairs(state.auras or {}) do
        if ownedFlame(aura) and tonumber(aura.duration) then
            aura.remaining = aura.duration
            aura.refreshedByMoltenBlast = true
            aura.refreshSourceSpellId = candidate.action.spellId
            return true
        end
    end
    for name, aura in pairs(state.targetAuras or {}) do
        if ownedFlame(aura) and tonumber(aura.duration) then
            local projected, key, value = {}, nil, nil
            for key, value in pairs(aura) do projected[key] = value end
            projected.remaining = projected.duration
            projected.refreshedByMoltenBlast = true
            projected.refreshSourceSpellId = candidate.action.spellId
            state.auras[name] = projected
            return true
        end
    end
    return true
end
