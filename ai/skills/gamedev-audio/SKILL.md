---
name: gamedev-audio
description: Game audio sourcing, design, and Unity implementation for indie games. Use when sourcing or creating SFX or music, implementing audio in Unity (AudioSource, AudioMixer, snapshots, spatial audio), mixing, or adding adaptive/dynamic audio. Use proactively when a mechanic or scene lacks audio feedback or when audio feels flat.
---

# Gamedev Audio

Source, design, and implement game audio that serves the game feel. Present options with trade-offs, recommend; flag buy-vs-build decisions on middleware.

## Use the references
- Finding/creating SFX and music, licensing → `references/audio-sourcing.md`.
- Unity AudioSource, AudioMixer, groups, snapshots, spatial audio, compression → `references/unity-audio-implementation.md`.
- State-driven, layered, and randomized adaptive audio → `references/adaptive-audio.md`.

## Defaults
- Readable first: every audio event must communicate something to the player. Cut sounds that don't.
- Randomize pitch (±10%, e.g. `Random.Range(0.9f, 1.1f)`) and volume (±2–3 dB) on repeated SFX to prevent ear fatigue.
- Implement audio in an `AudioManager` service (plain C#), not scattered `AudioSource.PlayOneShot` calls across MonoBehaviours.
- Buy-vs-build: FMOD and Wwise are clear buy wins for complex adaptive audio on a commercial title; for simple indie games, Unity's built-in AudioMixer is sufficient.
