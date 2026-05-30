# Camera Feel — Cinemachine 3.x, Follow, Shake, Framing

## Table of Contents
1. [Cinemachine 3.x Basics](#cinemachine-3x-basics)
2. [Follow & Damping](#follow--damping)
3. [Screenshake via Impulse](#screenshake-via-impulse)
4. [Framing — 2D vs 3D](#framing--2d-vs-3d)
5. [Common Mistakes](#common-mistakes)

---

## Cinemachine 3.x Basics

Cinemachine ships with Unity 6 as package `com.unity.cinemachine` 3.x. **Key API changes from 2.x:**

| 2.x component | 3.x replacement |
|---|---|
| `CinemachineVirtualCamera` | `CinemachineCamera` |
| `CinemachineFreeLook` | `CinemachineCamera` (with `CinemachineOrbitalFollow`) |
| `CinemachineTransposer` | `CinemachineFollow` (component on same GO) |
| `CinemachineFramingTransposer` | `CinemachinePositionComposer` |
| `CinemachineComposer` | `CinemachineRotationComposer` |
| `CinemachineGroupComposer` | `CinemachineGroupFraming` |
| `CinemachineCollider` | `CinemachineDeoccluder` |
| `CinemachineConfiner` | `CinemachineConfiner2D` / `CinemachineConfiner3D` |
| `Cinemachine3rdPersonFollow` | `CinemachineThirdPersonFollow` |

**Namespace:** All types moved to `Unity.Cinemachine` (was `Cinemachine`).
```csharp
using Unity.Cinemachine; // Cinemachine 3.x
```

**Architecture change:** In 2.x, pipeline components lived on a hidden child GO named "cm". In 3.x, all components (`CinemachineFollow`, `CinemachineRotationComposer`, etc.) are attached directly to the `CinemachineCamera` GameObject.

**Brain:** The `CinemachineBrain` component remains on the main `Camera` GameObject. It blends between active virtual cameras based on priority or manual activation.

**Minimal setup:**
1. Add `CinemachineBrain` to your main Camera.
2. Create a new GameObject, add `CinemachineCamera` component.
3. On the same GameObject, add `CinemachinePositionComposer` (2D following) or `CinemachineFollow` (3D offset follow).
4. Set `Follow` and `LookAt` targets on `CinemachineCamera`.

---

## Follow & Damping

### CinemachinePositionComposer (2D / screen-space follow)
Keeps the target in a defined screen region. Key fields:
- `Damping` (Vector3): How slowly the camera catches up. `(0.5, 0.5, 0)` is a reasonable starting point. Higher = heavier camera.
- `DeadZoneWidth/Height` (float): Target can move within this region without the camera responding.
- `SoftZoneWidth/Height` (float): Camera begins re-framing when target enters this border band.

```csharp
var composer = vcam.GetComponent<CinemachinePositionComposer>();
composer.Damping = new Vector3(0.4f, 0.4f, 0f);
composer.DeadZoneWidth  = 0.1f;
composer.DeadZoneHeight = 0.1f;
```

### Lookahead
`CinemachinePositionComposer` exposes `Lookahead.Time` — the camera predicts where the target will be in N seconds and leads the shot. Useful for fast-moving 2D games.
- `LookaheadTime = 0` = pure follow.
- `0.2–0.5` = camera leads the player; feels proactive.
- Disable or lower for top-down or slow-paced games to avoid jitter.

### CinemachineFollow (3D offset follow)
Maintains a fixed offset from the target in Follow-object space. Combine with `CinemachineRotationComposer` or `CinemachineThirdPersonFollow` for character cameras.

### Damping tuning rubric
- **Action platformer:** `Damping X = 0.3–0.5`, `Y = 0.1–0.2` (horizontal lag gives world breadth, tight vertical prevents nausea on jumps).
- **Top-down shooter:** `Damping X = Y = 0.2–0.4`, enable lookahead at `0.3`.
- **Cinematic / narrative:** `Damping X = Y = 0.8–1.5` for heavy, cinematic weight.

---

## Screenshake via Impulse

### Setup (Cinemachine 3.x)
1. Add `CinemachineImpulseSource` to the GameObject that generates the event (enemy, explosion, player).
2. Add `CinemachineImpulseListener` to the `CinemachineCamera` GameObject (it is a `CinemachineExtension`).

```csharp
using Unity.Cinemachine;

[SerializeField] CinemachineImpulseSource _impulse;

void OnImpact() {
    _impulse.GenerateImpulse(Vector3.up * 0.25f); // direction * force
}
```

### CinemachineImpulseListener fields
- `Gain` (float): Multiplier on incoming impulse strength. Default 1. Lower to taste.
- `ChannelMask` (int): Bitmask; listener only reacts to matching source channels. Use to isolate heavy hits from environmental rumble.
- `Use2DDistance` (bool): Distance falloff calculated in 2D (ignores Z) — enable for 2D games.
- `UseCameraSpace` (bool): Impulse direction interpreted in camera space.

### Taming screenshake
- **Start at 0.1–0.2 force** and raise. It is far easier to add than to un-learn an over-shaken game.
- **Channel separation:** Use channel 1 for player hits, channel 2 for explosions. Tune `Gain` per listener per channel.
- **Prefer positional shake over rotational.** Impulse-driven positional shake (default) is less nauseating than rotational.
- **Cap simultaneous impulses.** If many enemies all `GenerateImpulse` at once, result is overwhelming. Consider a singleton shake manager that throttles total active impulses.

### Alternative: Perlin shake (no Cinemachine Impulse)
For simple cases or if not using Cinemachine Impulse:
```csharp
IEnumerator Shake(float duration, float magnitude) {
    float elapsed = 0f;
    Vector3 origin = transform.localPosition;
    while (elapsed < duration) {
        float t = elapsed / duration;
        float strength = magnitude * (1 - t); // decay
        transform.localPosition = origin + (Vector3)Random.insideUnitCircle * strength;
        elapsed += Time.deltaTime;
        yield return null;
    }
    transform.localPosition = origin;
}
```
Use for camera rig child, not the Brain camera itself.

---

## Framing — 2D vs 3D

### 2D
- Use `CinemachinePositionComposer` as the position component.
- Enable `Use2DDistance` on any `CinemachineImpulseListener` to keep shake planar.
- For side-scrollers: set a small dead zone horizontally, generous vertically. Players expect horizontal panning to reveal ahead; vertical whipping is disorienting.
- **Lead the player:** offset screen position slightly in the direction of movement using `ScreenPosition` (e.g., `0.1` bias toward movement direction). Update via script when player changes direction, eased over ~0.3 s.
- **Confiner:** `CinemachineConfiner2D` with a `PolygonCollider2D` on a dedicated layer prevents camera from showing outside the level bounds.

### 3D
- Use `CinemachineFollow` or `CinemachineThirdPersonFollow` + `CinemachineRotationComposer`.
- Set a meaningful dead zone in `CinemachineRotationComposer` to avoid micro-jitter when the target is nearly stationary.
- For over-the-shoulder: `CinemachineThirdPersonFollow` handles collision-aware offset out of the box.
- **Depth of field and FOV as feel tools:** Narrow FOV = zoomed, tense. Wide FOV = fast, action. A brief FOV squeeze on sprinting or landing (tweened) adds physical weight without requiring any effect art.

---

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| **Too much shake** | Players feel seasick; reviews mention "headaches" | Cut shake force to 30% of current; add Gain cap |
| **Jitter on stationary target** | Camera vibrates when player stands still | Increase dead zone width/height; lower lookahead |
| **Rotational shake** | Horizon tilts — nauseating, especially in 3D | Use positional impulse only; set impulse direction to world-up or world-right |
| **Snapping camera** | Teleports when target moves fast | Enable damping; check that you're not overriding `transform.position` directly each frame while Cinemachine controls the camera |
| **Multiple active VCams at same priority** | Unpredictable blending | Only one `CinemachineCamera` should be "Live" at a time; manage via priority or `CinemachineCamera.enabled` |
| **Shake during cutscenes** | Immersion-breaking | Gate impulse listeners: `impulseListener.enabled = false` during scripted sequences |
| **Forgetting `CinemachineBrain` on main camera** | Virtual cameras do nothing | `CinemachineBrain` must be on the Unity `Camera` component's GameObject |
