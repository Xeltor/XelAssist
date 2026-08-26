-- Level-60 caster proof band. Catalogues are intentionally rank-heavy and
-- permuted; all decisions are made by the production graph fixture.
XelAssistGraphScenarioSetupOnly=true
local F=dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly=nil
local function order(a,n) local o,i={},nil if n==2 then for i=table.getn(a),1,-1 do table.insert(o,a[i]) end elseif n==3 then for i=2,table.getn(a) do table.insert(o,a[i]) end if a[1] then table.insert(o,a[1]) end else for i=1,table.getn(a) do table.insert(o,a[i]) end end return o end
local function resource(s,v,m) s.resource,s.resourceMax,s.playerResourceExact=v,m,true s.actors.player.resource,s.actors.player.resourceMax,s.actors.player.resourceExact=v,m,true end
local function wandState(s) s.wand={supported=true,active=false,activeKnown=true,pending=false,clockKnown=true,currentTargetGuid=s.targetGUID,speed=1.8,damage=82} end
local function base(class,mana,dist)
 local s=F.State("smart"); s.classMechanicClass,s.playerLevel=class,60
 s.distance,s.targetDistance=dist or 24,dist or 24; s.inCombat=true
 resource(s,mana or 1000,1000); wandState(s); return s
end
local function A(name,rank,kind,power,cost,facts) return F.Action(name,rank,kind,power,cost,facts) end
local function wand() local a=A("Shoot",1,"autoRepeat",0,0,{autoRepeat=true,wandRepeat=true,ambient=true,startOnly=true,recovery=true,ranged=true,cast=0,testMaxRange=30}) a.mock.gcd=0 return a end
local function expect(label,s,actions,wanted,role,depth)
 local i,p,r
 for i=1,3 do F:Use(s,order(actions,i)); XelAssistCharDB.graphDepth,XelAssistCharDB.role=depth or 3,role or "damage"; p,r=XelAssist.Graph:Evaluate("smart",true); assert(p and p.action.name==wanted,label.." order "..i.." got "..tostring(p and p.action.name or r)..", wanted "..wanted) end
 return p
end
local function dead(label,class,actions)
 local s=base(class,100,24); s.targetHealth,s.targetMax,s.targetHealthExact=0,4000,true
 local i,p for i=1,3 do F:Use(s,order(actions,i)); XelAssistCharDB.graphDepth=3; p=XelAssist.Graph:Evaluate("smart",true); assert(p==nil,label.." acted on dead target") end
end
local function setup(class,name)
 local s=base(class,1000,0); s.hostile,s.inCombat=false,false
 expect(class.." setup",s,{A(name,1,"buff",0,0,{self=true,testDuration=1800})},name)
end
local function recover(class,name)
 local s=base(class,80,0); s.hostile,s.inCombat=false,false
 expect(class.." recovery",s,{A(name,1,"resource",500,0,{self=true,recovery=true,channel=true})},name)
end

-- Mage: talented Pyroblast, distinct resistance schools, cooldown instant,
-- channel commitment, movement, interrupt and wand equipment fallback.
setup("MAGE","Mage Armor")
local function mage()
 return { A("Frostbolt",11,"damage",620,260,{cast=2.5,ranged=true,slow=true,testMaxRange=30,testSchool=4}),
  A("Frostbolt",10,"damage",540,235,{cast=2.5,ranged=true,slow=true,testMaxRange=30,testSchool=4}),
  A("Pyroblast",8,"dot",1050,440,{cast=6,ranged=true,testMaxRange=35,testSchool=2,testDuration=12,testPeriodicInterval=3,testDirectDamage=760,testPeriodicDamage=290}),
  A("Fire Blast",7,"damage",500,215,{ranged=true,testMaxRange=20,testSchool=2,testCooldown=8}), wand() }
end
local s=base("MAGE",1000,24); expect("Mage talented engage",s,mage(),"Frostbolt")
s.inCombat=true; resource(s,120,1000); expect("Mage starvation equipment",s,mage(),"Shoot")
s=base("MAGE",1000,18); s.moving=true; expect("Mage movement cooldown",s,mage(),"Fire Blast")
s=base("MAGE",1000,24); s.targetResistances={[5]=300}
local resisted=expect("Mage Frost resistance evidence",s,mage(),"Frostbolt")
assert(resisted.resistance and resisted.resistance.multiplier<1,
 "Mage resistance phase did not carry production resistance evidence")
s=base("MAGE",500,24); s.targetCasting,s.targetCastRemaining=true,1
local interrupt=mage(); table.insert(interrupt,A("Counterspell",1,"interrupt",0,100,{ranged=true,testMaxRange=30,testCooldown=30}))
expect("Mage interrupt safety",s,interrupt,"Counterspell")
dead("Mage","MAGE",mage()); recover("MAGE","Evocation")

-- Priest: healer role responds to a pressured friendly, damage role uses the
-- shadow talent line, Silence owns cast safety, and Fade answers unwanted aggro.
setup("PRIEST","Power Word: Fortitude")
local function priestDamage()
 return { A("Shadow Word: Pain",8,"dot",720,250,{ranged=true,testMaxRange=30,testSchool=5,testDuration=18,testPeriodicInterval=3}),
  A("Mind Blast",9,"damage",700,300,{cast=1.5,ranged=true,testMaxRange=30,testSchool=5}),
  A("Smite",10,"damage",610,280,{cast=2.5,ranged=true,testMaxRange=30,testSchool=1}), wand() }
end
s=base("PRIEST",1000,24); expect("Priest shadow engage",s,priestDamage(),"Shadow Word: Pain")
s=base("PRIEST",90,24); expect("Priest starvation equipment",s,priestDamage(),"Shoot")
s=base("PRIEST",600,24); s.targetCasting,s.targetCastRemaining=true,1
local pa=priestDamage(); table.insert(pa,A("Silence",1,"interrupt",0,225,{ranged=true,testMaxRange=30,testCooldown=45}))
expect("Priest talented interrupt",s,pa,"Silence")
s=base("PRIEST",700,24); s.hasAggro=true
expect("Priest threat pressure",s,{A("Fade",6,"threatDrop",0,150,{self=true,testCooldown=30,threatDropModel="temporary-flat",threatDropAmount=900,threatDropDuration=10}),A("Mind Blast",9,"damage",700,300,{cast=1.5,ranged=true,testMaxRange=30,testSchool=5})},"Fade")
local heal=base("PRIEST",700,20); heal.role="healer"
expect("Priest friendly pressure",heal,{A("Greater Heal",5,"heal",1500,500,{cast=2.5,testMaxRange=40}),A("Flash Heal",7,"heal",850,380,{cast=1.5,testMaxRange=40})},"Flash Heal","healer")
dead("Priest","PRIEST",priestDamage()); recover("PRIEST","Drink")

-- Warlock: pet actor participates independently, DoT engagement and wand
-- fallback preserve mana, movement keeps instant corruption, and Spell Lock
-- remains pet-owned while the player channel is valuable.
setup("WARLOCK","Demon Armor")
local function warlock()
 return { A("Corruption",7,"dot",760,265,{ranged=true,testMaxRange=30,testSchool=5,testDuration=18,testPeriodicInterval=3}),
  A("Shadow Bolt",10,"damage",720,315,{cast=2.5,ranged=true,testMaxRange=30,testSchool=5}),
  A("Drain Life",6,"damage",520,300,{cast=5,channel=true,leech=true,ranged=true,testMaxRange=30,testSchool=5,testDuration=5,testChannelInterval=1}), wand() }
end
s=base("WARLOCK",1000,24); s.pet=true; s.actors.pet={lifecycle="alive",health=1200,healthMax=1200,resource=100,resourceMax=100,resourceExact=true,readyAt=0,distance=4,distanceKind="hitbox",targetGuid=s.targetGUID,targetExists=true,targetsCurrent=true}
local wa=warlock(); table.insert(wa,F.PetAction("Bite","damage",500,35,{melee=true}))
expect("Warlock pet engage",s,wa,"Corruption")
s=base("WARLOCK",80,24); expect("Warlock starvation equipment",s,warlock(),"Shoot")
s=base("WARLOCK",700,24); s.moving=true; expect("Warlock movement",s,warlock(),"Corruption")
dead("Warlock","WARLOCK",warlock()); recover("WARLOCK","Drink")

print("ok: unordered level-60 Mage Priest Warlock causal proof bands")
