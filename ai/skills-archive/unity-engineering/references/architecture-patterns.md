# Architecture Patterns — Unity 6 / C#

## Table of Contents
1. [Composition over Inheritance](#1-composition-over-inheritance)
2. [Plain C# Services vs MonoBehaviours](#2-plain-c-services-vs-monobehaviours)
3. [ScriptableObject Patterns](#3-scriptableobject-patterns)
4. [Event & Messaging Patterns](#4-event--messaging-patterns)
5. [Dependency Injection Options](#5-dependency-injection-options)
6. [Scene & Bootstrap Structure](#6-scene--bootstrap-structure)
7. [Assembly Definitions](#7-assembly-definitions)

---

## 1. Composition over Inheritance

**The problem with deep MonoBehaviour hierarchies:**
- `Enemy : LivingThing : DamageableActor : MonoBehaviour` creates tight coupling — changing a base class ripples everywhere.
- Unity's component system already *is* a composition model; fighting it with inheritance doubles the pain.
- Deep hierarchies hide state: debugging requires tracing up multiple classes.

**Prefer instead:**
- Small, single-purpose components: `HealthComponent`, `MovementComponent`, `WeaponComponent`.
- Plain C# classes for logic that doesn't need `Transform` or Unity lifecycle (`DamageCalculator`, `StatBlock`).
- Communicate between components via events or direct references (injected at startup, not `GetComponent` every frame).

```csharp
// Bad: deep hierarchy
public class Boss : Enemy : Character : MonoBehaviour { ... }

// Good: composed from small pieces
public class Boss : MonoBehaviour
{
    [SerializeField] HealthComponent health;
    [SerializeField] MovementComponent movement;
    [SerializeField] AttackPattern attackPattern; // plain C# ScriptableObject
}
```

**Principle:** A MonoBehaviour should be a thin orchestrator; the bulk of logic lives in plain C# types it holds references to.

---

## 2. Plain C# Services vs MonoBehaviours

| | **MonoBehaviour** | **Plain C# Service** |
|---|---|---|
| Needs `Transform`/physics | Yes | No |
| Needs Unity lifecycle (`Update`, coroutines) | Yes | No (use explicit `Tick()` or async) |
| Serialized in Inspector | Easy | Requires wrapper SO or custom editor |
| Testable without Unity runtime | No | Yes |
| GC pressure | Higher (engine overhead) | Lower |

**Rule of thumb:** If it doesn't need to live in the scene hierarchy or interact with Unity's physics/rendering pipeline directly, make it a plain C# class.

**Composition root / bootstrap pattern:**
Create a single `GameBootstrap : MonoBehaviour` that lives in the bootstrap scene and instantiates/wires all services:

```csharp
public class GameBootstrap : MonoBehaviour
{
    [SerializeField] AudioSettingsSO audioSettings;

    void Awake()
    {
        // Plain C# services constructed and wired here
        var saveSystem = new SaveSystem();
        var audioService = new AudioService(audioSettings);
        var gameState = new GameStateService(saveSystem);

        // Register to a service locator or inject into scene objects
        ServiceLocator.Register(audioService);
        ServiceLocator.Register(gameState);
    }
}
```

**Init ordering:** Awake > OnEnable > Start within the same frame. Use `[DefaultExecutionOrder(-100)]` on your bootstrap to guarantee it runs before scene objects.

---

## 3. ScriptableObject Patterns

### Config/Data Objects
The most straightforward use: author data in the Inspector, reference it from MonoBehaviours.

```csharp
[CreateAssetMenu(menuName = "Config/EnemyStats")]
public class EnemyStatsSO : ScriptableObject
{
    public float maxHealth;
    public float moveSpeed;
    public float attackCooldown;
}
```

**Pros:** Live-editable, no prefab duplication, hot-reloadable in Editor.

### ScriptableObject as Event Channel
An `EventChannelSO` decouples sender from receiver without both needing a reference to each other.

```csharp
[CreateAssetMenu(menuName = "Events/GameEvent")]
public class GameEventSO : ScriptableObject
{
    readonly List<Action> listeners = new();
    public void Raise() { foreach (var l in listeners) l?.Invoke(); }
    public void Subscribe(Action listener) => listeners.Add(listener);
    public void Unsubscribe(Action listener) => listeners.Remove(listener);
}
```

Use a generic variant `GameEventSO<T>` for typed payloads.

### Runtime Set
A SO that tracks a collection of alive objects (e.g., all enemies currently in scene):

```csharp
[CreateAssetMenu(menuName = "Sets/EnemyRuntimeSet")]
public class EnemyRuntimeSetSO : ScriptableObject
{
    public readonly List<EnemyBehaviour> Items = new();
    public void Register(EnemyBehaviour e) => Items.Add(e);
    public void Unregister(EnemyBehaviour e) => Items.Remove(e);
}
```

**Pitfalls:**
- SOs are assets — their state persists between Play sessions in the Editor. Always reset runtime state in `OnEnable` or have an explicit `Reset()`.
- Shared mutable state in SOs is a footgun: two systems writing to the same SO field without coordination causes subtle bugs. Treat data SOs as read-only at runtime; reserve mutable SOs for explicit runtime-set or event patterns.

---

## 4. Event & Messaging Patterns

| Pattern | Coupling | Serializable | Overhead | Best For |
|---|---|---|---|---|
| C# `event`/`Action` | Low (compile-time type) | No | Minimal | Same-assembly, code-only wiring |
| `UnityEvent` | Low | Yes (Inspector) | Moderate (reflection) | Designer-wired hooks, small subscriber counts |
| SO Event Channel | Very low (asset ref) | Yes (drag-and-drop) | Low | Cross-scene, cross-system events |
| Minimal Event Bus | None | No | Low–Medium | Fire-and-forget, string or enum keyed |

**C# event/Action** — fastest, but both sides must have a compile-time reference:
```csharp
public event Action<int> OnHealthChanged;
// subscribe: health.OnHealthChanged += HandleHealthChange;
// always unsubscribe in OnDisable/OnDestroy
```

**UnityEvent** — useful for designers but avoid for hot-path events (reflection overhead).

**SO Event Channel** — recommended for cross-scene communication (e.g., player death triggering UI in a different scene loaded additively). See Section 3.

**Minimal Event Bus** — use for truly global, anonymous events. Keep it typed (use an enum or strongly-typed key) to avoid stringly-typed bugs:
```csharp
public static class GameEvents
{
    public static event Action OnLevelComplete;
    public static event Action<EnemyBehaviour> OnEnemyKilled;
    // ...
}
```

**Recommendation for a solo dev:** Start with C# `event`/`Action` for most things. Reach for SO event channels when you need cross-scene decoupling. Avoid `UnityEvent` in hot paths.

---

## 5. Dependency Injection Options

### Option A: Manual / Composition Root
Wire dependencies explicitly in `Awake()` in a bootstrap MonoBehaviour. Zero external packages.

**Pros:** No learning curve, zero overhead, you control everything.
**Cons:** Wiring gets verbose as the project grows; no auto-resolution.

**Recommendation: start here** for a solo dev with a small-to-mid project.

### Option B: VContainer
A modern, actively maintained DI container for Unity. GC-free after initial resolve. Uses a `LifetimeScope : MonoBehaviour` as the container root.

```csharp
public class GameLifetimeScope : LifetimeScope
{
    protected override void Configure(IContainerBuilder builder)
    {
        builder.Register<AudioService>(Lifetime.Singleton);
        builder.Register<SaveSystem>(Lifetime.Singleton);
        builder.RegisterComponentInHierarchy<PlayerBehaviour>();
    }
}
```

Install via Package Manager: `https://github.com/hadashiA/VContainer.git?path=VContainer/Assets/VContainer#1.x` or via OpenUPM.

**Pros:** Fast, minimal allocation, supports child LifetimeScopes for scene-level containers, Unity 6 compatible, actively developed.
**Cons:** Some upfront learning; adds a package dependency.

### Option C: Zenject (Extenject)
Older, more feature-rich DI framework. Last major release was 2020 — maintenance mode, not actively developed. Still functional but VContainer is the better choice for new Unity 6 projects.

**Recommendation:** Manual wiring for small/early projects. Migrate to VContainer when the service graph gets complex enough to warrant it (typically 8+ services with non-trivial dependencies). Avoid Zenject for new projects.

---

## 6. Scene & Bootstrap Structure

**Pattern: Single bootstrap scene + additive loading**

```
Scenes/
  Bootstrap        ← always loaded first; contains GameBootstrap, DontDestroyOnLoad services
  MainMenu         ← loaded additively
  Gameplay         ← loaded additively
  UI               ← loaded additively (persistent HUD)
```

- `Bootstrap` scene is the entry point in Build Settings (index 0).
- Services created in `Awake()` on `GameBootstrap` call `DontDestroyOnLoad` on their GameObject wrappers (or are plain C# and live in memory).
- Subsequent scenes loaded via `SceneManager.LoadSceneAsync(name, LoadSceneMode.Additive)`.

**Init ordering discipline:**
1. Bootstrap `Awake` → create all services, register to service locator or inject.
2. Scene `Awake` → scene-local objects acquire services (via locator, injection, or serialized SO refs).
3. Scene `Start` → all cross-scene wiring is complete, begin gameplay.

**Gotcha:** If you use Addressables for scenes, the bootstrap scene itself should remain a regular Build Settings scene so it's always available before the Addressables runtime is initialized.

---

## 7. Assembly Definitions

**Why:** Without asmdefs, every C# change triggers a full recompile of all scripts. With asmdefs, Unity only recompiles the affected assembly and its dependents — dramatically faster iteration for mid-to-large projects.

**Sensible layout:**

```
Assembly                  | Depends On
--------------------------|----------------------------------
Game.Core                 | (nothing — pure logic, no Unity)
Game.Gameplay             | Game.Core, Unity engine assemblies
Game.UI                   | Game.Core, Game.Gameplay
Game.Editor               | Game.Core (Editor only flag)
Tests                     | Game.Core, NUnit
```

**Rules:**
- `Game.Core` should have zero Unity dependencies if possible (enables pure C# unit testing).
- Editor-only code (`[CustomEditor]`, etc.) belongs in an assembly with "Editor" platforms only checked.
- Avoid circular references — Unity will hard-error. Design the dependency graph top-down.

**Gotchas:**
- Third-party packages in `Assets/` need their own asmdefs or an explicit reference in your asmdef. Packages in `Packages/` (Package Manager) expose their asmdef automatically.
- Adding an asmdef to an existing folder moves all scripts in that folder to the new assembly. Check for missing references after adding.
- `[assembly: InternalsVisibleTo("Tests")]` works across asmdefs for test access to internal types.
