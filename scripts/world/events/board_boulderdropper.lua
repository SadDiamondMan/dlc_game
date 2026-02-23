local BoardBoulderDropper, super = Class(Event, "board_boulderdropper")

function BoardBoulderDropper:init(data)
    super.init(self, data)
    local properties = data and data.properties or {}
	self.timer = 0
	self.init = false
	self.droprate = 40
	self.dropratefluctuation = 15
	self.startedup = false
	self.player = nil
	self.defaultpremake = properties["type"] or "player"
	self.resettimer = properties["resettimer"] or false
	self.premake = self.defaultpremake
	self.premakeinit = 2
end

function BoardBoulderDropper:update()
	super.update(self)
	local board = Game.world.board
	if not board then
		return
	end
	local player = Game.world.board.player
	if self.defaultpremake == "player" then
		local playerx, _ = player:getScreenPos()
		if playerx < 320 then
			self.premake = "right"
		else
			self.premake = "left"
		end
	end
	local cx = board.camera.x - 384/2 - 128
	local cy = board.camera.y - 256/2 - 64
	local colfa, rowfa = board.future_area_column, board.future_area_row
	local cola, rowa = board.area_column, board.area_row
	local colb, rowb = board:getArea(self.x, self.y)
	if colfa == colb and rowfa == rowb and board.swapping_grid and self.premakeinit == 2 then
		self.premakeinit = 0
	end
	if self.premakeinit == 0 then
		if self.premake == "right" then
			local boulder = BoardBoulder(cx - 120 + MathUtils.randomInt(-20, 20), cy + MathUtils.randomInt(60) + 20)
			boulder.layer = self.layer
			board:addChild(boulder)
			boulder = BoardBoulder(cx - 40 + MathUtils.randomInt(-20, 20), cy + MathUtils.randomInt(60))
			boulder.layer = self.layer
			board:addChild(boulder)
		end
		if self.premake == "left" then
			local boulder = BoardBoulder(cx + 760 + MathUtils.randomInt(-20, 20), cy + MathUtils.randomInt(60) + 20)
			boulder.layer = self.layer
			board:addChild(boulder)
			boulder = BoardBoulder(cx + 680 + MathUtils.randomInt(-20, 20), cy + MathUtils.randomInt(60))
			boulder.layer = self.layer
			board:addChild(boulder)
		end
		if self.premake == "vert" then
			local boulder = BoardBoulder(cx + MathUtils.random(0, 4*32), cy - 80 + MathUtils.randomInt(-20, 40))
			boulder.layer = self.layer
			board:addChild(boulder)
			boulder = BoardBoulder(cx + MathUtils.random(7*32, 11*32), cy - 80 + MathUtils.randomInt(-20, 40))
			boulder.layer = self.layer
			board:addChild(boulder)
		end
		self.premakeinit = 1
	end	
	if cola == colb and rowa == rowb then
		if board.swapping_grid then
			self.premakeinit = 2
			for _,boulder in ipairs(self.stage:getObjects(BoardBoulder)) do
				if boulder then
					boulder:remove()
				end
			end
		end
		
		if not self.init and not board.swapping_grid then
			self.timer = self.droprate - 1

			local boulder = BoardBoulder(cx + 320 + MathUtils.randomInt(-30, 30), cy - MathUtils.randomInt(60))
			boulder.layer = self.layer
			board:addChild(boulder)
			
			self.init = true
		end
		self.timer = self.timer + DTMULT
		if self.timer >= self.droprate and not board.swapping_grid then
			local boulder = BoardBoulder(cx + 180 + MathUtils.randomInt(320), cy - MathUtils.randomInt(40))
			boulder.layer = self.layer
			board:addChild(boulder)
			self.timer = MathUtils.randomInt(self.dropratefluctuation)
		end
	else
		if self.resettimer then
			self.timer = 0
		end
	end
	if self.premake == "vert" then
		for _,boulder in ipairs(self.stage:getObjects(BoardBoulder)) do
			if boulder and boulder.x >= cx + (4.5) * 32 and boulder.x <= cx + (7.5) * 32 then
				boulder.x = cx + TableUtils.pick({
					MathUtils.random((8.5) * 32, 11 * 32),
					MathUtils.random(0, (3.5) * 32),
				})
			end
		end
	end
end

return BoardBoulderDropper