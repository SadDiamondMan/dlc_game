--- The `World` Object manages everything relating to the overworld in Kristal. \
--- A globally available instance of `World` is stored in [`Game.world`](lua://Game.world).
---
---@class BoardWorld : Object
---
---@field state             string                          The current state that this `World` is in - should never be set manually, see [`BoardWorld:setState()`](lua://World.setState) instead
---@field state_manager     StateManager                    An object that manages the state of this `World`
---
---@field music             Music                           The `Music` instance that controls audio playback for this `World`
---
---@field map               Map                             The currently loaded map instance
---
---@field camera            Camera                          The camera object used to display the world
---
---@field player            Player                          The player character
---@field soul              OverworldSoul                   The soul of the player
---
---@field battle_borders    table                           *(unused? See [`Map.battle_borders`](lua://Map.battle_borders))*
---
---@field transition_fade   number                          *(unused?)*
---
---@field in_battle         boolean                         Whether the player is currently in a world battle set through [`BoardWorld:setBattle()](lua://World.setBattle) (affects the visibility of world battle content)
---@field in_battle_area    boolean                         Whether the player is currently standing inside a battlearea of the map (affects the visibility of world battle content)
---@field battle_alpha      number                          The current alpha value of world battle content
---
---@field bullets           WorldBullet[]                   A table of currently active bullets
---@field followers         Follower[]                      A table of all followers currently present in the world
---
---@field cutscene          WorldCutscene?                  The `WorldCutscene` object of the currently active cutscene, if present
---
---@field conroller_parent  Object                          The object that all controllers are parented to
---
---@field fader             BoardFader
---
---@field timer             Timer
---
---@field can_open_menu     boolean                         Whether the player can open their menu
---
---@field menu              LightMenu|DarkMenu?             The Menu object of the menu, if it is open
---
---@field calls             table<[string, string]>   A list of calls available on the cell phone in the Light World CELL menu
---
---@field door_delay        number                          *(Used internally)* Timer variable for door transition sounds
---
---@field healthbar         HealthBar
---
---@overload fun(map?: string) : World
local BoardWorld, super = Class(Object)

---@param map? string    The optional name of a map to initially load with the world
function BoardWorld:init(map, x, y, offx, offy, swidth, sheight)
    super.init(self)
    self.world = self
    Game.world.board = self
    Game.board = self
	self.screen_width = swidth or 384
	self.screen_height = sheight or 256
    self.camera = Camera(self, 0,0,self.screen_width,self.screen_height)
    -- states: GAMEPLAY, FADING, MENU
    self.state = "" -- Make warnings shut up, TODO: fix this
    self.state_manager = StateManager("GAMEPLAY", self, true)
    self.state_manager:addState("GAMEPLAY")
    self.state_manager:addState("FADING")
    self.state_manager:addState("MENU")

    self.map = Map(self)

    self.width = self.map.width * self.map.tile_width
    self.height = self.map.height * self.map.tile_height

    self:moveCamera((x or 0), (y or 0))
    self.off_x, self.off_y = offx or 128, offy or 64

    self.player = nil
    self.soul = nil

    self.battle_borders = {}

    self.transition_fade = 0

    self.in_battle = false
    self.in_battle_area = false
    self.battle_alpha = 0

    self.bullets = {}
    self.followers = {}

    self.cutscene = nil

    self.controller_parent = Object()
    self.controller_parent.layer = WORLD_LAYERS["bottom"] - 1
    self.controller_parent.persistent = true
    self.controller_parent.world = self
    self:addChild(self.controller_parent)

    self.fader = BoardFader()
    self.fader.layer = WORLD_LAYERS["above_ui"]
    self.fader.persistent = true
    self:addChild(self.fader)

    self.timer = Timer()
    self.timer.persistent = true
    self:addChild(self.timer)

    self.can_open_menu = true

    self.menu = nil

    self.debug_select = false

    self.calls = {}

    self.door_delay = 0

    if map then
        self:loadMap(map)
    end

	self.rafting = false
	self.targets_can_update_cam = true
	self.swapping_grid = false
	self.grayregion = nil
	self.chromstrength = 0.5
	self.crt_glitch = 0
	self.crttimer = 0
	self.crtshader = Assets.getShader("crt")
	self.grayshader = Assets.getShader("grayscalesand")
end

--- Heals a member of the party
---@param target    string|PartyMember  The party member to heal
---@param amount    number              The amount of HP to restore
---@param text?     string              An optional text to display when HP is resotred in the Light World, before the HP restoration message
function BoardWorld:heal(target, amount, text)
    if type(target) == "string" then
        target = Game:getPartyMember(target)
    end

    local maxed = target:heal(amount)

    if Game:isLight() then
        local message
        if maxed then
            message = "* Your HP was maxed out."
        else
            message = "* You recovered " .. amount .. " HP!"
        end
        if text then
            message = text .. " \n" .. message
        end
        Game.BoardWorld:showText(message)
    elseif self.healthbar then
        for _, actionbox in ipairs(self.healthbar.action_boxes) do
            if actionbox.chara.id == target.id then
                local text = HPText("+" .. amount, self.healthbar.x + actionbox.x + 69, self.healthbar.y + actionbox.y + 15)
                text.layer = WORLD_LAYERS["ui"] + 1
                Game.BoardWorld:addChild(text)
                return
            end
        end
    end
end

--- Hurts the party member `battler` by `amount`, or hurts the whole party for `amount`
---@overload fun(self: World, amount: number)
---@param battler   Character|string    The Character to hurt
---@param amount    number              The amount of damage to deal
---@return boolean  killed  Whether all targetted characters were knocked out by this damage
function BoardWorld:hurtParty(battler, amount)
    Assets.playSound("hurt")

    self:shakeCamera()
    self:showHealthBars()

    if type(battler) == "number" then
        amount = battler
        battler = nil
    end

    local any_killed = false
    local any_alive = false
    for _,party in ipairs(Game.party) do
        if not battler or battler == party.id or battler == party then
            local current_health = party:getHealth()
            party:setHealth(party:getHealth() - amount)
            if party:getHealth() <= 0 then
                party:setHealth(1)
                any_killed = true
            else
                any_alive = true
            end

            local dealt_amount = current_health - party:getHealth()

            for _,char in ipairs(self.stage:getObjects(Character)) do
                if char.actor and (char.actor.id == party:getActor().id) and dealt_amount > 0 then
                    char:statusMessage("damage", dealt_amount)
                end
            end
        elseif party:getHealth() > amount then
            any_alive = true
        end
    end

    if self.player then
        self.player.hurt_timer = 7
    end

    if any_killed and not any_alive then
        if not self.map:onGameOver() then
            Game:gameOver(self.soul:getScreenPos())
        end
        return true
    elseif battler then
        return any_killed
    end

    return false
end

--- Changes the state of the world
---@param state string
function BoardWorld:setState(state)
    self.state_manager:setState(state)
end

--- Opens the main overworld menu
---@param menu?     LightMenu|DarkMenu  An optional menu instance to open
---@param layer?    number  The layer to create the menu on (defaults to `WORLD_LAYERS["ui"]` or `600`)
---@return (DarkMenu|LightMenu)?
function BoardWorld:openMenu(menu, layer)
    if self:hasCutscene() then return end
    if self:inBattle() then return end
    if not self.can_open_menu then return end

    if self.menu then
        self.menu:remove()
        self.menu = nil
    end

    if not menu then
        menu = self:createMenu()
    end

    self.menu = menu
    if self.menu then
        self.menu.layer = layer and self:parseLayer(layer) or WORLD_LAYERS["ui"]

        if self.menu:includes(AbstractMenuComponent) then
            self.menu.close_callback = function()
                self:afterMenuClosed()
            end
        elseif self.menu:includes(Component) then
            -- Sigh... traverse the children to find the menu component
            for _,child in ipairs(self.menu:getComponents()) do
                if child:includes(AbstractMenuComponent) then
                    child.close_callback = function()
                        self:afterMenuClosed()
                    end
                    break
                end
            end
        end

        self:addChild(self.menu)
        self:setState("MENU")
    end
    return self.menu
end

--- Creates the main overworld menu if it does not exist \
--- *The [event](lua://KRISTAL_EVENT) `createMenu` is called by this function, which can return a custom menu to use instead of the default Light/Dark menu*
---@return LightMenu|DarkMenu
function BoardWorld:createMenu()
    local menu = Kristal.callEvent(KRISTAL_EVENT.createMenu)
    if menu then return menu end
    if Game:isLight() then
        menu = LightMenu()
    else
        menu = DarkMenu()
    end
    return menu
end

--- Closes the menu
function BoardWorld:closeMenu()
    if self.menu then
        if not self.menu.animate_out and self.menu.transitionOut then
            self.menu:transitionOut()
        elseif (not self.menu.transitionOut) and self.menu.close then
            self.menu:close()
        end
    end
    self:afterMenuClosed()
end

--- Runs whenever the menu is closed
function BoardWorld:afterMenuClosed()
    self:hideHealthBars()
    self.menu = nil
    self:setState("GAMEPLAY")
end

--- Sets the value of a cell flag (a special flag which normally starts at -1 and increments by 1 at the start of every call, named after the call cutscene)
---@param name  string  The name of the flag to set
---@param value integer The value to set the flag to
function BoardWorld:setCellFlag(name, value)
    Game:setFlag("lightmenu#cell:" .. name, value)
end

--- Gets the value of a cell flag (a special flag which normally starts at -1 and increments by 1 at the start of every call, named after the call cutscene)
---@param name      string
---@param default?  integer
---@return integer
function BoardWorld:getCellFlag(name, default)
    return Game:getFlag("lightmenu#cell:" .. name, default)
end

--- Registers a phone call in the Light World CELL menu
---@param name  string          The name of the call as it will show in the CELL menu
---@param scene string          The cutscene to play when the call is selected
function BoardWorld:registerCall(name, scene)
    table.insert(self.calls, {name, scene})
end

--- Replaces a phone call in the Light World CELL menu with another
---@param name  string          The name of the call as it will show in the CELL menu
---@param index integer         The index of the call to replace
---@param scene string          The cutscene to play when the call is selected
function BoardWorld:replaceCall(name, index, scene)
    self.calls[index] = {name, scene}
end

--- Shows party member health bars
function BoardWorld:showHealthBars()
    if Game.light then return end

    if self.healthbar then
        self.healthbar:transitionIn()
    else
        self.healthbar = HealthBar()
        self.healthbar.layer = WORLD_LAYERS["ui"]
        self:addChild(self.healthbar)
    end
end

--- Hides party member health bars
function BoardWorld:hideHealthBars()
    if self.healthbar then
        if not self.healthbar.animate_out then
            self.healthbar:transitionOut()
        end
    end
end

--- Called whenever the state of the world changes
---@param old string
---@param new string
function BoardWorld:onStateChange(old, new)
end

---@param key string
function BoardWorld:onKeyPressed(key)
--[[    if Kristal.Config["debug"] and Input.ctrl() then
    end

    if Game.lock_movement then return end

    if self.state == "GAMEPLAY" then
        if Input.isConfirm(key) and self.player and not self:hasCutscene() then
            if self.player:interact() then
                Input.clear("confirm")
            else
                self.ui:characterAction()
                self.ui:characterAction()
            end
        end
    end

    if Input.isMenu(key) then
        self:remove()
    end]]
end

--- Checks whether there is currently a textbox open
---@return boolean
function BoardWorld:isTextboxOpen()
    return (self:hasCutscene() and self.cutscene.textbox and self.cutscene.textbox.stage ~= nil) or 
	(Game.world:hasCutscene() and Game.world.cutscene.textbox and Game.world.cutscene.textbox.stage ~= nil)
end

--- Gets the collision map for the world
---@param enemy_check?  boolean     Whether to include the enemy collision map (defaults to `false`)
---@return Collider[]
function BoardWorld:getCollision(enemy_check)
    local col = {}
    for _,collider in ipairs(self.map.collision) do
        table.insert(col, collider)
    end
    if enemy_check then
        for _,collider in ipairs(self.map.enemy_collision) do
            table.insert(col, collider)
        end
    end
    for _,child in ipairs(self.children) do
        if child.solid_collider and child.solid then
            table.insert(col, child.solid_collider)
        elseif child.collider and child.solid then
            table.insert(col, child.collider)
        end
    end
    return col
end

--- Checks whether the input `collider` is colliding with anything in the world
---@param collider      Collider    The collider to check collision for
---@param enemy_check?  boolean     Whether to include the enemy collision map in the check
---@return boolean  collided    Whether a collision was found
---@return Object?  with        The object that was collided with
function BoardWorld:checkCollision(collider, enemy_check)
    Object.startCache()
    for _,other in ipairs(self:getCollision(enemy_check)) do
        if collider:collidesWith(other) and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

--- Checks whether the input `collider` is colliding with anything in the world
---@param collider      Collider    The collider to check collision for
---@param enemy_check?  boolean     Whether to include the enemy collision map in the check
---@return boolean  collided    Whether a collision was found
---@return Object?  with        The object that was collided with
function BoardWorld:checkCameraBlockerCollision(collider)
    Object.startCache()
    for _,other in ipairs(self.map.camera_blocker_area) do
        if collider:collidesWith(other) and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

--- Whether the world has a currently active cutscene
---@return boolean?
function BoardWorld:hasCutscene()
    return self.cutscene and not self.cutscene.ended
end

--- Starts a cutscene in the world
---@overload fun(self: World, id: string, ...)
---@param group string  The name of the group the cutscene is a part of
---@param id    string  The id of the cutscene 
---@param ...   any     Additional arguments that will be passed to the cutscene function
---@return WorldCutscene?   The cutscene object that was created
function BoardWorld:startCutscene(group, id, ...)
    if self.cutscene and not self.cutscene.ended then
        local cutscene_name = ""
        if type(group) == "string" then
            cutscene_name = group
            if type(id) == "string" then
                cutscene_name = group.."."..id
            end
        elseif type(group) == "function" then
            cutscene_name = "<function>"
        end
        error("Attempt to start a cutscene "..cutscene_name.." while already in cutscene "..self.cutscene.id)
    end
    if Kristal.Console.is_open then
        Kristal.Console:close()
    end
    self.cutscene = WorldCutscene(self, group, id, ...)
    return self.cutscene
end

--- Stops the current cutscene \
--- An error will be thrown when trying to stop a cutscene if none are active
function BoardWorld:stopCutscene()
    if not self.cutscene then
        error("Attempt to stop a cutscene while none are active.")
    end
    self.cutscene:onEnd()
    coroutine.yield(self.cutscene)
    self.cutscene = nil
end

--- Shows a textbox with the input `text`
---@param text      string|string[]
---@param after?    fun(cutscene: WorldCutscene)    A callback to run when the textbox is closed, receiving the cutscene instance used to display the text
function BoardWorld:showText(text, after)
    if type(text) ~= "table" then
        text = {text}
    end
    self:startCutscene(function(cutscene)
        for _,line in ipairs(text) do
            cutscene:text(line)
        end
        if after then
            after(cutscene)
        end
    end)
end

--- Spawns the player into the world
---@overload fun(self: World, x: number, y: number, chara: string|Actor, party?: string)
---@overload fun(self: World, marker: string, chara: string|Actor, party?: string)
---@param ... unknown   Arguments detailing how the player spawns
---|"x, y, chara"   # The co-ordinates of the player spawn and the Actor (instance or id) to use for the player
---|"marker, chara" # The marker name to spawn the player at and the Actor (instance or id) to use for the player
---@param party? string The party member ID associated with the player

function BoardWorld:spawnPlayer(...)
    local args = {...}
    local x, y = 0, 0
    local chara = "board_kris"
    local party

    if type(chara) == "string" then
        chara = Registry.createActor(chara)
    end

    local facing = "down"

    if #args > 0 then
        if type(args[1]) == "number" then
            x, y = args[1], args[2]
            chara = args[3] or chara
            party = args[4]
        elseif type(args[1]) == "string" then
            x, y = self.map:getMarker(args[1])
            chara = args[2] or chara
            party = args[3]
        end
    end


    if self.player then
        facing = self.player.facing
        self:removeChild(self.player)
    end
    if self.soul then
        self:removeChild(self.soul)
    end

    self.player = BoardPlayer(chara, x, y)
    self.player.world = self
    self.player.layer = self.map.object_layer
    self.player:setFacing(facing)
    self:addChild(self.player)

    --[[if party then
        self.player.party = party
    end

    self.soul = OverworldSoul(self.player:getRelativePos(self.player.actor:getSoulOffset()))
    self.soul:setColor(Game:getSoulColor())
    self.soul.layer = WORLD_LAYERS["soul"]
    self:addChild(self.soul)]]

   --[[ if self.camera.attached_x then
        self.camera:setPosition(self.player.x, self.camera.y)
    end
    if self.camera.attached_y then
        self.camera:setPosition(self.camera.x, self.player.y - (self.player.height * 2)/2)
    end]]
end

function BoardWorld:spawnFollower(...)
    local args = {...}
    local x, y = 0, 0
    local party
    local chara = "board_noelle"

    if type(chara) == "string" then
        chara = Registry.createActor(chara)
    end

    local facing = "down"

    if #args > 0 then
        if type(args[1]) == "number" then
            x, y = args[1], args[2]
            chara = args[3]
            party_slot = args[4]
        end
    end

    local m = self.map.markers["spawn".. party_slot]

    local f = BoardFollower(chara, m.x, m.y, party_slot)
    f.world = self
    f.layer = self.map.object_layer
    f:setFacing(facing)
    self:addChild(f)
    return f
end

--- Gets the `Character` in the world of a party member
---@param party string|PartyMember  The party member to get the character for
---@return Character?
function BoardWorld:getPartyCharacter(party)
    if type(party) == "string" then
        party = Game:getPartyMember(party)
    end
    local char_to_return
    for _,char in ipairs(Game.stage:getObjects(Character)) do
        -- Immediately break the loop and return if we find an explicit party match
        if char.party and char.party.id == party.id then
            return char
        end
        -- Store the first actor match, do not break loop as the match is not explicit
        if char.actor and char.actor.id == party:getActor().id then
            char_to_return = char_to_return or char
        end
    end
    return char_to_return
end

--- Gets the `Follower` or `Player` of a character currently in the party
---@param party string|PartyMember  The party member to get the character for
---@return Player|Follower?
function BoardWorld:getPartyCharacterInParty(party)
    if type(party) == "string" then
        party = Game:getPartyMember(party)
    end
    if self.player and Game:hasPartyMember(self.player:getPartyMember()) and party == self.player:getPartyMember() then
        return self.player
    else
        for _,follower in ipairs(self.followers) do
            if Game:hasPartyMember(follower:getPartyMember()) and party == follower:getPartyMember() then
                return follower
            end
        end
    end
end

--- Removes a follower
---@param chara string|Follower The `Follower` or the follower's actor id to remove
---@return Follower follower The follower that was removed
function BoardWorld:removeFollower(chara)
    local follower_arg = isClass(chara) and chara:includes(Follower)
    for i,follower in ipairs(self.followers) do
        if (follower_arg and follower == chara) or (not follower_arg and follower.actor.id == chara) then
            table.remove(self.followers, i)
            for j,temp in ipairs(Game.temp_followers) do
                if temp == follower.actor.id or (type(temp) == "table" and temp[1] == follower.actor.id) then
                    table.remove(Game.temp_followers, j)
                    break
                end
            end
            return follower
        end
    end
end

--[[
--- Spawns a follower into the world
---@param chara     Follower|string|Actor   The character to spawn as a follower
---@param options?  table                 A table defining additional properties to control the new follower
---|"x"         # The position of the follower
---|"y"         # The position of the follower
---|"index"     # The index of the follower in the list of followers
---|"temp"      # Whether the follower is temporary and disappears when the current map is exited (defaults to `true`)
---|"party"     # The id of the party member associated with this follower
---@return Follower
function BoardWorld:spawnFollower(chara, options)
    if type(chara) == "string" then
        chara = Registry.createActor(chara)
    end
    options = options or {}
    local follower
    if isClass(chara) and chara:includes(Follower) then
        follower = chara
    else
        local x = 0
        local y = 0
        if self.player then
            x = self.player.x
            y = self.player.y
        end
        follower = Follower(chara, x, y)
        follower.layer = self.map.object_layer
        if self.player then
            follower:setFacing(self.player.facing)
        end
    end
    if options["x"] or options["y"] then
        follower:setPosition(options["x"] or follower.x, options["y"] or follower.y)
    end
    if options["index"] then
        table.insert(self.followers, options["index"], follower)
    else
        table.insert(self.followers, follower)
    end
    if options["temp"] == false then
        if options["index"] then
            table.insert(Game.temp_followers, {follower.actor.id, options["index"]})
        else
            table.insert(Game.temp_followers, follower.actor.id)
        end
    end
    if options["party"] then
        follower.party = options["party"]
    end
    self:addChild(follower)
    follower:updateIndex()
    return follower
end
]]

--- Spawns characters in the world for the current party
---@param marker?   string|{x: number, y: number}                               The marker or co-ordinates to spawn the player at
---@param party?    (PartyMember|string)[]                                      A table of party members to spawn (Defaults to [`Game.party`](lua://Game.party))    
---@param extra?    (Follower|Actor|string|[Follower|Actor|string,integer])[]   Additional followers to add that are not in the party (defaults to [`Game.temp_followers`](lua://Game.temp_followers))
---@param facing?   "up"|"down"|"left"|"right"                                  The direction the party should be facing when they spawn
function BoardWorld:spawnParty(marker, party, extra, facing)




        if type(marker) == "table" then
            self:spawnPlayer(marker[1], marker[2], "board_kris")
        else
            self:spawnPlayer(marker or "spawn", "board_kris")
        end

        if Game.party[2] then
            local follower = self:spawnFollower(self.player.x, self.player.y, "board_susie", 2)
            follower:setFacing(facing or self.player.facing)
            
            self.followers[1] = follower
        end

        if Game.party[3] then
            local follower = self:spawnFollower(self.player.x, self.player.y, "board_ralsei", 3)
            follower:setFacing(facing or self.player.facing)
            
            self.followers[2] = follower
        end

    self.ui = BoardUI()
    Game.world:addChild(self.ui)


--[[
    party = party or Game.party or {"kris"}
    if #party > 0 then
        for i,chara in ipairs(party) do
            if type(chara) == "string" then
                party[i] = Game:getPartyMember(chara)
            end
        end
        if facing then
            self.player:setFacing(facing)
        end
        for i = 2, #party do
            local follower = self:spawnFollower(party[i]:getActor(), {party = party[i].id})
            follower:setFacing(facing or self.player.facing)
        end
        for _,actor in ipairs(extra or Game.temp_followers or {}) do
            if type(actor) == "table" then
                local follower = self:spawnFollower(actor[1], {index = actor[2]})
                follower:setFacing(facing or self.player.facing)
            else
                local follower = self:spawnFollower(actor)
                follower:setFacing(facing or self.player.facing)
            end
        end
    end]]
end

--- Spawns a new `WorldBullet` to the world
---@overload fun(self: World, bullet: WorldBullet)
---@param bullet?   string  The bullet to add to the world, if left unspecified, spawns the basic `WorldBullet`
---@param ...       any     Additional arguments to pass to the bullet's init() function
---@return WorldBullet bullet The newly created bullet
function BoardWorld:spawnBullet(bullet, ...)
    ---@diagnostic disable param-type-mismatch
    local new_bullet
    if isClass(bullet) and bullet:includes(WorldBullet) then
        new_bullet = bullet
    elseif Registry.getWorldBullet(bullet) then
        new_bullet = Registry.createWorldBullet(bullet, ...)
    else
        local x, y = ...
        table.remove(arg, 1)
        table.remove(arg, 1)
        new_bullet = WorldBullet(x, y, bullet, unpack(arg))
    end
    new_bullet.layer = WORLD_LAYERS["bullets"]
    new_bullet.world = self
    table.insert(self.bullets, new_bullet)
    if not new_bullet.parent then
        self:addChild(new_bullet)
    end
    return new_bullet
    ---@diagnostic enable param-type-mismatch
end

--- Spawns a new NPC object in the world
---@param actor         string|Actor    The actor to use for the new NPC, either an id string or an actor object
---@param x             number          The x-coordinate to place the NPC at
---@param y             number          The y-coordinate to place the NPC at
---@param properties?   table           A table of additional properties for the new NPC. Supports all the same values as an `npc` map event
---@return NPC npc The newly created npc.
function BoardWorld:spawnNPC(actor, x, y, properties)
    return self:spawnObject(NPC(actor, x, y, properties))
end

--- Spawns an object to the world
---@param obj Object            The object to add to the world
---@param layer? string|number  The layer to place the object on
---@return Object
function BoardWorld:spawnObject(obj, layer)
    obj.layer = self:parseLayer(layer)
    self:addChild(obj)
    return obj
end

--- Gets a specific character currently present in the world
---@param id        string  The actor id of the character to search for
---@param index?    number  The character's index, if they have multiple instances in the world. (Defaults to `1`)
---@return Character|nil chara The character instance, or `nil` if it was not found
function BoardWorld:getCharacter(id, index)
    local party_member = Game:getPartyMember(id)
    local i = 0
    for _,chara in ipairs(Game.stage:getObjects(Character)) do
        if chara.actor.id == id or (party_member and chara.party and chara.party == party_member.id) then
            i = i + 1
            if not index or index == i then
                return chara
            end
        end
    end
end

--- Gets the action box instance for a member of the party
---@param party_member string|PartyMember
---@return OverworldActionBox?
function BoardWorld:getActionBox(party_member)
    if not self.healthbar then return nil end
    if type(party_member) == "string" then
        party_member = Game:getPartyMember(party_member)
    end
    for _,box in ipairs(self.healthbar.action_boxes) do
        if box.chara == party_member then
            return box
        end
    end
    return nil
end

--- Creates a reaction text on a party member's healthbar (usually used for equipment and items)
---@param party_member  string|PartyMember  The party member who will react
---@param text          string              The text to display for the reaction
---@param display_time? number              The display time, in seconds, of the reaction (defaults to 5/3 seconds)
function BoardWorld:partyReact(party_member, text, display_time)
    local action_box = self:getActionBox(party_member)
    if action_box then
        action_box:react(text, display_time)
    end
end

--- Gets a specific event present in the current map
---@param id string|number  The unique numerical id of an event OR the text id of an event type to get the first instance of
---@return Event event The event instnace, or `nil` if it was not found
function BoardWorld:getEvent(id)
    return self.map:getEvent(id)
end

--- Gets a list of all instances of one type of event in the current maps
---@param name? string The text id of the event to search for, fetches every event if `nil`
---@return Event[] events A table containing every instance of the event in the current map
function BoardWorld:getEvents(name)
    return self.map:getEvents(name)
end

--- Disables following for all of the player's current followers
function BoardWorld:detachFollowers()
    for _,follower in ipairs(self.followers) do
        follower.following = false
    end
end

--- Enables following for all of the player's current followers and causes them to walk to their positions
---@param return_speed? number The walking speed of the followers while they return to the player
function BoardWorld:attachFollowers(return_speed)
    for _,follower in ipairs(self.followers) do
        follower:updateIndex()
        follower:returnToFollowing(return_speed)
    end
end
--- Enables following for all of the player's current followers, and immediately teleports them to their positions
function BoardWorld:attachFollowersImmediate()
    for _,follower in ipairs(self.followers) do
        follower.following = true

        follower:updateIndex()
        follower:moveToTarget()
    end
end

--- Parses a variable-type layer specification into a recognised layer
---@param layer?    number|string
---@return number
function BoardWorld:parseLayer(layer)
    return (type(layer) == "number" and layer)
            or WORLD_LAYERS[layer]
            or self.map.layers[layer]
            or self.map.object_layer
end

--- Sets up several variables for a new map
---@param map? Map|string|table The Map object, name, or data to load
---@param ... unknown           Additional arguments that will be passed forward into Map:onEnter()
function BoardWorld:setupMap(map, ...)
    for _,child in ipairs(self.children) do
        if not child.persistent then
            self:removeChild(child)
        end
    end
    for _,child in ipairs(self.controller_parent.children) do
        if not child.persistent then
            self.controller_parent:removeChild(child)
        end
    end

    self:updateChildList()

    self.healthbar = nil
    self.followers = {}

    --self.camera:resetModifiers(true)
    --self.camera:setAttached(true)

    if isClass(map) then
        self.map = map
    elseif type(map) == "string" then
        self.map = Registry.createMap(map, self, ...)
    elseif type(map) == "table" then
        self.map = Map(self, map, ...)
    else
        self.map = Map(self, nil, ...)
    end

    self.map:load()

    local dark_transitioned = self.map.light ~= Game:isLight()

    Game:setLight(self.map.light)

    self.width = self.map.width * self.map.tile_width
    self.height = self.map.height * self.map.tile_height

    --self.camera:setBounds(0, 0, self.map.width * self.map.tile_width, self.map.height * self.map.tile_height)

    self.battle_fader = Rectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.battle_fader:setParallax(0, 0)
    self.battle_fader:setColor(0, 0, 0)
    self.battle_fader.alpha = 0
    self.battle_fader.layer = self.map.battle_fader_layer
    self.battle_fader.debug_select = false
    self:addChild(self.battle_fader)

    self.in_battle = false
    self.in_battle_area = false
    self.battle_alpha = 0

    local map_border = self.map:getBorder(dark_transitioned)
    if map_border then
        Game:setBorder(Kristal.callEvent(KRISTAL_EVENT.onMapBorder, self.map, map_border) or map_border)
    end

    if not self.map.keep_music then
        self:transitionMusic(Kristal.callEvent(KRISTAL_EVENT.onMapMusic, self.map, self.map.music) or self.map.music)
    end
end

--- Loads into a new map file.
---@overload fun(self: World, map: string, x: number, y: number, facing?: string, callback?: string, ...: any)
---@overload fun(self: World, map: string, marker?: string, facing?: string, callback?: string, ...: any)
---@param map       string      The name of the map file to load
---@param x         number      The x-coordinate the player will spawn at in the new map
---@param y         number      The y-coordinate the player will spawn at in the new map
---@param marker?   string      The name of the marker the player will spawn at in the new map (Defaults to `"spawn"`)
---@param facing?   string      The direction the party should be facing when they spawn in the new map
---@param callback? fun()       A callback to run once the map has finished loading (Post Map:onEnter())
---@param ... unknown           Additional arguments that will be passed forward into Map:onEnter()
function BoardWorld:loadMap(...)
    local args = {...}
    -- x, y, facing, callback
    local map = table.remove(args, 1)
    local marker, x, y, facing, callback
    if type(args[1]) == "string" then
        marker = table.remove(args, 1)
    elseif type(args[1]) == "number" then
        x = table.remove(args, 1)
        y = table.remove(args, 1)
    else
        marker = "spawn"
    end
    if args[1] then
        facing = table.remove(args, 1)
    end
    if args[1] then
        callback = table.remove(args, 1)
    end

    if self.map then
        self.map:onExit()
    end

    -- MB Easter Egg
    if self.shouldMb and self:shouldMb(map) then
        -- TODO: Move these out of the Kristal table because that's stupid and it should've never been like that
        Kristal.mb_map_dest = map
        Kristal.mb_marker_dest = marker or {x, y}
        Kristal.mb_facing_dest = facing
        Kristal.mb_callback_dest = callback
        map = "​"
        marker = "spawn"
        x, y = nil, nil
        facing = nil
        callback = nil
    end

    self:setupMap(map, unpack(args))

    if self.map.markers["spawn"] then
        local spawn = self.map.markers["spawn"]
        --self.camera:setPosition(spawn.center_x, spawn.center_y)
    end

    if marker then
        self:spawnParty(marker, nil, nil, facing)
    else
        self:spawnParty({x, y}, nil, nil, facing)
    end

    self:setState("GAMEPLAY")

    for _,event in ipairs(self.map.events) do
        if event.postLoad then
            event:postLoad()
        end
    end

    self.map:onEnter()

    if callback then
        callback(self.map)
    end
end

--- Transitions the music from the current track to the `next`
---@overload fun(self: World, music: string)
---@param music     string                                              The name of the file to play next
---@param next      {music?: string, volume?: number, pitch?: number}   The filename, volume, and pitch of the next track
---@param fade_out? boolean                                             Whether to fade out the currently playing track before playing the next track
function BoardWorld:transitionMusic(next, fade_out)
    Game.world:transitionMusic(next, fade_out)
end

--[[
    Possible argument formats:
        - Target table
            e.g. ({map = "mapid", marker = "markerid", facing = "down"})
        - Map id, [ spawn X, spawn Y, [facing] ]
            e.g. ("mapid")
                 ("mapid", 20, 5)
                 ("mapid", 30, 40, "down")
        - Map id, [ marker, [facing] ]
            e.g. ("mapid", "markerid")
                 ("mapid", "markerid", "up")
]]
local function parseTransitionTargetArgs(...)
    local args = {...}
    if #args == 0 then return {} end
    if type(args[1]) ~= "table" or isClass(args[1]) then
        local target = {map = args[1]}
        if type(args[2]) == "number" and type(args[3]) == "number" then
            target.x = args[2]
            target.y = args[3]
            if type(args[4]) == "string" then
                target.facing = args[4]
            end
        elseif type(args[2]) == "string" then
            target.marker = args[2]
            if type(args[3]) == "string" then
                target.facing = args[3]
            end
        end
        return target
    else
        return args[1]
    end
end

--- Transitions from the world into a shop
---@param shop      string|Shop The shop to enter
---@param options?  table       An optional table of [`leave_options`](lua://Shop.leave_options) for exiting the shop
function BoardWorld:shopTransition(shop, options)
    self:fadeInto(function()
        Game:enterShop(shop, options)
    end)
end

--- Loads a new map and starts the transition effects for world music, borders, and the screen as a whole
---@overload fun(self: World, map: string, ...: any)
---@param ... any   Additional arguments that will be passed into BoardWorld:loadMap()
---@see World - BoardWorld:loadMap() 
function BoardWorld:mapTransition(...)
    local args = {...}
    local map = args[1]
    if type(map) == "string" then
        local map = Registry.createMap(map)
        if not map.keep_music then
            self:transitionMusic(Kristal.callEvent(KRISTAL_EVENT.onMapMusic, self.map, self.map.music) or map.music, true)
        end
        local dark_transition = map.light ~= Game:isLight()
        local map_border = map:getBorder(dark_transition)
        if map_border then
            Game:setBorder(Kristal.callEvent(KRISTAL_EVENT.onMapBorder, self.map, map_border) or map_border, 1)
        end
    end
    self:fadeInto(function()
        self:loadMap(Utils.unpack(args))
    end)
end

--- Fades the world out and into another piece of content
---@param callback fun()    The callback that is run in the middle of the fade (fully faded out) to load the next piece of content
function BoardWorld:fadeInto(callback)
    self:setState("FADING")
    Game.fader:transition(callback)
end

--- Gets the object that the camera is currently targetting
---@return Object|nil
function BoardWorld:getCameraTarget()
    if self.camera.target and self.camera.target.stage then
        return self.camera.target
    else
        return self.player
    end
end

--- Sets the object the camera should target
---@param target Object?
function BoardWorld:setCameraTarget(target)
    self.camera.target = target
end

--- Sets whether the camera should be attached to its target for each axis
---@param attached_x? boolean   Whether the camera's x-axis position should follow its target
---@param attached_y? boolean   Whether the camera's y-axis position should follow its target
function BoardWorld:setCameraAttached(attached_x, attached_y)
    self.camera:setAttached(attached_x, attached_y)
end

--- Sets whether the camera should follow its target on the x-axis
---@param attached? boolean
function BoardWorld:setCameraAttachedX(attached) self:setCameraAttached(attached, self.camera.attached_x) end
--- Sets whether the camera should follow its target on the y-axis
---@param attached? boolean
function BoardWorld:setCameraAttachedY(attached) self:setCameraAttached(self.camera.attached_y, attached) end

---@param x? number
---@param y? number
---@param friction? number
function BoardWorld:shakeCamera(x, y, friction)
    self.camera:shake(x, y, friction)
end

function BoardWorld:sortChildren()
    Utils.pushPerformance("World#sortChildren")
    Object.startCache()
    local positions = {}
    for _,child in ipairs(self.children) do
        local x, y = child:getSortPosition()
        positions[child] = {x = x, y = y}
    end
    table.stable_sort(self.children, function(a, b)
        local a_pos, b_pos = positions[a], positions[b]
        local ax, ay = a_pos.x, a_pos.y
        local bx, by = b_pos.x, b_pos.y
        -- Sort children by Y position, or by follower index if it's a follower/player (so the player is always on top)
        return a.layer < b.layer or
              (a.layer == b.layer and (math.floor(ay) < math.floor(by) or
              (math.floor(ay) == math.floor(by) and (b == self.player or
              (a:includes(Follower) and b:includes(Follower) and b.index < a.index)))))
    end)
    Object.endCache()
    Utils.popPerformance()
end

---@param parent Object
function BoardWorld:onRemove(parent)
    super.onRemove(self, parent)
    Game.world.board = nil
end

--- Sets whether the player is currently in battle - cannot override being inside a battle area
---@param value boolean
function BoardWorld:setBattle(value)
    self.in_battle = value
end

--- Whether the player is currently in a world battle
---@return boolean
function BoardWorld:inBattle()
    return self.in_battle or self.in_battle_area
end

function BoardWorld:update()
    if self.state == "GAMEPLAY" then
        -- Object collision
        local collided = {}
        local exited = {}
        Object.startCache()
        for _,obj in ipairs(self.children) do
            if not obj.solid and (obj.onCollide or obj.onEnter or obj.onExit) then
                for _,char in ipairs(self.stage:getObjects(Character)) do
                    if obj:collidesWith(char) then
                        if not obj:includes(OverworldSoul) then
                            table.insert(collided, {obj, char})
                        end
                    elseif obj.current_colliding and obj.current_colliding[char] then
                        table.insert(exited, {obj, char})
                    end
                end
            end
        end
        Object.endCache()
        for _,v in ipairs(collided) do
            if v[1].onCollide then
                v[1]:onCollide(v[2], DT)
            end
            if not v[1].current_colliding then
                v[1].current_colliding = {}
            end
            if not v[1].current_colliding[v[2]] then
                if v[1].onEnter then
                    v[1]:onEnter(v[2])
                end
                v[1].current_colliding[v[2]] = true
            end
        end
        for _,v in ipairs(exited) do
            if v[1].onExit then
                v[1]:onExit(v[2])
            end
            v[1].current_colliding[v[2]] = nil
        end
    end

    if self:inBattle() then
        self.battle_alpha = math.min(self.battle_alpha + (0.08 * DTMULT), 1)
    else
        self.battle_alpha = math.max(self.battle_alpha - (0.08 * DTMULT), 0)
    end

    local half_alpha = self.battle_alpha * 0.52

    for _,v in ipairs(self.followers) do
        v.sprite:setColor(1 - half_alpha, 1 - half_alpha, 1 - half_alpha, 1)
    end

    for _,battle_border in ipairs(self.map.battle_borders) do
        battle_border.alpha = self.battle_alpha
    end
    if self.battle_fader then
        self.battle_fader:setColor(0, 0, 0, half_alpha)
    end

    if (self.door_delay > 0) then
        self.door_delay = math.max(self.door_delay - DT, 0)
    end

    self.map:update()

    -- Always sort
    self.update_child_list = true
    super.update(self)

    -- Update cutscene after updating objects
    if self.cutscene then
        if not self.cutscene.ended then
            self.cutscene:update()
            if self.stage == nil then
                return
            end
        else
            self.cutscene = nil
        end
    end
    if self.player then
        self:cameraUpdate()
    end
end

function BoardWorld:fullDraw(...)
    self.main_canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    super.fullDraw(self)
    Draw.popCanvas(true)
    Draw.setColor(1, 1, 1)
	local crt_canvas = Draw.pushCanvas(self.screen_width, self.screen_height)
    Draw.drawCanvas(self.main_canvas)
	local drawgray = true
	if self:isTextboxOpen() then
		drawgray = false
	end
	if drawgray then
		for _, region in ipairs(self.stage:getObjects(BoardGrayRegion)) do
			if region and not region:isRemoved() then
				local regionx, regiony = region:getScreenPos(0, 0)
				Draw.pushScissor()
				Draw.scissor(regionx, regiony, region.width, region.height)
				self.grayshader:send("sand1", {255, 236, 189})
				self.grayshader:send("sand2", {255, 215, 140})
				self.grayshader:send("sand3", {151, 183, 255})
				self.grayshader:send("sand4", {177, 193, 227})
				self.grayshader:sendColor("sandcol", {0.82, 0.82, 0.82})
				local last_shader = love.graphics.getShader()
				love.graphics.setShader(self.grayshader)
				Draw.drawCanvas(self.main_canvas)
				love.graphics.setShader(last_shader)
				Draw.popScissor()
			end
		end
	end
    Draw.popCanvas(true)
	self.crttimer = (self.crttimer + 0.5 * DTMULT) % 3
	local vig = self.crt_glitch > 0 and (0.2 + MathUtils.random(MathUtils.clamp(self.crt_glitch / 200, 0, 0.1))) or 0.2
	local vigint = math.pow(1.5, 1.5 - vig) * 18
	local chrom_scale = self.crt_glitch > 0 and (MathUtils.randomInt(-4, 4) * MathUtils.clamp(self.crt_glitch / 5, 1, 5)) or self.chromstrength
	if chrom_scale == 0 then
		chrom_scale = 1
	end
	local filteramount = 0.1 + math.min(self.crt_glitch / 100, 0.1)
	self.crtshader:send("vignette_scale", vig)
	self.crtshader:send("vignette_intensity", vigint)
	self.crtshader:send("chromatic_scale", chrom_scale)
	self.crtshader:send("filter_amount", filteramount)
	self.crtshader:send("time", self.crttimer)
	self.crtshader:send("texsize", {1/self.screen_width, 1/self.screen_height})
	local last_shader = love.graphics.getShader()
	love.graphics.setShader(self.crtshader)
    Draw.drawCanvas(crt_canvas, self.off_x, self.off_y)
	love.graphics.setShader(last_shader)
end

function BoardWorld:draw()
    -- Draw background
    Draw.setColor(self.map.bg_color or {0, 0, 0, 0})
    love.graphics.rectangle("fill", 0, 0, self.map.width * self.map.tile_width, self.map.height * self.map.tile_height)
    Draw.setColor(1, 1, 1)

    super.draw(self)

    self.map:draw()
	
    if DEBUG_RENDER then
        for _,collision in ipairs(self.map.collision) do
            collision:draw(0, 0, 1, 0.5)
        end
        for _,collision in ipairs(self.map.enemy_collision) do
            collision:draw(0, 1, 1, 0.5)
        end
    end
end

function BoardWorld:cameraUpdate() -- this whole thing scares me
	local target = self.player
	if self.targets_can_update_cam then
		target = self:getCameraTarget()
	end
    if target then
        local px = target.x
        local py = target.y
        local grid_w = 192 * 2
        local grid_h = 256

        local xa = math.floor((px + 15) / grid_w) * grid_w + 192
        local ya = math.floor((py + 8) / grid_h) * grid_h + 176

        local xb = math.floor((px - 15) / grid_w) * grid_w + 192
        local yb = math.floor((py - 24) / grid_h) * grid_h + 176
        
        local x1,y1,x2,y2 = self:getAreaBounds()

        if not self.swapping_grid and not Game.lock_movement then
            local x = math.floor(px / grid_w) * grid_w + 192
            local y = math.floor(py / grid_h) * grid_h + 176
            if px < x1 then
                self:shiftGrid("left")
            elseif px > x2 then
                self:shiftGrid("right")
            elseif py < y1 then
                self:shiftGrid("up")
            elseif py > y2 then
                self:shiftGrid("down")
            end
            --self.swapping_grid = true
            --Game.lock_movement = true
        end
    end
end

---@param direction facing
function BoardWorld:shiftGrid(direction, after)
    Game.lock_movement = true
    local x, y = self.area_column, self.area_row
    if direction == "up" then
        y = y - 1
    elseif direction == "down" then
        y = y + 1
    elseif direction == "right" then
        x = x + 1
    elseif direction == "left" then
        x = x - 1
    end
    local cx, cy = self:getAreaCenter(x, y)
	local xx, yy = self:getAreaPosition(x, y)
	local c, r = self:getArea(xx, yy)
	local x1, y1, x2, y2 = self:getAreaBounds(c,r)
    if direction == "up" then
		self.timer:tween(0.5, self:getCameraTarget(), {y = y2})
    elseif direction == "down" then
		self.timer:tween(0.5, self:getCameraTarget(), {y = y1})
    elseif direction == "right" then
		self.timer:tween(0.5, self:getCameraTarget(), {x = x1})
    elseif direction == "left" then
		self.timer:tween(0.5, self:getCameraTarget(), {x = x2})
    end
	self.future_area_column, self.future_area_row = x, y
	self.swapping_grid = true
	self.camera:panTo(cx, cy, 0.5, "linear", function ()
        if after and after(self) then return end
        Game.lock_movement = false
		self.swapping_grid = false
		self.player.cambuff = 2
        self.area_column, self.area_row = x, y
        if direction == "up" then
            self:snapPlayer("bottom", self:getAreaPosition(x, y))
        elseif direction == "down" then
            self:snapPlayer("top", self:getAreaPosition(x, y))
        elseif direction == "right" then
            self:snapPlayer("left", self:getAreaPosition(x, y))
        elseif direction == "left" then
            self:snapPlayer("right", self:getAreaPosition(x, y))
        end
    end)
end

function BoardWorld:swap_grid(x, y)
    local cx, cy = self:getArea(x, y)
    self:moveCamera(cx, cy)
end

---@param x integer
---@param y integer
function BoardWorld:moveCamera(x, y) --Faking the camera again
    local cam_x = (x + 0.5) * self.screen_width
    local cam_y = (y + 0.5) * self.screen_height
    self.camera.x = cam_x
    self.camera.y = cam_y
    self.area_column, self.area_row = x, y
	self.future_area_column, self.future_area_row = x, y
end

---@param x integer
---@param y integer
---@return number, number
function BoardWorld:getAreaCenter(x,y)
    return (x + 0.5) * self.screen_width,
           (y + 0.5) * self.screen_height
end

function BoardWorld:getArea(x, y)
    local w = 192 * 2
    local h = 256

    local col = math.floor(x / w)
    local row = math.floor(y / h)
    return col, row
end

function BoardWorld:snapPlayer(dir, x, y)
    local c, r = self:getArea(x, y)
    local x1, y1, x2, y2 = self:getAreaBounds(c,r)
	local target = self.player
	if self.targets_can_update_cam then
		target = self:getCameraTarget()
	end
    if dir == "left" then
        target.x = x1
    elseif dir == "right" then
        target.x = x2
    elseif dir == "top" then
        target.y = y1
    elseif dir == "bottom" then
        target.y = y2
    end

    for _, i in ipairs(self.followers) do
        i.history = {}
        i.physics.move_path = nil
        i.pathing = false
        i.x = self.player.x
        i.y = self.player.y
    end
end

---@param x integer Row of area to get bounds of
---@param y integer Column of area to get bounds of
---@return number, number, number, number
---@overload fun(self:self): number, number, number, number
function BoardWorld:getAreaBounds(x, y)
    if not x then
        x, y = self.area_column, self.area_row
    end
    local x1, y1 = self:getAreaPosition(x, y)
    local x2, y2 = self:getAreaPosition(x + 1, y + 1)
    local px = 8
    x1, y1 = x1 + 16, y1 + 32
    x2, y2 = x2 - 16, y2 - 0
    return x1,y1,x2,y2
end

---@param x integer Row of area to get bounds of
---@param y integer Column of area to get bounds of
---@return number, number
function BoardWorld:getAreaPosition(x, y)
    if not x then
        x, y = self.area_column, self.area_row
    end
    assert(x == math.floor(x), "Non-integer x value passed: "..x)
    assert(y == math.floor(y), "Non-integer y value passed: "..y)
    return x * self.camera.width, y * self.camera.height
end

function BoardWorld:canDeepCopy()
    return false
end

function BoardWorld:setScore(score)
    self.ui:setScore(score)
end

function BoardWorld:drawMask()
    love.graphics.origin()
    love.graphics.rectangle("fill",self.x,self.y,self.screen_width,self.screen_height)
end

--- Returns the nearest valid pathfinding node, based on the map's `node_size`.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @return table<number> node_pos 2D Vector of node pos. Nil if no valid nodes are within a 1 node radius of this position.
function BoardWorld:getNearestNode(x, y)
    local node_size = self:getPathfinderNodeSize()

    return { Utils.round(x/node_size), Utils.round(y/node_size) }
end

--- Returns the nearest valid pathfinding node, based on the map's `node_size`.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @param collider Collider|nil Hitbox to check collision with.
--- @param range number A range of nodes to search within. Defaults to 1.
--- @return table<number>|nil node_pos 2D Vector of node pos. Nil if no valid nodes are within a 1 node radius of this position.
function BoardWorld:getNearestValidNode(x, y, collider, range)
    local node = self:getNearestNode(x, y)

    if (self:nodeIsValid(node[1], node[2], collider)) then
        return node
    elseif (collider and collider) then
        local current = nil
        local score = 999
        local get_score = function (score_x, score_y) return math.abs(score_x) + math.abs(score_y) end
        for off_x = -range, range, 1 do
            for off_y = -range, range, 1 do
                if (not (off_x == 0 and  off_y == 0)) then
                    local new_node = { node[1] + off_x, node[2] + off_y }
                    local valid = self:nodeIsValid(new_node[1], new_node[2], collider)
                    local new_score = get_score(off_x, off_y)
                    if (valid and (new_score < score)) then
                        current = new_node
                        score = new_score
                        if (score == 1) then return current end
                    end
                end
            end
        end
        return current
    end

    -- for off_x = -1, 1, 1 do
    --         for off_y = -1, 1, 1 do
    --             if (not (off_x == 0 and  off_y == 0) and math.abs(off_x) ~= math.abs(off_y)) then
    --                 local new_node = { node[1] + off_x, node[2] + off_y }
    --                 local valid = self:nodeIsValid(new_node[1], new_node[2], ref_collider)
    --                 if (valid) then
    --                     return new_node
    --                 end
    --             end
    --         end
    --     end
    
    return nil
end

---@param x number
---@param y number
---@param collider Collider
---@return number original_x
---@return number original_y
function BoardWorld:centerOnNode(x, y, collider)
    local world_pos = self:nodePosToWorld(x, y)

    local original_offset_x = collider.x
    local original_offset_y = collider.y
    local relative_pos_x, relative_pos_y = self:getRelativePos(world_pos[1], world_pos[2], collider.parent)
    collider.x = relative_pos_x - (original_offset_x / 2)
    collider.y = relative_pos_y - (original_offset_y / 2)
    return original_offset_x, original_offset_y
end

---@param x number
---@param y number
---@param collider Collider
function BoardWorld:nodeIsValid(x, y, collider)
    if (collider) then
        local og_x, og_y = self:centerOnNode(x, y, collider)
        local collided = self:checkCollision(collider, false) or not self:inBounds(self:nodePosToWorld(x, y))
        collider.x = og_x
        collider.y = og_y
        return not collided
    end
    return true
end

---@param x number
---@param y number
---@return table<number> world_pos
---@overload fun(x: table<number>): table<number>
function BoardWorld:nodePosToWorld(x, y)
    if (type(x) == "table") then
        y = x[2]
        x = x[1]
    end
    local node_size = self:getPathfinderNodeSize()
    return { x * node_size, y * node_size }
end

---@return number size
function BoardWorld:getPathfinderNodeSize()
    return self.map and self.map.pathfinder_node_size or Pathfinder:getConfig("default_node_size") or 40
end

---@overload fun(x: table<number>): boolean
function BoardWorld:inBounds(x, y)
    if (type(x) == "table") then
        y = x[2]
        x = x[1]
    end
    return x <= (self.map.width * self.map.tile_width) and x >= 0 and y <= (self.map.height * self.map.tile_height) and y >= 0
end

---Takes in two Node positions and finds a valid path between them. Uses the A* pathfinding algorithm.
---@param x number
---@param y number
---@param target_x number
---@param target_y number
---@param collider Collider
---@return table path
function BoardWorld:findPathTo(x, y, target_x, target_y, collider)

    local path = Luafinding(Vector(x, y), Vector(target_x, target_y), function (pos) return self:nodeIsValid(pos.x, pos.y, collider) end):GetPath() or {}
    if #path == 0 then Kristal.Console:log("But it was empty...") end
    local world_path = {}

    for index, value in ipairs(path) do
        local world_pos = self:nodePosToWorld(value.x, value.y)
        table.insert(world_path, world_pos)
    end

    return world_path


    -- local path = {}
    -- if (x == target_x and y == target_y) then return path end

    -- local compose = function (vec_x, vec_y)
    --     return tostring(vec_x)..","..tostring(vec_y)
    -- end

    -- local decompose = function (vecstring)
    --     local split = Utils.splitFast(vecstring, ",")
    --     return { tonumber(split[1]), tonumber(split[2]) }
    -- end

    -- local came_from = {}
    -- came_from[compose(x, y)] = compose(x, y)
    -- local frontier = PriorityQueue()
    -- frontier:put( {x, y}, 0 )
    -- local cost_so_far = {}
    -- cost_so_far[compose(x, y)] = 0

    -- local heuristic = function (current_x, current_y)
    --     return math.abs(target_x - current_x) + math.abs(target_y - current_y)
    -- end
    -- -- todo: maybe implement this if its worthwhile
    -- local movement_cost = function (node_x, node_y, next_x, next_y)
    --     --return math.abs(Utils.dist(node_x, node_y, next_x, next_y))
    -- end
    
    -- local max_nodes_searched = 100
    -- local nodes_counted = 0
    
    -- while (not frontier:empty()) and not (nodes_counted >= max_nodes_searched) do
    --     local current = frontier:popLeast()
    --     if (current[1] == target_x and current[2] == target_y) then
    --         break
    --     end
    --     local neighbors = self:getValidNeighbors(current[1], current[2], collider)
    --     if (#neighbors > 0) then
    --         for index, value in ipairs(neighbors) do
    --             local new_cost = (cost_so_far[compose(current[1], current[2])] or 1) + 1 -- movement_cost(current[1][1], current[1][2])
    --             if (not cost_so_far[compose(value[1], value[2])]) then --or new_cost < cost_so_far[compose(value[1], value[2])]) then
    --                 local priority = new_cost + heuristic(value[1], value[2])
    --                 frontier:put (value, priority)
    --                 came_from[compose(value[1], value[2])] = compose(current[1], current[2])
    --             end
    --         end
    --     end
    --     nodes_counted = nodes_counted + 1
    -- end

    -- if (not came_from[compose(target_x, target_y)]) then 
    --     Kristal.Console:log("Pathfinding failure, target not in final path...")
    --     return path
    -- end
    -- local current = {target_x, target_y}
    
    -- while ((current[1] ~= x and current[2] ~= y)) do
    --     local node = decompose(came_from[compose(current[1], current[2])])
    --     current = node
    --     table.insert(path, #path + 1, self:nodePosToWorld(node))
    -- end
    -- return Utils.reverse(path)

end


--- Returns all allowed pathfinding node neighbors.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @return table node_positions
function BoardWorld:getNeighbors(x, y)
    local node = {x, y}
    local neighbors = {}

    for off_x = -1, 1, 1 do
        for off_y = -1, 1, 1 do
            if (not (off_x == 0 and  off_y == 0)) then
                local new_node = { node[1] + off_x, node[2] + off_y }
                table.insert(neighbors, new_node)
            end
        end
    end
    
    
    return neighbors
end

--- Returns all valid pathfinding node neighbors.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @param collider Collider|nil Hitbox to check collision with.
--- @param range number A range of nodes to search within. Defaults to 1.
--- @return table node_positions
function BoardWorld:getValidNeighbors(x, y, collider, range)
    local node = {x, y}
    local neighbors = {}
    if not range then range = 1 end

    for off_x = -range, range, 1 do
        for off_y = -range, range, 1 do
            if (not (off_x == 0 and  off_y == 0)) then
                local new_node = { node[1] + off_x, node[2] + off_y }
                local valid = self:nodeIsValid(new_node[1], new_node[2], collider)
                if (valid) then
                    table.insert(neighbors, new_node)
                end
            end
        end
    end
    
    
    return neighbors
end

return BoardWorld