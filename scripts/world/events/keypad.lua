local Keypad, super = Class(Event, "keypad")

function Keypad:updatePad()
    if self.open then
        -- Destroy the door object
        self.solid = false
        self.visible = false
        local door = self.door

        if door then
            local id = door.id
            if id then
                Game.world.map:getEvent(id):remove()
            else
                door:remove()
            end
        end
    end
end

function Keypad:init(data)
    super.init(self, data)
    self:setSprite("world/events/keypad/idle")

    local properties = data.properties or {}
    self.properties = properties or {}
    self.open = false
    self.solid = true
    self.sound = properties["sound"] or "bell"
    self.errorsound = properties["errorsound"] or "error"
    self.door = properties["door"] or properties["object"] or properties["obj"]
    self.numbers = properties["numbers"] or 4
    self.padnumbers = properties["padnumbers"] or properties["pad"] or self.numbers
    self.pass = properties["pass"] or properties["password"] or "1234"

    self:setScale(1)
    self:setOrigin(0.5, 1)
    self:updatePad()
end

function Keypad:onAdd(parent)
    super.onAdd(self, parent)

    if self:getFlag("unlocked") then
        self.open = true
        self:updatePad()
    end
end

function Keypad:update()
    super.update(self)
end

function Keypad:draw()
    super.draw(self)
end

function Keypad:onInteract(player, dir)
    if self.open then return end
    local cutscene = Game.world:startCutscene(function(c)
        c:text("* It appears to be some kind of keypad.")
        c:text("* Enter the code?")
        local keychoice = c:choicer({"Enter code", "Do not"})
        if keychoice == 2 then return end
		local rows = {}
		for i = 1, self.numbers do
			table.insert(rows, {preset="numbers", c=StringUtils.sub(self.pass, i, i)})
		end
		local correct, input = c:passcode(rows)
		if correct then
			c:text("* (You entered the numbers knowingly.)")
            self.open = true
			if self.open then
				Assets.playSound("bluh")
				self:setFlag("unlocked", true)
				self:updatePad()
			end
		else
			c:text("* (...[wait:5] wrong combination!)")
		end
    end)
end

return Keypad