# Design: v0.4.1 Navidrome Online Polish & Reliability

## Technical Approach

Harden the existing Subsonic/Navidrome path in-place: keep Riverpod providers, file-backed stores, current player/audio handler, and artwork pipeline, then add typed remote failure states, server-scoped caches, bounded browse/search, and per-track playback recovery. This avoids the current `getTracks()` N+1 path in `subsonic_music_provider.dart`, preserves local-first behavior, and keeps remote data explicitly separate from local library intelligence.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Failure model | Extend `SubsonicFailure` into UI-facing typed states: auth, timeout, tls, unavailable, malformed, notFound, forbidden, unknown | `subsonic_api_client.dart` already throws typed failures, so the smallest safe change is mapping them through providers/UI instead of adding a new networking layer. |
| Remote metadata cache | Add a file-backed remote library cache keyed by `serverId + providerId`, storing payload, `lastSyncAt`, and `isStale` | `FileLibraryIntelligenceStore` and `SubsonicServerStore` already use JSON files; same persistence style avoids Drift/schema work while keeping remote/local fully isolated. |
| Artwork isolation | Cache remote artwork by `serverId + coverArtId + sizePx`, dedupe in-flight fetches, and keep short-lived negative results for corrupt/missing art | Current keys are track-centric; remote art must survive track remaps and never bleed across servers. |
| Playback recovery | Resolve remote streams per item with bounded retry and skip failed item only | `VantaAudioHandler.resolveQueueItemUris()` currently fails the whole queue with `Future.wait`; per-item handling is the minimal way to preserve queue continuity. |

## Data Flow

`LibraryScreen/remote providers -> SubsonicMusicProvider -> SubsonicApiClient -> Remote cache`

`Remote cache hit + server down -> stale UI + manual retry`

`Queue item -> SubsonicStreamResolverRegistry -> fresh stream URL -> AudioSource`

`Resolve failure -> mark track failed -> retry action or skip next track`

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/features/providers/infrastructure/subsonic_api_client.dart` | Modify | Normalize HTTP/status/code failures, bounded timeout/retry helpers, and safe classification for UI recovery. |
| `lib/features/providers/infrastructure/subsonic_music_provider.dart` | Modify | Replace full-library N+1 hydration with bounded browse/search fetches and remote cache writes/reads. |
| `lib/features/providers/infrastructure/subsonic_server_store.dart` | Modify | Add list/edit/delete/test/select helpers and targeted cleanup hooks for one server only. |
| `lib/features/providers/application/subsonic_providers.dart` | Modify | Expose active server state, remote cache store, and retry/refresh providers. |
| `lib/features/library/application/library_providers.dart` | Modify | Remote loading/error/stale/search providers with debounce and stale-request cancellation. |
| `lib/features/library/presentation/library_screen.dart` | Modify | Show offline/server-unavailable states, retry, refresh, stale badge/timestamp, and basic multi-server management without redesign. |
| `lib/shared/artwork_cache/*` | Modify | Server-scoped remote keys, in-flight dedupe, corrupt/miss handling, lazy placeholders, light now-playing/queue precache, non-blocking scroll. |
| `lib/features/player/application/subsonic_stream_resolver_registry.dart` | Modify | Return classified stream-resolution failures for retry/skip behavior. |
| `lib/features/player/infrastructure/vanta_audio_handler.dart` | Modify | Fail one remote track without breaking queue, preserve notification metadata, and allow manual retry from now playing. |
| `lib/features/player/domain/playback_session.dart` | Modify | Persist retry-safe remote identity only; never auth-bearing URLs. |
| `lib/features/library_intelligence/*` | Modify | Preserve `providerId::trackId` identity plus server scope for favorites/history/stats/recent/continue listening while keeping existing local compatibility. |
| `test/**` | Modify | Add provider/player/cache/UI regression coverage for reliability, isolation, redaction, and bounded behavior. |

## Interfaces / Contracts

- `RemoteLibrarySnapshot { serverId, providerId, tracks/albums/artists, lastSyncAt, isStale }`
- `RemoteLibraryUiState { data?, failure?, canRetry, isRefreshing, isUsingCache }`
- `RemoteTrackFailure { trackKey, serverId, reason, retryable }`
- Artwork cache key format: `subsonic|<serverId>|<coverArtId>|<sizePx>`

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Failure taxonomy, retry caps, backoff, server-scoped cache/artwork keys, redaction | Extend current `subsonic_api_client`, server-store, artwork-cache, and playback-session tests. |
| Integration | Remote browse/search fallback to cache, stale indicators, server delete isolation, queue continuation after one failure | Riverpod/provider tests and focused audio-handler tests with fake resolver/client. |
| Widget | Remote empty/loading/error/offline states, retry/refresh, multi-server sheet flows, source separation | Extend `library_screen_test.dart` without visual redesign assertions. |

## Migration / Rollout

No schema migration required. New remote cache files are additive. Existing intelligence data stays readable because stable keys remain `providerId::trackId`; remote-only fields are optional. Deleting a server must remove only that server's password, remote metadata cache, and remote artwork entries. The unrelated staged deletion `android/build/reports/problems/problems-report.html` remains untouched.

## Open Questions

- [ ] If `search3` album/artist groups are returned cleanly, can the Remote tab expose segmented songs/albums/artists without adding a new navigation pattern?
