-- civi_stairs: init.lua
-- Stairs and slabs for myCraftCivi building materials.
-- Ported and adapted from minetest_game/mods/stairs

stairs = {}

-- Helper function to rotate and place nodes
local function rotate_and_place(itemstack, placer, pointed_thing)
	local p0 = pointed_thing.under
	local p1 = pointed_thing.above
	local param2 = 0

	if placer then
		local placer_pos = placer:get_pos()
		if placer_pos then
			local diff = vector.subtract(p1, placer_pos)
			param2 = minetest.dir_to_facedir(diff)
			-- The player places a node on the side face of the node he is standing on
			if p0.y == p1.y and math.abs(diff.x) <= 0.5 and math.abs(diff.z) <= 0.5 and diff.y < 0 then
				-- reverse node direction
				param2 = (param2 + 2) % 4
			end
		end

		local finepos = minetest.pointed_thing_to_face_pos(placer, pointed_thing)
		local fpos = finepos.y % 1

		if p0.y - 1 == p1.y or (fpos > 0 and fpos < 0.5)
				or (fpos < -0.5 and fpos > -0.999999999) then
			param2 = param2 + 20
			if param2 == 21 then
				param2 = 23
			elseif param2 == 23 then
				param2 = 21
			end
		end
	end
	return minetest.item_place(itemstack, placer, pointed_thing, param2)
end

-- Set backface culling and world-aligned textures
local function set_textures(images)
	local stair_images = {}
	for i, image in ipairs(images) do
		stair_images[i] = type(image) == "string" and {name = image} or table.copy(image)
		if stair_images[i].backface_culling == nil then
			stair_images[i].backface_culling = true
		end
	end
	return stair_images
end

-- Register stair
function stairs.register_stair(subname, recipeitem, groups, images, description, sounds)
	local def = minetest.registered_nodes[recipeitem] or {}
	local stair_images = set_textures(images)
	local new_groups = table.copy(groups)
	new_groups.stair = 1

	minetest.register_node(":civi_stairs:stair_" .. subname, {
		description = description,
		drawtype = "nodebox",
		tiles = stair_images,
		use_texture_alpha = def.use_texture_alpha,
		sunlight_propagates = def.sunlight_propagates,
		light_source = def.light_source,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = new_groups,
		sounds = sounds or def.sounds,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.5, 0.5, 0.5},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	})

	if recipeitem then
		minetest.register_craft({
			output = "civi_stairs:stair_" .. subname .. " 8",
			recipe = {
				{"", "", recipeitem},
				{"", recipeitem, recipeitem},
				{recipeitem, recipeitem, recipeitem},
			},
		})
	end
end

-- Register slab
function stairs.register_slab(subname, recipeitem, groups, images, description, sounds)
	local def = minetest.registered_nodes[recipeitem] or {}
	local slab_images = set_textures(images)
	local new_groups = table.copy(groups)
	new_groups.slab = 1

	minetest.register_node(":civi_stairs:slab_" .. subname, {
		description = description,
		drawtype = "nodebox",
		tiles = slab_images,
		use_texture_alpha = def.use_texture_alpha,
		sunlight_propagates = def.sunlight_propagates,
		light_source = def.light_source,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = new_groups,
		sounds = sounds or def.sounds,
		node_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
		},
		on_place = function(itemstack, placer, pointed_thing)
			local under = minetest.get_node(pointed_thing.under)
			local wield_item = itemstack:get_name()
			local player_name = placer and placer:get_player_name() or ""

			if under and under.name:find("^civi_stairs:slab_") then
				local dir = minetest.dir_to_facedir(vector.subtract(
					pointed_thing.above, pointed_thing.under), true)
				local p2 = under.param2

				if p2 >= 20 and dir == 8 then
					p2 = p2 - 20
				elseif p2 <= 3 and dir == 4 then
					p2 = p2 + 20
				end

				minetest.item_place_node(ItemStack(wield_item), placer, pointed_thing, p2)
				if not minetest.is_creative_enabled(player_name) then
					itemstack:take_item()
				end
				return itemstack
			else
				return rotate_and_place(itemstack, placer, pointed_thing)
			end
		end,
	})

	if recipeitem then
		minetest.register_craft({
			output = "civi_stairs:slab_" .. subname .. " 6",
			recipe = {
				{recipeitem, recipeitem, recipeitem},
			},
		})
	end
end

-- Register inner stair
function stairs.register_stair_inner(subname, recipeitem, groups, images, description, sounds)
	local def = minetest.registered_nodes[recipeitem] or {}
	local stair_images = set_textures(images)
	local new_groups = table.copy(groups)
	new_groups.stair = 1

	minetest.register_node(":civi_stairs:stair_inner_" .. subname, {
		description = "Inner " .. description,
		drawtype = "nodebox",
		tiles = stair_images,
		use_texture_alpha = def.use_texture_alpha,
		sunlight_propagates = def.sunlight_propagates,
		light_source = def.light_source,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = new_groups,
		sounds = sounds or def.sounds,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.5, 0.5, 0.5},
				{-0.5, 0.0, -0.5, 0.0, 0.5, 0.0},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	})
end

-- Register outer stair
function stairs.register_stair_outer(subname, recipeitem, groups, images, description, sounds)
	local def = minetest.registered_nodes[recipeitem] or {}
	local stair_images = set_textures(images)
	local new_groups = table.copy(groups)
	new_groups.stair = 1

	minetest.register_node(":civi_stairs:stair_outer_" .. subname, {
		description = "Outer " .. description,
		drawtype = "nodebox",
		tiles = stair_images,
		use_texture_alpha = def.use_texture_alpha,
		sunlight_propagates = def.sunlight_propagates,
		light_source = def.light_source,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = new_groups,
		sounds = sounds or def.sounds,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.0, 0.5, 0.5},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	})
end

-- Stair/slab registration function
function stairs.register_stair_and_slab(subname, recipeitem, groups, images, desc_stair, desc_slab, sounds)
	stairs.register_stair(subname, recipeitem, groups, images, desc_stair, sounds)
	stairs.register_stair_inner(subname, recipeitem, groups, images, desc_stair, sounds)
	stairs.register_stair_outer(subname, recipeitem, groups, images, desc_stair, sounds)
	stairs.register_slab(subname, recipeitem, groups, images, desc_slab, sounds)
end

-- =========================================================
-- Registration for civi_core building materials
-- =========================================================

-- Wood variants
stairs.register_stair_and_slab("wood", "civi_core:wood", 
	{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}, 
	{"civi_wood.png"}, "Wooden Stair", "Wooden Slab", sounds.node_sound_wood_defaults())

stairs.register_stair_and_slab("acacia_wood", "civi_core:acacia_wood", 
	{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}, 
	{"civi_acacia_wood.png"}, "Acacia Wood Stair", "Acacia Wood Slab", sounds.node_sound_wood_defaults())

stairs.register_stair_and_slab("aspen_wood", "civi_core:aspen_wood", 
	{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}, 
	{"civi_aspen_wood.png"}, "Aspen Wood Stair", "Aspen Wood Slab", sounds.node_sound_wood_defaults())

stairs.register_stair_and_slab("junglewood", "civi_core:junglewood", 
	{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}, 
	{"civi_junglewood.png"}, "Jungle Wood Stair", "Jungle Wood Slab", sounds.node_sound_wood_defaults())

stairs.register_stair_and_slab("pine_wood", "civi_core:pine_wood", 
	{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}, 
	{"civi_pine_wood.png"}, "Pine Wood Stair", "Pine Wood Slab", sounds.node_sound_wood_defaults())

-- Stone variants
stairs.register_stair_and_slab("stone", "civi_core:stone", 
	{cracky = 3, stone = 1}, 
	{"civi_stone.png"}, "Stone Stair", "Stone Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("cobble", "civi_core:cobble", 
	{cracky = 3, stone = 1}, 
	{"civi_cobble.png"}, "Cobblestone Stair", "Cobblestone Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("stone_brick", "civi_core:stone_brick", 
	{cracky = 2, stone = 1}, 
	{"civi_stone_brick.png"}, "Stone Brick Stair", "Stone Brick Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("brick", "civi_core:brick", 
	{cracky = 3}, 
	{"civi_brick.png"}, "Brick Stair", "Brick Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("desert_stone", "civi_core:desert_stone", 
	{cracky = 3, stone = 1}, 
	{"civi_desert_stone.png"}, "Desert Stone Stair", "Desert Stone Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("sandstone", "civi_core:sandstone", 
	{crumbly = 2, cracky = 3, stone = 1}, 
	{"civi_sandstone.png"}, "Sandstone Stair", "Sandstone Slab", sounds.node_sound_stone_defaults())

-- Metal blocks
stairs.register_stair_and_slab("bronze_block", "civi_core:bronze_block", 
	{cracky = 1, level = 2}, 
	{"civi_bronze_block.png"}, "Bronze Block Stair", "Bronze Block Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("gold_block", "civi_core:gold_block", 
	{cracky = 1}, 
	{"civi_gold_block.png"}, "Gold Block Stair", "Gold Block Slab", sounds.node_sound_stone_defaults())

stairs.register_stair_and_slab("diamond_block", "civi_core:diamond_block", 
	{cracky = 1, level = 3}, 
	{"civi_diamond_block.png"}, "Diamond Block Stair", "Diamond Block Slab", sounds.node_sound_stone_defaults())

-- Special blocks
stairs.register_stair_and_slab("asphalt", "civi_core:asphalt", 
	{cracky = 2, stone = 1}, 
	{"civi_asphalt.png"}, "Asphalt Stair", "Asphalt Slab", sounds.node_sound_stone_defaults())

print("[civi_stairs] Mod loaded!")
