# Tasks: v0.4.1 Navidrome Online Polish & Reliability

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 900-1400 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 reliability+cache -> PR2 playback+artwork -> PR3 intelligence+search -> PR4 server mgmt+docs |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Failure taxonomy, retry, stale remote cache, offline UI | PR 1 | Foundation slice; keep local library intact |
| 2 | Per-track playback recovery and remote artwork hardening | PR 2 | Depends on PR 1 state/contracts |
| 3 | Source-aware intelligence and debounced remote search/navigation | PR 3 | Depends on PR 1; no redesign |
| 4 | Multi-server operations, hygiene, docs, manual checks | PR 4 | Final polish; leave staged Android deletion untouched |

## Phase 1: Reliability Foundation

- [x] 1.1 RED: extend `test/features/providers/infrastructure/subsonic_api_client_test.dart` for typed failures, capped backoff, timeout retry, and secret redaction scenarios from `subsonic-provider/spec.md`.
- [x] 1.2 GREEN: implement taxonomy/retry helpers in `lib/features/providers/infrastructure/subsonic_api_client.dart` without adding a new network layer.
- [x] 1.3 RED/GREEN: add remote snapshot cache tests in `test/features/providers/infrastructure/subsonic_music_provider_test.dart` and implement `serverId + providerId` stale cache reads/writes in `lib/features/providers/infrastructure/subsonic_music_provider.dart`.
- [x] 1.4 REFACTOR: wire retry/refresh state through `lib/features/providers/application/subsonic_providers.dart`, `lib/features/library/application/library_providers.dart`, and `lib/features/library/presentation/library_screen.dart` for offline/unavailable UI, stale timestamp, and manual retry only.

## Phase 2: Playback and Artwork Robustness

- [x] 2.1 RED: cover single-track failure, retryable resolution, and sanitized persisted session in `test/features/player/infrastructure/vanta_audio_handler_test.dart`, `test/features/player/application/subsonic_stream_resolver_registry_test.dart`, and `test/features/player/domain/playback_session_test.dart`.
- [x] 2.2 GREEN: update `lib/features/player/application/subsonic_stream_resolver_registry.dart`, `lib/features/player/infrastructure/vanta_audio_handler.dart`, `lib/features/player/domain/playback_session.dart`, and `lib/features/player/presentation/now_playing_screen.dart` for per-track retry/skip and visible Now Playing errors.
- [x] 2.3 RED/GREEN: add server-scoped artwork key, in-flight dedupe, negative-cache, and placeholder tests in `test/shared/artwork_cache/*.dart`; implement them in `lib/shared/artwork_cache/*` plus light queue/now-playing precache only.

## Phase 3: Intelligence and Remote Navigation

- [x] 3.1 RED: add source-identity collision tests in `test/features/library_intelligence/application/library_intelligence_*_test.dart` and `test/features/library_intelligence/infrastructure/file_library_intelligence_store_test.dart`.
- [x] 3.2 GREEN: preserve `providerId::trackId` plus server scope in `lib/features/library_intelligence/**/*.dart` while keeping local behavior unchanged.
- [x] 3.3 RED/GREEN: extend `test/features/library/application/library_providers_search_test.dart` and `test/features/library/presentation/library_screen_test.dart` for debounce, stale-request cancellation, loading/empty/error states, and source labels; implement in `lib/features/library/application/library_providers.dart` and `lib/features/library/presentation/library_screen.dart`.

## Phase 4: Multi-Server, Verification, Docs

- [x] 4.1 RED/GREEN: cover list/switch/edit/delete/test isolation in `test/features/providers/infrastructure/subsonic_server_store_test.dart`; implement helpers and targeted cleanup in `lib/features/providers/infrastructure/subsonic_server_store.dart` and `lib/features/providers/application/subsonic_providers.dart`.
- [x] 4.2 REFACTOR: add focused widget/manual checklist notes in this change folder if needed during apply/verify, preserve no redesign/no sync/no new providers, and explicitly keep `android/build/reports/problems/problems-report.html` untouched.
- [x] 4.3 VERIFY: run `flutter test` for touched suites and `flutter analyze --no-fatal-infos --no-fatal-warnings` after each PR slice, keeping tests with the same work unit.
