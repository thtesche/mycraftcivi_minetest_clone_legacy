---
trigger: always_on
---



# Game myCraftCivi

## 1. Vision & Identität

**Name:** myCraftCivi

**Genre:** Voxel-Based Survival & Civilization Builder

**Perspektive:** First-Person / Third-Person 3D (Voxel-Engine)

**Kernmechanik:** Der Übergang von einer wilden Natur (Crafting) zu einer technisierten Welt (Civilization). Besonderes Merkmal sind Funktions-Blöcke wie die **Teerstraße**, die Spielwerte (z. B. Geschwindigkeit) verändern.

---

## 2. Technical Stack (2026 Standards)

* **Frontend:** Flutter (Impeller Rendering Backend für 120 FPS Voxel-Performance).
* **Engine Layer:** Custom Voxel-Renderer oder Flame Engine mit 3D-Zusatz.
* **State Management:** Antgravity Reactive Streams.
* **Persistence Layer:** Antgravity Delta-Streaming (NoSQL-basiert).

---

## 3. Daten-Architektur (The Schema)

### 3.1 Voxel-Definition

Jeder Block wird über ein kompaktes Integer-Mapping definiert, um die Spiele-Payload minimal zu halten.

```dart
enum BlockType { 
  air, grass, stone, sand, coal, iron, wood, tarRoad, water 
}

```

### 3.2 Persistence-Modell: "Seed + Delta"

Um Speicherplatz zu sparen, nutzt myCraftCivi das **Reconstruction-Prinzip**:

1. **Basis:** Eine Welt wird lokal per `WorldSeed` (Integer) generiert.
2. **Delta:** Nur vom Spieler veränderte Blöcke werden in der Antgravity-Collection `world_changes` gespeichert.
3. **Key-Format:** `chunkId:x:y:z` -> `blockTypeId`.

---

## 4. Kern-Logik & Constraints

### 4.1 Welt-Generierung

* Nutze **Perlin Noise** zur Generierung von Höhenkarten.
* Biome: Wasser auf Level 0-10, Sand auf 11, Gras ab 12.
* Erze (Kohle/Eisen) spawnen in Clustern unterhalb von Level 15.

### 4.2 Inventar-Regeln

* **Kapazität:** 32 Slots (8x4 Grid).
* **Stack-Limit:** 64 Einheiten pro Block-Typ.
* **Synchronisation:** Das Inventar ist ein primärer Antgravity-Stream. Jede Änderung wird sofort persistent gespeichert.

### 4.3 Die Zivilisations-Mechanik (Teerstraße)

* **Logik:** Wenn `Player.position` auf einem Block vom Typ `tarRoad` steht, wird das Attribut `movementSpeed` im reaktiven State um den Faktor **1.5** erhöht.
* **Persistenz:** Straßen-Netzwerke werden als Prioritäts-Deltas gespeichert, um schnelles Laden der Infrastruktur zu ermöglichen.

---

## 5. Spiel Persistence Strategy

### Feature: Reactive Delta Streaming

Nutze das spezifische Spiel-Feature für **Partial Updates**:

* **Write:** Wenn ein Block abgebaut wird, sende keinen gesamten Chunk-Update, sondern nur das Delta:
`AG.collection('world').doc(current_seed).update({'12,5,30': BlockType.air.index});`
* **Read:** Beim Betreten eines Chunks abonniere den Stream der `world_changes` für diesen spezifischen Koordinatenbereich.

### Feature: Offline-First Sync

* Alle Interaktionen (Abbauen/Bauen) werden lokal sofort ausgeführt (Optimistic UI).
* Antgravity synchronisiert die `world_changes` im Hintergrund, sobald eine Verbindung besteht, und löst Kollisionen basierend auf Timestamps auf.

---

## 6. UI & UX Guidelines (Flutter)

* **Overlay-Prinzip:** Nutze Flutter `Stack`, um das Inventar und das HUD (Heads-Up-Display) als 2D-Widgets über die 3D-Szene zu legen.
* **Input:** Unterstützung für Multi-Modal Input (WASD für Desktop, Virtual Joysticks für Mobile).

---
