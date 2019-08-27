cnfg = require "config"
mf = require "mathFunctions"

local _M = {}


--##########################################################
-- Player data
--##########################################################

-- 7E:09C2 - 7E:09C3    Samus's health
-- 7E:09D6 - 7E:09D7    Samus's reserve tanks
-- 7E:09C6 - 7E:09C7    Samus's missiles
-- 7E:09CA - 7E:09CB    Samus's super missiles
-- 7E:09CE - 7E:09CF    Samus's power bombs

function _M.getHealth()	return memory.read_s16_le(0x09C2) end
function _M.getTanks() return memory.read_s16_le(0x09D6) end
function _M.getMissiles() return memory.read_s16_le(0x09C6) end
function _M.getSuperMissiles() return memory.read_s16_le(0x09CA) end
function _M.getBombs() return memory.read_s16_le(0x09CE) end


--##########################################################
-- Graphic data
--##########################################################

-- 7E:0AF6 - 7E:0AF7    Samus's X position in pixels
-- 7E:0AFA - 7E:0AFB    Samus's Y position in pixels
-- 7E:0B04 - 7E:0B05    Samus's X position on screen (0AF6 - 0911) (used for ellipse)
-- 7E:0B06 - 7E:0B07    Samus's Y position on screen (0AFA - 0915)
function _M.getPositions()
	samusX = memory.read_s16_le(0x0AF6)
	samusY = memory.read_s16_le(0x0AFA)
	_M.screenX = memory.read_s16_le(0x0B04)
	_M.screenY = memory.read_s16_le(0x0B06)
end

-- 7E:18A8 - 7E:18A9    Samus's invincibility timer when hurt
function _M.getSamusHitTimer() return memory.readbyte(0x18A8) end

function _M.getSamusHit(alreadyHit)
	local timer = _M.getSamusHitTimer()
	if timer > 0 then
		if alreadyHit == false then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- 7E:0990 - 7E:0991    Current X position of block(s) on screen Layer 1 or 2 to update?
-- 7E:0992 - 7E:0993    Current Y position of block(s) on screen Layer 1 or 2 to update?
function _M.getBlocks()
	local blocks = {}
	
	blockX = memory.read_s16_le(0x0990)
	blockY = memory.read_s16_le(0x0992)
		
	blocks[#blocks+1] = {["x"] = blockX, ["y"] = blockY, ["good"] = 1}
		
	return blocks
end

-- 7E:0D08 - 7E:0D09    X position of Grapple point
-- 7E:0D0C - 7E:0D0D    Y position of Grapple point
function _M.getGrapplePoints()
	local grapples = {}
	
	grappleX = memory.read_s16_le(0x0D08)
	grappleY = memory.read_s16_le(0x0D0C)
		
	grapples[#grapples+1] = {["x"] = grappleX, ["y"] = grappleY, ["good"] = 1}
		
	return grapples
end

-- 7E:1C29 - 7E:1C2A    Calculated PLM's X position
-- 7E:1C2B - 7E:1C2C    Calculated PLM's Y position
function _M.getPLMs()
	local plms = {}
	
	plmX = memory.read_s16_le(0x1C29)
	plmY = memory.read_s16_le(0x1C2B)
		
	plms[#plms+1] = {["x"] = plmX, ["y"] = plmY, ["good"] = -1}
		
	return plms
end

-- 7E:1A4B - 7E:1A6E    X position of projectile, in pixels (related to Enemies)
-- 7E:1A93 - 7E:1AB6    Y position of projectile, in pixels (related to Enemies)
function _M.getEnemyProjectiles()
	local eProjectiles = {}
	
	epX = memory.read_s32_le(0x1A4B)
	epY = memory.read_s32_le(0x1A93)

	eProjectiles[#eProjectiles+1] = {["x"] = epX, ["y"] = epY, ["good"] = -1}
		
	return eProjectiles
end


--##########################################################
-- Input data
--##########################################################

function _M.getInputs()
	_M.getPositions()
	
	blocks = _M.getBlocks()
	grapples = _M.getGrapplePoints()
	plms = _M.getPLMs()
	eProj = _M.getEnemyProjectiles()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
	for dy=-cnfg.BoxRadius*16,cnfg.BoxRadius*16,16 do
		for dx=-cnfg.BoxRadius*16,cnfg.BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			for i = 1,#blocks do
				distx = math.abs(blocks[i]["x"] - (samusX+dx))
				disty = math.abs(blocks[i]["y"] - (samusY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = blocks[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then inputDeltaDistance[#inputDeltaDistance] = mf.squashDistance(dist) end
				end
			end

			for i = 1,#grapples do
				distx = math.abs(grapples[i]["x"] - (samusX+dx))
				disty = math.abs(grapples[i]["y"] - (samusY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = grapples[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then inputDeltaDistance[#inputDeltaDistance] = mf.squashDistance(dist) end
				end
			end

			for i = 1,#plms do
				distx = math.abs(plms[i]["x"] - (samusX+dx))
				disty = math.abs(plms[i]["y"] - (samusY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = plms[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then inputDeltaDistance[#inputDeltaDistance] = mf.squashDistance(dist) end
				end
			end

			for i = 1,#eProj do
				distx = math.abs(eProj[i]["x"] - (samusX+dx))
				disty = math.abs(eProj[i]["y"] - (samusY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = eProj[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then inputDeltaDistance[#inputDeltaDistance] = mf.squashDistance(dist) end
				end
			end
		end
	end

	return inputs, inputDeltaDistance
end

function _M.clearJoypad()
	controller = {}
	for b = 1,#cnfg.ButtonNames do
		controller["P1 " .. cnfg.ButtonNames[b]] = false
	end
	joypad.set(controller)
end


return _M
