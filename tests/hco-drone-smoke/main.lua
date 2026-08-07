local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path

function love.errorhandler(message)
	io.stderr:write("HCO_DRONE_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n")
	os.exit(1)
end

local function assertTrue(value, message) if not value then error(message) end end
curTime, scrW, scrH = 0, 1920, 1080
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
function _S(v) return v end
function color(r, g, b, a) return setmetatable({r, g, b, a, unpack=function(self) return self[1],self[2],self[3],self[4] end}, {__mul=function(self) return self end}) end

local rotorStarts,droneDraws,outlineDraws=0,0,0
local removedLightBuffers,stoppedLightBuffers,destroyedLightBuffers=0,0,0
love = {graphics = {},audio={}}
love.errorhandler = function(message) io.stderr:write("HCO_DRONE_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n") os.exit(1) end
sound = {playWorld=function() end,play=function() end}
shadowMapping={}
function shadowMapping:removeBuffer() removedLightBuffers=removedLightBuffers+1 end
function shadowMapping:stopRenderingBuffer() stoppedLightBuffers=stoppedLightBuffers+1 end
function shadowMapping:destroyAtlasBuffer() destroyedLightBuffers=destroyedLightBuffers+1 end
function love.graphics.newImage() return {setFilter=function() end} end
function love.graphics.newQuad() return {} end
function love.graphics.setColor() end
function love.graphics.draw() droneDraws=droneDraws+1 end
function love.graphics.push() end
function love.graphics.pop() end
function love.graphics.translate() end
function love.graphics.rotate() end
function love.graphics.setLineWidth() end
function love.graphics.line() end
function love.graphics.circle() end
function love.audio.newSource()
	return {setLooping=function() end,setVolume=function() end,play=function() rotorStarts=rotorStarts+1 end,stop=function() end}
end

local base = {class="security_camera", mtindex={}}
base.mtindex.__index = base
function base:init() self.x,self.y=0,0 self.curViewAngRad=0 self.broken=false self.physics={} self.DYNAMIC_LIST_DEST={insertObject=function() return true end} end
function base:setSize(w,h) self.width,self.height=w,h end
function base:setPos(x,y) self.x,self.y=x,y end
function base:initHitbox(_,w,h)
	self.hitboxW,self.hitboxH=w,h
	self.body={x=self.x,y=self.y,destroyed=false,setPosition=function(body,x,y) body.x,body.y=x,y end,setAwake=function() end,isDestroyed=function(body) return body.destroyed end,destroy=function(body) body.destroyed=true end}
	self.fixture={destroyed=false,setFilterData=function() end,isDestroyed=function(fixture) return fixture.destroyed end}
end
function base:setViewAngle(a) self.curViewAngRad=math.rad(a) end
function base:setLightAngle(a) self.curViewAngRad=math.rad(a) end
function base:onPlacedIntoMap() self.placed=true end
function base:makeAimable() self.aimable=true end
function base:checkVision() return true end
function base:update() return true end
function base:updateCastColor() end
function base:runGenericRaycast() return {fraction=1} end
function base:breakCam() self.broken=true end
function base:remove() self.removed=true end

objects={registered={security_camera=base}}
local failCustomCreate=false
function objects.getClassData(id) return objects.registered[id] end
function objects.registerNew(data, inherit)
	data.baseClass=objects.registered[inherit]
	setmetatable(data, data.baseClass.mtindex)
	data.mtindex={__index=data}
	objects.registered[data.class]=data
end
function objects.create(id)
	if id=="hco_search_drone" and failCustomCreate then error("late class unavailable") end
	local class=objects.registered[id]
	local instance=setmetatable({}, class.mtindex)
	instance:init()
	return instance
end

local function actorObject(x,y,id)
	return {x=x,y=y,id=id,isValid=function() return true end,isDead=function(self) return self.dead == true end,isUnconscious=function(self) return self.unconscious == true end,getPos=function(self) return self.x,self.y end,getID=function(self) return self.id end,getAnimVariant=function(self) return self.animVariant end}
end
local worldNPCs={}
game={playerActor=actorObject(200,200,"player"),activeBullets={},worldObject={getNPCs=function() return worldNPCs end},addDynamicObject=function(o) o.dynamic=true end,removeDynamicObject=function(o) o.dynamic=false end}
game.playerActor.PLAYER=true
local crashGuard=actorObject(80,80,"response-guard")
function crashGuard:setSightPos(x,y) self.sightX,self.sightY=x,y end
function crashGuard:getState() return {goToAlert=function() self.alerted=true end} end
local rootState={disguise=nil,disguiseRisk=1}
local context={root=rootState,slot=1,target=actorObject(100,100,"target"),security={sectorPoints={{x=400,y=400}},guards={{role="response",actor=crashGuard}},drones={},droneCooldown=0,knowledge={}}}

local shells={}
package.preload["hco/security/drone_airframe"]=function()
	local module={}
	function module.initialize() return true end
	function module.create(owner,x,y)
		local shell={owner=owner,x=x,y=y,valid=true,isValid=function(self) return self.valid end,remove=function(self) self.valid=false end}
		table.insert(shells,shell)
		return shell
	end
	function module.sync(shell,owner) if shell and shell.valid then local offset=owner.hcoCenterOffset or 13 shell.x,shell.y=owner.x+offset,owner.y+offset end end
	function module.crash(shell,owner,x,y) if shell and shell.valid then shell.crashed=true return x+10,y+10 end return x,y end
	function module.update() end
	function module.drawOutline(shell) if shell and shell.valid then outlineDraws=outlineDraws+1 return true end return false end
	function module.remove(shell) if shell then shell.valid=false end end
	function module.clearContext(context) for _,shell in ipairs(shells) do if shell.owner and shell.owner.hcoContext==context then shell.valid=false end end end
	function module.diagnostics() local count=0 for _,shell in ipairs(shells) do if shell.valid then count=count+1 end end return {airframes=count,drawPasses=1,spriteReady=true,batchReady=true} end
	return module
end

local drones=require("hco/security/drones")
local config=require("hco/config")
assertTrue(drones.initialize(), "native camera drone behavior initializes")
drones.request(context,3,"body-evidence")
drones.update(context,0.1)
assertTrue(#context.security.drones==3,"three physical drone objects launch")
assertTrue(rotorStarts==3,"every physical drone starts its custom rotor loop")
for _, drone in ipairs(context.security.drones) do
	assertTrue(drone.placed and drone.dynamic,"drone enters world and dynamic update list")
	assertTrue(drone.hcoHitboxReady and drone.body~=nil,"runtime drone owns an explicit bullet-hit body")
	drone:updateSprite()
	drone:drawOutline()
	local beforeX,beforeY=drone.x,drone.y
	drone:update(1)
	local moved=math.sqrt((drone.x-beforeX)^2+(drone.y-beforeY)^2)
	local movementCap=context.security.droneMode=="AGGRESSIVE" and config.DRONE_MAX_AGGRESSIVE_SPEED or config.DRONE_MAX_PATROL_SPEED
	assertTrue(moved<=movementCap+0.001,"movement including separation obeys the active hard speed cap")
	local aimX,aimY=drone:getAimPos()
	assertTrue(aimX==drone.x+drone.hcoCenterOffset and aimY==drone.y+drone.hcoCenterOffset,"player aim target stays centered on the visible airframe")
	assertTrue(drone.body.x==aimX and drone.body.y==aimY,"bullet-hit body follows the visible aim center instead of the generic-object top-left corner")
	local expectedHitbox=drone.hcoType.heavy and 54 or drone.hcoType.id=="scout" and 44 or 48
	assertTrue(drone.hitboxW==expectedHitbox and drone.hitboxH==expectedHitbox,"physical hitbox covers the complete rotated airframe diagonal")
	assertTrue(drone.x~=100 or drone.y~=100,"drone flies toward a search sector")
end
local repairProbe=context.security.drones[3]
local staleBody=repairProbe.body
staleBody.destroyed=true
repairProbe:update(0.1)
assertTrue(repairProbe.body~=staleBody and repairProbe.hcoHitboxReady and repairProbe.hcoHitboxRepairs==1,"runtime watchdog rebuilds a destroyed moving fixture")
assertTrue(outlineDraws==3,"aim outline delegates to each visual airframe without native quad offsets")
assertTrue(drones.drawAll(),"world render pass sees active drones")
assertTrue(#shells==3,"every physical sensor receives a native visual airframe")
local patrolProbe=context.security.drones[3]
game.playerActor.x,game.playerActor.y=2000,2000
patrolProbe.hcoTracking=0
patrolProbe.hcoDestX,patrolProbe.hcoDestY=nil,nil
patrolProbe:update(0.1)
local committedPatrolX,committedPatrolY=patrolProbe.hcoDestX,patrolProbe.hcoDestY
assertTrue(committedPatrolX~=nil,"patrol resolves a distinct fallback destination when its authored sector collapses onto the current position")
patrolProbe:update(0.1)
assertTrue(patrolProbe.hcoDestX==committedPatrolX and patrolProbe.hcoDestY==committedPatrolY,"patrol keeps a distant destination instead of re-rolling it before arrival")
local armorProbe=context.security.drones[2]
armorProbe.hcoArmor,armorProbe.hcoArmorMax=3,3
local normalBullet={damage=20,armorPenetration=2,firer=game.playerActor}
function normalBullet:getDamage() return self.damage end
function normalBullet:getArmorPenetration() return self.armorPenetration end
function normalBullet:getFirer() return self.firer end
armorProbe:onHitBullet(normalBullet,{x=armorProbe.x+13,y=armorProbe.y+13})
assertTrue(armorProbe.hcoArmor==2 and not armorProbe.broken,"ordinary bullet removes one of at most three heavy armor points")
assertTrue(armorProbe.hcoHitFlash==0.42 and armorProbe.hcoArmorDisplay==0.95,"surviving heavy hit exposes readable impact and armor feedback")
local rifleBullet={damage=65,armorPenetration=11,firer=game.playerActor}
function rifleBullet:getDamage() return self.damage end
function rifleBullet:getArmorPenetration() return self.armorPenetration end
function rifleBullet:getFirer() return self.firer end
armorProbe.hcoArmor=3
armorProbe:onHitBullet(rifleBullet,{x=armorProbe.x+13,y=armorProbe.y+13})
assertTrue(armorProbe.hcoArmor==1 and not armorProbe.broken,"high-damage high-penetration rifle compresses a three-hit heavy to the required two-hit floor")
armorProbe:onHitBullet(rifleBullet,{x=armorProbe.x+13,y=armorProbe.y+13})
assertTrue(armorProbe.broken,"second high-caliber hit destroys the heavy drone")
local detector=context.security.drones[1]
local networkGuard=actorObject(900,900,"network-response")
function networkGuard:setSightPos(x,y) self.sightX,self.sightY=x,y end
function networkGuard:setSightTime(value) self.sightTime=value end
function networkGuard:setEnemyInSight(value,target) self.enemyInSight,self.enemyTarget=value,target end
function networkGuard:getState() return {goToCombat=function() networkGuard.combat=true end} end
local networkDrone={broken=false,hcoDestX=999,hcoDestY=999,hcoDestRefreshAt=99,hcoNextSearchAt=99}
local networkContext={root=rootState,slot=2,target=actorObject(850,850,"network-target"),security={sectorPoints={{x=700,y=700}},guards={{role="response",actor=networkGuard}},drones={networkDrone},droneCooldown=0,knowledge={},droneMode="PATROL"}}
rootState.contracts={context,networkContext}
context.security.droneMode="AGGRESSIVE"
context.security.droneSighting=nil
detector.hcoDetect,detector.hcoLastConfirmedAt=0,-100
for _=1,8 do
	game.playerActor.x,game.playerActor.y=detector.x+60,detector.y
	detector.hcoDestX,detector.hcoDestY=detector.x+500,detector.y
	detector:update(0.1)
end
assertTrue(context.security.droneSighting~=nil,"sustained player presence in cone confirms a sighting")
assertTrue(networkContext.security.droneMode=="AGGRESSIVE" and networkContext.security.droneSighting~=nil,"one confirmed drone sighting alarms every HCO security network on the map")
assertTrue(networkDrone.hcoDestX==nil and networkDrone.hcoNextSearchAt==0,"networked drones immediately abandon stale patrol destinations for the reported contact")
assertTrue(networkGuard.enemyInSight==true and networkGuard.combat==true,"networked response guards receive actionable player contact rather than a cosmetic alert")
game.playerActor.x,game.playerActor.y=2000,2000
networkContext.security.droneMode="AGGRESSIVE"
patrolProbe:update(0.1)
assertTrue(patrolProbe.lightColorCurrent==patrolProbe.lightColorInactive,"an alarmed drone wing visibly retains its red search state without firing through geometry")

-- A calm, plausible disguise slows patrol identification but never grants
-- permanent invisibility; suspicious behavior restores full acquisition.
context.security.droneSighting=nil
context.security.droneMode="PATROL"
rootState.disguise={group="security"}
rootState.disguiseRisk=0
detector.hcoDetect,detector.hcoSightGrace,detector.hcoTracking,detector.hcoLastConfirmedAt=0,0,0,-100
for _=1,6 do
	local cx,cy=detector:getAimPos()
	game.playerActor.x,game.playerActor.y=cx+math.cos(detector.hcoSensorAngle or 0)*60,cy+math.sin(detector.hcoSensorAngle or 0)*60
	detector:update(0.1)
end
assertTrue(context.security.droneSighting==nil and detector.hcoDetect>0,"valid calm disguise slows patrol-drone identity acquisition")
rootState.disguiseRisk=1
for _=1,8 do
	local cx,cy=detector:getAimPos()
	game.playerActor.x,game.playerActor.y=cx+math.cos(detector.hcoSensorAngle or 0)*60,cy+math.sin(detector.hcoSensorAngle or 0)*60
	detector:update(0.1)
end
assertTrue(context.security.droneSighting~=nil,"suspicious disguised behavior restores full drone acquisition")
rootState.disguise,rootState.disguiseRisk=nil,1

local evidenceDrone=context.security.drones[3]
local evidenceReports=0
context.security.reportDroneBodyEvidence=function(observer,body)
	evidenceReports=evidenceReports+1
	context.security.lastEvidenceObserver,context.security.lastEvidenceBody=observer,body
end
local ex,ey=evidenceDrone:getAimPos()
local deadBody=actorObject(ex+math.cos(evidenceDrone.hcoSensorAngle or 0)*55,ey+math.sin(evidenceDrone.hcoSensorAngle or 0)*55,"evidence-body")
deadBody.dead,deadBody.animVariant=true,"security"
worldNPCs={deadBody}
evidenceDrone.hcoEvidenceScanTime=0
evidenceDrone:update(0.1)
assertTrue(evidenceReports==1 and context.security.droneSeenBodies[deadBody.id],"drone reports an unobstructed dead body inside its real sensor cone exactly once")
evidenceDrone.hcoEvidenceScanTime=0
evidenceDrone:update(0.1)
assertTrue(evidenceReports==1,"shared evidence memory prevents duplicate drone body reports")
worldNPCs={}
detector.hcoIdleTime=config.DRONE_IDLE_RELOCATE_TIME+1
detector:update(0.1)
assertTrue((detector.hcoIdleRecoveries or 0)>=1,"idle watchdog immediately forces a new search or flank destination")
context.security.droneSighting=nil
detector.disrupted=true
for _=1,5 do detector:update(0.1) end
assertTrue(context.security.droneSighting==nil and detector.hcoDetect==0,"electronic disruption suppresses HCO acquisition and relay")
detector.disrupted=false
context.security.droneMode="AGGRESSIVE"
detector.hcoDetect,detector.hcoTracking,detector.hcoSightGrace=0,0,0
detector.runGenericRaycast=false
local strictX,strictY=detector:getAimPos()
game.playerActor.x,game.playerActor.y=strictX+55,strictY
detector:update(0.2)
assertTrue(detector.hcoDetect==0 and detector.hcoTracking==0 and detector.hcoWeaponState=="IDLE","missing native geometry trace cannot grant detection or weapon authority")
detector.runGenericRaycast=base.runGenericRaycast
local bulletCenterX,bulletCenterY=detector:getAimPos()
local fallbackBullet={x=bulletCenterX+12,y=bulletCenterY,travelX=120,travelY=0,firer=game.playerActor,stored=false}
function fallbackBullet:getFirer() return self.firer end
function fallbackBullet:makeInactive() self.inactive=true self.stored=true end
game.activeBullets={fallbackBullet}
local destroyedCone={casting=true,canRender=true,renderForward=true,effects=true}
function destroyedCone:setCasting(value) self.casting=value end
function destroyedCone:setCanRender(value) self.canRender=value end
function destroyedCone:setRenderForward(value) self.renderForward=value end
function destroyedCone:clearEffects() self.effects=false end
detector.lightBuffer=destroyedCone
detector.hcoBurstLeft,detector.hcoLaserCharge=3,0.5
detector.hcoAimTargetX,detector.hcoAimTargetY=999,999
local destroyedBefore=context.security.dronesDestroyed or 0
detector:update(1)
assertTrue(fallbackBullet.inactive,"one-frame player-bullet fallback consumes the projectile after a visible-path hit")
assertTrue(context.security.drones[1].broken,"drone remains bullet-breakable")
assertTrue(detector.hcoWeaponDisabled and detector.hcoWeaponState=="DESTROYED" and detector.hcoBurstLeft==0 and detector.hcoLaserCharge==0,"destruction hard-disables every weapon path and cancels queued fire")
assertTrue(detector.hcoAimTargetX==nil and detector.hcoAimTargetY==nil and detector.hcoDetect==0 and detector.hcoTracking==0,"destroyed carrier drops aim and detection state immediately")
assertTrue(detector.lightBuffer==nil and not destroyedCone.casting and not destroyedCone.canRender and not destroyedCone.renderForward and not destroyedCone.effects,"destroyed drone cannot retain a visible searchlight cone")
assertTrue(removedLightBuffers>=1 and stoppedLightBuffers>=1 and destroyedLightBuffers==1,"destroyed native light buffer leaves every render registry and is released")
assertTrue(context.security.droneCrashEvidence~=nil and context.security.dronesDestroyed==destroyedBefore+1,"destruction records localized crash evidence")
assertTrue(crashGuard.sightX~=nil,"an available response guard is sent to investigate the crash")
failCustomCreate=true
local fallbackContext={slot=2,target=actorObject(120,120),security={sectorPoints={{x=500,y=500}},guards={},drones={},droneCooldown=0}}
drones.request(fallbackContext,1,"fallback-test")
drones.update(fallbackContext,0.1)
assertTrue(#fallbackContext.security.drones==1,"second native security-camera drone launches")
assertTrue(fallbackContext.security.drones[1].hcoFallback==true,"native carrier is marked for diagnostics")
fallbackContext.security.drones[1]:update(1)
assertTrue(fallbackContext.security.drones[1].x~=120 or fallbackContext.security.drones[1].y~=120,"fallback drone remains mobile")
local capContext={slot=3,contract={seed=77,archetype="commander"},target=actorObject(140,140),security={sectorPoints={{x=540,y=540}},guards={},drones={},droneCooldown=0,droneMode="AGGRESSIVE",droneDoctrine={armor=100}}}
drones.request(capContext,1,"armor-cap-test")
drones.update(capContext,0.1)
assertTrue(#capContext.security.drones==1 and capContext.security.drones[1].hcoType.heavy,"Commander aggressive signature launches a heavy model")
assertTrue(capContext.security.drones[1].hcoArmor==3 and capContext.security.drones[1].hcoArmorMax==3,"even extreme doctrine scaling cannot exceed the three-hit heavy ceiling")
local heavy=capContext.security.drones[1]
assertTrue(heavy.hcoHitboxSize==54,"heavy target uses the forgiving full-diagonal carrier")
local heavyX,heavyY=heavy:getAimPos()
-- Native weapons advance a fresh bullet before adding it to activeBullets. The
-- recorded muzzle-to-current sweep must still hit a visible rotor edge even
-- though the latest one-frame reconstruction no longer crosses the drone.
local edgeBullet={shootX=heavyX-80,shootY=heavyY+25.5,x=heavyX+35,y=heavyY+25.5,travelX=70,travelY=0,firer=game.playerActor,stored=false}
function edgeBullet:getFirer() return self.firer end
function edgeBullet:makeInactive() self.inactive=true self.stored=true end
game.activeBullets={edgeBullet}
heavy:update(1)
assertTrue(edgeBullet.inactive and heavy.hcoArmor==2,"fallback registers a shot across the visible heavy rotor edge")
edgeBullet.stored,edgeBullet.inactive=false,false
edgeBullet.shotNumber=99
edgeBullet.shootX,edgeBullet.shootY=heavyX-90,heavyY-24
edgeBullet.x,edgeBullet.y=heavyX+35,heavyY-24
edgeBullet.travelX,edgeBullet.travelY=80,0
game.activeBullets={edgeBullet}
heavy:update(1)
assertTrue(edgeBullet.inactive and heavy.hcoArmor==1,"pooled bullet reuse clears the prior hit flag and receives an independent Heavy edge sweep")
heavy.body.destroyed=true
heavy.fixture.destroyed=true
heavy.initHitbox=function() error("simulated persistent fixture failure") end
heavy.hcoDetect,heavy.hcoTracking,heavy.hcoWeaponState=0.4,2,"AIMING"
heavy:update(0.8)
assertTrue(heavy.broken and heavy.hcoSafetyRetired and heavy.hcoDetect==0 and heavy.hcoWeaponState=="DESTROYED","persistently unhittable drone is terminally inert and safely retired before it can attack")

envController={getRoofReady=function() return false end}
local pendingContext={slot=4,target=actorObject(160,160),security={sectorPoints={{x=600,y=600}},guards={},drones={},droneCooldown=0}}
drones.request(pendingContext,1,"roof-readiness-test",true)
drones.update(pendingContext,0.1)
assertTrue(#pendingContext.security.drones==0 and pendingContext.security.droneDeploymentRequested==1,"deployment remains queued until the native roof map is finalized")
envController=nil
print("HCO_DRONE_SMOKE_PASS")
os.exit(0)
