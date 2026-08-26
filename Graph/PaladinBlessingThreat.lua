-- Search-pure consequence for an exact all-threat Paladin blessing. The leaf
-- composes a recipient-owned threat factor; it does not choose a blessing,
-- role, spell order, or fixed score.
XelAssist.Graph.PaladinBlessingThreat = {}
local P = XelAssist.Graph.PaladinBlessingThreat
local Evidence = XelAssist.Game.Player.PaladinBlessingThreat

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            local child, childKey, childValue = {}, nil, nil
            for childKey, childValue in pairs(value) do
                child[childKey] = type(childValue) == "table"
                    and copy(childValue) or childValue
            end
            out[key] = child
        else out[key] = value end
    end
    return out
end

local function exactEffect(value)
    local multiplier = value and finite(value.multiplier)
    local percent = value and finite(value.percent)
    return type(value) == "table" and value.exact == true
        and value.kind == "playerThreatMultiplier"
        and value.actor == "recipient"
        and value.schoolMask == Evidence.ALL_SCHOOLS
        and value.recipientShape == "single"
        and multiplier and multiplier > 0 and multiplier < 1
        and percent and multiplier == (100 + percent) / 100
        and finite(value.sourceSpellId) and value or nil
end

local function recompute(component)
    local count, multiplier, source, caster = 0, 1, nil, nil
    local key, entry
    for key, entry in pairs(component.byCaster or {}) do
        if entry.applies == true then
            count, multiplier = count + 1, entry.multiplier
            source, caster = entry.sourceSpellId, key
        end
    end
    component.activeCount = count
    if count > 1 then
        component.available, component.exact = false, false
        component.multiplier = nil
        component.reason = "multiple all-threat blessings have unresolved stacking"
        return false
    end
    component.available, component.exact = true, true
    component.multiplier, component.sourceSpellId = multiplier, source
    component.sourceGUID, component.reason = caster, nil
    return true
end

function P:Attach(state)
    if type(state) ~= "table" then return false end
    local root = state and state.paladinAuraState
    local player = root and root.player
    local out = { available = false, exact = false, byCaster = {},
        source = "exact root Paladin blessing threat evidence" }
    state.paladinBlessingThreat = out
    if not (root and root.available == true and player
        and player.available == true and player.guid == root.playerGUID) then
        out.reason = "Paladin self blessing state unavailable"
        return false
    end
    local caster, aura
    for caster, aura in pairs(player.blessingsByCaster or {}) do
        local active, found = Evidence:ActiveEffect(aura)
        if not (found and found.available == true and found.exact == true) then
            out.reason = found and found.reason
                or "Paladin blessing threat evidence unavailable"
            return false
        end
        if active then
            out.byCaster[caster] = { applies = true, exact = true,
                sourceSpellId = active.sourceSpellId,
                multiplier = active.multiplier, percent = active.percent,
                recipientShape = found.recipientShape }
        else
            out.byCaster[caster] = { applies = false, exact = true,
                sourceSpellId = aura.spellId }
        end
    end
    return recompute(out)
end

function P:Copy(source, target)
    if not (source and target and source.paladinBlessingThreat) then return false end
    target.paladinBlessingThreat = copy(source.paladinBlessingThreat)
    return true
end

function P:Prepare(state, projection)
    local effect = exactEffect(projection and projection.effect)
    if not effect then return nil, nil, false end
    local root, component = state and state.paladinAuraState,
        state and state.paladinBlessingThreat
    if not (projection.kind == "blessing" and root
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID) then
        return nil, "all-threat blessing graph consequence requires self", true
    end
    if not (component and component.available == true
        and component.exact == true) then
        return nil, component and component.reason
            or "Paladin blessing threat component unavailable", true
    end
    local caster, entry
    for caster, entry in pairs(component.byCaster or {}) do
        if caster ~= root.playerGUID and entry.applies == true then
            return nil, "all-threat blessing stacking is unresolved", true
        end
    end
    projection.paladinBlessingThreat = copy(effect)
    return projection, nil, true
end

function P:Score(context, projection)
    local prepared, reason, handled = self:Prepare(
        context and context.state, projection)
    if not handled or not prepared then return false, reason end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    -- Prevent the generic duration-based buff heuristic from inventing value;
    -- descendants discover the consequence through composed threat instead.
    context.kind = "classMechanic"
    context.reason = "changes all player threat"
    return true
end

-- Called only after the exact Paladin aura lifecycle accepted the transition.
function P:Apply(state, projection)
    local prepared, _, handled = self:Prepare(state, projection)
    local effect = prepared and exactEffect(prepared.paladinBlessingThreat)
    local root, component = state and state.paladinAuraState,
        state and state.paladinBlessingThreat
    local aura = root and root.player and root.player.blessingsByCaster
        and root.player.blessingsByCaster[root.playerGUID]
    if not (handled and effect and component and aura
        and aura.spellId == effect.sourceSpellId
        and aura.sourceGUID == root.playerGUID) then return false end
    component.byCaster[root.playerGUID] = { applies = true, exact = true,
        sourceSpellId = effect.sourceSpellId,
        multiplier = effect.multiplier, percent = effect.percent,
        recipientShape = effect.recipientShape, projected = true }
    return recompute(component)
end

-- PlayerThreat:Resolve can compose this factor after resolving other player-
-- owned components. Pet and non-player actors deliberately bypass it.
function P:Resolve(state, actor, baseMultiplier, baseExact)
    baseMultiplier = finite(baseMultiplier)
    if actor ~= "player" or not baseMultiplier or baseMultiplier < 0 then
        return baseMultiplier, baseExact ~= false
    end
    local component = state and state.paladinBlessingThreat
    if component == nil then return baseMultiplier, baseExact ~= false end
    if not (component.available == true and component.exact == true
        and finite(component.multiplier)) then
        return baseMultiplier, false, component
    end
    return baseMultiplier * component.multiplier,
        baseExact ~= false, component
end
