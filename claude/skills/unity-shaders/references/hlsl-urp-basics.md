# Custom HLSL Shaders for URP

Use when Shader Graph can't express the logic (multi-pass, custom vertex deformation, performance-critical instanced draws).

## Minimal URP Unlit Shader Template

```hlsl
Shader "Custom/MyUnlit"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
        _BaseMap   ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // SRP Batcher: ALL material properties must be inside this CBUFFER
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            TEXTURE2D(_BaseMap);  SAMPLER(sampler_BaseMap);

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings   { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                return tex * _BaseColor;
            }
            ENDHLSL
        }
    }
}
```

## SRP Batcher Rule (critical)
Every `float`/`half`/`int` property declared in `Properties {}` **must** appear inside `CBUFFER_START(UnityPerMaterial) … CBUFFER_END`. Textures and samplers live **outside** (they are in a separate bind group). Breaking this = SRP Batcher incompatible = batches break = draw call cost.

## URP Include Files (Unity 6 / URP 17)
| Include | Provides |
|---|---|
| `Core.hlsl` | `TransformObjectToHClip`, `TRANSFORM_TEX`, built-in matrices |
| `Lighting.hlsl` | `GetMainLight()`, `LightingLambert`, `LightingSpecular` |
| `ShaderVariablesFunctions.hlsl` | Utility functions (screen UV, depth sample) |
| `DeclareDepthTexture.hlsl` | `SampleSceneDepth(uv)` |
| `DeclareOpaqueTexture.hlsl` | `SampleSceneColor(uv)` (grab-pass alternative) |

Path prefix: `Packages/com.unity.render-pipelines.universal/ShaderLibrary/`

## Accessing URP Lighting (Lit pass)
```hlsl
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// In fragment:
InputData inputData = (InputData)0;
inputData.positionWS = IN.positionWS;
inputData.normalWS   = normalize(IN.normalWS);
inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

SurfaceData surfaceData = (SurfaceData)0;
surfaceData.albedo     = albedo.rgb;
surfaceData.smoothness = _Smoothness;
surfaceData.occlusion  = 1.0;

return UniversalFragmentPBR(inputData, surfaceData);
```

## LightMode Tags
| Tag value | When used |
|---|---|
| `UniversalForward` | Main color pass (opaque/transparent) |
| `ShadowCaster` | Shadow casting — required for shadows |
| `DepthOnly` | Pre-depth pass (required for depth effects) |
| `DepthNormals` | Normals pre-pass (SSAO) |
| `Universal2D` | 2D Renderer |

## Common Gotchas
- **Missing shadow pass**: if your custom shader doesn't include a `ShadowCaster` pass, objects cast no shadows. Copy one from URP samples.
- **GPU instancing**: add `#pragma multi_compile_instancing` to enable; does not require changing `#pragma target`. Keep `#pragma target 3.5` or higher for URP features like depth texture access.
- **Depth texture sampling**: call `#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"` and enable Depth Texture in the URP Asset.
- **API drift**: `GetMainLight()` signature and `InputData`/`SurfaceData` fields changed between URP 12, 14, 17. Always check against context7 for your URP version.
