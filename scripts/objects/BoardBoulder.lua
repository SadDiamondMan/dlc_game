local BoardBoulder, super = Class(Object)

function BoardBoulder:init(x, y)
    super.init(self, x - 16, y - 16)

	self.damage = 1
    self.sprite = Sprite("world/events/sword/boulder")
	self:addChild(self.sprite)
	self.sprite:setScale(2)
	self.sprite:setOrigin(0.5)
    self.destroy_on_hit = false
	self.solid = false
	self.init = 0
	self.myhealth = 2
	self.con = 1
	self.timer = 0
	self.waittime = 8
	self.cury = self.y + MathUtils.randomInt(50) + 10
	self.image_flipper = MathUtils.randomInt(80)
	self.physics.gravity = 0.7 + MathUtils.random(0.1)
	self.true_x = self.x
	self.true_y = self.y
	self.collider = Hitbox(self, -16, -16, 32, 32)
end

function BoardBoulder:update()
	super.update(self)
	local board = Game.world.board
	if not board then
		return
	end
	local cx = board.camera.x - 384/2 - 128
	local cy = board.camera.y - 256/2 - 64
	if self.con == 0 then
		self.waittime = 20 + MathUtils.randomInt(-4, 4)
		self.timer = 0
		self.cury = self.y
		self.con = 1
	end
	local grayregion = Game.world.board.grayregion
	if grayregion then
		if grayregion:collidesWith(self) then
			self:remove()
		end
	end
	if self.con == 1 then
		if self.y > self.cury + 60 then
			self.physics.speed_y = -6 + MathUtils.random(2)
			Assets.stopAndPlaySound("bump", 0.5, 0.9)
			self.con = 0
		end
	end
	if self.y > cy + 400 then
		self:remove()
	end
	if not board.swapping_grid then
		self.x = MathUtils.clamp(self.x, cx + 160, cx + 448)
	end
end

function BoardBoulder:onCollide(chara)
	local can_hurt = true
	if not chara.is_player then
		can_hurt = false
	end
    if can_hurt then
		chara:hurt(self.damage, self)
		if self.destroy_on_hit then
			self:remove()
		end
		return true
	end
end

function BoardBoulder:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	self.image_flipper = self.image_flipper + DTMULT
	if self.image_flipper >= 8 then
		self.sprite.scale_x = self.sprite.scale_x * -1
		self.image_flipper = 0
	end
	super.preDraw(self)
end

function BoardBoulder:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

return BoardBoulder