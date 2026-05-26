## Exploration: Add initial online support via Subsonic/Navidrome

### Current State
Vanta is currently local-first in practice: `tracksProvider` merges folder scan + MediaStore local tracks (`lib/features/library/application/library_providers.dart`) and all UI tabs render from that single local list (`lib/features/library/presentation/library_screen.dart`).

Domain identity already includes `providerId` + `id` on `Track` (`lib/features/library/domain/track.dart`), and playback intelligence/favorites/history keys are `providerId::id` (`lib/features/library_intelligence/application/library_intelligence_controller.dart`, `lib/features/player/infrastructure/vanta_audio_handler.dart`). This is good for multi-source identity.

However, playback currently bypasses provider stream resolution: `VantaAudioHandler` always loads `AudioSource.uri(Uri.parse(mediaItem.id))` and `mediaItem.id` is set to `track.uri` (`mediaItemFromTrack`), so `MusicProvider.resolveStream()` is not used anywhere.

Artwork pipeline is local-centric: cache key includes provider+track identity (good), but byte sources are `OnAudioQuery` and local file embedded extraction (`lib/shared/artwork_cache/artwork_cache_resolver.dart`). Remote URL fetching for cover art does not exist yet.

Persistence today is JSON files in app support dir for playlists, playback session, folder sources, intelligence, premium metadata overrides/palette cache. Drift is a dependency but currently not used in `lib/`. `flutter_secure_storage` is not installed.

### Affected Areas
- `lib/features/library/domain/track.dart` — may need remote identity/cover fields without breaking local semantics.
- `lib/features/library/domain/album.dart` — currently lacks provider identity; remote album IDs can collide.
- `lib/features/library/domain/artist.dart` — same collision risk as album.
- `lib/features/playlists/domain/playlist.dart` + `.../local_playlist_store.dart` — remote tracks in playlists persistence and rehydration.
- `lib/features/providers/domain/music_provider.dart` — current interface is minimal; no server context/config abstraction.
- `lib/features/providers/infrastructure/navidrome_provider.dart` — existing stub to replace with real implementation.
- `lib/features/library/application/library_providers.dart` — currently hardwired to local provider only.
- `lib/features/player/infrastructure/vanta_audio_handler.dart` — currently assumes `mediaItem.id == final playable URI`; no per-provider resolve/headers.
- `lib/features/player/application/media_item_artwork_request.dart` — `artworkId` is `int?`; remote cover identities may be non-integer strings.
- `lib/shared/artwork_cache/artwork_cache_resolver.dart` — needs remote cover byte source path.
- `lib/app/router.dart` + `lib/features/library/presentation/library_screen.dart` — source/server surfaces and route wiring.
- `pubspec.yaml` — add secure credential/network dependencies (`flutter_secure_storage`, likely `crypto`, network client package).
- `test/features/player/...`, `test/features/library/...`, `test/shared/artwork_cache/...` — add/adjust coverage for remote identity, stream resolution, and artwork source branching.

### Approaches
1. **Direct Navidrome integration in app layer** — Implement Navidrome-specific calls and UI directly now.
   - Pros: Fastest path to first remote playback.
   - Cons: Duplicates logic if later adding another Subsonic-compatible server; harder long-term maintenance.
   - Effort: Medium

2. **Reusable Subsonic provider base + Navidrome config first** — Build `SubsonicApiClient` + `SubsonicMusicProvider`, expose Navidrome as first server type/config.
   - Pros: Matches extensibility goal; clean separation; future Subsonic/OpenSubsonic servers mostly configuration.
   - Cons: Slightly more up-front structure work before first playback.
   - Effort: Medium

### Recommendation
Use **Approach 2** with a minimal first slice:
- Add provider-agnostic Subsonic client (JSON only) and `SubsonicMusicProvider`.
- Keep player source-agnostic by introducing a **stream resolution step at play time** (instead of baking expiring stream URL into `Track.uri`).
- Add a small server-config module (secure credentials + lightweight server metadata store).
- Add a separate remote library screen/tab (no local+remote mixed list in v1).

This minimizes regression risk for local playback and preserves architecture for future providers.

### Risks
- **Playback regression risk**: changing queue/source loading path could break local play-next/queue/session restore if not isolated.
- **Auth/stream expiry risk**: Subsonic stream links can depend on auth params; caching wrong URL in session may fail after restore.
- **Artwork path assumptions**: current artwork uses `int? artworkId` and local byte sources; remote covers need string IDs/URL fetch.
- **Security risk**: accidental logging of URL with auth query params if error/debug logs are not sanitized.

### Ready for Proposal
Yes — with strict scope guardrails:
- **Implement first**: server CRUD + secure credentials, ping/test connection, Subsonic search/library read endpoints, remote playback queue, remote artwork cache fetch, explicit remote UI surface.
- **Do not implement first**: offline downloads, bidirectional sync, metadata editing upstream, mixed local+remote unified view, multi-server sync logic, Jellyfin/YouTube/SMB/WebDAV.
