local help_pippins, super = Class(BoardEvent)

function help_pippins:init(data)
    super.init(self, data.x, data.y, data.width, data.height)
    self.data = data

    self.name = "HELP!"

    self.solid = true

    self.shop = self.data.properties['shop'] or nil
    self.wait_for_text = self.data.properties['waitfortext'] ~= false

    self.price = "100"

    self.spr = Sprite("sword/npcs/pippins")
    self.spr:setScale(2)
    self:addChild(self.spr)
    self.hitbox = {0, 0, 32, 32}
	self.do_sucker = false
	self.true_x = self.x
	self.true_y = self.y
	self.spr_true_x = self.spr.x
	self.spr_true_y = self.spr.y
end

function help_pippins:update()
	super.update(self)
	if self.do_sucker and self.spr.x < -self.x + Game.world.board.camera.x - 384/2 - 32 then
        self.price = nil
        self.name = "SUCKER"
		self.do_sucker = false
	end
end

function help_pippins:onInteract(player, dir)

    local i = Game.world.board.ui.inventory_bar
    local p = Game.world.board.player
    local cutscene = Game.world:startCutscene(function(c)

        if self.price and self.shop then
            if Game:getFlag("points") >= tonumber(self.price) then
                Game.world.board.ui:addScore(-self.price)
            else
                return
            end
        end

		c:wait(0.5)
		Game.world.timer:lerpVar(self.spr, "y", self.spr.y, self.spr.y - 32, 20, 2, "in")
		c:wait(50/30)
        Assets.playSound("board/mantle_dash_fast", 1, 1.8)
        Assets.playSound("board/splash", 0.4, 1.8)
		self.do_sucker = true
		Game.world.timer:lerpVar(self.spr, "x", self.spr.x, self.spr.x - 320, 20)
		c:wait(20/30)
		self.spr.visible = false
		self.collider.collidable = false
		self.solid = false
    end)
    cutscene:after(function()
        --maybe do stuff here?
    end)

    return true
end

function help_pippins:draw()
    super.draw(self)

    if self.shop then
        local shop = Game.world.board:getEvent(self.shop.id)
        if shop.text_active then
            if not shop.dialogue_text:isTyping() or self.wait_for_text == false then
                love.graphics.setFont(Assets.getFont("8bit"))
                love.graphics.setColor(1, 1, 1)

                love.graphics.printfOutline(self.name, (16 - #self.name * 8), 32, 2)
                if self.price then
                    love.graphics.printfOutline(self.price, (16 - #self.price * 8), 48, 2)
                end
           end
        end
    end
end

function help_pippins:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	self.spr_true_x = self.spr.x
	self.spr_true_y = self.spr.y
	self.spr.x = MathUtils.round(self.spr.x / 2) * 2
	self.spr.y = MathUtils.round(self.spr.y / 2) * 2
	super.preDraw(self)
end

function help_pippins:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
	self.spr.x = self.spr_true_x
	self.spr.y = self.spr_true_y
end

return help_pippins