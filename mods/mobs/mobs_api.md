# Mobs API — `mods/mobs`

## Overview

The `mobs` mod provides a comprehensive framework for defining, spawning, animating and controlling mobile entities (mobs) inside the myCraftCivi game. It handles the full lifecycle of every creature:

- **Registration** — declare mob properties, visuals, AI parameters and drop tables
- **Activation / Persistence** — serialize and restore live mob state when map chunks are loaded and unloaded
- **AI Behaviour** — state machine driving stand, walk, flee, follow and attack behaviours
- **Pathfinding integration** — falls back to Minetest's built-in pathfinder or — when available — delegates to the `pathfinder` mod for richer navigation
- **Combat** — melee dogfight, ranged shoot, combo dogshoot and explosive attacks
- **Environment** — water, lava, fire, light, air and suffocation damage
- **Breeding / Taming / Capture** — mob social interactions and player ownership
- **Spawning** — ABM-based and LBM-based spawn rules with configurable limits

All public functions live inside the global `mobs` table.  
Instance methods belong to the `mob_class` table and are available on every live entity via the Lua metatable `mob_class_meta`.

---

## Global Settings (`minetest.conf`)

| Key | Type | Default | Description |
|---|---|---|---|
| `enable_damage` | bool | `true` | Master damage toggle |
| `mobs_spawn` | bool | `true` | Allow mob spawning |
| `only_peaceful_mobs` | bool | `false` | Suppress monster spawning |
| `mobs_disable_blood` | bool | `false` | Suppress blood particle effect |
| `mob_hit_effect` | bool | `false` | Flash texture on hit |
| `mobs_drop_items` | bool | `true` | Mobs drop loot on death |
| `mobs_griefing` | bool | `true` | Allow mobs to break/place nodes |
| `mobs_spawn_protected` | bool | `true` | Allow spawn inside protected areas |
| `mobs_spawn_monster_protected` | bool | `true` | Allow monster spawn inside protected areas |
| `remove_far_mobs` | bool | `true` | Remove untamed mobs when chunks unload |
| `mob_area_spawn` | bool | `false` | Full collision-box clearance check before spawn |
| `mob_difficulty` | float | `1.0` | Global HP and damage multiplier |
| `max_objects_per_block` | int | `99` | Object density cap per block |
| `mob_nospawn_range` | int | `12` | Do not spawn within this many nodes of a player |
| `mob_active_limit` | int | `0` | Hard cap on simultaneously active mobs (0 = unlimited) |
| `mob_chance_multiplier` | float | `1` | Global spawn-chance multiplier |
| `enable_peaceful_player` | bool | `false` | All players have peaceful privilege |
| `mob_smooth_rotate` | bool | `true` | Interpolated yaw turning |
| `mob_height_fix` | bool | `true` | Prevent tiny collision-box mobs from clipping |
| `mob_pathfinding_enable` | bool | `true` | Enable built-in pathfinding |
| `mob_pathfinder_enable` | bool | `true` | Prefer external `pathfinder` mod when loaded |
| `mob_pathfinding_stuck_timeout` | float | `3.0` | Seconds before a stuck mob triggers pathfinding |
| `mob_pathfinding_stuck_path_timeout` | float | `5.0` | Seconds before a mob gives up following a path |
| `mob_pathfinding_algorithm` | string | `Dijkstra` | `Dijkstra`, `AStar`, or `AStar_noprefetch` |
| `mob_pathfinding_searchdistance` | int | `16` | Maximum search radius for built-in pathfinder |
| `mob_pathfinding_max_jump` | int | `4` | Maximum jump height for built-in pathfinder |
| `mob_pathfinding_max_drop` | int | `6` | Maximum fall height for built-in pathfinder |

---

## `mob_class` — Default Instance Properties

These are the baseline values automatically applied to every mob unless overridden in `mobs:register_mob`.

| Property | Default | Description |
|---|---|---|
| `owner` | `""` | Player name who owns this mob |
| `order` | `""` | Current NPC order (`"stand"` / `"follow"`) |
| `jump_height` | `4` | Impulse applied on jump |
| `lifetimer` | `180` | Seconds before mob despawns (untamed) |
| `view_range` | `5` | Detection radius (nodes) |
| `walk_velocity` | `1` | Speed while wandering |
| `run_velocity` | `2` | Speed while chasing |
| `light_damage` | `0` | HP per second in bright light |
| `light_damage_min` | `14` | Light level threshold (lower) |
| `light_damage_max` | `15` | Light level threshold (upper) |
| `water_damage` | `0` | HP per second in water |
| `lava_damage` | `4` | HP per second in lava |
| `fire_damage` | `4` | HP per second in fire |
| `air_damage` | `0` | HP per second in open air (aquatic mobs) |
| `suffocation` | `2` | HP per second when inside solid node |
| `fall_damage` | `1` | Enable fall damage |
| `fall_speed` | `-10` | Downward acceleration |
| `drops` | `{}` | Loot table |
| `armor` | `100` | Armour percentage |
| `passive` | `false` | Passive mobs never attack |
| `blood_amount` | `5` | Number of blood particles on hit |
| `blood_texture` | `"mobs_blood.png"` | Blood particle texture |
| `floats` | `1` | Float in liquid (1 = yes) |
| `reach` | `3` | Melee attack range (nodes) |
| `docile_by_day` | `false` | Passive during daytime |
| `fear_height` | `0` | Cliff height the mob avoids |
| `group_attack` | `false` | Call nearby same-type mobs into combat |
| `attack_monsters` | `false` | Attack monster-type entities |
| `attack_animals` | `false` | Attack animal-type entities |
| `attack_players` | `true` | Attack players |
| `attack_npcs` | `true` | Attack NPC entities |
| `friendly_fire` | `true` | Own arrows can hit self |

---

## Registration API

### `mobs:register_mob(name, def)`

Registers a new mob entity with Minetest.

**Parameters**

| Name | Type | Description |
|---|---|---|
| `name` | string | Fully qualified entity name, e.g. `"mobs_mc:zombie"` |
| `def` | table | Mob definition (see below) |

**Key `def` fields**

| Field | Type | Description |
|---|---|---|
| `type` | string | `"animal"`, `"monster"` or `"npc"` |
| `hp_min` / `hp_max` | int | Health range on spawn |
| `collisionbox` | table | Physics AABB `{x1,y1,z1,x2,y2,z2}` |
| `visual` | string | `"mesh"` or `"sprite"` |
| `mesh` | string | `.obj` filename |
| `textures` | table | List of texture sets (one chosen at random) |
| `visual_size` | table | `{x=1, y=1}` scale |
| `animation` | table | Frame ranges: `walk_start`, `walk_end`, `stand_start`, … |
| `sounds` | table | `{random, death, damage, war_cry, attack, jump, distance}` |
| `drops` | table | `{{name, chance, min, max}, …}` |
| `attack_type` | string | `"dogfight"`, `"shoot"`, `"dogshoot"`, `"explode"` |
| `damage` | int | Melee damage per hit |
| `arrow` | string | Projectile entity name for shoot attacks |
| `shoot_interval` | float | Minimum seconds between shots |
| `pathfinding` | int | `1` = navigate; `2` = navigate + dig |
| `follow` | string/table | Item(s) that attract the mob |
| `passive` | bool | Never attacks |
| `runaway` | bool | Flees when hit |
| `runaway_from` | table | List of entity names to flee from |
| `stay_near` | table | `{node_list, chance}` — periodically face nearby nodes |
| `replace_rate` | int | Chance denominator for node eating |
| `replace_what` | table | Nodes this mob consumes |
| `replace_with` | string | Node placed after consuming |
| `on_rightclick` | function | Called when player right-clicks |
| `on_die` | function | Called just before mob is removed |
| `on_spawn` | function | Called once after first activation |
| `do_custom` | function | Called every step; return `false` to suppress built-in logic |
| `custom_attack` | function | Override melee attack; return `true` to also run default |
| `on_breed` | function | Custom breeding callback |
| `on_grown` | function | Called when child reaches adult size |
| `immune_to` | table | `{{tool_name, damage}, …}` — damage overrides per tool |
| `group_attack` | bool | Alert nearby same-type mobs when attacked |
| `group_helper` | string | Additional mob name alerted during group attack |

**Example**

```lua
mobs:register_mob("mobs_mc:zombie", {
    type          = "monster",
    hp_min        = 10, hp_max = 20,
    attack_type   = "dogfight",
    damage        = 3,
    reach         = 2,
    walk_velocity = 1.2,
    run_velocity  = 2.5,
    view_range    = 16,
    pathfinding   = 1,
    drops         = {
        {name = "mobs_mc:rotten_flesh", chance = 1, min = 0, max = 2}
    },
    textures   = {{"mobs_zombie.png"}},
    mesh       = "mobs_zombie.obj",
    visual     = "mesh",
    collisionbox = {-0.3, -1.0, -0.3, 0.3, 0.8, 0.3},
    animation  = {
        stand_start = 0, stand_end = 0,
        walk_start = 0, walk_end = 40, walk_speed = 25,
    },
    sounds = {random = "mobs_zombie", death = "mobs_zombie_death",
              damage = "mobs_zombie_pain", distance = 16},
    on_rightclick = function(self, clicker)
        mobs:feed_tame(self, clicker, 8, false, false)
    end,
})
```

---

### `mobs:register_egg(mob, desc, background, addegg, no_creative)`

Registers two spawn-egg craftitems for `mob`:

- `mob` — a stackable egg that spawns a generic mob instance
- `mob .. "_set"` — a non-stackable egg that encodes the full mob state

| Parameter | Type | Description |
|---|---|---|
| `mob` | string | Entity name as registered with `register_mob` |
| `desc` | string | Display name |
| `background` | string | Texture |
| `addegg` | int | `1` to overlay the texture on an egg graphic |
| `no_creative` | bool | Exclude from creative inventory if `true` |

---

### `mobs:register_arrow(name, def)`

Registers a projectile entity used by `attack_type = "shoot"` mobs.

| `def` field | Description |
|---|---|
| `velocity` | Flight speed |
| `hit_player(self, player)` | Called when arrow reaches a player |
| `hit_mob(self, mob_obj)` | Called when arrow reaches a mob |
| `hit_node(self, pos, node)` | Called when arrow embeds in a node |
| `hit_object(self, obj)` | Called for other entity types |
| `drop` | `true` to drop arrow item on node hit |
| `lifetime` | Seconds before auto-removal (default `4.5`) |
| `tail` + `tail_texture` | Render a particle trail |

---

## Spawning API

### `mobs:spawn(def)`

Preferred, named-parameter spawning helper.

```lua
mobs:spawn({
    name          = "mobs_mc:pig",
    nodes         = {"default:dirt_with_grass"},
    neighbors     = {"air"},
    min_light     = 10,
    max_light     = 15,
    interval      = 30,
    chance        = 7000,
    active_object_count = 2,
    min_height    = -10,
    max_height    = 200,
    day_toggle    = true,   -- true=day only, false=night only, nil=always
    on_spawn      = function(self, pos) end,
})
```

---

### `mobs:spawn_specific(name, nodes, neighbors, min_light, max_light, interval, chance, aoc, min_height, max_height, day_toggle, on_spawn, map_load)`

Low-level spawn registration. Registers an ABM (or LBM when `map_load = true`).

- Respects all global settings: `mobs_spawn`, `mob_active_limit`, `mob_nospawn_range`, `spawn_protected`, …
- Each registered mob may have its chance and aoc overridden in `minetest.conf` with `mob_name = chance,aoc`.

---

### `mobs:register_spawn(name, nodes, max_light, min_light, chance, aoc, max_height, day_toggle)`

Compatibility wrapper around `spawn_specific`. Prefer `mobs:spawn` for new code.

---

### `mobs:add_mob(pos, def)`

Programmatically spawn a mob at runtime.

```lua
mobs:add_mob(pos, {
    name      = "mobs_mc:cow",
    owner     = "Alice",
    child     = false,
    nametag   = "Bessie",
})
```

Returns the entity userdata on success, or `nil`.

---

### `mobs:can_spawn(pos, name) → pos | nil`

Check whether there is sufficient space for `name` to spawn at `pos`.  
Returns adjusted spawn position or `nil` when blocked.

---

### `mobs:spawn_abm_check(pos, node, name)`

Override hook called before every spawn attempt.  
Return `true` to prevent spawning.

```lua
function mobs:spawn_abm_check(pos, node, name)
    if my_special_condition(pos) then return true end
end
```

---

## Instance Methods (mob_class)

All methods below are called on a mob entity table (`self`) or via the global `mobs` aliases.

---

### Movement & Orientation

#### `self:set_velocity(v)`

Propels the mob in its current facing direction at speed `v`.  
Automatically reduces speed based on liquid viscosity and stops if ordered to stand.

#### `self:get_velocity() → float`

Returns horizontal speed (magnitude of x/z velocity components).

#### `self:set_yaw(yaw, delay) → yaw`

Sets mob facing direction.  
When `delay > 0` and smooth rotation is enabled, interpolates over that many steps.

#### `mobs:yaw(entity, yaw, delay)`

Global alias to `entity:set_yaw`.

#### `mobs:yaw_to_pos(self, target, rot)`

Rotates `self` to face `target` position. `rot` adds an offset in radians.

---

### Animation

#### `self:set_animation(anim, force)`

Plays a named animation clip.  
Looks up `self.animation[anim .. "_start"]` and `[anim .. "_end"]`.  
Supported names (by convention): `"stand"`, `"walk"`, `"run"`, `"punch"`, `"shoot"`, `"jump"`, `"die"`, `"fly"`, `"injured"`.  
When multiple variants exist (`walk1`, `walk2`, …) one is chosen at random.  
Pass `force = true` to restart even if already playing.

---

### Sensing

#### `self:line_of_sight(pos1, pos2, stepsize) → bool`

Returns `true` if there is an unobstructed walkable line between the two positions.  
Uses Minetest raycast when available (5.0+), otherwise falls back to a stepwise scan that ignores non-walkable nodes.

#### `self:follow_holding(clicker) → bool`

Returns `true` if the player is holding an item that matches `self.follow`.

#### `self:flight_check() → bool`

Returns `true` if the mob is currently inside its intended flight/swim medium (`fly_in`).

#### `self:is_at_cliff() → bool`

Returns `true` if the mob is about to step off a drop exceeding `self.fear_height`.

---

### Health & Death

#### `self:check_for_death(cmi_cause) → bool`

Checks whether `self.health <= 0`. If so:
- Executes `on_die` callback if defined.
- Plays death animation and schedules removal.
- Triggers CMI notification if CMI mod is present.

Returns `true` when the mob dies.

**`cmi_cause` table fields:**

| Field | Description |
|---|---|
| `type` | `"punch"`, `"environment"`, `"fall"`, `"light"`, `"suffocation"`, `"unknown"` |
| `puncher` | Object reference for punch damage |
| `pos` | World position of hazard |
| `node` | Node name causing environmental damage |
| `hot` | `true` = fire/lava death (cooked drops) |

#### `self:item_drop()`

Spawns loot according to `self.drops`.  
Applies looting enchantment level from the killing tool.  
Rare items (`min = 0`) only drop when killed by a player.  
Items killed by fire/lava may yield cooked variants via the crafting system.

#### `self:do_env_damage() → bool`

Called every second to apply water, lava, fire, custom `damage_per_second`, air, light and suffocation damage.  
Returns `true` if the mob died.

#### `self:on_punch(hitter, tflp, tool_capabilities, dir, damage)`

Minetest callback. Computes and applies damage, applies weapon wear, spawns blood particles, triggers knock-back, and calls `group_attack` on nearby allies.

#### `self:on_blast(damage)`

Handles TNT blast damage via the standard punch mechanism.

---

### AI Behaviour

#### `self:on_step(dtime, moveresult)`

Main per-step function orchestrating the full AI cycle:

1. Update standing/on nodes at 4 Hz.
2. Apply falling / floating physics.
3. Apply smooth yaw rotation.
4. Apply environmental damage at 1 Hz.
5. Call `do_custom` hook.
6. Run `general_attack` to detect nearby targets.
7. Run `breed` timer.
8. Run `follow_flop` logic.
9. Execute current `do_states` (stand/walk/runaway/attack).
10. Attempt `do_jump`.
11. Check `do_runaway_from`.
12. Handle `do_stay_near`.

#### `self:do_states(dtime)`

Implements the behaviour state machine:

| State | Behaviour |
|---|---|
| `"stand"` | Idle; randomly turn; switch to walk |
| `"walk"` | Roam; stop at cliffs or fences |
| `"runaway"` | Sprint away; stop after 5 s |
| `"attack"` | Execute `attack_type` sub-behaviour |
| `"flop"` | Aquatic mob out of water |
| `"die"` | Death animation playing |

#### `self:general_attack()`

Scans `view_range` for attackable entities.  
Respects `passive`, `attack_players`, `attack_monsters`, `attack_animals`, `attack_npcs`, `specific_attack`, and `peaceful_player` privilege.  
Calls `do_attack(target)` on the nearest eligible target.

#### `self:do_attack(player)`

Transitions mob into attack state against `player`.

#### `self:smart_mobs(s, p, dist, dtime)`

Advanced pathfinding routine that detects stuck conditions and triggers the pathfinder.  
Falls back to the `pathfinder` mod's `find_path` when loaded, otherwise uses Minetest's built-in pathfinder.  
Level-2 pathfinding (`pathfinding = 2`) can mine blocking nodes when no path is found.

#### `self:do_jump() → bool`

Attempts a jump to overcome obstacles in the mob's forward direction.  
Skips if the mob flies or has `jump = false` or `jump_height = 0`.

#### `self:do_runaway_from()`

Checks for entities listed in `self.runaway_from` and transitions to `"runaway"` state.

#### `self:follow_flop()`

Handles:
- Following a player holding `self.follow` items.
- Following owner on NPC `"follow"` order.
- Aquatic mob flopping when out of water.

#### `self:day_docile() → bool`

Returns `true` when `docile_by_day` is set and current time is between 06:00 and 18:00.

#### `self:do_stay_near() → bool`

Periodically turns the mob toward a node type listed in `self.stay_near`.

#### `self:breed()`

Handles growth of children and mating between adult mobs:
- Children grow after `20 minutes` (accelerated by feeding).
- Adults within reach `3` and both `horny` mate after `30 s` of mutual proximity.
- Produces a child mob that starts at half scale.

#### `self:replace(pos)`

Consumes nodes beneath the mob according to `replace_what`/`replace_with` and `replace_rate`.  
Triggers `on_replace` callback before modifying the map.

#### `self:dogswitch(dtime) → int`

Toggles between melee (mode 1) and ranged (mode 2) phases for `attack_type = "dogshoot"`.  
Returns the current mode.

#### `self:collision() → {x, z}`

Computes a steering correction vector from nearby players for pushable mobs.

---

### Sound

#### `self:mob_sound(sound)`

Plays the given sound from the mob's position.  
Children sound at 1.5× pitch; a small random pitch variation is always applied.

---

### UI / Tags

#### `self:update_tag()`

Refreshes the mob nametag color to reflect current health percentage:
- Green → full
- Yellow → 75%
- Orange → 50%
- Red → 25%

Also appends owner, breeding countdown, and protection status.

---

### Persistence

#### `self:mob_activate(staticdata, def, dtime)`

Called by Minetest on entity activation.  
Restores serialized state, applies current definition values, initialises pathfinding data, and runs `on_spawn`/`after_activate` hooks.

#### `self:mob_staticdata() → string`

Called by Minetest to serialise entity state.  
Removes untamed mobs when unloading (`remove_far`).  
Returns `minetest.serialize(…)`.

#### `self:mob_expire(pos, dtime)`

Decrements `lifetimer` and removes mob when it expires, provided no players are within 15 nodes.

---

### Ownership / Social

#### `mobs:feed_tame(self, clicker, feed_count, breed, tame) → bool`

Handles right-click feeding:
- Heals 4 HP.
- Accelerates child growth by 10% per feeding.
- After `feed_count` feedings: triggers breeding if `breed = true`; tames if `tame = true`.
- Supports nametag application.

#### `mobs:capture_mob(self, clicker, chance_hand, chance_net, chance_lasso, force_take, replacewith) → ItemStack | false`

Captures mob into inventory (hand / net / lasso), subject to taming and ownership checks.

#### `mobs:force_capture(self, clicker)`

Unconditional capture, deposits `name_set` egg with full state into player inventory.

#### `mobs:protect(self, clicker) → bool`

Applies a protection rune (`mobs:protector` or `mobs:protector2`) to a tamed mob, preventing damage from non-owners.

---

### Explosions

#### `mobs:boom(self, pos, radius, damage_radius, texture)`

Triggers an explosion. Delegates to `tnt.boom` when the TNT mod is present and griefing is enabled; otherwise falls back to `safe_boom`.

#### `mobs:safe_boom(self, pos, radius, texture)`

Node-safe explosion: plays sound, applies physics push to nearby entities, emits smoke particles.

#### `mobs:explosion(pos, radius)`

Deprecated compatibility wrapper for `mobs:boom`.

---

### Utility Helpers

#### `mobs.is_creative(name) → bool`

Returns `true` when the player has creative mode or the `creative` privilege.

#### `mobs:is_node_dangerous(mob_object, nodename) → bool`

Returns `true` when `nodename` would deal damage to `mob_object` based on its damage properties.

#### `mobs:remove(self, decrease)`

Removes mob entity and optionally decrements the active mob counter.

#### `mobs:set_velocity(entity, v)`

Global alias to `entity:set_velocity(v)`.

#### `mobs:line_of_sight(entity, pos1, pos2, stepsize) → bool`

Global alias to `entity:line_of_sight(pos1, pos2, stepsize)`.

#### `mobs:effect(pos, amount, texture, min_size, max_size, radius, gravity, glow, fall)`

Spawns a particle burst at `pos`.

| Parameter | Default | Description |
|---|---|---|
| `amount` | — | Number of particles |
| `texture` | — | Particle texture |
| `min_size` / `max_size` | 0.5 / 1 | Particle size range |
| `radius` | 2 | Horizontal spread |
| `gravity` | -10 | Gravitational acceleration |
| `glow` | 0 | Particle glow level |
| `fall` | `true` = fall, `false` = rise, otherwise spread |

#### `mobs:alias_mob(old_name, new_name)`

Compatibility shim: registers `old_name` as an alias pointing to `new_name`.

---

## Callback Reference Summary

| Hook | Signature | When called |
|---|---|---|
| `on_spawn(self)` | bool | Once on first activation |
| `after_activate(self, staticdata, def, dtime)` | — | Every activation |
| `on_die(self, pos)` | — | Before removal on death |
| `on_flop(self)` | bool | Aquatic mob leaves water |
| `on_breed(self, partner_ent)` | bool | Before child spawned; `false` = cancel |
| `on_grown(self)` | — | Child becomes adult |
| `on_replace(self, pos, oldnode, newnode)` | bool | Before node eaten; `false` = cancel |
| `do_custom(self, dtime, moveresult)` | bool | Every step; `false` = skip built-in logic |
| `custom_attack(self, self2, p)` | bool | Melee attack; `true` = also run default |
| `do_punch(self, hitter, tflp, tool_caps, dir)` | bool | On punch; `false` = skip further processing |
| `on_rightclick(self, clicker)` | — | Player right-clicks mob |
| `spawn_abm_check(pos, node, name)` | bool | Before ABM spawn; `true` = reject |
| `arrow_override(ent)` | — | Customise arrow entity after creation |
