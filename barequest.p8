pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-->8
-- object
-- https://github.com/eevee/klinklang/blob/23c5715bda87f3c787e1c5fe78f30443c7bf3f56/object.lua (modified)

_object = {}
_object.__index = _object


-- constructor
function _object:__call(...)
  local this = setmetatable({}, self)
  return this, this:init(...)
end


-- methods
function _object:init() end
function _object:update() end
function _object:draw() end


-- subclassing
function _object:extend()
  proto = {}

  -- copy meta values, since lua
  -- doesn't walk the prototype
  -- chain to find them
  for k, v in pairs(self) do
    if sub(k, 1, 2) == "__" then
      proto[k] = v
    end
  end

  proto.__index = proto
  proto.__super = self

  return setmetatable(proto, self)
end


-->8
-- state machine

function _method(h, k)
  return h[k] and h[k](h)
end

function _machine()
  local stack = {}

  function fire_up(ev)
    foreach(stack, function(h) _method(h, ev) end)
  end

  function fire_down(ev)
    for i=#stack, 1, -1 do
      if _method(stack[i], ev) then
        break
      end
    end
  end

  return {
    fire_up = fire_up,
    fire_down = fire_down,
    update = function() fire_down('update') end,
    draw = function() fire_up('draw') end,
    pop = function() stack[#stack] = nil end,
    push = function(k) add(stack, k) end,
  }
end

-->8
-- thick print

function tprint(text, x, y, ic, oc)
  for ox=-1, 1 do
    for oy=-1, 1 do
      print(text, x + ox, y + oy, oc)
    end
  end

  print(text, x, y, ic)
end

-->8
-- colors
c_black=0
c_darkblue=1
c_darkpurple=2
c_darkgreen=3
c_brown=4
c_darkgrey=5
c_lightgrey=6
c_white=7
c_red=8
c_orange=9
c_yellow=10
c_green=11
c_blue=12
c_indigo=13
c_pink=14
c_peach=15


-->8
-- buttons
b_left = 0
b_right = 1
b_up = 2
b_down = 3
b_o = 4
b_x = 5
b_pause = 6

-->8
-- animations
_anim = _object:extend()

function _anim:init(frames)
  self.step = 0
  self.cur = 1
  self.frames = frames
end

function _anim:next()
  self.cur += 1
  if self.cur == #self.frames + 1 then
    self.cur = 1
  end

  return self.frames[self.cur]
end

function _anim:update()
  self.step += 1
  if (self.step % 3) == 0 then
    self:next()
  end

  return self.frames[self.cur]
end

function _anim:frame()
  return self.frames[self.cur]
end

function _anim:copy()
  return _anim(self.frames)
end


-->8
-- sprites
_sprite = _object:extend()

function _sprite:init(anims, palette)
  self.anims = anims
  self.palette = palette
  self.x = 0
  self.y = 0
end

function _sprite:draw()
  pal()
  if self.palette then
    self:palette()
  end

  spr(self.tile, self.x, self.y)
end

function _sprite:update()
  if self.anim then
    self.tile = self.anim:update()
  end
end

function _sprite:set_anim(to)
  self.anim = self.anims[to]
  if type(self.anim) == "number" then
    self.tile = self.anim
    self.anim = nil
  end
end

hero_anims = {
  idle_down = 1,
  idle_up = 17,
  idle_right = 33,
  idle_left = 49,
  walk_down = _anim({1, 2, 1, 3}),
  walk_up = 17,
  walk_right = 33,
  walk_left = 49,
}

function world()
  local camera_x, camera_y = 0, 0
  local hero = _sprite(hero_anims, function() palt(c_black, false) palt(c_red, true) end)
  hero.x = 60
  hero.y = 60
  hero:set_anim("walk_down")
  hero.dir = "down"

  return {
    update = function()
      if btn(b_left) then
        hero.x -= 1
        hero:set_anim("walk_left")
        hero.dir = "left"
      elseif btn(b_right) then
        hero.x += 1
        hero:set_anim("walk_right")
        hero.dir = "right"
      elseif btn(b_up) then
        hero.y -= 1
        hero:set_anim("walk_up")
        hero.dir = "up"
      elseif btn(b_down) then
        hero.y += 1
        hero:set_anim("walk_down")
        hero.dir = "down"
      else
        hero:set_anim("idle_" .. hero.dir)
      end

      if btnp(4) or btnp(5) then
        game.push(menu())
      end

      hero:update()
    end,

    draw = function()
      cls()
      pal()

      camera_x, camera_y = max(0, min(hero.x - 60, 897)), max(0, min(hero.y - 60, 385))
      camera(camera_x, camera_y)
      map(0, 0, 0, 0, 128, 64)
      tprint(stat(7), camera_x + 1, camera_y + 1, c_white, c_black)

      hero:draw()
    end,
  }
end

function menu()
  return {
    draw = function()
      rectfill(8, 8, 120, 120, c_lightgrey)
      rectfill(9, 9, 119, 119, c_darkblue)
    end,

    update = function()
      if btnp(4) or btnp(5) then
        game:pop()
      end
      return true
    end,
  }
end

game = _machine()
game.push(world())

function _draw() game.draw() end
function _update() game.update() end
__gfx__
00000000888888888998899889988998000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000899889988944449889444498000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700894444988440404884404048000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000844040488444444884444448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000844444481822228888222281000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700882222888842948118429488000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000184294818888848888488888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884884888888888888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000844884480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000844444480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000844444480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000844444480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000882222880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000184424810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884884880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000889988880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000889444880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884404880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884444880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000882222880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000882491880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888488880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888899880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884449880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884044880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000884444880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000882222880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000881942880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888848880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333388333333e33333333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333333333333b833333eae3333b33333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333b33333333e333333333b3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333b33333333b33333333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333333b333333333b3333b333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333333b333333333b3333333b333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404043404040404040404240404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404140404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
