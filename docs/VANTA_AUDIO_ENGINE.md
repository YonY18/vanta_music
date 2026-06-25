# Vanta Audio Engine

Vanta Audio Engine is the incremental path toward a stronger open-source playback architecture while keeping Flutter, `audio_service`, and the current stable Android playback behavior intact.

## Quick path

1. Keep **Android Default / Current Engine** selected for production playback.
2. Use **Vanta Native Engine (Experimental)** only to exercise the native WAV playback foundation, including narrowly eligible local Android `content://` WAV sources.
3. If native loading fails or the source/format is unsupported, Vanta falls back to the current engine.

## Objective

The long-term goal is a player architecture conceptually closer to AIMP, Poweramp, or VLC: a clean app shell, explicit engine abstraction, native decoding/output room, and predictable source routing. The first slice is intentionally conservative. It creates the seam and native package skeleton without replacing proven playback.

## Current architecture

| Layer | Current decision |
|------|------------------|
| Flutter UI | Unchanged. The existing player screens and Audio Settings screen remain the entry points. |
| App playback owner | `VantaAudioHandler` remains the queue, session, background playback, notification, and MediaSession owner. |
| Default engine | `just_audio` + `audio_service` stays the stable default. |
| Engine seam | `VantaAudioEngine` defines `init`, `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, `dispose`, and state/position/duration streams. |
| Native package | `packages/vanta_audio_engine` provides a MethodChannel/EventChannel bridge, JNI entry points, CMake, and split native files. |

## Available engines

### Android Default / Current Engine

- Default selection.
- Uses the existing `just_audio` and `audio_service` path.
- Preserves local playback, Navidrome/Subsonic streaming, downloads, playlists, miniplayer, now playing, background playback, and notification controls.

### Vanta Native Engine (Experimental)

- Android-first experimental engine.
- Exposes Dart `NativeVantaAudioEngine`.
- Initializes and disposes through JNI.
- Validates local `file://` sources before calling the platform layer.
- Accepts narrowly eligible local Android `content://` WAV sources only when clear WAV evidence exists, then stages them through `ContentResolver` into app-private cache before native load.
- Limits staged `content://` WAV sources to 512 MiB and deletes stale app-private staged files on native bridge startup/init/load/dispose boundaries.
- Supports local `.wav` files through a vendored miniaudio single-header decoder/output backend.
- Implements native `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, and duration/position reads for prepared WAV files.
- Returns controlled `unsupported-format`, `file-not-found`, `content-open-failed`, `content-stage-failed`, `native-load-failed`, or `not-prepared` errors when the native path cannot proceed.
- Does **not** claim MP3, FLAC, OGG/Vorbis, Opus, remote, or Subsonic/Navidrome native playback support yet.

## Fallback rules

| Source or failure | Result |
|-------------------|--------|
| Current engine selected | Use current engine. |
| Remote HTTP/HTTPS stream | Use current engine; remote URLs are not sent to native. |
| Subsonic/Navidrome source | Use current engine through the existing resolver path. |
| Eligible local `content://` WAV source | Stage through Android `ContentResolver` into app-private cache, then pass only the staged filesystem path to native. |
| Non-WAV or ambiguous `content://` source | Use current engine; native format/source evidence is unsupported. |
| Local non-WAV file | Use current engine; native format is unsupported. |
| Missing local file | Controlled native error, then current-engine fallback. |
| Native load/playback error | Log the redacted error and continue through current engine. |

Logs use redacted labels for remote/content/Subsonic sources and avoid tokens, passwords, full remote URLs, full content URIs, and local filenames.

User-visible native failure notification is not implemented yet; current behavior is privacy-safe logging plus current-engine fallback.

WAV eligibility is validated in Dart app selection, Dart package preflight, and Kotlin `ContentResolver` metadata checks. This duplication is deliberate layered defense so unsupported or ambiguous sources fail closed before native code receives a path.

## Native package structure

```text
packages/vanta_audio_engine/
├── lib/src/native_vanta_audio_engine.dart
└── android/src/main/
    ├── kotlin/com/vantamusic/audioengine/VantaAudioEnginePlugin.kt
    └── cpp/
        ├── CMakeLists.txt
        └── native/
        ├── vanta_engine.cpp/.h
        ├── vanta_decoder.cpp/.h
        └── vanta_output.cpp/.h
```

## Native playback status

| Area | Status |
|------|--------|
| Backend | miniaudio single-header backend vendored under `android/src/main/cpp/native/miniaudio.h`. |
| Supported format | Local `.wav` files and narrowly eligible local Android `content://` WAV sources staged into app-private cache. |
| Native commands | `init`, `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, `dispose`. |
| Position/duration | Native duration is emitted after load; position is read on command boundaries. Continuous position polling is still pending. |
| App integration | The existing `just_audio`/`audio_service` path remains the playback owner and fallback path. Native readiness is attempted only for eligible original local WAV sources, including clear WAV `content://` sources. |
| Out of scope | MP3, FLAC, OGG/Vorbis, Opus, ReplayGain, gapless, crossfade, remote streams, and ambiguous/non-WAV `content://` sources. |

## Licensing decisions

- BASS is not used because it is proprietary and not ideal for an open-source-first player architecture.
- FFmpeg is avoided initially to keep licensing, binary size, and integration complexity low.
- miniaudio is vendored as a single-header dependency and is available under a choice of public domain or MIT No Attribution (MIT-0), as stated in the header license block.
- Reviewer note: `android/src/main/cpp/native/miniaudio.h` is vendored third-party source and should be excluded from app-authored review-line budgeting.
- Additional open-source building blocks remain under evaluation before adoption.

## Candidate libraries

| Area | Candidate | Notes |
|------|-----------|-------|
| Output/mixing | miniaudio | Adopted for the first local WAV backend. |
| Tags | TagLib | Mature metadata support candidate. |
| FLAC | libFLAC or miniaudio decoder path | Evaluate when native decode starts. |
| OGG/Vorbis/Opus | libogg, libvorbis, libopus | Evaluate per codec and license constraints. |

## Roadmap

1. Stabilize the Dart abstraction and current-engine fallback seam.
2. Keep Android bridge compile-safe with MethodChannel/EventChannel, JNI, and CMake.
3. Harden the minimal miniaudio-backed local WAV path with device-audible verification.
4. Add continuous native position streaming and completion handling.
5. Add user-visible native fallback notification through a safe app notification surface.
6. Add native support for streaming/buffered sources when the routing model is proven safe.
7. Add FLAC support.
8. Add OGG/Vorbis/Opus support.
9. Add ReplayGain parsing/application with explicit user control.
10. Add gapless playback and crossfade in the engine layer.
11. Add TagLib-backed metadata extraction where useful.
12. Deepen MediaSession integration while preserving notification and lockscreen behavior.
