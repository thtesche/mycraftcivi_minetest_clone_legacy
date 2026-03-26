-- civi_storage: init.lua
print("[myCraftCivi] Loading civi_storage...")

local function get_chest_formspec(pos)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    local slots_y = 4
    local size_y = 9
    local p_inv_y = 4.5
    
    return "size[8,9]" ..
           "list[nodemeta:" .. spos .. ";main;0,0.3;8," .. slots_y .. ";]" ..
           "list[current_player;main;0," .. p_inv_y .. ";8,1;]" ..
           "list[current_player;main;0," .. (p_inv_y + 1.2) .. ";8,3;8]" ..
           "listring[nodemeta:" .. spos .. ";main]" ..
           "listring[current_player;main]"
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
    

    can_dig = function(pos, player)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        return inv:is_empty("main")
    end,
    
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        minetest.show_formspec(clicker:get_player_name(), "civi_storage:chest", get_chest_formspec(pos))
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
