---@class BoardPointsDisplay : Object
---@overload fun(...) : BoardPointsDisplay
local BoardPointsDisplay, super = Class(Object)

function BoardPointsDisplay:init(x, y, amount)
    super.init(self)

    self.x = x or 0
    self.y = y or 0
    self:setLayer(Game.world.board.player.layer + 0.01)

    self.amount = amount or 0
    self.timer = 0
    self.display_init = false
    self.onlyvisual = false

    Game.world.timer:after(1, function()
        self:remove()
	end)

    self.font = Assets.getFont("8bit")

    if not self.display_init then
        Game.stage.timer:lerpVar(self, "y", self.y, self.y - 20, 24, 6, "out")

        if not self.onlyvisual then
            Game.world.timer:after(7/30, function()
                if Game.world.board and Game.world.board.ui then
                    Game.world.board.ui:addScore(self.amount)
                end
            end)
        end
        
        self.display_init = true
	end
	self.true_x = self.x
	self.true_y = self.y
end

function BoardPointsDisplay:draw()
    super.draw(self)

    Draw.setColor(COLORS.white)

    local signer = "+"
    if self.amount < 0 then
        signer = ""
    end

    love.graphics.setFont(self.font)
    Draw.setColor(COLORS.black)
    love.graphics.print(signer..self.amount, 0 - 2, 0)
    love.graphics.print(signer..self.amount, 0 - 2, 0 - 2)
    love.graphics.print(signer..self.amount, 0 - 2, 0 + 2)
    love.graphics.print(signer..self.amount, 0 + 2, 0)
    love.graphics.print(signer..self.amount, 0 + 2, 0 - 2)
    love.graphics.print(signer..self.amount, 0 + 2, 0 + 2)
    love.graphics.print(signer..self.amount, 0, 0)
    love.graphics.print(signer..self.amount, 0, 0 - 2)
    love.graphics.print(signer..self.amount, 0, 0 + 2)

    if self.amount < 0 then
        Draw.setColor(ColorUtils.hexToRGB("#473DE3"))
    else
        Draw.setColor(COLORS.white)
    end
    love.graphics.print(signer..self.amount,  0, 0)
    Draw.setColor(COLORS.white)
end

function BoardPointsDisplay:preDraw()
	self.true_x = self.x
	self.true_y = self.y
	self.x = MathUtils.round(self.x / 2) * 2
	self.y = MathUtils.round(self.y / 2) * 2
	super.preDraw(self)
end

function BoardPointsDisplay:postDraw()
	super.postDraw(self)
	self.x = self.true_x
	self.y = self.true_y
end

return BoardPointsDisplay 