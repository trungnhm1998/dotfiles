# Pacing and Flow

## Table of Contents
1. [Intensity Curves](#intensity-curves)
2. [Reward Placement & Rhythm](#reward-placement--rhythm)
3. [Critical Path vs Exploration](#critical-path-vs-exploration)
4. [Difficulty Curve & Introduce-Then-Test](#difficulty-curve--introduce-then-test)
5. [Flow & Avoiding Fatigue](#flow--avoiding-fatigue)

---

## Intensity Curves

Intensity is the player's felt emotional load — threat, urgency, cognitive demand, sensory stimulation — at any moment.

**The pattern:** tension → release → tension → bigger release. Never flat; never unrelenting.

```
Intensity
  |         /\        /\
  |        /  \  /\  /  \___rest
  |   /\  /    \/  \/
  |__/  \/
  |_________________________ Time
```

**Practical tools:**
- **Combat encounters** — ramp up enemy count or aggression, then drop to a safe corridor before the next encounter.
- **Environmental threats** — narrowing paths, falling platforms, rising hazards, then a wide rest space.
- **Music/audio layers** — add instruments as threat increases; strip back on resolution.
- **Lighting** — dim, saturated colours during high intensity; warm, open light for rest beats.

**Recommendation:** Chart your level's intensity by minute on paper before building. Aim for 3–5 peaks per level with clear valleys between them. The final encounter should be the highest peak.

---

## Reward Placement & Rhythm

Rewards include: pickups (health, ammo, collectibles), narrative reveals, unlocks, vistas/set-pieces, and the satisfaction of clearing a room.

**Rhythm principles:**
- Place small rewards frequently early; space them further as the player gains mastery.
- Put a reward immediately after a hard section to confirm the player solved it correctly and create a positive feedback loop.
- Use optional rewards (off the critical path) to incentivise exploration without taxing players who stay on the golden path.
- Avoid placing a major reward right before a checkpoint — the player may quit after claiming it. Place checkpoints after rewards.

**Common mistakes:**
| Mistake | Effect | Fix |
|---|---|---|
| Reward before the hard section | Negates effort, feels cheap | Move reward to after |
| Long stretches with no reward | Player feels lost or bored | Add small collectibles or environmental payoffs |
| Every reward mandatory | Exploration feels pointless | Make 20–30 % of rewards optional |

**Recommendation:** Map every reward on your level layout diagram. Check that no 60-second stretch is completely empty.

---

## Critical Path vs Exploration

The **golden path** is the minimum-viable route from start to end. Everything else is optional content.

**Design the golden path first:**
1. Identify the mandatory gates (key, ability, story beat).
2. Connect them with the shortest playable route.
3. Test that route alone — if it isn't fun, the level isn't fun.

**Then layer optional content:**
- **Branches:** short side corridors that return to the main path (dead-end branches with a reward are fine if the return cost is low).
- **Secrets:** hidden areas that reward curiosity — use visual cues (different texture, suspicious gap, suspicious shadow) rather than pure randomness.
- **Sequence breaks:** if your game allows skipping sections, design one intentional shortcut so skilled players feel rewarded, not frustrated.

**Signposting:** players should always be able to reorient toward the critical path. Use:
- Lighting direction (light sources ahead on the golden path)
- NPC dialogue or arrows in the environment
- Subtle colour temperature shift (warm = forward, cool = side)

**Recommendation:** Draw the path as a flow diagram with branches annotated as optional. Never let an optional branch be longer than ~25 % of the segment it's adjacent to, unless it's a distinct sub-zone.

---

## Difficulty Curve & Introduce-Then-Test

The safest framework for teaching mechanics:

```
1. Introduce  → Safe space, no threat, player experiments freely
2. Reinforce  → Low-stakes challenge, one correct answer
3. Test       → Full pressure, player must apply skill under threat
4. Mastery    → Combine with another mechanic or add a twist
```

**Example — double jump in a 2D platformer:**
1. Gap that's jumpable with single jump, but a floating platform in the middle is placed at double-jump height → player discovers by accident.
2. Gap too wide for single jump, no enemies, clear landing. Only solution is double jump.
3. Same gap but with a patrolling enemy on the far side. Timing matters.
4. Moving platform + enemy below. Double jump combined with timing and enemy avoidance.

**Rules:**
- Never test a mechanic before introducing it.
- Keep the introduction visually unambiguous — if the player doesn't see the mechanic exists, they can't learn it.
- Allow failure without hard punishment at introduction and reinforce stages (no death pits until test stage).

**Difficulty tuning knobs:**
- Enemy count, health, damage
- Timer pressure
- Resource scarcity (ammo, healing)
- Environmental hazards density
- Information density (how many things to track simultaneously)

Adjust one knob at a time when playtesting so you can isolate what changed.

---

## Flow & Avoiding Fatigue

**Flow state** (Csikszentmihalyi): the player is fully engaged when challenge slightly exceeds current skill. Too easy → boredom. Too hard → anxiety/frustration.

**Signs you're out of flow:**
- Player dies in the same spot 5+ times with no visible progress → reduce difficulty or add a mid-point checkpoint.
- Player breezes through 3 sections in a row without tension → raise stakes or add a complication.
- Player reports the level feels "samey" → you need a pacing beat change (rest room, new mechanic, set-piece).

**Avoiding fatigue:**
- **Change the verb:** if a level is all combat, add a traversal challenge, a stealth moment, or a puzzle. Even 30 seconds of different activity resets attention.
- **Vary spatial density:** open spaces after tight corridors, vertical sections after horizontal ones.
- **Control sound:** silence or ambient-only sections feel restful even if the gameplay is neutral.
- **Limit continuous intensity to ~90 seconds** before a beat change, or players start to feel overwhelmed.

**Recommendation:** playtest with a timer running. If any emotional register (tense, calm, exploring, fighting) lasts more than 90–120 seconds unbroken, break it up.
