pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- helpers
function flr8(v)
  return flr(v / 8)
end

function check_collision(x, y)
  local cell_n = mget(flr8(x), flr8(y))
  return fget(cell_n, flag_collision)
end

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

-->8
-- gameplay

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

camera_x, camera_y = 0, 0

function world()
  local hero = _sprite(hero_anims, function() palt(c_black, false) palt(c_red, true) end)
  hero.x = 60
  hero.y = 188
  hero:set_anim("walk_down")
  hero.dir = "down"

  local splosions = {}

  return {
    update = function()
      if btn(b_left) then
        if not check_collision(hero.x - 1, hero.y) and not check_collision(hero.x - 1, hero.y + 7) then
          hero.x -= 1
        end
        hero:set_anim("walk_left")
        hero.dir = "left"
      elseif btn(b_right) then
        if not check_collision(hero.x + 8, hero.y) and not check_collision(hero.x + 8, hero.y + 7) then
          hero.x += 1
        end
        hero:set_anim("walk_right")
        hero.dir = "right"
      elseif btn(b_up) then
        if not check_collision(hero.x, hero.y - 1) and not check_collision(hero.x + 7, hero.y - 1) then
          hero.y -= 1
        end
        hero:set_anim("walk_up")
        hero.dir = "up"
      elseif btn(b_down) then
        if not check_collision(hero.x, hero.y + 8) and not check_collision(hero.x + 7, hero.y + 8) then
          hero.y += 1
        end
        hero:set_anim("walk_down")
        hero.dir = "down"
      else
        hero:set_anim("idle_" .. hero.dir)
      end

      if btnp(4) then
        game.push(menu())
      end

      if btnp(5) then
        add(splosions, _splosion(hero.x, hero.y, hero.tile, c_red))
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

      tprint(flr(stat(1) * 100) .. '%', camera_x + 16, camera_y + 1, c_white, c_black)

      hero:draw()

      for splosion in all(splosions) do
        splosion:draw()
      end
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
00000000555555555555555500444400555555555555555500000070000000000066660033333000000033333333300000000000000033330000000000000000
00000000555955555555a5550499994055555599995555550944477700666b60067bb76033300447474000333330044444444444444000330000000000000000
0070070055959555a55aa5554999999455555544445555550994497006bc7bc6677bb77633044444744444033304444444444444444444030000000000000000
0007700055555555a55aa555444444445555994444995555449449746cbccbc66bbbbbb630444647474644403044444444444444444444400000000000000000
0007700055555555a55a9a5a499aa99455554444444455554444447467bcccc66bbbbbb630444674447644403044444444444444444444400000000000000000
0070070055555555a5a99a5a444444445599444444449955444884746ccc7c76677bb77630444666466644403044444444444444444444400000000000000000
00000000555555a59a9999a9499999945544444444444455044884706cc7cc60067bb76030446444444464403044444444444444444444400000000000000000
00000000555555559999999944444444994444444444449904400470066666000066660030400004440000403040000444444444440000400000000000000000
33333333333333333300003344444444000000000000000000000000333993330000000033333000000033330000000000000000000000000000000000000000
333333333333333330bbbb034888888400000000000000000000000033aaaa330000000033300444444000330000000000000000000000000000000000000000
33333333333333330bbbb8b048888884000000000000000000000000399909930000000033044444488944030000000000000000000000000000000000000000
33333e33333333330b8bbbb048888884000000000000000000000000aa0aa0aa000000003044448989aa94400000000000000000000000000000000000000000
3333eae3333333330bbbbbb0888888880000000000000000000000009999999900000000304898999aaa94400000000000000000000000000000000000000000
33333e33333333330bbbb8b0444444440000000000000000000000003aaa0aa30000000030444448988944400000000000000000000000000000000000000000
33333333333333330bbbbbb049999994000000000000000000000000990999990000000030444444444444400000000000000000000000000000000000000000
333333333333333330000003444444440000000000000000000000003aaaaaa30000000030400004440000400000000000000000000000000000000000000000
33333333333333330000000000000000000000000000000000000000000000000000000033333000000033337000000000000000000000000000000000000000
33333333333833330000000000000000000000000000000000000000000000000000000033300444444000337000000000000000000000000000000000000000
33c33333338888830000000000000000000000000000000000000000000000000000000033046444444444037000000000000000000000000000000000000000
3cac3e333383388300000000000000000000000000000000000000000000000000000000304467ccccccc4407000000000000000000000000000000000000000
33c3eae33383e8880000000000000000000000000000000000000000000000000000000030446666666664407000000000000000000000000000000000000000
33333e3333388e830000000000000000000000000000000000000000000000000000000030446444644464407000000000000000000000000000000000000000
33333333333333330000000000000000000000000000000000000000000000000000000030444444444444407000000000000000000000000000000000000000
33333333333333330000000000000000000000000000000000000000000000000000000030400004440000407000000000000000000000000000000000000000
33333333344444433443434300000000000000000000000000000000000000000000000030400004440cc0407000000000000000000000000000000000000000
33333333444446444444444400000000000000000000000000000000000000000000000030400004440cc0407000000000000000000000000000000000000000
33c33333346444434464446400000000000000000000000000000000000000000000000030400704440000407000000000000000000000000000000000000000
3cac3333444464444444444400000000000000000000000000000000000000000000000030400004444444407000000000000000000000000000000000000000
33c33333444444444444444400000000000000000000000000000000000000000000000030000000000000007000000000000000000000000000000000000000
33333333346444434644444400000000000000000000000000000000000000000000000033535353535353537000000000000000000000000000000000000000
33333333444446444444446400000000000000000000000000000000000000000000000033353535353535337000000000000000000000000000000000000000
33333333344444433434334300000000000000000000000000000000000000000000000033333333333333337000000000000000000000000000000000000000
33333333333333333333333333333333333333330000000000000000000000008888888889988998899889980000000000000000000000000000000000000000
33333333333388333333e33333333333333355530000000000000000000000008998899889444498894444980000000000000000000000000000000000000000
333333333333b833333eae3333b33333335555530000000000000000000000008944449884404048844040480000000000000000000000000000000000000000
33333333333b33333333e333333333b3355555530000000000000000000000008440404884444448844444480000000000000000000000000000000000000000
33333333333b33333333b33333333333355555530000000000000000000000008444444818222288882222810000000000000000000000000000000000000000
3333333333b333333333b3333b333333355555330000000000000000000000008822228888429481184294880000000000000000000000000000000000000000
3333333333b333333333b3333333b333335555330000000000000000000000001842948188888488884888880000000000000000000000000000000000000000
33333333333333333333333333333333333333330000000000000000000000008848848888888888888888880000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008448844800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008822228800000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001844248100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008848848800000000000000000000000000000000000000000000000000000000
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
__map__
0202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000202000000000000000000000000000002020002020202020000000000000003020202000000080303030308000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000202020202020202020202020000000002020000000000000002020202020202020200020000000000000000000002000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000202020000000000000000000202000000000000000000000000000002020002020202020202000000000000020200000200000000000000000200000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000203020202020202020000000202000202020202020202020202000002020000000200000000000202020200020200000002000000000000020000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000213000000020000000202000002020000000000020202000002020000000000000200000200000000020200000000020000000002000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000200000000000000000202000000020002020200020202000002020202020202020202020200020202020200000000000202060200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000200000000020000000202000000000002020200020202000002020000000000000000000000000000020200000000000200000200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000202020202020202000202020000000002020203020202000002020002020202020202020200000000020200000000000206020200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000000020000000002000202020200020000020202020200000002020002020000000200000202020000020200000000000200000200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000000020004000002000202020200000000000402050000000002020002020002000205000200000000020200000000000202060200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000202020206020202020002000202020202020202020202020202000002020002020002000202000200000202020200000000000200000200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000020002000202000000020002000000000000020002020002020002000000000200000000020200000000000206020200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000020000000202000700060006000202020200000002020002020002020202020202020000020200000000000200000200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000200000200000200020200000202000000020002000000000000020002020000000002020200000000000000020200000000000200000200000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020202020202020202020202020202020202020202020202020202020204020202020202020202020202020202050202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121212121212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1217301711171117111711171117111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211111111111011111111111111101200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1217111711171117110b0c0c0c0d111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
121111111111111111393a3a3a3a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121131323211111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1220202020121131111111111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1220202020121131110b0d110b0d111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
122020202012113111393a11393a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212311212121131323232323232111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12113111292a113111090a11191a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12113111393a113111393a11393a111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211313232323232323232323232111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211111111111031111111113011111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1211111111111131111111111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1212121212121231111212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
