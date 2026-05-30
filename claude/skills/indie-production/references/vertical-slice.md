# Vertical Slice

## Contents
1. What a vertical slice is
2. What it is NOT
3. Choosing the smallest slice
4. Exit criteria

---

## 1. What a Vertical Slice Is

A vertical slice is **one polished, end-to-end fragment of the real game** — not a prototype, not a tech demo. It is the core loop, fully connected, playable from start to finish of that fragment, at a quality level that represents the final game.

"Vertical" means it cuts through all layers of the game simultaneously:
- Gameplay mechanics (feel and rules)
- Level / encounter design (a real piece of content)
- Audio (at least temp/placeholder that conveys intent)
- UI (enough to play without confusion)
- Art direction (consistent, represents the target style)

The slice is short. It might be one level, one encounter, one dungeon floor, or one run of the core loop. Length is not the point. **Fidelity is.**

A player who plays the vertical slice should be able to answer: "I understand what this game is, and it feels good to play."

---

## 2. What It Is NOT

**Not a horizontal prototype.** A prototype goes wide and shallow — it proves mechanics exist. A vertical slice goes narrow and deep — it proves mechanics are fun at shipping quality.

**Not a tech demo.** Tech demos prove systems work. A vertical slice proves the game is enjoyable. Players do not care that your shader works.

**Not a demo of all features.** You do not need to show every mechanic in the slice. You need to show the core loop at real quality. Features outside the core loop do not belong in the slice.

**Not a first-pass on everything.** Putting placeholder art, un-tuned numbers, and rough audio into "the vertical slice" and calling it done is a lie you tell yourself. The slice should be the first thing in the game you would not be embarrassed to show.

**Not optional.** Without a vertical slice, you risk spending a year on systems that do not produce a fun game. The slice is your proof of concept for fun, not just feasibility.

---

## 3. Choosing the Smallest Slice

The goal is the shortest path to proving the core loop is fun at real quality.

**Step 1: Name the core loop in one sentence.**
Example: "The player jumps between platforms, attacks enemies, and reaches a goal."

**Step 2: Strip to the minimum encounter.**
What is the smallest set of content that lets a player experience that loop once, completely?
- One enemy type (not five)
- One environment / biome (not three)
- One path from start to end (not a branching map)
- One boss or challenge moment (optional — only if it's the core)

**Step 3: Define what "polished" means for this slice.**
Polished does not mean final. It means: the movement feels good, the encounter is designed (not random), the art is consistent (not mixed styles), and the audio supports the action (not silent).

**Step 4: Cut anything in the slice that is not proving the core loop.**
- Inventory system? Cut unless inventory IS the core loop.
- Dialogue / story? Cut unless story IS the core loop.
- Multiple mechanics? Cut to the one that defines the game's identity.

**Decision test:** If you removed this element from the slice, would you still be proving whether the core loop is fun? If yes — cut it from the slice (it can be in the full game later).

---

## 4. Exit Criteria

The vertical slice is done when ALL of the following are true:

**Playability**
- [ ] A stranger can pick it up and complete it without instructions from you.
- [ ] The session has a clear start, middle, and end.
- [ ] There are no crashes or game-breaking bugs.

**Feel / Fun**
- [ ] You have playtested it with at least 3 people who are not you.
- [ ] Players are doing the thing you intended (moving, fighting, exploring — whatever the core is) and showing signs of engagement (leaning in, trying again, commenting on what's happening).
- [ ] The core mechanic feels good in your hands for 10 minutes straight.

**Quality bar**
- [ ] Art direction is consistent throughout the slice (one style, no mixed prototypes).
- [ ] Audio exists and supports the action (can be temp — must not be missing or jarring).
- [ ] UI communicates what the player needs to know without you explaining it.

**Conviction**
- [ ] You can watch someone play it without wanting to explain or apologize.
- [ ] You want to keep making this game. (If the slice killed your enthusiasm, that is important data.)

**Do not move into full production until the vertical slice exits.** Entering production with an unproven core loop is the most expensive mistake in solo indie dev.
