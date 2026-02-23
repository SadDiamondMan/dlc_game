---@overload fun(...) : RaftBoard
local RaftBoard, super = Class(Event, "raft_board")

function RaftBoard:init(data)
    super.init(self, data)

    local properties = data and data.properties or {}

    self:setSprite("world/events/sword/raft")
	self:setOrigin(0.5, 1)
	self:setPosition(self.x + self.width/2, self.y + self.height)
	self.solid = true
	self.engaged = false
	self.floatsiner = 0
	self.moving_x = 0
	self.moving_y = 0
	self.facing = "down"
    self.last_collided_x = false
    self.last_collided_y = false
    self.moved = 0
    self.noclip = false
    self.enemy_collision = false
	self.true_x = self.x
	self.true_y = self.y
end

function RaftBoard:onInteract(player, dir)
	if self.engaged then return end
    local p = Game.world.board.player
    local cutscene = Game.world:startCutscene(function(c)
		Game.world.board.rafting = true
		self.facing = "down"
		local jumptime = 10
		c:wait(1/30)
		Game:setFlag("raft_last_music", Game.world.music.current)
		Game:setFlag("raft_last_music_time", Game.world.music:tell())
		Game.world.music:fade(0, jumptime/30)
		Game.world.timer:after(jumptime/30, function()
			Game.world.music:play("ch3_board2")
			Game.world.music:setVolume(1)
		end)
		local amt = MathUtils.round(MathUtils.dist(p.x, p.y, self.x, self.y) / 6)
		local jumpheight = MathUtils.clamp(amt, 10, 32)
		p:jumpTo(self.x, self.y, jumpheight, jumptime/30)
		Game.world.timer:after(jumptime/30, function()
			Assets.playSound("board/lift")
		end)
		for i,f in ipairs(Game.world.board.followers) do
			Game.world.timer:after((5*i)/30, function()
				local amt = MathUtils.round(MathUtils.dist(f.x, f.y, self.x, self.y) / 6)
				local jumpheight = MathUtils.clamp(amt, 10, 32)
				f:setFacing(p:getFacing())
				f:jumpTo(self.x, self.y, jumpheight, jumptime/30)
				Game.world.timer:after(jumptime/30, function()
					Assets.playSound("board/lift", 1, (1+(0.2*i)))
				end)
			end)
		end
		c:wait((11+jumptime)/30)
		Game.world.board:setCameraTarget(self)
		self.engaged = true
    end)

    return true
end

function RaftBoard:isMovementEnabled()
    return not OVERLAY_OPEN
        and not Game.lock_movement
        and Game.state == "OVERWORLD"
        and self.world.state == "GAMEPLAY"
        and Game.world.board.player.hurt_timer <= 1
        and Game.world.door_delay == 0
		and self.world.rafting
end

function RaftBoard:update()
    super.update(self)
	self.floatsiner = self.floatsiner + DTMULT
	local yy = math.abs(math.sin(self.floatsiner / 15) * 2)
	self.sprite.y = MathUtils.round(yy/2)*2
    if self.engaged then
		if self:isMovementEnabled() then
			self:handleMovement()
		end
		local p = Game.world.board.player
		p:setPosition(self.x, self.y)
		for _,f in ipairs(Game.world.board.followers) do
			f:setPosition(self.x, self.y)
		end
    end
end

function RaftBoard:handleMovement()
    local walk_x = 0
    local walk_y = 0

    if     Input.down("left")  then walk_x = walk_x - 1
    elseif Input.down("right") then walk_x = walk_x + 1 end
    if     Input.down("up")    then walk_y = walk_y - 1
    elseif Input.down("down")  then walk_y = walk_y + 1 end

    self.moving_x = walk_x
    self.moving_y = walk_y

    local speed = 4

    self:move(walk_x, walk_y, speed * DTMULT)
end

function RaftBoard:getFacing()
    return self.facing
end

function RaftBoard:setFacing(dir)
    self.facing = dir
	local p = Game.world.board.player
	p:setFacing(dir)
	for _,f in ipairs(Game.world.board.followers) do
		f:setFacing(dir)
	end
end

function RaftBoard:move(x, y, speed, keep_facing)
    local movex, movey = x * (speed or 1), y * (speed or 1)

    local moved = false
    moved = self:moveX(movex, movey) or moved
    moved = self:moveY(movey, movex) or moved

    if moved then
        self.moved = math.max(self.moved, math.max(math.abs(movex) / DTMULT, math.abs(movey) / DTMULT))
    end

    if not keep_facing and (movex ~= 0 or movey ~= 0) then
        local dir = self:getFacing()
        if movex > 0 then
            dir = "right"
        elseif movex < 0 then
            dir = "left"
        elseif movey > 0 then
            dir = "down"
        elseif movey < 0 then
            dir = "up"
        end

        self:setFacing(dir)
    end

    return moved
end

function RaftBoard:moveX(amount, move_y)
    return self:doMoveAmount("x", amount, move_y)
end
function RaftBoard:moveY(amount, move_x)
    return self:doMoveAmount("y", amount, move_x)
end

function RaftBoard:doMoveAmount(type, amount, other_amount)
    other_amount = other_amount or 0

    if amount == 0 then
        self["last_collided_" .. type] = false
        return false, false
    end

    local other = type == "x" and "y" or "x"

    local sign = MathUtils.sign(amount)
    for i = 1, math.ceil(math.abs(amount)) do
        local moved = sign
        if (i > math.abs(amount)) then
            moved = (math.abs(amount) % 1) * sign
        end

        local last_a = self[type]
        local last_b = self[other]

        self[type] = self[type] + moved

        if (not self.noclip) and (not NOCLIP) then
            Object.startCache()
            local collided, target = self.world:checkCollision(self.collider, self.enemy_collision)
            if collided and not (other_amount > 0) then
                for j = 1, 2 do
                    Object.uncache(self)
                    self[other] = self[other] - j
                    collided, target = self.world:checkCollision(self.collider, self.enemy_collision)
                    if not collided then break end
                end
            end
            if collided and not (other_amount < 0) then
                self[other] = last_b
                for j = 1, 2 do
                    Object.uncache(self)
                    self[other] = self[other] + j
                    collided, target = self.world:checkCollision(self.collider, self.enemy_collision)
                    if not collided then break end
                end
            end
            Object.endCache()

            if collided then
                self[type] = last_a
                self[other] = last_b

                if target and target.onCollide then
                    target:onCollide(self)
                end

                self["last_collided_" .. type] = true
                return i > 1, target
            end
        end
    end
    self["last_collided_" .. type] = false
    return true, false
end

function RaftBoard:isCameraAttachable()
    return
end

function RaftBoard:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function RaftBoard:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

return RaftBoard