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

-- shake --
local shake_offset = 0
function screen_shake()
	local fade = 0.5
	local offset_x=16-rnd(32)
	local offset_y=16-rnd(32)
	
	offset_x*=shake_offset
	offset_y*=shake_offset
	
	camera(offset_x,offset_y)
	
	shake_offset*=fade
	if shake_offset<0.05 then
		shake_offset=0
	end
end

-- anim --
anim = {}
anim.data = {}
anim.data.new = function(sprites, w, h, times, moves, func_tags, is_loop)
	local obj = {}

	obj.sprites = sprites
	obj.spr_w = w
	obj.spr_h = h
	obj.times = times
	obj.moves = moves
	obj.func_tags = func_tags
	obj.is_loop = is_loop

	return obj
end

anim_table = {}
anim_table["pl_idle"]
= anim.data.new({0,1},1,1,{0.5,0.5},{0,0},{nil,nil},true)
anim_table["pl_slash"]
= anim.data.new({2,3},1,1,{0.1,0.3},{0,8},{nil,"regist_atk"},false)
anim_table["pl_damage"]
= anim.data.new({5},1,1,{0.3},{-8},{nil},false)
anim_table["pl_guard"]
= anim.data.new({4},1,1,{1},{0},{nil},true)
anim_table["pl_guard_scc"]
= anim.data.new({7},1,1,{0.05},{0},{nil},false)
anim_table["pl_reflect"]
= anim.data.new({6},1,1,{1.0},{-8},{nil},false)
anim_table["pl_cant_guard"]
= anim.data.new({8},1,1,{0.2},{0},{nil},false)

anim.controller = {}
anim.controller.new = function(owner)
	local obj = {}

	-- variables
	obj.key_name = ""
	obj.data = {}
	obj.spr_index = 0
	obj.elapsed_time = 0.0
	obj.crnt_move = 0
	obj.is_end = false
	obj.just_change = false
	obj.is_mirror = false
	obj.is_first = false
	obj.owner = owner

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
		self.crnt_move = self.data.moves[1]
		self.is_first = true
	end

	obj.update = function(self, delta_time)
		if self.data.times[1] <= 0 then
			return
		end

		self.just_change = false

		if self.is_first == false then
			self.crnt_move = 0
		end

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

			if self.just_change then
				local tag = self.data.func_tags[self.spr_index + 1]
				self.owner:callback_anim_change(tag)

				self.crnt_move = self.data.moves[self.spr_index + 1]
			end

			self.elapsed_time = 0.0
		end

		self.is_first = false
	end

	obj.get_spr = function(self)
		return self.data.sprites[self.spr_index + 1], self.data.spr_w, self.data.spr_h
	end

	obj.get_move = function(self)
		local move = self.crnt_move
		if self.is_mirror then
			move *= -1
		end
		return move
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
function check_floor(x, y)
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

-- camera_effect --
local request_cam_eff_color = 0
function draw_camera_effect()
	if request_cam_eff_color == 0 then
		return
	end

	rectfill(-32,-32,160,160,request_cam_eff_color)
	request_cam_eff_color = 0
end

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
	obj.draw = function(self, is_mirror, pal_c0, pal_c1)
		local is_pal = (pal_c0 and pal_c1)
		if is_pal then
			pal(pal_c0, pal_c1)
		end

		spr(self.spr_idx
			,self.pos.x + self.spr_offset.x
			,self.pos.y + self.spr_offset.y
			,self.spr_size.x
			,self.spr_size.y
			,is_mirror)

		if is_pal then
			pal()
		end
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
	obj.anim_controller = anim.controller.new(obj)
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

		self:update_pre_animation(delta_time)
		self:update_animation(delta_time)
		self:update_aft_animation(delta_time)
	end

	obj.draw = function(self, pal_c0, pal_c1)
		self:object_draw(self.direction == "left", pal_c0, pal_c1)
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

	obj.callback_anim_change = function(self, tag)
	end

	-- setting function
	obj.atk_callback = function(self, def_box)
	end

	obj.def_callback = function(self, atk_box)
	end

	return obj
end

act.weapon = {}
act.weapon.new = function()
	local obj = {}

	-- parameter
	obj.spr_base = 16
	obj.spr_ofs_x = -4
	obj.spr_ofs_y = -7
	obj.ofs_x = -8

	obj.draw = function(self, x, y, spr_idx, dir, is_mirror)
		local ofs_x = self.ofs_x
		if dir == "right" then
			ofs_x *= -1
		end
		if is_mirror then
			ofs_x *= -1
		end

		spr(spr_idx + self.spr_base
			,x + ofs_x + self.spr_ofs_x
			,y + self.spr_ofs_y
			,1
			,1
			,is_mirror)
	end

	return obj
end

act.stamina = {}
act.stamina.new = function(value_max)
	local obj = {}

	-- paramter
	obj.param_down = 50 / 1 -- value/sec
	obj.param_up = 25 / 1
	obj.param_stay_time = 0.3

	-- variables
	obj.value = value_max
	obj.value_max = value_max
	obj.is_reduce = false
	obj.is_request_recover = false
	obj.pre_is_reduce = false
	obj.state = "none"
	obj.current_state_time = 0.0

	obj.set_is_reduce = function(self, is_reduce)
		self.is_reduce = is_reduce
	end

	obj.request_recover = function(self)
		self.is_request_recover = true
	end

	obj.update = function(self, delta_time)
		local just_reduce = false
		if self.pre_is_reduce != self.is_reduce then
			if self.is_reduce then
				just_reduce = true
			end
			self.pre_is_reduce = self.is_reduce
		end

		local pre_state = self.state
		self:update_state(delta_time)

		if pre_state != self.state then
			self.current_state_time = 0
		else
			self.current_state_time += delta_time
		end

		self:update_value(delta_time, just_reduce)
	end

	obj.update_state = function(self, delta_time)
		if self.is_reduce then
			self.state = "down"
			return
		end

		local st = self.state
		if st == "down" then
			self.state = "stay"
		elseif st == "stay" then
			if self.current_state_time >= self.param_stay_time then
				self.state = "up"
			end
		elseif st == "up" then
			if self.value >= 100 then
				self.state = "none"
			end
		end
	end

	obj.update_value = function(self, delta_time, just_reduce)
		if self.is_request_recover then
			self.is_request_recover = false
			self.value = min(self.value + 50, self.value_max)
		end

		local st = self.state

		if just_reduce then
			self.value -= 10
		end

		if st == "down" then
			self.value -= self.param_down * delta_time
			self.value = max(self.value, 0)
		elseif st == "up" then
			self.value += self.param_up * delta_time
			self.value = min(self.value, self.value_max)
		end
	end

	obj.is_empty = function(self)
		return (self.value == 0)
	end

	return obj
end

act.meter = {}
act.meter.new = function(max_value, offset_y)
	local obj = {}

	obj.width = 8
	obj.hight = 0

	obj.x = 0
	obj.y = 0
	obj.offset_y = offset_y
	obj.max_value = max_value
	obj.value = max_value

	obj.update = function(self, x, y, value)
		self.value = value
		self.x = x
		self.y = y
	end

	obj.draw = function(self)
		if self.value == self.max_value then
			return
		end

		local ax = self.x - (self.width * 0.5)
		local ay = self.y + self.offset_y
		local bx = ax + self.width
		local by = ay + self.hight
		rectfill(ax, ay, bx, by, 1)

		local ratio = self.value / self.max_value
		bx = ax + (self.width * ratio)
		if ratio > 0 then
			rectfill(ax, ay, bx, by, 10)
		end
	end

	return obj
end

act.player = {}
act.player.new = function()
	local obj = act.chara.new()
	obj.chara_init = obj.init
	obj.chara_update_pre_animation = obj.update_pre_animation
	obj.chara_update_aft_animation = obj.update_aft_animation
	obj.chara_draw = obj.draw

	-- const
	obj.box_ofs_x = -4
	obj.box_ofs_y = -7

	-- variable
	obj.id = 1
	obj.action = "none"
	obj.anim_state = "idle"
	obj.request_pos = math.vec2.new(0, 0)
	obj.atk_hitbox = hit.data.new(obj)
	obj.weapon = act.weapon.new()
	obj.is_req_atk = false
	obj.insert_action = nil
	obj.is_damage = false

	-- stamina
	local max_stamina = 100
	obj.stamina = act.stamina.new(max_stamina)
	local stamina_meter_offset_y = -10
	obj.stamina_meter = act.meter.new(max_stamina, stamina_meter_offset_y)

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

	obj.draw = function(self)
		-- stamina
		self.stamina_meter:draw()

		-- chara
		if self.id == 1 then
			obj:chara_draw()
		else
			obj:chara_draw(8, 9)
		end

		-- weapon
		local wpn_dir = "left"
		if self.spr_idx == 3 then
			wpn_dir = "right"
		end

		local is_mirror = (self.direction == "left")
		self.weapon:draw(
			self.pos.x, self.pos.y
			,self.spr_idx, wpn_dir, is_mirror)
	end

	obj.update_pre_animation = function(self, delta_time)
		self:chara_update_pre_animation()
		self:update_action()
		self:update_stamina_is_reduce()
		self:update_anim_state()
		self.stamina:update(delta_time)
	end

	obj.update_aft_animation = function(self, delta_time)
		self:chara_update_aft_animation()
		self:update_request_pos()
		self:apply_request_pos()
		self:proc_req_atk()
		self.stamina_meter:update(self.pos.x, self.pos.y, self.stamina.value)

		self.insert_action = nil
	end

	obj.update_action = function(self)
		if self.insert_action != nil then
			self.action = self.insert_action
			return
		end

		if self.anim_controller.is_end == false then
			return
		end

		local pl_idx = (self.id -1)
		if btnp(4, pl_idx) then
			self.action = "slash"
			return
		end

		if btn(5, pl_idx) then
			if self.stamina:is_empty() then
				self.action = "cant_guard"
			else
				self.action = "guard"
			end
			return
		end

		self.action = "idle"
	end

	obj.update_stamina_is_reduce = function(self)
		local is_reduce = (
			self.action == "guard"
			or self.action == "cant_guard"
			)
		self.stamina:set_is_reduce(is_reduce)
	end

	obj.update_anim_state = function(self)
		local state = self.action

		if self:should_set_anim(state) then
			self.anim_state = state
			local state = "pl_" .. self.anim_state
			self.anim_controller:set(state)
		end
	end

	obj.should_set_anim = function(self, state)
		if self.anim_state != state then
			return true
		end

		if self.insert_action == "damage" then
			return true
		end

		return false
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

	obj.proc_req_atk = function(self)
		if self.is_req_atk then
			self:regist_atk_hitbox()
			self.is_req_atk = false
		end
	end

	obj.regist_atk_hitbox = function(self)
		local x = self.pos.x
		local y = self.pos.y

		self.atk_hitbox:set_offset(0, -7)
		self.atk_hitbox:set_pos(x, y)
		add(hit_checker.atk_list, self.atk_hitbox)
	end

	obj.callback_anim_change = function(self, tag)
		if tag == "regist_atk" then
			self.is_req_atk = true
		end
	end

	obj.atk_callback = function(self, def_box)
		if def_box.owner.action == "guard" then
			self.insert_action = "reflect"
		end
	end

	obj.def_callback = function(self, atk_box)
		if self.action == "guard" then
			self.insert_action = "guard_scc"
			shake_offset = 0.15
			self.stamina:request_recover()
			request_cam_eff_color = 10
			return
		end

		self.insert_action = "damage"
		shake_offset = 0.25
		request_cam_eff_color = 8
	end

	obj.dbg_draw_stamina = function(self)
		local v = self.stamina.value
		print(v, self.pos.x, self.pos.y - 16)
	end

	obj.check_floor = function(self)
		local x = self.pos.x
		local ofs_x = 4
		if self.direction == "right" then
			x += ofs_x
		else
			x -= ofs_x
		end

		return check_floor(x, self.pos.y + 1)
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
			--qlocal gap = 8

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

	obj.check_out_floor = function(self)
		for i = 1, self.max_count do
			local pl = self.list[i]
			if not pl:check_floor() then
				return i
			end
		end

		return 0
	end

	obj.dbg_draw_pos = function(self)
		foreach(self.list, function(obj) obj:dbg_draw_pos() end)
		foreach(self.list, function(obj) obj:dbg_draw_stamina() end)
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

-- end message --
act.end_message = {}
act.end_message.new = function()
	local obj = {}

	obj.center = 64
	obj.box_height = 10
	obj.winner = 0

	obj.draw = function(self)
		self:draw_back()
		self:draw_message()
	end

	obj.draw_message = function(self)
		local x = 64 - (4 * 4) -- char size * char count
		local y = self.center - 4
		local message = self.winner .. "P    WIN."
		print(message, x, y, 7)
	end

	obj.draw_back = function(self)
		local half_height = self.box_height * 0.5

		local ax = 0
		local ay = self.center - half_height
		local bx = 128
		local by = self.center + half_height

		rectfill(ax, ay, bx, by, 1)
	end

	return obj
end

-- global --
local map_info = act.map_info.new()
local player_list = sys.player_list.new()
local end_message = act.end_message.new()

local sequence = "battle"
function update_sequence()
	local out_player_idx = player_list:check_out_floor()
	if out_player_idx == 0 then
		return
	end

	if out_player_idx == 1 then
		end_message.winner = 2
	elseif out_player_idx == 2 then
		end_message.winner = 1
	end

	sequence = "end"
end

-- system --
function _init()
	player_list:init()
end

function _update()
	if sequence == "battle" then
		hit_checker:check()
		player_list:update()
		update_sequence()
	end

	dbg_print:update()
end

function _draw()
	screen_shake()

	map_info:draw()
	player_list:draw()

	if sequence == "end" then
		end_message:draw()
	end
	--draw_camera_effect()

	-- dbg
	--hit_checker:debug_draw()
	--player_list:dbg_draw_pos()
	dbg_print:draw()
end

__gfx__
11000000000000001100000011000000000000701100000011000000000070000110000000000000000000000000000000000000000000000000000000000000
01111110110000000111111001111110110006571111110011111100110657000011111100000000000000000000000000000000000000000000000000000000
0ffffff0011111100ffffff00ffffff001111657ffffff00ffffff000116571000ffffff00000000000000000000000000000000000000000000000000000000
0f1fff100ffffff07665ff100f1fff100ffff656f1ff1100665f11000ff657f000f1ff1100000000000000000000000000000000000000000000000000000000
0ffffff00f1fff105555fff00ffffff00f1ff656ffffff00555fff000f16561000ffffff00000000000000000000000000000000000000000000000000000000
502222005ffffff066652200002222050ffff55550222200665222000ff555f06652220000000000000000000000000000000000000000000000000000000000
5f8888005f88880000888000008888f5008888f05f888800008888000088f800555f880000000000000000000000000000000000000000000000000000000000
50f00f0050f00f0000f0000000f00f0500f00f0050f00f0000f00f0000f00f0066500f0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000700000000000000000000000000000077000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000007500000000000000000000000000000755000000000000000000000000000000000000000000000000000000000000000000000000
00007766000077660000000666770000000000000000776600000066000000000000007700000000000000000000000000000000000000000000000000000000
00075555000755550000000055557000000000000007555500000000000000000000075500000000000000000000000000000000000000000000000000000000
00006666000066660000000066660000000000000000666600000000000000000000006600000000000000000000000000000000000000000000000000000000
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
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181808080808080808080808080818181810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8181818181818181818181818181818181818100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
