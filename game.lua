config = require "config"
spritelist = require "spritelist"

local _M = {}

--##########################################################
-- Player data
--##########################################################

-- 7E:09C2 - 7E:09C3    Samus's health
function _M.getHealth()
	local health = memory.read_s16_le(0x09C2)
	return health
end

-- 7E:09C6 - 7E:09C7    Samus's missiles
function _M.getMissiles()
	local missiles = memory.read_s16_le(0x09C6)
	return missiles
end

-- 7E:09CA - 7E:09CB    Samus's super missiles
function _M.getMissiles()
	local superMissiles = memory.read_s16_le(0x09CA)
	return superMissiles
end

-- 7E:09CE - 7E:09CF    Samus's power bombs
function _M.getBombs()
	local bombs = memory.read_s16_le(0x09CE)
	return bombs
end

-- 7E:09D6 - 7E:09D7    Samus's reserve tanks
function _M.getTanks()
	local tanks = memory.read_s16_le(0x09D6)
	return tanks
end


--##########################################################
-- Graphic data WIP
--##########################################################

-- 7E:0AF6 - 7E:0AF7    Samus's X position in pixels
-- 7E:0AFA - 7E:0AFB    Samus's Y position in pixels
-- 7E:0B04 - 7E:0B05    Samus's X position on screen (0AF6 - 0911)
-- 7E:0B06 - 7E:0B07    Samus's Y position on screen (0AFA - 0915)
function _M.getPositions()
	samusX = memory.read_s16_le(0x0AF6)
	samusY = memory.read_s16_le(0x0AFA)
	_M.screenX = memory.read_s16_le(0x0B04)
	_M.screenY = memory.read_s16_le(0x0B06)
end

-- 7E:18A8 - 7E:18A9    Samus's invincibility timer when hurt
function _M.getSamusHit(alreadyHit)
	local timer = memory.read_s16_le(0x18A8)
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

function _M.getSamusHitTimer()
	local timer = memory.readbyte(0x18A8)
	return timer
end

-- 7F:0002 - 7F:6401    Room Tilemap (7F!!)
function _M.getTile(dx, dy)
	x = math.floor((samusX+dx+8)/16)
	y = math.floor((samusY+dy)/16)
	
	-- Calculates the tile Samus is standing on
	return memory.readbyte(0x0002 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
end

-- 7E:00D0 - 7E:02AF    Table of entries to update graphics, 7 bytes: Size (2 bytes), source address (3 bytes), VRAM target (2 bytes) (Unsure of size)
-- 7E:0340 - 7E:035B    Table of entries to read from graphics, 9 bytes: VRAM target(cannot be 0, 2 bytes), and all other DMA data (7 bytes) (Unsure of size)
-- 7E:1C37 - 7E:1C86    PLM header table
-- 7E:1F25 - 7E:1F30    Graphic pointer
-- 7E:1C29 - 7E:1C2A    Calculated PLM's X position
-- 7E:1C2B - 7E:1C2C    Calculated PLM's Y position
function _M.getSprites()
	local sprites = {}
	for slot=0,11 do
		local status = memory.readbyte(0x1F25+slot)
		if status ~= 0 then
			spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
			spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
			
			-- $7E009E	12 bytes	Sprites	Sprite number, or Acts Like setting for custom sprites.
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey, ["good"] = spritelist.Sprites[memory.readbyte(0x009e + slot) + 1]}
		end
	end		
		
	return sprites
end

--		;Atmospheric graphics are footsteps, water splash, air bubbles, etc.
-- 7E:0AD4 - 7E:0ADB    Atmospheric graphics animation timers (1-4). 8000+ means 'don't run related code during timer'
-- 7E:0ADC - 7E:0AE3    Atmospheric graphics X position (1-4)
-- 7E:0AE4 - 7E:0AEB    Atmospheric graphics Y position (1-4)
-- 7E:0AEC - 7E:0AF3    Atmospheric graphics type/animation frame number (1-4)
--		;01XX = water splash, 04XX = smoke moving right, 05XX = bubbles, 06XX and 07XX = smoke moving up
function _M.getExtendedSprites()
	local extended = {}
	for slot=0,11 do
		-- $7E170B	10 bytes	Sprites	Extended sprite number. A list of possible values can be found here. Last two bytes reserved for fireballs.
		local number = memory.readbyte(0x170B+slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
			spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey, ["good"]  =  spritelist.extSprites[memory.readbyte(0x170B + slot) + 1]}
		end
	end		
		
	return extended
end

--[[
function _M.getSprites()
	local sprites = {}
	for slot=0,11 do
		-- $7E14C8	12 bytes	Table containing 12 sprite status. The '0' status is used for non-existent sprites and should therefore be excluded. 
		local status = memory.readbyte(0x14C8+slot)
		if status ~= 0 then
			-- $7E00E4	Sprite X position, low byte				$7E14E0	Sprite X position, high byte
			-- $7E00D8	Sprite Y position, low byte				$7E14D4 Sprite Y position, high byte
			spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
			spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
			
			-- $7E009E	12 bytes	Sprites	Sprite number, or Acts Like setting for custom sprites.
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey, ["good"] = spritelist.Sprites[memory.readbyte(0x009e + slot) + 1]}
		end
	end		
		
	return sprites
end

function _M.getExtendedSprites()
	local extended = {}
	for slot=0,11 do
		-- $7E170B	10 bytes	Sprites	Extended sprite number. A list of possible values can be found here. Last two bytes reserved for fireballs.
		local number = memory.readbyte(0x170B+slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
			spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey, ["good"]  =  spritelist.extSprites[memory.readbyte(0x170B + slot) + 1]}
		end
	end		
		
	return extended
end
--]]


--##########################################################
-- Input data
--##########################################################

function _M.getInputs()
	_M.getPositions()
	
	sprites = _M.getSprites()
	extended = _M.getExtendedSprites()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
	for dy=-config.BoxRadius*16,config.BoxRadius*16,16 do
		for dx=-config.BoxRadius*16,config.BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			tile = _M.getTile(dx, dy)
			if tile == 1 and samusY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (samusX+dx))
				disty = math.abs(sprites[i]["y"] - (samusY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = sprites[i]["good"]
					
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (samusX+dx))
				disty = math.abs(extended[i]["y"] - (samusY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
			end
		end
	end
	
	return inputs, inputDeltaDistance
end

function _M.clearJoypad()
	controller = {}
	for b = 1,#config.ButtonNames do
		controller["P1 " .. config.ButtonNames[b]] = false
	end
	joypad.set(controller)
end

return _M