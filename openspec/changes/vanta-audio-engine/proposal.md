# Proposal: Vanta Audio Engine

## Intent

Introduce a safe, Android-first native audio-engine foundation without replacing the proven `just_audio`/`audio_service` path. The first delivery prioritizes a compile-safe integrated base, visible user choice, strict fallback behavior, and a minimal local WAV/miniaudio foundation—not complete native playback parity.

## Scope

### In Scope
- Add a Dart audio-engine abstraction and selection seam while keeping the current engine as the default.
- Add experimental `packages/vanta_audio_engine` with Dart API, Kotlin channel, JNI, CMake, and split C/C++ native files.
- Add a minimal miniaudio-backed local WAV path for native load/play/pause/stop/seek/volume commands, including safe staging for narrowly eligible Android `content://` WAV sources.
- Add an engine selector to existing Audio Settings; native engine is default OFF, current engine default ON.
- Route unsupported sources to the current engine: remote/Subsonic/Navidrome, non-WAV or ambiguous `content://`, and non-local/unsupported URIs.
- Log privacy-safe native-engine failures and continue with the current engine. User-visible failure notification remains pending until a safe app notification surface is selected.
- Document architecture and limits in `docs/VANTA_AUDIO_ENGINE.md`.

### Out of Scope
- Full miniaudio/native playback parity beyond the minimal local WAV foundation.
- Device-audible verification, streaming, continuous position updates, completion handling, and broader codec support.
- Replacing `VantaAudioHandler`, queue/session ownership, background controls, or remote streaming internals.
- Native support for non-WAV or ambiguous `content://`, remote streams, or provider-specific remote playback.

## Capabilities

### New Capabilities
- `vanta-audio-engine`: Engine selection, native package foundation, local WAV eligibility, minimal miniaudio playback commands, privacy-safe failure logging, fallback, and documentation.

### Modified Capabilities
- `subsonic-provider`: Remote/Subsonic/Navidrome playback must remain on the current engine while native support is experimental.

## Approach

Keep `VantaAudioHandler`/`audio_service` as the production path. Add a small Dart abstraction near `audio_handler_provider.dart` so selection is centralized. Build `packages/vanta_audio_engine` as an internal Android-first plugin foundation. Only real local WAV sources may be eligible for native routing initially. Android `content://` sources must be resolved with `ContentResolver` into app-private staged files before native receives a filesystem path; all ambiguous, remote, or unsupported sources fail closed to the current engine.

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
| URI eligibility mistakes | Medium | Allow native only for real local WAV `file://` or clear local WAV `content://` evidence; all else current engine. |

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
- [ ] User-visible native failure notification remains future work.
- [ ] Device-audible verification, streaming, continuous position updates, completion handling, and broader codec support remain future work.
