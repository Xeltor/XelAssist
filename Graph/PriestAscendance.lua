-- Search-pure fail-closed adapter. Observed Ascendance improves healing facts
-- through the runtime owner; a future activation is withheld because its
-- post-application engine-effective cast/cost cannot be read during search.
XelAssist.Graph.PriestAscendance={}
local G=XelAssist.Graph.PriestAscendance
local function runtime() return XelAssist.Game.Player.PriestAscendance end
function G:Attach(state)
    local owner=runtime(); local snapshot=owner and owner:Snapshot() or nil
    state.priestAscendance=snapshot
    return snapshot and snapshot.exact==true or false
end
function G:Copy(source,target)
    local found=source and source.priestAscendance
    if not found then target.priestAscendance=nil; return false end
    local out,key,value={},nil,nil; for key,value in pairs(found) do out[key]=value end
    target.priestAscendance=out; return true
end
function G:Prepare(action,state,tooltip)
    local facts=action and action.facts
    if not (facts and facts.priestAscendance==true) then return tooltip,nil,false end
    local snapshot=state and state.priestAscendance
    if not (snapshot and snapshot.exact==true) then
        return nil,"Ascendance self aura evidence unavailable",true
    end
    if snapshot.active then return nil,"Ascendance active",true end
    return nil,snapshot.unresolved or
        "Ascendance future healing modifiers unavailable",true
end
function G:Score(context)
    if context then context.ascendanceUnknown=
        "post-application engine healing modifiers unavailable" end
    return false,"Ascendance future consequences unresolved"
end
