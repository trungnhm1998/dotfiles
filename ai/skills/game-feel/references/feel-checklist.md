# Feel Checklist — Juice Levers & Tuning

## Table of Contents
1. [The Juice Levers](#the-juice-levers)
2. [Tuning Order](#tuning-order)
3. [Tooling Notes](#tooling-notes)
4. [Anti-Patterns](#anti-patterns)

---

## The Juice Levers

### Anticipation (Wind-Up)
**What it does:** A small pre-motion in the opposite direction signals intent and builds energy before an action fires. Borrowed from animation principles.
**Unity how-to:** On attack/jump start, tween scale to `(0.85, 1.15, 1)` over ~0.06 s using an ease-in curve, then spring back on the actual action fire.
```csharp
// PrimeTween example
Tween.Scale(transform, new Vector3(0.85f, 1.15f, 1f), 0.06f, Ease.InQuad)
     .OnComplete(() => FireAttack());
```

### Hitstop / Freeze-Frame
**What it does:** Pausing time for 1–6 frames at moment of impact makes hits feel physically heavy. Even 2 frames is perceptible.
**Unity how-to:** Set `Time.timeScale = 0f` for `hitStopDuration` seconds, then restore. Keep VFX and audio running on `unscaledTime`.
```csharp
IEnumerator HitStop(float duration) {
    Time.timeScale = 0f;
    yield return new WaitForSecondsRealtime(duration); // unscaled
    Time.timeScale = 1f;
}
```
Lever: `duration` — 0.04–0.10 s for light hits, up to 0.16 s for heavy/boss impacts.

### Screenshake
**What it does:** Communicates force and trauma spatially. Players read magnitude as power.
**Unity how-to (Cinemachine 3.x):** Add `CinemachineImpulseSource` on the hit source; add `CinemachineImpulseListener` on the `CinemachineCamera`. Call `impulseSource.GenerateImpulse(force)`.
```csharp
[SerializeField] CinemachineImpulseSource _impulse;
void OnHit() => _impulse.GenerateImpulse(Vector3.up * 0.3f);
```
Alternative (no Cinemachine): perlin-noise offset on a camera rig child, decaying over time.

### Knockback
**What it does:** Physical displacement of the hit target confirms force and creates readable spacing.
**Unity how-to:** `rb.AddForce(direction * strength, ForceMode2D.Impulse)`. For deterministic knockback override velocity: `rb.linearVelocity = direction * knockbackSpeed`.

### Particles / VFX
**What it does:** Punctuate events (hit sparks, dust on landing, muzzle flash) and reinforce audio.
**Unity how-to:** Use `ParticleSystem` with `Stop Action: Destroy` on one-shot effects. Pool heavy emitters via `ObjectPool<T>` (Unity built-in since 2021.1). URP: use VFX Graph for GPU-accelerated effects.

### Squash & Stretch
**What it does:** Exaggerates physical mass and acceleration — a bouncing object squashes on land, stretches in flight.
**Unity how-to:** Tween scale non-uniformly. Preserve volume: if X scales to `s`, Y scales to `1/s`. Apply on jump launch (stretch Y) and landing (squash Y).
```csharp
// Stretch on jump
Tween.Scale(transform, new Vector3(0.8f, 1.3f, 1f), 0.08f, Ease.OutQuad);
```

### Easing Curves
**What it does:** The shape of motion communicates weight. `OutQuad` = deceleration = heavy. `InBack` = anticipation. `OutElastic` = springy.
**Unity how-to:** Use `AnimationCurve` fields evaluated in `Lerp` calls, or pass `Ease` enum values to PrimeTween/DOTween. Avoid `Lerp(a, b, t)` with linear `t` for anything player-facing.
```csharp
// Evaluate custom curve
float t = _curve.Evaluate(elapsed / duration);
transform.position = Vector3.LerpUnclamped(start, end, t);
```

### Audio Layering
**What it does:** Stacked audio (impact body, high-frequency crack, low bass thump) creates perceived weight beyond what any single clip achieves.
**Unity how-to:** Play multiple `AudioSource`s simultaneously with slight pitch randomization (`pitch = Random.Range(0.95f, 1.05f)`). Use AudioMixer groups to keep layers balanced.

### Color Flashes (Hit Flash)
**What it does:** A brief white/red flash on a hit target confirms contact without relying on particles alone.
**Unity how-to (URP):** Swap material to a full-emission white material for 1–3 frames, then restore. Or use a `_HitFlashAmount` float property on a custom URP shader with `Lerp(baseColor, white, flashAmount)`.
```csharp
IEnumerator FlashWhite() {
    _renderer.material = _flashMaterial;
    yield return new WaitForSeconds(0.05f);
    _renderer.material = _originalMaterial;
}
```

### Time-Scale Tricks
**What it does:** Slow-motion (bullet-time), speed-ramp, and brief pauses create dramatic emphasis and let players read complex situations.
**Unity how-to:** `Time.timeScale` for global scale. Use `unscaledDeltaTime` in systems that must remain responsive (UI, camera). Tween time-scale itself for smooth ramp-in/out:
```csharp
Tween.Custom(1f, 0.3f, 0.15f, t => Time.timeScale = t, Ease.OutQuad);
```
Note: PrimeTween's `Tween.Custom` runs on `unscaledTime` when `useUnscaledTime: true`.

---

## Tuning Order

1. **Get it working mechanically first** — no juice on broken gameplay.
2. **Add audio** — often the cheapest highest-impact lever. A solid sound alone can make a prototype feel real.
3. **Add hitstop** — test at 2 frames, 4 frames, 6 frames. Stop when it feels satisfying, not later.
4. **Add screenshake** — start at 10% of what feels like "enough". It compounds with other effects.
5. **Add particles** — minimal first (a few sparks), scale up only if needed.
6. **Add easing/squash** — refine motion curves last; polish what's already readable.
7. **Each pass:** play the game, not the effect in isolation. Cut anything that doesn't communicate the underlying event.

> Rule: if removing an effect makes the action _less clear_, keep it. If removing it just makes it less flashy, it's optional.

---

## Tooling Notes

**PrimeTween** (free, Asset Store / UPM): Zero-allocation, modern API, runs on unscaled time natively. Recommended for new projects. Drop-in for many DOTween patterns.

**DOTween** (free standard / $15 Pro, Asset Store): Most-used tweening library, massive community, excellent sequencing (`DOSequence`). Pro adds a visual editor. Solid choice if you need tutorials or complex UI sequences.

They do not conflict — you can use both in one project. For a new indie project leaning build: start with PrimeTween; reach for DOTween if you need its DOSequence editor or find existing tutorials easier to follow.

**Feel / MMFeedbacks** (paid, ~$60 Asset Store, MoreMountains): Pre-wired feedback components covering shake, flash, particles, audio, haptics, and more. Version 5.x (2024–2025) requires Unity 6000.0.23f1+. Trade-off: faster to prototype, less control and more black-box than rolling your own. Worth it if you want polish before systems are stable.

---

## Anti-Patterns

- **Juice that hides game state:** A flashy hit effect that obscures whether the enemy died or is still alive. Every effect must leave state _more_ readable, not less.
- **Over-shake:** Screen shake above ~0.4 world-unit amplitude quickly becomes nauseating. Additive shakes from multiple sources compound — cap total magnitude.
- **Motion sickness triggers:** Constant camera motion, field-of-view pulses, and rotation shake (vs. positional shake) are the worst offenders. Prefer translational shake over rotational.
- **Hitstop stacking:** Multiple hitstops firing in rapid succession freeze gameplay. Gate with a cooldown or ignore new hitstop while one is active.
- **All levers at once on first hit:** Layer effects over playtesting sessions. Starting with everything on makes it impossible to know what is actually working.
