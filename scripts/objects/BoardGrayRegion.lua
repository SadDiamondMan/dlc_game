---@class BoardGrayRegion : Object
---@overload fun(...) : BoardGrayRegion
local BoardGrayRegion, super = Class(Object)

function BoardGrayRegion:init(x, y, width, height)
	super.init(self, x, y, width or 128, height or 96)
	self.siner = 0
	self.layer = WORLD_LAYERS["top"]
	self.cameradeath = false
	self.collider = Hitbox(self, 0, 0, self.width, self.height)
end

function BoardGrayRegion:update()
	super.update(self)
	self.siner = self.siner + DTMULT
	local board = Game.world.board
	if not board then
		return
	end
	if (board.swapping_grid or board.fader.state ~= "NONE" or board.fader.tilescovered > 0) then
		self:remove()
	end
	local player = board.player
	if Game.state == "BATTLE" then
		self:remove()
	end
	if not self.cameradeath and player and (not player.mycam or player.mycam:isRemoved()) then
		self.cameradeath = true
	end
	if self.cameradeath and player and player.mycam and not player.mycam:isRemoved() then
		self:remove()
	end
end
	
return BoardGrayRegion