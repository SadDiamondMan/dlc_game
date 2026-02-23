---@class BoardScoreAdder : Object
---@overload fun(...) : BoardScoreAdder
local BoardScoreAdder, super = Class(Object)

function BoardScoreAdder:init()
    super.init(self)

    self.scoreamount = 20
    self.timer = 0
    self.score_init = false
    self.mysnd = "scorecollect"
    self.modamt = 5
end

function BoardScoreAdder:update()
    super.update(self)

    if not self.score_init then
        self.scoreleft = self.scoreamount
        self.mysign = MathUtils.sign(self.scoreamount)
        self.score_init = true

        if self.mysign < 0 then
            Game.board.ui.score_bar.sprite:setColor(ColorUtils.hexToRGB("#E33D47"))
            Game.board.ui.score_bar:shake()
        end

        if self.modamt == 5 then
            if math.abs(self.scoreamount) >= 100 then
                self.modamt = 10
            end
            if math.abs(self.scoreamount) >= 1000 then
                self.modamt = 100
            end
        end
    else
        self.timer = self.timer + (1 * DTMULT)

		if self.timer >= 1 then
			if self.scoreleft ~= 0 then
				if self.scoreleft > 0 then
					Assets.playSound(self.mysnd, nil, 1)
				end
				if self.scoreleft < 0 then
					Assets.playSound(self.mysnd, nil, 0.8)
				end

				if self.mysign > 0 then
					if self.scoreleft > self.modamt then
						self.scoreleft = self.scoreleft - self.modamt
						Game:setFlag("points", Game:getFlag("points") + self.modamt)
					else
						Game:setFlag("points", Game:getFlag("points") + self.scoreleft)
						self.scoreleft = 0
					end
				end
				if self.mysign < 0 then
					if self.scoreleft < -self.modamt then
						self.scoreleft = self.scoreleft + self.modamt
						Game:setFlag("points", Game:getFlag("points") - self.modamt)
					else
						Game:setFlag("points", Game:getFlag("points") + self.scoreleft)
						self.scoreleft = 0
					end
				end
			else
				Game.board.ui.score_bar.sprite:setColor(COLORS.white)
				self:remove()
			end
			self.timer = 0
		end
    end
end

return BoardScoreAdder