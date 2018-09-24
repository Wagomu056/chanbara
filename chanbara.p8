pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- debug --
dbg = {}
dbg.print = {}
dbg.print.data = function(msg, frame, color)
	local obj = {}
	obj.msg = msg
	obj.frame = frame
	if color != nil then
		obj.color = color
	else
		obj.color = 12
	end

	obj.decrement_frame = function(self)
		self.frame -= 1
	end

	return obj
end

dbg.print.new = function()
	local obj = {}

	obj.table = {}

	obj.set_print = function(self, msg, frame, color)
		local data = dbg.print.data(msg, frame, color)
		add(self.table, data)
	end

	obj.update = function(self)
		for data in all(self.table) do
			if data.frame < 1 then
				del(self.table, data)
			end
		end

		for i, data in pairs(self.table) do
			self.table[i]:decrement_frame()
		end
	end

	obj.draw = function(self)
		local offset = 8
		for i, data in pairs(self.table) do
			print(data.msg, 0, offset * (i - 1), data.color)
		end
	end

	return obj
end

local dbg_print = dbg.print.new()

-- math --
math = {}
math.vec2 = {}
math.vec2.new = function(x, y)
	local obj = {}

	obj.x = x
	obj.y = y

	return obj
end

-- anim --
anim = {}
anim.data = {}
anim.data.new = function(sprites, w, h, times, moves, is_loop)
	local obj = {}

	obj.sprites = sprites
	obj.spr_w = w
	obj.spr_h = h
	obj.times = times
	obj.moves = moves
	obj.is_loop = is_loop

	return obj
end

anim_table = {}
anim_table["pl_idle"] = anim.data.new({0,1},1,1,{0.5,0.5},{0,0},true)
anim_table["pl_slash"] = anim.data.new({2,3},1,1,{0.2,0.3},{0,8},false)

anim.controller = {}
anim.controller.new = function()
	local obj = {}

	-- variables
	obj.key_name = ""
	obj.data = {}
	obj.spr_index = 0
	obj.elapsed_time = 0.0
	obj.is_end = false
	obj.just_change = false
	obj.is_mirror = false

	-- functions
	obj.set = function(self, key_name)
		self.key_name = key_name
		self.data = anim_table[key_name]
		self.spr_index = 0
		self.elapsed_time = 0.0
		self.is_end = false
		if self.data.is_loop then
			self.is_end = true
		end
		self.just_change = false
	end

	obj.update = function(self, delta_time)
		if self.data.times[1] <= 0 then
			return
		end

		self.just_change = false

		self.elapsed_time += delta_time

		if self.elapsed_time >= self.data.times[self.spr_index + 1] then
			if self.data.is_loop == true then
				self.spr_index = (self.spr_index + 1) % #(self.data.sprites)
				self.just_change = true
			else
				local is_end = ((self.spr_index + 1) == #(self.data.sprites))
				if is_end then
					self.is_end = true
				else
					self.spr_index += 1
					self.just_change = true
				end
			end

			self.elapsed_time = 0.0
		end
	end

	obj.get_spr = function(self)
		return self.data.sprites[self.spr_index + 1], self.data.spr_w, self.data.spr_h
	end

	obj.get_move = function(self)
		if self.just_change == false then
			return 0.0
		else
			local move = self.data.moves[self.spr_index + 1]
			if self.is_mirror then
				move *= -1
			end
			return move
		end
	end

	obj.debug_draw = function(self)
		local offset = 8
		local row = 0
		local color = 12
		print(self.key_name, 0, 0, color)
		row += 1
		print(self.spr_index, 0, row * offset, color)
		row += 1
		print(self.elapsed_time, 0, row * offset, color)
		row += 1
		print(self.data.sprites[self.spr_index + 1], 0, row * offset, color)
		row += 1
	end

	return obj
end

-- collision --
function check_wall(x, y)
	local map_val = mget(x / 8, y / 8)
	return fget(map_val,0)
end

-- hit check --
hit = {}
hit.data = {}
hit.data.new = function(owner)
	local obj = {}

	obj.aa = math.vec2.new(0, 0)
	obj.bb = math.vec2.new(0, 0)
	obj.offset = math.vec2.new(0, 0)
	obj.width = 0
	obj.hight = 0
	obj.owner = owner
	obj.is_mirror = false

	obj.set_pos = function(self, x, y)
		local up_x = x + self.offset.x
		local up_y = y + self.offset.y
		local dw_x = up_x + self.width - 1
		local dw_y = up_y + self.hight - 1

		if self.is_mirror then
			self.aa.x = up_x - self.width
			self.aa.y = up_y
			self.bb.x = dw_x - self.width
			self.bb.y = dw_y
		else
			self.aa.x = up_x
			self.aa.y = up_y
			self.bb.x = dw_x
			self.bb.y = dw_y
		end
	end

	obj.set_size = function(self, w, h)
		self.width = w
		self.hight = h
	end

	obj.set_offset = function(self, x, y)
		self.offset.x = x
		self.offset.y = y
	end

	obj.debug_draw = function(self, color)
		rect(self.aa.x, self.aa.y
			,self.bb.x, self.bb.y
			,color)
	end

	return obj
end

function check_hit(box_a, box_b)
	if box_a.aa.x > box_b.bb.x then
		return false
	end
	if box_a.bb.x < box_b.aa.x then
		return false
	end
	if box_a.aa.y > box_b.bb.y then
		return false
	end
	if box_a.bb.y < box_b.aa.y then
		return false
	end

	return true
end

hit.checker ={}
hit.checker.new = function()
	local obj = {}
	obj.atk_list = {}
	obj.def_list = {}

	obj.check = function(self)
		for atk_i, atk in pairs(self.atk_list) do
			for def_i, def in pairs(self.def_list) do
				if check_hit(atk, def) then
					atk.owner:atk_callback(def)
					def.owner:def_callback(atk)
				end
			end
		end

		for i = 1, #self.atk_list do
			self.atk_list[i] = nil
		end
	end

	obj.debug_draw = function(self)
		for i, box in pairs(self.def_list) do
			box:debug_draw(12)
		end
		for i, box in pairs(self.atk_list) do
			box:debug_draw(14)
		end
	end

	obj.regist_def_hit_data = function(self, def_data)
		add(self.def_list, def_data)	
	end

	return obj
end
local hit_checker = hit.checker.new()

-- time_keeper --
time_keeper = {}
time_keeper.new = function()
	local obj = {}

	-- variables
	obj.pre_elapsed_time = 0.0
	obj.delta_time = 0.0

	-- function
	obj.init = function(self)
		self.pre_elapsed_time = time()
	end

	obj.update = function(self)
		local elapsed_time = time()
		self.delta_time = elapsed_time - self.pre_elapsed_time
		self.pre_elapsed_time = elapsed_time
	end

	return obj
end

-- act --
local act = {}

act.object = {}
act.object.new = function()
	local obj = {}

	-- variables
	obj.pos = math.vec2.new(0,0)
	obj.spr_size = math.vec2.new(1,1)
	obj.spr_offset = math.vec2.new(0,0)
	obj.spr_idx = 0

	-- function
	obj.draw = function(self, is_reverse)
		spr(self.spr_idx
			,self.pos.x + self.spr_offset.x
			,self.pos.y + self.spr_offset.y
			,self.spr_size.x
			,self.spr_size.y
			,is_reverse)
	end

	-- update function
	obj.update_pre = function(self)
	end

	obj.update_control = function(self)
	end

	obj.update_animation = function(self)
	end

	obj.set_pos = function(self, x, y)
		self.pos.x = x
		self.pos.y = y
	end

	obj.set_spr_size = function(self, x, y)
		self.spr_size.x = x
		self.spr_size.y = y
	end

	obj.set_spr_offset = function(self, x, y)
		self.spr_offset.x = x
		self.spr_offset.y = y
	end

	obj.dbg_draw_pos = function(self)
		pset(self.pos.x, self.pos.y, 11)
	end

	return obj
end

act.chara = {}
act.chara.new = function()
	local obj = act.object.new()
	obj.object_draw = obj.draw

	-- variable
	obj.anim_controller = anim.controller.new()
	obj.time_keeper = time_keeper.new()
	obj.hitbox = hit.data.new(obj)
	obj.direction = "right"

	-- base function
	obj.init = function(self)
		self.time_keeper:init()
	end

	obj.update = function(self)
		self.time_keeper:update()
		local delta_time = self.time_keeper.delta_time

		self:update_pre_animation()
		self:update_animation(delta_time)
		self:update_aft_animation()
	end

	obj.draw = function(self)
		self:object_draw(self.direction == "left")
	end

	-- derivation function
	obj.update_pre_animation = function(self)
		self.hitbox:set_pos(self.pos.x, self.pos.y)
	end

	obj.update_aft_animation = function(self)
	end

	obj.update_animation = function(self, delta_time)
		self.anim_controller:update(delta_time)
		self.spr_idx, self.spr_size.x, self.spr_size.y = self.anim_controller:get_spr()
	end

	-- setting function
	obj.atk_callback = function(self)
	end

	obj.def_callback = function(self, atk_box)
	end

	return obj
end

act.player = {}
act.player.new = function()
	local obj = act.chara.new()
	obj.chara_init = obj.init
	obj.chara_update_pre_animation = obj.update_pre_animation
	obj.chara_update_aft_animation = obj.update_aft_animation

	-- const
	obj.box_ofs_x = -4
	obj.box_ofs_y = -7

	-- variable
	obj.id = 1
	obj.action = "none"
	obj.anim_state = "idle"
	obj.request_pos = math.vec2.new(0, 0)
	obj.atk_hitbox = hit.data.new(obj)

	-- function
	obj.init = function(self, id, direction)
		self:chara_init()

		self.id = id
		self.direction = direction

		self:set_spr_size(1,1)
		self:set_spr_offset(self.box_ofs_x, self.box_ofs_y)

		self.hitbox:set_size(8, 8)
		self.hitbox:set_offset(self.box_ofs_x, self.box_ofs_y)
		self.hitbox:set_pos(self.pos.x, self.pos.y)
		hit_checker:regist_def_hit_data(self.hitbox)

		self.anim_controller.is_mirror = (self.direction == "left")
		self.anim_controller:set("pl_idle")
		
		self.request_pos.x = 0
		self.request_pos.y = 0

		self.atk_hitbox.is_mirror = (direction == "left")
		self.atk_hitbox:set_size(10, 8)
	end

	obj.update_pre_animation = function(self)
		self:chara_update_pre_animation()
		self:update_action()
		self:update_anim_state()
	end

	obj.update_aft_animation = function(self)
		self:chara_update_aft_animation()
		self:update_request_pos()
		self:apply_request_pos()
	end

	obj.update_action = function(self)
		if self.anim_controller.is_end == false then
			return
		end

		if btnp(4, (self.id -1)) then
			self.action = "slash"
			self:regist_atk_hitbox()
			return
		end

		self.action = "idle"
	end

	obj.update_anim_state = function(self)
		local state = self.action

		if self.anim_state != state then
			self.anim_state = state
			local state = "pl_" .. self.anim_state
			self.anim_controller:set(state)
		end
	end

	obj.update_request_pos = function(self)
		self.request_pos.x
		= self.anim_controller:get_move()
	end

	obj.apply_request_pos = function(self)
		local x = self.pos.x + self.request_pos.x
		local y = self.pos.y + self.request_pos.y
		self:set_pos(x, y)

		self.request_pos.x = 0
		self.request_pos.y = 0
	end

	obj.regist_atk_hitbox = function(self)
		local x = self.pos.x
		local y = self.pos.y

		self.atk_hitbox:set_offset(0, -7)
		self.atk_hitbox:set_pos(x, y)
		add(hit_checker.atk_list, self.atk_hitbox)
	end

	return obj
end

-- player list --
sys = {}
sys.player_list = {}
sys.player_list.new = function()
	local obj = {}
	obj.max_count = 2
	obj.list = {}

	obj.init = function(self)
		for i = 1, self.max_count do
			add(self.list, act.player.new())
		end

		for i = 1, self.max_count do
			local pl = self.list[i]

			local directin = "right"
			if i % 2 == 0 then
				directin = "left"
			end
			pl:init(i, directin)

			local window_center = 64
			local gap = 40
			if directin == "right" then
				gap *= -1
			end

			local x = window_center + gap
			local y = 79
			pl:set_pos(x, y)
		end
	end

	obj.update = function(self)
		foreach(self.list, function(obj) obj:update() end)
	end

	obj.draw = function(self)
		foreach(self.list, function(obj) obj:draw() end)
	end

	obj.dbg_draw_pos = function(self)
		foreach(self.list, function(obj) obj:dbg_draw_pos() end)
	end

	return obj
end

-- map --
act.map_info = {}
act.map_info.new = function()
	local obj = {}

	-- variables
	obj.base_x = 0
	obj.base_y = 0
	obj.size = 16

	-- functions
	obj.draw = function(self)
		map(self.base_x, self.base_y,
			0, 0, self.size, self.size)
	end

	return obj
end

-- global --
local map_info = act.map_info.new()
--local player = act.player.new()
local player_list = sys.player_list.new()

-- system --
function _init()
	player_list:init()
end

function _update()
	hit_checker:check()

	player_list:update()
	dbg_print:update()
end

function _draw()
	map_info:draw()
	player_list:draw()

	-- dbg
	hit_checker:debug_draw()
	player_list:dbg_draw_pos()
	dbg_print:draw()
end

__gfx__
11000000000000001100000011000000110000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111110110000000111111001111110011116570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ffffff0011111100ffffff00ffffff00ffff6570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f1fff100ffffff07765ff100f1fff100f1ff6560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ffffff00f1fff105555fff00ffffff00ffff6560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
502222005ffffff06665220000222205002225550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5f8888005f88880000888000008888f5008888f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50f00f0050f00f0000f0000000f00f0500f00f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007766000077660000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00075555000755550000000055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006666000066660000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01700000077000000710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77710000711700007711000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11770000711700001777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01700000077000000710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818182000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818182000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818182000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181808080808080808080808080818182000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
