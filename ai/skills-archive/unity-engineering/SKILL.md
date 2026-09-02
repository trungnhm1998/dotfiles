---
name: unity-engineering
description: Unity 6 / URP architecture and C# performance guidance for gameplay code. Use when structuring systems or managers, deciding MonoBehaviour vs plain C# service, designing ScriptableObject or event/messaging patterns, choosing dependency injection, or addressing GC/allocations, frame budget, object pooling, Addressables, or profiling. Use proactively before building a sizable new system or when judging whether code is performant.
---

# Unity Engineering

Apply Unity 6 / URP architecture and performance best practices to gameplay code. Present options with trade-offs, then recommend (see global CLAUDE.md voice), and teach the principle.

## Use the references
- **Architecture** (system structure, MonoBehaviour vs service, ScriptableObjects, events, DI, bootstrap, asmdefs) → read `references/architecture-patterns.md`.
- **Performance** (GC/allocations, frame budget, pooling, Addressables, Jobs/Burst, profiling) → read `references/performance-checklist.md`.
- **URP specifics** (SRP Batcher, GPU instancing, Renderer Features, 2D vs 3D setup) → read `references/urp-notes.md`.

## Defaults
- Composition over deep inheritance; one responsibility per type; subscribe in `OnEnable`, unsubscribe in `OnDisable`/`OnDestroy`.
- Treat `Update`/`FixedUpdate`/`LateUpdate` and coroutines as hot paths — no per-frame allocations.
- Verify any uncertain Unity/package API against context7 before asserting it.
