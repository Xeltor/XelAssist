-- Root-only capture of mutable resistance inputs. Search consumes the copied
-- installed-DBC descriptor and dynamic-school key carried by each sealed
-- action; it must never cold-read client APIs while expanding graph nodes.
XelAssist.Graph.ResistanceEvidence = {}
local E = XelAssist.Graph.ResistanceEvidence

local function copy(value, depth, seen)
    if type(value) ~= "table" or depth <= 0 then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, child = {}, nil, nil
    seen[value] = out
    for key, child in pairs(value) do
        out[key] = copy(child, depth - 1, seen)
    end
    return out
end

function E:Attach(action)
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    if not (type(action) == "table" and resistance) then return false end
    if tonumber(action.spellId) and resistance.SpellFacts then
        local ok, metadata = pcall(
            resistance.SpellFacts, resistance, action.spellId)
        action.resistanceMetadataCaptured = true
        action.resistanceMetadata = ok and type(metadata) == "table"
            and copy(metadata, 5) or nil
    end
    local dynamic = action.facts and action.facts.dynamicSchool
    if dynamic then
        local ok, context = false, nil
        if resistance.DynamicContext then
            ok, context = pcall(
                resistance.DynamicContext, resistance, dynamic)
        end
        action.resistanceDynamicContextCaptured = true
        action.resistanceDynamicContext = ok and context or nil
    end
    return action.resistanceMetadataCaptured == true
        or action.resistanceDynamicContextCaptured == true
end

function E:AttachResult(source, result)
    if not (type(source) == "table" and type(result) == "table"
        and result ~= source and tonumber(result.spellId)) then return false end
    self:Attach(result)
    source.triggeredResistanceEvidence = {
        spellId = result.spellId,
        metadataCaptured = result.resistanceMetadataCaptured == true,
        metadata = copy(result.resistanceMetadata, 5),
        dynamicContextCaptured =
            result.resistanceDynamicContextCaptured == true,
        dynamicContext = result.resistanceDynamicContext,
    }
    return true
end
