# Design: v0.2 Intelligent Library

## Technical Approach

Extend the existing feature-first Riverpod architecture without a visual redesign. Keep intelligence JSON-first by evolving `LibrarySnapshot`, `LibraryIntelligenceReducer`, and file stores, then expose bounded derived providers to Library, Playlists, and Player UI. v0.2 stays incremental: no Drift migration, no cloud/AI implementation, and each slice should remain reviewable under ~400 changed lines.

## Architecture Decisions

| Area | Choice | Alternatives considered | Rationale |
|------|--------|-------------------------|-----------|
| Persistence | Evolve JSON files: `library_intelligence.json` and `playlists.json` with optional/defaulted fields | Drift/SQLite migration | Meets v0.2 scope, preserves rollback, avoids schema churn while beta is stabilizing. |
| Derived data | Keep bounded Riverpod projections in `library_intelligence_providers.dart` | Compute in widgets or eagerly materialize all sections | Matches current pattern and keeps UI declarative; providers can cap results before rendering. |
| UI scope | Add small cards/sheets/detail screens using current `Card`, `ListTile`, `SliverList/ListView.builder`, `VantaColors` | New design system or full Library redesign | User constraint is current style; lazy builders preserve performance. |
| Queue UX | Surface queue read/jump first through `VantaAudioHandler`/`PlayerController`; defer advanced reorder if too large | Full queue editor in one slice | Spec asks queue actions, but review budget requires slicing; playback intent must stay stable. |

## Data Flow

    VantaAudioHandler ──play/progress/complete──→ LibraryIntelligenceSink
            │                                      │
            │                                      └─debounced save→ library_intelligence.json
            │
            └─queue/session streams→ PlayerController/Riverpod → UI

    tracksProvider + LibrarySnapshot ─→ bounded mapping providers ─→ Home/Library/Stats
    PlaylistsController ──────────────→ LocalPlaylistStore ───────→ playlists.json

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/library_intelligence/domain/library_snapshot.dart` | Modify | Add history entries and richer stats fields with backward-compatible JSON parsing. |
| `lib/features/library_intelligence/domain/library_event.dart` | Modify | Include listened duration/completion inputs needed by history. |
| `lib/features/library_intelligence/application/library_intelligence_reducer.dart` | Modify | Cap history/top lists, update completion/progress deterministically. |
| `lib/features/library_intelligence/application/library_intelligence_providers.dart` | Modify | Add bounded providers for history, top listened songs, total duration, and stats. |
| `lib/features/library_intelligence/infrastructure/file_library_intelligence_store.dart` | Modify | Keep forgiving JSON load and add pruning before save if needed. |
| `lib/features/playlists/domain/playlist.dart` | Modify | Add copy/equality helpers if needed for rename/remove/reorder operations. |
| `lib/features/playlists/application/playlists_controller.dart` | Modify | Add rename, delete, remove track, reorder track; keep pure helpers testable. |
| `lib/features/playlists/infrastructure/local_playlist_store.dart` | Modify | Preserve compatible JSON; validate malformed playlists/tracks safely. |
| `lib/features/library/presentation/library_screen.dart` | Modify | Add stats cards, playlist detail navigation, removal/reorder controls, premium empty states; keep lazy lists. |
| `lib/features/library/presentation/library_intelligence_sections.dart` | Modify | Keep `topN` sections bounded and add explicit empty/product rules. |
| `lib/features/player/infrastructure/vanta_audio_handler.dart` | Modify | Expose queue snapshot actions: jump, remove, play next/add end, later reorder if slice budget allows. |
| `lib/features/player/application/player_controller.dart` | Modify | Add queue commands that delegate to audio handler. |
| `lib/features/player/presentation/now_playing_screen.dart` | Modify | Add favorite/action/queue entry points without changing layout language. |
| `test/features/**` | Modify | Add unit/widget-level regressions for JSON, reducers, playlists, providers, queue. |

## Interfaces / Contracts

New fields must be optional on read and emitted on write:

```dart
class PlaybackHistoryEntry {
  final String trackKey;
  final DateTime listenedAt;
  final int listenedDurationMs;
  final bool completed;
}
```

Provider contracts: lists returned to UI must already be bounded (`topN`/history cap), immutable, and filtered to tracks present in `tracksProvider`.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Reducer history, caps, favorites, stats, playlist rename/remove/reorder | `flutter_test` pure helper tests. |
| Provider | Snapshot + tracks mapping filters ghosts and bounds lists | `ProviderContainer` overrides as existing tests do. |
| Store | Backward-compatible/malformed JSON and pruning | Temp/local store tests matching current file-store tests. |
| UI/Controller | Playlist detail actions and queue commands | Widget/controller tests where feasible; avoid brittle golden tests. |

## Migration / Rollout

No migration required. Roll out in review slices: (1) playlist helpers/store tests, (2) intelligence history/stats providers, (3) Library UI polish, (4) queue controls, (5) premium empty states. Rollback is reverting slices; old JSON remains readable because new fields default safely.

## Open Questions

- [ ] Advanced queue reorder may exceed the 400-line budget; if so, ship jump/remove/play-next/add-end first and defer reorder to the next slice.
