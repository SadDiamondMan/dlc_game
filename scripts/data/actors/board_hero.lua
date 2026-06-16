local actor, super = Class(Actor, "board_hero")


function actor:onSpriteInit(sprite)
    sprite.alpha = 0
end


function actor:onWorldDraw(chara)
    if self.sheet then

        local a = chara.sprite.sprite_options[1]
        local b = self.sheet[a]

        if not b then return end

        local x, y = b[1] * 16, b[2] * 16
        local s = self.sprite_sheet

        local quad = Assets.getQuad(x, y, 16, 16, 64, 64)
        love.graphics.draw(s, quad, 0, 0)
    end
end


function actor:init()
    super.init(self)
    self.name = "Hero"

    self.width = 16
    self.height = 16
    self.hitbox = {0.2, 8.2, 15.4, 7.4}
    self.soul_offset = {8, 16}
    self.path = "sword/party/kris"
    self.default = "walk"
    self.voice = nil
    self.portrait_path = nil
    self.portrait_offset = nil
    self.can_blush = false

    self.animations = {
    }
    self.mirror_sprites = {
        ["walk/down"] = "walk/up",
        ["walk/up"] = "walk/down",
        ["walk/left"] = "walk/left",
        ["walk/right"] = "walk/right",
    }
    self.offsets = {
        ["walk/left"] = {0, 0},
        ["walk/right"] = {0, 0},
        ["walk/up"] = {0, 0},
        ["walk/down"] = {0, 0},

        ["item"] = {-1, 0},
    }

    self.health = 90
    self.healthMax = 90
    self.color = {1, 0.5, 0}
    self.health_color = {1, 0.5, 0}

    self.sprite_sheet = Assets.getTexture("sword/party/hero/sprite_sheet")

    self.sheet = {
        ["walk/down_1"] = {0, 0},
        ["walk/down_2"] = {0, 1},

        ["walk/left_1"] = {1, 0},
        ["walk/left_2"] = {1, 1},

        ["walk/up_1"] = {2, 0},
        ["walk/up_2"] = {2, 1},

        ["walk/right_1"] = {3, 0},
        ["walk/right_2"] = {3, 1},
    }

end

return actor