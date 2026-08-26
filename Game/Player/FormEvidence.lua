-- Exact local-player form evidence from ClassicAPI's stable 1.12
-- SpellShapeshiftForm ID. This describes current state only; stance/form
-- transitions remain owned by their class-specific graph adapters.
XelAssist.Game.Player.FormEvidence = {}
local F = XelAssist.Game.Player.FormEvidence

local MAX_FORM_ID = 32

local function integer(value)
    value = tonumber(value)
    if value == nil or value < 0 or value > MAX_FORM_ID
        or math.floor(value) ~= value then return nil end
    return value
end

function F:Snapshot()
    local out = { available = false,
        source = "ClassicAPI stable SpellShapeshiftForm ID" }
    if type(GetShapeshiftFormID) ~= "function" then
        out.reason = "player form API unavailable"
        return out
    end
    local ok, formID = pcall(GetShapeshiftFormID)
    formID = ok and integer(formID) or nil
    if formID == nil then
        out.reason = "player form observation invalid"
        return out
    end
    out.available, out.formID = true, formID
    return out
end
