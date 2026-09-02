# Performance Checklist — Unity 6 / C#

## Table of Contents
1. [Per-Frame Allocation Offenders](#1-per-frame-allocation-offenders)
2. [Caching & References](#2-caching--references)
3. [Object Pooling](#3-object-pooling)
4. [Addressables Lifecycle](#4-addressables-lifecycle)
5. [Jobs & Burst](#5-jobs--burst)
6. [Profiling Workflow](#6-profiling-workflow)

---

## 1. Per-Frame Allocation Offenders

Each item below causes a managed heap allocation every frame, creating GC pressure that manifests as frame spikes.

### LINQ in Update
```csharp
// BAD — allocates an enumerator + intermediate collections every frame
void Update() {
    var closest = enemies.Where(e => e.IsAlive).OrderBy(e => distance(e)).First();
}

// GOOD — manual loop, zero allocation
void Update() {
    Enemy closest = null;
    float bestDist = float.MaxValue;
    foreach (var e in enemies) {
        if (!e.IsAlive) continue;
        float d = Vector3.Distance(transform.position, e.transform.position);
        if (d < bestDist) { bestDist = d; closest = e; }
    }
}
```

### Boxing
Occurs when a value type (int, float, struct, enum) is assigned to `object`, `interface`, or passed to a non-generic method:
```csharp
// BAD — boxes the int
object val = 42;
Debug.Log("Score: " + score); // also boxes if score is int

// GOOD — use string interpolation with pre-built strings or StringBuilder for hot paths
// For debug logs gated behind a flag, the boxing only happens when the condition is true
```

### String Concatenation / Interpolation
`string.Format`, `$"..."`, and `+` all allocate a new string object. For HUD that updates every frame, maintain a `StringBuilder` and only call `.ToString()` when the value actually changes.

### Capturing Lambdas / Closures
```csharp
// BAD — captures 'target', allocating a delegate object each call
void Update() {
    enemies.ForEach(e => e.MoveTo(target)); // new delegate each frame
}

// GOOD — cache the delegate as a field, or use a for loop
```

### Camera.main
`Camera.main` iterates all cameras every call. Cache it once:
```csharp
// BAD
void Update() { Ray r = Camera.main.ScreenPointToRay(Input.mousePosition); }

// GOOD — cache in Awake/Start
Camera _camera;
void Awake() { _camera = Camera.main; }
void Update() { Ray r = _camera.ScreenPointToRay(Input.mousePosition); }
```
Note: In Unity 6, `Camera.main` is slightly faster than earlier versions due to internal caching improvements, but it's still best practice to cache it yourself.

### GetComponent / Find in Loops
Both search scene/component data structures. Cache results in `Awake` or `Start`:
```csharp
// BAD
void Update() { GetComponent<Rigidbody>().AddForce(Vector3.up); }

// GOOD
Rigidbody _rb;
void Awake() { _rb = GetComponent<Rigidbody>(); }
void Update() { _rb.AddForce(Vector3.up); }
```

### new Arrays / Collections per Frame
```csharp
// BAD
void Update() {
    var hits = new RaycastHit[10]; // allocation every frame
    Physics.RaycastNonAlloc(ray, hits);
}

// GOOD — pre-allocate as a field
readonly RaycastHit[] _hits = new RaycastHit[10];
void Update() { Physics.RaycastNonAlloc(ray, _hits); }
```

### Uncached WaitForSeconds
```csharp
// BAD — new WaitForSeconds allocated every time the coroutine runs
IEnumerator FireLoop() {
    while (true) {
        yield return new WaitForSeconds(fireRate); // allocates
    }
}

// GOOD — cache once
WaitForSeconds _fireWait;
void Awake() { _fireWait = new WaitForSeconds(fireRate); }
IEnumerator FireLoop() {
    while (true) { yield return _fireWait; }
}
```
Also cache `WaitForFixedUpdate`, `WaitForEndOfFrame`.

---

## 2. Caching & References

**Fields to always cache (Awake/Start):**
- `GetComponent<T>()` results
- `Camera.main`
- `transform` (already cached by Unity internally, but caching locally is harmless and explicit)
- `GameObject.tag` comparisons → use `CompareTag()` instead of `== "Player"` (no allocation)
- `Input.GetAxis` strings — not allocating but `CompareTag` vs string == matters for tags

**Pattern: Lazy cache with null check**
```csharp
Animator _animator;
Animator Animator => _animator ??= GetComponent<Animator>();
```
Good for optional components; avoid in hot paths due to null-check overhead.

---

## 3. Object Pooling

**When to pool:**
- Objects frequently instantiated and destroyed at runtime: projectiles, particles (if not using the Particle System), VFX, enemies in waves, damage numbers.
- `Instantiate`/`Destroy` are expensive — they allocate managed objects, trigger `Awake`/`OnEnable`/`OnDestroy`, and cause GC spikes.

**Built-in pooling: `UnityEngine.Pool.ObjectPool<T>`** (available since Unity 2021 LTS, confirmed in Unity 6)

```csharp
using UnityEngine.Pool;

public class BulletSpawner : MonoBehaviour
{
    [SerializeField] Bullet bulletPrefab;
    ObjectPool<Bullet> _pool;

    void Awake()
    {
        _pool = new ObjectPool<Bullet>(
            createFunc:    () => Instantiate(bulletPrefab),
            actionOnGet:   b  => b.gameObject.SetActive(true),
            actionOnRelease: b => b.gameObject.SetActive(false),
            actionOnDestroy: b => Destroy(b.gameObject),
            collectionCheck: true,   // catches double-release in Editor
            defaultCapacity: 20,
            maxSize: 100
        );
    }

    public void Fire(Vector3 position, Vector3 direction)
    {
        var bullet = _pool.Get();
        bullet.transform.SetPositionAndRotation(position, Quaternion.LookRotation(direction));
        bullet.Initialize(_pool); // bullet calls _pool.Release(this) when done
    }
}
```

The `UnityEngine.Pool` namespace also provides `CollectionPool<TCollection, TItem>` for pooling `List<T>`, `HashSet<T>`, and `Dictionary<TKey, TValue>` — useful for temporary collections inside algorithms.

---

## 4. Addressables Lifecycle

**Load / release discipline:**
Every `Addressables.LoadAssetAsync<T>` call increments a reference count. The asset is unloaded only when `Addressables.Release(handle)` (or `Addressables.ReleaseAsset(obj)`) is called the same number of times.

```csharp
// Load
AsyncOperationHandle<GameObject> _handle;
async void LoadEnemy(string key)
{
    _handle = Addressables.LoadAssetAsync<GameObject>(key);
    await _handle.Task;
    Instantiate(_handle.Result);
}

// Release — call when done (scene unload, object destroyed)
void OnDestroy() {
    if (_handle.IsValid()) Addressables.Release(_handle);
}
```

**Avoiding leaks across scene loads:**
- Never hold handles in static fields without explicit cleanup.
- Use `Addressables.LoadSceneAsync` with `UnloadSceneOptions.UnloadAllEmbeddedSceneObjects` to clean up scene-local addresses.
- Group assets by their lifetime in the Addressables Groups window: one group per scene, one for shared/persistent assets.

**Instantiate shorthand (auto-tracks the handle internally):**
```csharp
var handle = Addressables.InstantiateAsync(key);
// Release with:
Addressables.ReleaseInstance(instance); // also destroys the GameObject
```

**Profile:** Use the Addressables Profiler (Window > Asset Management > Addressables > Profiler) to see reference counts live.

---

## 5. Jobs & Burst

**When Jobs/Burst is justified:**
- You have a measured hot path (from the Profiler) processing large arrays of data: thousands of agents, physics queries, spatial lookups, procedural mesh generation.
- `Update` on hundreds of MonoBehaviours can often be replaced by a single `IJobParallelFor`.

**When it's premature:**
- Your game has < ~500 entities being processed per frame.
- You haven't profiled and confirmed the bottleneck is CPU-bound gameplay code.

**Quick mental model:**
- `IJob` — single-threaded off the main thread.
- `IJobParallelFor` — work split across worker threads, each index must be independent.
- `[BurstCompile]` — converts HLSL-like safe C# (structs, NativeArrays, no managed refs) to optimized native code via LLVM. Add it to any job for a 10–100x speedup on math-heavy code.

```csharp
[BurstCompile]
struct MoveJob : IJobParallelFor
{
    public NativeArray<float3> positions;
    public NativeArray<float3> velocities;
    public float deltaTime;

    public void Execute(int i)
    {
        positions[i] += velocities[i] * deltaTime;
    }
}
```

**Rule:** Profile first. Only reach for Jobs/Burst when you have evidence of a CPU bottleneck that MonoBehaviour-based code cannot solve.

---

## 6. Profiling Workflow

**Tool chain:**
1. **Unity Profiler** (Window > Analysis > Profiler) — your first stop. Use it in Play mode to capture CPU/GPU/memory frames. Look at the CPU Usage module: identify which `Update`, coroutine, or render method is expensive.

2. **Deep Profile** — enables per-method allocation tracking. Warning: adds significant overhead, 3–10x slower than normal. Use it only to pinpoint an allocation source, then disable it for performance measurements.

3. **Memory Profiler package** (`com.unity.memoryprofiler`, version 1.1.x for Unity 6) — install via Package Manager. Opens at Window > Analysis > Memory Profiler. Lets you take memory snapshots, compare them between sessions, see managed heap fragmentation, and track which assets are loaded. Essential for finding leaks across scene loads.

4. **Frame Debugger** (Window > Analysis > Frame Debugger) — shows every draw call in a frame. Critical for diagnosing SRP Batcher breaks, overdraw, and unexpected render passes.

**Key workflow:**
1. Profile a representative gameplay scenario (not the Editor start screen).
2. Sort CPU samples by self-time to find the actual offender (not just the call site).
3. **Profile on target device** — PC Editor performance does not predict mobile or console behavior. Frame budget, GC behavior, and GPU limits differ drastically.
4. Fix the biggest offender, then re-profile. Don't micro-optimize before you've found the real bottleneck.
