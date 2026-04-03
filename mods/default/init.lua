-- default shim for myCraftCivi
-- Aliases default nodes to civi_core nodes

default = {}

-- Node Aliases
local nodes = {
    "stone", "dirt", "dirt_with_grass", "sand", "wood",
    "acacia_wood", "junglewood", "pine_wood", "aspen_wood",
    "glass", "ice", "snowblock", "snow", "cobble",
    "stone_with_coal", "stone_with_iron", "stone_with_copper", "stone_with_gold",
    "torch", "gravel", "mossycobble", "desert_cobble", "paper"
}

for _, name in ipairs(nodes) do
    minetest.register_alias("default:" .. name, "civi_core:" .. name)
end

minetest.register_alias("default:steel_block", "civi_core:steel_block")
minetest.register_alias("default:obsidian", "civi_core:obsidian")
minetest.register_alias("default:obsidian_glass", "civi_core:obsidian_glass")

-- Item Aliases
local items = {
    "coal_lump", "iron_lump", "copper_lump", "gold_lump", "stick", "coalblock"
}

for _, name in ipairs(items) do
    minetest.register_alias("default:" .. name, "civi_core:" .. name)
end

minetest.register_alias("default:steel_ingot", "civi_core:steel_ingot")

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

default.node_sound_metal_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_metal_defaults then return sounds.node_sound_metal_defaults(tbl) end
    return {}
end

default.node_sound_gravel_defaults = function(tbl)
    if _G.sounds and sounds.node_sound_gravel_defaults then return sounds.node_sound_gravel_defaults(tbl) end
    return {}
end

-- General functions
function default.can_interact_with_node(player, pos)
	if player and player:get_player_name() then
		if minetest.check_player_privs(player, "protection_bypass") then
			return true
		end
	end
	return not minetest.is_protected(pos, player and player:get_player_name() or "")
end

print("[Default Shim] Loaded.")

