## Exploration: vanta-audio-engine

### Current State
Playback is initialized in `lib/main.dart`, which awaits `initAudioHandler()` and injects a concrete `VantaAudioHandler` through `audioHandlerProvider`. `initAudioHandler()` in `lib/features/player/application/audio_handler_provider.dart` builds the `AudioService` handler, loads persisted `AudioSettings`, wires Subsonic stream resolution plus offline download fallback, and restores the last playback session.

UI and feature code do not talk to `just_audio` directly. They consume Riverpod streams from `player_controller.dart`, while `VantaAudioHandler` owns the real queue, `AudioPlayer`, `MediaItem` identity, session persistence, and remote/local URI resolution. Local tracks stay local by keeping `MediaItem.id` equal to the original `Track.uri`, while Subsonic/Navidrome tracks keep canonical `subsonic://` IDs and are resolved just-in-time to HTTPS or downloaded file URIs.

At exploration time, audio settings already persisted to `audio_settings.json` via `FileAudioSettingsStore`, loaded through `AudioSettingsController`, and rendered in `AudioSettingsScreen`, which is routed from `LibraryScreen` via `/audio-settings`. That baseline made the screen the safe insertion point for the now-added experimental audio-engine selector.

Android currently uses a single `:app` module. `MainActivity` extends `AudioServiceActivity`, `android/settings.gradle.kts` only includes `:app`, and there is no existing app-authored platform channel/plugin package in the repo. However, `android/app/build.gradle.kts` already exposes `ndkVersion = flutter.ndkVersion`, and the generated registrant already includes `jni`/`jni_flutter`, so JNI/CMake adoption is feasible.

### Affected Areas
- `lib/main.dart` — app boot waits for audio handler initialization and injects the concrete implementation.
- `lib/features/player/application/audio_handler_provider.dart` — primary player composition root; safest place to select default vs experimental engine.
- `lib/features/player/application/player_controller.dart` — stable app-facing control abstraction already shielding UI from concrete playback internals.
- `lib/features/player/infrastructure/vanta_audio_handler.dart` — current default engine implementation and the current source of queue/session/state truth.
- `lib/features/player/domain/audio_settings.dart` — likely home for a future persisted engine preference.
- `lib/features/player/application/audio_settings_controller.dart` — persistence/apply flow for settings; would apply engine selection later.
- `lib/features/player/presentation/audio_settings_screen.dart` — existing routed settings UI where a selector can be added without redesign.
- `lib/features/library/domain/track.dart` — source identity model consumed by all playback entry points.
- `lib/features/providers/infrastructure/local_music_provider.dart` — local tracks may be `content://` or `file://`, which matters for native-engine eligibility.
- `lib/features/library/application/folder_library_controller.dart` — additional local source produces explicit `file://` tracks with providerId `folder`.
- `lib/features/providers/infrastructure/subsonic_music_provider.dart` — remote tracks use canonical `subsonic://track?...` URIs and server-scoped provider IDs.
- `lib/features/player/application/subsonic_stream_resolver_registry.dart` — current remote/offline resolution boundary; useful for routing non-local playback back to the existing engine.
- `android/app/src/main/kotlin/com/vantamusic/app/MainActivity.kt` — current Android entry point if app-level channel registration is used.
- `android/settings.gradle.kts` / `android/app/build.gradle.kts` — would change if the experimental engine becomes a new plugin/module with CMake/JNI.
- `test/features/player/**`, `test/app/router_test.dart` — existing coverage around player helpers, settings, and routing that can protect the first slice.

### Approaches
1. **Handler-level engine adapter** — keep `PlayerController` and UI untouched, introduce a Dart playback-engine interface under `features/player`, keep `VantaAudioHandler` as the default adapter, and add an experimental native-backed adapter selected only for eligible local items.
   - Pros: smallest behavioral surface; preserves `audio_service` integration and current UI/state streams; safe fallback for remote/Navidrome and unsupported local URIs.
   - Cons: native adapter must either mimic enough of `VantaAudioHandler` behavior or share queue/state logic with it; first cut still needs careful event/state mapping.
   - Effort: Medium

2. **Separate internal Flutter plugin/package first** — create `packages/vanta_audio_engine` as an isolated Android-first plugin with MethodChannel/EventChannel + JNI/CMake skeleton, then integrate it later behind the player composition root.
   - Pros: best long-term separation; native code stays out of app module; clearer ownership and future reuse.
   - Cons: integration still required afterward; package + Android wiring alone may consume most of a 400-line review slice if combined with runtime selection.
   - Effort: Medium

3. **Replace the current handler directly** — swap `VantaAudioHandler` internals to native playback for local sources inside the existing class.
   - Pros: fewer public types.
   - Cons: mixes experiment with the proven path, raises regression risk, and makes remote fallback/session behavior harder to reason about.
   - Effort: High

### Recommendation
Use **Approach 1**, implemented in slices, and make **Approach 2** the packaging shape of the experimental path. In practice: keep `VantaAudioHandler`/`audio_service` as the production default, introduce a small Dart engine abstraction at the composition root, and only delegate to the native engine for clearly eligible local playback. Remote/Subsonic/Navidrome items continue through the current handler unchanged. Android `content://` sources may be attempted only when they have clear WAV evidence and are staged through `ContentResolver` into app-private cache before native load.

Recommended first slice under the 400-line review budget: define the engine-selection seam with a guarded, visible opt-in selector and a minimal native WAV readiness path. That means adding an engine enum/config model, a selector/factory defaulting to `just_audio`, and an experimental package skeleton (`packages/vanta_audio_engine`) with Android plugin/JNI/CMake support. The experimental path may attempt only clearly eligible local WAV files or clear WAV `content://` sources and MUST fall back to the current handler for remote, unsupported, or failing sources.

### Risks
- Local tracks are not uniformly file paths: `LocalMusicProvider` can emit `content://` URIs, while folder imports emit `file://`; a native engine that only knows raw files MUST never receive raw content URIs and must use private staging or fail closed.
- `VantaAudioHandler` currently owns queue mutation, `MediaItem` identity, remote retry semantics, session restore, and intelligence events; duplicating that logic in a native path would be easy to get wrong.
- `audio_service` is tied to the current handler lifecycle (`AudioService.init`, `AudioServiceActivity`); bypassing too much of that stack could break notifications/background controls.
- There is no existing in-repo plugin/module convention, so adding `packages/vanta_audio_engine` will also introduce workspace/dependency wiring decisions.
- A single slice that includes package creation, native channels, JNI, queue routing, settings UI, and fallback logic is very likely to exceed the 400-line review budget.

### Ready for Proposal
Yes — propose an incremental plan starting with a safe opt-in seam: (1) engine abstraction + default factory, (2) internal Android-first package skeleton, (3) local-file WAV eligibility routing with hard fallback to current handler, (4) settings selector/UI exposure, (5) docs in `docs/VANTA_AUDIO_ENGINE.md`.
