# Proposal: Vanta Audio Engine

## Intent

Introduce a safe, Android-first native audio-engine foundation without replacing the proven `just_audio`/`audio_service` path. The current delivery prioritizes a compile-safe integrated base, visible user choice, strict fallback behavior, and minimal local WAV plus experimental local FLAC playback through miniaudio—not complete native playback parity.

## Scope

### In Scope
- Add a Dart audio-engine abstraction and selection seam while keeping the current engine as the default.
- Add experimental `packages/vanta_audio_engine` with Dart API, Kotlin channel, JNI, CMake, and split C/C++ native files.
- Add a minimal miniaudio-backed local WAV path and experimental local FLAC path for native load/play/pause/stop/seek/volume commands, including Kotlin `ContentResolver` validation and safe staging for eligible local Android `content://` WAV/FLAC sources.
- Add an engine selector to existing Audio Settings; native engine is default OFF, current engine default ON.
- Route unsupported sources to the current engine: remote/Subsonic/Navidrome, non-WAV/FLAC sources, local `content://` sources with explicit unsupported evidence, and non-local/unsupported URIs.
- Log privacy-safe native-engine failures and continue with the current engine. User-visible failure notification remains pending until a safe app notification surface is selected.
- Document architecture and limits in `docs/VANTA_AUDIO_ENGINE.md`.

### Out of Scope
- Full miniaudio/native playback parity beyond the minimal local WAV and experimental local FLAC foundation.
- Device-audible verification, streaming, continuous position updates, completion handling, and broader codec support.
- Replacing `VantaAudioHandler`, queue/session ownership, background controls, or remote streaming internals.
- Native support for non-WAV/FLAC, remote streams, provider-specific remote playback, or local `content://` sources that Kotlin cannot validate as WAV/FLAC.

## Capabilities

### New Capabilities
- `vanta-audio-engine`: Engine selection, native package foundation, local WAV and experimental local FLAC eligibility, minimal miniaudio playback commands, privacy-safe failure logging, fallback, and documentation.

### Modified Capabilities
- `subsonic-provider`: Remote/Subsonic/Navidrome playback must remain on the current engine while native support is experimental.

## Approach

Keep `VantaAudioHandler`/`audio_service` as the production path. Add a small Dart abstraction near `audio_handler_provider.dart` so selection is centralized. Build `packages/vanta_audio_engine` as an internal Android-first plugin foundation. Only real local WAV sources and experimental local FLAC sources may be eligible for native routing in this slice. Local Android `content://` sources with explicit unsupported Dart evidence fail closed to the current engine; local `content://` sources without Dart MIME/display-name evidence may attempt native routing so Kotlin can validate and stage them authoritatively with `ContentResolver`. Raw `content://` URIs never reach C++; native receives only a staged filesystem path. Remote/Subsonic/Navidrome and other unsupported sources still fail closed to the current engine.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/player/application/audio_handler_provider.dart` | Modified | Engine selection seam and fallback routing. |
| `lib/features/player/domain/audio_settings.dart` | Modified | Persist selected engine preference. |
| `lib/features/player/presentation/audio_settings_screen.dart` | Modified | Visible engine selector. |
| `packages/vanta_audio_engine/` | New | Dart API, Kotlin channel, JNI/CMake, split native files, and minimal WAV/miniaudio backend. |
| `pubspec.yaml` | Modified | Package/workspace wiring. |
| `docs/VANTA_AUDIO_ENGINE.md` | New | Architecture, limits, fallback rules. |
| `test/features/player/**` | Modified | Selection, persistence, routing, and fallback coverage. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Review exceeds 400 lines | High | Forecast chained slices before apply; user preference noted but guard remains. |
| Native path regresses playback | Medium | Default OFF; current engine remains default and fallback target. |
| URI eligibility mistakes | Medium | Allow native only for real local WAV/FLAC `file://` sources, clear local WAV/FLAC `content://` evidence, or local `content://` sources that Kotlin validates and stages; explicit unsupported evidence, remote sources, and unresolved content stay on the current engine. |

## Rollback Plan

Disable/remove the native-engine preference and package dependency; keep current engine as the only registered path. Revert Audio Settings selector and docs without migrating playback data.

## Dependencies

- Android NDK/CMake through Flutter/Gradle configuration.
- Existing `audio_service`, `just_audio`, and Audio Settings persistence.

## Success Criteria

- [x] App compiles/analyzes with integrated native package foundation.
- [x] Current engine remains default and existing playback behavior is preserved.
- [x] Audio Settings exposes engine selection with native OFF by default.
- [x] Unsupported sources and native failures log privacy-safe fallback and continue through the current engine.
- [x] Minimal local WAV/miniaudio load and playback command path exists.
- [x] Clear local Android `content://` WAV sources are staged privately before native load.
- [x] Experimental local FLAC support uses the existing miniaudio/`dr_flac` decoder path with safe file/content routing and current-engine fallback.
- [ ] User-visible native failure notification remains future work.
- [ ] Device-audible verification, streaming, continuous position updates, completion handling, and broader codec support beyond WAV/FLAC remain future work.
