local path = minetest.get_modpath("civi_npc")
dofile(path .. "/programs.lua")

-- Register the Lumberjack occupation
npc.occupations.register_occupation("lumberjack", {
    dialogues = {
        type = "given",
        data = {
            { text = "Hello! I'm a lumberjack and I'm okay. I sleep all night and I work all day.", tags = { "unisex" } },
            { text = "Need some wood? I'm working on it!", tags = { "unisex" } }
        }
    },
    textures = { 
        { name = "character.png", tags = { "male", "adult" } } 
    },
    building_types = { "lumberjack" },
    initial_inventory = {
        { name = "civi_core:axe_stone", count = 1 },
        { name = "civi_core:iron_lump", count = 10 }
    },
    -- Default state program for this occupation
    state_program = {
        name = "civi_npc:lumberjack_behavior",
        args = {}
    }
})

-- Register the Lumberjack mob using advanced_npc base hooks
mobs:register_mob("civi_npc:lumberjack", {
    type = "npc",
    passive = true, 
    initial_properties = {
        hp_min = 20,
        hp_max = 20,
    },
    collisionbox = {-0.3, -0.0, -0.3, 0.3, 1.8, 0.3},
    visual = "mesh",
    mesh = "character.b3d", 
    textures = {
        {"character.png"}, 
    },
    makes_footstep_sound = true,
    walk_velocity = 1.5,
    run_velocity = 3,
    water_damage = 0,
    lava_damage = 4,
    fall_damage = 0,
    view_range = 15,
    animation = {
        speed_normal = 30,
        speed_run = 30,
        stand_start = 0,
        stand_end = 79,
        walk_start = 168,
        walk_end = 187,
        run_start = 168,
        run_end = 187,
        punch_start = 189,
        punch_end = 198,
    },
    
    -- advanced_npc hooks
    on_spawn = function(self)
        npc.initialize(self, self.object:get_pos(), true)
        -- Set the lumberjack occupation specifically
        self.occupation_name = "lumberjack"
        npc.exec.set_state_program(self, "civi_npc:lumberjack_behavior", {})
    end,

    after_activate = function(self)
        if not self.initialized then
            npc.initialize(self, self.object:get_pos(), true)
        end
        self.occupation_name = "lumberjack"
        npc.exec.set_state_program(self, "civi_npc:lumberjack_behavior", {})
    end,

    on_rightclick = function(self, clicker)
        npc.rightclick_interaction(self, clicker)
    end,

    do_custom = function(self, dtime)
        return npc.step(self, dtime)
    end,
})

-- Spawning rule
mobs:spawn({
    name = "civi_npc:lumberjack",
    nodes = {"civi_core:dirt_with_grass"},
    min_light = 10,
    chance = 7000,
    active_object_count = 1,
    min_height = 0,
})

-- Spawn egg
mobs:register_egg("civi_npc:lumberjack", "Lumberjack (Advanced)", "civi_wood.png", 1)
