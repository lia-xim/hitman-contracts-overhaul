local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path
local draws=0
love={graphics={}}
love.errorhandler=function(message) io.stderr:write("HCO_VISUAL_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n") os.exit(1) end
function love.graphics.newImage() return {setFilter=function() end} end
function love.graphics.newQuad() return {} end
function love.graphics.setColor() end
function love.graphics.draw() draws=draws+1 end
local goon={postDraw=function() end}
actor={getClassData=function(id) if id=="goon" then return goon end end}
local priorityDraws=0
priorityRenderer={activeRenderMap={},renderOrder={}}
function priorityRenderer:add(object, priority)
	self.activeRenderMap[object]={object=object,priority=priority}
	table.insert(self.renderOrder, object)
end
function priorityRenderer:findObject(object)
	for _, candidate in ipairs(self.renderOrder) do if candidate==object then return candidate end end
end
function priorityRenderer:draw()
	priorityDraws=priorityDraws+1
	for _, object in ipairs(self.renderOrder) do object:draw() end
end
local state={hooks={}}
assert(require("hco/visuals").initialize(state),"visual hook installs")
local npc=setmetatable({_hcoFactionVisual=2,_hcoContractTarget=true,_visible=true},{__index=goon})
function npc:getDrawPosition() return 100,100 end
function npc:getAngle() return 0 end
npc:postDraw()
assert(draws==1,"faction insignia renders once")
print("HCO_VISUAL_SMOKE_PASS")
os.exit(0)
