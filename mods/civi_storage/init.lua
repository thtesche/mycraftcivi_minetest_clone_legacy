-- civi_storage: init.lua
print("[myCraftCivi] Loading civi_storage...")

civi_storage = {}
civi_storage.chest = {}
civi_storage.chest.open_chests = {}

-- Support for translations (placeholder)
local S = function(id) return id end

function civi_storage.chest.get_chest_formspec(pos)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    return "size[8,9]" ..
           "list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
           "list[current_player;main;0,4.85;8,1;]" ..
           "list[current_player;main;0,6.08;8,3;8]" ..
           "listring[nodemeta:" .. spos .. ";main]" ..
           "listring[current_player;main]"
end

function civi_storage.chest.chest_lid_obstructed(pos)
    local above = {x = pos.x, y = pos.y + 1, z = pos.z}
    local def = minetest.registered_nodes[minetest.get_node(above).name]
    if def and
            (def.drawtype == "airlike" or
            def.drawtype == "signlike" or
            def.drawtype == "torchlike" or
            (def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
        return false
    end
    return true
end

function civi_storage.chest.chest_lid_close(pn)
    local chest_open_info = civi_storage.chest.open_chests[pn]
    if not chest_open_info then return end

    local pos = chest_open_info.pos
    local sound = chest_open_info.sound
    local swap = chest_open_info.swap

    civi_storage.chest.open_chests[pn] = nil
    for k, v in pairs(civi_storage.chest.open_chests) do
        if vector.equals(v.pos, pos) then
            return true
        end
    end

    local node = minetest.get_node(pos)
    minetest.after(0.2, function()
        local current_node = minetest.get_node(pos)
        if current_node.name ~= swap .. "_open" then
            return
        end
        minetest.swap_node(pos, {name = swap, param2 = node.param2})
        minetest.sound_play(sound, {gain = 0.3, pos = pos,
            max_hear_distance = 10}, true)
    end)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local pn = player:get_player_name()
    if formname ~= "civi_storage:chest" then
        if civi_storage.chest.open_chests[pn] then
            civi_storage.chest.chest_lid_close(pn)
        end
        return
    end

    if fields.quit and civi_storage.chest.open_chests[pn] then
        civi_storage.chest.chest_lid_close(pn)
    end
    return true
end)

minetest.register_on_leaveplayer(function(player)
    local pn = player:get_player_name()
    if civi_storage.chest.open_chests[pn] then
        civi_storage.chest.chest_lid_close(pn)
    end
end)

function civi_storage.chest.register_chest(prefixed_name, d)
    local name = prefixed_name:sub(1,1) == ':' and prefixed_name:sub(2,-1) or prefixed_name
    local def = table.copy(d)
    def.drawtype = "mesh"
    def.visual = "mesh"
    def.paramtype = "light"
    def.paramtype2 = "facedir"
    def.legacy_facedir_simple = true
    def.is_ground_content = false

    if def.protected then
        def.on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", S("Locked Chest"))
            meta:set_string("owner", "")
            local inv = meta:get_inventory()
            inv:set_size("main", 8*4)
        end
        def.after_place_node = function(pos, placer)
            local meta = minetest.get_meta(pos)
            meta:set_string("owner", placer:get_player_name() or "")
            meta:set_string("infotext", S("Locked Chest (owned by @1)"):gsub("@1", meta:get_string("owner")))
        end
        def.can_dig = function(pos, player)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            return inv:is_empty("main") and
                    (not player or meta:get_string("owner") == "" or meta:get_string("owner") == player:get_player_name())
        end
        def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            local meta = minetest.get_meta(pos)
            local owner = meta:get_string("owner")
            local cn = clicker:get_player_name()
            
            if owner ~= "" and owner ~= cn then
                minetest.chat_send_player(cn, S("You do not own this chest."))
                return itemstack
            end

            if civi_storage.chest.open_chests[cn] then
                civi_storage.chest.chest_lid_close(cn)
            end

            minetest.sound_play(def.sound_open, {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
            if not civi_storage.chest.chest_lid_obstructed(pos) then
                minetest.swap_node(pos, { name = name .. "_open", param2 = node.param2 })
            end
            minetest.after(0.2, minetest.show_formspec, cn, "civi_storage:chest", civi_storage.chest.get_chest_formspec(pos))
            civi_storage.chest.open_chests[cn] = { pos = pos, sound = def.sound_close, swap = name }
        end
    else
        def.on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", S("Chest"))
            local inv = meta:get_inventory()
            inv:set_size("main", 8*4)
        end
        def.can_dig = function(pos, player)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            return inv:is_empty("main")
        end
        def.on_rightclick = function(pos, node, clicker)
            local cn = clicker:get_player_name()

            if civi_storage.chest.open_chests[cn] then
                civi_storage.chest.chest_lid_close(cn)
            end

            minetest.sound_play(def.sound_open, {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
            if not civi_storage.chest.chest_lid_obstructed(pos) then
                minetest.swap_node(pos, { name = name .. "_open", param2 = node.param2 })
            end
            minetest.after(0.2, minetest.show_formspec, cn, "civi_storage:chest", civi_storage.chest.get_chest_formspec(pos))
            civi_storage.chest.open_chests[cn] = { pos = pos, sound = def.sound_close, swap = name }
        end
    end

    local def_opened = table.copy(def)
    local def_closed = table.copy(def)

    def_opened.mesh = "chest_open.obj"
    for i = 1, #def_opened.tiles do
        if type(def_opened.tiles[i]) == "string" then
            def_opened.tiles[i] = {name = def_opened.tiles[i], backface_culling = true}
        elseif def_opened.tiles[i].backface_culling == nil then
            def_opened.tiles[i].backface_culling = true
        end
    end
    def_opened.drop = name
    def_opened.groups.not_in_creative_inventory = 1
    def_opened.selection_box = {
        type = "fixed",
        fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
    }
    def_opened.can_dig = function() return false end

    def_closed.mesh = nil
    def_closed.drawtype = nil
    -- Mesh order in MTG: Top, Top, Side, Side, Front, Inside
    -- Block order in MTG: Top, Bottom, Right, Left, Back, Front
    -- We adjust tiles to make the block look right before swapping to mesh
    def_closed.tiles[6] = def.tiles[5] 
    def_closed.tiles[5] = def.tiles[3] 
    def_closed.tiles[3] = def.tiles[3] .. "^[transformFX"

    minetest.register_node(prefixed_name, def_closed)
    minetest.register_node(prefixed_name .. "_open", def_opened)

    -- Close opened chests on load
    local modname, chestname = prefixed_name:match("^(:?.-):(.*)$")
    minetest.register_lbm({
        label = "close opened chests on load",
        name = modname .. ":close_" .. chestname .. "_open",
        nodenames = {prefixed_name .. "_open"},
        run_at_every_load = true,
        action = function(pos, node)
            node.name = prefixed_name
            minetest.swap_node(pos, node)
        end
    })
end

-- =========================================================
-- 1. SINGLE CHEST
-- =========================================================

civi_storage.chest.register_chest("civi_storage:chest", {
    description = S("Chest (32 Slots)"),
    tiles = {
        "civi_chest_top.png",
        "civi_chest_top.png",
        "civi_chest_side.png",
        "civi_chest_side.png",
        "civi_chest_front.png",
        "civi_chest_inside.png"
    },
    sounds = sounds.node_sound_wood_defaults(),
    sound_open = "civi_chest_open",
    sound_close = "civi_chest_close",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, container = 1},
})

-- =========================================================
-- 2. LOCKED CHEST
-- =========================================================

civi_storage.chest.register_chest("civi_storage:chest_locked", {
    description = S("Locked Chest (32 Slots)"),
    tiles = {
        "civi_chest_top.png",
        "civi_chest_top.png",
        "civi_chest_side.png",
        "civi_chest_side.png",
        "civi_chest_lock.png",
        "civi_chest_inside.png"
    },
    sounds = sounds.node_sound_wood_defaults(),
    sound_open = "civi_chest_open",
    sound_close = "civi_chest_close",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, container = 1},
    protected = true,
})


-- =========================================================
-- 3. CRAFTING
-- =========================================================

minetest.register_craft({
    output = "civi_storage:chest",
    recipe = {
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
        {"civi_core:wood", "", "civi_core:wood"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
    }
})

minetest.register_craft({
    output = "civi_storage:chest_locked",
    recipe = {
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
        {"civi_core:wood", "civi_core:iron_ingot", "civi_core:wood"},
        {"civi_core:wood", "civi_core:wood", "civi_core:wood"},
    }
})
