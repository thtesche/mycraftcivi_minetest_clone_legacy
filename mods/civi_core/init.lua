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
    -- Configure player model and appearance
    player:set_properties({
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        visual_size = {x = 1, y = 1},
        collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
        stepheight = 0.6,
        eye_height = 1.47,
    })

    -- Inventory size and starting equipment (8x4 Grid = 32 Slots)
    local inv = player:get_inventory()
    if inv then
        inv:set_size("main", 32)
        inv:set_size("craft", 9)
        print("[myCraftCivi] Inventory & Crafting for " .. name .. " initialized")
    end


    -- Local animations for 1st person (arms when walking etc.)
    player:set_local_animation(
        {x = 0,   y = 79},  -- stand
        {x = 168, y = 187}, -- walk
        {x = 189, y = 198}, -- mine
        {x = 200, y = 219}, -- walk_mine
        30 -- animation speed
    )

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

local sounds = {}

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
    groups = {crumbly = 3, soil = 1},
    sounds = sounds.node_sound_dirt_defaults(),
})

minetest.register_node("civi_core:dirt_with_grass", {
    description = "Dirt with Grass",
    tiles = {"civi_grass.png", "civi_dirt.png", {name = "civi_dirt.png^civi_grass_side.png", tileable_vertical = false}},
    groups = {crumbly = 3, soil = 1},
    sounds = sounds.node_sound_dirt_defaults(),
})

minetest.register_node("civi_core:sand", {
    description = "Sand",
    tiles = {"civi_sand.png"},
    groups = {crumbly = 3, falling_node = 1, sand = 1},
    sounds = sounds.node_sound_sand_defaults(),
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

-- =========================================================
-- BÄUME UND NAHRUNG
-- =========================================================

minetest.register_node("civi_core:tree", {
    description = "Tree Trunk (Wood)",
    tiles = {"civi_tree_trunk_top.png", "civi_tree_trunk_top.png", "civi_tree_trunk.png"},
    groups = {tree = 1, choppy = 2, oddy_breakable_by_hand = 1, flammable = 2},
    sounds = sounds.node_sound_wood_defaults(),
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
    on_use = minetest.item_eat(2, "default_dig_crumbly"),
    on_place = minetest.item_eat(2, "default_dig_crumbly"),
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
    on_use = minetest.item_eat(1, "default_dig_crumbly"),
    on_place = minetest.item_eat(1, "default_dig_crumbly"),
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
    on_use = minetest.item_eat(-5, "default_dig_crumbly"),
    on_place = minetest.item_eat(-5, "default_dig_crumbly"),
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
    alpha = 160,
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
    alpha = 160,
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
-- 3. DER ASPHALT-BLOCK (Kern-Feature)
-- =========================================================

minetest.register_node("civi_core:asphalt", {
    description = "Civi Asphalt (Speed: 1.8x)",
    tiles = {"civi_asphalt.png"},
    groups = {cracky = 2, stone = 1},
    sounds = sounds.node_sound_stone_defaults(),
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
            player:set_physics_override({speed = final_speed})
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

minetest.register_tool("civi_core:stick", {
    description = "Primitive Stick",
    inventory_image = "civi_stick.png",
    wield_image = "civi_stick.png",
    tool_capabilities = {
        full_punch_interval = 0.8,
        max_drop_level = 0,
        groupcaps = {
            crumbly = {times={[1]=1.5, [2]=1.0, [3]=0.5}, uses=20, maxlevel=1},
            cracky  = {times={[3]=2.0}, uses=20, maxlevel=1},
            snappy  = {times={[2]=0.5, [3]=0.2}, uses=20, maxlevel=1},
            choppy  = {times={[2]=2.5, [3]=1.5}, uses=20, maxlevel=1},
        },
        damage_groups = {fleshy=2},
    }
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
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    local name = digger:get_player_name()
    local meta = digger:get_meta()
    local held = digger:get_wielded_item():get_name()

    -- 1. Special Drop for Stone
    if oldnode.name == "civi_core:stone" then
        if held == "civi_core:stick" then
            -- With Stick -> Drop Cobblestone
            local obj = minetest.add_item(pos, "civi_core:cobble")
            if obj then
                obj:set_velocity({x = math.random(-1, 1), y = 2, z = math.random(-1, 1)})
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
            minetest.chat_send_all("*** " .. name .. " unlocked the achievement 'Hunter & Gatherer'!")
            minetest.chat_send_player(name, "[System] You can now craft a stick from wood or leaves.")
            
            -- Play sound
            minetest.sound_play("civi_achievement", {to_player = name, gain = 1.0})
            
            -- UI immediately update
            if i3 then
                i3.update_inventory(digger)
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
    output = "civi_core:stick 4",
    recipe = {
        {"civi_core:tree"},
    }
})

-- Crafting Lock: Sticks only after Achievement
minetest.register_on_craft(function(itemstack, crafter, recipe, inventory)
    if itemstack:get_name() == "civi_core:stick" then
        local meta = crafter:get_meta()
        if meta:get_int("civi_core:ach_hunter_gatherer") ~= 1 then
            local name = crafter:get_player_name()
            minetest.chat_send_player(name, "[System] You must become a 'Hunter & Gatherer' first (mine wood & gather food)!")
            return ItemStack("") -- Verhindert das Crafting
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