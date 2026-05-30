# Buy vs Build Rubric

## Contents
1. Decision factors
2. Scoring rubric
3. Default toward build — with clear buy-win signals
4. Asset Store cautions

---

## 1. Decision Factors

Evaluate each factor for the specific thing you're considering buying vs building.

**Time saved**
How many hours would it realistically take you to build this to the same quality? Compare to: the asset cost + integration time + learning-the-asset time. Time saved is only real if you actually use those hours on something that moves the game forward.

**Control and quality fit**
Does the asset do exactly what your game needs, or will you be fighting it to fit your design? Assets built generically often need significant modification to feel right in a specific game. If you'll spend 40% of the "saved" time hacking the asset to fit, you may not save much.

**Cost**
For a solo indie dev targeting commercial release: asset cost matters but is rarely the deciding factor for tools and utilities. It matters more for art packs, where the per-asset quality vs making-it-yourself trade-off is starker.

**Learning value**
Some systems are worth building yourself because understanding them makes you a better developer (pathfinding, save systems, simple state machines). Some are pure commodity (icon packs, font licenses, audio middleware). Weight learning value toward build for things central to your game's systems.

**Lock-in and maintenance**
If the asset is abandoned by its publisher, what happens? Can you fork and maintain it? Is it built on a supported Unity version/package? Extensions or tools that hook deep into Unity's pipeline carry higher lock-in risk than self-contained gameplay libraries.

**Licensing for commercial release**
See section 4.

---

## 2. Scoring Rubric

Score each factor 1–3 where higher = favors BUY.

| Factor | 1 (Build) | 2 (Neutral) | 3 (Buy) |
|---|---|---|---|
| Time saved | < 1 week | 1–3 weeks | 3+ weeks |
| Quality fit | Needs heavy modification | Minor tweaks | Fits as-is |
| Cost | High relative to budget | Moderate | Low / free |
| Learning value | Core to my game's identity | Adjacent | Commodity work |
| Lock-in risk | Deep engine integration, no source | Has source, maintainable | Lightweight, swappable |
| Licensing | Unclear or restricted | Standard EULA verified | Standard EULA verified |

**Interpretation:**
- 6–9 points: Default to Build.
- 10–14 points: Worth a closer look — check the specific asset quality and reviews.
- 15–18 points: Strong buy signal. Verify licensing before purchasing.

This rubric is a conversation-starter, not a calculator. Use it to surface the real trade-offs, then decide.

---

## 3. Default Toward Build, With Clear Buy-Win Signals

You lean toward building — that is a reasonable default for a developer who wants to understand their own game. Building core systems yourself means you can debug them, modify them, and they fit your architecture.

**When build is clearly right:**
- The system is the core mechanic or closely coupled to it.
- You want to understand it deeply for design tuning reasons.
- The asset would need more than ~30% modification to fit your needs.
- The asset has poor reviews, is old/unmaintained, or has licensing ambiguity.

**Clear buy-win signals — flag these:**

**Commodity work.** Art you will never produce at acceptable quality solo (complex character rigs, professional music/SFX, icon/UI packs). This is not your game's differentiator — buying frees you for what is.

**Far outside your current skill and time budget.** If an asset represents a domain that would take you 3–6+ months to reach competence in (advanced VFX, complex shaders, audio DSP), and it does not sit at the core of your game's identity, the buy case is strong.

**Time-critical path.** If you're blocked on something and it's gating the vertical slice or a key milestone, a good asset that unblocks you may be worth the trade-off. You can always replace it later.

**The honest question:** "Will building this make my game more fun, or will it just make me feel productive?" If the answer is the latter, the rubric probably points to Buy.

---

## 4. Asset Store Cautions

### Licensing for commercial use (verified against Unity Asset Store EULA FAQ, May 2026)

**Commercial use is permitted** for standard Asset Store purchases, including free assets, provided the asset is embedded and integrated into your game as a product — not sold or redistributed as a standalone asset.

**License types:**
- **Single Entity license:** Covers you as an individual, or your entire team if everyone works for the same legal entity. Correct for a solo indie developer.
- **Multi-Entity license:** Required if you use independent contractors or collaborators from outside your legal entity who need to access or modify the asset in development.
- **Extension license:** Some assets use this model — it requires a seat per developer who installs or uses the asset, managed via Unity's Cloud Dashboard. Check the asset's listing for its license type before purchasing.

**Key restrictions:**
- Assets cannot be resold or redistributed as standalone items.
- Your shipped game must contain "substantial original creative work" beyond the asset — the asset cannot be the majority of what the player is buying.
- If your game allows players to extract or download assets separately (e.g., a modding system that exposes raw assets), standard EULA does not cover this — you need explicit publisher permission.

**Recommendation:** Before purchasing any asset for a commercial project, check: (1) the license type on the asset's listing page, (2) whether the publisher has any additional terms, and (3) whether the asset's EULA has been updated recently (Unity updated and clarified their Asset Store terms effective August 2025).

### Dependency rot
Unity evolves. Assets that haven't been updated in 2+ years may not compile cleanly on Unity 6 / current URP. Check:
- Last updated date on the listing.
- The publisher's response history to issues/reviews.
- Whether the asset uses deprecated Unity APIs (check reviews for Unity version complaints).

Favor assets with recent updates and responsive publishers. An abandoned asset you can't compile is worth nothing.

### "Asset flip" feel
Players recognize recycled asset packs — especially audio, environments, and UI. This is not a moral judgment; it's a practical one. Games built entirely from common asset packs look generic and are harder to market.

**Practical guidance:**
- Build or commission the visual and audio elements that define your game's identity. These are your differentiators.
- Buy utility and commodity work freely: shaders, tools, editors, SFX packs (modified), font licenses.
- If you use an art pack as a starting point, commit to customizing and stylizing it significantly before shipping.
