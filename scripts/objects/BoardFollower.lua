--- The character controlled by the player when in the Board.
---@class BoardFollower : Character
---@overload fun(chara: string|Actor, x?: number, y?: number) : BoardFollower
local BoardFollower, super = Class(Character)

function BoardFollower:init(chara, x, y, party_slot)
    super.init(self, chara, x, y)
 
    self.pathing = false

    self.party_slot = party_slot

    self.following = false

    if Game.party[party_slot].id == "ralsei" then
        self.following = true
    end

    self.follow_delay = FOLLOW_DELAY

    self.world = Game.world.board
    self.is_player = true

    self.state_manager = StateManager("WALK", self, true)
    self.state_manager:addState("WALK", { update = self.updateWalk })

    self.auto_moving = false

    self.hurt_timer = 0

    self.moving_x = 0
    self.moving_y = 0
    self.walk_speed = 4

    self.last_move_x = self.x
    self.last_move_y = self.y

    self.history_time = 0
    self.history = {}

    self.battle_alpha = 0

    self.persistent = true
    self.noclip = false

    self.p_update = 0

    self.frames = 0
end

function BoardFollower:getBaseWalkSpeed()
    return 4
end

function BoardFollower:getCurrentSpeed()
    local speed = self:getBaseWalkSpeed()
    return speed
end

function BoardFollower:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "State: " .. self.state_manager.state)
    table.insert(info, "Walk speed: " .. self:getBaseWalkSpeed())
    table.insert(info, "Current walk speed: " .. self:getCurrentSpeed())
    table.insert(info, "Hurt timer: " .. self.hurt_timer)
    return info
end

function BoardFollower:onAdd(parent)
    super.onAdd(self, parent)
end

function BoardFollower:onRemove(parent)
    super.onRemove(self, parent)
end

function BoardFollower:onRemoveFromStage(stage)
    super.onRemoveFromStage(self, stage)
end

function BoardFollower:setActor(actor)
    super.setActor(self, actor)

    local hx, hy, hw, hh = self.collider.x, self.collider.y, self.collider.width, self.collider.height
end

function BoardFollower:setState(state, ...)
    self.state_manager:setState(state, ...)
end

function BoardFollower:isCameraAttachable()
    return
end

function BoardFollower:isMovementEnabled()
    return not OVERLAY_OPEN
        and not Game.lock_movement
        and Game.state == "OVERWORLD"
        and self.world.state == "GAMEPLAY"
        and self.hurt_timer == 0
        and Game.world.door_delay == 0
end

function BoardFollower:updatePlayer()
    local id = Game.party[self.party_slot].id

    if self.p_update < 15 then
        self.p_update = self.p_update + DTMULT
        return
    end
    
    self.p_update = 0

    if id == "ralsei" then
        local p = Game.world.board.player

        local dx = p.x - self.x
        local dy = p.y - self.y
        local dd = dx * dx + dy * dy
        if not (dd <= 64 * 64) then self:pathfindTo(p.x, p.y) end
    elseif id == "susie" then
    end
end

function BoardFollower:getTarget()
    return Game.world.board.player
end

function BoardFollower:getTargetPosition()
    local follow_delay = self:getFollowDelay()
    local tx, ty, facing, state, args = self.x, self.y, self.facing, nil, {}
    for i,v in ipairs(self.history) do
        tx, ty, facing, state, args = v.x, v.y, v.facing, v.state, v.state_args
        local upper = self.history_time - v.time
        if upper > follow_delay then
            if i > 1 then
                local prev = self.history[i - 1]
                local lower = self.history_time - prev.time

                local t = (follow_delay - lower) / (upper - lower)

                tx = MathUtils.lerp(prev.x, v.x, t)
                ty = MathUtils.lerp(prev.y, v.y, t)
            end
            break
        end
    end
    return tx, ty, facing, state, args
end

function BoardFollower:moveToTarget(speed)
    if self:getTarget() and self:getTarget().history then
        local tx, ty, facing, state, args = self:getTargetPosition()
        local dx, dy = tx - self.x, ty - self.y

        if speed then
            dx = MathUtils.approach(self.x, tx, speed * DTMULT) - self.x
            dy = MathUtils.approach(self.y, ty, speed * DTMULT) - self.y
        end

        self:move(dx, dy)

        if facing and (not speed or (dx == 0 and dy == 0)) then
            self:setFacing(facing)
        end

        if state and self.state_manager:hasState(state) then
            self.state_manager:setState(state, unpack(args or {}))
        end

        return dx, dy
    else
        return 0, 0
    end
end

--- Gets the delay in seconds this follower will follow its target's position,
--- taking into account the delay of followers in front of itself.
function BoardFollower:getFollowDelay()
    local total_delay = 0

    for i,v in ipairs(Game.world.board.followers) do
        total_delay = total_delay + v.follow_delay

        if v == self then break end
    end

    return total_delay
end

function BoardFollower:isAutoMoving()
    local target_time = self:getFollowDelay()
    for i,v in ipairs(self.history) do
        if v.auto then
            return true
        end
        if (self.history_time - v.time) > target_time then
            break
        end
    end
    return false
end


function BoardFollower:updateHistory(moved, auto)
    if moved then
        self.blush_timer = 0
    end
    local target = self:getTarget()

    local auto_move = auto or self:isAutoMoving()

    if moved or auto_move then
        self.history_time = self.history_time + DT

        table.insert(self.history, 1, {x = target.x, y = target.y, facing = target.facing, time = self.history_time, state = target.state, state_args = target.state_manager.args, auto = auto})
        while (self.history_time - self.history[#self.history].time) > (Game.max_followers * FOLLOW_DELAY) do
            table.remove(self.history, #self.history)
        end

        if self.following and not self.physics.move_target then
            self:moveToTarget()
        end
    end
end

function BoardFollower:replayMovement(walk_x, walk_y)

    if self.replay then
        local f = "".. self.frames

        if self.replay["left"][f] then
            if self.replay["left"][f] == 1 then self.l = 1
            else self.l = nil end
        elseif self.replay["right"][f] then
            if self.replay["right"][f] == 1 then self.r = 1
            else self.r = nil end
        end

        if self.replay["down"][f] then
            if self.replay["down"][f] == 1 then self.d = 1
            else self.d = nil end
        elseif self.replay["up"][f] then
            if self.replay["up"][f] == 1 then self.u = 1
            else self.u = nil end
        end


        if self.l then walk_x = walk_x - 1
        elseif self.r then walk_x = walk_x + 1 end
        if self.u then walk_y = walk_y - 1
        elseif self.d then walk_y = walk_y + 1 end


        local speed = self:getCurrentSpeed()


        self:move(walk_x, walk_y, speed * DTMULT)
        self.frames = self.frames + 1
    end
end

function BoardFollower:handleMovement()
    local walk_x = 0
    local walk_y = 0

    self:replayMovement(walk_x, walk_y)

    self:updatePlayer()
end

function BoardFollower:updateWalk()
    if self:isMovementEnabled() then
        self:handleMovement()
    end
end

function BoardFollower:isMoving()
    return self.moving_x ~= 0 or self.moving_y ~= 0
end

function BoardFollower:hurt(amount, hazard)
end

-- Creates a smoke puff effect.
---@param x?        number  The x-coordinate of the effect. (Defaults to player's x-position)
---@param y?        number  The y-coordinate of the effect. (Defaults to player's y-position)
---@param color?    table   The color of the effect.
function BoardFollower:createPuff(x, y, color)
    local color = color or {}

    local puff = BoardSmokePuff(x or self.moving_x, y or self.moving_y)
    puff:setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    puff:setOriginExact(8, 8)
    puff:setLayer(self.layer + 0.1)
    self:addChild(puff)
end

-- changes the current player character
function BoardFollower:switchCharacter()
end

-- abilities for the characters
function BoardFollower:characterAction()
end

function BoardFollower:update()

    self.state_manager:update()

    super.update(self)
end

--- Attempts to path a character to a position from its current position.
--- Returns false if failed.
--- 
--- @param x number The target X position.
---@param y number The target Y position.
---@param options table A table of options. Supported options:
---|"refollow" # If a follower, will immediately refollow after pathfinding completion or failure.
---|"refollow_on_fail" # If a follower, will immediately refollow after pathfinding failure.
---|"speed" # The walking speed at which the character will follow the path. Defaults to 4.
---|"after" # A function executed after pathfinding is complete. Recieves no arguments.
---|"valid_distance" # The valid range to search for ending positions by the target. Defaults to 1.
function BoardFollower:pathfindTo(x, y, options)
    self.following = false
    options = options or {}
    if (options and options.refollow_on_fail == nil) then options.refollow_on_fail = true end
    local current_node = Game.world.board:getNearestNode(self.x, self.y)
    local target_node = Game.world.board:getNearestValidNode(x, y, self.collider, options.valid_distance or 5)
    if (not target_node) then
        if options and (options.refollow or options.refollow_on_fail) and self.returnToFollowing then self:returnToFollowing(6) end
        --Kristal.Console:log("[Pathfinder] : Target node invalid! Returning...")
        return false
    end
    local path = Game.world.board:findPathTo(current_node[1], current_node[2], target_node[1], target_node[2], self.collider)
    if (#path == 0) then
        if options and (options.refollow or options.refollow_on_fail) and self.returnToFollowing then self:returnToFollowing(6) end
        --Kristal.Console:log("[Pathfinder] : Pathfinding failed! Returning...")
        return false
    end
    self.pathing = true
    --Kristal.Console:log("[Pathfinder] : Found a path that is " ..#path.." nodes long! Pathfinding...")
    self:walkPath(path, { speed = options and options.speed or 4, loop = false, relative = false, after = function ()
        self.pathing = false
        if options and options.after then options.after() end
        if options and options.refollow and self.returnToFollowing then self:returnToFollowing(6) end
        --Kristal.Console:log("[Pathfinder] : Pathfinding complete! Arrived at target destination.")
        end }
    )
    return true
end

function BoardFollower:doWalkToStep(x, y, keep_facing)
    local was_noclip = self.noclip
    self.noclip = not self.pathing
    self:move(x, y, 1, keep_facing)
    self.noclip = was_noclip
end

function BoardFollower:draw()
    if DEBUG_RENDER and Pathfinder:getConfig("debug_render_pathfinding") then
        local node = Game.world.board:getNearestNode(self.x, self.y)
        local neighbors = Game.world.board:getValidNeighbors(node[1], node[2], self.collider, 1)
        Draw.setColor(0, 1, 0.5, 0.5)
        local sprite = Assets.getTexture("effects/criticalswing/sparkle_2")
        local sprite_path = Assets.getTexture("effects/criticalswing/sparkle_1")
        for index, value in ipairs(neighbors) do
            local world_pos = Game.world.board:nodePosToWorld(value[1], value[2])
            local relative_x, relative_y = Game.world.board:getRelativePos(world_pos[1], world_pos[2], self)
            Draw.draw(sprite, relative_x - 4, relative_y - 4, nil, nil, nil)
        end
        Draw.setColor(1, 1, 1, 0.25)
        if (self.pathing and self.physics.move_path and self.physics.move_path.path and (#self.physics.move_path.path > 0)) then
            love.graphics.setLineWidth(1)
            love.graphics.setLineStyle("rough")
            local last_line_end = nil
            for index, value in ipairs(self.physics.move_path.path) do
                local relative_x, relative_y = Game.world.board:getRelativePos(value[1], value[2], self)
                if (last_line_end) then love.graphics.line(last_line_end[1], last_line_end[2], relative_x, relative_y) end
                Draw.draw(sprite_path, relative_x - 4, relative_y - 4, nil, nil, nil)
                last_line_end = { relative_x, relative_y }
            end
        end
        Draw.setColor(1,1,1,1)
    end
    super.draw(self)
end

return BoardFollower
