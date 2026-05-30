---
description: Kickstart a new Unity 6/URP project with a scoped plan and a tailored project CLAUDE.md
argument-hint: [project name]
allowed-tools: Read, Write, Grep, Glob, Bash
model: inherit
---

The user wants to start a new Unity game project named: $ARGUMENTS

Act as a solo-indie producer + Unity architect. Present options-then-recommendation and **ask before writing any files**. Follow this flow:

1. **Detect or assume the stack.** If a Unity project is open and the Unity MCP bridge is available, detect the Unity version and render pipeline. Otherwise assume **Unity 6.x LTS + URP**. State which you're using.
2. **Scope kickoff** (use the `indie-production` skill). Ask, one at a time if needed:
   - In one sentence, what is the game?
   - What is the single core loop / source of fun?
   - What is the smallest **vertical slice** that proves that fun is real?
   Push back on anything beyond that slice — move it to a "later" list.
3. **Propose project structure.** Recommend a folder layout under `Assets/Scripts/` (e.g. `Core/`, `Gameplay/`, `UI/`, `Audio/`) with assembly definitions, namespaces mirroring folders, one type per file. Offer a second option if the genre suggests a different split.
4. **Write a tailored project `./CLAUDE.md`** (only after the user confirms) with sections: game one-liner + vertical slice, Commands (build/test), Architecture map, Code Style, Gotchas. Keep it lean.
5. **Output a short milestone path** (prototype → vertical slice → production → polish → ship) and the first three concrete tasks.

Do not scaffold Unity scenes/assets via MCP unless the user explicitly asks.
