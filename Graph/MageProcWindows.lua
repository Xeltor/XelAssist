-- Branch-local consumption of exact Mage proc windows captured at the root.
XelAssist.Graph.MageProcWindows = {}
local M=XelAssist.Graph.MageProcWindows
local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=v end return o end
local function nested(t)
    local o=copy(t); o.hotStreak=t.hotStreak and copy(t.hotStreak); o.flashFreeze=t.flashFreeze and copy(t.flashFreeze); return o
end
function M:Attach(state,snapshot)
    if not (state and snapshot and snapshot.available and snapshot.exact) then return false end
    state.mageProcWindows=nested(snapshot); return true
end
function M:Copy(source,target)
    target.mageProcWindows=source.mageProcWindows and nested(source.mageProcWindows); return target.mageProcWindows~=nil
end
function M:PrepareLegal(action,state,tooltip)
    local facts=action and action.facts; local kind=facts and facts.mageProcConsumer
    if not kind then return tooltip,nil,false end
    if facts.mageProcConsumerExact~=true then return nil,facts.mageProcReason,true end
    local root=state and state.mageProcWindows; local window=root and root[kind]
    if not (root and root.available and root.exact and window) then return nil,"Mage proc root state unavailable",true end
    local out=copy(tooltip)
    local start=math.max(tonumber(state.time) or 0,tonumber(state.playerGcdReadyAt) or 0,
        tonumber(state.actorReadyAt and state.actorReadyAt.player) or 0)
    if window.consumed==true then
        return nil,"ordinary post-proc timing requires a fresh root observation",true
    end
    if window.active~=true or not window.expiresAt or start>=window.expiresAt then return out,nil,true end
    local contract=facts.mageProcContract
    if not (contract and contract.exact and contract.kind==kind and contract.spellId==action.spellId
        and contract.auraSpellId==window.auraSpellId) then return nil,"Mage proc consequence was not root-sealed",true end
    out.cast,out.cost=contract.cast,contract.cost
    out.mageProcConsumption={exact=true,kind=kind,spellId=action.spellId,auraSpellId=window.auraSpellId}
    return out,nil,true
end
function M:Consume(state,candidate)
    local mark=candidate and candidate.tooltip and candidate.tooltip.mageProcConsumption
    local root=state and state.mageProcWindows; local window=mark and root and root[mark.kind]
    if not (mark and mark.exact and window and window.active and candidate.action
        and mark.spellId==candidate.action.spellId and mark.auraSpellId==window.auraSpellId) then return false end
    window.active=false; window.consumed=true; window.stacks=0; window.expiresAt=nil
    return true
end
