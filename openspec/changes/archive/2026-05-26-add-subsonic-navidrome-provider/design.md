# Design: Add Subsonic/Navidrome Provider

## Technical Approach

Add a reusable Subsonic/OpenSubsonic provider while keeping the local library and player paths stable. Navidrome is modeled as saved server metadata for the Subsonic provider, not a hardcoded provider class. Remote browse/search stays in dedicated Riverpod providers and UI surfaces; existing `tracksProvider`, smart sections, and local playback remain local-only.

## Architecture Decisions

| Decision | Choice | Tradeoff / Rationale |
|---|---|---|
| Provider model | Replace the `NavidromeProvider` stub with `SubsonicMusicProvider` plus `SubsonicServerConfig` | Keeps OpenSubsonic reusable and avoids another single-server abstraction. |
| Secrets | Store password/token material only in `flutter_secure_storage`; persist only id, name, baseUrl, username, apiVersion | Requires split repositories, but prevents JSON/log/session leakage. |
| Identity | Add `providerId` to `Album`/`Artist`; keep `Track.providerId`; remote ids use server-scoped ids | Prevents local/remote collisions without changing local track ids or broad Drift migration. |
| Playback | Inject a `StreamResolverRegistry` into `VantaAudioHandler`; local provider resolves to `track.uri`, remote resolves on demand | Player remains source-agnostic; local playback behavior is unchanged. |
| Artwork | Extend artwork resolver with provider-aware remote byte source and cache sanitized keys | Avoids auth URLs in logs/cache names and keeps list paint async. |

## Data Flow

```text
Remote UI -> subsonicRemoteLibraryProvider -> SubsonicMusicProvider
          -> SubsonicApiClient -> server/rest/*.view

PlayerController -> VantaAudioHandler -> StreamResolverRegistry
                 -> MusicProvider.resolveStream(track) -> just_audio AudioSource
```

## File Changes

| File | Action | Description |
|---|---|---|
| `pubspec.yaml` | Modify | Add `flutter_secure_storage`, `http`, `crypto`. |
| `lib/features/providers/domain/music_provider.dart` | Modify | Keep interface; document provider ids and stream resolution contract. |
| `lib/features/providers/domain/provider_identity.dart` | Create | Helpers for stable local/remote keys. |
| `lib/features/providers/infrastructure/subsonic_api_client.dart` | Create | Builds auth params (`u`, `s`, `t`, `v`, `c=vanta`, `f=json`), ping, browse/search, stream/cover URLs, timeout/error mapping. |
| `lib/features/providers/infrastructure/subsonic_music_provider.dart` | Create | Maps Subsonic artists/albums/songs to domain models and resolves streams. |
| `lib/features/providers/infrastructure/subsonic_server_store.dart` | Create | Non-sensitive config JSON + secure storage secret access. |
| `lib/features/providers/infrastructure/navidrome_provider.dart` | Delete/replace | Remove MVP stub in favor of configured Subsonic provider. |
| `lib/features/library/domain/{album,artist}.dart` | Modify | Add `providerId`, default local compatibility if needed. |
| `lib/features/library/application/library_collections.dart` | Modify | Include provider in album/artist grouping keys. |
| `lib/features/library/application/library_providers.dart` | Modify | Add remote providers; keep existing local `tracksProvider` unchanged. |
| `lib/features/player/infrastructure/vanta_audio_handler.dart` | Modify | Resolve queue item stream URI at enqueue/restore; never persist secret URLs. |
| `lib/features/player/domain/playback_session.dart` | Modify | Persist provider/track metadata, not authenticated stream URLs for remote items. |
| `lib/shared/artwork_cache/*` | Modify | Add remote cover source; sanitize diagnostics and cache keys. |
| `lib/features/providers/presentation/*` | Create | Minimal server form/test and remote browse/search empty/loading/error states. |
| `docs/manual/navidrome-subsonic-test.md` | Create | Manual setup, test connection, browse/search/play/artwork checklist. |

## Interfaces / Contracts

```dart
class SubsonicServerConfig { String id, name, baseUrl, username, apiVersion; }
abstract class SubsonicSecretStore { Future<String?> readPassword(String serverId); }
abstract class StreamResolverRegistry { Future<StreamUri> resolve(Track track); }
```

`SubsonicApiClient` returns typed failures: auth, timeout, tls, server, malformedResponse. Error messages and logs use redacted URLs; TLS validation is never disabled.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Auth params, redaction, URL building, JSON mapping, errors | Fake HTTP client + secure store. |
| Unit | Provider identity grouping and local compatibility | Existing collection tests plus remote cases. |
| Unit | Audio handler dynamic resolution/session persistence | Fake registry; assert local URI unchanged and remote sessions omit auth URLs. |
| Unit | Remote artwork cache | Fake remote bytes source; assert async cache hit and sanitized diagnostics. |
| Manual | Real Navidrome | `docs/manual/navidrome-subsonic-test.md`; run `flutter test`. |

## Migration / Rollout

No broad Drift migration. Slice 1: client/config/secrets. Slice 2: provider mapping + tests. Slice 3: source-separated UI. Slice 4: player stream resolution/session safety. Slice 5: artwork cache + manual Navidrome doc.

## Open Questions

- [ ] Whether multiple saved Subsonic servers are needed in the first UI, or one configured server is enough for MVP.
