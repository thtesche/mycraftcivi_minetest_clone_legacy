-- my_civi/init.lua
-- Central hub for myCraftCivi

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Load modules
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/crafting.lua")
dofile(modpath .. "/player.lua")

minetest.log("action", "[" .. modname .. "] Loaded!")
