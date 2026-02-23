--- The character controlled by the player when in the Board.
---@class BoardPlayer : Character
---@overload fun(chara: string|Actor, x?: number, y?: number) : BoardPlayer
local BoardPlayer, super = Class(Character)

function BoardPlayer:init(chara, x, y)
    super.init(self, chara, x, y)

    self.world = Game.world.board
    self.is_player = true

    self.state_manager = StateManager("WALK", self, true)
    self.state_manager:addState("WALK", { update = self.updateWalk })
    self.state_manager:addState("HURT", { update = self.updateHurt })

    self.auto_moving = false

    self.hurt_timer = 0

    self.moving_x = 0
    self.moving_y = 0
    self.walk_speed = 4

    self.last_move_x = self.x
    self.last_move_y = self.y

    self.history_time = 0
    self.history = {}

    self.interact_buffer = 0

    self.battle_alpha = 0

    self.persistent = true
    self.noclip = false

    self.charas = {"kris", "susie", "ralsei", "lancer", "noelle", "hero", "jamm", "len"} 

    self.chara_state = "none"

    self.switch_char = true
    self.switch_buffer = 0

    --kris variables
    self.kris_has_sword = false
    self.sword_buffer = 0
    self.sword_facing = "down"

    --susie variables
    self.grab = 0
    self.grab_con = 0
    self.grab_buffer = 0
    self.grabbed = 0
    self.grab_marker = nil
    self.doagrab = false

    --ralsei variables
    self.go_stoole = false
    self.stool = nil
    self.stool_buffer = 0
    self.unstoole = false

    --lancer variables
    self.dig_freeze = 0
    self.dig_con = 0
    self.dig_time = 0

    self.boat = false

    self.sleepy = false
    self.sleeping = false
    self.sleepytimer = 0

    self.ribbon = false
    self.bow_x = self.x
    self.bow_y = self.y

    self.stink = false
    self.stink_timer = 0

    self.hookshot = true
    self.hook_buffer = 0
    self.hook = 0
    self.hook_con = 0
    self.force_hook = false
	
	self.hit_move = 0
	self.hit_move_speed = 0
	self.hit_x = 0
	self.hit_y = 0
	self.iframes = 0
	self.stopiframesflickerconds = 0
	self.iframes_visible = true

    self.k = {"left", "right", "up", "down"}

    self.frames = 0
    self.rec_left = {}
    self.rec_right = {}
    self.rec_up = {}
    self.rec_down = {}
    self.recording = {["left"] = self.rec_left, ["right"] = self.rec_right, ["up"] = self.rec_up, ["down"] = self.rec_down}
	
	self.boardgrid = true
	self.bcamera = true
	self.mycam = nil
	self.cant_photo_icon = nil
	self.cant_photo_timer_1 = nil
	self.cant_photo_timer_2 = nil
	self.true_x = self.x
	self.true_y = self.y
	self.cambuff = 0
end

function BoardPlayer:saveMovement()
    love.filesystem.write("rec.json", JSON.encode(self.recording))
end

function BoardPlayer:handleRecord()
    self.frames = self.frames + 1

    for _, k in ipairs(self.k) do
        local hf = "l_" .. k
        local rt = self["rec_" .. k]


        if Input.down(k) then
            if not self[hf] then
                rt[tostring(self.frames)] = 1
                self[hf] = true
            end

        elseif self[hf] then
            self[hf] = nil
            rt[tostring(self.frames)] = 0
        end
    end
end

function BoardPlayer:handleMovement()
    local walk_x = 0
    local walk_y = 0

    if     Input.down("left")  then walk_x = walk_x - 1
    elseif Input.down("right") then walk_x = walk_x + 1 end
    if     Input.down("up")    then walk_y = walk_y - 1
    elseif Input.down("down")  then walk_y = walk_y + 1 end

    if Input.down("f7") then
        self:handleRecord()
    end

    self.moving_x = walk_x
    self.moving_y = walk_y

    local speed = self:getCurrentSpeed()

    self:move(walk_x, walk_y, speed * DTMULT)
end

function BoardPlayer:updateWalk()
    if self:isMovementEnabled() then
        self:handleMovement()
    end
end

function BoardPlayer:getBaseWalkSpeed()
    return 4
end

function BoardPlayer:getCurrentSpeed()
    local speed = self:getBaseWalkSpeed()
    return speed
end

function BoardPlayer:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "State: " .. self.state_manager.state)
    table.insert(info, "Walk speed: " .. self:getBaseWalkSpeed())
    table.insert(info, "Current walk speed: " .. self:getCurrentSpeed())
    table.insert(info, "Hurt timer: " .. self.hurt_timer)
    return info
end

function BoardPlayer:onAdd(parent)
    super.onAdd(self, parent)

    if parent:includes(World) and not parent.player then
        parent.player = self
    end
end

function BoardPlayer:onRemove(parent)
    super.onRemove(self, parent)

    if parent:includes(World) and parent.player == self then
        parent.player = nil
    end
end

function BoardPlayer:onRemoveFromStage(stage)
    super.onRemoveFromStage(self, stage)
end

function BoardPlayer:setActor(actor)
    super.setActor(self, actor)

    local hx, hy, hw, hh = self.collider.x, self.collider.y, self.collider.width, self.collider.height

    self.interact_collider = {
        ["left"] = Hitbox(self, hx - 13, hy, hw / 2 + 13, hh),
        ["right"] = Hitbox(self, hx + hw / 2, hy, hw / 2 + 13, hh),
        ["up"] = Hitbox(self, hx, hy - 19, hw, hh / 2 + 19),
        ["down"] = Hitbox(self, hx, hy + hh / 2, hw, hh / 2 + 14)
    }
end

function BoardPlayer:interact()
    if self.interact_buffer > 0 then
        return true
    end

    local col = self.interact_collider[self.facing]

    local interactables = {}
    for _, obj in ipairs(self.world.children) do
        if obj.onInteract and obj:collidesWith(col) then
            local rx, ry = obj:getRelativePos(obj.width / 2, obj.height / 2, self.parent)
            table.insert(interactables, { obj = obj, dist = Utils.dist(self.x, self.y, rx, ry) })
        end
    end
    table.sort(interactables, function (a, b) return a.dist < b.dist end)
    for _, v in ipairs(interactables) do
        if v.obj:onInteract(self, self.facing) then
            self.interact_buffer = v.obj.interact_buffer or 0
            return true
        end
    end

    return false
end

function BoardPlayer:setState(state, ...)
    self.state_manager:setState(state, ...)
end

function BoardPlayer:resetFollowerHistory()
    for _, follower in ipairs(Game.world.board.followers) do
        if follower:getTarget() == self then
            follower:copyHistoryFrom(self)
        end
    end
end

--- Aligns the player's followers' directions and positions.
---@param facing?   string  The direction every character should face (Defaults to player's direction)
---@param x?        number  The x-coordinate of the 'front' of the line. (Defaults to player's x-position)
---@param y?        number  The y-coordinate of the 'front' of the line. (Defaults to player's y-position)
---@param dist?     number  The distance between each follower.
function BoardPlayer:alignFollowers(facing, x, y, dist)
    facing = facing or self.facing
    x, y = x or self.x, y or self.y

    local offset_x, offset_y = 0, 0
    if facing == "left" then
        offset_x = 1
    elseif facing == "right" then
        offset_x = -1
    elseif facing == "up" then
        offset_y = 1
    elseif facing == "down" then
        offset_y = -1
    end

    self.history = { { x = x, y = y, time = self.history_time } }
    for i = 1, Game.max_followers do
        local idist = dist and (i * dist) or (((i * FOLLOW_DELAY) / (1 / 30)) * 4)
        table.insert(self.history,
            { x = x + (offset_x * idist), y = y + (offset_y * idist), facing = facing,
                time = self.history_time - (i * FOLLOW_DELAY) })
    end
    self:resetFollowerHistory()
end

--- Adds all followers' current positions to their movement history.
function BoardPlayer:interpolateFollowers()
    for i, follower in ipairs(Game.world.board.followers) do
        if follower:getTarget() == self then
            follower:interpolateHistory()
        end
    end
end

function BoardPlayer:isCameraAttachable()
    return
end

function BoardPlayer:isMovementEnabled()
    return not OVERLAY_OPEN
        and not Game.lock_movement
        and Game.state == "OVERWORLD"
        and self.world.state == "GAMEPLAY"
        and self.hurt_timer <= 1
        and Game.world.door_delay == 0
		and not self.world.rafting
end

function BoardPlayer:isHurtingEnabled()
	return self:isMovementEnabled()
end

function BoardPlayer:hurt(amount, hazard)
	if self.iframes <= 0 and self.actor.health > 0 and self:isHurtingEnabled() then
		Assets.playSound("board/playerhurt")
		self.iframes = 20
		self.actor.health = self.actor.health - amount
		self.iframes_visible = false
		self.hurt_timer = 5
		for _,healthbar in ipairs(self.world.ui.healthbars) do
			if healthbar.party.id == self.actor.id then
				healthbar:shake()
				healthbar.override_color = COLORS.red
				Game.world.timer:after(2/30, function()
					healthbar.override_color = nil
				end)
			end
		end		
		if hazard then
			self.hit_move = 32
			self.hit_move_speed = 16
			self.hit_x = 0
			self.hit_y = 0
			local dir = -math.deg(MathUtils.angle(self.x, self.y, hazard.last_x + hazard.width/2, hazard.last_y + hazard.height/2)) % 360
			local check_collisions = false
			if (not self.noclip) and (not NOCLIP) then
				check_collisions = true
			end
			if check_collisions then
				Object.startCache()
				if dir >= 135 and dir < 225 then
					local collider_check_x = Hitbox(self, self.collider.x + 16, self.collider.y, self.collider.width, self.collider.height)
					local collider_check_y = Hitbox(self, self.collider.x, self.collider.y - 16, self.collider.width, self.collider.height)
					local collider_check_z = Hitbox(self, self.collider.x, self.collider.y + 16, self.collider.width, self.collider.height)
					local collided_x, _ = self.world:checkCollision(collider_check_x, false)
					local collided_y, _ = self.world:checkCollision(collider_check_y, false)
					local collided_z, _ = self.world:checkCollision(collider_check_z, false)
					if not collided_x then
						self.hit_x = self.hit_x + self.hit_move_speed
					elseif hazard.y > self.y and not collided_y then
						self.hit_y = self.hit_y - self.hit_move_speed
					elseif not collided_z then
						self.hit_y = self.hit_y + self.hit_move_speed
					end
				end
				if dir >= 315 or dir < 45 then
					local collider_check_x = Hitbox(self, self.collider.x - 16, self.collider.y, self.collider.width, self.collider.height)
					local collider_check_y = Hitbox(self, self.collider.x, self.collider.y - 16, self.collider.width, self.collider.height)
					local collider_check_z = Hitbox(self, self.collider.x, self.collider.y + 16, self.collider.width, self.collider.height)
					local collided_x, _ = self.world:checkCollision(collider_check_x, false)
					local collided_y, _ = self.world:checkCollision(collider_check_y, false)
					local collided_z, _ = self.world:checkCollision(collider_check_z, false)
					if not collided_x then
						self.hit_x = self.hit_x - self.hit_move_speed
					elseif hazard.y > self.y and not collided_y then
						self.hit_y = self.hit_y - self.hit_move_speed
					elseif not collided_z then
						self.hit_y = self.hit_y + self.hit_move_speed
					end
				end
				if dir >= 45 and dir < 135 then
					local collider_check_x = Hitbox(self, self.collider.x, self.collider.y + 16, self.collider.width, self.collider.height)
					local collider_check_y = Hitbox(self, self.collider.x - 16, self.collider.y, self.collider.width, self.collider.height)
					local collider_check_z = Hitbox(self, self.collider.x + 16, self.collider.y, self.collider.width, self.collider.height)
					local collided_x, _ = self.world:checkCollision(collider_check_x, false)
					local collided_y, _ = self.world:checkCollision(collider_check_y, false)
					local collided_z, _ = self.world:checkCollision(collider_check_z, false)
					if not collided_x then
						self.hit_y = self.hit_y + self.hit_move_speed
					elseif hazard.x < self.x and not collided_y then
						self.hit_x = self.hit_x - self.hit_move_speed
					elseif not collided_z then
						self.hit_x = self.hit_x + self.hit_move_speed
					end
				end
				if dir >= 225 and dir < 315 then
					local collider_check_x = Hitbox(self, self.collider.x, self.collider.y - 16, self.collider.width, self.collider.height)
					local collider_check_y = Hitbox(self, self.collider.x - 16, self.collider.y, self.collider.width, self.collider.height)
					local collider_check_z = Hitbox(self, self.collider.x + 16, self.collider.y, self.collider.width, self.collider.height)
					local collided_x, _ = self.world:checkCollision(collider_check_x, false)
					local collided_y, _ = self.world:checkCollision(collider_check_y, false)
					local collided_z, _ = self.world:checkCollision(collider_check_z, false)
					if not collided_x then
						self.hit_y = self.hit_y - self.hit_move_speed
					elseif hazard.x < self.x and not collided_y then
						self.hit_x = self.hit_x - self.hit_move_speed
					elseif not collided_z then
						self.hit_x = self.hit_x + self.hit_move_speed
					end
				end
				Object.endCache()
			end
		end
		self:setState("HURT")
	end
end

function BoardPlayer:updateHurt()
	if self.hit_move > 0 then
		self.hit_move = self.hit_move - self.hit_move_speed * DTMULT
		self:move(self.hit_x, self.hit_y, DTMULT, true)
	else
		self.iframes_visible = true
		if self.actor.health <= 0 then
			self.actor.health = 0
			if self.is_player then
				self.actor.health = 1 -- placeholder
				self:setState("WALK")
			else
				self:setState("DEATH")
			end
		else
			self:setState("WALK")
		end
	end
end

function BoardPlayer:isMoving()
    return self.moving_x ~= 0 or self.moving_y ~= 0
end

-- Creates a smoke puff effect.
---@param x?        number  The x-coordinate of the effect. (Defaults to player's x-position)
---@param y?        number  The y-coordinate of the effect. (Defaults to player's y-position)
---@param color?    table   The color of the effect.
function BoardPlayer:createPuff(x, y, color)
    local color = color or {}

    local puff = BoardSmokePuff(x or self.moving_x, y or self.moving_y)
    puff:setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    puff:setOriginExact(8, 8)
    puff:setLayer(self.layer + 0.1)
    self:addChild(puff)
end

-- changes the current player character
function BoardPlayer:switchCharacter()
    self:createPuff(nil, nil, {201/255, 201/255, 201/255})

    local id = self.actor.id:gsub("board_", "")
    for i, name in ipairs(self.charas) do
        if name == id then
            local next_index = (i % #self.charas) + 1
            self:setActor("board_" .. self.charas[next_index])

            Assets.playSound("voice/board", 1, 1.1 + (next_index / 10))
            Assets.playSound("voice/board", 1, 0.2 + (next_index / 10))
            Assets.playSound("board/splash", 0.4, 0.8)

            break
        end
    end

    local b = self.world.ui.healthbars[1]
    b:init(b.x, b.y, self.actor)
end

-- abilities for the characters
function BoardPlayer:characterAction()
    local id = self.actor.id:gsub("board_", "")
    local name = id..""..id

    if name == id.."kris" then    -- nothing (unless you've obtained the sword or camera)
		self.bcamera = false
		if Game.world.board.ui.inventory_bar and Game.world.board.ui.inventory_bar.inventory["camera"] then
			self.bcamera = true
		end
		local camwidth = 4
		local camheight = 3
		local can_photo = true
		local make_sign = true
		if self.world:checkCameraBlockerCollision(self.collider) then
			can_photo = false
		end
		for _,camsolid in ipairs(self.stage:getObjects(BoardCamSolid)) do
            if camsolid.camblock_collider and self:collidesWith(camsolid.camblock_collider) then
                can_photo = false
			end
		end
		if self.bcamera and not Game.world.board:hasCutscene() and (not self.mycam or self.mycam:isRemoved()) and self.cambuff <= 0 then
			if can_photo then
				local playxround = MathUtils.round((self.x - 16) / 32) * 32
				local playyround = MathUtils.round((self.y - 32) / 32) * 32
				playxround = playxround - (camwidth / 2) * 32
				playyround = playyround - (camheight / 2) * 32
				playxround = MathUtils.round(playxround / 32) * 32
				playyround = MathUtils.round(playyround / 32) * 32
				self.mycam = BoardPlayerCamera(playxround, playyround, camwidth, camheight)
				self.parent:addChild(self.mycam)
			elseif make_sign then 
				if self.cant_photo_icon then self.cant_photo_icon:remove() end
				if self.cant_photo_timer_1 then
					Game.world.timer:cancel(self.cant_photo_timer_1)
					self.cant_photo_timer_1 = nil
				end
				if self.cant_photo_timer_2 then
					Game.world.timer:cancel(self.cant_photo_timer_2)
					self.cant_photo_timer_2 = nil
				end
				self.cant_photo_icon = BoardSprite("sword/effects/nophoto", self.x, self.y - 24)
				self.cant_photo_icon:setScale(2)
				self.cant_photo_icon:play(1/5)
				self.cant_photo_icon:setFrame(2)
				self.cant_photo_icon:setOrigin(0.5, 1)
				self.cant_photo_icon.physics.speed_y = -2.8
				self.cant_photo_icon.physics.gravity = 0.2
				self.cant_photo_icon.layer = 100
				if self.cant_photo_icon.y <= 64 then
					self.cant_photo_icon.y = 64
				end
				self.parent:addChild(self.cant_photo_icon)
				self.cant_photo_timer_1 = Game.world.timer:after(15/30, function()
					self.cant_photo_icon.physics.gravity = 0
					self.cant_photo_icon.physics.speed_y = 0
				end)
				self.cant_photo_timer_2 = Game.world.timer:after(20/30, function()
					self.cant_photo_icon:remove()
				end)
				Assets.stopAndPlaySound("error")
			end
		end
        return
    end
    if name == id.."susie" then   -- grab and throw
        return
    end
    if name == id.."ralsei" then  -- stool forme
        local can_stoole = true
        local stoolevolume = 0.6
		
        if self.chara_state == "none" and (self.stool_buffer <= 0 or self.go_stoole) then
            if can_stoole then
                self.go_stoole = false
				
                self.stool_x, self.stool_y = Mod:boardTile(self.x, self.y)
                self.x, self.y = self.stool_x, self.stool_y

                --creates a "pushblock_board" event
                self.stool = Game.world.board:spawnObject(Registry.createLegacyEvent("pushblock_board", {
                    x = self.stool_x, 
                    y =  self.stool_y, 
                    properties = { 
					    sprite = "sword/party/ralsei/stoolforme",
					    pushsound = "voice/ralsei"
                    }
                }))
                self.stool:setLayer(self.layer - 0.1)

                self:createPuff(nil, nil, {19/255, 210/255, 111/255})
                self.chara_state = "stoolforme"
                Assets.playSound("board/ralsei_cube", stoolevolume, 1)
                --Game.lock_movement = true
                self.alpha = 0
                self.stool_buffer = 3
            end
        end

        if self.chara_state == "stoolforme" and (self.stool_buffer <= 0 or self.unstoole) then
            self.unstoole = false

            Assets.playSound("board/ralsei_cube", stoolevolume, 0.7)
            --Kristal.Console:log("unstooled")
            self.stool:remove()
            self:createPuff(nil, nil, {19/255, 210/255, 111/255})
            --Game.lock_movement = false
            self.chara_state = "none"
            self.alpha = 1
            self.stool_buffer = 3
        end
    end
    if name == id.."lancer" then  -- digging
        return
    end
    if name == id.."elnina" then  -- crying
        return
    end
    if name == id.."noelle" then  -- ice magic
        return
    end
    if name == id.."jamm" then    -- hookshot
        return
    end
end

function BoardPlayer:updateHistory()
    if #self.history == 0 then
        table.insert(self.history, { x = self.x, y = self.y, time = 0 })
    end

    local moved = self.x ~= self.last_move_x or self.y ~= self.last_move_y

    local auto = self.auto_moving

    if moved then
        self.history_time = self.history_time + DT

        table.insert(self.history, 1,
            { x = self.x, y = self.y, facing = self.facing, time = self.history_time, state = self.state_manager.state,
                state_args = self.state_manager.args, auto = auto })
        while (self.history_time - self.history[#self.history].time) > (Game.max_followers * FOLLOW_DELAY) do
            table.remove(self.history, #self.history)
        end
    end

    -- Need this for ralsei
    for _, follower in ipairs(Game.world.board.followers) do
        follower:updateHistory(moved, auto)
    end

    self.last_move_x = self.x
    self.last_move_y = self.y
end

function BoardPlayer:update()
    if self.hurt_timer > 0 then
        self.hurt_timer = MathUtils.approach(self.hurt_timer, 0, DTMULT)
    end 

	if self.cambuff > 0 then
        self.cambuff = self.cambuff - DTMULT
    end

    if self.iframes > -5 then
        self.iframes = MathUtils.approach(self.iframes, -5, DTMULT)
    end	

	if self.iframes > 0 then
		if self.stopiframesflickerconds == 0 then
			if MathUtils.round(self.iframes) % 2 == 0 then
				if self.iframes_visible then
					self.iframes_visible = false
				else
					self.iframes_visible = true
				end
				if FRAMERATE > 30 or (FRAMERATE == 0 and FPS > 30) then
					self.stopiframesflickerconds = self.iframes
				end
			end
		end
		if self.stopiframesflickerconds ~= 0 and self.iframes <= self.stopiframesflickerconds-0.4 then
			self.stopiframesflickerconds = 0
		end
	else
		self.iframes_visible = true
		self.stopiframesflickerconds = 0
	end

    self.state_manager:update()

    self:updateHistory()

    if not Game.world.cutscene and not Game.world.menu then
        self.interact_buffer = MathUtils.approach(self.interact_buffer, 0, DT)
    end

    local id = self.actor.id:gsub("board_", "")
    local name = id..""..id

    if name == id.."ralsei" then
        if self.stool_buffer > 0 then
            self.stool_buffer = MathUtils.approach(self.stool_buffer, 0, DTMULT)
        end
    end

    super.update(self)
end

function BoardPlayer:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	if self.boardgrid then
		self.x = MathUtils.round(self.x / 2) * 2
		self.y = MathUtils.round(self.y / 2) * 2
	end
	super.preDraw(self)
end

function BoardPlayer:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

function BoardPlayer:draw()
    -- Draw the player
	if self.iframes_visible then
		super.draw(self)
	end

    local col = self.interact_collider[self.facing]
    if DEBUG_RENDER then
        col:draw(1, 0, 0, 0.5)
    end
end

return BoardPlayer
