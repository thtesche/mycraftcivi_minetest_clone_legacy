-- Programs for civi_npc using advanced_npc API

-- Program 1: Chop Tree
-- This program is executed when a tree is found.
-- Arguments: { pos = {x,y,z} }
npc.programs.register("civi_npc:chop_tree", function(self, args)
    local tree_pos = args.pos or "calculated_target_pos"
    if not tree_pos then
        npc.log("ERROR", "civi_npc:chop_tree called without position")
        return
    end

    -- 1. Walk to tree
    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
        new_program = "civi_npc:walk_to_pos_robust",
        new_args = {
            end_pos = tree_pos,
            use_access_node = true
        }
    })

    -- 2. Wait at tree and chop
    npc.exec.proc.enqueue(self, "advanced_npc:set_animation", {
        start_frame = npc.ANIMATION_MINE_START,
        end_frame = npc.ANIMATION_MINE_END,
        frame_speed = (self.animation and self.animation.speed_normal) or 30
    })
    npc.exec.proc.enqueue(self, "advanced_npc:wait", {time = 2})

    -- 3. Actual chopping logic (instruction)
    npc.exec.proc.enqueue(self, "civi_npc:do_manual_chop", {pos = tree_pos})
    
    -- 4. Reset animation
    npc.exec.proc.enqueue(self, "advanced_npc:set_animation", {
        start_frame = npc.ANIMATION_STAND_START,
        end_frame = npc.ANIMATION_STAND_END,
        frame_speed = (self.animation and self.animation.speed_normal) or 30
    })
end)


-- Instruction for the actual node removal and gathering
npc.programs.instr.register("civi_npc:do_manual_chop", function(self, args)
    local tree_pos = args.pos
    if not tree_pos then return end

    -- Re-check if it's still a tree
    local node = minetest.get_node(tree_pos)
    if minetest.get_item_group(node.name, "tree") == 0 then return end

    -- Check distance
    local pos = self.object:get_pos()
    if vector.distance(pos, tree_pos) > 4 then
        npc.log("WARNING", "Lumberjack too far from tree to chop: "..vector.distance(pos, tree_pos))
        return
    end

    -- Find base trunk (to clear the whole tree)
    local base_pos = {x=tree_pos.x, y=tree_pos.y, z=tree_pos.z}
    for i = 1, 20 do
        local under = {x=base_pos.x, y=base_pos.y-1, z=base_pos.z}
        if minetest.get_item_group(minetest.get_node(under).name, "tree") > 0 then
            base_pos.y = base_pos.y - 1
        else
            break
        end
    end

    -- Sweep area
    local gathered_saplings = 0
    for y_offset = -1, 15 do
        for x_offset = -3, 3 do
            for z_offset = -3, 3 do
                local check_pos = {
                    x = base_pos.x + x_offset, 
                    y = base_pos.y + y_offset, 
                    z = base_pos.z + z_offset
                }
                local n = minetest.get_node(check_pos)
                
                if minetest.get_item_group(n.name, "tree") > 0 then
                    local drops = minetest.get_node_drops(n.name, "")
                    for _, item in ipairs(drops) do
                        local stack = ItemStack(item)
                        if minetest.get_item_group(stack:get_name(), "tree") > 0 or stack:get_name() == "civi_core:tree" then
                            npc.add_item_to_inventory_itemstring(self, item)
                        elseif minetest.get_item_group(stack:get_name(), "sapling") > 0 or stack:get_name() == "civi_core:sapling" then
                            gathered_saplings = gathered_saplings + stack:get_count()
                        end
                    end
                    minetest.remove_node(check_pos)
                elseif minetest.get_item_group(n.name, "leaves") > 0 then
                    local drops = minetest.get_node_drops(n.name, "")
                    for _, item in ipairs(drops) do
                        local stack = ItemStack(item)
                        local name = stack:get_name()
                        if minetest.get_item_group(name, "sapling") > 0 or name == "civi_core:sapling" then
                            gathered_saplings = gathered_saplings + stack:get_count()
                        else
                            minetest.add_item(check_pos, item)
                        end
                    end
                    minetest.remove_node(check_pos)
                end
            end
        end
    end

    -- Replant saplings
    while gathered_saplings > 0 do
        for r = 1, 10 do
            local rx = base_pos.x + math.random(-3, 3)
            local ry = base_pos.y + math.random(-2, 2)
            local rz = base_pos.z + math.random(-3, 3)
            
            local p_under = {x=rx, y=ry-1, z=rz}
            local p_above = {x=rx, y=ry, z=rz}
            local n_under = minetest.get_node(p_under)
            local n_above = minetest.get_node(p_above)
            
            if (n_under.name == "civi_core:dirt_with_grass" or n_under.name == "civi_core:dirt") and n_above.name == "air" then
                minetest.set_node(p_above, {name = "civi_core:sapling"})
                break
            end
        end
        gathered_saplings = gathered_saplings - 1
    end
end)

-- Robust movement program (inspired by sociedades)
npc.programs.register("civi_npc:walk_to_pos_robust", function(self, args)
    local use_access_node = args.use_access_node or false
    local end_pos, node_pos = npc.programs.helper.get_pos_argument(self, args.end_pos, use_access_node)
    
    if not end_pos then 
        npc.log("WARNING", "civi_npc:walk_to_pos_robust called without valid position: "..dump(args.end_pos))
        return 
    end
    
    local walkable_nodes = {
        "civi_core:dirt_with_grass",
        "civi_core:dirt",
        "civi_core:stone",
        "civi_core:sand",
        "civi_core:gravel",
        "civi_core:cobble",
        "civi_core:tree",
        "default:dirt_with_grass",
        "default:dirt",
        "default:stone",
        "default:sand",
        "default:gravel"
    }

    local current_pos = self.object:get_pos()
    local dist = vector.distance(current_pos, end_pos)
    
    -- If target is far, break into segments
    if dist > 12 then
        local segment_dist = 8
        local dir = vector.direction(current_pos, end_pos)
        local target_segment_pos = vector.add(current_pos, vector.multiply(dir, segment_dist))
        
        -- Walk to segment
        npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
            new_program = "advanced_npc:walk_to_pos",
            new_args = {
                end_pos = target_segment_pos,
                use_access_node = false,
                walkable = walkable_nodes,
                enforce_move = true
            }
        })
        
        -- Recursively call robust walk until close
        npc.exec.proc.enqueue(self, "civi_npc:walk_to_pos_robust", {
            end_pos = end_pos,
            use_access_node = use_access_node
        })
    else
        -- Close enough, final walk
        npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
            new_program = "advanced_npc:walk_to_pos",
            new_args = {
                end_pos = end_pos,
                use_access_node = use_access_node,
                walkable = walkable_nodes,
                enforce_move = true
            }
        })
    end
end)

-- Program 2: Deliver to Chest
npc.programs.register("civi_npc:deliver_to_chest", function(self, args)
    -- 1. Find nearest chest
    local pos = self.object:get_pos()
    local chest_pos = minetest.find_node_near(pos, 300, {"civi_storage:chest", "civi_storage:chest_double"})
    
    if not chest_pos then
        npc.log("DEBUG", "Lumberjack could not find a chest for delivery")
        return
    end

    -- Save chest pos for access in instructions
    npc.locations.add_shared_accessible_place(
        self, {owner="", node_pos=chest_pos}, "chest_pos", true, {})

    -- 2. Walk to chest
    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
        new_program = "civi_npc:walk_to_pos_robust",
        new_args = {
            end_pos = "chest_pos",
            use_access_node = true
        }
    })

    -- 3. Wait at chest
    npc.exec.proc.enqueue(self, "advanced_npc:wait", {time = 1})

    -- 4. Deposit
    npc.exec.proc.enqueue(self, "civi_npc:do_deposit", {pos = "chest_pos"})
end)

npc.programs.instr.register("civi_npc:do_deposit", function(self, args)
    local target = args.pos or "chest_pos"
    local chest_pos = npc.programs.helper.get_pos_argument(self, target, false)
    if not chest_pos then return end
    
    local meta = minetest.get_meta(chest_pos)
    local inv = meta:get_inventory()
    if not inv then return end

    -- Move everything from internal inventory to chest
    for i, item_string in pairs(self.inventory) do
        if item_string ~= "" then
            local stack = ItemStack(item_string)
            if inv:room_for_item("main", stack) then
                inv:add_item("main", stack)
                self.inventory[i] = "" -- Clear from NPC inventory
            end
        end
    end
end)

-- State Program: Main Behavior
npc.programs.register("civi_npc:lumberjack_behavior", function(self, args)
    -- 1. Check if we have wood to deliver
    local has_wood = false
    for _, item_string in pairs(self.inventory) do
        if item_string ~= "" then
            local stack = ItemStack(item_string)
            if minetest.get_item_group(stack:get_name(), "tree") > 0 then
                has_wood = true
                break
            end
        end
    end

    if has_wood then
        npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
            new_program = "civi_npc:deliver_to_chest",
            new_args = {}
        })
        return
    end

    -- 2. Otherwise search for trees
    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
        new_program = "advanced_npc:node_query",
        new_args = {
            range = 100,
            nodes = {"group:tree", "civi_core:tree"},
            on_found_executables = {
                ["group:tree"] = {
                    {
                        program_name = "civi_npc:chop_tree",
                        arguments = {} 
                    }
                },
                ["civi_core:tree"] = {
                    {
                        program_name = "civi_npc:chop_tree",
                        arguments = {}
                    }
                }
            },
            on_not_found_executables = {
                [1] = {
                    program_name = "advanced_npc:wander",
                    arguments = {chance = 50, radius = 10}
                }
            }
        }
    })
end)
