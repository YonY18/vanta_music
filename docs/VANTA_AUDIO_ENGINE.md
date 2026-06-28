# Vanta Audio Engine

Vanta Audio Engine is the incremental path toward a stronger open-source playback architecture while keeping Flutter, `audio_service`, and the current stable Android playback behavior intact.

## Quick path

1. Keep **Android Default / Current Engine** selected for production playback.
2. Use **Vanta Native Engine (Experimental)** only to exercise the native WAV/FLAC/MP3 playback foundation, including local Android `content://` WAV/FLAC sources validated by the platform layer, native position/duration events, and seek/completion behavior.
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
- Supports local `.wav`, experimental local `.flac`, and experimental local `.mp3` files through a vendored miniaudio single-header decoder/output backend.
- Keeps the native output device open across compatible native-to-native local WAV/FLAC/MP3 loads when sample rate, channel count, and PCM format match. This is an experimental output lifecycle optimization only; it is not full gapless playback, preloading, or crossfade.
- Implements native `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, and duration/position reads for prepared WAV/FLAC/MP3 files.
- Emits native state, duration, and periodic position events through EventChannels; the app handler forwards those while the native engine owns playback.
- Owns playback for native-ready items, including restored startup/session items, without also preparing that same item through `just_audio`; `just_audio` remains the fallback/current engine for unsupported, remote, and native-failed sources.
- Returns controlled `unsupported_format`, `file_not_found`, `content_open_failed`, `content_stage_failed`, `decode_error`, `output_error`, `seek_error`, or `native_method_error` errors when the native path cannot proceed.
- Does **not** claim Android `content://` MP3, OGG/Vorbis, Opus, M4A/AAC, remote, or Subsonic/Navidrome native playback support yet.

## Native FLAC playback status

Local FLAC playback is now experimental on Android when **Vanta Native Engine (Experimental)** is selected. The implementation does not vendor upstream libFLAC directly. Instead, this slice uses miniaudio's bundled `dr_flac` decoder path because `miniaudio.h` is already present in the native package, includes FLAC decoding support by default, and avoids unsafe network fetching, unreviewed submodules, or a large new third-party vendoring step.

| Area | Status |
|------|--------|
| Decoder choice | miniaudio `ma_decoder` with bundled `dr_flac` for `.flac`; separate `vanta_flac_decoder.cpp/.h` wrapper keeps FLAC decoding isolated from output/device logic. |
| License | miniaudio is public domain or MIT No Attribution (MIT-0), as stated in the vendored header. `dr_flac` is bundled inside miniaudio under the same vendored source review note. |
| Local file FLAC | Experimental native attempt for existing local `.flac` files. |
| Android `content://` FLAC | Experimental native attempt for original local content sources; Kotlin validates FLAC MIME/display-name/path evidence and stages content to an app-private `.flac` cache file before C++ receives a filesystem path. |
| Metadata | Native decoder records sample rate, channels, total PCM frames, and duration when available. Original FLAC bits per sample is not surfaced by the current miniaudio path and remains unavailable in this slice. |
| Output | Existing miniaudio output device remains responsible for playback; decoder code only decodes PCM frames. Compatible native-to-native transitions may reuse the already-open output device after stopping callbacks and swapping the decoder under lock. Incompatible transitions recreate output as before. |
| Automation | Dart selection/package contract and Kotlin staging behavior are testable. Device-audible native FLAC playback still requires manual Android verification. |

## Native MP3 playback status

Local MP3 playback is experimental on Android when **Vanta Native Engine (Experimental)** is selected. This slice uses the existing vendored miniaudio decoder path with bundled `dr_mp3`; no BASS, FFmpeg, proprietary codec library, or new dependency was added.

| Area | Status |
|------|--------|
| Decoder choice | miniaudio `ma_decoder` with bundled `dr_mp3` for `.mp3`; separate `vanta_mp3_decoder.cpp/.h` wrapper keeps MP3 decoding isolated from output/device logic. |
| License | miniaudio is public domain or MIT No Attribution (MIT-0), as stated in the vendored header. `dr_mp3` is bundled inside miniaudio under the same vendored source review note. |
| Local file MP3 | Experimental native attempt for existing local `.mp3` files only. |
| Android `content://` MP3 | Not native in this work unit. Content MP3 remains on the current engine until a dedicated validation/staging slice proves it safe. |
| Metadata | Native decoder records sample rate, channels, total PCM frames, and duration when available. MP3 VBR duration/seek depends on miniaudio/dr_mp3 frame metadata and may be approximate when source metadata is incomplete. |
| Output | Existing ring-buffer/output pipeline is reused. The audio callback remains ring-buffer-only and does not decode MP3 directly. |

## Phase 3 stability status

This phase keeps the implementation intentionally narrow: state correctness, position/duration/seek reliability, and decoder architecture. It does not rewire the full app queue into native code yet.

| Area | Current behavior |
|------|------------------|
| State model | Native bridge maps `idle`, `loading`, `ready`, `playing`, `paused`, `stopped`, `completed`, and `error`. Terminal `completed` is suppressed after `error` until a new load/play cycle resets the terminal state. |
| Position | Kotlin polls native position every 250 ms while playing and sends updates through the position EventChannel. `VantaAudioHandler` forwards native position only while native owns playback. |
| Duration | WAV/FLAC/MP3 duration is calculated from total PCM frames and sample rate when available. MP3 VBR duration may be approximate when decoder metadata is incomplete. The bridge emits duration after load; unknown duration remains `null`. |
| Seek | Dart clamps negative seek requests to zero. Kotlin and C++ clamp seeks beyond known duration to the track duration. Handler seek updates native position state and preserves paused vs playing state. |
| Completion | Native completion emits final position near duration before `completed`; handler advances to the next queue item or exposes terminal completed state at end of queue. |
| Callback safety | The miniaudio callback contract forbids allocations, locks, decoder/file I/O, channel calls, and logging. It reads only from the preallocated SPSC PCM ring buffer, fills silence on underrun, and updates atomic counters; a host-tested policy seam guards that contract. |
| Foreground playback | Android native playback starts a foreground `mediaPlayback` service plus a partial WakeLock while native output is playing. Pause, stop, dispose, completion, and failures release the keepalive path. |
| Buffer policy | Native FLAC/WAV/MP3 uses an internal stability-oriented PCM ring buffer policy. The helper is clamp-tested between 250 ms and 1000 ms, but production currently uses the stable-music default: 750 ms capacity with up to 500 ms initial fill. No external/runtime adjustment is exposed yet. |
| Diagnostics | Low-noise native diagnostics include underrun counts, ring buffer fill/capacity frames and ms, decoder thread alive, audio callback alive, foreground service active, WakeLock active, backend, sample rate, channels, output buffer policy, continuous playback time, and last native error code. |
| Audio focus/noisy | `audio_session` remains the app-level focus owner. Native playback pauses on pause/unknown interruptions and headphone/Bluetooth noisy events, ducks/unducks for duck interruptions, and does not auto-resume after pause/noisy events. |
| Output lifecycle | Native loads stop the current output before replacing the decoder. If the new decoder has the same sample rate, channel count, and PCM format, the output is reused; otherwise it is closed and recreated. Stop, dispose, native errors, unsupported formats, and fallback paths release native output instead of reusing it. |

### Format support table

| Format/source | Android native experimental | iOS native | Fallback behavior |
|---------------|-----------------------------|------------|-------------------|
| Local WAV file | Yes | No | Current engine if native is not selected or native fails. |
| Local FLAC file | Yes, experimental | No | Current engine if native is not selected or native fails. |
| Local MP3 file | Yes, experimental | No | Current engine if native is not selected or native fails. |
| Android `content://` WAV | Yes, with safe private staging | No | Current engine if Kotlin validation, staging, or native load fails. |
| Android `content://` FLAC | Yes, experimental, with safe private staging | No | Current engine if Kotlin validation, staging, or native load fails. |
| Android `content://` MP3 | No | No | Current engine; dedicated validation remains future work. |
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
5. Seek to a negative position through any debug hook if available, then seek beyond the track duration; expected behavior is clamp-to-zero and clamp-to-duration without a crash or permanent loading state.
6. Play a local `.mp3` file to confirm native routing when the experimental engine is selected. Then play content-MP3, OGG/Opus, M4A/AAC, remote, and Navidrome/Subsonic tracks to confirm they still use the current engine fallback.
7. Watch logs for `[VantaAudioEngine]` messages; they should use redacted source labels and controlled error codes without full paths, URIs, server URLs, or tokens.
8. Play two local native-supported FLAC/WAV tracks with matching output format and watch Android logs for `output=reused`. Play incompatible tracks or fallback formats and verify `output=recreated reason=...` or current-engine fallback without path/URI disclosure.

### Stabilization manual checklist

- [ ] FLAC local playback with screen on for 10 minutes: no cuts, no native crash, underruns stable at zero after startup.
- [ ] FLAC local playback with screen off for 30 minutes: foreground service active, WakeLock held while playing, no choppiness.
- [ ] App background playback for 30 minutes: playback continues, notification/MediaSession remains usable.
- [ ] Lock/unlock repeatedly during native FLAC playback: no stuck buffering, no playback owner switch unless a native error occurs.
- [ ] Battery saver enabled: no cuts; if the device blocks native output, current-engine fallback or graceful failure leaves controls responsive.
- [ ] Headphones disconnected / Bluetooth route removed: playback pauses automatically and does not unexpectedly resume.
- [ ] Bluetooth playback if available: play/pause and route changes remain stable.
- [ ] Notification play/pause: state, position, duration, and track metadata remain synchronized; no duplicate notifications.
- [ ] App seek start/middle/near-end: position updates correctly while playing and paused.
- [ ] Fast repeated app seeks: no native crash, no stuck buffering, no playing-without-audio state.
- [ ] Next/previous: native-to-native and native-to-current-engine transitions keep queue state correct.
- [ ] Local MP3: routes to native only when the experimental engine is selected; content-MP3/remote/Navidrome/Subsonic remain on the current engine fallback path.

## Fallback rules

| Source or failure | Result |
|-------------------|--------|
| Current engine selected | Use current engine. |
| Remote HTTP/HTTPS stream | Use current engine; remote URLs are not sent to native. |
| Subsonic/Navidrome source | Use current engine through the existing resolver path. |
| Original local Android `content://` source | Attempt platform validation; Kotlin stages supported WAV/FLAC through Android `ContentResolver` into app-private cache, then passes only the staged filesystem path to native. |
| Non-WAV/FLAC `content://` source, including MP3 | Controlled `unsupported_format` native error, then current-engine fallback. Explicit unsupported Dart MIME/display-name evidence may fail earlier before platform invocation. |
| Local MP3 file | Attempt native only when the experimental engine is selected; fall back to current engine on native load/playback errors. |
| Local M4A/AAC/ALAC/OGG/Opus/OGA/AMR/3GP file | Use current engine; native format is unsupported or intentionally ignored. |
| Missing local file | Controlled native error, then current-engine fallback. |
| Native load/playback error | Log the redacted error and continue through current engine. |
| Native seek error | Release native ownership, prepare the current engine for the current item, and apply the requested seek through the current engine when possible. |
| Foreground service / WakeLock failure | Log a privacy-safe keepalive code and fail or fall back gracefully; release any partial native ownership. |
| ABI/native library unavailable | Return controlled native-library-unavailable errors so the handler can keep the current engine usable. |
| Native-owned stop | Stop/release only the native engine and clear session state; do not stop the current engine unnecessarily. |

Logs use redacted labels for remote/content/Subsonic sources and avoid tokens, passwords, full remote URLs, full content URIs, and local filenames. Native fallback logs include safe codes in the form `native-error code=...`.

User-visible native failure notification is not implemented yet; current behavior is privacy-safe logging plus current-engine fallback. Basic FLAC gapless remains a next step: output reuse reduces close/open churn, but true gapless needs a native queue/preload model and is intentionally not implemented in this stabilization slice.

Local file eligibility remains strict in Dart by `.wav`/`.flac`/`.mp3` extension. Android `content://` eligibility is intentionally delegated to Kotlin when the original source is local/provider-local and the native experimental engine is selected, because many MediaStore URIs are opaque in Dart. Kotlin `ContentResolver` metadata checks decide whether the content can be staged as WAV/FLAC before native code receives a filesystem path; content MP3 remains future work.

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
            ├── vanta_decoder_factory.cpp/.h
            ├── vanta_flac_decoder.cpp/.h
            ├── vanta_mp3_decoder.cpp/.h
            └── vanta_output.cpp/.h
```

## Decoder factory status

`vanta_decoder_factory.cpp/.h` is the native extension/type routing seam. It currently returns:

| Extension | Native decoder kind | Status |
|-----------|---------------------|--------|
| `.wav` | `wav` | Existing miniaudio WAV path. |
| `.flac` | `flac` | Existing isolated FLAC wrapper. |
| `.mp3` | `mp3` | Existing miniaudio `dr_mp3` path through isolated MP3 wrapper. |
| `.ogg`, `.opus`, `.oga`, `.m4a`, `.aac`, `.alac`, `.amr`, `.3gp`, other | `unsupported` | Current-engine fallback or ignored by native routing. Future codec work should be localized here plus dedicated decoder wrappers. |

## Native playback status

| Area | Status |
|------|--------|
| Backend | miniaudio single-header backend vendored under `android/src/main/cpp/native/miniaudio.h`. |
| Supported format | Local `.wav`/`.flac`/`.mp3` files and original local Android `content://` WAV/FLAC sources staged into app-private cache after Kotlin validation. |
| Native commands | `init`, `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, `dispose`. |
| Position/duration/completion | Native duration is emitted after load; native position is polled periodically while playing; handler-level completion advances the queue and exposes terminal completed state at queue end. |
| App integration | `VantaAudioHandler` remains the queue, MediaSession, notification, and fallback coordinator. Native-ready items are owned by Vanta Native Engine without duplicate `just_audio` preparation; unsupported or failed native attempts load through the current engine. |
| Out of scope | Android `content://` MP3, OGG/Vorbis, Opus, M4A/AAC/ALAC, AMR/3GP, ReplayGain, gapless, crossfade, remote streams, and non-WAV/FLAC `content://` native playback. |

## Native queue and gapless status

Native queue/gapless is prepared architecturally but not implemented as full native ownership yet.

| Capability | Status |
|------------|--------|
| Handler queue ownership | Still owned by `VantaAudioHandler` and `audio_service`. This preserves background controls and fallback reliability. |
| Native skip on completion | Implemented at handler level: native completion advances to the next item and decides native vs current-engine routing per item. |
| Native `setQueue` / preloading | Not implemented. This needs a dedicated native queue model before real gapless. |
| Output reuse | Experimental. Compatible handler-driven native-to-native transitions can keep the output device open, but the next decoder is still loaded at transition time. This reduces output close/open churn; it does not remove all audible gaps. |
| Gapless prebuffer | Not implemented. The decoder factory and isolated decoder wrappers are the intended foundation for this future step. |

## Licensing

Vanta Music is licensed as `GPL-3.0-or-later`.

The native audio engine is designed to use open source components only. Proprietary engines such as BASS are intentionally avoided.

Third-party native libraries keep their own licenses and should be listed in `THIRD_PARTY_NOTICES.md`.

### Licensing decisions

- BASS is not used because it is proprietary and not ideal for an open-source-first player architecture.
- FFmpeg is avoided initially to keep licensing, binary size, and integration complexity low.
- miniaudio is vendored as a single-header dependency and is available under a choice of public domain or MIT No Attribution (MIT-0), as stated in the header license block. This slice uses miniaudio's bundled `dr_flac` and `dr_mp3` decoder paths for experimental FLAC/MP3 rather than adding upstream libFLAC, BASS, FFmpeg, or another codec dependency.
- Reviewer note: `android/src/main/cpp/native/miniaudio.h` is vendored third-party source and should be excluded from app-authored review-line budgeting.
- Additional open-source building blocks remain under evaluation before adoption.

## Candidate libraries

| Area | Candidate | Notes |
|------|-----------|-------|
| Output/mixing | miniaudio | Adopted for the first local WAV backend. |
| Tags | TagLib | Mature metadata support candidate. |
| FLAC | miniaudio bundled `dr_flac` path | Adopted for the experimental local FLAC slice; upstream libFLAC remains a possible future replacement if vendored deliberately. |
| MP3 | miniaudio bundled `dr_mp3` path | Adopted for the experimental local file MP3 slice; content MP3 remains future work. |
| OGG/Vorbis/Opus | libogg, libvorbis, libopus | Evaluate per codec and license constraints. |

## Roadmap

1. Stabilize the Dart abstraction and current-engine fallback seam.
2. Keep Android bridge compile-safe with MethodChannel/EventChannel, JNI, and CMake.
3. Harden the minimal miniaudio-backed local WAV path with device-audible verification.
4. Expand native queue scaffolding only after the handler/native ownership contract stays stable under device testing.
5. Add user-visible native fallback notification through a safe app notification surface.
6. Add native support for streaming/buffered sources when the routing model is proven safe.
7. Harden experimental FLAC support with device-audible verification and completion polish.
8. Evaluate Android `content://` MP3 validation/staging or prepare M4A/AAC fallback UX before adding more native codecs.
9. Add ReplayGain parsing/application with explicit user control.
10. Add gapless playback and crossfade in the engine layer.
11. Add TagLib-backed metadata extraction where useful.
12. Deepen MediaSession integration while preserving notification and lockscreen behavior.
