local function is_physically_solid(name, pos)
	local def = minetest.registered_nodes[name]
	if not def then return false end
	if not def.walkable then return false end
	-- Nur Blaetter und Flora (walkable=true aber physikalisch passierbar)
	if minetest.get_item_group(name, "leaves") > 0 then return false end
	-- NICHT grass-Gruppe ausschliessen: civi_core:dirt_with_grass hat grass=1 aber ist solid!
	return true
end

local function walkable(node, pos, current_pos)
	if not node then return false end
	local name = node.name
	local def = minetest.registered_nodes[name]
	if not def then return false end
	if not def.walkable then return false end
	-- Nur Blaetter: walkable=true aber Entitaeten koennen durchgehen
	-- NICHT grass-Gruppe: civi_core:dirt_with_grass hat grass=1 aber ist solid!
	if minetest.get_item_group(name, "leaves") > 0 then return false end
	return true
end

local function is_door(name)
	return name:find("door") or name:find("gate")
end

local function is_door_open(name, pos)
	local node = minetest.get_node(pos)
	if node.param2 == 1 or node.param2 == 3 then return true end
	return false
end

local function hash_node_position(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function get_distance(pos1, pos2)
	return vector.distance(pos1, pos2)
end

local function get_neighbor_ground_level(pos, jump_height, fall_height, current_pos)
	local node = minetest.get_node(pos)
	if walkable(node, pos, current_pos) then
		-- step up
		local height = 0
		repeat
			height = height + 1
			if height > jump_height then
				return nil
			end
			pos.y = pos.y + 1
			node = minetest.get_node(pos)
		until not walkable(node, pos, current_pos)
		return pos
	else
		-- same level or fall
		local node_under = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
		if walkable(node_under, {x = pos.x, y = pos.y - 1, z = pos.z}, current_pos) then
			return pos
		else
			-- falling
			local height = 0
			repeat
				height = height + 1
				if height > fall_height then
					return nil
				end
				pos.y = pos.y - 1
				node = minetest.get_node(pos)
			until walkable(node, pos, current_pos)
			return {x = pos.x, y = pos.y + 1, z = pos.z}
		end
	end
end

pathfinder = {}

function pathfinder.find_path(pos, endpos, entity, dtime)
	if not pos or not endpos then return nil end
	pos = vector.round(pos)
	endpos = vector.round(endpos)

	local entity_jump_height = (entity and entity.jump_height) or 1.1
	local entity_fear_height = (entity and entity.fear_height) or 3
	local entity_height = 2
	
	local start_node = minetest.get_node(pos)
	
	-- Robust Start: If starting inside a solid block, try to find nearby air
	if is_physically_solid(start_node.name, pos) then
		local found_air = false
		local offsets = {{x=0,y=1,z=0}, {x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1}}
		for _, o in ipairs(offsets) do
			local p = vector.add(pos, o)
			if not is_physically_solid(minetest.get_node(p).name, p) then
				pos = p
				start_node = minetest.get_node(pos)
				found_air = true
				break
			end
		end
	end

	local start_index = hash_node_position(pos)
	local target_index = hash_node_position(endpos)

	local openSet = {}
	local closedSet = {}

	openSet[start_index] = {
		gCost = 0,
		hCost = get_distance(pos, endpos),
		fCost = get_distance(pos, endpos),
		pos = pos,
		parent = nil
	}

	local count = 1
	local start_time = minetest.get_us_time()

	local steps_checked = 0
	repeat
		-- 1. Find best node (Min fCost)
		steps_checked = steps_checked + 1
		local current_index = nil
		local current_values = nil

		for i, v in pairs(openSet) do
			if not current_index then
				current_index = i
				current_values = v
			elseif v and current_values and v.fCost and current_values.fCost then
				if v.fCost < current_values.fCost or (v.fCost == current_values.fCost and v.hCost < current_values.hCost) then
					current_index = i
					current_values = v
				end
			end
		end

		if not current_index or not current_values or not current_values.pos then break end

		-- 2. Success Check
		if current_index == target_index or vector.distance(current_values.pos, endpos) < 1.1 then
			local path = {}
			local temp_idx = current_index
			repeat
				-- Look up in closedSet first, fall back to openSet (goal may not be closed yet)
				local node_data = closedSet[temp_idx] or openSet[temp_idx]
				if not node_data then break end  -- dead end in chain, should not happen
				table.insert(path, node_data.pos)
				temp_idx = node_data.parent
			until not temp_idx
			
			local reverse_path = {}
			for i = #path, 1, -1 do table.insert(reverse_path, path[i]) end
			
			-- Visualize path
			for _, p in ipairs(reverse_path) do
				minetest.add_particlespawner({
					amount = 40,
					time = 5,
					minpos = {x=p.x-0.2, y=p.y+1.2, z=p.z-0.2},
					maxpos = {x=p.x+0.2, y=p.y+1.3, z=p.z+0.2},
					minvel = {x=-0.1, y=0.1, z=-0.1},
					maxvel = {x=0.1, y=0.2, z=0.1},
					minacc = {x=0, y=0, z=0},
					maxacc = {x=0, y=0.01, z=0},
					minexptime = 2.0,
					maxexptime = 4.0,
					minsize = 2.0,
					maxsize = 4.0,
					collisiondetection = false,
					vertical = false,
					texture = "heart.png^[colorize:#00FF00:200",
					glow = 10,
				})
			end
			minetest.log("action", "[Pathfinder] SUCCESS: Path found ("..#reverse_path.." nodes, "..steps_checked.." steps checked)")
			return reverse_path
		end

		-- 3. Move current to closed
		openSet[current_index] = nil
		closedSet[current_index] = current_values
		count = count - 1

		-- 4. Check Neighbors
		local current_pos = current_values.pos
		local neighbor_offsets = {
			{x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1},
			{x=1,y=0,z=1}, {x=1,y=0,z=-1}, {x=-1,y=0,z=1}, {x=-1,y=0,z=-1}
		}

		for _, off in ipairs(neighbor_offsets) do
			local n_pos = vector.add(current_pos, off)
			local neighbor_ground = get_neighbor_ground_level(vector.new(n_pos), entity_jump_height, entity_fear_height, current_pos)
			
			if neighbor_ground then
				local n_hash = hash_node_position(neighbor_ground)
				if not closedSet[n_hash] then
					-- Clearance check (head space)
					local head_pos = {x=neighbor_ground.x, y=neighbor_ground.y+1, z=neighbor_ground.z}
					local h_node = minetest.get_node(head_pos)
					if h_node and not is_physically_solid(h_node.name, head_pos) then
						local move_dist = (off.x ~= 0 and off.z ~= 0) and 14 or 10
						local new_gCost = (current_values.gCost or 0) + move_dist
						
						if not openSet[n_hash] or new_gCost < openSet[n_hash].gCost then
							if not openSet[n_hash] then count = count + 1 end
							local h = get_distance(neighbor_ground, endpos)
							openSet[n_hash] = {
								gCost = new_gCost,
								hCost = h,
								fCost = new_gCost + h,
								pos = neighbor_ground,
								parent = current_index
							}
						end
					end
				end
			end
		end

		if count > 30000 or (minetest.get_us_time() - start_time)/1000 > 500 then
			break
		end
	until count < 1

	-- Failure Diagnostics
	minetest.chat_send_all("[Pathfinder] FAIL: Search limit reached after "..steps_checked.." steps (count="..count..").")
	local audit = "[Pathfinder] TARGET AUDIT at "..minetest.pos_to_string(endpos)..": "
	local adirs = {{x=1,y=0,z=0},{x=-1,y=0,z=0},{x=0,y=0,z=1},{x=0,y=0,z=-1},{x=0,y=1,z=0},{x=0,y=-1,z=0}}
	for _, d in ipairs(adirs) do
		local p = vector.add(endpos, d)
		audit = audit .. minetest.get_node(p).name .. ", "
	end
	minetest.chat_send_all(audit)
	return nil
end

-- Load interactive debug commands (/p2nt, /p2stop)
dofile(minetest.get_modpath("pathfinder") .. "/commands.lua")
