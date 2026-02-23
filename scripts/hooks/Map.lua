---@class Map : Class
---@overload fun(...) : Map
local Map, super = HookSystem.hookScript(Map)

function Map:init(world, data)
    super.init(self, world, data)
    self.camera_blocker_area = {}
end

function Map:loadLayer(layer, depth)
    if layer.type == "objectgroup" and StringUtils.startsWith(layer.name:lower(), "camera_blocker") then
        self:loadCameraBlockerArea(layer)
        self:loadShapes(layer)
    else
		super.loadLayer(self, layer, depth)
	end
end

function Map:loadCameraBlockerArea(layer)
    TableUtils.merge(self.camera_blocker_area, self:loadHitboxes(layer))
end

return Map