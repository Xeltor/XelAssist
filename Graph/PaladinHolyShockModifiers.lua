-- Search-pure consumption of root-observed Holy Shock timing modifiers.
XelAssist.Graph.PaladinHolyShockModifiers = {}
local H=XelAssist.Graph.PaladinHolyShockModifiers
local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=v end return o end
local function nested(t)
    local o=copy(t); o.gcd=copy(t.gcd); o.cooldown=copy(t.cooldown); return o
end
function H:Attach(state,snapshot)
    if not (state and snapshot and snapshot.available and snapshot.exact) then return false end
    state.paladinHolyShockModifiers=nested(snapshot); return true
end
function H:Copy(source,target)
    if source.paladinHolyShockModifiers then
        target.paladinHolyShockModifiers=nested(source.paladinHolyShockModifiers)
    end
    return target.paladinHolyShockModifiers~=nil
end
function H:PrepareLegal(action,state,tooltip)
    local facts=action and action.facts
    if not (facts and facts.holyShockModifierConsumer) then return tooltip,nil,false end
    if facts.holyShockModifierConsumerExact~=true then
        return nil,"Holy Shock consumer topology is incomplete",true
    end
    local root=state and state.paladinHolyShockModifiers
    if not (root and root.available and root.exact) then
        return nil,"Holy Shock modifier root state unavailable",true
    end
    if root.gcd.consumed or root.cooldown.consumed then
        return nil,"ordinary Holy Shock timing requires a fresh root observation",true
    end
    if not (root.gcd.active or root.cooldown.active) then return tooltip,nil,true end
    local contract=facts.holyShockModifierContract
    if not (contract and contract.exact and contract.spellId==action.spellId
        and contract.gcdAura==(root.gcd.active and root.gcd.auraSpellId or nil)
        and contract.cooldownAura==(root.cooldown.active
            and root.cooldown.auraSpellId or nil)) then
        return nil,"engine-effective Holy Shock timing was not sealed",true
    end
    local out=copy(tooltip)
    out.gcd,out.cooldown=contract.gcd,contract.cooldown
    out.holyShockModifierConsumption={exact=true,spellId=action.spellId,
        gcdAura=contract.gcdAura,cooldownAura=contract.cooldownAura}
    return out,nil,true
end
function H:Consume(state,candidate)
    local mark=candidate and candidate.tooltip
        and candidate.tooltip.holyShockModifierConsumption
    local root=state and state.paladinHolyShockModifiers
    if not (mark and mark.exact and root and candidate.action
        and mark.spellId==candidate.action.spellId) then return false end
    local consumed=false
    if mark.gcdAura and root.gcd.active and root.gcd.auraSpellId==mark.gcdAura then
        root.gcd.active,root.gcd.consumed=false,true; consumed=true
    end
    if mark.cooldownAura and root.cooldown.active
        and root.cooldown.auraSpellId==mark.cooldownAura then
        root.cooldown.active,root.cooldown.consumed=false,true; consumed=true
    end
    return consumed
end
