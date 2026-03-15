-- civi_inventory: init.lua

-- Create the custom crafting page
sfinv.register_page("civi_inventory:crafting", {
    title = "Crafting",
    get = function(self, player, context)
        local meta = player:get_meta()
        local has_ach = meta:get_int("civi_core:ach_hunter_gatherer") == 1
        
        -- Approved layout from user
        local formspec = 
            -- Background (matching civi_core style)
            "background9[0,0;8,9;civi_gui_bg.png;true;10]" ..
            
            -- Crafting Grid (Position X=3.5, Y=0.5)
            "list[current_player;craft;3.5,0.5;3,3;]" ..
            
            -- Arrow and Result
            "image[6.5,1.5;1,1;civi_gui_arrow.png]" ..
            "label[7.5,1.0;Result:]" ..
            "list[current_player;craftpreview;7.5,1.5;1,1;]" ..
            
            -- Main Inventory
            "label[0,4.2;Player Inventory:]" ..
            "list[current_player;main;0,4.7;8,4;]" ..
            
            -- Shift-click logic
            "listring[current_player;main]" ..
            "listring[current_player;craft]" ..

            -- Left side buttons
            "button[0,0.5;3,1;btn_teleport;Teleport]" ..
            "button[0,1.8;3,1;btn_music;Music]"

        -- Achievement indicator if unlocked
        if has_ach then
            formspec = formspec .. 
                "image[0,3.0;1,1;civi_achievement_hunter.png^[makealpha:255,0,255]" ..
                "tooltip[0,3.0;1,1;Achievement: Hunter & Gatherer Unlocked!]"
        end

        return sfinv.make_formspec(player, context, formspec)
    end,
    
    on_player_receive_fields = function(self, player, context, fields)
        if fields.btn_teleport then
            minetest.chat_send_player(player:get_player_name(), "[System] Teleport initiated...")
            return true
        end
        if fields.btn_music then
            minetest.chat_send_player(player:get_player_name(), "[System] Music toggled (placeholder).")
            return true
        end
    end
})

-- Set our page as the default home page
function sfinv.get_homepage_name(player)
    return "civi_inventory:crafting"
end
