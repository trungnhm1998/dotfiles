# Scope Heuristics for Solo Indie Dev

## Contents
1. Sizing to one dev
2. The fun-core test
3. Cut-lists and the "later" list
4. Hidden costs of a feature
5. Signs you're over-scoping

---

## 1. Sizing to One Dev

A realistic project for a solo dev has:
- **One core mechanic** that fits in a weekend prototype.
- **A total scope** you could describe in two sentences without hand-waving.
- **A content budget** you can produce alone (or know exactly what you'll outsource).

### Time-budget reality check
As a solo dev with a day job or part-time work, assume **10–15 focused hours per week** for your game. As full-time indie, assume **30–40 hours** (not 60 — you'll burn out).

| Scope target | Realistic calendar time (part-time) | Full-time |
|---|---|---|
| Jam game / micro game | 1–4 weeks | 1–2 weeks |
| Small finished game | 6–18 months | 3–9 months |
| Mid-size game (5–10h play) | 2–4+ years | 1–2+ years |
| "My dream RPG" | Never solo | Never solo |

### The "can I actually finish this?" test
Answer these honestly:
1. Can I describe every major system on one index card?
2. Have I built the core mechanic end-to-end, even ugly?
3. Do I know what "done" looks like — not "great", just done?
4. Would a stranger understand the game in 30 seconds?

If any answer is "not really", the scope is too vague or too big.

---

## 2. The Fun-Core Test

Every game has exactly one thing that must be fun for the game to work. Everything else is in service of that thing.

**Find it by asking:** If you stripped every feature except one loop — move, act, react — would it still feel good to do five times in a row?

Examples:
- Celeste: the jump feels good. Everything else is a reason to jump more.
- Into the Breach: one turn of combat is a satisfying puzzle. Everything else gives you more turns.
- Stardew Valley: the act of planting and harvesting is calming. Everything else extends the reason to do it.

**Your game has a fun core.** Name it in one sentence. If you can't, you don't know it yet — stop adding features and find it first.

**The test:** Play only your core loop for 10 minutes, ignoring everything broken. Is it intrinsically satisfying? If no: fix the core. If yes: protect it with your life.

---

## 3. Cut-Lists and the "Later" List

The goal is not to throw ideas away — it's to get them out of your head and out of the sprint.

### The "later" list
Keep a single `IDEAS.md` or Trello column called **Later**. When you have a feature idea:
1. Write it down with a one-line rationale.
2. Put it in Later.
3. Close the mental tab.

Rules:
- Anything in Later is a gift to future-you, not a commitment.
- Revisit it at each milestone. Most ideas won't survive contact with the actual game.
- Ideas that appear on the Later list three milestones in a row without being pulled forward can be cut permanently.

### The cut-list process (at each milestone review)
- List everything in scope for the next milestone.
- Ask of each item: "If I cut this, does the game stop being fun?" If no — move it to Later.
- Cut until the remaining list feels almost too small. Then cut one more thing.

The goal is a list you are **confident** you can finish, not a list you hope to finish.

---

## 4. Hidden Costs of a Feature

When you estimate a feature, the raw build time is the smallest cost.

| Cost type | Description |
|---|---|
| **Content** | Every mechanic needs content to populate it. Enemies need art, audio, data. |
| **Tuning** | New systems need numbers. Numbers need iteration. Iteration needs time. |
| **Bug surface** | Every system is a new failure mode. Complex interaction = exponential bug surface. |
| **Maintenance** | Systems you build in Month 2 will break when you add things in Month 8. |
| **QA / testing** | You have to test every feature on every change. Solo = you are QA. |
| **UX / onboarding** | Players need to understand the feature or it's invisible or frustrating. |
| **Scope drag** | Features attract features. An inventory system wants crafting. Crafting wants recipes. Recipes want a UI. |

**Rule of thumb:** A feature that feels like 2 days of coding often costs 1–2 weeks total when all hidden costs land.

Before adding: multiply your raw estimate by **3x** for a more honest number.

---

## 5. Signs You're Over-Scoping

Stop and reassess if you see these:

- **"Just one more system"** — you've said this three times this month.
- **Systems without content** — you have five mechanics but only one level.
- **Prototype has been "almost done" for two months.**
- **You're solving problems your players don't have yet** — polish before the core is fun.
- **Your design doc grew instead of shrank** since last milestone.
- **You're building tools to build the game** — engine work masquerading as game dev.
- **You can't describe the game to a stranger** in 30 seconds without it getting complicated.
- **The fun test fails** — you avoid playing your own prototype.
- **Energy is going into features, not into "is this fun?"**

When you hit three or more of these, call a scope review. Don't just push through — cutting now costs a day; cutting in six months costs a month.
