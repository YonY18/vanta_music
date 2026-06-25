# Vanta Audio Engine

Vanta Audio Engine is the incremental path toward a stronger open-source playback architecture while keeping Flutter, `audio_service`, and the current stable Android playback behavior intact.

## Quick path

1. Keep **Android Default / Current Engine** selected for production playback.
2. Use **Vanta Native Engine (Experimental)** only to exercise the native WAV/FLAC playback foundation, including local Android `content://` sources validated by the platform layer.
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
- Lets original local Android `content://` sources reach the platform layer even when Dart lacks MIME/display-name evidence; Kotlin `ContentResolver` metadata remains authoritative before staging WAV/FLAC content into app-private cache.
- Limits staged `content://` audio sources to 512 MiB and deletes stale app-private staged files on native bridge startup/init/load/dispose boundaries.
- Supports local `.wav` and experimental local `.flac` files through a vendored miniaudio single-header decoder/output backend.
- Implements native `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, and duration/position reads for prepared WAV/FLAC files.
- Owns playback for native-ready items without also preparing that same item through `just_audio`; `just_audio` remains the fallback/current engine for unsupported, remote, and native-failed sources.
- Returns controlled `unsupported_format`, `file_not_found`, `content_open_failed`, `content_stage_failed`, `decode_error`, `output_error`, or `not_prepared` errors when the native path cannot proceed.
- Does **not** claim MP3, OGG/Vorbis, Opus, M4A/AAC, remote, or Subsonic/Navidrome native playback support yet.

## Native FLAC playback status

Local FLAC playback is now experimental on Android when **Vanta Native Engine (Experimental)** is selected. The implementation does not vendor upstream libFLAC directly. Instead, this slice uses miniaudio's bundled `dr_flac` decoder path because `miniaudio.h` is already present in the native package, includes FLAC decoding support by default, and avoids unsafe network fetching, unreviewed submodules, or a large new third-party vendoring step.

| Area | Status |
|------|--------|
| Decoder choice | miniaudio `ma_decoder` with bundled `dr_flac` for `.flac`; separate `vanta_flac_decoder.cpp/.h` wrapper keeps FLAC decoding isolated from output/device logic. |
| License | miniaudio is public domain or MIT No Attribution (MIT-0), as stated in the vendored header. `dr_flac` is bundled inside miniaudio under the same vendored source review note. |
| Local file FLAC | Experimental native attempt for existing local `.flac` files. |
| Android `content://` FLAC | Experimental native attempt for original local content sources; Kotlin validates FLAC MIME/display-name/path evidence and stages content to an app-private `.flac` cache file before C++ receives a filesystem path. |
| Metadata | Native decoder records sample rate, channels, total PCM frames, and duration when available. Original FLAC bits per sample is not surfaced by the current miniaudio path and remains unavailable in this slice. |
| Output | Existing miniaudio output device remains responsible for playback; decoder code only decodes PCM frames. |
| Automation | Dart selection/package contract and Kotlin staging behavior are testable. Device-audible native FLAC playback still requires manual Android verification. |

### Format support table

| Format/source | Android native experimental | iOS native | Fallback behavior |
|---------------|-----------------------------|------------|-------------------|
| Local WAV file | Yes | No | Current engine if native is not selected or native fails. |
| Local FLAC file | Yes, experimental | No | Current engine if native is not selected or native fails. |
| Android `content://` WAV | Yes, with safe private staging | No | Current engine if Kotlin validation, staging, or native load fails. |
| Android `content://` FLAC | Yes, experimental, with safe private staging | No | Current engine if Kotlin validation, staging, or native load fails. |
| MP3 | No | No | Current engine. |
| OGG/Vorbis | No | No | Current engine. |
| Opus | No | No | Current engine. |
| M4A/AAC | No | No | Current engine. |
| Remote HTTP/HTTPS | No | No | Current engine. |
| Navidrome/Subsonic | No | No | Existing resolver/current engine path. |

### Quick manual test guide

1. Build and install a debug Android APK.
2. In Audio Settings, select **Vanta Native Engine (Experimental)**.
3. Play a known-good local `.flac` file from local storage.
4. Verify playback starts, pause/resume works, stop resets position, and seek moves to the requested position.
5. Play MP3, OGG/Opus, M4A/AAC, remote, and Navidrome/Subsonic tracks to confirm they still use the current engine fallback.
6. Watch logs for `[VantaAudioEngine]` messages; they should use redacted source labels and controlled error codes without full paths, URIs, server URLs, or tokens.

## Fallback rules

| Source or failure | Result |
|-------------------|--------|
| Current engine selected | Use current engine. |
| Remote HTTP/HTTPS stream | Use current engine; remote URLs are not sent to native. |
| Subsonic/Navidrome source | Use current engine through the existing resolver path. |
| Original local Android `content://` source | Attempt platform validation; Kotlin stages supported WAV/FLAC through Android `ContentResolver` into app-private cache, then passes only the staged filesystem path to native. |
| Non-WAV/FLAC `content://` source | Controlled `unsupported_format` native error, then current-engine fallback. Explicit unsupported Dart MIME/display-name evidence may fail earlier before platform invocation. |
| Local non-WAV/FLAC file | Use current engine; native format is unsupported. |
| Missing local file | Controlled native error, then current-engine fallback. |
| Native load/playback error | Log the redacted error and continue through current engine. |

Logs use redacted labels for remote/content/Subsonic sources and avoid tokens, passwords, full remote URLs, full content URIs, and local filenames.

User-visible native failure notification is not implemented yet; current behavior is privacy-safe logging plus current-engine fallback.

Local file eligibility remains strict in Dart by `.wav`/`.flac` extension. Android `content://` eligibility is intentionally delegated to Kotlin when the original source is local/provider-local and the native experimental engine is selected, because many MediaStore URIs are opaque in Dart. Kotlin `ContentResolver` metadata checks decide whether the content can be staged as WAV/FLAC before native code receives a filesystem path.

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
            ├── vanta_flac_decoder.cpp/.h
            └── vanta_output.cpp/.h
```

## Native playback status

| Area | Status |
|------|--------|
| Backend | miniaudio single-header backend vendored under `android/src/main/cpp/native/miniaudio.h`. |
| Supported format | Local `.wav`/`.flac` files and original local Android `content://` WAV/FLAC sources staged into app-private cache after Kotlin validation. |
| Native commands | `init`, `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, `dispose`. |
| Position/duration/completion | Native duration is emitted after load; position is read on command boundaries; basic handler-level completion advances the queue and exposes terminal completed state at queue end. Continuous position polling and completion polish are still pending. |
| App integration | `VantaAudioHandler` remains the queue, MediaSession, notification, and fallback coordinator. Native-ready items are owned by Vanta Native Engine without duplicate `just_audio` preparation; unsupported or failed native attempts load through the current engine. |
| Out of scope | MP3, OGG/Vorbis, Opus, M4A/AAC, ReplayGain, gapless, crossfade, remote streams, and non-WAV/FLAC `content://` native playback. |

## Licensing decisions

- BASS is not used because it is proprietary and not ideal for an open-source-first player architecture.
- FFmpeg is avoided initially to keep licensing, binary size, and integration complexity low.
- miniaudio is vendored as a single-header dependency and is available under a choice of public domain or MIT No Attribution (MIT-0), as stated in the header license block. This slice uses miniaudio's bundled `dr_flac` decoder path for experimental FLAC rather than adding upstream libFLAC.
- Reviewer note: `android/src/main/cpp/native/miniaudio.h` is vendored third-party source and should be excluded from app-authored review-line budgeting.
- Additional open-source building blocks remain under evaluation before adoption.

## Candidate libraries

| Area | Candidate | Notes |
|------|-----------|-------|
| Output/mixing | miniaudio | Adopted for the first local WAV backend. |
| Tags | TagLib | Mature metadata support candidate. |
| FLAC | miniaudio bundled `dr_flac` path | Adopted for the experimental local FLAC slice; upstream libFLAC remains a possible future replacement if vendored deliberately. |
| OGG/Vorbis/Opus | libogg, libvorbis, libopus | Evaluate per codec and license constraints. |

## Roadmap

1. Stabilize the Dart abstraction and current-engine fallback seam.
2. Keep Android bridge compile-safe with MethodChannel/EventChannel, JNI, and CMake.
3. Harden the minimal miniaudio-backed local WAV path with device-audible verification.
4. Add continuous native position streaming and polish completion handling beyond the basic handler-level completion path.
5. Add user-visible native fallback notification through a safe app notification surface.
6. Add native support for streaming/buffered sources when the routing model is proven safe.
7. Harden experimental FLAC support with device-audible verification and completion polish.
8. Add OGG/Vorbis/Opus support.
9. Add ReplayGain parsing/application with explicit user control.
10. Add gapless playback and crossfade in the engine layer.
11. Add TagLib-backed metadata extraction where useful.
12. Deepen MediaSession integration while preserving notification and lockscreen behavior.
