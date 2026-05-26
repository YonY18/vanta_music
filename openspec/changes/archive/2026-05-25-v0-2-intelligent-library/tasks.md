# Tasks: v0.2 Intelligent Library

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 520-760 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Playlist lifecycle + persistence hardening with tests | PR 1 | Base main; include RED/GREEN for rename/remove/reorder boundaries. |
| 2 | Library intelligence history/stats/providers with bounded lists | PR 2 | Depends PR 1 only by shared patterns; keep caps/pruning + reducer/provider tests. |
| 3 | UI wiring (library/player) + queue actions + premium empty states | PR 3 | Depends PR 2; include widget/controller tests and fallback copy checks. |

## Phase 1: Foundation / Contracts

- [x] 1.1 RED: Add failing unit tests in `test/features/library_intelligence/domain/library_snapshot_test.dart` for optional JSON fields (`listenedDurationMs`, `completed`) and backward-compatible decode.
- [x] 1.2 GREEN: Update `lib/features/library_intelligence/domain/library_snapshot.dart` and `lib/features/library_intelligence/domain/library_event.dart` to parse/write new history fields with safe defaults.
- [x] 1.3 REFACTOR: Add deterministic cap constants/helpers in `lib/features/library_intelligence/application/library_intelligence_reducer.dart` and verify unchanged behavior for existing favorites.

## Phase 2: Core Implementation

- [x] 2.1 RED: Add failing tests in `test/features/playlists/application/playlists_controller_test.dart` for rename/delete/remove-track/reorder including first/last boundary scenario.
- [x] 2.2 GREEN: Implement operations in `lib/features/playlists/application/playlists_controller.dart` and needed value semantics in `lib/features/playlists/domain/playlist.dart`.
- [x] 2.3 RED/GREEN: Add malformed/backward JSON tests in `test/features/playlists/infrastructure/local_playlist_store_test.dart`, then harden `lib/features/playlists/infrastructure/local_playlist_store.dart`.
- [x] 2.4 RED/GREEN: Add reducer/provider tests in `test/features/library_intelligence/application/library_intelligence_reducer_test.dart` and `.../library_intelligence_providers_test.dart`, then implement bounded history/top/stats providers in `lib/features/library_intelligence/application/library_intelligence_providers.dart`.

## Phase 3: Integration / Wiring

- [x] 3.1 RED: Add widget tests in `test/features/library/presentation/library_screen_test.dart` for stats cards, playlist detail navigation, and smart-section empty-state rules.
- [x] 3.2 GREEN: Wire UI in `lib/features/library/presentation/library_screen.dart` and `lib/features/library/presentation/library_intelligence_sections.dart` using lazy builders and bounded provider outputs.
- [x] 3.3 RED/GREEN: Add controller/handler tests in `test/features/player/application/player_controller_test.dart` and `.../infrastructure/vanta_audio_handler_test.dart` for queue jump/remove/play-next/add-end.
- [x] 3.4 GREEN: Implement queue commands in `lib/features/player/application/player_controller.dart`, `lib/features/player/infrastructure/vanta_audio_handler.dart`, and expose entry points in `lib/features/player/presentation/now_playing_screen.dart`.

## Phase 4: Verification / Cleanup

- [x] 4.1 Run `flutter test` and fix regressions in touched feature tests before merging each work unit.
- [x] 4.2 Run `flutter analyze --no-fatal-infos --no-fatal-warnings`; apply minimal cleanup in modified files only (no redesign, no Drift migration, no external providers).
