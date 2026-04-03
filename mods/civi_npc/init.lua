print("[myCraftCivi] Loading civi_npc...")

-- Register the Lumberjack mob
-- Table to map tree trunks to their respective saplings for smart replanting
local trunk_to_sapling = {
    ["civi_core:tree"] = "civi_core:sapling",
    ["civi_core:acacia_tree"] = "civi_core:acacia_sapling",
    ["civi_core:aspen_tree"] = "civi_core:aspen_sapling",
    ["civi_core:jungletree"] = "civi_core:jungle_sapling",
    ["civi_core:pine_tree"] = "civi_core:pine_sapling",
}

-- Utility: Find a valid air node next to a target where the NPC can stand
local function find_standing_spot(target_pos)
    local neighbor_offsets = {
        {x=1,z=0}, {x=-1,z=0}, {x=0,z=1}, {x=0,z=-1},
        {x=1,z=1}, {x=-1,z=-1}, {x=1,z=-1}, {x=-1,z=1}
    }
    -- Check at same Y, Y-1, Y+1 (Prioritize ground level)
    for _, dy in ipairs({0, -1, 1}) do
        for _, off in ipairs(neighbor_offsets) do
            local p = {x=target_pos.x+off.x, y=target_pos.y+dy, z=target_pos.z+off.z}
            local node = minetest.get_node(p)
            local node_below = minetest.get_node({x=p.x, y=p.y-1, z=p.z})
            local node_above = minetest.get_node({x=p.x, y=p.y+1, z=p.z})
            
            local def = minetest.registered_nodes[node.name]
            local def_below = minetest.registered_nodes[node_below.name]
            local def_above = minetest.registered_nodes[node_above.name]

            if def and not def.walkable and 
               def_below and def_below.walkable and
               def_above and not def_above.walkable then
                return p
            end
        end
    end
    return nil
end

mobs:register_mob("civi_npc:lumberjack", {
    type = "npc",
    passive = true, 
    hp_min = 20,
    hp_max = 20,
    collisionbox = {-0.3, -0.0, -0.3, 0.3, 1.8, 0.3},
    visual = "mesh",
    mesh = "skinsdb_3d_armor_character_5.b3d", 
    textures = {
        "blank.png",              -- Slot 1: 64x32 base
        "character.farmer_male.png", -- Slot 2: 64x64 overlay/modern
        "blank.png",              -- Slot 3: Armor
        "blank.png"               -- Slot 4: Wielded item
    },
    makes_footstep_sound = true,
    walk_velocity = 1.5,
    run_velocity = 3,
    water_damage = 0,
    lava_damage = 4,
    fall_damage = 0,
    pathfinding = 2,
    jump_height = 1.6,
    jump_chance = 80,
    can_leap = true,
    animation = {
        speed_normal = 30,
        speed_run = 30,
        stand_start = 0,
        stand_end = 79,
        walk_start = 168,
        walk_end = 187,
        run_start = 168,
        run_end = 187,
        punch_start = 189,
        punch_end = 198,
    },

    do_custom = function(self, dtime)
        -- Init internal state
        if not self.inv then
            self.inv = { wood = 0, saplings = {} }
            self.blacklist = {} -- [pos_hash] = expiration_time
            self.target_failures = 0
        end
        -- Migration guard: convert old number-format saplings to the new table format
        if type(self.inv.saplings) == "number" then
            self.inv.saplings = {}
        end
        self.greedy_timer = self.greedy_timer or 0
        self.blacklist = self.blacklist or {}
        self.target_failures = self.target_failures or 0

        local pos = self.object:get_pos()
        if not pos then return false end

        -- === Obstacle Logic removed: handled by pathfinder ===

        local target = self.target_chest or self.stand_target or self.target_tree
        
        -- ==== 1. BUSY / INTERACTION LOCK ====
        -- If we are already chopping or delivering, stay stationary and do nothing else.

        -- A. Chest Interaction
        if self.target_chest then
            local target_node = minetest.get_node(self.target_chest)
            if target_node.name ~= "civi_storage:chest" and target_node.name ~= "civi_storage:chest_locked" then
                self.target_chest = nil
            else
                local d2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_chest.x, y=0, z=self.target_chest.z})
                local dy = math.abs(pos.y - self.target_chest.y)

                if d2d <= 2.2 and dy <= 3.0 then
                    self:set_velocity(0)
                    self.path_way = nil
                    self:set_animation("punch")
                    self.deposit_timer = (self.deposit_timer or 0) + dtime
                    
                    if self.deposit_timer < 0.1 then
                        local node = minetest.get_node(self.target_chest)
                        if not self.original_chest_name then
                            self.original_chest_name = node.name
                            if node.name == "civi_storage:chest" or node.name == "civi_storage:chest_locked" then
                                minetest.swap_node(self.target_chest, {name = node.name .. "_open", param2 = node.param2})
                                minetest.sound_play("civi_chest_open", {pos = self.target_chest, gain = 0.3, max_hear_distance = 10})
                            end
                        end
                    end

                    if self.deposit_timer >= 2.0 then
                        local meta = minetest.get_meta(self.target_chest)
                        local inv = meta:get_inventory()
                        local wood_amount = (self.inv.wood or 0)
                        if wood_amount > 0 then
                            local half_wood = math.floor(wood_amount / 2)
                            local boards = half_wood * 4
                            local remaining_wood = wood_amount - half_wood
                            if boards > 0 then inv:add_item("main", ItemStack("civi_core:wood " .. boards)) end
                            if remaining_wood > 0 then inv:add_item("main", ItemStack("civi_core:tree " .. remaining_wood)) end
                            self.inv.wood = 0
                        end

                        -- Deposit all saplings
                        for name, count in pairs(self.inv.saplings) do
                            if count > 0 then
                                inv:add_item("main", ItemStack(name .. " " .. count))
                                self.inv.saplings[name] = 0
                            end
                        end

                        if self.original_chest_name then
                            local node = minetest.get_node(self.target_chest)
                            minetest.swap_node(self.target_chest, {name = self.original_chest_name, param2 = node.param2})
                            minetest.sound_play("civi_chest_close", {pos = self.target_chest, gain = 0.3, max_hear_distance = 10})
                            self.original_chest_name = nil
                        end
                        self.target_chest = nil
                        self.stand_target = nil
                        self.deposit_timer = 0
                        self.search_timer = 1.0
                    end
                    return true -- STAY BUSY
                end
            end
        end

        -- B. Tree Interaction
        if self.target_tree then
            local tnode = minetest.get_node(self.target_tree)
            if minetest.get_item_group(tnode.name, "tree") == 0 then
                self.target_tree = nil
            else
                local dist_2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_tree.x, y=0, z=self.target_tree.z})
                local dist_y = math.abs(pos.y - self.target_tree.y)
                if dist_2d <= 3.0 and dist_y <= 15.0 then
                    self:set_velocity(0)
                    self.path_way = nil
                    self:set_animation("punch")
                    self.chopping_timer = (self.chopping_timer or 0) + dtime
                    if self.chopping_timer > 2.0 then
                        self.chopping_timer = 0
                        for y_offset = -1, 30 do
                            for x_offset = -3, 3 do
                                for z_offset = -3, 3 do
                                    local check_pos = {x = self.target_tree.x + x_offset, y = self.target_tree.y + y_offset, z = self.target_tree.z + z_offset}
                                    local node = minetest.get_node(check_pos)
                                    if minetest.get_item_group(node.name, "tree") > 0 then
                                        local drops = minetest.get_node_drops(node.name, "")
                                        for _, item in ipairs(drops) do
                                            local stack = ItemStack(item)
                                            if minetest.get_item_group(stack:get_name(), "tree") > 0 or stack:get_name() == "civi_core:tree" then
                                                self.inv.wood = self.inv.wood + stack:get_count()
                                            elseif minetest.get_item_group(stack:get_name(), "sapling") > 0 or stack:get_name() == "civi_core:sapling" then
                                                local name = stack:get_name()
                                                self.inv.saplings[name] = (self.inv.saplings[name] or 0) + stack:get_count()
                                            end
                                        end
                                        minetest.remove_node(check_pos)
                                    elseif minetest.get_item_group(node.name, "leaves") > 0 then
                                        local drops = minetest.get_node_drops(node.name, "")
                                        for _, item in ipairs(drops) do
                                            local stack = ItemStack(item)
                                            if minetest.get_item_group(stack:get_name(), "sapling") > 0 or stack:get_name() == "civi_core:sapling" then
                                                local name = stack:get_name()
                                                self.inv.saplings[name] = (self.inv.saplings[name] or 0) + stack:get_count()
                                            else minetest.add_item(check_pos, item) end
                                        end
                                        minetest.remove_node(check_pos)
                                    end
                                end
                            end
                        end
                        
                        -- Smart Replanting
                        local sapling_to_plant = trunk_to_sapling[tnode.name] or "civi_core:sapling"
                        local pos_below = {x=self.target_tree.x, y=self.target_tree.y-1, z=self.target_tree.z}
                        local node_below = minetest.get_node(pos_below)
                        if minetest.get_item_group(node_below.name, "soil") > 0 then
                            -- Check if we have the specific sapling
                            if (self.inv.saplings[sapling_to_plant] or 0) > 0 then
                                minetest.set_node(self.target_tree, {name = sapling_to_plant})
                                self.inv.saplings[sapling_to_plant] = self.inv.saplings[sapling_to_plant] - 1
                                minetest.sound_play("default_place_node", {pos = self.target_tree, gain = 0.5})
                            else
                                -- Fallback to ANY sapling in the table
                                for s_name, count in pairs(self.inv.saplings) do
                                    if count > 0 then
                                        minetest.set_node(self.target_tree, {name = s_name})
                                        self.inv.saplings[s_name] = self.inv.saplings[s_name] - 1
                                        minetest.sound_play("default_place_node", {pos = self.target_tree, gain = 0.5})
                                        break
                                    end
                                end
                            end
                        end

                        self.target_tree = nil
                        self.stand_target = nil
                        self.search_timer = 1.1
                    end
                    return true -- STAY BUSY
                end
            end
        end

        -- ==== 2. PATHFINDING LOGIC ====
        if target then
            self.path_timer = (self.path_timer or 0) + dtime
            
            -- If target changed, reset path
            if not self.last_target or not vector.equals(self.last_target, target) then
                self.path_way = nil
                self.last_target = vector.new(target)
            end

            -- Update path if it doesn't exist or every 3 seconds
            if (not self.path_way or #self.path_way == 0) and self.path_timer > 3.0 then
                self.path_timer = 0
                if pathfinder and pathfinder.find_path then
                    local find_target = self.stand_target or target
                    local path = pathfinder.find_path(pos, find_target, self, dtime)
                    if path then
                        self.path_way = path
                        self.target_failures = 0
                    else
                        self.target_failures = self.target_failures + 1
                        -- Greedy Fallback: try walking directly towards it for 5s
                        self.greedy_timer = 5.0
                        self.greedy_timer = 5.0
                    end
                end
                
                if self.target_failures >= 4 then
                    -- Give up on this target
                    local hash = minetest.hash_node_position(target)
                    self.blacklist[hash] = minetest.get_gametime() + 60
                    self.target_tree = nil
                    self.target_chest = nil
                    self.target_failures = 0
                    minetest.chat_send_all("[NPC] Target unreachable. Entering recovery...")
                end
            end
        else
            self.path_way = nil
            self.path_timer = 3.1 -- Ready for next target
        end

        -- Move along the path if it exists
        if target and self.path_way and #self.path_way > 0 then
            local next_p = self.path_way[1]
            -- Offset to center of node for actual movement
            local target_wp = {x=next_p.x + 0.5, y=next_p.y, z=next_p.z + 0.5}
            local d2node = vector.distance({x=pos.x, y=0, z=pos.z}, {x=target_wp.x, y=0, z=target_wp.z})
            
            -- Arrival threshold: Stop earlier if it's the final node to avoid getting stuck or lunging
            local threshold = (#self.path_way == 1) and 2.2 or 0.6
            if d2node < threshold then
                table.remove(self.path_way, 1)
                if #self.path_way == 0 then
                    self:set_velocity(0)
                end
            else
                local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=target_wp.x, y=0, z=target_wp.z})
                self.object:set_yaw(minetest.dir_to_yaw(direction))
                self:set_velocity(self.walk_velocity)
                self:set_animation("walk")
                
                -- Stuck detection: Only jump if we are truly stuck far from the goal
                local vel = self.object:get_velocity()
                if vel and (math.abs(vel.x) < 0.1 and math.abs(vel.z) < 0.1) and (d2node > 2.2) then
                    self:do_jump()
                end
                
                -- Predictive Jump: If wp is higher, force a jump immediately
                if next_p.y > pos.y + 0.1 then
                    self:do_jump()
                end
                
                -- Reset greedy timer if we found a path
                self.greedy_timer = 0
                
                -- Check if we are physically blocked (stuck)
                self.stuck_timer = (self.stuck_timer or 0) + dtime
                if self.stuck_timer > 2.0 then
                    -- If we are stuck for 2 seconds at the same spot, recalculate path immediately
                    self.path_way = nil
                    self.path_timer = 3.1
                    self.stuck_timer = 0
                end
            end
        end

        -- ==== 1.5 GREEDY FALLBACK MOVEMENT ====

        -- ==== 3. SEARCH LOGIC (Tree or Chest) ====
        self.search_timer = (self.search_timer or 0) + dtime
        if not self.target_tree and not self.target_chest then
            if self.search_timer >= 1.0 then
                self.search_timer = 0
                
                -- 1. CHEST SEARCH (Priority if we have wood)
                if self.inv.wood > 0 then
                    local crange = 110
                    local cp1 = {x=pos.x-crange, y=pos.y-crange, z=pos.z-crange}
                    local cp2 = {x=pos.x+crange, y=pos.y+crange, z=pos.z+crange}
                    local chests = minetest.find_nodes_in_area(cp1, cp2, {"civi_storage:chest", "civi_storage:chest_locked"})
                    if #chests > 0 then
                        table.sort(chests, function(a, b)
                            return vector.distance(pos, a) < vector.distance(pos, b)
                        end)
                        
                        for _, chest_pos in ipairs(chests) do
                            local stand_spot = find_standing_spot(chest_pos)
                            if stand_spot then
                                self.target_chest = chest_pos
                                self.stand_target = stand_spot
                                self.path_timer = 3.1
                                minetest.chat_send_all("[NPC] Heading to chest at "..minetest.pos_to_string(chest_pos))
                                return true
                            else
                                self.blacklist[minetest.hash_node_position(chest_pos)] = minetest.get_gametime() + 300
                            end
                        end
                    end
                end
                
                -- 2. TREE SEARCH (Only if we have no wood)
                if self.inv.wood == 0 then
                    local range = 100
                    local p1 = {x=pos.x-range, y=pos.y-range, z=pos.z-range}
                    local p2 = {x=pos.x+range, y=pos.y+range, z=pos.z+range}
                    local found_nodes = minetest.find_nodes_in_area(p1, p2, {"group:tree"})
                    
                    local roots = {} -- hash -> root_pos
                    local now = minetest.get_gametime()
                    
                    for _, p in ipairs(found_nodes) do
                        local check_pos = vector.new(p)
                        for i = 1, 30 do
                            local under = {x=check_pos.x, y=check_pos.y-1, z=check_pos.z}
                            if minetest.get_item_group(minetest.get_node(under).name, "tree") > 0 then
                                check_pos.y = check_pos.y - 1
                            else break end
                        end
                        
                        local hash = minetest.hash_node_position(check_pos)
                        if not self.blacklist[hash] or self.blacklist[hash] < now then
                            roots[hash] = check_pos
                        end
                    end
                    
                    local candidates = {}
                    for _, root in pairs(roots) do
                        table.insert(candidates, root)
                    end
                    
                    if #candidates > 0 then
                        table.sort(candidates, function(a, b)
                            return vector.distance(pos, a) < vector.distance(pos, b)
                        end)
                        
                        for _, found_root in ipairs(candidates) do
                            local stand_spot = find_standing_spot(found_root)
                            if stand_spot then
                                self.target_tree = found_root
                                self.stand_target = stand_spot
                                self.path_timer = 3.1 -- Force immediate pathfinding
                                minetest.chat_send_all("[NPC] Nearest unique tree found at "..minetest.pos_to_string(found_root))
                                return true
                            else
                                self.blacklist[minetest.hash_node_position(found_root)] = minetest.get_gametime() + 300
                            end
                        end
                    end
                end
                self.stuck_timer = 0
            end
            return false
        end

        return true
    end,
})

-- Spawning rule
-- [[ Spawning rule disabled for debugging
mobs:spawn({
    name = "civi_npc:lumberjack",
    nodes = {"civi_core:dirt_with_grass"},
    min_light = 10,
    chance = 7000,
    active_object_count = 1,
    min_height = 0,
})
-- ]]


-- Spawn egg for the inventory
mobs:register_egg("civi_npc:lumberjack", "Lumberjack (myCraftCivi)", "civi_wood.png", 1)

-- Load Hut spawning logic (Disabled for debugging)
-- dofile(minetest.get_modpath("civi_npc") .. "/huts.lua")
