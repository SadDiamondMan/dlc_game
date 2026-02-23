local board_item, super = Class(BoardEvent)

function board_item:init(data)
    super.init(self, data.x, data.y, data.width, data.height)
    self.data = data
    self.id = self.data.properties['id'] or "test_item"
    self.spr = self.data.properties['sprite'] or "sword/ui/inventory/test_item"
    self.name = self.data.properties['name'] or "NESS"
    self.text = self.data.properties['text'] or "YOU GOT THE [color:yellow]".. self.name .."[color:reset]!"
    self.moretext = TiledUtils.parsePropertyMultiList("moretext", self.data.properties) or nil
    self.slot = self.data.properties['slot'] or 0
	self.amt = self.data.properties['amount'] or 1
    self.sound = self.data.properties['sound'] or "board/itemget"

    self.shop = self.data.properties['shop'] or nil

    self.price = self.data.properties['price'] or nil
    self.glow = self.data.properties['glow'] or false
    self.wait_for_text = self.data.properties['waitfortext'] ~= false

    self:setSprite(self.spr)
    self.hitbox = {0, 0, 32, 32}
	if self.shop then
		self.hitbox = {2, 2, 30, 30}
	end
	
	if self.id == "keycount" then
		self.text = self.data.properties['text'] or "YOU GOT [color:yellow]KEY[color:reset] x1"
	elseif self.id == "qcount" then
		self.text = self.data.properties['text'] or "YOU GOT [color:yellow]Q[color:reset] x1"
		self.glow = self.data.properties['glow'] or true
	elseif self.id == "lancer" then
		self.text = self.data.properties['text'] or "YOU GOT [color:yellow]LANCER[color:reset]!"
	elseif self.id == "camera" then
		self.text = self.data.properties['text'] or "YOU GOT THE [color:yellow]CAMERA[color:reset]!"
		self.moretext[1] = self.moretext and self.moretext[1] or "PRESS [color:yellow]"..Input.getText("confirm").."[color:reset] TO TAKE A PICTURE!"
		self.amt = self.data.properties['amount'] or 0
	end
	self.makestars = false
	self.makestarstimer = 0
	self.makestarstimerloop = 0
	self.glowtimer = 0
	self.glowsiner = 0
    self.color_mask = self.sprite:addFX(ColorMaskFX(COLORS.white, 0))
    self.color_mask.amount = 0
	self.true_x = self.x
	self.true_y = self.y
end

function board_item:update()
	if self.makestars then
		local starlayer = self.layer - 0.01
		self.makestarstimer = self.makestarstimer + DTMULT
		self.makestarstimerloop = self.makestarstimerloop + DTMULT
		
		if self.makestarstimerloop >= 2 then
			local star = BoardSmallStar(self.x, self.y)
			star.layer = starlayer
			star.physics.direction = math.rad(self.makestarstimer * 20)
			star.physics.speed = 5
			star.physics.friction = 0.25
			star.frame = MathUtils.randomInt(3)
			Game.world.timer:after(MathUtils.random(13, 16)/30, function()
				star:remove()
			end)
			Game.world.board:addChild(star)
			
			local star2 = BoardSmallStar(self.x, self.y)
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
	if self.glow and not (self.shop and self.price) then
		self.glowtimer = self.glowtimer + DTMULT
		if self.glowtimer >= 8 then
			self.glowsiner = self.glowsiner + DTMULT
			self.glowtimer = 0
		end
		self.color_mask.amount = math.abs(math.sin(self.glowsiner / 2))
	else
		self.color_mask.amount = 0
	end
end

function board_item:onInteract(player, dir)
	if self.price and self.shop then
		if Game:getFlag("points") >= tonumber(self.price) then
			self:pickup()
		end
	end
end

function board_item:onEnter(chara)
    if chara.is_player and not Game.lock_movement and not self.world:hasCutscene() then
		if self.price and self.shop then
			if Game:getFlag("points") < tonumber(self.price) then
				return
			end
		end
		self:pickup()
	end
end

function board_item:pickup()
	local i = Game.world.board.ui.inventory_bar
	local p = Game.world.board.player
	local cutscene = Game.world:startCutscene(function(c)
		if self.id == "lancer" and i.lancer > 0 then
			self.text = self.data.properties['text'] or "YOU GOT ANOTHER [color:yellow]LANCER[color:reset]!"
		end
		if self.price and self.shop then
			if Game:getFlag("points") >= tonumber(self.price) then
				Game.world.board.ui:addScore(-self.price)
				self.price = nil
			end
		end
		self.glow = false
		self.layer = p.layer
		Game.world.timer:script(function(wait)
			if not p.actor.no_spin then
				wait(3/30)
				p:setFacing("left")
				wait(1/30)
				p:setFacing("up")
				wait(1/30)
				p:setFacing("right")
				wait(1/30)
				p:setFacing("down")
				wait(1/30)
				p:setFacing("left")
				wait(1/30)
				p:setFacing("up")
				wait(1/30)
				p:setFacing("right")
				wait(1/30)
			else
				wait(10/30)
			end
			p:setSprite("item")
		end)
		Game.world.timer:lerpVar(self, "x", self.x, p.x - 16, 12, 2, "in")
		Game.world.timer:lerpVar(self, "y", self.y, p.y - 64 - 8, 12, 2, "out")
		c:wait(12/30)
		Assets.playSound(self.sound)
		self.makestars = true
		c:boardText(self.text) 
		if self.moretext then
            for _,line in ipairs(self.moretext) do
                c:boardText(line)
            end
		end
		c:resetBoardText()
		self.collider.collidable = false
		p:resetSprite()
		self.makestars = false
		if self.slot ~= -1 then
			self.visible = false
			local xx, yy = self:localToScreenPos(Game.world.board.off_x, Game.world.board.off_y)
			self.item_sprite = Sprite(self.spr, xx, yy)
			self.item_sprite:setOrigin(0)
			self.item_sprite:setScale(2)
			self.item_sprite:setLayer(WORLD_LAYERS["top"] - 1)
			Game.world:addChild(self.item_sprite)
			local desigx = 0
			local desigy = 0
			if i then
				desigx = i.x + 8
				desigy = i.y + 10 + (48 * self.slot)
			end
			Game.world.timer:lerpVar(self.item_sprite, "x", xx, desigx, 20, 2, "in")
			Game.world.timer:lerpVar(self.item_sprite, "y", yy, desigy, 20, 2, "out")
			Game.world.timer:after(20/30, function()
				Assets.playSound("item")
				Game.world.board.ui:addItem(self, self.slot)
				self.item_sprite:remove()
				self:remove()
			end)
		else
			Game.world.timer:after(3/30, function()
				self:remove()
			end)
		end
	end)
	cutscene:after(function()
		--maybe do stuff here?
	end)

	return true
end

function board_item:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function board_item:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

function board_item:draw()
    super.draw(self)

    if self.shop and self.price then
        local shop = Game.world.board:getEvent(self.shop.id)
        if shop.text_active then
            if not shop.dialogue_text:isTyping() or self.wait_for_text == false then
                love.graphics.setFont(Assets.getFont("8bit"))
                love.graphics.setColor(1, 1, 1)

                love.graphics.printfOutline(self.name, (16 - #self.name * 8), 32, 2)
                if self.price == "0" then
                    love.graphics.printfOutline("FREE", -16, 48, 2)
                else
                    love.graphics.printfOutline(self.price, (16 - #self.price * 8), 48, 2)
                end

            end
        end
    end
end

return board_item