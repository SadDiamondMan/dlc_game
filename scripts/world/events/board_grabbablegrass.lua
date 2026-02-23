local BoardGrabbableGrass, super = Class(Event)

function BoardGrabbableGrass:init(data)
    super.init(self, data)

    local properties = data and data.properties or {}

	self:setSprite("world/events/sword/grabbablegrass/idle")
	self.siner = 0
	self.con = 0
	self.init = false
	self.grabdaddy = nil
	self.grabcount = 0
	self.bomb = 0
	self.coin = 0
	self.cameraend = 0
	self.trig = nil
	self.trigtime = 0
	self.resetcon = 0
	self.dofun = nil
	self.dograb = nil
	self.docanfreemove = nil
	self.type = properties["type"] or "coin"
	self.value = properties["value"] or 20
	self.potsprite = nil
	self.infinite = properties["infinite"] ~= false
end

function BoardGrabbableGrass:update()
	-- Very unfinished
    super.update(self)
	self.siner = self.siner + DTMULT
	if self.con == 0 then
		self.sprite:setFrame(math.floor(math.abs(self.siner / 15) * 3) + 1)
	end
end

return BoardGrabbableGrass