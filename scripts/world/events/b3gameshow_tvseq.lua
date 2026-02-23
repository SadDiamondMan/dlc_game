local b3gameshow_tvseq, super = Class(Event, "b3gameshow_tvseq")

function b3gameshow_tvseq:init(data)
    super.init(self, data)

    self:setSprite("world/events/sword/b3gameshow_word")
	self.visible = false
end

function b3gameshow_tvseq:update()
    super.update(self)
	local grayregion = Game.world.board.grayregion
	if grayregion then
		if grayregion:collidesWith(self) then
			self.visible = true
		end
	end
end

return b3gameshow_tvseq