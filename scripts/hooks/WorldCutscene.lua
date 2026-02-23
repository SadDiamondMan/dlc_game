---@class WorldCutscene : WorldCutscene
local WorldCutscene, super = HookSystem.hookScript(WorldCutscene)

local function waitForTextbox(self) return not self.textbox or self.textbox:isDone() end

function WorldCutscene:boardText(text, options)
    options = options or {}

	if not self.textbox and self.board_texted then
		self.board_texted = false
	end
    self:closeText()
    local world = Game.world.board or Game.world
	local instant = self.board_texted or false
    self.textbox = BoardTextbox(128, 346, 384, 86, instant)
    self.textbox.layer = WORLD_LAYERS["above_events"]-0.01
    world:addChild(self.textbox)
    self.textbox:setParallax(0, 0)

    if options["top"] == nil and self.textbox_top == nil then
        local _, player_y = world.player:localToScreenPos()
        options["top"] = player_y > 192-32
    end
    if options["top"] or (options["top"] == nil and self.textbox_top) then
		self.textbox.side = 0
        if Game.world.board then
            self.textbox.x = 0
            self.textbox.y = -112
            self.textbox.endy = -16
        else
		    self.textbox.y = -80
			self.textbox.endy = 48
		end
    else
		if Game.world.board then
            self.textbox.x = 0
            self.textbox.y = 284
            self.textbox.endy = 156
		end
	end
    self.textbox.active = true
    self.textbox.visible = true
	self.textbox.text.state["typing"] = false

    if options["functions"] then
        for id,func in pairs(options["functions"]) do
            self.textbox:addFunction(id, func)
        end
    end

    if options["font"] then
        if type(options["font"]) == "table" then
            -- {font, size}
            self.textbox:setFont(options["font"][1], options["font"][2])
        else
            self.textbox:setFont(options["font"])
        end
    end

    if options["align"] then
        self.textbox:setAlign(options["align"])
    end

    self.textbox:setSkippable(options["skip"] or options["skip"] == nil)
    self.textbox:setAdvance(options["advance"] or options["advance"] == nil)
    self.textbox:setAuto(options["auto"])

    self.textbox:setText(text, function()
		self.board_texted = true
        self.textbox:remove()
        self:tryResume()
    end)

    local wait = options["wait"] or options["wait"] == nil
    if not self.textbox.text.can_advance then
        wait = options["wait"] -- By default, don't wait if the textbox can't advance
    end

    if wait then
        return self:wait(waitForTextbox)
    else
        return waitForTextbox, self.textbox
    end
end

function WorldCutscene:resetBoardText()
	self.board_texted = false
end

return WorldCutscene