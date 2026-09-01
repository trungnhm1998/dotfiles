# Animation Pipeline (Blender → Unity)

## Rigging Basics in Blender

**Armature setup:**
1. Add Armature (Shift+A → Armature).
2. In Edit mode: extrude bones to match the mesh hierarchy (root → pelvis → spine → chest → etc.).
3. Name every bone clearly: `mixamo` naming or Unity's `Humanoid` naming for Humanoid rig support.
4. Parent mesh to armature: select mesh, then armature → Ctrl+P → **With Automatic Weights**. Check for weight painting issues.

**Humanoid vs Generic rig in Unity:**

| Rig type | Use when | Trade-offs |
|---|---|---|
| Humanoid | Biped characters; want Avatar retargeting / IK / animation reuse | Requires bone name mapping; some deformation tweaks lost |
| Generic | Non-biped, props, vehicles, stylized characters | Full control; no retargeting |

**Recommendation:** Use **Humanoid** for player/NPC characters (animation retargeting and IK are worth it); **Generic** for everything else.

## Creating Animation Clips in Blender

1. Open the **Action Editor** (in the bottom editor strip, switch to Action Editor).
2. Click **New** to create an action. Name it clearly: `Idle`, `Run`, `Jump_Start`, `Attack_01`.
3. Animate in Object/Pose mode using keyframes (I key).
4. For export: in the **Action Editor** header, click the **Push Down** button (down-arrow icon) to push the current action into an NLA strip. Repeat for each action. Alternatively, in the FBX export options enable **Bake Animation** → all actions export automatically.

**FBX export for animations:**
- Enable **Armature** and **Mesh** in the export.
- Under **Animation**: enable **Bake Animation**, set **Simplify** to 0 (or low) for clean curves.
- **Key All Bones** = on (avoids missing keyframe issues in Unity).

## Unity Import: Animations

In Unity, select the imported FBX → **Animations** tab:
- Each NLA strip / action appears as a clip. Select it → set **Loop Time** if it's a looping animation.
- Set **Root Transform Rotation / Position**: for in-place animations, **Bake into Pose** the root position (XZ). For root motion, leave it off.
- **Compression**: Optimal or Off (Off = larger file but no baking artifacts).

## Animator Controller

1. Create an Animator Controller asset → assign to the character's `Animator` component.
2. Add **States** (each references an animation clip).
3. Add **Parameters** (Float `Speed`, Bool `IsGrounded`, Trigger `Jump`).
4. Add **Transitions** with conditions (e.g. Speed > 0.1 → Walking; Trigger Jump fires → Jump state).

**Blend Trees** (for directional movement):
- Replace multiple speed states with a 1D or 2D Blend Tree.
- 1D: drive by `Speed` → blend Idle → Walk → Run.
- 2D Simple Directional: drive by `VelocityX` + `VelocityZ` → blend 8-directional movement.

## Root Motion vs Script-Driven Movement

| Approach | Use when |
|---|---|
| Root motion | Animation defines movement; character velocity matches anim (melee, climbing) |
| Script-driven | Physics/controller owns velocity; animation is cosmetic overlay |

**Root motion setup:** Enable **Apply Root Motion** on the `Animator`; bake root into the clip (uncheck "Bake Into Pose" for XZ in Unity import). The Animator.OnAnimatorMove callback lets you intercept and modify root motion.

## Common Animation Issues

| Symptom | Cause | Fix |
|---|---|---|
| Character slides on import | Root motion off / wrong pose root | Check "Bake Into Pose" XZ in Unity clip settings |
| T-pose on play | No default state in Animator | Set a default state (right-click → Set as Layer Default State) |
| Jittery animation | High Simplify on FBX export | Set Simplify to 0 in Blender FBX export |
| Animation stretches mesh | Scale not applied to armature | Apply scale (Ctrl+A) to both mesh and armature in Blender before rigging |
| Clips not visible in Unity | Actions not in NLA or not exported | Push actions to NLA strips in Blender before export |
