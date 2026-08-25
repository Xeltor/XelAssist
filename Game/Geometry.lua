-- Position evidence whose client semantics are proven useful to decisions.
-- UnitXP's inSight query is intentionally excluded: it is not a cast-LOS API.
XelAssist.Game.Geometry = {}
local G = XelAssist.Game.Geometry

function G:Observe(from, to)
    local out = { source = nil, lineOfSight = nil, behind = nil }
    if not UnitXP or not from or not to or not UnitExists(from)
        or not UnitExists(to) then return out end
    local ok, value = pcall(UnitXP, "behind", from, to)
    if ok and type(value) == "boolean" then
        out.behind, out.source = value, "UnitXP"
    end
    return out
end
