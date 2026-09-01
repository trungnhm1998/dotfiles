# Modeling Fundamentals for Game Assets

## Low-Poly vs High-Poly Workflow

**Direct low-poly (most common for solo indie):**
- Model the final mesh at the target triangle count.
- Add detail with normal maps baked from a high-poly or hand-painted.
- Fast iteration, easier to rig and animate.

**High-poly → low-poly bake (for hero assets):**
1. Model a detailed high-poly.
2. Retopologize to low-poly.
3. Bake: normals, AO, curvature from high → low.
4. Use the low-poly in-engine with the baked maps.

**Poly budget rough guides (URP, mid-range target):**
| Asset type | Triangle range |
|---|---|
| Background prop | 50–500 |
| Environment piece | 200–2 000 |
| Gameplay character | 1 000–5 000 |
| Hero/player character | 3 000–10 000 |

Keep total scene tris under your target GPU budget; profile on actual hardware.

## UV Unwrapping

**Goal:** every face maps to a non-overlapping UV island on a 0–1 UV space.

**Blender workflow:**
1. Mark Seams: select edges → Edge → Mark Seam. Put seams where they're least visible (under arms, back of neck, bottom of props).
2. Select all faces in Edit mode → U → Smart UV Project (quick) or Unwrap (better for complex shapes).
3. In UV Editor: arrange islands to fill 90%+ of UV space; larger/important faces get more UV space.

**Tips:**
- UV islands should not overlap (unless intentional for mirrored UVs).
- Keep UVs axis-aligned where possible for better texel density.
- Use **Texel Density** addon (or manual check) to ensure consistent texture resolution.

## Texture Atlasing

Combine multiple objects' textures into one atlas → reduces draw calls (one material for many objects).

**Blender workflow:**
1. Set all objects to use the same material.
2. Unwrap all objects into the same UV space (manually pack islands or use UVPackmaster addon).
3. Bake/paint onto one shared texture.

**When to atlas:** environment props that appear together frequently. Don't atlas: character (needs own UVs for skinning).

## Normal Map Baking (Blender)

1. Create a high-poly version of your mesh.
2. Duplicate → low-poly retopo (or use Decimate as a quick test).
3. In Blender: Render → Cycles. Add a new Image Texture node to the low-poly material (don't connect it — just select it as the bake target).
4. Select the high-poly first, then Shift-select the low-poly so the low-poly is the active object → Render Properties → Bake → Bake Type: Normal → enable **Selected to Active** → Bake. (The active/last-selected object receives the bake.)
5. Export the baked normal map; import into Unity with Import Type = Normal map.

## Topology Tips

- **Quads preferred** during modeling (loop cuts work correctly; subdiv works).
- **Triangulate before export** (Blender FBX export does this automatically; or Ctrl+T in Edit mode).
- Avoid **n-gons** (faces with 5+ vertices) — they triangulate unpredictably.
- **Edge flow** should follow the shape's curvature for cleaner deformation on animated meshes.
- **Poles** (vertices with 3 or 5+ edges): minimize them; place away from deformation zones.

## LODs (Level of Detail)

Unity supports LOD Groups. For solo indie, LODs are optional — profile first, add if needed.
- Rough LOD ratios: LOD0 = 100%, LOD1 = 50%, LOD2 = 20% of LOD0 tris.
- In Unity: add a `LODGroup` component; assign mesh renderers to each LOD level.
- Transition distances depend on object screen size — tweak in the LODGroup inspector.
