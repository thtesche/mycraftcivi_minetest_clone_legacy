print("[myCraftCivi] Loading civi_npc...")

-- Register the Lumberjack mob
mobs:register_mob("civi_npc:lumberjack", {
    type = "npc",
    passive = true, 
    hp_min = 20,
    hp_max = 20,
    collisionbox = {-0.3, -0.0, -0.3, 0.3, 1.8, 0.3},
    visual = "mesh",
    mesh = "character.b3d", 
    textures = {
        {"character.png"}, 
    },
    makes_footstep_sound = true,
    walk_velocity = 1.5,
    run_velocity = 3,
    water_damage = 0,
    lava_damage = 4,
    fall_damage = 0,
    view_range = 15,

    do_custom = function(self, dtime)
        -- Search Timer: Save performance, only search 1x per second
        self.search_timer = (self.search_timer or 0) + dtime
        
        -- Do we not have a target tree yet? Then search every 1 sec:
        if not self.target_tree then
            if self.search_timer >= 1.0 then
                self.search_timer = 0
                local pos = self.object:get_pos()
                if pos then
                    self.target_tree = minetest.find_node_near(pos, 10, {"group:tree"})
                    self.stuck_timer = 0 -- Start timeout for getting stuck
                end
            end
            
            -- Since we don't have a target, let the standard AI roam normally
            return false 
        end

        -- ==== FROM HERE: WE HAVE A TREE TARGETED ====
        local pos = self.object:get_pos()
        if not pos then return false end

        -- Check if the tree might have been mined by a player in the meantime
        local target_node = minetest.get_node(self.target_tree)
        if minetest.get_item_group(target_node.name, "tree") == 0 then
            self.target_tree = nil
            return false
        end

        local dist = vector.distance(pos, self.target_tree)

        if dist > 2.0 then
            -- 1. STILL TOO FAR AWAY: Walk towards it continuously
            local direction = vector.direction(pos, self.target_tree)
            local yaw = minetest.dir_to_yaw(direction)
            
            self.object:set_yaw(yaw)
            self:set_velocity(self.walk_velocity)
            self:set_animation("walk")

            -- Anti-Stuck Logic: If they don't arrive after 10 seconds (mountain etc.), give up
            self.stuck_timer = (self.stuck_timer or 0) + dtime
            if self.stuck_timer > 10.0 then
                self.target_tree = nil
                self.stuck_timer = 0
            end

        else
            -- 2. CLOSE ENOUGH: Start chopping!
            self:set_velocity(0)
            self:set_animation("punch")
            
            -- The lumberjack takes 2 seconds to chop down the tree (visual feedback)
            self.chopping_timer = (self.chopping_timer or 0) + dtime
            
            if self.chopping_timer > 2.0 then
                self.chopping_timer = 0
                
                -- Area-Sweep: Y-Offset starts at -1 in case the targeted block was the middle trunk
                for y_offset = -1, 7 do
                    for x_offset = -2, 2 do
                        for z_offset = -2, 2 do
                            local check_pos = {
                                x = self.target_tree.x + x_offset, 
                                y = self.target_tree.y + y_offset, 
                                z = self.target_tree.z + z_offset
                            }
                            local node = minetest.get_node(check_pos)
                            
                            -- Is it wood or leaves?
                            if minetest.get_item_group(node.name, "tree") > 0 or minetest.get_item_group(node.name, "leaves") > 0 then
                                minetest.dig_node(check_pos)
                            end
                        end
                    end
                end

                -- Replant-Logic (Plant sapling)
                local node_below = minetest.get_node({x=self.target_tree.x, y=self.target_tree.y-1, z=self.target_tree.z})
                if node_below.name == "civi_core:dirt_with_grass" or node_below.name == "civi_core:dirt" then
                    minetest.set_node(self.target_tree, {name = "civi_core:sapling"})
                end

                -- Job is done, discard target so they search for a new tree
                self.target_tree = nil
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
