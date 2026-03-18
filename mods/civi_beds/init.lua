-- civi_beds/init.lua

civi_beds = {}

-- Removes a node without calling on_destruct()
local function remove_no_destruct(pos)
    minetest.swap_node(pos, {name = "air"})
    minetest.remove_node(pos)
end

-- Helper to get other bed half
local function get_other_bed_pos(pos, is_bottom)
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    if is_bottom then
        return vector.add(pos, dir)
    else
        return vector.subtract(pos, dir)
    end
end

-- Sleep logic
function civi_beds.sleep(pos, player)
    local name = player:get_player_name()
    local tod = minetest.get_timeofday()

    -- Only at night
    if tod > 0.2 and tod < 0.805 then
        minetest.chat_send_player(name, "You can only sleep at night!")
        return
    end

    -- Set spawn point
    player:get_meta():set_string("civi_beds:spawn", minetest.pos_to_string(pos))
    minetest.chat_send_player(name, "Spawn point set!")

    -- Skip night (Simple version for singleplayer/small servers)
    minetest.set_timeofday(0.23)
    minetest.chat_send_all("Good morning!")
end

-- Register bed function
function civi_beds.register_bed(name, def)
    local bottom_name = name .. "_bottom"
    local top_name = name .. "_top"

    -- Bottom (Foot)
    minetest.register_node(bottom_name, {
        description = def.description,
        inventory_image = def.inventory_image,
        wield_image = def.wield_image,
        drawtype = "nodebox",
        tiles = def.tiles.bottom,
        paramtype = "light",
        paramtype2 = "facedir",
        groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, bed = 1},
        node_box = {
            type = "fixed",
            fixed = def.nodebox.bottom,
        },
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, 0.0625, 1.5},
        },
        on_place = function(itemstack, placer, pointed_thing)
            local pos = pointed_thing.above
            local dir = minetest.dir_to_facedir(placer:get_look_dir())
            local other_pos = vector.add(pos, minetest.facedir_to_dir(dir))

            if minetest.get_node(other_pos).name ~= "air" then
                return itemstack
            end

            minetest.set_node(pos, {name = bottom_name, param2 = dir})
            minetest.set_node(other_pos, {name = top_name, param2 = dir})

            itemstack:take_item()
            return itemstack
        end,
        on_destruct = function(pos)
            local other = get_other_bed_pos(pos, true)
            if minetest.get_node(other).name == top_name then
                remove_no_destruct(other)
            end
        end,
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            civi_beds.sleep(pos, clicker)
        end,
    })

    -- Top (Head)
    minetest.register_node(top_name, {
        drawtype = "nodebox",
        tiles = def.tiles.top,
        paramtype = "light",
        paramtype2 = "facedir",
        groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, bed = 2, not_in_creative_inventory = 1},
        node_box = {
            type = "fixed",
            fixed = def.nodebox.top,
        },
        selection_box = {
            type = "fixed",
            fixed = {0, 0, 0, 0, 0, 0}, -- Proxy to bottom
        },
        on_destruct = function(pos)
            local other = get_other_bed_pos(pos, false)
            if minetest.get_node(other).name == bottom_name then
                remove_no_destruct(other)
            end
        end,
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            local other = get_other_bed_pos(pos, false)
            civi_beds.sleep(other, clicker)
        end,
        drop = bottom_name,
    })

    -- Recipe
    minetest.register_craft({
        output = bottom_name,
        recipe = def.recipe,
    })
end

-- Fancy Bed
civi_beds.register_bed("civi_beds:fancy_bed", {
    description = "Fancy Bed",
    inventory_image = "beds_bed_fancy.png",
    wield_image = "beds_bed_fancy.png",
    tiles = {
        bottom = {
            "beds_bed_top1.png",
            "beds_bed_under.png",
            "beds_bed_side1.png",
            "beds_bed_side1.png^[transformFX",
            "beds_bed_foot.png",
            "beds_bed_foot.png",
        },
        top = {
            "beds_bed_top2.png",
            "beds_bed_under.png",
            "beds_bed_side2.png",
            "beds_bed_side2.png^[transformFX",
            "beds_bed_head.png",
            "beds_bed_head.png",
        }
    },
    nodebox = {
        bottom = {
            {-0.5, -0.5, -0.5, -0.375, -0.065, -0.4375},
            {0.375, -0.5, -0.5, 0.5, -0.065, -0.4375},
            {-0.5, -0.375, -0.5, 0.5, -0.125, -0.4375},
            {-0.5, -0.375, -0.5, -0.4375, -0.125, 0.5},
            {0.4375, -0.375, -0.5, 0.5, -0.125, 0.5},
            {-0.4375, -0.3125, -0.4375, 0.4375, -0.0625, 0.5},
        },
        top = {
            {-0.5, -0.5, 0.4375, -0.375, 0.1875, 0.5},
            {0.375, -0.5, 0.4375, 0.5, 0.1875, 0.5},
            {-0.5, 0, 0.4375, 0.5, 0.125, 0.5},
            {-0.5, -0.375, 0.4375, 0.5, -0.125, 0.5},
            {-0.5, -0.375, -0.5, -0.4375, -0.125, 0.5},
            {0.4375, -0.375, -0.5, 0.5, -0.125, 0.5},
            {-0.4375, -0.3125, -0.5, 0.4375, -0.0625, 0.4375},
        }
    },
    recipe = {
        {"", "", "civi_core:stick"},
        {"wool:white", "wool:white", "wool:white"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
    },
})

-- Simple Bed
civi_beds.register_bed("civi_beds:bed", {
    description = "Simple Bed",
    inventory_image = "beds_bed.png",
    wield_image = "beds_bed.png",
    tiles = {
        bottom = {
            "beds_bed_top_bottom.png^[transformR90",
            "beds_bed_under.png",
            "beds_bed_side_bottom_r.png",
            "beds_bed_side_bottom_r.png^[transformFX",
            "civi_gui_bg.png", -- fallback for blank
            "beds_bed_side_bottom.png"
        },
        top = {
            "beds_bed_top_top.png^[transformR90",
            "beds_bed_under.png",
            "beds_bed_side_top_r.png",
            "beds_bed_side_top_r.png^[transformFX",
            "beds_bed_side_top.png",
            "civi_gui_bg.png", -- fallback for blank
        }
    },
    nodebox = {
        bottom = {-0.5, -0.5, -0.5, 0.5, 0.0625, 0.5},
        top = {-0.5, -0.5, -0.5, 0.5, 0.0625, 0.5},
    },
    recipe = {
        {"wool:white", "wool:white", "wool:white"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"}
    },
})

-- Respawn logic
minetest.register_on_respawnplayer(function(player)
    local meta = player:get_meta()
    local spawn_str = meta:get_string("civi_beds:spawn")
    if spawn_str ~= "" then
        local pos = minetest.string_to_pos(spawn_str)
        if pos then
            -- Verify bed still exists
            local node = minetest.get_node(pos)
            if minetest.get_item_group(node.name, "bed") > 0 then
                player:set_pos(pos)
                return true
            end
        end
    end
    return false
end)

print("[Civi Beds] Loaded.")
