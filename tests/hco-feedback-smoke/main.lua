local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path
scrW,scrH=1920,1080
function _S(v) return v end
local texts,sounds,chimes={}, {}, 0
love={audio={newSource=function() return {setVolume=function() end,play=function() chimes=chimes+1 end} end}}
love.errorhandler=function(message) io.stderr:write("HCO_FEEDBACK_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n") os.exit(1) end
gui={}
function gui.create()
	local o={w=420,valid=true}
	for _,name in ipairs({"setFont","setTargetW","setupVisual","addDepth","wrapText","setPos"}) do o[name]=function() end end
	o.setText=function(_,value) table.insert(texts,value) end
	o.isValid=function(self) return self.valid end
	o.kill=function(self) self.valid=false end
	return o
end
sound={play=function(_,id) table.insert(sounds,id) end}
game={playerActor={},addHUDElement=function() end}
local feedback=require("hco/feedback")
assert(feedback.show("FIRST TACTICAL NOTICE"),"first notice queues")
assert(feedback.show("SECOND TACTICAL NOTICE"),"second notice queues")
assert(#texts==0,"queued notices do not overlap native objective startup")
feedback.update(1.25)
assert(#texts==1 and texts[1]=="FIRST TACTICAL NOTICE","first queued notice renders alone")
feedback.update(3.4)
feedback.update(0.45)
assert(#texts==2 and texts[2]=="SECOND TACTICAL NOTICE","second notice waits for first")
assert(feedback.complete({archetype="commander",condition={result=true}},4200),"completion banner renders")
assert(texts[3]:find("CONTRACT COMPLETE") and texts[3]:find("%+%$4200") and texts[3]:find("BONUS CONDITION COMPLETE"),"completion text is explicit")
assert(chimes==1,"custom completion chime plays")
assert(#sounds==1 and sounds[1]=="wep_select_confirm","native confirmation fallback layers safely")
print("HCO_FEEDBACK_SMOKE_PASS")
os.exit(0)
