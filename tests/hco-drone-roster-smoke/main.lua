local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path

function love.errorhandler(message)
	io.stderr:write("HCO_DRONE_ROSTER_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n")
	os.exit(1)
end

local function assertTrue(value, message) if not value then error(message) end end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
curTime = 0

local laserSounds, worldSounds, bullets, damage = 0, 0, 0, 0
love = {audio={}}
love.errorhandler = function(message) io.stderr:write("HCO_DRONE_ROSTER_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n") os.exit(1) end
function love.audio.newSource()
	return {setLooping=function() end,setVolume=function() end,play=function() laserSounds=laserSounds+1 end,stop=function() end}
end
sound = {playWorld=function() worldSounds=worldSounds+1 end}

local sourceActor = {id="guard",isValid=function() return true end,isDead=function() return false end,isUnconscious=function() return false end,getID=function(self) return self.id end}
local player = {x=500,y=500,id="player",isValid=function() return true end,isDead=function() return false end,isUnconscious=function() return false end,getPos=function(self) return self.x,self.y end,getID=function(self) return self.id end,getWeaponBulletHeight=function() return 90 end,takeDamage=function(self,amount) damage=damage+amount end}
game = {playerActor=player,worldObject={getSize=function() return 1000,800 end}}
weapons = {instantiate=function(self,id)
	return {id=id,createBullet=function() bullets=bullets+1 end,getBulletSpeed=function() return 1000 end,getFireSound=function() return "native_fire" end,remove=function(self) self.removed=true end}
end}

local types = require("hco/security/drone_types")
local config = require("hco/config")
local flight = require("hco/security/drone_flight")
local droneWeapons = require("hco/security/drone_weapons")
assertTrue(#types.all()==7,"roster is restricted to exactly seven models")
for index, expected in ipairs({"scout","pistol_light","pistol_heavy","smg_light","smg_heavy","laser_light","laser_heavy"}) do
	assertTrue(types.get(index).id==expected,"roster order is stable for atlas rows")
end
assertTrue(types.get("scout").renderScale==0.32 and types.get("pistol_light").renderScale==0.35 and types.get("pistol_heavy").renderScale==0.39,"RC24 keeps scout, light and heavy silhouettes actor-scaled")
assertTrue(types.get("scout").armor==1 and types.get("pistol_light").armor==1 and types.get("smg_light").armor==1 and types.get("laser_light").armor==1,"all light drones remain strict one-hit targets")
assertTrue(types.get("pistol_heavy").armor==2 and types.get("smg_heavy").armor==3 and types.get("laser_heavy").armor==3,"heavy drones are bounded to two or three ordinary hits")

local context={slot=1,contract={seed=42,archetype="commander"},target={x=490,y=390,getPos=function(self) return self.x,self.y end},security={sectorPoints={{x=-80,y=900},{x=880,y=700}},guards={{role="response",actor=sourceActor}},droneGeneration=1}}
context.security.drones={}
context.security.droneWaveFirstIndex=1
local selected={}
local uniqueCount, heavyCount, laserCount = 0, 0, 0
for index=1,7 do
	local definition=types.select(context,index,true)
	if index <= 6 then assertTrue(not selected[definition.id],"balanced wing keeps the first six models unique") end
	if not selected[definition.id] then uniqueCount=uniqueCount+1 end
	selected[definition.id]=true
	if definition.heavy then heavyCount=heavyCount+1 end
	if definition.family=="laser" then laserCount=laserCount+1 end
	table.insert(context.security.drones,{hcoType=definition,broken=false,hcoIndex=index,x=100+index*90,y=100})
end
assertTrue(selected.smg_heavy,"Commander aggressive wave guarantees its heavy SMG signature")
assertTrue(uniqueCount==6,"caps allow one duplicate only after six distinct balanced roles")
assertTrue(heavyCount<=config.DRONE_MAX_HEAVY_COUNT and laserCount<=config.DRONE_MAX_LASER_COUNT,"balanced wing enforces heavy and laser caps")
context.security.drones={}
local spawnX,spawnY=flight.spawnPoint(context,1)
assertTrue(spawnX>=48 and spawnX<=952 and spawnY>=48 and spawnY<=752,"spawn points are clamped inside world bounds")

local drone={x=300,y=300,hcoIndex=2,hcoContext=context,hcoType=types.get("pistol_light"),hcoSensorAngle=math.atan2(player.y-313,player.x-313),setPos=function(self,x,y) self.x,self.y=x,y end,setLightAngle=function() end}
droneWeapons.update(drone,player,true,0,0.1,true)
droneWeapons.update(drone,player,true,0,0.1,true)
assertTrue(bullets==1 and worldSounds==1,"pistol drone emits a native bullet and native gunshot")

drone.hcoType=types.get("laser_light")
drone.hcoWeaponCooldown=0
for _=1,10 do curTime=curTime+0.1 droneWeapons.update(drone,player,true,0,0.1,true) end
assertTrue(damage==18,"light laser applies damage only after its full telegraph")
assertTrue(laserSounds>=1,"custom light laser asset is played")

drone.hcoTracking=0
flight.beginTracking(drone,player)
local firstAngle=drone.hcoTrackSlotAngle
local x1,y1=flight.destination(drone,player,true)
curTime=curTime+0.1
local x2,y2=flight.destination(drone,player,true)
assertTrue(math.abs(firstAngle-drone.hcoTrackSlotAngle)<0.0001,"tracking keeps a stable formation slot")
assertTrue(math.sqrt((x2-x1)^2+(y2-y1)^2)<20,"tracking destination breathes instead of orbiting past the player")

drone.hcoNextFlankAt=curTime-0.1
local preFlankAngle=drone.hcoTrackSlotAngle
assertTrue(flight.updateTactics(drone,player,true,true)=="FLANK","confirmed aggressive contact schedules a real flank relocation")
assertTrue(drone.hcoTrackSlotAngle~=preFlankAngle and drone.hcoDestX==nil,"flank changes the stable slot and forces a new flight destination")
drone.hcoTracking=0
drone.hcoNextSearchAt=curTime-0.1
assertTrue(flight.updateTactics(drone,player,true,false)=="SEARCH" and drone.hcoSearchPhase==1,"lost aggressive contact advances a timed exploration phase")
context.security.droneMode="AGGRESSIVE"
context.security.lastKnown={x=500,y=400,time=curTime}
local searchX,searchY=flight.destination(drone,player,true)
assertTrue(searchX>=48 and searchX<=952 and searchY>=48 and searchY<=752,"aggressive exploration ring remains inside playable world bounds")

world={PATHFIND_TILE_STATE={FREE=0,WALKABLE=1,OBSTRUCTED=2,DOOR=3,GARAGE_DOOR=4,CLIMBABLE=5,WINDOW=6,OBSTRUCTED_LOW=7}}
local testGrid={worldToIndex=function(_,x,y) return {x=x,y=y} end}
game.worldObject.getFloorTileGrid=function() return testGrid end
game.worldObject.getPFGridValue=function(_,index) return index.x>=340 and world.PATHFIND_TILE_STATE.OBSTRUCTED or world.PATHFIND_TILE_STATE.WALKABLE end
drone.x,drone.y=300,300
drone.hcoCenterOffset=13
drone.hcoDestX,drone.hcoDestY=500,313
local _,_,wallMove,avoided=flight.move(drone,1,60)
assertTrue(avoided and wallMove>0,"building wall triggers an active avoidance maneuver instead of a standstill")
assertTrue(drone.x+13<340,"building avoidance does not cross the blocked wall tile")
local committedWallSide=drone.hcoWallSide
for _=1,4 do flight.move(drone,0.2,60) end
assertTrue(committedWallSide~=nil and drone.hcoWallSide==committedWallSide,"wall following keeps one steering side instead of oscillating left and right every frame")

-- A narrow wall/gate between two outdoor cells is crossed as an explicit
-- unarmed air transit after steering has proven unable to progress. Wide
-- buildings remain rejected by the bounded landing search.
game.worldObject.getPFGridValue=function(_,index)
	return index.x>=340 and index.x<=390 and world.PATHFIND_TILE_STATE.OBSTRUCTED or world.PATHFIND_TILE_STATE.WALKABLE
end
drone.x,drone.y=317,300
drone.hcoDestX,drone.hcoDestY=500,313
drone.hcoBlockedTime=require("hco/config").DRONE_BARRIER_HOP_DELAY
flight.move(drone,0.1,60)
assertTrue(flight.isTransiting(drone) and drone.hcoTransitProgress==0,"narrow barrier starts a controlled flight transition")
for step=1,12 do flight.move(drone,0.1,60) end
assertTrue(not flight.isTransiting(drone) and drone.x+13>390,"barrier transition lands on the verified outdoor side")

envController={
	getRoofReady=function() return true end,
	getPosUnderRoof=function(_,x) return x>=340 and x<=390 end
}
game.worldObject.getPFGridValue=function() return world.PATHFIND_TILE_STATE.WALKABLE end
drone.x,drone.y=317,300
drone.hcoDestX,drone.hcoDestY=500,313
drone.hcoBlockedTime=require("hco/config").DRONE_BARRIER_HOP_DELAY
flight.move(drone,0.1,60)
assertTrue(not flight.isTransiting(drone) and drone.x+13<340,"even a narrow roofed building is never accepted as barrier-hop geometry")
envController=nil

-- Intravenous 2 exposes its finalized indoor map through envController. A
-- pathable tile under a roof is still an invalid armed-drone location.
game.worldObject.getPFGridValue=function() return world.PATHFIND_TILE_STATE.WALKABLE end
game.worldObject.getBestPFPoint=function(_,_,_,targetX,targetY) return {x=targetX,y=targetY} end
testGrid.indexToWorld=function(_,index) return index.x,index.y end
envController={
	getRoofReady=function() return true end,
	getPosUnderRoof=function(_,x) return x<600 end
}
assertTrue(not flight.isSafeCombatPoint(300,300),"roofed pathable floor is rejected as a combat position")
local outdoorX,outdoorY=flight.snapToPlayable(300,300,300,300)
assertTrue(outdoorX and outdoorX>=622 and flight.isSafeCombatPoint(outdoorX,outdoorY),"indoor route point is migrated to a fully clear outdoor footprint")
drone.x,drone.y=650-13,420-13
drone.hcoDestX,drone.hcoDestY=300,420
local _,_,roofMove,roofAvoided=flight.move(drone,1,120)
assertTrue(roofAvoided and roofMove>0 and drone.x+13>=600,"lag-sized movement step cannot tunnel through a roofed building footprint")
local getFloorTileGrid=game.worldObject.getFloorTileGrid
game.worldObject.getFloorTileGrid=function() return nil end
assertTrue(not flight.isSafeCombatPoint(700,300),"ready roof controller with missing floor geometry fails closed")
game.worldObject.getFloorTileGrid=getFloorTileGrid
envController=nil

drone.hcoBodyAngle=0
drone.hcoSensorAngle=0
flight.updateAim(drone,0.1,player,true,0)
assertTrue(drone.hcoSensorAngle~=drone.hcoBodyAngle,"sensor gimbal turns independently before the airframe body")

print("HCO_DRONE_ROSTER_SMOKE_PASS")
os.exit(0)
