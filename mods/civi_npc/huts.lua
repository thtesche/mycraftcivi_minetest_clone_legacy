-- civi_npc: huts.lua
-- Automatic spawning of lumberjack huts with NPCs

-- 1. SPAWNER NODE
-- This node triggers NPC spawning when the schematic is placed
-- Function to handle hut setup (foundation + NPC)
local function spawn_lumberjack_hut(pos)
    -- 1. STONE FOUNDATION: Fill 5x5 area underneath with stone if air/leaves
    for dx = -3, 3 do
        for dz = -3, 3 do
            local p_ground = {x=pos.x + dx, y=pos.y - 1, z=pos.z + dz}
            -- Fill down until solid ground or 5 blocks down
            for dy = 0, 4 do
                local p_under = {x=p_ground.x, y=p_ground.y - dy, z=p_ground.z}
                local node = minetest.get_node(p_under)
                if node.name == "air" or node.name:find("leaves") or node.name:find("water") then
                    minetest.set_node(p_under, {name = "civi_core:stone"})
                else
                    break -- Found solid ground
                end
            end
        end
    end

    -- 2. SPAWN NPC:
    local obj = minetest.add_entity(pos, "civi_npc:lumberjack")
    if obj then
        obj:set_pos({x=pos.x, y=pos.y + 0.1, z=pos.z})
        print("[civi_npc] Lumberjack spawned from mapgen hut at " .. minetest.pos_to_string(pos))
    end
    -- Remove spawner node
    minetest.remove_node(pos)
end

-- 1. SPAWNER NODE
-- This node triggers NPC spawning when the schematic is placed by mapgen
minetest.register_node("civi_npc:lumberjack_spawner", {
    description = "Lumberjack Spawner (Place inside schematic)",
    tiles = {"civi_lumberjack_spawner.png"}, 
    is_ground_content = false,
    groups = {dig_immediate = 3},
    -- No on_construct here! This allows players to place it for schematics.
})

-- 2. MAPGEN TRIGGER
-- Scan newly generated chunks for spawners
minetest.register_on_generated(function(minp, maxp, blockseed)
    local spawners = minetest.find_nodes_in_area(minp, maxp, {"civi_npc:lumberjack_spawner"})
    for _, pos in ipairs(spawners) do
        spawn_lumberjack_hut(pos)
    end
end)

-- 2. SCHEMATIC DECORATION
-- Places the lumberjack hut rarely in the world
minetest.register_decoration({
    name = "civi_npc:lumberjack_hut",
    deco_type = "schematic",
    place_on = {"civi_core:dirt_with_grass"},
    sidelen = 80,
    fill_ratio = 0.0002, -- Very rare (one in ~5000 grass nodes)
    biomes = nil, -- Apply to all grass biomes
    y_min = 1,
    y_max = 31000,
    schematic = minetest.get_modpath("civi_npc") .. "/../../schematics/lumberjack_hut.mts",
    flags = "place_center_x, place_center_z, force_placement",
    rotation = "random",
    -- Offset to ensure correct placement on ground (buried by 2 to accommodate foundation)
    place_offset_y = -2,
})

print("[civi_npc] Hut spawning logic initialized")
