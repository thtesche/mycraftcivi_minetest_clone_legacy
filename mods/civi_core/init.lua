-- civi_core: init.lua
-- Standalone Luanti Game – no minetest_game required

print("[myCraftCivi] Loading civi_core...")

-- =========================================================
-- SPAWN SYSTEM: Place player safely on the ground
-- =========================================================

local function find_ground(pos)
    -- Search down until a solid block is hit
    local p = {x = pos.x, y = pos.y, z = pos.z}
    for i = 1, 200 do
        p.y = pos.y - i
        local node = minetest.get_node_or_nil(p)
        if node and node.name ~= "air" and node.name ~= "ignore" and
           node.name ~= "civi_core:water_source" and node.name ~= "civi_core:water_flowing" then
            return {x = p.x, y = p.y + 2, z = p.z}  -- 2 blocks above ground
        end
    end
    return nil
end

local function safe_spawn(player)
    -- Wait for mapgen, then search for spawn position
    minetest.after(0.5, function()
        if not player or not player:is_valid() then return end
        local pos = player:get_pos()
        -- Emerge terrain at spawn position
        minetest.emerge_area(
            {x = pos.x - 16, y = pos.y - 64, z = pos.z - 16},
            {x = pos.x + 16, y = pos.y + 16, z = pos.z + 16},
            function()
                minetest.after(0.5, function()
                    if not player or not player:is_valid() then return end
                    local ground = find_ground({x = pos.x, y = pos.y + 50, z = pos.z})
                    if ground then
                        player:set_pos(ground)
                    else
                        -- Fallback: Set to known safe height
                        player:set_pos({x = pos.x, y = 10, z = pos.z})
                    end
                end)
            end
        )
    end)
end

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    -- Configure player model and appearance (handled by player_api / skinsdb)
    -- player:set_properties({
    --     visual = "mesh",
    --     mesh = "character.b3d",
    --     textures = {"character.png"},
    --     visual_size = {x = 1, y = 1},
    --     collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
    --     stepheight = 0.6,
    --     eye_height = 1.47,
    -- })

    -- Inventory size and starting equipment (8x4 Grid = 32 Slots)
    local inv = player:get_inventory()
    if inv then
        inv:set_size("main", 32)
        inv:set_size("craft", 9)
        print("[myCraftCivi] Inventory & Crafting for " .. name .. " initialized")
    end


    -- Local animations for 1st person (handled by player_api)

    safe_spawn(player)
end)

minetest.register_on_respawnplayer(function(player)
    safe_spawn(player)
    return true  -- true = we handle the respawn ourselves
end)

-- Fallschaden deaktivieren (optional, zum Testen komfortabler)
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if reason and reason.type == "fall" then
        return 0  -- Keinen Fallschaden
    end
    return hp_change
end, true)

-- =========================================================
-- SOUND HELPERS (based on minetest_game default functions)
-- =========================================================

sounds = {}

function sounds.node_sound_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "", gain = 1.0}
    tbl.dug = tbl.dug or {name = "default_dug_node", gain = 0.25}
    tbl.place = tbl.place or {name = "default_place_node_hard", gain = 1.0}
    return tbl
end

function sounds.node_sound_stone_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_hard_footstep", gain = 0.2}
    tbl.dug = tbl.dug or {name = "default_hard_footstep", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_dirt_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_dirt_footstep", gain = 0.25}
    tbl.dig = tbl.dig or {name = "default_dig_crumbly", gain = 0.4}
    tbl.dug = tbl.dug or {name = "default_dirt_footstep", gain = 1.0}
    tbl.place = tbl.place or {name = "default_place_node", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_sand_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_sand_footstep", gain = 0.05}
    tbl.dug = tbl.dug or {name = "default_sand_footstep", gain = 0.15}
    tbl.place = tbl.place or {name = "default_place_node", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_wood_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_wood_footstep", gain = 0.15}
    tbl.dig = tbl.dig or {name = "default_dig_choppy", gain = 0.4}
    tbl.dug = tbl.dug or {name = "default_wood_footstep", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_leaves_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_grass_footstep", gain = 0.45}
    tbl.dug = tbl.dug or {name = "default_grass_footstep", gain = 0.7}
    tbl.place = tbl.place or {name = "default_place_node", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_glass_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_glass_footstep", gain = 0.3}
    tbl.dig = tbl.dig or {name = "default_glass_footstep", gain = 0.5}
    tbl.dug = tbl.dug or {name = "default_break_glass", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_ice_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_ice_footstep", gain = 0.15}
    tbl.dig = tbl.dig or {name = "default_ice_dig", gain = 0.5}
    tbl.dug = tbl.dug or {name = "default_ice_dug", gain = 0.5}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_snow_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_snow_footstep", gain = 0.2}
    tbl.dig = tbl.dig or {name = "default_snow_footstep", gain = 0.3}
    tbl.dug = tbl.dug or {name = "default_snow_footstep", gain = 0.3}
    tbl.place = tbl.place or {name = "default_place_node", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_water_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_water_footstep", gain = 0.2}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_metal_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_metal_footstep", gain = 0.25}
    tbl.dig = tbl.dig or {name = "default_dig_metal", gain = 0.5}
    tbl.dug = tbl.dug or {name = "default_dug_metal", gain = 0.5}
    tbl.place = tbl.place or {name = "default_place_node_metal", gain = 0.5}
    return sounds.node_sound_defaults(tbl)
end

function sounds.node_sound_gravel_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "default_gravel_footstep", gain = 0.3}
    tbl.dig = tbl.dig or {name = "default_gravel_dig", gain = 0.35}
    tbl.dug = tbl.dug or {name = "default_gravel_dug", gain = 0.35}
    tbl.place = tbl.place or {name = "default_place_node", gain = 1.0}
    return sounds.node_sound_defaults(tbl)
end


-- =========================================================
-- 1. TERRAIN-BLÖCKE (werden vom Welt-Generator benötigt)
-- =========================================================

minetest.register_node("civi_core:stone", {
    description = "Stone",
    tiles = {"civi_stone.png"},
    groups = {cracky = 3, stone = 1},
    drop = "", -- Hand dug drops nothing
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:cobble", {
    description = "Cobblestone",
    tiles = {"civi_cobble.png"},
    groups = {cracky = 3, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:dirt", {
    description = "Dirt",
    tiles = {"civi_dirt.png"},
    groups = {crumbly = 3, soil = 1, dirt = 1},
    sounds = sounds.node_sound_dirt_defaults(),
})

minetest.register_node("civi_core:dirt_with_grass", {
    description = "Dirt with Grass",
    tiles = {"civi_grass.png", "civi_dirt.png", {name = "civi_dirt.png^civi_grass_side.png", tileable_vertical = false}},
    groups = {crumbly = 3, soil = 1, grass = 1},
    sounds = sounds.node_sound_dirt_defaults(),
})

minetest.register_node("civi_core:sand", {
    description = "Sand",
    tiles = {"civi_sand.png"},
    groups = {crumbly = 3, falling_node = 1, sand = 1},
    sounds = sounds.node_sound_sand_defaults(),
})

minetest.register_node("civi_core:gravel", {
    description = "Gravel",
    tiles = {"civi_gravel.png"},
    groups = {crumbly = 2, falling_node = 1},
    sounds = sounds.node_sound_gravel_defaults(),
})

minetest.register_node("civi_core:mossycobble", {
    description = "Mossy Cobblestone",
    tiles = {"civi_mossycobble.png"},
    groups = {cracky = 3, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:desert_cobble", {
    description = "Desert Cobblestone",
    tiles = {"civi_desert_cobble.png"},
    groups = {cracky = 3, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craftitem("civi_core:paper", {
    description = "Paper",
    inventory_image = "civi_paper.png",
    groups = {flammable = 3},
})


minetest.register_node("civi_core:stone_with_coal", {
    description = "Coal Ore",
    tiles = {"civi_stone.png^civi_mineral_coal.png"},
    groups = {cracky = 3},
    drop = "civi_core:coal_lump",
    sounds = sounds.node_sound_stone_defaults(),
})
minetest.register_craftitem("civi_core:coal_lump", {
    description = "Coal Lump",
    inventory_image = "civi_coal_lump.png",
    groups = {coal = 1, flammable = 1}
})

minetest.register_node("civi_core:coalblock", {
    description = "Coal Block",
    tiles = {"civi_coal_block.png"},
    is_ground_content = false,
    groups = {cracky = 3},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craft({
    output = "civi_core:coalblock",
    recipe = {
        {"civi_core:coal_lump", "civi_core:coal_lump", "civi_core:coal_lump"},
        {"civi_core:coal_lump", "civi_core:coal_lump", "civi_core:coal_lump"},
        {"civi_core:coal_lump", "civi_core:coal_lump", "civi_core:coal_lump"},
    }
})

minetest.register_craft({
    output = "civi_core:coal_lump 9",
    recipe = {
        {"civi_core:coalblock"},
    }
})

minetest.register_node("civi_core:stone_with_iron", {
    description = "Iron Ore",
    tiles = {"civi_stone.png^civi_mineral_iron.png"},
    groups = {cracky = 2},
    drop = "civi_core:iron_lump",
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craftitem("civi_core:iron_lump", {
    description = "Iron Lump",
    inventory_image = "civi_iron_lump.png",
})

minetest.register_craftitem("civi_core:steel_ingot", {
    description = "Steel Ingot",
    inventory_image = "civi_steel_ingot.png",
})

minetest.register_node("civi_core:steel_block", {
    description = "Steel Block",
    tiles = {"civi_steel_block.png"},
    is_ground_content = false,
    groups = {cracky = 1, level = 2},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craft({
    type = "cooking",
    output = "civi_core:steel_ingot",
    recipe = "civi_core:iron_lump",
})

minetest.register_node("civi_core:obsidian", {
    description = "Obsidian",
    tiles = {"civi_obsidian.png"},
    is_ground_content = false,
    groups = {cracky = 1, level = 2},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:obsidian_glass", {
    description = "Obsidian Glass",
    drawtype = "glasslike",
    tiles = {"civi_obsidian_glass.png"},
    paramtype = "light",
    sunlight_propagates = true,
    use_texture_alpha = "clip",
    groups = {snappy = 2, cracky = 3, obsidian = 1},
    sounds = sounds.node_sound_glass_defaults(),
})

minetest.register_node("civi_core:stone_with_copper", {
    description = "Copper Ore",
    tiles = {"civi_stone.png^civi_mineral_copper.png"},
    groups = {cracky = 2},
    drop = "civi_core:copper_lump",
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craftitem("civi_core:copper_lump", {
    description = "Copper Lump",
    inventory_image = "civi_copper_lump.png",
})

minetest.register_node("civi_core:stone_with_gold", {
    description = "Gold Ore",
    tiles = {"civi_stone.png^civi_mineral_gold.png"},
    groups = {cracky = 2},
    drop = "civi_core:gold_lump",
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_craftitem("civi_core:gold_lump", {
    description = "Gold Lump",
    inventory_image = "civi_gold_lump.png",
})

minetest.register_node("civi_core:glass", {
    description = "Glass",
    drawtype = "glasslike",
    tiles = {"civi_glass.png"},
    paramtype = "light",
    sunlight_propagates = true,
    use_texture_alpha = "clip",
    groups = {snappy = 2, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = sounds.node_sound_glass_defaults(),
})

minetest.register_node("civi_core:ice", {
    description = "Ice",
    tiles = {"civi_ice.png"},
    is_ground_content = false,
    paramtype = "light",
    groups = {cracky = 3, slippery = 3},
    sounds = sounds.node_sound_ice_defaults(),
})

minetest.register_node("civi_core:snowblock", {
    description = "Snow Block",
    tiles = {"civi_snow.png"},
    groups = {crumbly = 3, snowy = 1},
    sounds = sounds.node_sound_snow_defaults(),
})

minetest.register_node("civi_core:snow", {
    description = "Snow",
    drawtype = "nodebox",
    tiles = {"civi_snow.png"},
    paramtype = "light",
    buildable_to = true,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
    },
    groups = {crumbly = 3, falling_node = 1, snowy = 1},
    sounds = sounds.node_sound_snow_defaults(),
})

minetest.register_node("civi_core:wood", {
    description = "Wooden Planks",
    tiles = {"civi_wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
    sounds = sounds.node_sound_wood_defaults(),
})

minetest.register_node("civi_core:stone_brick", {
    description = "Stone Brick",
    tiles = {"civi_stone_brick.png"},
    groups = {cracky = 2, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:brick", {
    description = "Brick",
    tiles = {"civi_brick.png"},
    groups = {cracky = 3},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:desert_stone", {
    description = "Desert Stone",
    tiles = {"civi_desert_stone.png"},
    groups = {cracky = 3, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:sandstone", {
    description = "Sandstone",
    tiles = {"civi_sandstone.png"},
    groups = {crumbly = 2, cracky = 3, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:bronze_block", {
    description = "Bronze Block",
    tiles = {"civi_bronze_block.png"},
    groups = {cracky = 1, level = 2},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:gold_block", {
    description = "Gold Block",
    tiles = {"civi_gold_block.png"},
    groups = {cracky = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

minetest.register_node("civi_core:diamond_block", {
    description = "Diamond Block",
    tiles = {"civi_diamond_block.png"},
    groups = {cracky = 1, level = 3},
    sounds = sounds.node_sound_stone_defaults(),
})

-- =========================================================
-- 2. BÄUME, NATUR & LICHT
-- =========================================================

-- Torch (based on minetest_game default:torch)
local function torch_on_flood(pos, oldnode, newnode)
    minetest.add_item(pos, ItemStack("civi_core:torch 1"))
    return false
end

minetest.register_node("civi_core:torch", {
    description = "Torch",
    drawtype = "mesh",
    mesh = "torch_floor.obj",
    inventory_image = "civi_torch.png",
    wield_image = "civi_torch.png",
    tiles = {{
        name = "civi_torch_animated.png",
        animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3}
    }},
    use_texture_alpha = "clip",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = 12,
    groups = {choppy=2, dig_immediate=3, flammable=1, attached_node=1, torch=1},
    drop = "civi_core:torch",
    selection_box = {
        type = "wallmounted",
        wall_bottom = {-1/8, -1/2, -1/8, 1/8, 2/16, 1/8},
    },
    sounds = sounds.node_sound_wood_defaults(),
    on_place = function(itemstack, placer, pointed_thing)
        local under = pointed_thing.under
        local above = pointed_thing.above
        local wdir = minetest.dir_to_wallmounted(vector.subtract(under, above))
        local fakestack = itemstack
        if wdir == 0 then
            fakestack:set_name("civi_core:torch_ceiling")
        elseif wdir == 1 then
            fakestack:set_name("civi_core:torch")
        else
            fakestack:set_name("civi_core:torch_wall")
        end
        itemstack = minetest.item_place(fakestack, placer, pointed_thing, wdir)
        itemstack:set_name("civi_core:torch")
        return itemstack
    end,
    floodable = true,
    on_flood = torch_on_flood,
})

minetest.register_node("civi_core:torch_wall", {
    drawtype = "mesh",
    mesh = "torch_wall.obj",
    tiles = {{
        name = "civi_torch_animated.png",
        animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3}
    }},
    use_texture_alpha = "clip",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = 12,
    groups = {choppy=2, dig_immediate=3, flammable=1, not_in_creative_inventory=1, attached_node=1, torch=1},
    drop = "civi_core:torch",
    selection_box = {
        type = "wallmounted",
        wall_side = {-1/2, -1/2, -1/8, -1/8, 1/8, 1/8},
    },
    sounds = sounds.node_sound_wood_defaults(),
    floodable = true,
    on_flood = torch_on_flood,
})

minetest.register_node("civi_core:torch_ceiling", {
    drawtype = "mesh",
    mesh = "torch_ceiling.obj",
    tiles = {{
        name = "civi_torch_animated.png",
        animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3}
    }},
    use_texture_alpha = "clip",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = 12,
    groups = {choppy=2, dig_immediate=3, flammable=1, not_in_creative_inventory=1, attached_node=1, torch=1},
    drop = "civi_core:torch",
    selection_box = {
        type = "wallmounted",
        wall_top = {-1/8, -1/16, -5/16, 1/8, 1/2, 1/8},
    },
    sounds = sounds.node_sound_wood_defaults(),
    floodable = true,
    on_flood = torch_on_flood,
})

minetest.register_node("civi_core:tree", {
    description = "Tree Trunk (Wood)",
    tiles = {"civi_tree_trunk_top.png", "civi_tree_trunk_top.png", "civi_tree_trunk.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
})

-- Acacia
minetest.register_node("civi_core:acacia_tree", {
    description = "Acacia Tree Trunk",
    tiles = {"civi_acacia_tree_top.png", "civi_acacia_tree_top.png", "civi_acacia_tree.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:acacia_wood", {
    description = "Acacia Wood Planks",
    tiles = {"civi_acacia_wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:acacia_leaves", {
    description = "Acacia Leaves",
    drawtype = "allfaces_optional",
    tiles = {"civi_acacia_leaves.png"},
    paramtype = "light",
    groups = {snappy = 3, leafdecay = 3, leaves = 1, flammable = 2},
    sounds = sounds.node_sound_leaves_defaults(),
})

-- Aspen
minetest.register_node("civi_core:aspen_tree", {
    description = "Aspen Tree Trunk",
    tiles = {"civi_aspen_tree_top.png", "civi_aspen_tree_top.png", "civi_aspen_tree.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:aspen_wood", {
    description = "Aspen Wood Planks",
    tiles = {"civi_aspen_wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:aspen_leaves", {
    description = "Aspen Leaves",
    drawtype = "allfaces_optional",
    tiles = {"civi_aspen_leaves.png"},
    paramtype = "light",
    groups = {snappy = 3, leafdecay = 3, leaves = 1, flammable = 2},
    sounds = sounds.node_sound_leaves_defaults(),
})

-- Jungle
minetest.register_node("civi_core:jungletree", {
    description = "Jungle Tree Trunk",
    tiles = {"civi_jungletree_top.png", "civi_jungletree_top.png", "civi_jungletree.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:junglewood", {
    description = "Jungle Wood Planks",
    tiles = {"civi_junglewood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:jungleleaves", {
    description = "Jungle Leaves",
    drawtype = "allfaces_optional",
    tiles = {"civi_jungleleaves.png"},
    paramtype = "light",
    groups = {snappy = 3, leafdecay = 3, leaves = 1, flammable = 2},
    sounds = sounds.node_sound_leaves_defaults(),
})

-- Pine
minetest.register_node("civi_core:pine_tree", {
    description = "Pine Tree Trunk",
    tiles = {"civi_pine_tree_top.png", "civi_pine_tree_top.png", "civi_pine_tree.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:pine_wood", {
    description = "Pine Wood Planks",
    tiles = {"civi_pine_wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
    sounds = sounds.node_sound_wood_defaults(),
})
minetest.register_node("civi_core:pine_needles", {
    description = "Pine Needles",
    drawtype = "allfaces_optional",
    tiles = {"civi_pine_needles.png"},
    paramtype = "light",
    groups = {snappy = 3, leafdecay = 3, leaves = 1, flammable = 2},
    sounds = sounds.node_sound_leaves_defaults(),
})

minetest.register_node("civi_core:leaves", {
    description = "Leaves",
    drawtype = "allfaces_optional",
    tiles = {"civi_leaves.png"},
    paramtype = "light",
    walkable = true,
    climbable = false,
    is_ground_content = false,
    groups = {snappy = 3, leafdecay = 3, leaves = 1, flammable = 2},
    drop = {
        max_items = 1,
        items = {
            {items = {"civi_core:sapling"}, rarity = 20},
            {items = {"civi_core:apple"}, rarity = 20},
            {items = {"civi_core:leaves"}},
        }
    },
    sounds = sounds.node_sound_leaves_defaults(),
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        if placer and placer:is_player() then
            local node = minetest.get_node(pos)
            node.param2 = 1
            minetest.set_node(pos, node)
        end
    end,
})

minetest.register_node("civi_core:sapling", {
    description = "Sapling",
    drawtype = "plantlike",
    tiles = {"civi_sapling.png"},
    inventory_image = "civi_sapling.png",
    wield_image = "civi_sapling.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    selection_box = {
        type = "fixed",
        fixed = {-3 / 16, -0.5, -3 / 16, 3 / 16, 0.5, 3 / 16}
    },
    groups = {snappy = 2, dig_immediate = 3, flammable = 2, sapling = 1, attached_node = 1},
    sounds = sounds.node_sound_leaves_defaults(),
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        local pos_under = pointed_thing.under
        local node_under = minetest.get_node(pos_under).name
        
        -- Erlaube Platzierung nur auf Erde, Gras oder Sand
        if node_under == "civi_core:dirt" or 
           node_under == "civi_core:dirt_with_grass" or 
           node_under == "civi_core:sand" then
            return minetest.item_place(itemstack, placer, pointed_thing)
        end
        
        return itemstack
    end,
    on_construct = function(pos)
        minetest.get_node_timer(pos):start(math.random(300, 1500))
    end,
    on_timer = function(pos)
        minetest.place_schematic({x = pos.x - 3, y = pos.y - 1, z = pos.z - 3},
            minetest.get_modpath("civi_core") .. "/schematics/apple_tree.mts", "random", nil, false)
        return false
    end,
})

minetest.register_node("civi_core:apple", {
    description = "Apple",
    drawtype = "plantlike",
    tiles = {"civi_apple.png"},
    inventory_image = "civi_apple.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    selection_box = {
        type = "fixed",
        fixed = {-3 / 16, -7 / 16, -3 / 16, 3 / 16, 4 / 16, 3 / 16}
    },
    groups = {fleshy = 3, dig_immediate = 3, flammable = 2, leafdecay = 3, food = 1},
    on_use = minetest.item_eat(2),
    on_place = minetest.item_eat(2),
})

minetest.register_node("civi_core:mushroom_brown", {
    description = "Brown Mushroom",
    drawtype = "plantlike",
    tiles = {"civi_mushroom_brown.png"},
    inventory_image = "civi_mushroom_brown.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    groups = {snappy = 3, attached_node = 1, flammable = 1, food = 1},
    on_use = minetest.item_eat(1),
    on_place = minetest.item_eat(1),
})

minetest.register_node("civi_core:mushroom_red", {
    description = "Red Mushroom (Poisonous!)",
    drawtype = "plantlike",
    tiles = {"civi_mushroom_red.png"},
    inventory_image = "civi_mushroom_red.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    groups = {snappy = 3, attached_node = 1, flammable = 1, food = 1},
    on_use = minetest.item_eat(-5),
    on_place = minetest.item_eat(-5),
})

minetest.register_node("civi_core:water_source", {
    description = "Water Source",
    drawtype = "liquid",
    tiles = {
        {
            name = "civi_water.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 2.0,
            },
        },
    },
    use_texture_alpha = "blend",
    paramtype = "light",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    is_ground_content = false,
    liquidtype = "source",
    liquid_alternative_flowing = "civi_core:water_flowing",
    liquid_alternative_source = "civi_core:water_source",
    liquid_viscosity = 1,
    groups = {water = 3, liquid = 3},
    sounds = sounds.node_sound_water_defaults(),
})

minetest.register_node("civi_core:water_flowing", {
    description = "Flowing Water",
    drawtype = "flowingliquid",
    tiles = {"civi_water.png"},
    special_tiles = {
        {
            name = "civi_water.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 0.8,
            },
        },
        {
            name = "civi_water.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 0.8,
            },
        },
    },
    use_texture_alpha = "blend",
    paramtype = "light",
    paramtype2 = "flowingliquid",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    is_ground_content = false,
    liquidtype = "flowing",
    liquid_alternative_flowing = "civi_core:water_flowing",
    liquid_alternative_source = "civi_core:water_source",
    liquid_viscosity = 1,
    groups = {water = 3, liquid = 3, not_in_creative_inventory = 1},
})

-- =========================================================
-- 2. MAPGEN-ALIASES (sagen dem Weltgenerator welche Blöcke
--    er für Boden, Stein und Wasser verwenden soll)
-- =========================================================

minetest.register_alias("mapgen_stone",          "civi_core:stone")
minetest.register_alias("mapgen_dirt",           "civi_core:dirt")
minetest.register_alias("mapgen_dirt_with_grass","civi_core:dirt_with_grass")
minetest.register_alias("mapgen_river_water_source",   "civi_core:water_source")
minetest.register_alias("mapgen_water_source",   "civi_core:water_source")
minetest.register_alias("mapgen_sand",           "civi_core:sand")
minetest.register_alias("mapgen_ice",            "civi_core:ice")
minetest.register_alias("mapgen_snowblock",      "civi_core:snowblock")
minetest.register_alias("mapgen_snow",           "civi_core:snow")

-- Erz-Generierung
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "civi_core:stone_with_coal",
    wherein        = "civi_core:stone",
    clust_scarcity = 8 * 8 * 8,
    clust_num_ores = 8,
    clust_size     = 3,
    y_max          = 31000,
    y_min          = -31000,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "civi_core:stone_with_iron",
    wherein        = "civi_core:stone",
    clust_scarcity = 9 * 9 * 9,
    clust_num_ores = 12,
    clust_size     = 3,
    y_max          = 31000,
    y_min          = -31000,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "civi_core:stone_with_copper",
    wherein        = "civi_core:stone",
    clust_scarcity = 12 * 12 * 12,
    clust_num_ores = 4,
    clust_size     = 3,
    y_max          = 31000,
    y_min          = -31000,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "civi_core:stone_with_gold",
    wherein        = "civi_core:stone",
    clust_scarcity = 15 * 15 * 15,
    clust_num_ores = 3,
    clust_size     = 2,
    y_max          = 0,
    y_min          = -31000,
})

-- =========================================================
-- 3. EINRICHTUNG & HILFSMITTEL
-- =========================================================

minetest.register_node("civi_core:bookshelf", {
    description = "Bookshelf",
    tiles = {"civi_wood.png", "civi_wood.png", "civi_bookshelf.png"},
    groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3},
    sounds = sounds.node_sound_wood_defaults(),
})

minetest.register_node("civi_core:ladder", {
    description = "Wooden Ladder",
    drawtype = "signlike",
    tiles = {"civi_ladder_wood.png"},
    inventory_image = "civi_ladder_wood.png",
    wield_image = "civi_ladder_wood.png",
    paramtype = "light",
    paramtype2 = "wallmounted",
    walkable = false,
    climbable = true,
    sunlight_propagates = true,
    selection_box = {
        type = "wallmounted",
        --wall_top = = <default>
        --wall_bottom = = <default>
        --wall_side = = <default>
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 3, flammable = 2, attached_node = 1},
    sounds = sounds.node_sound_wood_defaults(),
})

minetest.register_node("civi_core:fence_wood", {
    description = "Wooden Fence",
    drawtype = "fencelike",
    tiles = {"civi_fence_wood.png"},
    inventory_image = "civi_fence_wood.png",
    wield_image = "civi_fence_wood.png",
    paramtype = "light",
    sunlight_propagates = true,
    is_ground_content = false,
    selection_box = {
        type = "fixed",
        fixed = {-1/5, -1/2, -1/5, 1/5, 1/2, 1/5}
    },
    collision_box = {
        type = "fixed",
        fixed = {-1/2, -1/2, -1/2, 1/2, 1, 1/2}
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, fence = 1},
    sounds = sounds.node_sound_wood_defaults(),
})

-- =========================================================
-- 4. DER ASPHALT-BLOCK (Kern-Feature)
-- =========================================================

minetest.register_node("civi_core:asphalt", {
    description = "Civi Asphalt (Speed: 1.8x)",
    tiles = {"civi_asphalt.png"},
    groups = {cracky = 2, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
})

-- =========================================================
-- 4. LEAF DECAY SYSTEM
-- =========================================================

local function leafdecay_after_destruct(pos, oldnode, def)
    for _, v in pairs(minetest.find_nodes_in_area(vector.subtract(pos, def.radius),
            vector.add(pos, def.radius), def.leaves)) do
        local node = minetest.get_node(v)
        local timer = minetest.get_node_timer(v)
        if node.param2 ~= 1 and not timer:is_started() then
            timer:start(math.random(20, 120) / 10)
        end
    end
end

local function leafdecay_on_timer(pos, def)
    if minetest.find_node_near(pos, def.radius, def.trunks) then
        return false
    end

    local node = minetest.get_node(pos)
    local drops = minetest.get_node_drops(node.name)
    for _, item in ipairs(drops) do
        minetest.add_item({
            x = pos.x - 0.5 + math.random(),
            y = pos.y - 0.5 + math.random(),
            z = pos.z - 0.5 + math.random(),
        }, item)
    end

    minetest.remove_node(pos)
    minetest.check_for_falling(pos)
end

function civi_core_register_leafdecay(def)
    for _, v in pairs(def.trunks) do
        minetest.override_item(v, {
            after_destruct = function(pos, oldnode)
                leafdecay_after_destruct(pos, oldnode, def)
            end,
        })
    end
    for _, v in pairs(def.leaves) do
        minetest.override_item(v, {
            on_timer = function(pos)
                leafdecay_on_timer(pos, def)
            end,
        })
    end
end

civi_core_register_leafdecay({
    trunks = {"civi_core:tree"},
    leaves = {"civi_core:leaves", "civi_core:apple"},
    radius = 3,
})

-- =========================================================
-- 4. PLAYER-ANIMATIONEN UND SPEED
-- =========================================================

-- =========================================================
-- 4. PLAYER-STAT-TRACKING UND GLOBALSTEP (Animationen & Speed)
-- =========================================================

local player_stats = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local stats = player_stats[name]
        if not stats then
            player_stats[name] = {
                last_up = false,
                last_press_time = 0,
                is_sprinting = false,
                current_speed = 1.0,
                current_anim = "",
            }
            stats = player_stats[name]
        end

        local pos = player:get_pos()
        local ctrl = player:get_player_control()
        -- 1. Double-Tap "W" Erkennung
        if ctrl.up and not stats.last_up then
            local now = minetest.get_us_time() / 1000000
            if (now - stats.last_press_time) < 0.3 then
                stats.is_sprinting = true
            end
            stats.last_press_time = now
        end
        stats.last_up = ctrl.up

        -- Sprint-Abbruch
        if not ctrl.up or ctrl.sneak then
            stats.is_sprinting = false
        end

        -- 2. Geschwindigkeits-Berechnung
        local base_speed = 1.0
        local node_pos = {x = pos.x, y = pos.y - 0.5, z = pos.z}
        local node = minetest.get_node_or_nil(node_pos)
        if node and node.name == "civi_core:asphalt" then
            base_speed = 1.8
        end

        local final_speed = base_speed
        if stats.is_sprinting then
            final_speed = final_speed * 1.5
        elseif ctrl.sneak then
            final_speed = final_speed * 0.4
        end

        -- Nur Updaten wenn nötig
        if final_speed ~= stats.current_speed then
            player:set_physics_override({
                speed = final_speed,
                jump = 1.0,
                gravity = 1.0
            })
            stats.current_speed = final_speed
        end

        -- 3. Animations-Logik
        local anim = "stand"
        if ctrl.up or ctrl.down or ctrl.left or ctrl.right then
            anim = "walk"
        end
        if ctrl.LMB then
            anim = (anim == "walk") and "walk_mine" or "mine"
        end

        -- Animation-Frames und Geschwindigkeit
        local anim_speed = 30 * final_speed
        if anim == "stand" then anim_speed = 30 end

        if stats.current_anim ~= anim or (anim ~= "stand" and math.abs(stats.last_anim_speed - anim_speed) > 5) then
            if anim == "walk" then
                player:set_animation({x = 168, y = 187}, anim_speed)
            elseif anim == "mine" then
                player:set_animation({x = 189, y = 198}, 30)
            elseif anim == "walk_mine" then
                player:set_animation({x = 200, y = 219}, anim_speed)
            else
                player:set_animation({x = 0, y = 79}, 30)
            end
            stats.current_anim = anim
            stats.last_anim_speed = anim_speed
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    player_stats[player:get_player_name()] = nil
end)

-- =========================================================
-- 5. BIOME-REGISTRIERUNG (für Oberfläche, Ozean und Strände)
-- =========================================================

-- Ein Ozean-Biome für alles unter dem Meeresspiegel
minetest.register_biome({
    name = "ocean",
    node_top = "civi_core:dirt",
    depth_top = 1,
    node_filler = "civi_core:dirt",
    depth_filler = 3,
    node_stone = "civi_core:stone",
    node_water_top = "civi_core:water_source",
    depth_water_top = 10,
    y_min = -31000,
    y_max = -4,
    heat_point = 50,
    humidity_point = 50,
})

-- Ein Strand-Biome für den Übergang (Sand am Wasser)
-- Deckt den Bereich von -3 bis 2 ab (3 unter Wasser, 2 über Wasser)
minetest.register_biome({
    name = "beach",
    node_top = "civi_core:sand",
    depth_top = 1,
    node_filler = "civi_core:sand",
    depth_filler = 3,
    y_min = -3,
    y_max = 2,
    heat_point = 50,
    humidity_point = 50,
})

-- Grasland für alles über dem Strand
minetest.register_biome({
    name = "grassland",
    node_top = "civi_core:dirt_with_grass",
    depth_top = 1,
    node_filler = "civi_core:dirt",
    depth_filler = 3,
    node_stone = "civi_core:stone",
    node_water_top = "civi_core:water_source",
    depth_water_top = 10,
    y_min = 3,
    y_max = 31000,
    heat_point = 50,
    humidity_point = 50,
})

-- =========================================================
-- 6. ABBAUEN/MINING: Die Hand als Werkzeug registrieren
-- =========================================================

minetest.register_item(":", {
    type = "none",
    wield_image = "civi_hand.png",
    wield_scale = {x=1, y=1, z=2.5},
    tool_capabilities = {
        full_punch_interval = 0.9,
        max_drop_level = 0,
        groupcaps = {
            crumbly = {times={[2]=3.00, [3]=0.70}, uses=0, maxlevel=1},
            cracky  = {times={[3]=3.00}, uses=0, maxlevel=1},
            snappy  = {times={[2]=0.80, [3]=0.40}, uses=0, maxlevel=1},
            choppy  = {times={[2]=4.00, [3]=3.00}, uses=0, maxlevel=1},
        },
        damage_groups = {fleshy=1},
    }
})

minetest.register_tool("civi_core:pick_wood", {
    description = "Wooden Pickaxe",
    inventory_image = "civi_pick_wood.png",
    tool_capabilities = {
        full_punch_interval = 1.2,
        max_drop_level = 0,
        groupcaps = {
            cracky = {times={[3]=1.6}, uses=20, maxlevel=1},
        },
        damage_groups = {fleshy=2},
    },
    groups = {pickaxe = 1},
})

minetest.register_tool("civi_core:pick_stone", {
    description = "Stone Pickaxe",
    inventory_image = "civi_pick_stone.png",
    tool_capabilities = {
        full_punch_interval = 1.3,
        max_drop_level = 0,
        groupcaps = {
            cracky = {times={[2]=2.0, [3]=1.00}, uses=20, maxlevel=1},
        },
        damage_groups = {fleshy=3},
    },
    groups = {pickaxe = 1},
})

minetest.register_tool("civi_core:axe_iron", {
    description = "Iron Axe",
    inventory_image = "civi_axe_iron.png",
    tool_capabilities = {
        full_punch_interval = 1.0,
        max_drop_level = 1,
        groupcaps = {
            choppy = {times={[1]=2.50, [2]=1.40, [3]=1.00}, uses=20, maxlevel=2},
            cracky = {times={[2]=2.0, [3]=1.0}, uses=20, maxlevel=2}, -- Added for Gold Ore mining as requested
        },
        damage_groups = {fleshy=4},
    },
    groups = {axe = 1},
})

-- Ingots (Barren)
minetest.register_craftitem("civi_core:steel_ingot", {
    description = "Steel Ingot",
    inventory_image = "civi_steel_ingot.png",
    groups = {toolrepair = 1},
})

minetest.register_craftitem("civi_core:copper_ingot", {
    description = "Copper Ingot",
    inventory_image = "civi_copper_ingot.png",
})

minetest.register_craftitem("civi_core:gold_ingot", {
    description = "Gold Ingot",
    inventory_image = "civi_gold_ingot.png",
})

minetest.register_craftitem("civi_core:stick", {
    description = "Stick",
    inventory_image = "civi_stick.png",
    groups = {stick = 1, flammable = 1},
})

-- =========================================================
-- 7. MAPGEN DECORATIONS (Bäume & Pflanzen)
-- =========================================================

-- Aliase für Schematics (die Apple_tree.mts nutzt default:tree/leaves)
minetest.register_alias("default:tree", "civi_core:tree")
minetest.register_alias("default:leaves", "civi_core:leaves")
minetest.register_alias("default:apple", "civi_core:apple")

minetest.register_decoration({
    name = "civi_core:apple_tree",
    deco_type = "schematic",
    place_on = {"civi_core:dirt_with_grass"},
    sidelen = 16,
    noise_params = {
        offset = 0.01,
        scale = 0.01,
        spread = {x = 100, y = 100, z = 100},
        seed = 2,
        octaves = 3,
        persist = 0.66
    },
    y_max = 31000,
    y_min = 1,
    schematic = minetest.get_modpath("civi_core") .. "/schematics/apple_tree.mts",
    flags = "place_center_x, place_center_z",
})

minetest.register_decoration({
    name = "civi_core:mushroom_brown",
    deco_type = "simple",
    place_on = {"civi_core:dirt_with_grass"},
    sidelen = 16,
    noise_params = {
        offset = 0,
        scale = 0.005,
        spread = {x = 100, y = 100, z = 100},
        seed = 13,
        octaves = 3,
        persist = 0.66
    },
    y_max = 31000,
    y_min = 1,
    decoration = "civi_core:mushroom_brown",
})

minetest.register_decoration({
    name = "civi_core:mushroom_red",
    deco_type = "simple",
    place_on = {"civi_core:dirt_with_grass"},
    sidelen = 16,
    noise_params = {
        offset = 0,
        scale = 0.002,
        spread = {x = 100, y = 100, z = 100},
        seed = 42,
        octaves = 3,
        persist = 0.66
    },
    y_max = 31000,
    y_min = 1,
    decoration = "civi_core:mushroom_red",
})

-- Die alte Strand-Dekoration wird durch das Biome ersetzt

-- =========================================================
-- 8. ERRUNGENSCHAFTEN & SPEZIAL-LOGIK
-- =========================================================

-- Fortschritt tracken und Stein-Drops beeinflussen
-- =========================================================
-- 6. ERFOLGE & SPIELFORTSCHRITT
-- =========================================================

if minetest.get_modpath("awards") then
    minetest.register_on_mods_loaded(function()
        if not _G.awards then return end
        awards.register_award("civi_core:hunter_gatherer", {
            title = "Hunter & Gatherer",
            description = "Mine wood and gather food to start your civilization.",
            icon = "civi_apple.png",
        })
        awards.register_award("civi_core:stone_age", {
            title = "Stone Age",
            description = "Craft a stone pickaxe to mine metal ores (Iron/Copper).",
            icon = "civi_pick_stone.png",
        })
        awards.register_award("civi_core:iron_age", {
            title = "Iron Age",
            description = "Craft an iron axe to mine gold and process wood faster.",
            icon = "civi_axe_iron.png",
        })
        awards.register_award("civi_core:age_of_fire", {
            title = "Age of Fire",
            description = "Craft a furnace to smelt ores into pure ingots.",
            icon = "civi_furnace_front.png",
        })
    end)
end

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    local name = digger:get_player_name()
    local meta = digger:get_meta()
    local held = digger:get_wielded_item():get_name()

    -- 1. Special Drop for Stone
    if oldnode.name == "civi_core:stone" then
        if minetest.get_item_group(held, "pickaxe") > 0 then
            -- With Pickaxe -> Add to Inventory (Auto-Pickup)
            local inv = digger:get_inventory()
            local leftover = inv:add_item("main", "civi_core:cobble")
            if not leftover:is_empty() then
                local obj = minetest.add_item(pos, leftover)
                if obj then
                    obj:set_velocity({x = math.random(-1, 1), y = 2, z = math.random(-1, 1)})
                end
            end
            -- Refresh UI
            if minetest.get_modpath("i3") then
                i3.set_fs(digger)
            end
        end
        -- Hand dug (defined by drop="")
    end

    -- 2. Achievement Tracking
    if meta:get_int("civi_core:ach_hunter_gatherer") == 0 then
        -- Wood collected?
        if oldnode.name == "civi_core:tree" then
            meta:set_int("civi_core:got_wood", 1)
        end
        -- Food collected?
        if oldnode.name == "civi_core:apple" or 
           oldnode.name == "civi_core:mushroom_brown" or 
           oldnode.name == "civi_core:mushroom_red" then
            meta:set_int("civi_core:got_food", 1)
        end

        -- Check if both requirements met
        if meta:get_int("civi_core:got_wood") == 1 and meta:get_int("civi_core:got_food") == 1 then
            meta:set_int("civi_core:ach_hunter_gatherer", 1)
            
            -- Play sound
            minetest.sound_play("civi_achievement", {to_player = name, gain = 1.0})
            
            -- Awards Mod Integration
            if minetest.get_modpath("awards") then
                awards.unlock(name, "civi_core:hunter_gatherer")
            end

            -- UI immediately update
            if i3 then
                i3.set_fs(digger)
            end
        end
    end
end)

-- Crafting Recipes
minetest.register_craft({
    output = "civi_core:stick 4",
    recipe = {
        {"", "", "group:leaves"},
        {"", "group:leaves", ""},
        {"group:leaves", "", ""},
    }
})

minetest.register_craft({
    output = "civi_core:paper 3",
    recipe = {
        {"group:leaves", "group:leaves", "group:leaves"},
    }
})

minetest.register_craft({
    output = "civi_core:wood 4",
    recipe = {
        {"civi_core:tree"},
    }
})

minetest.register_craft({
    output = "civi_core:stick 8",
    recipe = {
        {"civi_core:wood"},
    }
})

minetest.register_craft({
    output = "civi_core:torch 4",
    recipe = {
        {"civi_core:coal_lump"},
        {"civi_core:stick"},
        {"civi_core:stick"},
    }
})

-- Custom Wooden Pickaxe Recipe
minetest.register_craft({
    output = "civi_core:pick_wood",
    recipe = {
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
        {"", "civi_core:stick", ""},
        {"", "civi_core:stick", ""},
    }
})

minetest.register_craft({
    output = "civi_core:pick_stone",
    recipe = {
        {"civi_core:cobble", "civi_core:cobble", "civi_core:cobble"},
        {"", "civi_core:stick", ""},
        {"", "civi_core:stick", ""},
    }
})

minetest.register_craft({
    output = "civi_core:axe_iron",
    recipe = {
        {"civi_core:steel_ingot", "civi_core:steel_ingot", ""},
        {"civi_core:steel_ingot", "civi_core:stick", ""},
        {"", "civi_core:stick", ""},
    }
})

-- =========================================================
-- 9. FURNACE & SMELTING LOGIC
-- =========================================================

local function get_furnace_active_formspec(fuel_percent, item_percent)
    return "size[8,8.5]"..
        "list[context;src;2.75,0.5;1,1;]"..
        "list[context;fuel;2.75,2.5;1,1;]"..
        "image[2.75,1.5;1,1;civi_furnace_fire_bg.png^[lowpart:"..
        (fuel_percent)..":civi_furnace_fire_fg.png]"..
        "image[3.75,1.5;1,1;civi_gui_furnace_arrow_bg.png^[lowpart:"..
        (item_percent)..":civi_gui_furnace_arrow_fg.png^[transformR270]"..
        "list[context;dst;4.75,0.96;2,2;]"..
        "list[current_player;main;0,4.25;8,1;]"..
        "list[current_player;main;0,5.5;8,3;8]"..
        "listring[context;dst]"..
        "listring[current_player;main]"..
        "listring[context;src]"..
        "listring[current_player;main]"..
        "listring[context;fuel]"..
        "listring[current_player;main]"
end

local function get_furnace_inactive_formspec()
    return "size[8,8.5]"..
        "list[context;src;2.75,0.5;1,1;]"..
        "list[context;fuel;2.75,2.5;1,1;]"..
        "image[2.75,1.5;1,1;civi_furnace_fire_bg.png]"..
        "image[3.75,1.5;1,1;civi_gui_furnace_arrow_bg.png^[transformR270]"..
        "list[context;dst;4.75,0.96;2,2;]"..
        "list[current_player;main;0,4.25;8,1;]"..
        "list[current_player;main;0,5.5;8,3;8]"..
        "listring[context;dst]"..
        "listring[current_player;main]"..
        "listring[context;src]"..
        "listring[current_player;main]"..
        "listring[context;fuel]"..
        "listring[current_player;main]"
end

local function can_dig(pos, player)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    return inv:is_empty("fuel") and inv:is_empty("dst") and inv:is_empty("src")
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
    if listname == "fuel" then
        if minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0 then
            return stack:get_count()
        else
            return 0
        end
    elseif listname == "src" then
        return stack:get_count()
    elseif listname == "dst" then
        return 0
    end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local stack = inv:get_stack(from_list, from_index)
    return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
    return stack:get_count()
end

local function swap_node(pos, name)
    local node = minetest.get_node(pos)
    if node.name == name then return end
    node.name = name
    minetest.swap_node(pos, node)
end

local function furnace_node_timer(pos, elapsed)
    local meta = minetest.get_meta(pos)
    local fuel_time = meta:get_float("fuel_time") or 0
    local src_time = meta:get_float("src_time") or 0
    local fuel_totaltime = meta:get_float("fuel_totaltime") or 0
    local inv = meta:get_inventory()
    local update = true

    while elapsed > 0 and update do
        update = false
        local srclist = inv:get_list("src")
        local fuellist = inv:get_list("fuel")

        local cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
        local cookable = cooked.time ~= 0

        local el = math.min(elapsed, fuel_totaltime - fuel_time)
        if cookable then
            el = math.min(el, cooked.time - src_time)
        end

        if fuel_time < fuel_totaltime then
            fuel_time = fuel_time + el
            if cookable then
                src_time = src_time + el
                if src_time >= cooked.time then
                    if inv:room_for_item("dst", cooked.item) then
                        inv:add_item("dst", cooked.item)
                        inv:set_stack("src", 1, aftercooked.items[1])
                        src_time = src_time - cooked.time
                        update = true
                    end
                else
                    update = true
                end
            end
        else
            if cookable then
                local fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})
                if fuel.time > 0 then
                    inv:set_stack("fuel", 1, afterfuel.items[1])
                    fuel_totaltime = fuel.time
                    fuel_time = 0
                    update = true
                else
                    fuel_totaltime = 0
                    src_time = 0
                end
            else
                fuel_totaltime = 0
                src_time = 0
            end
        end
        elapsed = elapsed - el
    end

    local item_percent = 0
    local srclist = inv:get_list("src")
    local cooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
    if cooked.time ~= 0 then
        item_percent = math.floor(src_time / cooked.time * 100)
    end

    if fuel_totaltime ~= 0 then
        local fuel_percent = 100 - math.floor(fuel_time / fuel_totaltime * 100)
        meta:set_string("formspec", get_furnace_active_formspec(fuel_percent, item_percent))
        swap_node(pos, "civi_core:furnace_active")
        meta:set_string("infotext", "Furnace active")
        return true
    else
        meta:set_string("formspec", get_furnace_inactive_formspec())
        swap_node(pos, "civi_core:furnace")
        meta:set_string("infotext", "Furnace inactive")
        return false
    end
end

minetest.register_node("civi_core:furnace", {
    description = "Furnace",
    tiles = {
        "civi_furnace_top.png", "civi_furnace_bottom.png",
        "civi_furnace_side.png", "civi_furnace_side.png",
        "civi_furnace_side.png", "civi_furnace_front.png"
    },
    paramtype2 = "facedir",
    groups = {cracky=2},
    can_dig = can_dig,
    on_timer = furnace_node_timer,
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        inv:set_size('src', 1)
        inv:set_size('fuel', 1)
        inv:set_size('dst', 4)
        meta:set_string("formspec", get_furnace_inactive_formspec())
    end,
    on_metadata_inventory_put = function(pos)
        minetest.get_node_timer(pos):start(1.0)
    end,
    on_metadata_inventory_take = function(pos)
        minetest.get_node_timer(pos):start(1.0)
    end,
    allow_metadata_inventory_put = allow_metadata_inventory_put,
    allow_metadata_inventory_move = allow_metadata_inventory_move,
    allow_metadata_inventory_take = allow_metadata_inventory_take,
})

minetest.register_node("civi_core:furnace_active", {
    description = "Furnace",
    tiles = {
        "civi_furnace_top.png", "civi_furnace_bottom.png",
        "civi_furnace_side.png", "civi_furnace_side.png",
        "civi_furnace_side.png",
        {
            name = "civi_furnace_front_active.png",
            animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.5},
        }
    },
    paramtype2 = "facedir",
    light_source = 8,
    drop = "civi_core:furnace",
    groups = {cracky=2, not_in_creative_inventory=1},
    on_timer = furnace_node_timer,
    can_dig = can_dig,
    allow_metadata_inventory_put = allow_metadata_inventory_put,
    allow_metadata_inventory_move = allow_metadata_inventory_move,
    allow_metadata_inventory_take = allow_metadata_inventory_take,
})

-- Smelting Recipes
minetest.register_craft({
    type = "cooking",
    output = "civi_core:steel_ingot",
    recipe = "civi_core:iron_lump",
    cooktime = 3,
})

minetest.register_craft({
    type = "cooking",
    output = "civi_core:gold_ingot",
    recipe = "civi_core:gold_lump",
    cooktime = 3,
})

minetest.register_craft({
    type = "cooking",
    output = "civi_core:copper_ingot",
    recipe = "civi_core:copper_lump",
    cooktime = 3,
})

-- Furnace Recipe
minetest.register_craft({
    output = "civi_core:furnace",
    recipe = {
        {"civi_core:cobble", "civi_core:cobble", "civi_core:cobble"},
        {"civi_core:cobble", "", "civi_core:cobble"},
        {"civi_core:cobble", "civi_core:cobble", "civi_core:cobble"},
    }
})

-- Construction Blocks
minetest.register_craft({
    output = "civi_core:stone_brick 4",
    recipe = {
        {"civi_core:stone", "civi_core:stone"},
        {"civi_core:stone", "civi_core:stone"},
    }
})

minetest.register_craft({
    output = "civi_core:brick 4",
    recipe = {
        {"civi_core:dirt", "civi_core:dirt"},
        {"civi_core:dirt", "civi_core:dirt"},
    }
})

-- Metal & Gem Blocks
minetest.register_craft({
    output = "civi_core:bronze_block",
    recipe = {
        {"civi_core:copper_ingot", "civi_core:copper_ingot", "civi_core:copper_ingot"},
        {"civi_core:copper_ingot", "civi_core:steel_ingot", "civi_core:copper_ingot"},
        {"civi_core:copper_ingot", "civi_core:copper_ingot", "civi_core:copper_ingot"},
    }
})

minetest.register_craft({
    output = "civi_core:gold_block",
    recipe = {
        {"civi_core:gold_ingot", "civi_core:gold_ingot", "civi_core:gold_ingot"},
        {"civi_core:gold_ingot", "civi_core:gold_ingot", "civi_core:gold_ingot"},
        {"civi_core:gold_ingot", "civi_core:gold_ingot", "civi_core:gold_ingot"},
    }
})

-- Utility & Furniture
minetest.register_craft({
    output = "civi_core:bookshelf",
    recipe = {
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
        {"civi_core:stick", "civi_core:stick", "civi_core:stick"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
    }
})

minetest.register_craft({
    output = "civi_core:ladder 4",
    recipe = {
        {"civi_core:stick", "", "civi_core:stick"},
        {"civi_core:stick", "civi_core:stick", "civi_core:stick"},
        {"civi_core:stick", "", "civi_core:stick"},
    }
})

minetest.register_craft({
    output = "civi_core:fence_wood 2",
    recipe = {
        {"civi_core:stick", "civi_core:stick", "civi_core:stick"},
        {"civi_core:stick", "civi_core:stick", "civi_core:stick"},
    }
})

-- Wood Variant Plank Crafts
local woods = {"acacia", "aspen", "jungle", "pine"}
for _, wood in ipairs(woods) do
    minetest.register_craft({
        output = "civi_core:" .. wood .. "_wood 4",
        recipe = {{"civi_core:" .. wood .. "_tree"}},
    })
end

-- Crafting Logic: Progress & Achievements
minetest.register_on_craft(function(itemstack, crafter, recipe, inventory)
    local name = itemstack:get_name()
    local meta = crafter:get_meta()
    local p_name = crafter:get_player_name()

    -- 1. Progress Lock: Sticks only after Hunter & Gatherer
    if name == "civi_core:stick" then
        if meta:get_int("civi_core:ach_hunter_gatherer") ~= 1 then
            minetest.chat_send_player(p_name, "[System] You must become a 'Hunter & Gatherer' first (mine wood & gather food)!")
            return ItemStack("") -- Verhindert das Crafting
        end
    end

    -- 2. Achievement Trigger: Stone Age
    if name == "civi_core:pick_stone" then
        if meta:get_int("civi_core:ach_stone_age") == 0 then
            meta:set_int("civi_core:ach_stone_age", 1)
            minetest.sound_play("civi_achievement", {to_player = p_name, gain = 1.0})
            if minetest.get_modpath("awards") then
                awards.unlock(p_name, "civi_core:stone_age")
            end
        end
    end

    -- 3. Achievement Trigger: Iron Age
    if name == "civi_core:axe_iron" then
        if meta:get_int("civi_core:ach_iron_age") == 0 then
            meta:set_int("civi_core:ach_iron_age", 1)
            minetest.sound_play("civi_achievement", {to_player = p_name, gain = 1.0})
            if minetest.get_modpath("awards") then
                awards.unlock(p_name, "civi_core:iron_age")
            end
        end
    end

    -- 4. Achievement Trigger: Age of Fire
    if name == "civi_core:furnace" then
        if meta:get_int("civi_core:ach_age_of_fire") == 0 then
            meta:set_int("civi_core:ach_age_of_fire", 1)
            minetest.sound_play("civi_achievement", {to_player = p_name, gain = 1.0})
            if minetest.get_modpath("awards") then
                awards.unlock(p_name, "civi_core:age_of_fire")
            end
        end
    end

    return itemstack
end)

print("[myCraftCivi] civi_core successfully loaded!")
-- Chat-Kommando als Fallback
minetest.register_chatcommand("inv", {
    description = "Opens the inventory manually",
    func = function(name)
        local p = minetest.get_player_by_name(name)
        if p then
            local fs = p:get_inventory_formspec()
            if fs == "" then
                fs = "formspec_version[4]size[12,8]label[1,0.5;Inventory (Fallback)]list[current_player;main;1,1;8,4;]listring[current_player;main]"
            end
            minetest.show_formspec(name, "civi_core:inventory", fs)
            return true, "Inventory opened."
        end
        return false, "Player not found."
    end,
})