# Unity Audio Implementation

## Core Components

**AudioSource** — plays audio clips on a GameObject. Key settings:
- `PlayOneShot(clip)` — fire-and-forget; multiple overlapping playbacks OK.
- `Play()` — plays the assigned clip; calling it again restarts it.
- `loop` — loop the clip.
- **Spatial Blend**: 0 = 2D (UI, music), 1 = 3D (world-space, attenuates with distance).

**AudioListener** — typically on the Camera or player GameObject. Only one active at a time.

**AudioClip** — the imported audio asset. Import settings matter (see below).

## AudioMixer

The AudioMixer routes audio through named **Groups** and applies effects/volume per group.

**Setup:**
1. Create: **Assets → Create → Audio Mixer**.
2. Default structure: Master → SFX, Master → Music, Master → UI.
3. Assign AudioSources to groups: `AudioSource.outputAudioMixerGroup = sfxGroup`.

**Exposed parameters** — right-click a group's Volume fader → Expose → rename (e.g. `MasterVolume`). Set in code:
```csharp
audioMixer.SetFloat("MasterVolume", Mathf.Log10(value) * 20); // linear → dB
audioMixer.GetFloat("MasterVolume", out float db);
```

**Effects per group:** Add a Compressor, EQ, Reverb Zone Mix, etc. on individual groups (not Master, unless intentional).

## Snapshots

Snapshots capture the full AudioMixer state (all group volumes + effect settings).

**Use case:** Pause menu (muffle music, lower SFX), underwater (low-pass filter on all), boss fight (boost music, compress SFX).

```csharp
[SerializeField] AudioMixerSnapshot _normalSnapshot;
[SerializeField] AudioMixerSnapshot _pausedSnapshot;

void OnPause() => _pausedSnapshot.TransitionTo(0.3f);   // 0.3s blend
void OnResume() => _normalSnapshot.TransitionTo(0.15f);
```

Create additional snapshots in the AudioMixer window: click **Snapshots** → the `+` button.

## AudioManager Pattern

Centralize audio playback in a plain C# service to avoid scattered `AudioSource.PlayOneShot` calls:

```csharp
public class AudioManager
{
    readonly AudioSource _sfxSource;
    readonly AudioSource _musicSource;
    readonly AudioMixer  _mixer;

    public AudioManager(AudioSource sfx, AudioSource music, AudioMixer mixer)
    {
        _sfxSource   = sfx;
        _musicSource = music;
        _mixer       = mixer;
    }

    public void PlaySFX(AudioClip clip, float volume = 1f)
        => _sfxSource.PlayOneShot(clip, volume);

    public void PlayMusic(AudioClip clip)
    {
        _musicSource.clip = clip;
        _musicSource.Play();
    }

    public void SetMasterVolume(float linear)   // 0–1
        => _mixer.SetFloat("MasterVolume", Mathf.Log10(Mathf.Max(linear, 0.0001f)) * 20);
}
```

Wire this up from your Bootstrap/composition root; inject into systems via constructor or a service locator.

## Spatial Audio (3D Sound)

On an AudioSource:
- **Spatial Blend** = 1 (full 3D).
- **3D Sound Settings**: set **Min Distance** (full volume) and **Max Distance** (silence).
- **Volume Rolloff**: Logarithmic (realistic), Linear (predictable), Custom (curve).

For moving audio emitters (enemy shots, moving vehicles): place the AudioSource on the moving GameObject; it follows automatically.

**Audio Listener** should be on the camera or player — keep only one active.

## Import Settings (Compression)

Select an audio clip → Inspector:

| Setting | Value | Notes |
|---|---|---|
| Load Type | **Decompress on Load** | Short SFX (< 1s); fast playback, RAM cost |
| Load Type | **Compressed in Memory** | Medium SFX (1–10s); balanced |
| Load Type | **Streaming** | Music / long ambience; minimal RAM, slight CPU |
| Compression Format | **Vorbis** (OGG) | Best quality/size ratio |
| Quality | 70–100 | Lower = smaller file; < 70 audible artifacts |
| Sample Rate Setting | Preserve Sample Rate | Don't downsample unless size is critical |

**Platform overrides** (iOS/Android): use ADPCM or MP3 if Vorbis CPU cost is an issue on mobile.

## Pitch / Volume Randomization

```csharp
public void PlaySFXRandomized(AudioClip clip)
{
    // Note: setting pitch/volume on the source affects ALL currently-playing PlayOneShot sounds
    // that share this source. For overlapping one-shots this is acceptable as a quick variation
    // hack; for precise per-shot randomization, pool a separate AudioSource per call.
    _sfxSource.pitch  = Random.Range(0.9f, 1.1f);
    _sfxSource.volume = Random.Range(0.85f, 1.0f);
    _sfxSource.PlayOneShot(clip);
}
```

Apply this to any SFX that plays repeatedly (footsteps, weapon fire, UI clicks).
