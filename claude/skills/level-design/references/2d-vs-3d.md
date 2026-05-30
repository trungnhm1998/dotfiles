# 2D vs 3D Level Design Differences

## Table of Contents
1. [Sightlines & Readability](#sightlines--readability)
2. [Navigation & Gating](#navigation--gating)
3. [Composition — Leading the Eye](#composition--leading-the-eye)
4. [Tooling Notes](#tooling-notes)

---

## Sightlines & Readability

Sightlines are the lines of information the player reads from the current camera view. Everything in a level must be readable from that view — if the player can't see a threat or path, they cannot respond to it fairly.

### 2D

- The camera is almost always fixed to an axis (side-scrolling, top-down, isometric). The player sees a flat slice of the world.
- **Advantage:** readability is inherently high — everything in the frame is at the same visual depth, so silhouettes carry most of the information. A pit is obviously a pit. An enemy stands out against a background.
- **Challenge:** depth illusion requires deliberate parallax layering. Without it, the background and foreground blend together, and hazards become unreadable.
- **Rules of thumb:**
  - Hazards and enemies must contrast strongly against the background in both hue and value (brightness). Test in greyscale.
  - Platforms the player can stand on should share a consistent visual language (e.g., always a top edge highlight, always a specific colour family). Don't use the same visual style for decorative background geometry that mimics platforms — this causes phantom-platform confusion.
  - Camera scroll direction implies progression — scrolling right means "go right." Break this rule deliberately and signal it.

### 3D

- The camera has full 3D freedom (third-person, first-person, fixed 3D, isometric 3D). Depth is real, not implied.
- **Advantage:** vertical and horizontal space feel independent; massive scale differences are immediately legible.
- **Challenge:** sightlines can be destroyed by geometry. A pillar in the wrong place hides an enemy. A ceiling blocks a platform the player needs to see. Corners become blind spots where threats can spawn unfairly.
- **Rules of thumb:**
  - Design sightlines explicitly: stand at each major decision point and ask "can the player see the threat / exit / reward from here before committing?" If not, open up the geometry or move the element.
  - Enemy sight and spawn placement must account for camera angle — a threat spawning behind the camera is never fair.
  - Use height differentiation: elevated positions should feel like rewards or threats the player can read and respond to, not surprises.
  - Test all sightlines at the game's actual FOV, not at editor defaults.

---

## Navigation & Gating

### 2D

- Navigation is primarily **left/right** (side-scrolling) or **cardinal** (top-down). The solution space is constrained by the axis lock.
- **Gating mechanisms:** locked doors, key pickups, ability gates (e.g., can't reach that ledge until you have double jump), destructible walls, switches.
- **Returning to blocked areas (Metroidvania style):** the locked area must be visible before the player has the key — they need to register "I cannot get there yet" as a goal, not a mystery after the fact.
- **Backtracking cost:** 2D layouts can use shortcuts (one-way drops, teleporters) to reduce tedious backtracking without removing the sense of a connected world.
- **Trap:** 2D levels can feel linear even when they branch, because the flat axis makes spatial relationships obvious. Counteract this with vertical layering — routes at different heights give a sense of a larger space.

### 3D

- Navigation is **omnidirectional**. Players can approach most points from multiple angles. This is both the biggest design freedom and the biggest readability risk.
- **Gating mechanisms:** same core types (locked doors, abilities, keys), plus: narrow passages that implicitly limit access, elevated platforms only reachable with a specific skill, environmental hazards that block until deactivated.
- **Wayfinding is a first-class design concern in 3D and not in 2D.** The player cannot see the whole level at a glance. You must design navigational landmarks — a tower visible from everywhere, a colour-coded objective marker, an audio cue that increases in volume near the goal.
- **Trap:** 3D environments can feel like mazes if every corridor looks the same. Each major junction or area should have a unique visual anchor (different light colour, a distinctive prop, different wall texture) so players can self-locate.

**Key difference summary:**
| | 2D | 3D |
|---|---|---|
| Primary navigation axis | 1–2 axes | All axes |
| Wayfinding complexity | Low (axis-locked) | High (requires landmark design) |
| Gating visibility | Easy (can see locked area) | Requires deliberate sightline design |
| Backtracking cost | Manageable with shortcuts | High if not addressed with map/markers |

---

## Composition — Leading the Eye

Composition is how you arrange visual elements to guide the player's attention toward what matters: the next platform, the threat, the exit.

### 2D

Leading the eye in 2D is graphic design applied to games.

- **Value contrast:** the most important element should be the brightest or darkest thing in the frame. If everything has the same value, nothing is prioritised.
- **Framing:** architectural elements (arches, corridors, overhangs) can frame the next objective and point the player's gaze there.
- **Colour temperature:** warm colours advance (catch the eye); cool colours recede. Use warm accent colours on critical-path elements.
- **Line direction:** diagonal lines in the background implicitly suggest movement direction. Horizontal lines feel stable/safe; angled lines feel dynamic/dangerous.
- **Enemy colour:** enemies should break from the background palette deliberately — one contrasting hue used only for enemies. This is a readability contract with the player.
- **Parallax layers:** foreground (darkened, partial) → midground (gameplay) → background (muted, low detail). Keep the gameplay layer (midground) highest in contrast. Background elements should never compete with gameplay elements for brightness.

### 3D

Leading the eye in 3D uses spatial and lighting techniques rather than graphic composition.

- **Light as a waypoint:** a shaft of light, a glowing object, or a brighter lit area draws the player toward it. This is the single most effective wayfinding tool in 3D.
- **Architectural funnelling:** corridors, doorways, and gaps naturally direct movement. Players move toward openings. Design chokepoints to point toward objectives.
- **The "thumbnail test":** blur the scene heavily. Can you still see the path of light and the objective? If not, the composition needs more contrast.
- **Scale and silhouette:** a large, distinctive structure at the end of a path (a tower, a gate, a cliff) acts as a destination goal. Players instinctively move toward large distinct shapes.
- **Avoid visual noise near critical paths:** over-dressed environments with many equally prominent props flatten the hierarchy. Reserve visual complexity for non-critical areas (rest spaces, optional zones); keep the critical path clean.
- **Camera angle and FOV:** a lower camera angle makes ceilings and upper routes readable; a higher one opens up floor-level layout. Decide camera disposition intentionally for each zone based on what the player needs to see.

---

## Tooling Notes

### 2D — Tilemap System

Unity's built-in **Tilemap** system is the standard 2D blockout and level-building tool.

- **Package:** `com.unity.2d.tilemap` — included with Unity by default; no separate install needed for basic Tilemap. The **2D Tilemap Extras** package (`com.unity.2d.tilemap.extras`, available via Package Manager → Unity Registry) adds additional tile types (RuleTile, AnimatedTile, RandomTile) useful for blockouts and final tilesets.
- **Blockout workflow:**
  1. Create a Grid GameObject (GameObject → 2D Object → Tilemap → Rectangular / Isometric).
  2. Open the Tile Palette (Window → 2D → Tile Palette).
  3. Create a solid-colour debug tile (a 16×16 or 32×32 sprite filled with a flat colour, sliced as a single tile). Use distinct colours per layer: green = ground, red = hazard, blue = water, grey = wall.
  4. Paint the level with the Tile Palette brush. Adjust grid cell size to match your character metrics in pixels-per-unit.
- **Colliders:** add a **Tilemap Collider 2D** component to the tilemap and a **Composite Collider 2D** (with Rigidbody2D set to Static) to merge tile colliders into a single efficient shape.
- **Layers:** use separate Tilemap GameObjects per layer (ground, background, hazards, foreground decoration) so you can toggle visibility and colliders independently.
- **Limitation:** Tilemap is grid-constrained. For non-grid geometry (angled ramps, organic shapes), use a SpriteShape or plain polygon colliders with sprite art.

### 3D — ProBuilder

**ProBuilder** (`com.unity.probuilder`) is the standard 3D blockout tool for Unity.

- **Install:** Package Manager → Unity Registry → search "ProBuilder" → Install. Compatible with Unity 6.x (verified: package version 6.0.x released for Unity 6000.x).
- **Blockout workflow:**
  1. Open the ProBuilder window (Tools → ProBuilder → ProBuilder Window).
  2. Create shapes with New Shape (Cube, Stair, Arch, Cylinder, etc.).
  3. Select faces/edges/vertices to extrude, bevel, or resize directly in the scene.
  4. Use Vertex snapping (hold Ctrl) and the ProBuilder grid to keep geometry on consistent units.
  5. Assign a flat unlit material in a neutral colour (grey or distinct-colour-per-zone) to all blockout meshes. Disable shadows during blockout to keep the editor fast.
- **Key operations for blockout:**
  - **Extrude Face:** select a face → press `E` (or use ProBuilder toolbar) → drag to extend a wall or platform.
  - **Insert Edge Loop:** subdivides a face so you can reshape mid-geometry.
  - **ProGrids / Grid Snapping:** use the scene grid (View → Grid and Snap Settings) or ProBuilder's built-in snapping to keep geometry on metric units.
- **Limitation:** ProBuilder is for blockout and simple final geometry, not high-poly art. Export to a DCC (Blender, Maya) for final assets, or use ProBuilder meshes as collision proxies behind final art.
- **Alternative for very simple blockouts:** Unity primitive GameObjects (cube, plane, ramp made from a rotated cube) require zero setup and are sufficient for early metric testing before ProBuilder shapes are needed.

**Trade-off summary:**
| Tool | Strength | Weakness |
|---|---|---|
| Tilemap (2D) | Fast grid-based iteration, built-in colliders | Grid-locked, no freeform geometry |
| 2D Tilemap Extras | Rule Tiles for auto-tiling, less manual painting | Extra package to install |
| ProBuilder (3D) | Freeform mesh editing in-editor, precise extrusion | Steeper learning curve than primitives |
| Unity Primitives (3D) | Zero setup, always available | No mesh editing, limited shapes |
