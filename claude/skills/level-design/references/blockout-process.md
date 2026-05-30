# Blockout Process

## Table of Contents
1. [Greybox-First](#greybox-first)
2. [Player Metrics](#player-metrics)
3. [Iteration Loop](#iteration-loop)
4. [When to Lock Layout Before Art](#when-to-lock-layout-before-art)

---

## Greybox-First

A **greybox** (or blockout / whitebox) is a level built entirely from untextured primitive geometry — cubes, ramps, cylinders, planes — with placeholder pickups and hazards. No art, no final materials.

**Why iterate before art:**
- Art is expensive to change. A wall moved 2 metres in grey geometry takes seconds; the same move with final meshes, lightmaps, and dressed props takes hours.
- Fun is determined by layout, scale, and metrics — not by how it looks. Discovering the layout is broken after art is in is one of the most costly mistakes in game dev.
- Playtesting a greybox gives uncontaminated feedback: testers react to the gameplay, not the visuals.
- It forces you to commit to scale early, which prevents the common trap of building beautiful areas that don't actually play well.

**What a greybox must contain:**
- All geometry that the player can stand on, run along, jump over, or be blocked by
- Approximate enemy spawn positions (use placeholder cubes or GameObjects tagged `Enemy_Placeholder`)
- All pickups, doors, triggers, and scripted events (can be invisible triggers)
- Camera bounds/confines (especially for 2D)
- Lighting direction indicator (a directional light, not final — just to reveal readability)

**What to leave out:**
- Final meshes, textures, materials
- VFX, particles, ambient audio
- Final lighting bakes

**Tooling in Unity 6.x:**
- **3D:** Use **ProBuilder** (`com.unity.probuilder`, available via Package Manager → Unity Registry) to build blockout geometry directly in the scene. Faster than importing external meshes, and geometry can be resized and reshaped non-destructively.
- **2D:** Use the built-in **Tilemap** system (Window → 2D → Tile Palette) with solid-colour debug tiles. For basic collision shapes, Unity's primitive sprites or BoxCollider2D on sprites work well.
- Both: Unity's built-in **primitive GameObjects** (3D Object → Cube / Plane / Sphere) are always available and zero-dependency for very quick blocking.

---

## Player Metrics

Player metrics are the physical properties of your character that define how the level must be designed. Every jump gap, ceiling height, and ledge must be derived from these numbers — not guessed.

**Core metrics to measure before building:**

| Metric | How to measure | Typical use |
|---|---|---|
| Walk speed | Units/sec at ground level | Corridor length, patrol territory |
| Run/sprint speed | Units/sec | Chase sequences, open area scale |
| Jump height (apex) | Units above ground at peak | Ceiling clearance, platform height |
| Jump distance (horizontal) | Units from takeoff to landing | Gap width |
| Double-jump height / distance | If applicable | Upper platform reach |
| Crouch height | Units of clearance needed | Low passage height |
| Dash distance | Units covered | Gap bypass, hazard skip |
| Reach / attack range | Units in front of player | Enemy placement, breakable object distance |
| Fall damage threshold | Units of fall before damage | Pit depth for punishment vs safe-drop |

**Translating to grid:**
- Pick a base unit. Common choices: 1 Unity unit = 1 metre (for 3D); 1 tile = 16px or 32px at 100 PPU (for 2D).
- Convert all metrics to this unit. Example: "player runs at 6 units/sec, corridor should feel long but not tedious → 12–18 units (2–3 seconds)."
- In ProBuilder, use the vertex snap grid (hold Ctrl while moving) set to 0.25 or 0.5 units to keep geometry on consistent increments.
- In Tilemap, the grid IS your unit — design everything in tile counts derived from your metrics.

**Practical tip:** Create a **metrics reference scene** — a simple flat scene with labelled geometry showing jump arc, run distance markers, and max reach. Keep it open in a second Editor window while building. This is sometimes called a "metric sheet."

---

## Iteration Loop

Level design is a loop, not a pipeline. Expect to run it 5–10 times on a single level.

```
Plan (paper/diagram)
       ↓
Build greybox
       ↓
Playtest (self + others)
       ↓
Identify friction / dead spots
       ↓
Adjust layout / metrics
       ↓
Re-playtest
       ↓  (repeat until fun)
Lock layout
```

**Playtesting the greybox:**

- **Solo playtest:** play your own level, but do it without stopping. Don't fix things mid-run. Take notes. Look for: moments you die unfairly, moments you're confused about where to go, moments nothing interesting happens.
- **Observer playtest:** watch someone else play without giving hints. Note where they get stuck, where they go the wrong direction, and where they seem bored or frustrated. Do not intervene.
- **Metrics to watch:** death locations, time per section, exploration paths taken.

**Adjustment heuristics:**
- Player dies at same spot repeatedly → reduce threat, add cover, or add a checkpoint before it.
- Player misses the critical path → add a sightline, light source, or audio cue pointing the way.
- Section feels too short → extend the buildup, not the payoff.
- Section feels too long → remove filler encounters, tighten geometry.
- Player doesn't find the optional area → make the entrance more visually distinct or add a hint.

**Recommended iteration cadence:**
- After each full blockout pass, do a solo playtest before touching anything.
- Get an observer playtest after you feel "it's working."
- Only start dressing art after two observer playtests where no one gets lost and timing feels right.

---

## When to Lock Layout Before Art

Locking layout means: the walls, platforms, doors, and major geometry will not move. You are committing to this as the final spatial structure.

**Lock conditions — all should be true:**
1. A player unfamiliar with the level can reach the end without being told where to go.
2. Playtests show consistent timing within acceptable range (e.g., your target is 4 minutes; playtests land 3:30–5:00).
3. No section produces more than 2–3 consecutive unfair deaths in observer playtests.
4. The critical path is navigable; optional content is discoverable by at least 50 % of playtesters without hints.
5. Encounter difficulty matches the intended curve (not accidental spikes).

**What you can still change after locking:**
- Enemy properties (health, damage, speed) — these are tuning, not layout.
- Pickup positions (fine adjustment within a defined zone).
- Lighting mood and colour (not structural sightlines).
- Visual dressing (props, decals) — as long as they don't block navigation.

**What you cannot change after art starts:**
- Floor/wall/ceiling positions (every centimetre shift invalidates lightmaps and prop placement).
- Camera volumes and trigger zones tied to geometry.
- Doorway/opening dimensions (all door art/animations are keyed to this).

**Recommendation:** Create a checklist in a comment component or a text file next to the scene. Sign it off with a date. Treat post-lock layout changes as a formal decision requiring re-playtesting, not a quick tweak.
