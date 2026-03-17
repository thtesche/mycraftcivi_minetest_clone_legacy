-- default shim for myCraftCivi
-- Aliases default nodes to civi_core nodes

default = {}

-- Node Aliases
local nodes = {
    "stone", "dirt", "dirt_with_grass", "sand", "wood", "tree", "leaves", 
    "glass", "ice", "snowblock", "snow", "cobble",
    "stone_with_coal", "stone_with_iron", "stone_with_copper", "stone_with_gold",
    "torch"
}

for _, name in ipairs(nodes) do
    minetest.register_alias("default:" .. name, "civi_core:" .. name)
end

-- Item Aliases
local items = {
    "coal_lump", "iron_lump", "copper_lump", "gold_lump", "stick", "apple"
}

for _, name in ipairs(items) do
    minetest.register_alias("default:" .. name, "civi_core:" .. name)
end

-- Sound Helpers (Proxy to civi_core sounds if available)
-- These are expected by many mods from minetest_game
default.node_sound_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_defaults then return sounds.node_sound_defaults(tbl) end
    return {}
end

default.node_sound_stone_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_stone_defaults then return sounds.node_sound_stone_defaults(tbl) end
    return {}
end

default.node_sound_dirt_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_dirt_defaults then return sounds.node_sound_dirt_defaults(tbl) end
    return {}
end

default.node_sound_sand_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_sand_defaults then return sounds.node_sound_sand_defaults(tbl) end
    return {}
end

default.node_sound_wood_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_wood_defaults then return sounds.node_sound_wood_defaults(tbl) end
    return {}
end

default.node_sound_leaves_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_leaves_defaults then return sounds.node_sound_leaves_defaults(tbl) end
    return {}
end

default.node_sound_glass_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_glass_defaults then return sounds.node_sound_glass_defaults(tbl) end
    return {}
end

default.node_sound_ice_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_ice_defaults then return sounds.node_sound_ice_defaults(tbl) end
    return {}
end

default.node_sound_snow_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_snow_defaults then return sounds.node_sound_snow_defaults(tbl) end
    return {}
end

default.node_sound_water_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_water_defaults then return sounds.node_sound_water_defaults(tbl) end
    return {}
end

print("[Default Shim] Loaded with Sound Helpers.")

