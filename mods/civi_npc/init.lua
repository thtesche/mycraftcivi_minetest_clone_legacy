print("[myCraftCivi] Loading civi_npc...")

-- Register the Lumberjack mob
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
            self.inv = { wood = 0, saplings = 0 }
            self.blacklist = {} -- [pos_hash] = expiration_time
            self.target_failures = 0
        end
        self.blacklist = self.blacklist or {}
        self.target_failures = self.target_failures or 0

        local pos = self.object:get_pos()
        if not pos then return false end

        -- === Obstacle Logic removed: handled by pathfinder ===

        local target = self.target_chest or self.target_tree
        
        -- ==== 1. PATHFINDING LOGIC ====
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
                    local path = pathfinder.find_path(pos, target, self, dtime)
                    if path then
                        self.path_way = path
                        self.target_failures = 0
                    else
                        self.target_failures = self.target_failures + 1
                        if self.target_failures >= 3 then
                            -- Give up on this target
                            local hash = minetest.hash_node_position(target)
                            self.blacklist[hash] = minetest.get_gametime() + 60
                            self.target_tree = nil
                            self.target_chest = nil
                            self.target_failures = 0
                            minetest.chat_send_all("[NPC] Target unreachable. Blacklisting...")
                        end
                    end
                end
            end
        else
            self.path_way = nil
            self.path_timer = 3.1 -- Ready for next target
        end

        -- Move along the path if it exists
        if target and self.path_way and #self.path_way > 0 then
            local next_p = self.path_way[1]
            local d2node = vector.distance({x=pos.x, y=0, z=pos.z}, {x=next_p.x, y=0, z=next_p.z})
            
            if d2node < 0.6 then
                table.remove(self.path_way, 1)
                if #self.path_way == 0 then
                    self:set_velocity(0)
                end
            else
                local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=next_p.x, y=0, z=next_p.z})
                self.object:set_yaw(minetest.dir_to_yaw(direction))
                self:set_velocity(self.walk_velocity)
                self:set_animation("walk")
                self:do_jump()
                
                -- Check if we are physically blocked (stuck)
                self.stuck_timer = (self.stuck_timer or 0) + dtime
                if self.stuck_timer > 5.0 then
                    -- If we are stuck for 5 seconds at the same spot, recalculate path immediately
                    self.path_way = nil
                    self.path_timer = 3.1
                    self.stuck_timer = 0
                end
            end
        end

        -- ==== 2. CHEST LOGIC (Interaction only) ====
        if self.target_chest then
            local target_node = minetest.get_node(self.target_chest)
            if target_node.name ~= "civi_storage:chest" and target_node.name ~= "civi_storage:chest_double" then
                self.target_chest = nil
                return false
            end

            local d2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_chest.x, y=0, z=self.target_chest.z})
            local dy = math.abs(pos.y - self.target_chest.y)

            if d2d <= 1.2 and dy <= 3.0 then
                -- At chest: Interaction
                self:set_velocity(0)
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
                    
                    if self.original_chest_name then
                        local node = minetest.get_node(self.target_chest)
                        minetest.swap_node(self.target_chest, {name = self.original_chest_name, param2 = node.param2})
                        minetest.sound_play("civi_chest_close", {pos = self.target_chest, gain = 0.3, max_hear_distance = 10})
                        self.original_chest_name = nil
                    end
                    self.target_chest = nil
                    self.stuck_timer = 0
                    self.deposit_timer = 0
                    self.search_timer = 1.0
                    self.path_way = nil
                end
            end
            return true
        end

        -- ==== 3. TREE LOGIC (Interaction only) ====
        self.search_timer = (self.search_timer or 0) + dtime
        if not self.target_tree then
            if self.search_timer >= 1.0 then
                self.search_timer = 0
                -- SEARCH FOR NEAREST TREE (Skipping blacklisted)
                local range = 100
                local p1 = {x=pos.x-range, y=pos.y-range, z=pos.z-range}
                local p2 = {x=pos.x+range, y=pos.y+range, z=pos.z+range}
                local found_nodes = minetest.find_nodes_in_area(p1, p2, {"group:tree"})
                local candidates = {}
                local now = minetest.get_gametime()
                for _, p in ipairs(found_nodes) do
                    local hash = minetest.hash_node_position(p)
                    if not self.blacklist[hash] or self.blacklist[hash] < now then
                        table.insert(candidates, p)
                    end
                end

                if #candidates > 0 then
                    -- Sort by distance
                    table.sort(candidates, function(a, b)
                        return vector.distance(pos, a) < vector.distance(pos, b)
                    end)
                    
                    local found_tree = candidates[1]
                    -- Trace down to the root (lowest trunk block)
                    for i = 1, 30 do
                        local under = {x=found_tree.x, y=found_tree.y-1, z=found_tree.z}
                        if minetest.get_item_group(minetest.get_node(under).name, "tree") > 0 then
                            found_tree.y = found_tree.y - 1
                        else break end
                    end
                    self.target_tree = found_tree
                end
                self.stuck_timer = 0
            end
            return false 
        end

        local target_node = minetest.get_node(self.target_tree)
        if minetest.get_item_group(target_node.name, "tree") == 0 then
            self.target_tree = nil
            return false
        end

        local dist_2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_tree.x, y=0, z=self.target_tree.z})
        local dist_y = math.abs(pos.y - self.target_tree.y)

        if dist_2d <= 1.5 and dist_y <= 15.0 then
            -- Chopping
            self:set_velocity(0)
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
                                        self.inv.saplings = self.inv.saplings + stack:get_count()
                                    end
                                end
                                minetest.remove_node(check_pos)
                            elseif minetest.get_item_group(node.name, "leaves") > 0 then
                                local drops = minetest.get_node_drops(node.name, "")
                                for _, item in ipairs(drops) do
                                    local stack = ItemStack(item)
                                    if minetest.get_item_group(stack:get_name(), "sapling") > 0 or stack:get_name() == "civi_core:sapling" then
                                        self.inv.saplings = self.inv.saplings + stack:get_count()
                                    else minetest.add_item(check_pos, item) end
                                end
                                minetest.remove_node(check_pos)
                            end
                        end
                    end
                end

                local nearby_objs = minetest.get_objects_inside_radius(pos, 5)
                for _, obj in ipairs(nearby_objs) do
                    local ent = obj:get_luaentity()
                    if ent and ent.name == "__builtin:item" then
                        local stack = ItemStack(ent.itemstring)
                        if minetest.get_item_group(stack:get_name(), "sapling") > 0 or stack:get_name() == "civi_core:sapling" then
                            self.inv.saplings = self.inv.saplings + stack:get_count()
                            obj:remove()
                        end
                    end
                end

                while self.inv.saplings > 0 do
                    for r = 1, 10 do
                        local rx, ry, rz = self.target_tree.x + math.random(-3, 3), self.target_tree.y + math.random(-2, 2), self.target_tree.z + math.random(-3, 3)
                        local p_under, p_above = {x=rx, y=ry-1, z=rz}, {x=rx, y=ry, z=rz}
                        if (minetest.get_node(p_under).name:find("grass") or minetest.get_node(p_under).name:find("dirt")) and minetest.get_node(p_above).name == "air" then
                            minetest.set_node(p_above, {name = "civi_core:sapling"})
                            break
                        end
                    end
                    self.inv.saplings = self.inv.saplings - 1
                end

                self.target_tree = nil
                if self.inv.wood > 0 then
                    local p = self.object:get_pos()
                    -- Find nearest chest
                    local crange = 100
                    local cp1 = {x=p.x-crange, y=p.y-crange, z=p.z-crange}
                    local cp2 = {x=p.x+crange, y=p.y+crange, z=p.z+crange}
                    local chests = minetest.find_nodes_in_area(cp1, cp2, {"civi_storage:chest", "civi_storage:chest_double"})
                    if #chests > 0 then
                        table.sort(chests, function(a, b)
                            return vector.distance(p, a) < vector.distance(p, b)
                        end)
                        self.target_chest = chests[1]
                    end
                end
                self.path_way = nil
            end
        end
        return true
    end,
})

-- Spawning rule
mobs:spawn({
    name = "civi_npc:lumberjack",
    nodes = {"civi_core:dirt_with_grass"},
    min_light = 10,
    chance = 7000,
    active_object_count = 1,
    min_height = 0,
})


-- Spawn egg for the inventory
mobs:register_egg("civi_npc:lumberjack", "Lumberjack (myCraftCivi)", "civi_wood.png", 1)

-- Load Hut spawning logic
dofile(minetest.get_modpath("civi_npc") .. "/huts.lua")
