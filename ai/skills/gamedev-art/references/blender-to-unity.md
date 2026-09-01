# Blender → Unity Pipeline

## Scale & Units

| Setting | Value |
|---|---|
| Blender scene units | **Metric, scale 1.0** (1 BU = 1 m) |
| Apply Scale before export | **Always** — Ctrl+A → Scale (or All Transforms) |
| Unity import scale | Leave at **1** in the Model Import Settings |

Un-applied scale (e.g. an object scaled to 0.01 in Object mode without applying) → physics wrong, animations wrong, particles wrong. Fix: Ctrl+A → Scale in Object mode before export.

## Coordinate Axes

Blender uses **Z-up, Y-forward**. Unity uses **Y-up, Z-forward**. The FBX exporter handles the conversion **if** you use the correct FBX export axis settings:

- **Forward:** `-Z Forward`
- **Up:** `Y Up`

(These are the Blender FBX exporter defaults — just don't change them.)

Result: the object arrives in Unity facing the correct direction. If it arrives rotated 90°, you either changed these or imported a file exported with different settings.

## FBX Export Settings (recommended)

In Blender: **File → Export → FBX (.fbx)**

| Option | Value |
|---|---|
| Selected Objects | On (export only what you need) |
| Apply Scalings | **FBX Units Scale** (recommended) |
| Forward / Up | `-Z / Y` (defaults) |
| Apply Unit | On |
| Armature: Add Leaf Bones | Off (cleaner hierarchy in Unity) |
| Mesh: Smoothing | **Face** (normals baked per face) or **Edge** (hard-edge-aware) |
| Mesh: Tangent Space | On (required for normal maps) |

## Unity Import Settings (Model tab)

| Setting | Value |
|---|---|
| Scale Factor | 1 (if Apply Scale was done) |
| Import Blendshapes | as needed |
| Generate Colliders | Off (create manually) |
| Normals | Import (use Blender's normals) |
| Tangents | Calculate Tangent Space or Import |

## Materials

**Option A — Unity Material Remapping (recommended for solo devs)**
- In Unity Model Import Settings → **Materials** tab → Extract Materials.
- Unity creates stub materials; you then assign textures manually.
- Keeps materials editable in Unity without touching Blender.

**Option B — Embed Textures in FBX**
- In FBX export: enable **Path Mode: Copy** + press the embed icon.
- Unity imports textures automatically but they're harder to manage.

**Recommended texture naming convention** (assign manually after Extract Materials):
- `AssetName_albedo` or `_d` → drag onto Albedo slot
- `AssetName_normal` or `_n` → drag onto Normal Map slot (set Import Type = Normal map)
- `AssetName_metallic` or `_m` → drag onto Metallic slot

## Common Import Errors

| Symptom | Cause | Fix |
|---|---|---|
| Object rotated 90° | Wrong FBX axis settings | Re-export with `-Z Forward, Y Up` |
| Object 100× too small | Scale not applied | Ctrl+A → Scale, re-export |
| Animations broken/stretched | Un-applied scale on armature | Apply scale to armature + mesh before rigging |
| No materials visible | Embedded textures missing | Use Extract Materials and reassign |
| Dark face patches | Flipped normals | In Blender: select all → Mesh → Normals → Recalculate Outside |
| Seams visible in-engine | Smoothing group mismatch | Set Smoothing to Edge in FBX export |

## Texture Formats for Unity (URP)

| Format | Use |
|---|---|
| PNG | Albedo, roughness/metallic masks |
| PNG (16-bit) | Height maps |
| EXR | HDR emission, lightmaps |
| Unity auto-compresses | DXT (PC), ASTC (mobile) at import |

Set **Max Size** to 1024 or 2048 for game assets; 512 for small props.
