-- my_civi/crafting.lua
-- Recipe definitions

minetest.register_craft({
    output = "my_civi:asphalt_road 8",
    recipe = {
        {"default:gravel", "default:gravel", "default:gravel"},
        {"default:coal_lump", "default:coal_lump", "default:coal_lump"},
        {"default:gravel", "default:gravel", "default:gravel"},
    }
})
