pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- enums

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

-- darkened colors
drk = {
  [0]=0, -- black      -> black
  0,     -- darkblue   -> black
  1,     -- darkpurple -> darkblue
  1,     -- darkgreen  -> darkblue
  2,     -- brown      -> darkpurple
  1,     -- darkgrey   -> darkblue
  5,     -- lightgrey  -> darkgrey
  6,     -- white      -> lightgrey
  2,     -- red        -> darkpurple
  4,     -- orange     -> brown
  9,     -- yellow     -> orange
  3,     -- green      -> darkgreen
  1,     -- blue       -> darkblue
  1,     -- indigo     -> darkblue
  2,     -- pink       -> darkpurple
  5,     -- peach      -> darkgrey
}

-- buttons
b_left = 0
b_right = 1
b_up = 2
b_down = 3
b_o = 4
b_x = 5
b_pause = 6


-- sprite flags
flag_collision = 0
flag_portal = 1

-- memory locs

screen = 0x6000
shading_base = 0x4300




-->8
-- systems

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

function _method(h, k)
  return h[k] and h[k](h)
end

function _machine()
  local stack = {}

  function fire_up(ev)
    for i=1, #stack do
      _method(stack[i], ev)
    end
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
-- helpers
function flr8(v)
  return flr(v / 8)
end

function check_flag(x, y, flag)
  local cell_n = mget(flr8(x), flr8(y))
  return fget(cell_n, flag)
end

function check_collision(x, y)
  return check_flag(x, y, flag_collision)
end

function tprint(text, x, y, ic, oc)
  for ox=-1, 1 do
    for oy=-1, 1 do
      print(text, x + ox, y + oy, oc)
    end
  end

  print(text, x, y, ic)
end

-->8
-- entities

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

-- sprites
_sprite = _object:extend()

function _sprite:init(anims, palette, x, y)
  self.anims = anims
  self.palette = palette
  self.x = x or 0
  self.y = y or 0
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

function _sprite:dmove(dx, dy)
  self.x += dx
  self.y += dy
end

function _sprite:move(to_x, to_y)
  self.x = to_x
  self.y = to_y
end

-- dest sprite
_dsprite = _sprite:extend()

function _dsprite:init(anims, palette, x, y)
  self.__super.init(self, anims, palette, x, y)
  self.tx = x
  self.ty = y
end

function _dsprite:dmove(dx, dy)
  self.tx += dx
  self.ty += dy
end

function _dsprite:move(to_x, to_y)
  self.tx = to_x
  self.ty = to_y
end

function _dsprite:is_ok()
  return self.x == self.tx and self.y == self.ty
end

-- pixel explosions
function _splosion(sx, sy, tile, trans)
  local particles = {}
  local bx = (tile % 16) * 8
  local by = flr(tile / 16) * 8
  for x=0, 7 do
    for y=0, 7 do
      local c = sget(bx + x, by + y)
      if c ~= trans then
        add(particles, {
          x=x,
          y=y,
          dx=rnd(6) - 3,
          dy=rnd(6) - 3,
          c=c,
        })
      end
    end
  end

  return {
    draw = function()
      for ptcl in all(particles) do
        pset(sx + ptcl.x, sy + ptcl.y, ptcl.c)

        if check_collision(sx + ptcl.x + ptcl.dx, sy + ptcl.y) then
          ptcl.dx *= -1
        end
        if check_collision(sx + ptcl.x, sy + ptcl.y + ptcl.dy) then
          ptcl.dy *= -1
        end

        ptcl.x += ptcl.dx
        ptcl.y += ptcl.dy
        ptcl.dx *= 0.9
        ptcl.dy *= 0.9

        if (abs(ptcl.dx) < 0.1 and abs(ptcl.dy) < 0.1) then
          del(particles, ptcl)
        end
      end
    end,
  }
end

-- torch lighting
function set_light(l)
  if not l then
    light = 0
    light_sq = 0
    shade_factor = 0
    return
  end

  if l < 8 then
    l = 8
  end
  if l > 32 then
    l = 32
  end
  light = l
  light_sq = l * l / 2
  shade_factor = shl(8, flr(l / 8))
end

-->8
-- game config

hero_anims = {
  idle_down = 72,
  idle_up = 88,
  idle_right = 104,
  idle_left = 120,
  walk_down = _anim({72, 73, 72, 74}),
  walk_up = 88,
  walk_right = 104,
  walk_left = 120,
}

room_town = 9
room_d1_f1 = 1
room_d1_f2 = 2
room_d1_f3 = 3
room_d1_f4 = 4

room = room_town
rooms = {
  {x=0, y=0, light=32},
  {x=16, y=0, light=32},
  {x=32, y=0, light=32},
  {x=48, y=0, light=32,},
  [room_town] = {x=0, y=16},
}

set_light(rooms[room].light)

portals = {
  {x=8, y=31, to_x=1, to_y=4, to_room=room_d1_f1},
  {x=0, y=4, to_x=8, to_y=30, to_room=room_town},

  {x=10, y=10, to_x=27, to_y=10, to_room=room_d1_f2},
  {x=26, y=10, to_x=11, to_y=10, to_room=room_d1_f1},

  {x=24, y=10, to_x=40, to_y=9, to_room=room_d1_f3},
  {x=40, y=10, to_x=23, to_y=10, to_room=room_d1_f2},

  {x=40, y=15, to_x=56, to_y=14, to_room=room_d1_f4},
  {x=56, y=15, to_x=40, to_y=14, to_room=room_d1_f3},
}

-->8
-- game play

hero = _dsprite(hero_anims, function() palt(c_black, false) palt(c_red, true) end, 56, 184)
hero:set_anim("walk_down")
hero.dir = "down"

camera_x, camera_y = 0, 0

function world()
  local splosions = {}

  return {
    update = function()
      if hero:is_ok() then
        local hx = hero.x + 4
        local hy = hero.y + 4

        if check_flag(hx, hy, flag_portal) then
          for portal in all(portals) do
            if portal.x == flr8(hero.x + 4) and portal.y == flr8(hero.y + 4) then
              game.push(fade_out(teleport(portal.to_x * 8, portal.to_y * 8, portal.to_room)))
              return true
            end
          end
        end

        if btn(b_left) then
          if not check_collision(hx - 8, hy) then
            hero:dmove(-8, 0)
          end
        elseif btn(b_right) then
          if not check_collision(hx + 8, hy) then
            hero:dmove(8, 0)
          end
        elseif btn(b_up) then
          if not check_collision(hx, hy - 8) then
            hero:dmove(0, -8)
          end
        elseif btn(b_down) then
          if not check_collision(hx, hy + 8) then
            hero:dmove(0, 8)
          end
        end
      end

      if not hero:is_ok() then
        if hero.tx < hero.x then
          hero.x -= 1
          hero.dir = "left"
        elseif hero.tx > hero.x then
          hero.x += 1
          hero.dir = "right"
        elseif hero.ty < hero.y then
          hero.y -= 1
          hero.dir = "up"
        elseif hero.ty > hero.y then
          hero.y += 1
          hero.dir = "down"
        end

        hero:set_anim("walk_" .. hero.dir)
      else
        hero:set_anim("idle_" .. hero.dir)
      end

      if btnp(b_x) then
        add(splosions, _splosion(hero.x, hero.y, hero.tile, c_red))
      end

      hero:update()
    end,

    draw = function()
      cls()
      pal()
      local clip_x, clip_y, clip_s = nil, nil, nil

      if light > 0 then
        clip_x = min(127, max(0, hero.x - camera_x - light))
        clip_y = min(127, max(0, hero.y - camera_y - light))
        clip_s = light * 2 + 8
        clip(clip_x, clip_y, clip_s, clip_s)
      end

      local cur_room = rooms[room]
      local l = cur_room.x * 8
      local r = l + (cur_room.w or 16) * 8
      local t = cur_room.y * 8
      local b = t + (cur_room.h or 16) * 8

      camera_x, camera_y = max(l, min(hero.x - 60, r - 128)), max(t, min(hero.y - 60, b - 128))
      camera(camera_x, camera_y)
      map(0, 0, 0, 0, 128, 64)

      hero:draw()

      if light > 0 then
        local hx = camera_x - hero.x - 3
        local hy = camera_y - hero.y - 3
        local max_clip_x = min(64, (clip_x + clip_s) / 2)
        local max_clip_y = min(127, clip_y + clip_s)

        -- this doesn't perfectly shade horizontal pixels
        -- ...which normally isn't too much of an issue
        for x=clip_x / 2, max_clip_x  do
          local lsq = light_sq + rnd(16)
          for y=clip_y, max_clip_y do
            -- local addr = 0x6000 + x + y * 64
            local addr = bor(bor(0x6000, x), shl(y, 6))

            local dst_x = x * 2 + hx
            local dst_y = y + hy
            local dst_sq = dst_x * dst_x + dst_y * dst_y

            local shades = flr((dst_sq - lsq) / shade_factor)
            local shade_color = 0x00

            if shades < 5 then
              -- shading_table = shading_base + shades * 256
              local shading_table = shading_base + shl(shades, 8)
              local shading_addr = shading_table + peek(addr)
              shade_color = peek(shading_addr)
            end

            if shades > 0 then
              poke(addr, shade_color)
            end
          end
        end
      end

      for splosion in all(splosions) do
        splosion:draw()
      end

      clip()

      tprint(stat(7) .. 'fps', camera_x + 1, camera_y + 1, c_white, c_black)
      tprint('c' .. flr(stat(1) * 100) .. '%', camera_x + 28, camera_y + 1, c_white, c_black)
      tprint('m' .. flr(stat(2) / 20.48) .. '%', camera_x + 56, camera_y + 1, c_white, c_black)
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
        game.pop()
      end
      return true
    end,
  }
end

function fade_out(next)
  local frame = 0
  local shades = {[0]=0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
  return {
    draw = function()
      for j=0, 15 do
        pal(j, shades[j], 1)
      end
    end,

    update = function()
      frame += 1

      for j=0, 15 do
        shades[j] = drk[shades[j]]
      end

      if frame == 6 then
        game.pop()
        game.push(next or fade_in())
      end

      return true
    end,
  }
end

function fade_in()
  local frame = 0
  local faded = 6

  return {
    draw = function()
      local shades = {[0]=0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
      for i=1, faded do
        for j=0, 15 do
          shades[j] = drk[shades[j]]
        end
      end

      for j=0, 15 do
        pal(j, shades[j], 1)
      end
    end,

    update = function()
      faded -= 1

      if faded == -1 then
        game.pop()
      end

      return true
    end,
  }
end

function teleport(to_x, to_y, to_room, next)
  return {
    draw = function()
      for j=0, 15 do
        pal(j, c_black, 1)
      end
    end,

    update = function()
      hero:move(to_x, to_y)
      hero.x = to_x
      hero.y = to_y
      room = to_room
      set_light(rooms[to_room].light)
      game.pop()
      game.push(next or fade_in())
      return true
    end
  }
end

game = _machine()
game.push(world())

function _init()
  -- initialize shade colors
  for sh=0, 5 do
    local shades = {}

    for j=0, 15 do
      shades[j] = sget(8 + sh, 32 + j)
    end

    local shading_table = shading_base + shl(sh, 8)

    for x=0, 255 do
      local left_color = band(x, 0xf)
      local right_color = band(lshr(x, 4), 0xf)
      poke(bor(shading_table, x), shl(shades[right_color], 4) + shades[left_color])
    end
  end
end

function _draw() game.draw() end
function _update() game.update() end

__gfx__
00000000aa96090a055555559a999a9aa9a49494700002a00000007000000000006666003333300000003333333330000000000000003333aaaaa944449aaaaa
000000009a00090a50055555900000099a222229606602900944477700666b60067bb7603330044747400033333004444444444444400033aaa9944994499aaa
007007009aa60009555055550099990042210000006d00000994497006bc7bc6677bb7763304444474444403330444444444444444444403a9944997a994499a
00077000aa960a09555505550944444021110dd050dd0dd0449449746cbccbc66bbbbbb630444647474644403044444444444444444444409449977aaaa99449
00077000aa00090a555505550222222010000d5050000d504444447467bcccc66bbbbbb6304446744476444030444444444444444444444049977aaaaaaaa994
007007009aa6000a55550555044444401055055050550550444884746ccc7c76677bb7763044466646664440304444444444444444444440497aaaaaaaaaaa94
000000009aa60a0905005555022aa2200051000050550000044884706cc7cc60067bb760304464444444644030444444444444444444444049aaaaaaaaaaaa94
00000000aa060a0950555555044444401011011050550110044004700666660000666600304000044400004030400004444444444400004049aaaaaaaaaaaa94
333333333333333333333333000000000000000000000000400000000000000000000004333330000000333300000000000000000000000049aaaaaaaaaaaa94
333333333333333333000033000000000000000000000000009aa9aa9aa9aa9aaa9aa900333004444440003300000000000000000000000049aaaaaaaaaaaa94
333333333333333330aabb03000000000000000000000000092222222222222222222290330444444889440300000000000000000000000049aaaaaaaaaaa994
33333e33333333330aabb8b00000000000000000000000000a20101010101010101012a03044448989aa9440000000000000000000000000499aaaaaaaa99994
3333eae3333333330bebbbb00000000000000000000000000a21000000000000000002a0304898999aaa944000000000000000000000000094499aaaa9999449
33333e33333333330bbbb2b00000000000000000000000000920000000000000000012903044444898894440000000000000000000000000a994499a99944997
33333333333333330b8bb3300000000000000000000000000a21000000000000000002a03044444444444440000000000000000000000000aaa994499449977a
333333333333333330bb33030000000000000000000000000a20000000000000000012a03040000444000040000000000000000000000000aaaaa94444977aaa
3333333333000033333333333333333340000004000000000a21000040000004000002a03333300000003333000000000090800099990999aaaaaa94497aaaaa
333333333077aa033330033333000033009aa9009aa9aa9a0a200000009aa900000012a03330044444400033000000009000809099900099aaaaaa9449aaaaaa
33c333330aaa09903307603330bb7b03092222a0222222220921000009222290000002a033044444444444030000000090a000909990a099aaaaaa9449aaaaaa
3cac3e33070770a03076d6030b7bb3300a201290101010100a2000000a2012a000001290304467ccccccc4400000000000a0a00099009009aaaaaa9449aaaaaa
33c3eae309999990306dd5030bbb3b300a2102a0010101010a2100000a2102a0000002a03044666666666440000000004000a0a0990a0009aaaaaa9449aaaaaa
33333e330aaa0990306dd503303333030a2012a0222222220a20000009222290000012a0304464446444644000000000409000a099000900aaaaaa9449aaaaaa
3333333309044440305d520333022033092102909aa9aa9a09210000009aa900000002a03044444444444440000000000090400090090aa0aaaaaa9449aaaaaa
3333333330a9990333333333330420330a2012a0000000000a2000004000000400001290304000044400004000000000a00040a090a00a00aaaaaa9449aaaaaa
333333333444444334434343333330330a2102a00a2102a00a21000000000000000002a0304000044407c040000000000a000a00000000000000000000000000
33333333444446444444444433300b030a2012a00a2012a00a20000000000000000012a030400604440cc0400000000000090a0990440aa00000000000000000
33c333333464444344644464300b00b0092102a0092102a009210000000000000000029030400004440000400000000004090000000000000000000000000000
3cac333344446444444444440b00b0b00a2012900a2012900a20000000000000000012a030400004444444400000000004000aa0990aa0990000000000000000
33c33333444444444444444430b0b0300a2102a00a2102a00a21010101010101010102a035353535353535350000000000000000000000000000000000000000
33333333346444434644444430b030300a2222a00a2012a00922222222222222222222903353535353535353000000000a0990aa044099040000000000000000
33333333444446444444446430303030009aa900092102a0009aa9aa9aa9aa9aaa9aa9003335353535353533000000000a000000000000000000000000000000
33333333344444433434334333333333400000040a2012904000000000000000000000043333333333333333000000000aa0440990aa0aa00000000000000000
00000077000000770000000000000000000000000000000000000000000000008008800880088008800880080000000000000000000000000000000000000000
11100077100000770000000000000000000000000000000000000000000000000990099009900990099009900000000000000000000000000000000000000000
22110077210000770000000000000000000000000000000000000000000000000944449009444490094444900000000000000000000000000000000000000000
33311077310000770000000000000000000000000000000000000000000000000440404004404040044040400000000000000000000000000000000000000000
42211077421000770000000000000000000000000000000000000000000000000444444004444440044444400000000000000000000000000000000000000000
55111077510000770000000000000000000000000000000000000000000000008022220880222208802222080000000000000000000000000000000000000000
66d51077651000770000000000000000000000000000000000000000000000008042940880429408804294080000000000000000000000000000000000000000
776d1077765100770000000000000000000000000000000000000000000000008000000880000008800000080000000000000000000000000000000000000000
88221077821000770000000000000000000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
94221077942100770000000000000000000000000000000000000000000000008448844800000000000000000000000000000000000000000000000000000000
a9421077a94210770000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
bb331077b31000770000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
ccd51077c10000770000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
dd511077d10000770000000000000000000000000000000000000000000000008822228800000000000000000000000000000000000000000000000000000000
ee421077e21000770000000000000000000000000000000000000000000000001844248100000000000000000000000000000000000000000000000000000000
f9421077f51000770000000000000000000000000000000000000000000000008848848800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008899888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008894448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844048800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008822228800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008824918800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008884888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888998800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844498800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008840448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008822228800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008819428800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888488800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888998800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844498800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008840448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008844448800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008822228800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008819428800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888488800000000000000000000000000000000000000000000000000000000
__gff__
0000010102020002000101010101000000000101020201010101010101010000000101010101010101010101010100000000000001010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0037373737373737373737373737370000373737373737373737373737373700003737373737373737373737373737002727272727272727272727272727272700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
282e342e2f2e2f2e2f2e2f2e2f2e2e2628000000000000000000000000000026270027272727270000000000000003262727000000080303030308000000272700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
280e0f0e0f0e0f0e0f0e0f0e0e0f0e2628252525252525252525250000000026270000000000000027272727272727262700270000000000000000000027002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f1625182e2f2e2f2e1f1e1f1e2628000000000000000000000000000026270027272727272727000000000000262700002700000000000000002700002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
050e0f3503362525252525180e0f0e2628002525252525252525180e0f000026270000002700000000002727272700262700000027000000000000270000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f352f2e35031e1f1e341e1f1e2628000036280000000000351e1f000026270000000000002700002700000000262700000000270000000027000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
280e0f350f0e352f2e272e2f2e2f2e262800000034000e0f2400350e0f000026272727272727272727272700272727262700000000002727062700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f351f1e350f0e0f0e240e0f0e262800000000001e1f3500351e1f000026270000000000000000000000000000262700000000002700002700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
280e0f35272e36252525252525181e2600180000000025170003350e0f000026270027272727272727272700000000262700000000002706272700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f350f0e0f0e352f2e2f2e352e2600001800270000363717381e00000026270027270000002700002727270000262700000000002700002700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
280e0f351f1e1f1e350f040f0e350e2600002800000000000435050000000026270027270027002705002700000000262700000000002727062700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f3625252506252525181e351e2600373725252525252525252525180026270027270027002727002700002727262700000000002700002700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
280e0f0e0f0e0f0e0f0e0f352e342e2628000000340034000000000000340026270027270027000000002700000000262700000000002706272700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
281e1f1e1f1e1f1e1f1e1f350e0f0e2628000700060006002525252500000026270027270027272727272727270000262700000000002700002700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
282e2f242f2e242e2f242f35241f1e2628000000240024000000000000240026270000000027272700000000000000262700000000002700002700000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0017171717171717171717171717170000171717171717171717171717171700001717171717171704171717171717002727272727272727052727272727272700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121212121212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1221302111211121112111211121111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211111111111011111111111111101200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1221112111211121110b0c0c0c0d111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
121111111111111111393a3a3a3a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121131323211111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211301123121131111111231111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211222211231131110b0d110b0d111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
122011111012113111393a11393a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212311212121131323232323232111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12113111292a113111090a11191a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12113111393a113111393a11393a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211313232323232323232323232111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211111111111031111111113011111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211231111111131111123111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121231071212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
