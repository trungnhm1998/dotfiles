---
name: gamedev-art
description: Blender 3D art and the Blender-to-Unity pipeline for indie game assets. Use when modeling, UV unwrapping, texturing, rigging, or animating in Blender, or when exporting/importing assets into Unity (scale, axis, FBX settings, materials). Use proactively when the user is about to create or import a 3D asset and hasn't addressed the export pipeline.
---

# Gamedev Art (Blender → Unity)

Author game-ready 3D assets in Blender and get them into Unity correctly. Present options with trade-offs, then recommend; teach the why.

## Use the references
- Export settings, scale, axis, materials, common import errors → `references/blender-to-unity.md`.
- Low-poly modeling, UV unwrapping, atlasing, baking → `references/modeling-fundamentals.md`.
- Rigging, animation clips, Unity Animator setup → `references/animation-pipeline.md`.

## Defaults
- Always **Apply Scale** (Ctrl+A → Scale) in Blender before export — un-applied scale causes wrong physics/animation in Unity.
- Export FBX with **Forward: -Z, Up: Y** (Blender default) → Unity's coordinate system handles the rest.
- Buy-vs-build note: character art and animation rigging are time-intensive; stock assets (Synty, Kenney) are clear buy wins for a solo dev unless art style is the game's identity.
