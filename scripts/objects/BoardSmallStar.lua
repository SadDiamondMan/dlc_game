---@class BoardSmallStar : Object
---@overload fun(...) : BoardSmallStar
local BoardSmallStar, super = Class(Object)

function BoardSmallStar:init(x, y)
    super.init(self, x, y)

	self.frames = {
		Assets.getTexture("sword/effects/star_8px/" .. Game.world.board.player.actor.id) or Assets.getTexture("sword/effects/star_8px/board_kris"),
		Game.world.board.followers[1] and Assets.getTexture("sword/effects/star_8px/" .. Game.world.board.followers[1].actor.id) or Assets.getTexture("sword/effects/star_8px/board_susie"),
		Game.world.board.followers[2] and Assets.getTexture("sword/effects/star_8px/" .. Game.world.board.followers[2].actor.id) or Assets.getTexture("sword/effects/star_8px/board_ralsei")
	}
	self.frame = 0
	self.true_x = self.x
	self.true_y = self.y
end

function BoardSmallStar:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function BoardSmallStar:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

function BoardSmallStar:draw()
	Draw.draw(self.frames[((self.frame) % #self.frames) + 1], 0, 0, 0, 2, 2)
	super.draw(self)
end

return BoardSmallStar