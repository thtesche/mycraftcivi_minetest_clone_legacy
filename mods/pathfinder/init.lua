pathfinder = {}

--[[
minetest.get_content_id(name)
minetest.registered_nodes
minetest.get_name_from_content_id(id)
local ivm = a:index(pos.x, pos.y, pos.z)
local ivm = a:indexp(pos)
minetest.hash_node_position({x=,y=,z=})
minetest.get_position_from_hash(hash)

start_index, target_index, current_index
^ Hash of position

current_value
^ {int:hCost, int:gCost, int:fCost, hash:parent, vect:pos}
]]--

local openSet = {}
local closedSet = {}

local function get_distance(start_pos, end_pos)
	local distX = math.abs(start_pos.x - end_pos.x)
	local distZ = math.abs(start_pos.z - end_pos.z)
	
	if distX > distZ then
		return 14 * distZ + 10 * (distX - distZ)
	else
		return 14 * distX + 10 * (distZ - distX)
	end
end

local function get_distance_to_neighbor(start_pos, end_pos)
	local distX = math.abs(start_pos.x - end_pos.x)
	local distY = math.abs(start_pos.y - end_pos.y)
	local distZ = math.abs(start_pos.z - end_pos.z)
	
	if distX > distZ then
		return (14 * distZ + 10 * (distX - distZ)) * (distY + 1)
	else
		return (14 * distX + 10 * (distZ - distX)) * (distY + 1)
	end
end

local function is_door(node_name)
	local groups = minetest.registered_nodes[node_name] and minetest.registered_nodes[node_name].groups or {}
	return groups.door ~= nil or groups.gate ~= nil or string.find(node_name, "doors:door") or string.find(node_name, "doors:hidden")
end

local function is_door_open(node_name, pos)
	if not is_door(node_name) then return false end
	local meta = minetest.get_meta(pos)
	local state = meta:get_int("state")
	-- Check both civi_doors (even/odd state) and open/closed node name pattern
	return (state % 2 == 1) or string.find(node_name, "_open") or string.find(node_name, "_c") or string.find(node_name, "_d")
end

-- node_name and pos are required for accurate door check
local function is_physically_solid(node_name, pos)
	if is_door(node_name) then
		return not is_door_open(node_name, pos)
	end
	local def = minetest.registered_nodes[node_name]
	-- Specifically check height: if any part of the 2-block height is solid, the node-column is "solid" for corner cutting.
	local solid = def and def.walkable
	if not solid then
		local node_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z})
		local def_above = minetest.registered_nodes[node_above.name]
		solid = def_above and def_above.walkable
	end
	return solid
end

local function walkable(node, pos, current_pos)
	-- For A* search purposes, doors are always "passable"
	if is_door(node.name) then
		return false
	end
	local def = minetest.registered_nodes[node.name]
	return def and def.walkable
end

local function get_neighbor_ground_level(pos, jump_height, fall_height, current_pos)
	local node = minetest.get_node(pos)
	local height = 0
	if walkable(node, pos, current_pos) then
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

function pathfinder.find_path(pos, endpos, entity, dtime)
	-- round positions if not done by former functions
	pos = { x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5), z = math.floor(pos.z + 0.5) }
	endpos = { x = math.floor(endpos.x + 0.5), y = math.floor(endpos.y + 0.5), z = math.floor(endpos.z + 0.5) }

	local target_node = minetest.get_node(endpos)
	if walkable(target_node, endpos, endpos) then
		endpos.y = endpos.y + 1
	end

	local start_node = minetest.get_node(pos)
	if is_door(start_node.name) then
		if start_node.param2 == 0 then
			pos.z = pos.z + 1
		elseif start_node.param2 == 1 then
			pos.x = pos.x + 1
		elseif start_node.param2 == 2 then
			pos.z = pos.z - 1
		elseif start_node.param2 == 3 then
			pos.x = pos.x - 1
		end
	end

	local start_time = minetest.get_us_time()
	local start_index = minetest.hash_node_position(pos)
	local target_index = minetest.hash_node_position(endpos)
	local count = 1
	openSet = {}
	closedSet = {}

	local h_start = get_distance(pos, endpos)
	openSet[start_index] = {hCost = h_start, gCost = 0, fCost = h_start, parent = nil, pos = pos}

	-- Entity values
	local entity_height = math.ceil(entity.collisionbox[5] - entity.collisionbox[2]) or 2
	local entity_fear_height = entity.fear_height or 3
	local entity_jump_height = entity.jump_height or 1

	repeat
		local current_index
		local current_values

		-- Get one index as reference from openSet
		for i, v in pairs(openSet) do
			current_index = i
			current_values = v
			break
		end

		-- Search for lowest fCost
		for i, v in pairs(openSet) do
			if v.fCost < openSet[current_index].fCost or v.fCost == current_values.fCost and v.hCost < current_values.hCost then
				current_index = i
				current_values = v
			end
		end

		openSet[current_index] = nil
		closedSet[current_index] = current_values
		count = count - 1

		if current_index == target_index then
			local path = {}
			repeat
				if not closedSet[current_index] then
					return
				end
				table.insert(path, closedSet[current_index].pos)
				current_index = closedSet[current_index].parent
			until start_index == current_index
			table.insert(path, closedSet[current_index].pos)

			local reverse_path = {}
			repeat
				table.insert(reverse_path, table.remove(path))
			until #path == 0
			return reverse_path
		end

		local current_pos = current_values.pos
		local neighbors = {}
		local neighbors_index = 1
		for z = -1, 1 do
			for x = -1, 1 do
				local neighbor_pos = {x = current_pos.x + x, y = current_pos.y, z = current_pos.z + z}
				local node = minetest.get_node(neighbor_pos)
				local neighbor_ground_level = get_neighbor_ground_level(neighbor_pos, entity_jump_height, entity_fear_height, current_pos)
				local neighbor_clearance = false

				if neighbor_ground_level then
					local neighbor_hash = minetest.hash_node_position(neighbor_ground_level)
					local pos_above_head = {x = current_pos.x, y = current_pos.y + entity_height, z = current_pos.z}
					local node_above_head = minetest.get_node(pos_above_head)
					if neighbor_ground_level.y - current_pos.y > 0 and not walkable(node_above_head, pos_above_head, current_pos) then
						local height = -1
						repeat
							height = height + 1
							local pos = { x = neighbor_ground_level.x, y = neighbor_ground_level.y + height, z = neighbor_ground_level.z}
							local n_node = minetest.get_node(pos)
						until walkable(n_node, pos, current_pos) or height > entity_height
						if height >= entity_height then
							neighbor_clearance = true
						end
					elseif neighbor_ground_level.y - current_pos.y > 0 and walkable(node_above_head, pos_above_head, current_pos) then
						neighbors[neighbors_index] = {
							hash = nil,
							pos = nil,
							clear = nil,
							walkable = nil,
							solid = nil,
						}
					else
						local height = -1
						repeat
							height = height + 1
							local pos = { x = neighbor_ground_level.x, y = current_pos.y + height, z = neighbor_ground_level.z}
							local n_node = minetest.get_node(pos)
						until walkable(n_node, pos, current_pos) or height > entity_height
						if height >= entity_height then
							neighbor_clearance = true
						end
					end
					neighbors[neighbors_index] = {
						hash = minetest.hash_node_position(neighbor_ground_level),
						pos = neighbor_ground_level,
						clear = neighbor_clearance,
						walkable = walkable(node, neighbor_pos, current_pos),
						solid = is_physically_solid(node.name, neighbor_pos),
					}
				else
					neighbors[neighbors_index] = {
						hash = nil,
						pos = nil,
						clear = nil,
						walkable = nil,
						solid = nil,
					}
				end
				neighbors_index = neighbors_index + 1
			end
		end

		for id, neighbor in pairs(neighbors) do
			-- don't cut corners
			local cut_corner = false
			if id == 1 then
				if neighbors[2].solid or neighbors[4].solid then
					cut_corner = true
				end
			elseif id == 3 then
				if neighbors[2].solid or neighbors[6].solid then
					cut_corner = true
				end
			elseif id == 7 then
				if neighbors[8].solid or neighbors[4].solid then
					cut_corner = true
				end
			elseif id == 9 then
				if neighbors[8].solid or neighbors[6].solid then
					cut_corner = true
				end
			end

			if neighbor.hash and neighbor.hash ~= current_index and not closedSet[neighbor.hash] and neighbor.clear and not cut_corner then
				local dx = math.abs(current_pos.x - neighbor.pos.x)
				local dz = math.abs(current_pos.z - neighbor.pos.z)
				local move_cost = 10
				if dx > 0 and dz > 0 then
					move_cost = 20 -- Increase diagonal cost to 2x straight cost
				end
				
				-- Wall proximity penalty: avoid hugging solid blocks
				local wall_penalty = 0
				-- Check 4 orthogonal neighbors for solids at both ground and head level
				local check_offsets = {{x=1,z=0},{x=-1,z=0},{x=0,z=1},{x=0,z=-1}}
				for _, offset in ipairs(check_offsets) do
					local npos = {x=neighbor.pos.x+offset.x, y=neighbor.pos.y, z=neighbor.pos.z+offset.z}
					local nnode = minetest.get_node(npos)
					-- Exclude doors from wall penalty to encourage approaching exits
					if is_physically_solid(nnode.name, npos) and not is_door(nnode.name) then
						wall_penalty = wall_penalty + 15 -- Aggressive penalty to stay in center
					end
				end
				move_cost = move_cost + wall_penalty

				-- Door opening penalty remains
				local neighbor_node = minetest.get_node(neighbor.pos)
				if is_door(neighbor_node.name) and not is_door_open(neighbor_node.name, neighbor.pos) then
					move_cost = move_cost + 150
				end

				local move_cost_to_neighbor = current_values.gCost + move_cost
				local gCost = 0
				if openSet[neighbor.hash] then
					gCost = openSet[neighbor.hash].gCost
				end
				if move_cost_to_neighbor < gCost or not openSet[neighbor.hash] then
					if not openSet[neighbor.hash] then
						count = count + 1
					end
					local hCost = get_distance(neighbor.pos, endpos)
					openSet[neighbor.hash] = {
						gCost = move_cost_to_neighbor,
						hCost = hCost,
						fCost = move_cost_to_neighbor + hCost,
						parent = current_index,
						pos = neighbor.pos
					}
				end
			end
		end

		if count > 2000 then
			return
		end

		if (minetest.get_us_time() - start_time) / 1000 > 50 - dtime * 50 then
			return
		end

	until count < 1
	return {pos}
end
