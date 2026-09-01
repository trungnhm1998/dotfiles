# Audio Sourcing for Indie Games

## SFX Sources

### Free
| Source | URL | Notes |
|---|---|---|
| Freesound.org | freesound.org | Large library; check each file's license (CC0 safest for commercial) |
| Sonniss GDC Pack | sonniss.com/gameaudiogdc | Annual free release; royalty-free for commercial use |
| Kenney.nl | kenney.nl/assets | Simple, clean game SFX packs; CC0 |
| ZapSplat | zapsplat.com | Free tier with attribution; paid tier no attribution |

### Paid
| Source | URL | Notes |
|---|---|---|
| GameSounds.xyz | gamesounds.xyz | Indie-priced packs; royalty-free |
| Sonniss (full store) | sonniss.com | Professional library; lifetime license |
| A Sound Effect | asoundeffect.com | Curated packs, professional quality |
| Epidemic Sound | epidemicsound.com | Subscription; excellent for music |
| Artlist | artlist.io | Subscription; music + SFX; clean licensing |

**License check:** for commercial release, verify the license allows commercial use with no per-unit royalties. CC0 and "royalty-free commercial" are safe. CC BY requires attribution.

## Creating Your Own SFX

### Synth / Retro Tools
| Tool | Best for | Price |
|---|---|---|
| **BFXR** | 8-bit SFX (jumps, pickups, hits) | Free |
| **ChipTone** | Chiptune-style SFX with more control | Free |
| **sfxr** | Quick retro prototyping | Free |

**Tip:** For pixel art / retro-style games, generated synth SFX are entirely on-brand. For realistic or stylized 3D games, prefer recorded/layered sounds.

### DAW Recording / Processing
- **Audacity** (free) — record, clean, trim, export. Good for simple one-shot SFX.
- **Reaper** (affordable, ~$60 discounted) — full DAW with pro plugins; worth it for serious audio work.
- **GarageBand** (free on Mac) — good for quick music sketches.

**Foley technique:** Record real-world sounds with a phone mic or USB mic, then pitch/process them. Footsteps on gravel = actual gravel. UI clicks = tapping a hard surface. The source material often doesn't matter — the processing does.

## Music Options

### Stock / Subscription
- **Epidemic Sound** / **Artlist**: flat subscription, unlimited tracks, clean commercial license. Best value for solo devs.
- **incompetech.com** (Kevin MacLeod): free with attribution; recognizable but widely used.

### Composing Your Own
- **GarageBand / LMMS** (free) → learn basic composition if the music is simple/ambient.
- **Bandcamp**: hire an indie composer (cheaper than stock subscriptions for a single game).
- **Fiverr / UpWork**: hire game composers; give a reference track and style brief.

**Buy-vs-build for music:** Composing original music is a significant skill investment. Unless you're drawn to it, buy (subscription or commission) — audio is where solo devs most often underestimate scope.

## Asset Format Guidelines

| Use | Format | Notes |
|---|---|---|
| Short SFX | WAV (uncompressed) | Import in Unity; Unity compresses on platform |
| Long music / ambience | OGG / MP3 | Use **Streaming** load type in Unity |
| Voice-over | WAV | Higher quality source |

Unity compresses audio on import per platform (see `unity-audio-implementation.md`). Keep source files at full quality.
