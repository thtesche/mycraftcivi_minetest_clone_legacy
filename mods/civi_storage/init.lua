-- civi_storage: init.lua
print("[myCraftCivi] Loading civi_storage...")

local function get_chest_formspec(pos, is_double)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    local slots_y = is_double and 8 or 4
    local size_y = is_double and 13 or 9
    local player_inv_y = is_double and (is_double and 8.5 or 4.5)
    
    -- Correcting some y positions for nice layout
    local p_inv_y = is_double and 8.5 or 4.5
    
    return "size[8," .. size_y .. "]" ..
           "list[nodemeta:" .. spos .. ";main;0,0.3;8," .. slots_y .. ";]" ..
           "list[current_player;main;0," .. p_inv_y .. ";8,1;]" ..
           "list[current_player;main;0," .. (p_inv_y + 1.2) .. ";8,3;8]" ..
           "listring[nodemeta:" .. spos .. ";main]" ..
           "listring[current_player;main]"
end

-- Helper to check and merge chests
local function try_merge(pos)
    local node = minetest.get_node(pos)
    if node.name ~= "civi_storage:chest" then return end
    
    local neighbors = {
        {x=pos.x+1, y=pos.y, z=pos.z},
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x, y=pos.y, z=pos.z+1},
        {x=pos.x, y=pos.y, z=pos.z-1}
    }
    
    for _, npos in ipairs(neighbors) do
        local nnode = minetest.get_node(npos)
        if nnode.name == "civi_storage:chest" then
            local meta = minetest.get_meta(pos)
            local nmeta = minetest.get_meta(npos)
            
            -- Check if both are empty to be safe
            local inv = meta:get_inventory()
            local ninv = nmeta:get_inventory()
            
            if inv:is_empty("main") and ninv:is_empty("main") then
                minetest.set_node(pos, {name = "civi_storage:chest_double", param2 = node.param2})
                minetest.remove_node(npos)
                minetest.chat_send_all("Chest merged!")
                return true
            end
        end
    end
    return false
end

-- =========================================================
-- 1. SINGLE CHEST
-- =========================================================

minetest.register_node("civi_storage:chest", {
    description = "Civi Chest (32 Slots)",
    tiles = {
        "civi_chest_top.png", "civi_chest_top.png",
        "civi_chest_side.png", "civi_chest_side.png",
        "civi_chest_side.png", "civi_chest_front.png"
    },
    paramtype2 = "facedir",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, container = 1},
    sounds = sounds.node_sound_wood_defaults(),
    
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Chest")
        local inv = meta:get_inventory()
        inv:set_size("main", 8 * 4) 
    end,
    
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        try_merge(pos)
    end,

    can_dig = function(pos, player)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        return inv:is_empty("main")
    end,
    
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        minetest.show_formspec(clicker:get_player_name(), "civi_storage:chest", get_chest_formspec(pos, false))
    end,
})

-- =========================================================
-- 2. DOUBLE CHEST
-- =========================================================

minetest.register_node("civi_storage:chest_double", {
    description = "Civi Double Chest (64 Slots)",
    tiles = {
        "civi_chest_top.png", "civi_chest_top.png",
        "civi_chest_side.png", "civi_chest_side.png",
        "civi_chest_side.png", "civi_chest_front.png"
    },
    paramtype2 = "facedir",
    drop = "civi_storage:chest 2",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, container = 1, not_in_creative_inventory = 1},
    sounds = sounds.node_sound_wood_defaults(),
    
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Double Chest")
        local inv = meta:get_inventory()
        inv:set_size("main", 8 * 8)
    end,
    
    can_dig = function(pos, player)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        return inv:is_empty("main")
    end,
    
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        minetest.show_formspec(clicker:get_player_name(), "civi_storage:chest_double", get_chest_formspec(pos, true))
    end,
})

-- =========================================================
-- 3. CRAFTING
-- =========================================================

minetest.register_craft({
    output = "civi_storage:chest",
    recipe = {
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
        {"civi_core:wood", "", "civi_core:wood"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
    }
})
