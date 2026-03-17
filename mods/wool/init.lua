-- Wool shim
local colors = {
    "black", "blue", "brown", "cyan", "dark_green", "dark_grey",
    "green", "grey", "magenta", "orange", "pink", "red", "violet",
    "white", "yellow"
}

for _, color in ipairs(colors) do
    minetest.register_node("wool:" .. color, {
        description = color:gsub("^%l", string.upper) .. " Wool",
        tiles = {"wool_" .. color .. ".png"},
        groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 3, flammable = 1, wool = 1},
    })
end
