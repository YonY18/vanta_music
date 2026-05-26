# Tasks: Add Subsonic/Navidrome Provider

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 900-1300 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 -> PR 2 -> PR 3 -> PR 4 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Multi-server config + secure secret boundaries | PR 1 | Base: main; includes RED/GREEN/REFACTOR tests for server store + auth params. |
| 2 | Subsonic provider read/search/stream contracts | PR 2 | Base: PR 1; keeps Navidrome as server config, not provider-specific code. |
| 3 | Remote library/search surfaces + player resolver/session safety | PR 3 | Base: PR 2; separated remote UI/providers; no auth URL persistence. |
| 4 | Remote artwork/cache guardrails + manual smoke doc | PR 4 | Base: PR 3; async cache behavior + auth-hygiene diagnostics. |

## Phase 1: Foundation (config, identity, secrets)

- [x] 1.1 **RED** Add failing tests in `test/features/providers/infrastructure/subsonic_server_store_test.dart` for multi-server add/edit/delete/select and secure-storage-by-server-id boundaries.
- [x] 1.2 **GREEN** Create `lib/features/providers/infrastructure/subsonic_server_store.dart` for non-sensitive server metadata list, simple active server id, and secure secret lookup keyed by `serverId`; no advanced switching.
- [x] 1.3 **REFACTOR** Create `lib/features/providers/domain/provider_identity.dart` and update `lib/features/library/domain/album.dart` + `lib/features/library/domain/artist.dart` for `providerId` defaults preserving local compatibility.

## Phase 2: Subsonic API + provider core

- [x] 2.1 **RED** Add failing tests in `test/features/providers/infrastructure/subsonic_api_client_test.dart` for auth params (`u,s,t,v,c,f`), timeout/TLS/auth errors, and redacted logging.
- [x] 2.2 **GREEN** Create `lib/features/providers/infrastructure/subsonic_api_client.dart` implementing ping/getArtists/getAlbumList2/getAlbum/getSong/search3/stream/getCoverArt with typed failures.
- [x] 2.3 **RED** Add failing mapping/stream tests in `test/features/providers/infrastructure/subsonic_music_provider_test.dart` for server-scoped ids and no full-download path.
- [x] 2.4 **GREEN/REFACTOR** Create `lib/features/providers/infrastructure/subsonic_music_provider.dart`, replace `lib/features/providers/infrastructure/navidrome_provider.dart`, and update `lib/features/providers/domain/music_provider.dart` contracts.

## Phase 3: Integration (remote surfaces + playback)

- [x] 3.1 **RED** Extend `test/features/library/application/library_providers_search_test.dart` and `test/features/library/presentation/library_screen_test.dart` for remote-scoped browse/search separated from local smart sections.
- [x] 3.2 **GREEN** Update `lib/features/library/application/library_providers.dart`, `lib/features/library/application/library_collections.dart`, and `lib/features/library/presentation/library_screen.dart` to add dedicated remote providers/UI states.
- [x] 3.3 **RED** Add failing cases in `test/features/player/infrastructure/vanta_audio_handler_test.dart` + `test/features/player/domain/playback_session_test.dart` for dynamic resolver and non-persistence of auth-bearing stream URLs.
- [x] 3.4 **GREEN/REFACTOR** Update `lib/features/player/infrastructure/vanta_audio_handler.dart` and `lib/features/player/domain/playback_session.dart` with `StreamResolverRegistry` integration and sanitized persisted session fields.

## Phase 4: Artwork, verification, and manual smoke

- [x] 4.1 **RED** Add failing tests in `test/shared/artwork_cache/artwork_cache_resolver_test.dart` + `test/shared/artwork_cache/artwork_precache_test.dart` for async remote artwork fetch, bounded cache reuse, and sanitized keys/diagnostics.
- [x] 4.2 **GREEN/REFACTOR** Update `lib/shared/artwork_cache/artwork_cache_resolver.dart`, `lib/shared/artwork_cache/artwork_cache_key.dart`, and `lib/shared/artwork_cache/artwork_cache_diagnostics.dart` for remote cover bytes without scroll jank or auth leakage.
- [x] 4.3 Add dependency wiring in `pubspec.yaml`, create `docs/manual/navidrome-subsonic-test.md`, then run `flutter test` with results captured in change notes.
