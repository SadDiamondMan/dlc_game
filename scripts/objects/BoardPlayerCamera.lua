---@class BoardPlayerCamera : Sprite
---@overload fun(...) : BoardPlayerCamera
local BoardPlayerCamera, super = Class(Object)

function BoardPlayerCamera:init(x, y, camwidth, camheight)
    super.init(self, x, y)

	self.kris = nil
	self.init = 0
	self.con = 0
	self.camwidth = camwidth or 3
	self.camheight = camheight or 3
	self.layer = 100
	self.timer = 0
	self.camshot = false
	self.arrowtimer = 0
	self.arrowdraw = false
	self.party = {}
	self.rectprog = 0
	self._end = 0
	self.cameraframe = true
	self.photo = 0
	self.picturetaken = false
	self.makestars = false
	self.makestarstimer = 0
	self.makestarstimerloop = 0
	self.photoarray = {}
	self.uholdbuff = 0
	self.dholdbuff = 0
	self.lholdbuff = 0
	self.rholdbuff = 0
	self.createphoto = false
	self.addgreenblocks = false
	self.flagtoset = nil
	self.controllable = true
	self.remoted = false
	self.remoteu = false
	self.remotel = false
	self.remoter = false
	self.notalk = true
	self.timercon = 0
	self.pxwhite_tex = Assets.getTexture("bubbles/fill")
	self.frame_tex = Assets.getFrames("sword/ui/playercamera/playercamera")
	self.arrow_tex = Assets.getTexture("sword/ui/playercamera/arrow")
end

function BoardPlayerCamera:onAdd(parent)
	super.onAdd(self, parent)
	Assets.playSound("power", 1, 1.5)
end

function BoardPlayerCamera:isMovementEnabled()
    return not OVERLAY_OPEN
        and Game.state == "OVERWORLD"
        and Game.world.board.state == "GAMEPLAY"
        and Game.world.board.player.hurt_timer <= 1
        and Game.world.door_delay == 0
		and not Game.world.board:hasCutscene()
end

function BoardPlayerCamera:update()
	super.update(self)
	
	local board = Game.world.board
	if not board then
		return
	end
	if (board.swapping_grid or board.fader.state ~= "NONE" or board.fader.tilescovered > 0) then
		self:remove()
	end
	if self.init == 0 then
		self.kris = board.player
		Game.lock_movement = true
		self.init = 1
	end
	if self.kris then
		if self.kris.iframes > 0 then
			self._end = 99
		end
	end
	if self.con == 0 and self:isMovementEnabled() then
		if self.controllable then
			if Input.down("up") or self.remoteu then
				self.uholdbuff = self.uholdbuff + DTMULT
			else
				self.uholdbuff = 1
			end
			if Input.down("down") or self.remoted then
				self.dholdbuff = self.dholdbuff + DTMULT
			else
				self.dholdbuff = 1
			end
			if Input.down("left") or self.remotel then
				self.lholdbuff = self.lholdbuff + DTMULT
			else
				self.lholdbuff = 1
			end
			if Input.down("right") or self.remoter then
				self.rholdbuff = self.rholdbuff + DTMULT
			else
				self.rholdbuff = 1
			end
			if Input.down("up") and Input.down("down") then
				self.dholdbuff = 1
				self.uholdbuff = 1
			end
			if Input.down("left") and Input.down("right") then
				self.lholdbuff = 1
				self.rholdbuff = 1
			end
		else
			if self.remoteu then
				self.uholdbuff = self.uholdbuff + DTMULT
			else
				self.uholdbuff = 1
			end
			if self.remoted then
				self.dholdbuff = self.dholdbuff + DTMULT
			else
				self.dholdbuff = 1
			end
			if self.remotel then
				self.lholdbuff = self.lholdbuff + DTMULT
			else
				self.lholdbuff = 1
			end
			if self.remoter then
				self.rholdbuff = self.rholdbuff + DTMULT
			else
				self.rholdbuff = 1
			end
		end
		local buffmodrate = 2
		if self.dholdbuff >= buffmodrate then
			self.y = self.y + 16
			Assets.stopAndPlaySound("ui_move", 0.5, 1.1)
			self.dholdbuff = 0
		end
		if self.uholdbuff >= buffmodrate then
			self.y = self.y - 16
			Assets.stopAndPlaySound("ui_move", 0.5, 1.2)
			self.uholdbuff = 0
		end
		if self.lholdbuff >= buffmodrate then
			self.x = self.x - 16
			Assets.stopAndPlaySound("ui_move", 0.5, 1.1)
			self.lholdbuff = 0
		end
		if self.rholdbuff >= buffmodrate then
			self.x = self.x + 16
			Assets.stopAndPlaySound("ui_move", 0.5, 1.2)
			self.rholdbuff = 0
		end
		if self.controllable then
			if Input.pressed("cancel") then
				self._end = 99
			elseif Input.pressed("confirm") then
				self:cameraFlash()
			end
		end
	end
	if self.con == 1 then
		self.timer = self.timer + DTMULT
		if self.timer >= 1 and self.timercon == 0 then
			self.timercon = 1
			self.camshot = true
		end
		local shutterwait = 1
		local closetime = 4
		local opentime = 3
		local closepause = 3
		local photowaittime = 15
		if self.timer >= shutterwait and self.timercon == 1 then
			self.timercon = 2
			Game.world.timer:lerpVar(self, "rectprog", 0, 1, closetime)
		end
		if self.timer >= shutterwait + closetime and self.timercon == 2 then
			self.timercon = 3
			self:takePicture()
		end
		if self.timer >= shutterwait + closepause + closetime and self.timercon == 3 then
			self.timercon = 4
			Game.world.timer:lerpVar(self, "rectprog", 1, 0, opentime)
			Game.lock_movement = true
		end
		if self.createphoto then
			if self.timer >= 61 then
				local photox = self.x + ((self.camwidth / 2) * 32) - 16
				local photoy = self.y + ((self.camheight / 2) * 32) - 16
				self.photo = BoardSprite("sword/ui/inventory/photo", photox, photoy)
				self.photo:setScale(2)
				self.photo.layer = self.layer - 0.01
				Game.world.board:addChild(self.photo)
				local starcount = 16				
				for i = 0, starcount do
					local star = BoardSmallStar(photox, photoy)
					star.layer = self.photo.layer - 0.01
					star.physics.direction = math.rad((i / starcount) * 360)
					star.physics.speed = 20
					star.physics.friction = 0.1
					star.frame = MathUtils.randomInt(3)
					Game.world.timer:after(15/30, function()
						star:remove()
					end)
					Game.world.board:addChild(star)
				end
				self.timer = -15
				self.cameraframe = false
				self.timercon = 0
				self.con = self.con + 1
			end
		elseif self.timer >= 21 then
			self._end = true
		end
	end
	if self.con == 2 then
		self.timer = self.timer + DTMULT
		if self.timer >= 5 and self.timercon == 0 then
			self.timercon = 1
			self.kris:setSprite("item")
			Game.world.timer:lerpVar(self.photo, "x", self.photo.x, self.kris.x, 5, 2, "in")
			Game.world.timer:lerpVar(self.photo, "y", self.photo.y, self.kris.y - 32, 5, 2, "out")
		end
		if self.timer >= 20 and self.timercon == 1 then
			self.timercon = 2
			Assets.playSound("board/itemget")
			self.makestars = true
		end
		local photodescendtime = 6
		if self.timer >= 50 and self.timercon == 2 then
			self.timercon = 3
			self.photo.layer = self.kris.layer
			Game.world.timer:lerpVar(self.photo, "y", self.photo.y, self.photo.y + 30, photodescendtime, 2, "out")
			Game.world.timer:after(photodescendtime/30, function()
				self.photo:remove()
			end)
		end
		if self.timer >= 60 + photodescendtime - 10 then
			self._end = 1 
		end
	end
	if self._end ~= 0 then
		if self.kris then
			self.kris:resetSprite()
			Game.lock_movement = false
		end
		if self._end ~= 99 then
			-- reset susie and ralsei here
		end
		if self.flagtoset then
			Game:setFlag(self.flagtoset, true)
		end
		for _, obj in ipairs(self.photoarray) do
			if obj then
				obj.frozen = false
			end
		end
		self:remove()
	end
	if self.makestars and self.photo then
		local starlayer = self.layer - 0.01
		self.makestarstimer = self.makestarstimer + DTMULT
		self.makestarstimerloop = self.makestarstimerloop + DTMULT
		
		if self.makestarstimerloop >= 2 then
			local star = BoardSmallStar(self.photo.x, self.photo.y)
			star.layer = starlayer
			star.physics.direction = math.rad(self.makestarstimer * 20)
			star.physics.speed = 5
			star.physics.friction = 0.25
			star.frame = MathUtils.randomInt(3)
			Game.world.timer:after(MathUtils.random(13, 16)/30, function()
				star:remove()
			end)
			Game.world.board:addChild(star)
			
			local star2 = BoardSmallStar(self.photo.x, self.photo.y)
			star2.layer = starlayer
			star2.physics.direction = math.rad((self.makestarstimer * 20) + 180)
			star2.physics.speed = 5
			star2.physics.friction = 0.25
			star2.frame = MathUtils.randomInt(3)
			Game.world.timer:after(MathUtils.random(13, 16)/30, function()
				star2:remove()
			end)
			Game.world.board:addChild(star2)
			self.makestarstimerloop = 0
		end
		
		if self.makestarstimer >= 16 then
			self.makestars = false
		end
	end
	self.remoted = false
	self.remoteu = false
	self.remotel = false
	self.remoter = false
end

function BoardPlayerCamera:cameraFlash()
	self.timercon = 0
	self.con = self.con + 1
	self.picturetaken = true
	Assets.playSound("camera_flash")
end

function BoardPlayerCamera:takePicture()
	self.createphoto = false
	local photocollider = Hitbox(self, 4, 4, (self.camwidth * 32) - 8, (self.camheight * 32) - 8)
	for _,obj in ipairs(Game.world.board.children) do
        if obj and photocollider:collidesWith(obj) then
			if obj.photo_react then
				obj:onTakePicture()
				if obj.photo_freeze then
					table.insert(self.photoarray, photo)
				end
				self.flagtoset = obj.photoflag or nil
			end
        end
    end
	if not self.flagtoset then
		if Game.world.board.grayregion then
			Game.world.board.grayregion:remove()
			Game.world.board.grayregion = nil
		end
		Game.world.board.grayregion = BoardGrayRegion(self.x, self.y, self.camwidth * 32, self.camheight * 32)
		Game.world.board:addChild(Game.world.board.grayregion)
	end
end

function BoardPlayerCamera:preDraw()
	local xmin, ymin = Game.world.board:getAreaPosition()
	local xmax, ymax = xmin + ((12 - self.camwidth) * 32), ymin + ((8 - self.camheight) * 32)
	self.x = MathUtils.clamp(self.x, xmin, xmax)
	self.y = MathUtils.clamp(self.y, ymin, ymax)
	super.preDraw(self)
end

function BoardPlayerCamera:draw()
	super.draw(self)
	local amt = self.rectprog
	amt = MathUtils.clamp(amt, 0, 1)
	Draw.draw(self.pxwhite_tex, 0, 0, 0, self.camwidth * 32, MathUtils.round(((self.camheight / 2) * 32 * amt) / 2) * 2)
	Draw.draw(self.pxwhite_tex, 0, self.camheight * 32, 0, self.camwidth * 32, -MathUtils.round(((self.camheight / 2) * 32 * amt) / 2) * 2)
	Draw.draw(self.pxwhite_tex, self.camwidth * 32, 0, 0, -MathUtils.round(((self.camwidth / 2) * 32 * amt) / 2) * 2, self.camheight * 32)
	Draw.draw(self.pxwhite_tex, 0, 0, 0, MathUtils.round(((self.camwidth / 2) * 32 * amt) / 2) * 2, self.camheight * 32)
	if self.cameraframe then
		for i = 0, self.camwidth - 1 do
			Draw.draw(self.frame_tex[2], (i * 32), 0, 0, 2, 2)
			Draw.draw(self.frame_tex[7], (i * 32), ((self.camheight - 1) * 32), 0, 2, 2)
		end
		for i = 0, self.camheight - 1 do
			Draw.draw(self.frame_tex[4], 0, (i * 32), 0, 2, 2)
			Draw.draw(self.frame_tex[5], ((self.camwidth - 1) * 32), (i * 32), 0, 2, 2)
		end
		Draw.draw(self.frame_tex[1], 0, 0, 0, 2, 2)
		Draw.draw(self.frame_tex[3], (32 * (self.camwidth - 1)), 0, 0, 2, 2)
		Draw.draw(self.frame_tex[6], 0, (32 * (self.camheight - 1)), 0, 2, 2)
		Draw.draw(self.frame_tex[8], (32 * (self.camwidth - 1)), (32 * (self.camheight - 1)), 0, 2, 2)
	end
	if self.con == 0 then
		self.arrowtimer = self.arrowtimer + DTMULT
		if self.arrowtimer >= 15 then
			self.arrowdraw = not self.arrowdraw
			self.arrowtimer = 0
		end
		if self.arrowdraw then
			Draw.draw(self.arrow_tex, -4, MathUtils.round(((((self.camheight / 2) * 32)) - 8) / 2) * 2, math.rad(90), 2, 2)
			Draw.draw(self.arrow_tex, (self.camwidth * 32) + 4, MathUtils.round(((((self.camheight / 2) * 32)) + 8) / 2) * 2, math.rad(-90), 2, 2)
			Draw.draw(self.arrow_tex, MathUtils.round(((((self.camwidth / 2) * 32)) + 8) / 2) * 2, -4, math.rad(180), 2, 2)
			Draw.draw(self.arrow_tex, MathUtils.round(((((self.camwidth / 2) * 32)) - 8) / 2) * 2, MathUtils.round(((self.camheight * 32) + 4) / 2) * 2, 0, 2, 2)
		end
	end
	if self.camshot then
		self.camshot = false
		--TODO: vacationmemories.png screenshot recreation
	end
end

return BoardPlayerCamera