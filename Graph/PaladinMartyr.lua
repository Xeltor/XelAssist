-- Safety boundary for Martyr's compound packets. The generic Paladin aura
-- graph still owns seal replacement/consumption; this leaf refuses to credit
-- outgoing Holy damage while its material self-health cost is unrepresentable.
XelAssist.Graph.PaladinMartyr={}
local M=XelAssist.Graph.PaladinMartyr
local function copy(t) local o,k,v={},nil,nil for k,v in pairs(t or {}) do o[k]=type(v)=="table" and copy(v) or v end return o end
function M:Attach(state,snapshot)
 if not (state and snapshot and snapshot.available and snapshot.exact) then return false end
 state.paladinMartyr=copy(snapshot);return true
end
function M:Copy(source,target)
 target.paladinMartyr=source.paladinMartyr and copy(source.paladinMartyr);return target.paladinMartyr~=nil
end
local function active(state)
 local root=state and state.paladinAuraState;local player=root and root.player
 local seal=player and player.activeSeal
 return root and root.available==true and seal and seal.exact==true
  and seal.spellId==45802 and seal.recipientRelation=="self" and seal or nil
end
local function exact(state,facts,requireFacts)
 local root=state and state.paladinMartyr;local p=root and root.profile
 if requireFacts and not (facts and facts.paladinMartyrExact==true
  and facts.paladinMartyrEvidence and facts.paladinMartyrEvidence.sealSpellId==45802) then return nil end
 return root and root.available and root.exact and type(p)=="table" and p.exact==true
  and p.sealSpellId==45802 and p.procSpellId==45814 and p.judgementSpellId==45816
  and p.weaponHolyCoefficient==.20 and p.compoundRepresentable==false and p
end
function M:WeaponOutcome(action,state)
 local seal=active(state); if not seal then return nil,nil,false end
 local facts=action and action.facts or {};local p=exact(state,facts,false)
 local weapon=facts.weaponHand or facts.usesWeaponSkill or facts.deliverySubtype=="melee"
 if not weapon then return nil,nil,false end
 if not p then return nil,"Martyr weapon packet evidence unavailable",true end
 return {exact=true,representable=false,sourceSealSpellId=seal.spellId,
  holy={spellId=p.procSpellId,school=1,weaponCoefficient=.20,target="hostile"},
  selfHealth={spellId=p.procSelfSpellId,target="self",exact=false},gap=p.gap},p.gap,true
end
function M:JudgementOutcome(action,state)
 local facts=action and action.facts or {};if not facts.paladinMartyrJudgement then return nil,nil,false end
 local seal=active(state);local p=seal and exact(state,facts,true)
 if not p then return nil,"Martyr Judgement requires its exact active seal",true end
 return {exact=true,representable=false,consumesSeal=true,sourceSealSpellId=45802,
  holy={spellId=45816,school=1,target="hostile",basePoints=169,dieSides=30,
   pointsPerLevel=6.099999904632568},selfHealth={spellId=45817,target="self",exact=false},gap=p.gap},p.gap,true
end
