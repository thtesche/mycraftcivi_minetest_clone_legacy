-- wool/init.lua

-- Load support for MT game translation.
local S = minetest.get_translator("wool")

local dyes = dye.dyes

local wool_colors = {
	{"black",      "Black",      "#000000b0"},
	{"blue",       "Blue",       "#015dbb70"},
	{"brown",      "Brown",      "#663300a0"},
	{"cyan",       "Cyan",       "#01ffd870"},
	{"dark_green", "Dark Green", "#005b0770"},
	{"dark_grey",  "Dark Grey",  "#303030b0"},
	{"green",      "Green",      "#61ff0170"},
	{"grey",       "Grey",       "#5b5b5bb0"},
	{"magenta",    "Magenta",    "#ff05bb70"},
	{"orange",     "Orange",     "#ff840170"},
	{"pink",       "Pink",       "#ff65b570"},
	{"red",        "Red",        "#ff0000a0"},
	{"violet",     "Violet",     "#2000c970"},
	{"white",      "White",      "#abababc0"},
	{"yellow",     "Yellow",     "#e3ff0070"},
}

for i = 1, #wool_colors do
	local name = wool_colors[i][1]
	local desc = wool_colors[i][2]
	local hex  = wool_colors[i][3]

	local color_group = "color_" .. name

	minetest.register_node("wool:" .. name, {
		description = S(desc .. " Wool"),
		tiles = {"wool_white.png^[colorize:" .. hex},
		is_ground_content = false,
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 3,
				flammable = 3, wool = 1, [color_group] = 1},
		sounds = sounds.node_sound_defaults(),
	})

	minetest.register_craft{
		type = "shapeless",
		output = "wool:" .. name,
		recipe = {"group:dye,color_" .. name, "group:wool"},
	}
end

-- Legacy
-- Backwards compatibility with jordach's 16-color wool mod
minetest.register_alias("wool:dark_blue", "wool:blue")
minetest.register_alias("wool:gold", "wool:yellow")

-- Dummy calls to S() to allow translation scripts to detect the strings.
-- To update this run:
-- for _,e in ipairs(dye.dyes) do print(("S(%q)"):format(e[2].." Wool")) end

--[[
S("White Wool")
S("Grey Wool")
S("Dark Grey Wool")
S("Black Wool")
S("Violet Wool")
S("Blue Wool")
S("Cyan Wool")
S("Dark Green Wool")
S("Green Wool")
S("Yellow Wool")
S("Brown Wool")
S("Orange Wool")
S("Red Wool")
S("Magenta Wool")
S("Pink Wool")
--]]
