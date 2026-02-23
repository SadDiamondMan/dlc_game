local shopwriter_board, super = Class(Event)

function shopwriter_board:init(data)
    super.init(self, data.x, data.y, data.width, data.height)

    self.default_font = "8bit"
    self.default_font_size = 1

    self.font = self.default_font
    self.font_size = self.default_font_size
	
	self.text = data.properties["text"] or ""
	self.dialogue_text = DialogueText("", 0, -3, 640, 480,
    { auto_size = true, line_offset = 4, style = "none"})
    self.dialogue_text.skip_speed = true
    self:addChild(self.dialogue_text)
	self.text_active = false
	self.advance_snd = false
    --self.hitbox = {0, 0, data.width, data.height}
end

function shopwriter_board:update()
    super.update(self)

	local board = Game.world.board
	if not board then
		return
	end
	local cola, rowa = board:getArea(board.player.x, board.player.y - 1)
	local colb, rowb = board:getArea(self.x, self.y)
	if self.text_active and (cola ~= colb or rowa ~= rowb or board.swapping_grid or self.world.fader.state ~= "NONE" or self.world.fader.tilescovered > 0) then
		self.text_active = false
		self:setText("")
		self.advance_snd = true
	elseif not self.text_active and cola == colb and rowa == rowb and not board.swapping_grid and self.world.fader.state == "NONE" and self.world.fader.tilescovered <= 0 then
		self.text_active = true
		self:setText(self.text)
		self.advance_snd = false
	end
	if self.text_active then
		if not self.dialogue_text:isTyping() then
			if not self.advance_snd then
				Assets.stopAndPlaySound("board/text_end")
				self.advance_snd = true
			end
		end
	end
end

function shopwriter_board:setText(text, callback)
    self.dialogue_text.font = self.font
    self.dialogue_text.font_size = self.font_size

    self.dialogue_text:setText("[voice:board][noskip][speed:0.5]"..text, callback or self.advance_callback)
end

return shopwriter_board