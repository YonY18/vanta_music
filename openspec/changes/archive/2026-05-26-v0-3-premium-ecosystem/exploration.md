## Exploration: v0.3 Premium Ecosystem

### Current State
The app already follows a feature-first clean layering with Riverpod + GoRouter (`lib/app/app.dart`, `lib/app/router.dart`, `lib/features/**`). Playback and queue are centralized in `VantaAudioHandler` with persisted session restore (`lib/features/player/infrastructure/vanta_audio_handler.dart`, `lib/features/player/infrastructure/file_playback_session_store.dart`).

Persistence is currently JSON-file based for playlists, folder sources, playback session, and intelligence snapshot (`lib/features/playlists/infrastructure/local_playlist_store.dart`, `lib/features/library/infrastructure/file_folder_library_store.dart`, `lib/features/player/infrastructure/file_playback_session_store.dart`, `lib/features/library_intelligence/infrastructure/file_library_intelligence_store.dart`). Drift/sqlite dependencies exist in `pubspec.yaml` but there is no active database usage in `lib/` yet.

Artwork already has a strong local-first pipeline: cache keying, on-device file cache with LRU-ish pruning, MediaStore fetch + embedded fallback (`lib/shared/artwork_cache/artwork_cache_resolver.dart`, `lib/shared/artwork_cache/file_artwork_cache_store.dart`). UI already defers artwork on scroll and precaches selected items (`lib/shared/widgets/artwork_tile.dart`, `lib/features/library/application/library_providers.dart:120+`).

Provider ecosystem prep already exists as stubs (`MusicProvider` + `NavidromeProvider`/`JellyfinProvider`) without implementation, which is good for v0.3 “prep-only” scope (`lib/features/providers/domain/music_provider.dart`, `lib/features/providers/infrastructure/navidrome_provider.dart`, `lib/features/providers/infrastructure/jellyfin_provider.dart`).

### Affected Areas
- `lib/shared/artwork_cache/*` — extend for missing-artwork download metadata, fallback strategy, optional artist-level assets, and cache policy controls.
- `lib/features/library/domain/track.dart` + library mapping providers — add enriched metadata fields and editor-safe update model.
- `lib/features/player/presentation/now_playing_screen.dart` — add minimal lyrics panel/route and smooth transition from now playing.
- `lib/features/player/infrastructure/vanta_audio_handler.dart` + `player_controller.dart` — queue reorder API, queue mutation persistence guarantees, smart restore policy.
- `lib/features/library/presentation/library_screen.dart` (large file) — currently mixes many tabs/concerns; new premium features should be added via extracted widgets to avoid rebuild blowups.
- `lib/app/theme.dart` + player/library presentation widgets — micro-animations/transitions must preserve exact style tokens.
- `lib/features/providers/domain/music_provider.dart` and new provider contracts — add prep interfaces for Navidrome/Jellyfin/SMB/WebDAV without replacing `LocalMusicProvider`.
- `lib/main.dart` — currently portrait lock blocks desktop readiness (`SystemChrome.setPreferredOrientations([portraitUp])`).
- `test/features/**`, `test/shared/**` — extend existing test-first pattern for queue behavior, metadata cache semantics, and lyrics offline fallback.

### Approaches
1. **Incremental JSON-first (recommended for early v0.3 slices)** — keep current file-based stores, add narrowly scoped JSON artifacts for new metadata/lyrics/queue UX state.
   - Pros: minimal risk, fastest integration with current architecture, keeps PRs under ~400 lines, no migration complexity now.
   - Cons: multi-file consistency and query-heavy growth can become costly later; weaker transactional guarantees.
   - Effort: Low/Medium.

2. **Early Drift/SQLite foundation for new domains** — introduce DB now for metadata/history/cache indexing before feature expansion.
   - Pros: stronger scalability, transactional updates, better query flexibility for premium metadata/lyrics/search over time.
   - Cons: migration cost now, wider blast radius, likely exceeds first-slice review budget, slows visible v0.3 delivery.
   - Effort: High.

### Recommendation
Adopt a **hybrid progressive path**: start v0.3 with **incremental JSON-first** for user-visible premium wins (metadata fallback UX, minimal lyrics, queue interactions, micro-transitions), while designing clear repository interfaces so a later DB migration is low-friction.

Minimal first-slice scope (review-safe):
1) Metadata premium foundations only (non-blocking artwork fallback + cache policy + placeholders + dynamic palette extraction hooks).
2) Queue UX minimal upgrade (play-next/add-end polish + reorder API contract + persistence tests; lightweight UI controls first).
3) Minimal lyrics local/offline model + read-only screen transition from now playing (no heavy effects).

### Risks
- **Excessive rebuild risk**: `library_screen.dart` is very large (1732 lines) and watches many providers in single widgets; adding premium UI directly there can trigger avoidable recomposition and review complexity.
- **I/O growth risk**: multiple JSON stores can fragment state and increase load/save overhead as metadata/lyrics/history grow.
- **Queue correctness risk**: reorder + swipe + persistence may desync queue index/audio source order if mutations are not atomic in handler.
- **Performance regression risk**: adding blur/transitions/artwork effects without profiling can hurt frame pacing; must gate by low-cost primitives and measured rebuild boundaries.
- **Desktop-prep conflict**: current portrait lock and mobile-first layout assumptions can block future desktop behavior if not isolated behind platform-adaptive wrappers.

### Ready for Proposal
Yes — with strict progressive boundaries.

Tell the user:
- v0.3 should start with **small, integrated slices** preserving current style and performance.
- First slices should explicitly **avoid full DB migration, online provider implementation, complex lyrics/karaoke, and desktop full rollout**.
- Add contracts/interfaces now, not full ecosystems now.

### v0.3 Slice Boundaries (400-line review protection)
- **Slice 1 (metadata premium core)**: no network plugins yet; only fallback pipeline extension, palette extraction hook, cache/lazy behavior tests.
- **Slice 2 (queue premium core)**: reorder contract in handler + minimal UI affordances + persistence tests; defer advanced gestures.
- **Slice 3 (lyrics minimal)**: local lyrics storage/cache + simple viewer + now-playing transition; defer sync/animations.
- **Slice 4 (perf hardening)**: targeted rebuild and image/list/query optimizations based on profiling evidence.
- **Slice 5 (ecosystem/desktop prep)**: interfaces/models/adapters only; no full provider integrations.

### What NOT to implement in first v0.3 slices
- Full Drift migration for all existing stores.
- Full online metadata or lyrics provider integrations and plugin lock-in.
- Karaoke/timed-word effects, shader-heavy visuals, or large animation systems.
- Full Navidrome/Jellyfin/SMB/WebDAV implementations.
- Full desktop feature parity and platform-specific packaging workflows.
- Global redesign/theme rewrite.
