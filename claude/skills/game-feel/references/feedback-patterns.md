# Feedback Patterns — Channels, Readability, Input Feel

## Table of Contents
1. [Feedback Channels](#feedback-channels)
2. [Readability Discipline](#readability-discipline)
3. [Input Feel](#input-feel)
4. [Game-State Communication](#game-state-communication)

---

## Feedback Channels

Every player action or world event can be communicated across up to four channels. Layering them multiplies perceived weight; using only one makes events feel thin.

| Channel | Examples | Unity entry points |
|---------|----------|--------------------|
| **Visual** | Hit flash, particles, screen shake, UI pop, color change | ParticleSystem, Animator, shader properties, UI Animator, Cinemachine Impulse |
| **Audio** | Impact SFX, voice/grunt, music sting, UI click | AudioSource, AudioMixer, FMOD/Wwise |
| **Haptic** | Controller rumble (gamepad), mobile vibration | `Gamepad.current?.SetMotorSpeeds()` (Input System), Handheld.Vibrate() |
| **Gameplay** | Hitstop, knockback, slowdown, unlock | Code-level: Time.timeScale, Rigidbody forces |

**Layering principle:** Visual alone = readable. Visual + audio = satisfying. Add haptic = visceral. Add gameplay pause (hitstop) = impactful. Each layer is additive — you don't need all four for every event, but a major hit or death should use at least three.

### Channel priority by event severity
- Minor (footstep, UI hover): 1 channel (audio or visual).
- Standard (bullet impact, coin collect): 2 channels (visual + audio).
- Heavy (boss hit, player damage): 3 channels (visual + audio + gameplay).
- Critical (kill, level complete): all 4.

---

## Readability Discipline

**One clear signal per event.** When two events fire simultaneously (player shoots, shell casing drops, muzzle flashes, enemy reacts) all effects compete. Hierarchy them:

1. Identify the **primary communicator** (what the player must understand: "I hit the enemy").
2. Make that signal the largest or most saturated.
3. Secondary effects (shell casing, dust) are smaller, desaturated, or time-offset by a frame or two.

### Contrast budget
Each frame has a limited "contrast budget." Every particle, flash, and shake spends some of it. When the budget overflows, players feel confused, not impressed. Audit by asking: can a new player immediately read what just happened?

### Color semantics
Establish and maintain color conventions early:
- One color = player damage / danger (typically red).
- One color = enemy hit confirmation (typically white flash).
- One color = pickups / positive events (typically yellow/gold).

Do not repurpose a convention mid-game.

### Duration and persistence
Short effects (< 0.1 s) communicate snap and speed. Long effects (> 0.5 s) communicate power and weight. Effects that linger too long obscure subsequent events. If your particle system is still visible when the next attack fires, shorten it.

---

## Input Feel

The feel of *controls* — not just effects — is often the first bottleneck.

### Input buffering
**What:** Accept and queue an input for a short window (e.g., 0.1–0.2 s) before it can legally execute. Prevents "I pressed it but nothing happened."
**How:** Store `_bufferedAction = action; _bufferTimer = bufferWindow;` on press. In the relevant state check, execute and clear if `_bufferTimer > 0`.
```csharp
void Update() {
    if (Input.GetButtonDown("Jump")) { _jumpBuffer = 0.15f; }
    _jumpBuffer -= Time.deltaTime;
    if (_jumpBuffer > 0 && _isGrounded) { Jump(); _jumpBuffer = 0; }
}
```

### Coyote time
**What:** Allow a jump for a short window (0.08–0.15 s) after the player walks off a ledge. Corrects the frustration of "I was on the edge and fell."
**How:** Record `_coyoteTimer` when the player leaves ground (but did not jump). Allow jump if timer > 0.
```csharp
if (_wasGrounded && !_isGrounded && !_jumped) _coyoteTimer = 0.12f;
_coyoteTimer -= Time.deltaTime;
bool canJump = _isGrounded || _coyoteTimer > 0;
```

### Response latency
Target input → visual response within 1 frame (16 ms at 60 fps). Any perceptible delay between button press and animation/movement start reads as "laggy controls." Common causes:
- Animations with long entry transitions (shorten blend times in Animator).
- Physics-only movement queried after `FixedUpdate` (input checked in `Update`, applied in `FixedUpdate` — this is correct; do NOT move physics objects in `Update`).
- Over-smoothed velocity (ease in is fine, but first-frame response should be immediate).

### Feel of acceleration vs. top speed
Instant top speed = snappy but can feel slippery. Gradual acceleration = weighty but can feel unresponsive. Recommendation: fast acceleration (reach 80% speed in ~0.1 s), then soft deceleration to top speed. This reads as responsive *and* weighty.

---

## Game-State Communication

### Telegraphs (tells)
A telegraph is a visual cue that precedes a threat, giving the player time to react. Without it, damage feels unfair.
- **Duration:** Match to difficulty. Easy: 1.0–1.5 s. Hard: 0.3–0.5 s.
- **Implementation:** Use `Animator` warning states, floor decals (projected decals in URP), or a progress-bar shader on the enemy.
- **Rule:** If the player has no recourse until after the damage, it is punishment, not challenge.

### Cooldown readability
Players need to know *when* an ability is ready without stopping to look at UI.
- **Visual:** Desaturate/darken the ability icon while cooling down; restore color with a "ready" flash.
- **Audio:** A subtle "ready" sound cue when cooldown completes — players learn this subconsciously.
- **In-world:** Color-shift the character model slightly (shader `_CooldownAmount` property) for the player's own abilities.

### Health / resource legibility
- Keep health bars large enough to read during fast action.
- Use color gradient (green → yellow → red) so current state is readable peripherally.
- Flash the bar briefly on damage rather than just sliding it — the flash confirms the event even when the player's gaze is elsewhere.

### Information hierarchy in VFX
If an enemy has a weak point, its VFX there should be noticeably different from general hit sparks — brighter color, different shape, or a unique sound. This teaches the system without a tutorial.
