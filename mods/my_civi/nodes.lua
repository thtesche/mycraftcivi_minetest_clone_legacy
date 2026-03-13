-- my_civi/nodes.lua
-- Node definitions (blocks)

-- Asphalt/Tarmac Road
minetest.register_node("my_civi:asphalt_road", {
    description = "Asphalt Road",
    tiles = {"my_civi_asphalt.png"},
    groups = {cracky = 3, road = 1},
    sounds = mod_default and mod_default.node_sound_stone_defaults(),
})
