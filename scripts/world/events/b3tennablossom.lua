local b3tennablossom, super = Class(Event)

function b3tennablossom:init(data)
    super.init(self, data)

    self:setSprite("world/events/sword/b3_tenna_blossom")
	self.visible = false
	self.con = 0
end

function b3tennablossom:update()
    super.update(self)
	local grayregion = Game.world.board.grayregion
	if self.con == 0 then
		if grayregion then
			if grayregion:collidesWith(self) then
				self.visible = true
				self.sprite:play(4/30, false)
				Game.world.board:spawnObject(BoardPointsDisplay(self.x + 16, self.y + 32, 100), self.layer + 0.1)
				self.con = 1
			end
		end
	end
end

return b3tennablossom