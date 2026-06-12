---
paths:
  - "**/*.cs"
---

# Unity / C# engineering conventions

## Architecture
- Prefer composition and plain C# services + ScriptableObjects over deep MonoBehaviour inheritance.
- Use assembly definitions; namespaces mirror folders; one type per file.
- Avoid deprecated Unity APIs (`OnGUI`, `WWW`, legacy `Input` manager) — prefer UI Toolkit / `UnityWebRequest` / the new Input System.

## Performance
- Flag per-frame heap allocations (LINQ/boxing/`string` concat/`Camera.main`/`GetComponent` in `Update`) and frame-budget costs.

## Testing
- Name unit tests **`UnitUnderTest_StateUnderTest_Expected`** (e.g. `Aggregate_WithNoModifiers_ReturnsBase`) — the method/type under test, the scenario, then the expected outcome; PascalCase segments joined by `_`.

## Editor discipline
- When creating a Unity scene, save it to disk immediately after creation and verify the import record before any scene switch or reimport — unsaved scenes + corrupted import records have silently eaten an hour before.
- Keep the Unity MCP bridge to its `core` tool group by default; activate extra groups (`testing`, `ui`, `profiling`, …) on demand via `manage_tools` and only for the task at hand.
