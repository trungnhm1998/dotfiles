# Playtesting Guide for Solo Indie Dev

## Contents
1. Why and when — early, ugly, often
2. Running a session — don't explain, watch
3. What to observe
4. Signal vs noise
5. Acting on feedback

---

## 1. Why and When

You cannot playtest your own game. You know where everything is, how it works, and what is supposed to happen. You will never experience your game the way a first-time player does. That experience is the only one that matters at launch.

**Why:**
- Players will find failure modes you cannot imagine.
- Fun that feels obvious to you may be invisible to others.
- Confusion you've normalized will stop real players cold.
- Early playtesting is cheap. Late playtesting is expensive. Post-launch discovery is catastrophic.

**When to start:** As soon as the game is playable without you holding it together. If the vertical slice is not there yet, playtesting friends informally still yields signal. Even an ugly prototype with the core mechanic can be playtested to answer "is this interesting at all?"

**Cadence:**
- Prototype phase: 1–2 informal sessions with anyone available.
- Vertical slice: 3+ dedicated sessions, ideally with people who don't know you well.
- Production milestones: Every 4–6 weeks minimum.
- Pre-beta: Wider external playtest (5–10+ people).
- Post-beta: One final check on the release build flow (install, launch, first 10 minutes).

**Who to ask:**
- Players in your target audience are the most valuable.
- Friends and family give false positives — they will be kind. Still useful for basic sanity checks.
- Strangers on Discord, game dev communities, or local events give honest reactions.

---

## 2. Running a Session

The hardest rule: **do not explain the game**.

If you have to explain something for the player to proceed, that is a bug in your game, not a gap in their knowledge. Note it and stay quiet.

### Setup
- Give them the build and step back.
- Say: "I'm going to watch you play. I won't answer questions — I want to see what happens without my help. There are no wrong answers."
- If they ask how to do something: "What do you think?" or just "Try it."

### During the session
- Do not say anything. Write things down instead.
- Note: what they do, where they stop, what they say out loud.
- Watch their face, not the screen — confusion, boredom, and delight are readable.
- Time box: 20–40 minutes is usually enough for a vertical-slice-sized game. Longer is fine if they're still engaged.

### After the session
- Ask open questions: "What was going through your head when X happened?" "What did you think you were supposed to do there?" "Was there anything you wanted to do that you couldn't?"
- Avoid leading questions: not "Did you find the combat fun?" — ask "What did you think of the combat?"
- Let them talk. Don't defend or explain.

### Recording
If you can screen-record (OBS, Unity's built-in recorder), do it. You will miss things during the live session.

---

## 3. What to Observe

**Stuck moments** — they stop moving, look around, re-read things. The game failed to communicate something.

**Bored moments** — pace slows, they disengage, they start doing something mindless. The game is not giving them enough to react to.

**Confused moments** — they do something unexpected, repeatedly, that breaks your intent. The feedback loop is unclear.

**Delight moments** — they laugh, lean in, say "oh!" or "wait, can I...?" These are gold. Note them. Do more of what caused them.

**First-minute behavior** — what do they do in the first 60 seconds with zero guidance? This is your tutorial / onboarding test.

**Death / failure reactions** — frustration is normal; hopelessness is not. Do they understand why they failed?

**What they ignore** — if a system you built goes untouched, the game isn't surfacing it or the player doesn't need it.

---

## 4. Signal vs Noise

One tester is not a trend.

| Observation type | Weight |
|---|---|
| Same thing happens with 3+ testers | Strong signal — investigate |
| 2 testers hit the same moment | Soft signal — watch for more |
| 1 tester does something unusual | Weak signal — note it, don't act yet |
| 1 tester says "you should add X" | Opinion — see section 5 |
| 1 tester doesn't finish | Could be time, could be disengagement, could be life — not enough data |

**Bias adjustments:**
- Friends playtest charitably. Discount praise from friends; focus on what confused them.
- Younger / less experienced players show UI and onboarding gaps more clearly.
- Hardcore players miss tutorialization gaps because they try everything instinctively.

**The exit survey trap:** Survey data is the least useful playtest data. What players do is more honest than what they say. Watch first; ask after.

---

## 5. Acting on Feedback

### The core rule
**Problems are real. Solutions are suggestions.**

When a player says "you should add a map," they are telling you they felt lost. They are not necessarily telling you to build a map. The underlying problem (felt lost) is real. Their proposed solution (map) is one option among many — and often not the right one.

Always translate feedback into the underlying problem before deciding what to fix:
- "The combat is too hard" → player is failing in a way that feels unfair. Maybe telegraphing, maybe progression, maybe a specific enemy.
- "I didn't know where to go" → navigation/direction feedback is failing. Maybe an arrow, maybe better landmarks, maybe level design.
- "It felt slow" → the game's pacing is off somewhere. Maybe movement speed, maybe reward frequency, maybe enemy density.

### What to fix and what to park
- **Fix immediately:** anything that prevents players from experiencing the core loop. Crashes, softlocks, blocking confusion.
- **Investigate:** anything that 3+ testers hit in the same place.
- **Park in the Later list:** feature requests. The game might not need them.
- **Ignore (carefully):** one-off opinions that contradict your design intent, especially from players outside your target audience.

### After a playtest round
1. List every observed problem (not solution) from your notes.
2. Sort by: how many testers hit it, and how much it blocked the core loop.
3. Fix the top 3–5. Retest.
4. Don't try to fix everything from one round before the next test — you'll chase your tail.
