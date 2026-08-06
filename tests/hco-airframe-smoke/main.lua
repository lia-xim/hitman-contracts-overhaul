local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path

function love.errorhandler(message)
	io.stderr:write("HCO_AIRFRAME_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n")
	os.exit(1)
end

local function assertTrue(value, message) if not value then error(message) end end

local imageDraws, batchUpdates, treeInserts = 0, 0, 0
local lastSpriteUpdate, lastWreckUpdate, flightEffectRectangles = nil, nil, 0
love = {graphics={}}
love.errorhandler = function(message) io.stderr:write("HCO_AIRFRAME_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n") os.exit(1) end
function love.graphics.newImage(path) return {path=path,setFilter=function() end} end
function love.graphics.newQuad(x,y,w,h) return {x=x,y=y,w=w,h=h} end
function love.graphics.setColor() end
function love.graphics.circle() end
function love.graphics.line() end
function love.graphics.rectangle() flightEffectRectangles=flightEffectRectangles+1 end
function love.graphics.push() end
function love.graphics.pop() end
function love.graphics.translate() end
function love.graphics.rotate() end
function love.graphics.setLineWidth() end
function love.graphics.draw(image,quad,x,y,rotation,sx,sy,ox,oy)
	imageDraws=imageDraws+1
	lastDirectDraw={image=image and image.path,quad=quad,x=x,y=y,rotation=rotation,sx=sx,sy=sy,ox=ox,oy=oy}
end

priorityRenderer={activeRenderMap={},renderOrder={[0]=0}}
function priorityRenderer:add(object, priority)
	if self.activeRenderMap[object] then return end
	local struct={object=object,priority=priority}
	table.insert(self.renderOrder,struct)
	self.renderOrder[0]=self.renderOrder[0]+1
	self.activeRenderMap[object]=struct
end
function priorityRenderer:remove(object)
	local struct=self.activeRenderMap[object]
	if not struct then return end
	for i,candidate in ipairs(self.renderOrder) do if candidate==struct then table.remove(self.renderOrder,i) break end end
	self.renderOrder[0]=self.renderOrder[0]-1
	self.activeRenderMap[object]=nil
end
function priorityRenderer:findObject(object) return self.activeRenderMap[object] end

spriteBatchController={containers={}}
function spriteBatchController:getContainer(id) return self.containers[id] end
function spriteBatchController:newSpriteBatch(id)
	local container={id=id,slots={},nextSlot=0,visibility=0}
	function container:setShouldSortSprites() end
	function container:setColor() end
	function container:allocateSlot() self.nextSlot=self.nextSlot+1 self.slots[self.nextSlot]=true return self.nextSlot end
	function container:getAllocatedSlot(slot) return self.slots[slot] end
	function container:deallocateSlot(slot) self.slots[slot]=nil return true end
	function container:increaseVisibility() if self.visibility==0 then priorityRenderer:add(self,68) end self.visibility=self.visibility+1 end
	function container:decreaseVisibility() self.visibility=self.visibility-1 if self.visibility==0 then priorityRenderer:remove(self) end end
	function container:getVisibility() return self.visibility end
	function container:updateSprite(slot,quad,x,y,rotation,sx,sy,ox,oy)
		batchUpdates=batchUpdates+1
		local update={slot=slot,quad=quad,x=x,y=y,rotation=rotation,sx=sx,sy=sy,ox=ox,oy=oy}
		if self.id=="hco_drone_wreck_airframes" then lastWreckUpdate=update else lastSpriteUpdate=update end
	end
	self.containers[id]=container
	return container,true
end

local renderTree={}
function renderTree:insert() treeInserts=treeInserts+1 end
local visHandler={}
function visHandler:removeObject(object) object.removedFromVisibility=true end
local world={}
function world:getDecorQuadTree() return renderTree end
function world:getDecorQuadTreeVisHandler() return visHandler end
function world:addDecorEntity(object) object.WITHINQUADTREE=true renderTree:insert(object) end
function world:removeDecorationEntity(object) object.WITHINQUADTREE=false end
game={worldObject=world}

entity={mtindex={}}
entity.mtindex.__index=entity
function entity:init() self.x,self.y=0,0 self._isValid=true end
function entity:_onRegister() end
function entity:onRegister() end
function entity:enumerateActions() end
function entity:_onPlacedIntoMap() end
function entity:onPlacedIntoMap() if not self._placed then self._placed=true self:_onPlacedIntoMap() end end
function entity:isValid() return self._isValid end
function entity:remove() self._isValid=false end

objects={registered={}}
function objects.getClassData(id) return objects.registered[id] end
function objects.registerNew(data)
	data.baseClass=entity
	setmetatable(data,entity.mtindex)
	data.mtindex={__index=data}
	objects.registered[data.class]=data
end
function objects.create(id)
	local class=objects.registered[id]
	local instance=setmetatable({},class.mtindex)
	instance:init()
	return instance
end

curTime=1
local owner={x=100,y=200,curViewAngRad=0.5,hcoBodyAngle=0.25,hcoSensorAngle=0.5,hcoFrame=2,hcoType={index=5,heavy=true,renderScale=0.57},hcoContext={security={droneMode="PATROL"}}}
local airframes=require("hco/security/drone_airframe")
assertTrue(airframes.initialize(),"native airframe class registers")
local shell,err=airframes.create(owner,113,213)
assertTrue(shell~=nil,err or "airframe creation failed")
assertTrue(shell.WITHINQUADTREE and treeInserts>=1,"airframe enters native decor quadtree")
shell:enterVisibilityRange()
shell:draw()
assertTrue(batchUpdates==1,"quadtree draw updates native sprite-batch slot")
assertTrue(math.abs(lastSpriteUpdate.sx-0.57)<0.0001 and math.abs(lastSpriteUpdate.sy-0.57)<0.0001,"heavy airframe uses its roster scale")
assertTrue(math.abs(lastSpriteUpdate.rotation-(0.25-math.pi*0.5))<0.0001,"airframe body follows the flight heading independently of the sensor")
local stats=airframes.diagnostics()
assertTrue(stats.drawPasses==1 and stats.batchReady and stats.spriteReady and stats.wreckSpriteReady and stats.airframes==1,"native diagnostics report both live and wreck atlases ready")
assertTrue(priorityRenderer.activeRenderMap[spriteBatchController.containers.hco_drone_roster_airframes]~=nil,"native roster sprite batch enters priority renderer")
assertTrue(airframes.drawOutline(shell) and imageDraws==1,"aim outline draws the runtime atlas frame directly")
owner.x,owner.y,owner.hcoFrame,owner.hcoBodyAngle,owner.hcoSensorAngle=150,250,3,0.4,0.8
airframes.sync(shell,owner)
assertTrue(shell.x==163 and shell.y==263 and shell.hcoFrame==3,"airframe follows sensor carrier")
assertTrue(shell.hcoBodyAngle==0.4 and shell.hcoSensorAngle==0.8,"body and gimbal angles remain independent")
curTime=2
shell:draw()
assertTrue(flightEffectRectangles>=4,"movement creates a short pixel wake")
owner.disrupted=true
owner.hcoContext.security.droneMode="AGGRESSIVE"
owner.hcoHitFlash=0.4
owner.hcoArmorDisplay=0.9
owner.hcoArmor,owner.hcoArmorMax=2,3
owner.hcoLastArmorDamage=2
airframes.sync(shell,owner)
assertTrue(shell.hcoDisrupted and shell.hcoAggressive,"sensor state reaches native airframe effects")
local rectanglesBeforeImpact=flightEffectRectangles
shell:draw()
assertTrue(flightEffectRectangles>=rectanglesBeforeImpact+12,"heavy impact renders nine sparks plus three readable armor pips")
assertTrue(shell.hcoArmor==2 and shell.hcoArmorMax==3,"airframe receives bounded heavy armor state")
local crashStartX,crashStartY=shell.x,shell.y
local landX,landY=airframes.crash(shell,owner,crashStartX,crashStartY)
assertTrue(landX~=crashStartX or landY~=crashStartY,"destroyed airframe receives a real tumble destination")
local crashStats=airframes.diagnostics()
assertTrue(crashStats.airframes==0 and crashStats.wrecks==1,"crashing shell leaves the active roster and enters wreck lifecycle")
assertTrue(crashStats.wreckBatchReady,"crashing shell immediately acquires the dedicated native wreck batch")
curTime=2.4
local updatesBeforeCrashTick=batchUpdates
airframes.update(owner.hcoContext,0.4)
assertTrue(batchUpdates>updatesBeforeCrashTick and lastWreckUpdate.quad.x==96,"runtime tick advances a static wreck from damage frame one to frame two without relying on another decor draw")
shell:draw()
assertTrue(lastWreckUpdate~=nil,"destroyed airframe updates the dedicated native wreck batch")
assertTrue(lastWreckUpdate.x~=crashStartX or lastWreckUpdate.y~=crashStartY,"mid-crash wreck sprite moves away from its flight position")
assertTrue(math.abs(lastWreckUpdate.rotation-(0.4-math.pi*0.5))>0.2,"mid-crash wreck visibly tumbles")
assertTrue(shell.hcoSlot==nil,"destroyed airframe releases the cached intact sprite-batch slot")
assertTrue(shell.hcoWreckSlot~=nil,"destroyed airframe retains a visible native wreck slot")
assertTrue(priorityRenderer.activeRenderMap[spriteBatchController.containers.hco_drone_wreck_airframes]~=nil,"wreck batch remains registered in the priority renderer")
curTime=3.2
airframes.update(owner.hcoContext,0.8)
shell:draw()
assertTrue(lastWreckUpdate.quad.x==288,"landed drone persists as the unmistakable final wreck frame")
assertTrue(not airframes.drawOutline(shell),"landed wreck never keeps an aim outline")
airframes.clearContext(owner.hcoContext)
assertTrue(not shell:isValid(),"context cleanup removes persistent crash wrecks")
print("HCO_AIRFRAME_SMOKE_PASS")
os.exit(0)
