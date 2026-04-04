# Pathfinder API — `mods/pathfinder`

## Overview

The `pathfinder` mod provides a custom **A\* (A-Star) pathfinding implementation** purpose-built for the myCraftCivi voxel environment. It is loaded as a standalone mod and exposes a single global function — `pathfinder.find_path` — which the `mobs` mod calls automatically when the pathfinder is present.

### Why a Custom Pathfinder?

Minetest ships with a built-in `minetest.find_path` function based on Dijkstra's algorithm. While functional, it has several limitations relevant to NPC gameplay:

- No entity-aware constraints (jump height, fall tolerance).
- No robust start-node recovery when an entity has clipped into a wall.
- The Dijkstra algorithm expands uniformly rather than directing search toward the goal.

This mod addresses all three issues with a **greedy A\* search** that respects entity physics, handles terrain edge cases (vegetation passability, door/gate states), and provides built-in debug visualisation.

---

## Architecture

```
pathfinder.find_path(startPos, endPos, entity, dtime)
    │
    ├── Input validation & position rounding
    ├── Robust start: if entity is inside a solid block, scan adjacent nodes
    ├── Initialise open/closed sets with A* cost fields (gCost, hCost, fCost)
    │
    ├── Main loop (until open set empty | 10,000 node limit | 100 ms timeout)
    │    ├── Select node with lowest fCost (ties broken by hCost)
    │    ├── Success check: reached endPos within 1.1 nodes
    │    │    └── Reconstruct path → visualise → return reversed list
    │    │
    │    ├── Move current → closed set
    │    └── Expand 8 cardinal + diagonal neighbors
    │         ├── get_neighbor_ground_level() — handles steps up and drops down
    │         ├── Head-clearance check (2-node height)
    │         └── Cost update and open-set entry
    │
    └── Failure: log diagnostics, broadcast audit to all players, return nil
```

---

## Public API

### `pathfinder.find_path(pos, endpos, entity, dtime) → table | nil`

Searches for a walkable path from `pos` to `endpos`.

**Parameters**

| Name | Type | Description |
|---|---|---|
| `pos` | `{x,y,z}` | Starting position. Will be rounded to integer coordinates. |
| `endpos` | `{x,y,z}` | Target position. Will be rounded to integer coordinates. |
| `entity` | table \| nil | Live mob entity userdata (used to read `jump_height` and `fear_height`). Pass `nil` to use default constraints. |
| `dtime` | float | Current server step delta time (currently unused internally, reserved for future throttling). |

**Returns**

- A **sequential table of `{x,y,z}` waypoints** from start to goal (inclusive) when a path is found.  
- `nil` when no path exists or the search budget is exceeded.

**Usage Example (mobs mod integration)**

```lua
local pathfinder_mod = minetest.get_modpath("pathfinder")

if pathfinder_mod and pathfinder_enable then
    self.path.way = pathfinder.find_path(start_pos, target_pos, self, dtime)
else
    self.path.way = minetest.find_path(...)
end
```

**Entity constraints read from `entity`**

| Entity field | Default when nil | Effect |
|---|---|---|
| `entity.jump_height` | `1.1` | Maximum number of nodes the entity can step up in one move |
| `entity.fear_height` | `3` | Maximum number of nodes the entity will drop between waypoints |

---

## Internal Functions

These functions are not exposed publicly but document the internal logic to support future maintenance and extension.

---

### `is_physically_solid(name, pos) → bool`

A strict solidity test used for the **start-node recovery** check and the **head-clearance** check.

Returns `false` (traversable) for:
- Nodes not registered or lacking `walkable = true`.
- Nodes in the `leaves` group (tree canopies).
- Nodes in the `flora` group (plants, saplings).
- Nodes in the `grass` group (surface vegetation).
- Nodes in the `attached_node` group (torches, rails, etc.).

Returns `true` (solid / blocking) for all other walkable nodes.

**Rationale:** NPCs are expected to walk through vegetation but not through stone or wood.

---

### `walkable(node, pos, current_pos) → bool`

Used exclusively during neighbor expansion to determine whether a candidate node blocks lateral movement.

Same rules as `is_physically_solid` **except** it does not filter `attached_node` — attached nodes can block side movement but not head clearance.

---

### `is_door(name) → bool`

Returns `true` when the node name contains the substring `"door"` or `"gate"`.

Currently reserved for future door-traversal logic. The pathfinder treats door nodes according to their `walkable` property (closed doors are solid, open doors are passable).

---

### `is_door_open(name, pos) → bool`

Checks whether a door or gate at `pos` is in its open state by inspecting `node.param2`:
- `param2 == 1` or `param2 == 3` → open.

---

### `hash_node_position(pos) → string`

Produces a string key `"x,y,z"` for use as a hash table index in the open and closed sets.

---

### `get_distance(pos1, pos2) → float`

Returns Euclidean 3D distance between two positions using `vector.distance`.  
Used as the A\* heuristic `h(n)`.

---

### `get_neighbor_ground_level(pos, jump_height, fall_height, current_pos) → {x,y,z} | nil`

The **terrain-traversal kernel** of the pathfinder. Given a candidate neighbour position offset from the current node, it returns the actual walkable ground position the entity would land on, or `nil` if the terrain is impassable.

**Logic:**

1. **Node is solid at offset position** → attempt to step up:
   - Increment Y up to `jump_height` nodes.
   - Return the first non-solid position above if found.
   - Return `nil` if jump limit exceeded.

2. **Node is non-solid at offset position:**
   a. **Solid ground directly below** → return offset position (same-level move).
   b. **No solid ground below** → fall:
      - Decrement Y up to `fall_height` nodes.
      - Return position one above the first solid node found.
      - Return `nil` if fall limit exceeded.

**This single function encodes all terrain physics.** No special-case code is needed elsewhere in the search loop.

---

## The A\* Search Loop

The main search operates on two Lua tables:

| Table | Purpose |
|---|---|
| `openSet` | Nodes discovered but not yet fully evaluated. Keyed by hash. |
| `closedSet` | Nodes already evaluated. Keyed by hash. |

Each entry is a record:

```lua
{
    gCost  = number,  -- actual movement cost from start
    hCost  = number,  -- heuristic cost to goal (Euclidean distance)
    fCost  = number,  -- gCost + hCost
    pos    = {x,y,z}, -- world position
    parent = string,  -- hash key of parent node (for path reconstruction)
}
```

**Movement costs** follow the standard A\* convention:
- Cardinal move (N/S/E/W): cost **10**
- Diagonal move (NE/NW/SE/SW): cost **14** (≈ 10 × √2)

**Termination conditions (whichever comes first)**

| Condition | Description |
|---|---|
| Goal reached | `current_index == target_index` or distance to `endpos < 1.1` |
| Open set empty | No reachable nodes remain |
| 10,000 node limit | Prevents frame-rate spikes on open terrain |
| 100 ms wall-clock timeout | `minetest.get_us_time()` guard |

---

## Path Reconstruction

When the goal is reached, the path is rebuilt by following `parent` pointers from the goal node back to the start:

```lua
local path = {}
local temp_idx = current_index
repeat
    local node_data = closedSet[temp_idx] or openSet[temp_idx]
    table.insert(path, node_data.pos)
    temp_idx = node_data.parent
until not temp_idx
```

The resulting list is then reversed so element `[1]` is the first waypoint from the start.

---

## Debug Visualisation

When a path is found, the mod spawns a **particle spawner on every waypoint** for visual debugging:

```
Texture:  heart.png^[colorize:#00FF00:200   (green hearts)
Duration: 30 seconds
Height:   1.2–1.3 nodes above waypoint
Glow:     10
```

A success message is also written to the action log:

```
[Pathfinder] SUCCESS: Path found (N nodes, M steps checked)
```

> [!WARNING]
> These debug particles and the chat broadcast on failure are currently **always active**. For production use, wrap them behind a configurable debug flag or remove them.

---

## Failure Diagnostics

When no path is found, the following information is broadcast to **all connected players** (debug aid):

```
[Pathfinder] FAIL: No path found after N nodes.
[Pathfinder] TARGET AUDIT at (x,y,z): <node names of 6 adjacent positions>
```

The target audit helps identify whether the goal position is surrounded by solid blocks, which would make it inherently unreachable.

---

## Start-Node Robustness

If the entity begins inside a physically solid block (clipped through terrain or a fence post), the algorithm probes five adjacent offsets in priority order before starting the search:

```lua
{x=0,y=1,z=0}   -- above (highest priority: escape upward)
{x=1,y=0,z=0}   -- east
{x=-1,y=0,z=0}  -- west
{x=0,y=0,z=1}   -- south
{x=0,y=0,z=-1}  -- north
```

The first non-solid neighbor becomes the effective start node. This prevents the NPC from failing to path immediately after spawning or after being teleported.

---

## Integration with the Mobs Mod

The `mobs` mod checks for the `pathfinder` mod via:

```lua
local pathfinder_mod = minetest.get_modpath("pathfinder")
```

And uses it when `mob_pathfinder_enable` is `true` in `minetest.conf` (default `true`).

The call is made from `mob_class:smart_mobs()` inside `mods/mobs/api.lua`:

```lua
if pathfinder_mod and pathfinder_enable then
    self.path.way = pathfinder.find_path(s, p1, self, dtime)
else
    self.path.way = minetest.find_path(
        s, p1,
        pathfinding_searchdistance,
        jumpheight, dropheight,
        pathfinding_algorithm)
end
```

The returned waypoint list (`self.path.way`) is consumed in `do_states → attack → dogfight`:

```lua
if self.path.following and self.path.way then
    local p1 = self.path.way[1]
    if abs(p1.x - s.x) + abs(p1.z - s.z) < 0.6 then
        table.remove(self.path.way, 1)  -- waypoint reached, advance
    end
    p = {x = p1.x, y = p1.y, z = p1.z}  -- steer toward next waypoint
end
```

---

## Configuration Checklist

| You want… | Set in `minetest.conf` |
|---|---|
| Disable external pathfinder completely | `mob_pathfinder_enable = false` |
| Also disable built-in pathfinding | `mob_pathfinding_enable = false` |
| Mobs trigger pathfinding sooner | Lower `mob_pathfinding_stuck_timeout` (default `3.0`) |
| Mobs give up path earlier | Lower `mob_pathfinding_stuck_path_timeout` (default `5.0`) |
| Entity can jump higher | Set `jump_height` in the mob definition |
| Entity won't drop far | Set `fear_height` in the mob definition |

---

## Known Limitations & Future Improvements

| Limitation | Notes |
|---|---|
| Single-threaded | Search runs on the main game thread; the 100 ms cap prevents stalls but limits range |
| 8-directional only | No vertical-only moves (ladders, vines) — entity must be able to jump |
| Debug output always on | Green heart particles and chat broadcasts should be gated behind a `debug` flag |
| Door state ignored in planning | `is_door_open` is defined but not used yet in the neighbor-expansion loop |
| No partial-path return | On failure the function returns `nil`; returning the best partial path may improve behaviour |
| Diagonal clearance not checked | Diagonal moves to corners may allow clipping through 1-node-wide walls |
