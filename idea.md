# Game myCraftCivi

## 1. Vision & Identity

**Name:** myCraftCivi

**Genre:** Voxel-Based Survival & Civilization Builder

**Perspective:** First-Person / Third-Person 3D (Luanti Engine)

**Core Mechanic:** The transition from wild nature (Crafting) to a technologized world (Civilization). A special feature includes functional blocks like **Asphalt**, which modify gameplay attributes (e.g., movement speed).

---

## 2. Technical Stack (Luanti Standards)

* **Engine:** Luanti (Voxel engine with Lua API).
* **Rendering:** Irrlicht/Mt-Engine (Cross-platform voxel rendering).
* **State Management:** Lua table-based state & mod persistent storage.
* **Persistence Layer:** SQLite/LevelDB (Luanti standard).

---

## 3. Data Architecture (The Schema)

### 3.1 Voxel Definition

Every block is defined via `minetest.register_node`.

```lua
-- Example Node Definition
minetest.register_node("civi_core:stone", {
    description = "Stone",
    tiles = {"civi_stone.png"},
    groups = {cracky = 3, stone = 1},
})
```

### 3.2 Persistence Model: "Chunk Storage"

Luanti manages the world in chunks (MapBlocks).

1. **Base:** A world is generated via a `WorldSeed`.
2. **Delta:** All interactions are stored in the world database.
3. **Format:** Standard Luanti Map format.

---

## 4. Core Logic & Constraints

### 4.1 World Generation

* Use Luanti Mapgen V7 or a custom Lua Mapgen.
* Biomes: Water, Sand, Grass, Stone.
* Ores (Coal/Iron/Copper/Gold) spawn in clusters.

### 4.2 Inventory Rules

* **Capacity:** Standard Luanti inventory grid.
* **Synchronization:** The inventory is synchronized between server and client via the Luanti protocol.

### 4.3 The Civilization Mechanic (Asphalt Road)

* **Logic:** When a player stands on a block of type `civi_core:asphalt`, the `movementSpeed` is increased by a factor of **1.8** via `physics_override`.
* **Persistence:** Roads are part of the regular Map Delta.

---

## 5. Game Persistence Strategy

### Feature: Mod Storage

Use `minetest.get_mod_storage()` for civilization metadata.

* **Write:** Changes to the world are permanently stored in `map.sqlite`.
* **Read:** When a MapBlock is loaded, all nodes and their metadata are automatically loaded.

### Feature: Offline Interaction (Singleplayer)

* All interactions are executed locally immediately.
* Luanti ensures the consistency of the world database.

---

## 6. UI & UX Guidelines (Luanti Formspecs)

* **Overlay Principle:** Use Luanti `formspec` to display inventory and menus.
* **Input:** Standard Luanti controls (WASD, F7 for perspective, Mouse for interaction).

---
