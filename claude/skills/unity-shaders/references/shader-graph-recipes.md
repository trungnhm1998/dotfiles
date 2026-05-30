# Shader Graph Recipes (URP)

## Setup
- Create: **Assets → Create → Shader Graph → URP → Lit / Unlit Shader Graph**. Lit follows URP's lighting model; Unlit is free-form.
- Assign to a material: set the material's Shader dropdown to your graph.
- Graph Inspector (top-left) → **Graph Settings**: set Surface Type (Opaque/Transparent), Render Face, Alpha Clipping.

## Exposed Properties
Add properties in the **Blackboard** (left panel). Each property becomes an editable field on materials and can be animated or set via `MaterialPropertyBlock`.

| Property Type | Use for |
|---|---|
| Texture2D | albedo, normal maps, masks |
| Float / Vector1 | scalars (threshold, speed) |
| Color | tint, emission color |
| Boolean | toggle features (keyword) |

Tip: rename the **Reference** field (in the property inspector) — this is the HLSL variable name scripts will use.

## Core Node Patterns

### Texture + Normal Map (lit)
1. `Sample Texture 2D` → albedo → plug into **Base Color** of Fragment.
2. `Sample Texture 2D` — set the node's **Type** dropdown to **Normal** (this unpacks the normal map automatically) → plug into **Normal (Tangent Space)**.
3. Add a `Smoothness` float property → **Smoothness**.

### UV Scrolling (water, lava, conveyor)
```
Time → Multiply (speed) → Add to UV → Sample Texture 2D
```
Use a `Vector2` property for scroll direction so it's tweakable.

### Alpha Clipping (dissolve base)
Enable **Alpha Clipping** in Graph Settings. Drive the **Alpha** output from a noise texture; drive the **Alpha Clip Threshold** from a Float property. Animating the threshold over time = dissolve.

### Emission
Sample an emission texture (or use Color) → multiply by intensity Float → plug into **Emission**. Enable **Emission** in Graph Settings.

### Fresnel / Rim
`Fresnel Effect` node → multiply by color → add to Emission. Controls: Power (sharpness), base (strength).

## Subgraphs
**Create → Shader Graph → Sub Graph**. Reusable node group — acts like a function. Great for: UV distortion, noise sampling, color grading. Keep subgraphs in `Assets/Shaders/Subgraphs/`.

## SRP Batcher Compatibility
Shader Graph generates SRP-Batcher-compatible shaders automatically **as long as you don't add extra HLSL passes manually** that skip the CBUFFER. Check compatibility: select the shader asset → Inspector → "SRP Batcher: compatible".

## Common Gotchas
- **Transparency sorting**: Transparent materials use the camera distance sort — objects at the same distance flicker. Use `Render Queue` offset or OIT.
- **Shader keywords bloat**: each Boolean property adds a keyword variant. Keep Boolean toggles minimal; prefer masking via a texture.
- **Normal map import setting**: texture must be imported as **Normal map** type, or the Y-channel is wrong.
- **Precision**: use `Half` precision in Graph Settings for mobile performance gains; watch banding on gradients.
