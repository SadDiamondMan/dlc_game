---@class BoardSprite : Sprite
---@overload fun(...) : BoardSprite
local BoardSprite, super = Class(Sprite)

function BoardSprite:init(...)
	super.init(self, ...)
	self.true_x = self.x
	self.true_y = self.y
end

function BoardSprite:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function BoardSprite:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

return BoardSprite