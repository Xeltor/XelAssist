-- Branch-local Shield Block window. It grants no speculative mitigation;
-- charges are consumed only by an authoritative resolved blocked white swing.
XelAssist.Graph.WarriorShieldBlock={}
local S=XelAssist.Graph.WarriorShieldBlock
local function cp(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=v end return o end
function S:Prepare(action,state,tooltip)
 local f=action and action.facts; local e=f and f.warriorShieldBlockEvidence
 if not (f and f.warriorShieldBlock) then return tooltip,nil,false end
 if not (e and e.exact and e.spellId==2565 and (e.charges==1 or e.charges==2)
  and type(e.duration)=="number" and e.duration>0 and e.duration<=60
  and e.blockChanceBonus==75 and e.cost==10) then return nil,"Shield Block evidence incomplete",true end
 if not (state and state.playerForm and state.playerForm.available==true
  and state.playerForm.formID==18 and state.resourceType==1
  and state.playerResourceExact==true and tonumber(state.resource)>=10) then
  return nil,"Shield Block stance or rage unavailable",true end
 local off=state.inventory and state.inventory.offHand
 if not (off and off.classificationKnown and off.classID==4 and off.subClassID==6
  and off.broken==false) then return nil,"usable shield unavailable",true end
 local out=cp(tooltip); out.warriorShieldBlockApplication={exact=true,
  spellId=2565,charges=e.charges,duration=e.duration}
 out.classMechanic="warriorShieldBlock"; return out,nil,true
end
function S:Score(context,projection)
 local a=projection and projection.warriorShieldBlockApplication
 if not (a and a.exact) then return false,"Shield Block transition unavailable" end
 context.power,context.expectedPower,context.effectivePower=0,0,0
 context.value=0;context.estimated=true
 context.reason="block value and exact incoming block outcome unavailable"
 return true
end
function S:Apply(state,candidate)
 local a=candidate and candidate.tooltip and candidate.tooltip.warriorShieldBlockApplication
 if not (a and a.exact and (a.charges==1 or a.charges==2)) then return false end
 state.warriorShieldBlock={active=true,charges=a.charges,
  expiresAt=(tonumber(state.time) or 0)+a.duration,projected=true}; return true
end
function S:Advance(state,elapsed)
 local w=state and state.warriorShieldBlock; if not w then return end
 if (tonumber(state.time) or 0)+(tonumber(elapsed) or 0)>=w.expiresAt then w.active=false;w.charges=0 end
end
function S:Copy(source,target)
 if not target then return false end
 target.warriorShieldBlock=source and source.warriorShieldBlock
  and cp(source.warriorShieldBlock) or nil
 return target.warriorShieldBlock~=nil
end
function S:ConsumeObservedBlock(state,event)
 local w=state and state.warriorShieldBlock
 if not (w and w.active and w.charges>0 and event and event.whiteSwing==true
  and event.victimKind=="player" and event.outcomeExact==true
  and tonumber(event.blockedAmount) and event.blockedAmount>0) then return false end
 w.charges=w.charges-1; if w.charges==0 then w.active=false end; return true
end
