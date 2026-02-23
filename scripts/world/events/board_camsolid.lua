local BoardCamSolid, super = Class(Event)

function BoardCamSolid:init(data)
    super.init(self, data)

    local properties = data and data.properties or {}

	self.camera_block_frames = Assets.getFrames("world/events/sword/camerablock/camerablock")
	self.solid_positions = {
		{x = 0, y = 0},
		{x = 16, y = 0},
		{x = 0, y = 16},
		{x = 16, y = 16},
	}
	self.solid_colliders = {
		Hitbox(self, 0, 0, 16, 16),
		Hitbox(self, 16, 0, 16, 16),
		Hitbox(self, 0, 16, 16, 16),
		Hitbox(self, 16, 16, 16, 16),
	}
	self.camblock_collider = Hitbox(self, 0, 0, 32, 32)
	self.collider = ColliderGroup(self, self.solid_colliders)
	self.solid = true
end

function BoardCamSolid:update()
    super.update(self)
	for i = 1, 4 do
		self.solid_colliders[i].collidable = true
	end	
	local grayregion = Game.world.board.grayregion
	if grayregion then
		local photocollider = Hitbox(self, 4, 4, 4, 4)
		if grayregion:collidesWith(photocollider) then
			self.solid_colliders[1].collidable = false
		end
		photocollider = Hitbox(self, 4 + 16, 4, 4, 4)
		if grayregion:collidesWith(photocollider) then
			self.solid_colliders[2].collidable = false
		end
		photocollider = Hitbox(self, 4, 4 + 16, 4, 4)
		if grayregion:collidesWith(photocollider) then
			self.solid_colliders[3].collidable = false
		end
		photocollider = Hitbox(self, 4 + 16, 4 + 16, 4, 4)
		if grayregion:collidesWith(photocollider) then
			self.solid_colliders[4].collidable = false
		end
	end
end

function BoardCamSolid:draw()
    super.draw(self)
	for i = 1, 4 do
		if self.solid_colliders[i].collidable then
			Draw.draw(self.camera_block_frames[i], self.solid_positions[i].x, self.solid_positions[i].y, 0, 2, 2)
		end		
	end
end

return BoardCamSolid