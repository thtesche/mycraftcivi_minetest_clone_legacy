-- my_civi/player.lua
-- Player logic and speed boosts

minetest.register_on_joinplayer(function(player)
    -- Initial setup for joining players
end)

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        pos.y = pos.y - 0.1
        local node = minetest.get_node(pos)
        
        -- Speed boost on road nodes
        if node.name == "my_civi:asphalt_road" then
            player:set_physics_override({speed = 2.0})
        else
            player:set_physics_override({speed = 1.0})
        end
    end
end)
