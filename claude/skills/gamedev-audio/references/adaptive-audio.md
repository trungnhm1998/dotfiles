# Adaptive Audio for Unity

Adaptive audio responds to game state — tension, health, environment — to make the audio dynamic.

## State-Driven Music (Snapshot Transitions)

The simplest adaptive music: transition between Snapshots based on game state.

```csharp
public enum MusicState { Exploration, Combat, Victory, Danger }

public class MusicController
{
    readonly Dictionary<MusicState, AudioMixerSnapshot> _snapshots;

    public MusicController(Dictionary<MusicState, AudioMixerSnapshot> snapshots)
        => _snapshots = snapshots;

    public void SetState(MusicState state, float transitionTime = 0.5f)
        => _snapshots[state].TransitionTo(transitionTime);
}
```

Wire snapshot references from the Inspector (via a ScriptableObject or MonoBehaviour wrapper).

## Layered Music (Horizontal Re-Sequencing)

Play multiple AudioSources simultaneously (same BPM, same length, synced start). Enable/disable layers to change musical intensity without breaking continuity.

```csharp
public class LayeredMusicPlayer
{
    readonly AudioSource[] _layers;

    public LayeredMusicPlayer(AudioSource[] layers) => _layers = layers;

    public void StartAll()
    {
        double startDSP = AudioSettings.dspTime + 0.1;
        foreach (var src in _layers)
            src.PlayScheduled(startDSP);   // bit-perfect sync via DSP clock
    }

    public void SetLayerActive(int index, bool active)
        => _layers[index].volume = active ? 1f : 0f;  // volume=0 keeps the voice slot occupied; use Pause() to free it
}
```

**Key**: use `AudioSource.PlayScheduled(dspTime)` for sample-accurate sync. All clips must be the same length (or multiples) in bars. A loop of exactly 44100 × 4 bars at 120 BPM works reliably.

## Randomizing SFX Variation

Don't play the same clip every time. Use a variant pool:

```csharp
public class SFXVariantPool
{
    readonly AudioClip[] _clips;
    int _lastIndex = -1;

    public SFXVariantPool(AudioClip[] clips) => _clips = clips;

    public AudioClip Pick()
    {
        if (_clips.Length == 1) return _clips[0];
        int idx;
        do { idx = Random.Range(0, _clips.Length); } while (idx == _lastIndex);
        _lastIndex = idx;
        return _clips[idx];
    }
}
```

Combine with pitch/volume randomization (`unity-audio-implementation.md`) for maximum variation.

## Ambient Soundscape Zones

Use Unity trigger volumes to cross-fade ambient loops:

```csharp
// CrossFadeZone: attach this MonoBehaviour to trigger volumes in the scene.
// Set _targetAmbient in the Inspector; wire _currentAmbient from AudioManager at runtime.
public class CrossFadeZone : MonoBehaviour
{
    [SerializeField] AudioSource _targetAmbient;
    AudioSource _currentAmbient;

    public void SetCurrentAmbient(AudioSource current) => _currentAmbient = current;

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player") && _currentAmbient != null)
            StartCoroutine(CrossFadeTo(_targetAmbient, 2f));
    }

    IEnumerator CrossFadeTo(AudioSource next, float duration)
    {
        next.volume = 0f;
        next.Play();
        float elapsed = 0f;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float t = elapsed / duration;
            _currentAmbient.volume = 1f - t;
            next.volume = t;
            yield return null;
        }
        _currentAmbient.Stop();
        _currentAmbient = next;
    }
}
```

## FMOD / Wwise (Middleware)

| Tool | Use when |
|---|---|
| **FMOD Studio** | Complex adaptive audio, many states, non-linear sequencing. Free up to ~$200k revenue (check current terms). |
| **Wwise** | Larger teams, licensed console targets. More complex setup. |
| **Unity built-in** | Simple indie games. Snapshots + layered AudioSources cover 80% of cases. |

**Recommendation:** Ship with Unity built-in audio first. Migrate to FMOD if you need: beat-synchronized branching, adaptive stems, or per-platform audio behavior you can't express with Snapshots. The migration path exists but takes effort — plan it as a deliberate task, not a hotfix.

## Common Mistakes

- **AudioSources on destroyed GameObjects**: always `Stop()` and null-check before `Destroy`.
- **Too many simultaneous AudioSources**: Unity limits real voices (default 32 on standalone; lower on mobile — check Project Settings → Audio → Real Voice Count). Excess clips are dropped. Pool and re-use AudioSources.
- **Music on a world-space AudioSource**: music should be on a non-spatialized source (Spatial Blend = 0) or the AudioListener won't move away from it.
- **Volume in linear, not dB**: the AudioMixer works in dB. Use `Mathf.Log10(linear) * 20` to convert.
