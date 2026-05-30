# Common Shader Effects (URP)

## Dissolve (Burn / Cutout Transition)

**How it works:** Sample a noise texture; subtract a threshold; alpha-clip the result. Animate the threshold 0→1 to dissolve.

**Shader Graph:**
1. `Sample Texture 2D` (noise) → `R` channel → `Subtract` (threshold Float property) → `Alpha Clip Threshold` input.
2. Enable **Alpha Clipping** in Graph Settings.
3. Add an **Edge Color**: `Step` node (Edge = 0.05, In = subtracted value) → multiply by Edge Color → add to Emission. This outputs 1 in the thin band above the clip threshold, creating a glowing edge.
4. Animate `_DissolveThreshold` via script: `material.SetFloat("_DissolveThreshold", t)`.

**HLSL shorthand:**
```hlsl
float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, IN.uv).r;
clip(noise - _Threshold); // pixels below threshold are discarded
```

---

## Outline

**Option A — Normal Expand (single-pass, cheap):**
Extra pass renders the object slightly scaled along normals, back-face only, solid color.
```hlsl
// Extra pass: Cull Front
// Attributes struct must include: float3 normalOS : NORMAL; float4 positionOS : POSITION;
float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
float3 posWS    = TransformObjectToWorld(IN.positionOS.xyz) + normalWS * _OutlineWidth;
OUT.positionHCS = TransformWorldToHClip(posWS);
// return outline color in fragment
```
Limitation: breaks on hard-edge meshes (split normals artifact). Fix: store smooth normals in UV4.

**Option B — Post-process (Renderer Feature, robust):**
Edge-detect on depth+normals buffer via a URP Renderer Feature. Cleaner look, works on any mesh. Higher cost, more setup. Use `ScriptableRendererFeature` + `ScriptableRenderPass`.

**Recommendation:** Option A for quick in-game outlines (enemies, pickups); Option B for a stylized global outline look.

---

## Toon Shading (Cel Shading)

**Core idea:** Step/posterize the diffuse light value instead of smooth gradient.

**Shader Graph:**
1. `Normal Dot Product` with main light direction → `Step(threshold)` → controls shadow band.
2. For multiple bands: `Smoothstep` or a `Ramp Texture` (sample a 1D gradient texture with the dot value as UV.x).
3. **Specular**: `Smoothstep` on the specular highlight → makes it a hard dot.

**HLSL:**
```hlsl
float NdotL = saturate(dot(normalWS, lightDir));
float toon  = step(0.5, NdotL);        // hard shadow at 50%
// Or ramp: SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(NdotL, 0.5)).r;
float3 color = albedo * toon * lightColor;
```

**Outline pairing:** Toon shading + normal-expand outline = classic cel look. Keep outline width subtle (0.002–0.006 world units).

---

## Stylized Water

**Layers:**
1. **Depth fade** — sample `_CameraDepthTexture`, compute water depth, drive opacity/color from depth.
2. **Surface normal distortion** — scroll two normal maps at different speeds; combine with `BlendAngleCorrectedNormals` or add them; distort screen-space reflection UV.
3. **Foam** — near-shore foam: `step(depthDifference, foamThreshold)` → foam texture mask.
4. **Wave vertex offset** — in vertex shader, add `sin(time + positionWS.x * freq) * amplitude` to Y position.

**Shader Graph approach:** Use `Scene Depth` node (requires depth texture enabled in URP Asset). For screen-space distortion use `Scene Color` node (opaque objects only; transparent order matters).

**Buy-vs-build note:** Stylized water is a significant shader — Crest Ocean System (expensive, feature-rich) or Polyart Stylized Water (affordable, simple) are clear buy wins for complex water. Build for simple surfaces.

---

## Glow / Bloom

Bloom in URP is **post-processing, not per-object**. Make objects appear to glow:
1. Add a **Volume** with **Bloom** effect enabled; set Intensity and Threshold.
2. On glowing materials: set **Emission** color above 1 in HDR (use the HDR color picker; values > 1 trigger bloom).
3. Enable HDR on the camera (URP Asset → HDR checkbox).

For selective glow (some objects only): use a Layer Mask on the Bloom volume, or paint the glow object to a separate render layer using a Renderer Feature.
