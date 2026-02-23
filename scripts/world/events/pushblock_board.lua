--- A Pushable Block! Collision for Pushblocks can be created by adding a `blockcollision` layer to a map. \
--- `PushBlockBoard` is an [`Event`](lua://Event.init) - naming an object `pushblock` on an `objects` layer in a map creates this object. \
--- See this object's Fields for the configurable properties on this object.
--- 
---@class PushBlockBoard : Event
---
---@field default_sprite    string      *[Property `sprite`]* An optional custom sprite the block should use
---@field solved_sprite     string      *[Property `solvedsprite`]* An optional custom solve sprite the block uses
---
---@field solid             boolean     
---
---@field push_dist         number      *[Property `pushdist`]* The number of pixels the block moves per push (Defaults to `32`, one tile)
---@field push_timer        number      *[Property `pushtime`]* The time the block takes to complete a push, in seconds (Defaults to `0.2`)
---
---@field push_sound        string      *[Property `pushsound`]* The name of the sound file to play when the block is pushed (Defaults to `pushsound`)
---@field collide_sound     string      *[Property `collisionsound`]* The name of the sound file to play when the block cannot be pushed (Defaults to `collisionsound`)
---
---@field press_buttons     boolean     *[Property `pressbuttons`]* Unused (Defaults to `true`)
---
---@field lock_in_place     boolean     *[Property `lock`]* Whether the block gets locked in place when in a solved state (Defaults to `false`)
---
---@field input_lock        boolean     *[Property `inputlock`]* Whether the player's input's are locked while the block is being pushed
---
---@field start_x           number      Initial position of the block
---@field start_y           number      Initial position of the block
---
---@field state             string      The current state of the Pushblock - value can be IDLE, PUSH, RESET, or LIFT
---
---@field solved            boolean     Whether the pushblock is in a solved state
---
---@overload fun(...) : PushBlockBoard
local PushBlockBoard, super = Class(Event, "pushblock_board")

function PushBlockBoard:init(data, x, y, shape, sprite, solved_sprite)
    super.init(self, data, x, y, shape)

    local properties = data.properties or {}

    self.default_sprite = properties["sprite"] or sprite or "world/events/sword/pushableblock"
    self.solved_sprite = properties["solvedsprite"] or properties["sprite"] or solved_sprite or sprite or "world/events/sword/pushableblock"

    self:setSprite(self.default_sprite)
    self.solid = true

    -- Options
    self.push_dist = properties["pushdist"] or 32
    self.push_time = properties["pushtime"] or 0.2

    self.push_sound = properties["pushsound"] or "wing"
    self.collision_sound = properties["collisionsound"] or "impact"
    self.lift_sound = properties["liftsound"] or "board/lift"

    self.press_buttons = properties["pressbuttons"] ~= false

    self.lock_in_place = properties["lock"] or false
    self.input_lock = properties["inputlock"]

    -- State variables
    self.start_x = self.x
    self.start_y = self.y

    -- IDLE, PUSH, RESET, LIFT
    self.state = "IDLE"

    self.solved = false
	
    self.throw_reticle = Sprite("world/events/sword/throw_reticle")
    self.throw_reticle:setScale(2)
    
    local sprite_b = properties["sprite"] or sprite or "world/events/sword/pushableblock"
    self.carry = Sprite(sprite_b)
    self.carry.y = -12
	self.true_x = self.x
	self.true_y = self.y
end


function PushBlockBoard:checkCol(x, y)
    local collided = false

    local bound_check = Hitbox(self.world, x + 0.5, y + 0.5, 31, 31)

    Object.startCache()
    for _,collider in ipairs(Game.world.map.block_collision) do
        if collider:collidesWith(bound_check) then
            collided = true
            break
        end
    end
    if Game.world.board.player:collidesWith(bound_check) then
        collided = true
    end
    if not collided then
        self.collidable = false
        collided = self.world:checkCollision(bound_check)
        self.collidable = true
    end
    Object.endCache()

    return collided
end

function PushBlockBoard:update()
    super.update(self)

    if self.wait_a_frame_plz then self.wait_a_frame_plz = nil end

    if self.state == "LIFT" then

        self:canThrow()

        if self.throw_reticle.visible and Input.pressed("confirm") then
            local p = Game.world.board.player
            local rec = self.throw_reticle

            p.actor.default = "walk"
            p:resetSprite()

            self.x, self.y = rec.x, rec.y
            Game.world.board:removeChild(self.throw_reticle)
            p:removeChild(self.carry)
            self:playPushSound()
            self.solid = true
            self.visible = true
            self.state = "IDLE"
            p.carry = nil

            --1 frame pickup cooldown so susie doesnt pick it up the same frame she drops it
            -- i'm sorry to anyone who is reading this code
            self.wait_a_frame_plz = 0 
        end
    end
end

function PushBlockBoard:onInteract(chara, facing)
    if not self.solid or self.wait_a_frame_plz then return false end
    if chara.actor.id == "board_susie" then

        self:playLiftSound()
        chara.actor.default = "walk_armsup"
        chara:resetSprite()
        chara.carry = true

        chara:addChild(self.carry)

        Game.world.board:addChild(self.throw_reticle)
        self.throw_reticle.layer = chara.layer

        self.solid = false
        self.visible = false
        self.state = "LIFT"

        return true
    elseif chara.actor.id ~= "board_kris" then
        return true
    end

    if self.state ~= "IDLE" then return true end

    if not self:checkCollision(facing) then
        self:onPush(facing)
        self:playPushSound()
    else
        self:onPushFail(facing)
        self:playCollisionSound()
    end

    return true
end

function PushBlockBoard:playPushSound()
    if self.push_sound and self.push_sound ~= "" then
        for i = 0, 3-1 do
            Game.world.timer:after((1 + (2 * i))/30, function()
                Assets.playSound(self.push_sound, 1, 1.5 + (i / 20))
            end)
        end
    end
end

function PushBlockBoard:playCollisionSound()
    if self.collision_sound and self.collision_sound ~= "" then
        Assets.playSound(self.collision_sound, nil, 1.2)
    end
end

function PushBlockBoard:playLiftSound()
    if self.lift_sound and self.lift_sound ~= "" then
        Assets.stopAndPlaySound(self.lift_sound)
    end
end

function PushBlockBoard:checkCollision(facing)
    local collided = false

    local dx, dy = Utils.getFacingVector(facing)
    local target_x, target_y = self.x + dx * self.push_dist, self.y + dy * self.push_dist

    local x1, y1 = math.min(self.x, target_x), math.min(self.y, target_y)
    local x2, y2 = math.max(self.x + self.width, target_x + self.width), math.max(self.y + self.height, target_y + self.height)

    local bound_check = Hitbox(Game.world.board, x1 + 1, y1 + 1, x2 - x1 - 2, y2 - y1 - 2)

    Object.startCache()
    for _,collider in ipairs(Game.world.board.map.block_collision) do
        if collider:collidesWith(bound_check) then
            collided = true
            break
        end
    end
    if not collided then
        self.collidable = false
        collided = Game.world.board:checkCollision(bound_check)
        self.collidable = true
    end
    Object.endCache()

    return collided
end

function PushBlockBoard:onPush(facing)
    if self.solved then
        if self.lock_in_place then
            return
        end

        self.solved = false
        self:onUnsolved()
    end

    local input_lock = Game:getConfig("pushBlockInputLock")
    if self.input_lock ~= nil then
        input_lock = self.input_lock
    end

    if input_lock then
        Game.lock_movement = true
    end

    self.state = "PUSH"
    local dx, dy = Utils.getFacingVector(facing)
    self:slideTo(self.x + dx * self.push_dist, self.y + dy * self.push_dist, self.push_time, "linear", function()
        self.state = "IDLE"
        self:onPushEnd(facing)

        if input_lock and not Game.world.cutscene then
            Game.lock_movement = false
        end
    end)
end

--- *(Override)* Called when the block enters a solved state
function PushBlockBoard:onSolved()
    self:setSprite(self.solved_sprite)
end

--- *(Override)* Called when the block stops being in a solved state
function PushBlockBoard:onUnsolved()
    self:setSprite(self.default_sprite)
end

--- *(Override)* Called when a block finishes being pushed
function PushBlockBoard:onPushEnd(facing) end
--- *(Override)* Called when a block cannot be pushed because of collision
function PushBlockBoard:onPushFail(facing) end

--- Fades the block out and returns it to its original position
function PushBlockBoard:reset()
    if self.solved then
        self.solved = false
        self:onUnsolved()
    end

    self.state = "RESET"
    self.collidable = false
    self.sprite:fadeToSpeed(0, 0.2, function()
        self.x = self.start_x
        self.y = self.start_y
        self:onReset()
        self.sprite:fadeToSpeed(1, 0.2, function()
            self.collidable = true
            self.state = "IDLE"
        end)
    end)
end


function PushBlockBoard:canThrow()
    local p = Game.world.board.player
    local a, b = Mod:getPf()
    local c, r = Mod:boardTile(p.x + a, p.y + b)
    self.throw_reticle.visible = true

    -- if block placement is invalid we push it back a few
    -- if its still invalid we give up

    if self:checkCol(c, r) then
        a, b = Mod:getPf(32)
        c, r = c - a, r - b

        if self:checkCol(c, r) then
            c, r = c - a, r - b
  
            if self:checkCol(c, r) then
                self.throw_reticle.visible = false
            end
        end
    end


    self.throw_reticle.x = c
    self.throw_reticle.y = r
end

--- *(Override)* Called when the block is reset
function PushBlockBoard:onReset() end

function PushBlockBoard:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function PushBlockBoard:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

return PushBlockBoard