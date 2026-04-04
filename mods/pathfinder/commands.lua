-- pathfinder/commands.lua
-- Chat-Commands zur interaktiven Pathfinding-Visualisierung
-- /p2nt  - Findet den naechsten Baum und zeigt den Weg per Partikel an
-- /p2stop - Loescht alle aktiven Partikel-Spawner

-- Globale Liste aller aktiven Spawner-IDs (pro Spieler)
local active_spawners = {}  -- [player_name] = {id1, id2, ...}

-- Hilfsfunktion: Spawner anlegen und ID speichern
local function spawn_path_marker(player_name, pos, color)
    color = color or "#00FF00"  -- Gruen = Weg
    local id = minetest.add_particlespawner({
        amount = 15,
        time = 0,  -- time=0 = laeuft bis manuell geloescht
        minpos = {x=pos.x-0.15, y=pos.y+1.1, z=pos.z-0.15},
        maxpos = {x=pos.x+0.15, y=pos.y+1.3, z=pos.z+0.15},
        minvel = {x=-0.05, y=0.1, z=-0.05},
        maxvel = {x=0.05, y=0.2, z=0.05},
        minacc = {x=0, y=0, z=0},
        maxacc = {x=0, y=0.02, z=0},
        minexptime = 1.5,
        maxexptime = 3.0,
        minsize = 2.0,
        maxsize = 4.0,
        collisiondetection = false,
        vertical = false,
        texture = "heart.png^[colorize:" .. color .. ":200",
        glow = 14,
    })
    if not active_spawners[player_name] then
        active_spawners[player_name] = {}
    end
    table.insert(active_spawners[player_name], id)
end

-- /p2stop: Alle Spawner des Spielers loeschen
minetest.register_chatcommand("p2stop", {
    description = "Loescht alle aktiven Pfad-Partikel-Spawner",
    privs = {interact = true},
    func = function(name, param)
        local spawners = active_spawners[name]
        if not spawners or #spawners == 0 then
            return true, "[Pathfinder] Keine aktiven Spawner vorhanden."
        end
        local count = #spawners
        for _, id in ipairs(spawners) do
            minetest.delete_particlespawner(id)
        end
        active_spawners[name] = {}
        return true, "[Pathfinder] " .. count .. " Spawner geloescht."
    end
})

-- /p2nt: Weg zum naechsten Baum per Pathfinder berechnen und anzeigen
minetest.register_chatcommand("p2nt", {
    description = "Zeigt den Weg zum naechsten Baum per Partikel an",
    privs = {interact = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "[Pathfinder] Spieler nicht gefunden."
        end

        local pos = vector.round(player:get_pos())

        -- Zuerst alte Spawner des Spielers loeschen
        if active_spawners[name] and #active_spawners[name] > 0 then
            for _, id in ipairs(active_spawners[name]) do
                minetest.delete_particlespawner(id)
            end
            active_spawners[name] = {}
        end

        minetest.chat_send_player(name, "[Pathfinder] Suche naechsten Baum ...")

        -- Naechsten Baum im Umkreis von 150 Nodes suchen
        local search_range = 150
        local p1 = {x=pos.x-search_range, y=pos.y-search_range, z=pos.z-search_range}
        local p2 = {x=pos.x+search_range, y=pos.y+search_range, z=pos.z+search_range}
        local tree_nodes = minetest.find_nodes_in_area(p1, p2, {"group:tree"})

        if not tree_nodes or #tree_nodes == 0 then
            return false, "[Pathfinder] Kein Baum im Umkreis von " .. search_range .. " Nodes gefunden."
        end

        -- Sortieren nach Distanz, dann Wurzel des naechsten Baumes finden
        table.sort(tree_nodes, function(a, b)
            return vector.distance(pos, a) < vector.distance(pos, b)
        end)

        -- Baumwurzel (unterster Block) ermitteln
        local tree_root = vector.new(tree_nodes[1])
        for i = 1, 30 do
            local under = {x=tree_root.x, y=tree_root.y-1, z=tree_root.z}
            if minetest.get_item_group(minetest.get_node(under).name, "tree") > 0 then
                tree_root.y = tree_root.y - 1
            else
                break
            end
        end

        -- Naechsten freien Standplatz neben der Baumwurzel finden
        local function find_stand_spot_near_tree(root, start_pos)

            -- Kann man physikalisch darin stehen?
            -- WICHTIG: grass-Gruppe NICHT ausschliessen (dirt_with_grass hat grass=1 aber ist solid!)
            local function is_passable(name)
                local def = minetest.registered_nodes[name]
                if not def or not def.walkable then return true end
                if minetest.get_item_group(name, "leaves") > 0 then return true end
                return false
            end

            -- Echter fester Boden (kein Baumstamm, keine Blaetter)?
            local function is_solid_ground(name)
                local def = minetest.registered_nodes[name]
                if not def or not def.walkable then return false end
                if minetest.get_item_group(name, "tree")   > 0 then return false end
                if minetest.get_item_group(name, "leaves") > 0 then return false end
                return true
            end

            local neighbor_offsets = {
                {x=1,z=0}, {x=-1,z=0}, {x=0,z=1},  {x=0,z=-1},
                {x=1,z=1}, {x=-1,z=-1},{x=1,z=-1}, {x=-1,z=1}
            }

            -- Pro Richtung: Y von oben nach unten scannen, ersten gueltigen Standplatz nehmen
            for _, off in ipairs(neighbor_offsets) do
                local cx = root.x + off.x
                local cz = root.z + off.z
                for dy = 3, -5, -1 do
                    local cy     = root.y + dy
                    local n_here  = minetest.get_node({x=cx, y=cy,   z=cz}).name
                    local n_below = minetest.get_node({x=cx, y=cy-1, z=cz}).name
                    local n_above = minetest.get_node({x=cx, y=cy+1, z=cz}).name
                    if is_passable(n_here) and is_solid_ground(n_below) and is_passable(n_above) then
                        -- Muss von der Seite erreichbar sein
                        local horizontal_ok = false
                        for _, ho in ipairs({{x=1,z=0},{x=-1,z=0},{x=0,z=1},{x=0,z=-1}}) do
                            if is_passable(minetest.get_node({x=cx+ho.x, y=cy, z=cz+ho.z}).name) then
                                horizontal_ok = true
                                break
                            end
                        end
                        if horizontal_ok then
                            return {x=cx, y=cy, z=cz}
                        end
                    end
                end
            end
            return nil
        end

        local stand_target = find_stand_spot_near_tree(tree_root, pos)
        if not stand_target then
            return false,
                "[Pathfinder] Kein begehbarer Standplatz neben dem Baum bei " ..
                minetest.pos_to_string(tree_root) .. " gefunden."
        end

        minetest.chat_send_player(name,
            "[Pathfinder] Starte bei " .. minetest.pos_to_string(pos) ..
            " -> Baum: " .. minetest.pos_to_string(tree_root) ..
            " | Ziel (Standplatz): " .. minetest.pos_to_string(stand_target))

        -- Pathfinder aufrufen mit korrektem Standplatz neben dem Stamm
        local path = pathfinder.find_path(pos, stand_target, nil, 0)

        if not path or #path == 0 then
            return false,
                "[Pathfinder] KEIN WEG gefunden von " ..
                minetest.pos_to_string(pos) .. " nach " ..
                minetest.pos_to_string(stand_target) .. "."
        end

        -- Weg visualisieren
        -- Start = Blau, Ziel = Rot, Zwischenpunkte = Gruen
        for i, wp in ipairs(path) do
            local color
            if i == 1 then
                color = "#0088FF"     -- Start: Blau
            elseif i == #path then
                color = "#FF4400"     -- Ziel: Rot/Orange
            else
                color = "#00FF00"     -- Weg: Gruen
            end
            spawn_path_marker(name, wp, color)
        end

        return true,
            "[Pathfinder] WEG GEFUNDEN! " .. #path .. " Wegpunkte von " ..
            minetest.pos_to_string(pos) .. " zum Baum bei " ..
            minetest.pos_to_string(tree_root) ..
            " (Standplatz: " .. minetest.pos_to_string(stand_target) .. ")" ..
            ". Zum Loeschen: /p2stop"
    end
})
