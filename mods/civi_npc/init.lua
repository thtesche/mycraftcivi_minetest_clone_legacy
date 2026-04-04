print("[myCraftCivi] Loading civi_npc...")

-- Debug-Flags fuer NPC-Kontrolle im laufenden Betrieb
npc_quiet  = true    -- [NPC] Chat-Meldungen unterdruecken (standardmäßig stumm)
npc_paused = false   -- Gesamte NPC-KI einfrieren (auch Pathfinder-Ausgaben stoppen)
npc_debug  = false   -- Detaillierte Pathfinding-Logs pro Aufruf

minetest.register_chatcommand("npc_quiet", {
    description = "[NPC] Chat-Ausgaben ein/ausschalten",
    privs = {interact = true},
    func = function(name, param)
        npc_quiet = not npc_quiet
        return true, "[NPC] Chat: " .. (npc_quiet and "STUMM (Standard)" or "AKTIV")
    end
})

minetest.register_chatcommand("npc_pause", {
    description = "Gesamte NPC-KI pausieren/fortsetzen (stoppt auch Pathfinder-Logs)",
    privs = {interact = true},
    func = function(name, param)
        npc_paused = not npc_paused
        return true, "[NPC] KI: " .. (npc_paused and "PAUSIERT" or "AKTIV")
    end
})

minetest.register_chatcommand("npc_debug", {
    description = "Detaillierte NPC-Pathfinding Logs ein/ausschalten",
    privs = {interact = true},
    func = function(name, param)
        npc_debug = not npc_debug
        return true, "[NPC] Debug: " .. (npc_debug and "AN" or "AUS")
    end
})

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

    -- Kann man physikalisch darin stehen?
    -- Luft, dekorative Flora (walkable=false) und Blaetter = passierbar
    -- WICHTIG: grass-Gruppe NICHT ausschliessen da civi_core:dirt_with_grass group grass=1 hat!
    local function is_passable(name)
        local def = minetest.registered_nodes[name]
        if not def or not def.walkable then return true end   -- Luft, Dekogras, etc.
        if minetest.get_item_group(name, "leaves") > 0 then return true end  -- Blaetter
        return false  -- alle anderen walkable=true Bloecke sind solid
    end

    -- Echter fester Boden (kein Baumstamm, keine Blaetter)?
    local function is_solid_ground(name)
        local def = minetest.registered_nodes[name]
        if not def or not def.walkable then return false end
        if minetest.get_item_group(name, "tree")   > 0 then return false end
        if minetest.get_item_group(name, "leaves") > 0 then return false end
        return true
    end

    local neighbor_offsets = {
        {x=1,z=0}, {x=-1,z=0}, {x=0,z=1},  {x=0,z=-1},
        {x=1,z=1}, {x=-1,z=-1},{x=1,z=-1}, {x=-1,z=1}
    }

    -- Pro Richtung: Y von oben nach unten scannen, ersten gueltigen Standplatz nehmen
    for _, off in ipairs(neighbor_offsets) do
        local cx = target_pos.x + off.x
        local cz = target_pos.z + off.z
        for dy = 3, -5, -1 do
            local cy      = target_pos.y + dy
            local n_here  = minetest.get_node({x=cx, y=cy,   z=cz}).name
            local n_below = minetest.get_node({x=cx, y=cy-1, z=cz}).name
            local n_above = minetest.get_node({x=cx, y=cy+1, z=cz}).name
            if is_passable(n_here) and is_solid_ground(n_below) and is_passable(n_above) then
                -- Muss von der Seite erreichbar sein (kein 1-Block-Loch, das nur von oben zugaenglich ist)
                local horizontal_ok = false
                for _, ho in ipairs({{x=1,z=0},{x=-1,z=0},{x=0,z=1},{x=0,z=-1}}) do
                    if is_passable(minetest.get_node({x=cx+ho.x, y=cy, z=cz+ho.z}).name) then
                        horizontal_ok = true
                        break
                    end
                end
                if horizontal_ok then
                    return {x=cx, y=cy, z=cz}
                end
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
    jump_height = 2.0,
    fear_height = 3,
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
        -- Wenn NPC pausiert ist, sofort zurueck (keine KI, keine Pathfinder-Calls)
        if npc_paused then
            self:set_velocity(0)
            return true
        end

        if not self.inv then
            self.inv = { wood = 0, saplings = {}, items = {} }
            self.blacklist = {} -- [pos_hash] = expiration_time
            self.target_failures = 0
        end
        -- Migration guards
        if type(self.inv.saplings) == "number" then self.inv.saplings = {} end
        if not self.inv.items then self.inv.items = {} end
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
            local tname = target_node.name
            if tname ~= "civi_storage:chest" and tname ~= "civi_storage:chest_locked" and 
               tname ~= "civi_storage:chest_open" and tname ~= "civi_storage:chest_locked_open" then
                if npc_debug then minetest.chat_send_all("[NPC-DBG] Abandoning chest: node is "..tname) end
                self.target_chest = nil
                self.stand_target = nil
            else
                local chest_center = {x=self.target_chest.x + 0.5, y=self.target_chest.y + 0.5, z=self.target_chest.z + 0.5}
                local d2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=chest_center.x, y=0, z=chest_center.z})
                local dy = math.abs(pos.y - self.target_chest.y)

                if npc_debug then minetest.chat_send_all("[NPC-DBG] ChestDist: d2d="..string.format("%.2f", d2d).." dy="..string.format("%.2f", dy)) end

                if d2d <= 3.5 and dy <= 3.0 then
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

                        -- Deposit all miscellaneous items (fruits, etc.)
                        for name, count in pairs(self.inv.items) do
                            if count > 0 then
                                inv:add_item("main", ItemStack(name .. " " .. count))
                                self.inv.items[name] = 0
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
                local tree_center = {x=self.target_tree.x + 0.5, y=self.target_tree.y + 0.5, z=self.target_tree.z + 0.5}
                local dist_2d = vector.distance({x=pos.x, y=0, z=pos.z}, {x=tree_center.x, y=0, z=tree_center.z})
                local dist_y = math.abs(pos.y - self.target_tree.y)
                
                if npc_debug then minetest.chat_send_all("[NPC-DBG] TreeDist: d2d="..string.format("%.2f", dist_2d).." dy="..string.format("%.2f", dist_y)) end

                if dist_2d <= 4.0 and dist_y <= 15.0 then
                    self:set_velocity(0)
                    self.path_way = nil
                    self:set_animation("punch")
                    self.chopping_timer = (self.chopping_timer or 0) + dtime
                    if self.chopping_timer > 2.0 then
                        self.chopping_timer = 0
                        local p1 = {x = self.target_tree.x - 6, y = self.target_tree.y - 1, z = self.target_tree.z - 6}
                        local p2 = {x = self.target_tree.x + 6, y = self.target_tree.y + 45, z = self.target_tree.z + 6}
                        local nodes = minetest.find_nodes_in_area(p1, p2, {"group:tree", "group:leaves", "group:leafdecay"})

                        for _, p in ipairs(nodes) do
                            local node = minetest.get_node(p)
                            local drops = minetest.get_node_drops(node.name, "")
                            for _, item in ipairs(drops) do
                                local stack = ItemStack(item)
                                local iname = stack:get_name()
                                local is_sapling = minetest.get_item_group(iname, "sapling") > 0 or 
                                                 iname == "civi_core:sapling" or 
                                                 iname == "civi_core:jungle_sapling"
                                
                                if minetest.get_item_group(iname, "tree") > 0 or iname == "civi_core:tree" then
                                    self.inv.wood = self.inv.wood + stack:get_count()
                                elseif is_sapling then
                                    local name = stack:get_name()
                                    self.inv.saplings[name] = (self.inv.saplings[name] or 0) + stack:get_count()
                                else
                                    -- Collect fruits/drops, but EXCLUDE leaf nodes (as items)
                                    if minetest.get_item_group(iname, "leaves") == 0 and 
                                       minetest.get_item_group(iname, "grass") == 0 and
                                       minetest.get_item_group(iname, "flora") == 0 then
                                        self.inv.items[iname] = (self.inv.items[iname] or 0) + stack:get_count()
                                    end
                                end
                            end
                            minetest.remove_node(p)
                        end
                        
                        -- Smart Replanting
                        local sapling_to_plant = trunk_to_sapling[tnode.name] or "civi_core:sapling"
                        
                        if npc_debug then
                            local s_count = self.inv.saplings[sapling_to_plant] or 0
                            minetest.chat_send_all("[NPC-DBG] Replant check: "..sapling_to_plant.." count="..s_count)
                        end

                        -- For large trees like Jungle Trees, check a 2x2 area for replanting
                        local plant_offsets = {{x=0, z=0}}
                        if tnode.name == "civi_core:jungletree" then
                            plant_offsets = {{x=0, z=0}, {x=1, z=0}, {x=0, z=1}, {x=1, z=1}}
                        end

                        for _, p_off in ipairs(plant_offsets) do
                            local p_pos = {x=self.target_tree.x + p_off.x, y=self.target_tree.y, z=self.target_tree.z + p_off.z}
                            local pos_below = {x=p_pos.x, y=p_pos.y-1, z=p_pos.z}
                            local node_below = minetest.get_node(pos_below)
                            
                            local is_soil = minetest.get_item_group(node_below.name, "soil") > 0 or 
                                            minetest.get_item_group(node_below.name, "dirt") > 0
                            
                            if is_soil and minetest.get_node(p_pos).name == "air" then
                                -- Check if we have the specific sapling
                                if (self.inv.saplings[sapling_to_plant] or 0) > 0 then
                                    minetest.set_node(p_pos, {name = sapling_to_plant})
                                    self.inv.saplings[sapling_to_plant] = self.inv.saplings[sapling_to_plant] - 1
                                    minetest.sound_play("default_place_node", {pos = p_pos, gain = 0.5})
                                else
                                    -- Fallback to ANY sapling in the table
                                    for s_name, count in pairs(self.inv.saplings) do
                                        if count > 0 then
                                            minetest.set_node(p_pos, {name = s_name})
                                            self.inv.saplings[s_name] = self.inv.saplings[s_name] - 1
                                            minetest.sound_play("default_place_node", {pos = p_pos, gain = 0.5})
                                            break
                                        end
                                    end
                                end
                            elseif npc_debug then
                                minetest.chat_send_all("[NPC-DBG] Replant FAIL at "..minetest.pos_to_string(p_pos)..": soil="..tostring(is_soil).." node="..minetest.get_node(p_pos).name)
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

                    if npc_debug then
                        local raw_pos   = self.object:get_pos()
                        local rnd_pos   = vector.round(raw_pos)
                        local node_here = minetest.get_node(rnd_pos).name
                        minetest.chat_send_all(
                            "[NPC-DBG] raw=" .. string.format("(%.2f,%.2f,%.2f)", raw_pos.x, raw_pos.y, raw_pos.z) ..
                            " rnd=" .. minetest.pos_to_string(rnd_pos) ..
                            " node=" .. node_here ..
                            " stand=" .. (self.stand_target and minetest.pos_to_string(self.stand_target) or "nil") ..
                            " target=" .. minetest.pos_to_string(find_target)
                        )
                    end

                    self.path_way = pathfinder.find_path(pos, self.stand_target, self)
                    if self.path_way then
                        self.target_failures = 0
                        self.greedy_timer = 0 -- Reset greedy if path found
                    else
                        if npc_debug then
                            minetest.chat_send_all("[NPC-DBG] Kein Pfad. Failures=" .. (self.target_failures + 1))
                        end
                        self.target_failures = self.target_failures + 1
                        self.greedy_timer = 5.0
                    end
                end
                
                if self.target_failures >= 4 then
                    -- Give up on this target — alles zuruecksetzen
                    local hash = minetest.hash_node_position(target)
                    self.blacklist[hash] = minetest.get_gametime() + 60
                    self.target_tree   = nil
                    self.target_chest  = nil
                    self.stand_target  = nil   -- gecachten Standplatz vergessen!
                    self.path_way      = nil
                    self.last_target   = nil   -- Zwangsrecalc beim naechsten Target
                    self.target_failures = 0
                    if not npc_quiet then minetest.chat_send_all("[NPC] Target unreachable. Entering recovery...") end
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
            -- Arrival threshold: Final node needs to be reached more precisely
            local threshold = (#self.path_way == 1) and 1.2 or 0.6
            if d2node < threshold then
                table.remove(self.path_way, 1)
                self.stuck_timer = 0       -- Fortschritt! Stuck-Timer zuruecksetzen.
                self.last_pos = nil        -- Position-Referenz ebenfalls zuruecksetzen
                if #self.path_way == 0 then
                    self:set_velocity(0)
                end
            else
                local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=target_wp.x, y=0, z=target_wp.z})
                self.object:set_yaw(minetest.dir_to_yaw(direction))
                self:set_velocity(self.walk_velocity)
                self:set_animation("walk")

                -- Sprung bei haengerem Blockl: mit Cooldown, nicht jeden Tick
                self.jump_cooldown = (self.jump_cooldown or 0) - dtime
                if next_p.y > pos.y + 0.1 and self.jump_cooldown <= 0 then
                    self:do_jump()
                    self.jump_cooldown = 0.5
                end

                -- Stuck-Erkennung: nur wenn wir uns WIRKLICH nicht bewegen
                -- (Vergleich mit Position vor 3 Sekunden, nicht mit aktuellem Velocity)
                self.stuck_timer = (self.stuck_timer or 0) + dtime
                if self.stuck_timer >= 3.0 then
                    local last = self.last_pos
                    if last and vector.distance(pos, last) < 0.5 then
                        -- Wirklich festgesteckt: Pfad neu berechnen
                        self.path_way = nil
                        self.path_timer = 3.1
                    end
                    -- Neue Referenzposition merken
                    self.last_pos   = vector.new(pos)
                    self.stuck_timer = 0
                end
            end
        end

        -- ==== 1.5 GREEDY FALLBACK MOVEMENT ====
        if target and not self.path_way and (self.greedy_timer or 0) > 0 then
            self.greedy_timer = self.greedy_timer - dtime
            local direction = vector.direction({x=pos.x, y=0, z=pos.z}, {x=target.x, y=0, z=target.z})
            self.object:set_yaw(minetest.dir_to_yaw(direction))
            self:set_velocity(self.walk_velocity)
            self:set_animation("walk")
            
            -- Simple Obstacle Jumping
            self.jump_cooldown = (self.jump_cooldown or 0) - dtime
            local scan_pos = vector.add(pos, vector.multiply(direction, 0.8))
            if minetest.get_node(scan_pos).name ~= "air" and self.jump_cooldown <= 0 then
                self:do_jump()
                self.jump_cooldown = 1.0
            end

            -- If we are in greedy mode and truly stuck, fail sooner
            self.stuck_timer = (self.stuck_timer or 0) + dtime
            if self.stuck_timer > 3.0 then
                if self.last_pos and vector.distance(pos, self.last_pos) < 0.2 then
                    self.greedy_timer = 0 -- Stop greedy
                    self.target_failures = 4 -- Force recovery/blacklist
                end
                self.last_pos = vector.new(pos)
                self.stuck_timer = 0
            end
        end

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
                    local chests = minetest.find_nodes_in_area(cp1, cp2, {
                        "civi_storage:chest", "civi_storage:chest_locked",
                        "civi_storage:chest_open", "civi_storage:chest_locked_open"
                    })
                    if #chests > 0 then
                        table.sort(chests, function(a, b)
                            return vector.distance(pos, a) < vector.distance(pos, b)
                        end)
                        
                        for _, chest_pos in ipairs(chests) do
                            local hash = minetest.hash_node_position(chest_pos)
                            -- Blacklist pruefen: Truhe die nicht erreichbar war ueberspringen
                            if self.blacklist[hash] and self.blacklist[hash] >= minetest.get_gametime() then
                                -- skip: blacklisted
                            else
                                local stand_spot = find_standing_spot(chest_pos)
                                if stand_spot then
                                    self.target_chest = chest_pos
                                    self.stand_target = stand_spot
                                    self.path_timer = 3.1
                                    if not npc_quiet then minetest.chat_send_all("[NPC] Heading to chest at "..minetest.pos_to_string(chest_pos)) end
                                    return true
                                else
                                    self.blacklist[hash] = minetest.get_gametime() + 300
                                end
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
                                if not npc_quiet then minetest.chat_send_all("[NPC] Nearest unique tree found at "..minetest.pos_to_string(found_root)) end
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
