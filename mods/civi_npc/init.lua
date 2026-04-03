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
        -- Init internal inventory
        if not self.inv then
            self.inv = { wood = 0, saplings = 0 }
        end

        local pos = self.object:get_pos()
        if not pos then return false end

        -- === Obstacle Logic: Prevent Stuck by trees/leaves/fences ===
        self.obstacle_timer = (self.obstacle_timer or 0) + dtime
        if self.obstacle_timer > 0.5 then
            self.obstacle_timer = 0
            local p = vector.round(pos)
            local check_positions = {
                {x=p.x, y=p.y+1, z=p.z}, -- Head level
                {x=p.x, y=p.y+2, z=p.z}, -- Above head
            }
            local yaw = self.object:get_yaw()
            if yaw then
                local dir_x = -math.sin(yaw)
                local dir_z = math.cos(yaw)
                local front_p = vector.round({x=pos.x + dir_x, y=pos.y, z=pos.z + dir_z})
                table.insert(check_positions, {x=front_p.x, y=front_p.y, z=front_p.z})
                table.insert(check_positions, {x=front_p.x, y=front_p.y+1, z=front_p.z})
                table.insert(check_positions, {x=front_p.x, y=front_p.y+2, z=front_p.z})
            end
            for _, cp in ipairs(check_positions) do
                local node = minetest.get_node(cp)
                
                -- 1. Tree/Leaves Clearing
                if minetest.get_item_group(node.name, "tree") > 0 or minetest.get_item_group(node.name, "leaves") > 0 then
                    if minetest.get_item_group(node.name, "tree") > 0 then
                        local drops = minetest.get_node_drops(node.name, "")
                        for _, item in ipairs(drops) do
                            local stack = ItemStack(item)
                            if minetest.get_item_group(stack:get_name(), "tree") > 0 or stack:get_name() == "civi_core:tree" then
                                self.inv.wood = self.inv.wood + stack:get_count()
                            end
                        end
                    end
                    minetest.remove_node(cp)
                    if self.target_tree and cp.x == self.target_tree.x and cp.y == self.target_tree.y and cp.z == self.target_tree.z then
                        self.target_tree = nil
                    end
                end

                -- 2. Gate interaction: Open closed gates
                if minetest.get_item_group(node.name, "gate") > 0 then
                    -- Check if it's a closed gate (usually looks like *_closed)
                    if node.name:find("_closed") then
                        -- Use the doors mod toggle function (requires doors to be loaded)
                        if doors and doors.fencegate_toggle then
                            doors.fencegate_toggle(cp, node, self.object)
                        end
                    end
                end

                -- 3. Fences: The pathfinding (pathfinding=2) and jump_height (1.6) 
                -- will handle jumping over or avoiding fences. We do NOT remove them.
            end
        end

        -- ==== 1. CHEST LOGIC ====
        if self.target_chest then
            local target_node = minetest.get_node(self.target_chest)
            if target_node.name ~= "civi_storage:chest" and target_node.name ~= "civi_storage:chest_double" then
                self.target_chest = nil -- Chest was removed or invalid
                return false
            end

            local d2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_chest.x, y=0, z=self.target_chest.z})
            local dy = math.abs(pos.y - self.target_chest.y)

            if d2d > 1.2 or dy > 3.0 then
                -- Walk towards chest
                local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=self.target_chest.x, y=0, z=self.target_chest.z})
                self.object:set_yaw(minetest.dir_to_yaw(direction))
                self:set_velocity(self.walk_velocity)
                self:set_animation("walk")
                self:do_jump()

                -- Anti-Stuck Logic
                self.stuck_timer = (self.stuck_timer or 0) + dtime
                if self.stuck_timer > 20.0 then
                    print("[civi_npc] Lumberjack stuck at chest, resetting target")
                    self.target_chest = nil
                    self.stuck_timer = 0
                end
            else
                -- At chest: Deposit and Craft Sequence (2 seconds)
                self:set_velocity(0)
                self:set_animation("punch")
                
                self.deposit_timer = (self.deposit_timer or 0) + dtime
                
                -- Start: Open the chest
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
                        
                        if boards > 0 then
                            inv:add_item("main", ItemStack("civi_core:wood " .. boards))
                        end
                        if remaining_wood > 0 then
                            inv:add_item("main", ItemStack("civi_core:tree " .. remaining_wood))
                        end
                        self.inv.wood = 0
                        print("[civi_npc] Lumberjack deposited wood and boards")
                    end
                    
                    -- End: Close the chest
                    if self.original_chest_name then
                        local node = minetest.get_node(self.target_chest)
                        minetest.swap_node(self.target_chest, {name = self.original_chest_name, param2 = node.param2})
                        minetest.sound_play("civi_chest_close", {pos = self.target_chest, gain = 0.3, max_hear_distance = 10})
                        self.original_chest_name = nil
                    end

                    self.target_chest = nil
                    self.stuck_timer = 0
                    self.deposit_timer = 0
                    self.search_timer = 1.0 -- Force tree search in next tick
                end
            end
            return true
        end

        -- ==== 2. TREE LOGIC ====
        -- Search Timer: Save performance, only search 1x per second
        self.search_timer = (self.search_timer or 0) + dtime
        
        -- Do we not have a target tree yet? Then search every 1 sec:
        if not self.target_tree then
            if self.search_timer >= 1.0 then
                self.search_timer = 0
                local found_tree = minetest.find_node_near(pos, 150, {"group:tree"})
                if found_tree then
                    -- Trace down to the root (lowest trunk block)
                    for i = 1, 30 do
                        local under = {x=found_tree.x, y=found_tree.y-1, z=found_tree.z}
                        if minetest.get_item_group(minetest.get_node(under).name, "tree") > 0 then
                            found_tree.y = found_tree.y - 1
                        else
                            break
                        end
                    end
                    self.target_tree = found_tree
                end
                self.stuck_timer = 0 -- Start timeout for getting stuck
            end
            
            -- Since we don't have a target, let the standard AI roam normally
            return false 
        end

        -- Check if the tree might have been mined by a player in the meantime
        local target_node = minetest.get_node(self.target_tree)
        if minetest.get_item_group(target_node.name, "tree") == 0 then
            self.target_tree = nil
            return false
        end

        -- horizontal distance check
        local dist_2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=self.target_tree.x, y=0, z=self.target_tree.z})
        local dist_y = math.abs(pos.y - self.target_tree.y)

        if dist_2d > 0.8 then
            -- STILL TOO FAR HORIZONTALLY: Walk towards the target's X/Z
            local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=self.target_tree.x, y=0, z=self.target_tree.z})
            self.object:set_yaw(minetest.dir_to_yaw(direction))
            self:set_velocity(self.walk_velocity)
            self:set_animation("walk")
            self:do_jump()
            
            -- Anti-Stuck Logic
            self.stuck_timer = (self.stuck_timer or 0) + dtime
            if self.stuck_timer > 15.0 then
                self.target_tree = nil
                self.stuck_timer = 0
            end
        elseif dist_y > 15.0 then
            -- AT THE CORRECT X/Z, but wood is too high?
            self:set_velocity(0)
            self:set_animation("stand")
        else
            -- 2. CLOSE ENOUGH: Start chopping!
            self:set_velocity(0)
            self:set_animation("punch")
            
            -- The lumberjack takes 2 seconds to chop down the tree (visual feedback)
            self.chopping_timer = (self.chopping_timer or 0) + dtime
            
            if self.chopping_timer > 2.0 then
                self.chopping_timer = 0
                
                -- Area-Sweep: Start from our root-optimized target_tree

                -- Area-Sweep: Increased height to 30 for tall trees and floating logs
                for y_offset = -1, 30 do
                    for x_offset = -3, 3 do
                        for z_offset = -3, 3 do
                            local check_pos = {
                                x = self.target_tree.x + x_offset, 
                                y = self.target_tree.y + y_offset, 
                                z = self.target_tree.z + z_offset
                            }
                            local node = minetest.get_node(check_pos)
                            
                            -- Is it wood or leaves?
                            if minetest.get_item_group(node.name, "tree") > 0 then
                                -- Gather logs into internal inventory
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
                                -- Drop leaves and apples as items, but keep saplings
                                local drops = minetest.get_node_drops(node.name, "")
                                for _, item in ipairs(drops) do
                                    local stack = ItemStack(item)
                                    local name = stack:get_name()
                                    if minetest.get_item_group(name, "sapling") > 0 or name == "civi_core:sapling" then
                                        self.inv.saplings = self.inv.saplings + stack:get_count()
                                    else
                                        minetest.add_item(check_pos, item)
                                    end
                                end
                                minetest.remove_node(check_pos)
                            end
                        end
                    end
                end

                -- Pickup logic: Collect nearby sapling items from the ground
                local nearby_objs = minetest.get_objects_inside_radius(pos, 5)
                for _, obj in ipairs(nearby_objs) do
                    local ent = obj:get_luaentity()
                    if ent and ent.name == "__builtin:item" then
                        local stack = ItemStack(ent.itemstring)
                        local name = stack:get_name()
                        if minetest.get_item_group(name, "sapling") > 0 or name == "civi_core:sapling" then
                            self.inv.saplings = self.inv.saplings + stack:get_count()
                            obj:remove()
                        end
                    end
                end

                -- Replant-Logic: Plant gathered saplings
                while self.inv.saplings > 0 do
                    for r = 1, 10 do
                        local rx = self.target_tree.x + math.random(-3, 3)
                        local ry = self.target_tree.y + math.random(-2, 2)
                        local rz = self.target_tree.z + math.random(-3, 3)
                        
                        local p_under = {x=rx, y=ry-1, z=rz}
                        local p_above = {x=rx, y=ry, z=rz}
                        local n_under = minetest.get_node(p_under)
                        local n_above = minetest.get_node(p_above)
                        
                        if (n_under.name == "civi_core:dirt_with_grass" or n_under.name == "civi_core:dirt") and n_above.name == "air" then
                            minetest.set_node(p_above, {name = "civi_core:sapling"})
                            break
                        end
                    end
                    -- Consume sapling even if no valid planting spot was found
                    self.inv.saplings = self.inv.saplings - 1
                end

                -- Job is done, discard target tree
                self.target_tree = nil
                
                -- Check for chest delivery
                if self.inv.wood > 0 then
                    local p = self.object:get_pos()
                    self.target_chest = minetest.find_node_near(p, 300, {"civi_storage:chest", "civi_storage:chest_double"})
                end
            end
        end
        
        -- IMPORTANT: Replaces mobs behavior only as long as they work as a lumberjack
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
