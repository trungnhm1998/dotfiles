---
name: unity-shaders
description: URP Shader Graph and custom HLSL shaders for Unity 6. Use when writing or debugging a shader, choosing between Shader Graph vs HLSL, implementing a visual effect (dissolve, outline, toon, water, glow), diagnosing SRP Batcher breakage, or understanding how URP lighting/passes work. Use proactively when a material-based effect is needed and the implementation path is unclear.
---

# Unity Shaders (URP)

Author URP-compatible shaders using Shader Graph or custom HLSL. Present options with trade-offs, then recommend; teach the why briefly.

## Use the references
- Shader Graph node recipes and workflow → `references/shader-graph-recipes.md`.
- Custom HLSL for URP (CBUFFER, lighting, vertex/fragment) → `references/hlsl-urp-basics.md`.
- Common effect implementations (dissolve, outline, toon, water) → `references/common-effects.md`.

## Defaults
- Prefer Shader Graph for new effects — visual, tweakable, URP-maintained. Drop to HLSL when Shader Graph can't express the logic or performance is critical.
- Always verify: SRP Batcher requires `CBUFFER_START(UnityPerMaterial)` around all material properties. Breaking this has real batch cost.
- Verify any URP API (pass names, built-in textures, `InputData`, `SurfaceData`) against context7 + URP docs before asserting — URP APIs changed across 12→14→17.
