XelAssist.Graph.HunterStingingNettle = {}
local N=XelAssist.Graph.HunterStingingNettle
local State=XelAssist.Graph.State
function N:Prepare(context)
    local runtime=XelAssist.Game.Player.HunterStingingNettle
    local found=runtime and (runtime:Evidence(context.tooltip) or runtime:Evidence(context.facts))
    if not found then
        if context.facts.requiresStingingNettleEvidence and context.facts.stingingNettleEvidenceReason then
            return nil,context.facts.stingingNettleEvidenceReason,true end
        return nil,nil,false
    end
    if found.active~=true then return nil,nil,false end
    local descriptor=context.descriptor
    local key,guid=descriptor and descriptor.key,descriptor and descriptor.guid
    if not (descriptor and descriptor.relation=="hostile" and key~=nil
        and guid~=nil and State and State.HostileByKey) then
        return nil,"Stinging Nettle target identity unavailable",true
    end
    local record=State:HostileByKey(context.state,key)
    if not (record and record.guid==guid and record.dead~=true) then
        return nil,"Stinging Nettle target changed",true
    end
    local prior=record.projectedAuras and record.projectedAuras["Serpent Sting"]
        or record.targetAuras and record.targetAuras["Serpent Sting"]
    local priorTicks=0
    if prior then
        local remaining=tonumber(prior.remaining)
        if remaining==nil then return nil,"Serpent Sting remaining time unavailable",true end
        if remaining>=found.duration then return nil,nil,false end
        priorTicks=math.ceil(math.max(0,remaining)/found.interval)
    end
    local marginal=math.max(0,found.duration/found.interval-priorTicks)*found.tickDamage
    if marginal<=0 then return nil,nil,false end
    context.stingingNettleTransition={exact=true,name="Serpent Sting",
        targetKey=key,targetGUID=guid,
        stingSpellId=found.stingSpellId,duration=found.duration,interval=found.interval,
        tickDamage=found.tickDamage,totalDamage=found.totalDamage,
        marginalDamage=marginal,magnitudeEstimated=found.magnitudeEstimated,
        source=found.source}
    return context.stingingNettleTransition,nil,true
end
function N:Score(context)
    local t=context.stingingNettleTransition; if not t then return false end
    local delivery=math.max(0,math.min(1,tonumber(context.effectDelivery) or 1))
    t.applicationProbability=delivery; t.expectedDamage=t.marginalDamage*delivery
    if t.magnitudeEstimated then context.estimated=true end
    context.value=context.value+t.expectedDamage*4/math.max(.5,tonumber(context.downtime) or .5)
    if t.expectedDamage>0 then context.reason="strikes and applies Stinging Nettle" end
    return true
end
function N:Apply(state,candidate)
    local t=candidate.stingingNettleTransition
    if not (t and t.exact==true and t.targetKey~=nil and t.targetGUID~=nil
        and candidate.targetKey==t.targetKey and candidate.targetGUID==t.targetGUID
        and State and State.HostileByKey) then return false end
    local record=State:HostileByKey(state,t.targetKey)
    if not (record and record.guid==t.targetGUID and record.dead~=true) then
        return false
    end
    record.projectedAuras=record.projectedAuras or {}
    local prior=record.projectedAuras[t.name]
    if prior and tonumber(prior.remaining) and prior.remaining>=t.duration then return false end
    local branches=XelAssist.Graph.EventAuras
        and XelAssist.Graph.EventAuras:ReplaceScheduledAura(state,t.targetKey,
            t.targetGUID,t.name,t.applicationProbability,prior) or nil
    record.projectedAuras[t.name]={mine=true,target=record.unit or "target",
        targetKey=t.targetKey,targetGUID=t.targetGUID,spellId=t.stingSpellId,
        duration=t.duration,remaining=t.duration,periodicRate=t.totalDamage/t.duration,
        periodicInterval=t.interval,periodicNextIn=t.interval,
        periodicThreatActor="player",periodicThreatMultiplier=1,
        periodicBranches=branches,applicationProbability=t.applicationProbability,
        stingingNettle=true}
    if State.RefreshHostileRecord then
        State:RefreshHostileRecord(state,t.targetKey)
    end
    return true
end
